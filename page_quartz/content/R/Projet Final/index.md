---
title: "Projet final : Classification bayésienne et Analyse Factorielle Discriminante"
output:
  html_document:
    theme: readable
    highlight: textmate
    toc: true
    toc_depth: 4
    toc_float: true
    number_sections: true
    code_folding: hide
    df_print: paged
---

```{r setup, include=FALSE}
knitr::opts_chunk$set(
  echo = TRUE,
  message = FALSE,
  warning = FALSE,
  fig.width = 9,
  fig.height = 5,
  fig.align = "center"
)
```

<style type="text/css">
body {
  font-size: 16px;
  line-height: 1.6;
}

p, li {
  text-align: justify;
}

h1, h2, h3 {
  color: #0b4f8a;
}

pre, code {
  font-size: 13px;
}

.main-container {
  max-width: 1200px;
}

blockquote {
  border-left: 4px solid #0b4f8a;
  padding-left: 12px;
  color: #444;
}
</style>

::: {align="center"}
**Fouille de données avec R pour la data science et l'intelligence artificielle**  
:::


<hr style="border: 1px solid #bfcad4;">

# Préambule

Ce rapport s'inscrit dans le cadre du challenge Kaggle **LLM - Detect AI Generated Text**, dont l'objectif est de déterminer si un essai a été écrit par un humain (`label = 0`) ou généré par une IA (`label = 1`). Le travail exploite `train_essays.csv` (jeu officiel) ainsi que `train_drcat_01.csv` à `train_drcat_04.csv` (jeu DAIGT enrichi), afin d'obtenir un volume de données suffisant pour entraîner et évaluer correctement les modèles.

Le critère principal du challenge est le **ROC-AUC** calculé sur des probabilités prédites. Dans ce rapport, ce critère est complété par l'accuracy, la précision, le rappel, le score F1 et le score de Brier, afin d'évaluer à la fois la capacité de discrimination du modèle et la qualité de calibration probabiliste.

La démarche suit une logique de cours en cinq étapes cohérentes : d'abord préparer les données et vérifier leur qualité, ensuite extraire des caractéristiques textuelles interprétables et vectorielles, puis réduire la dimension de façon discriminante avec l'AFD, entraîner un classifieur bayésien sur l'espace réduit, et enfin valider les performances avec une évaluation robuste en validation croisée stratifiée.

# Données et prétraitement

Cette section explique comment les données brutes sont transformées en un jeu exploitable pour l'analyse. La démarche de code est volontairement structurée : charger uniquement les fichiers nécessaires, harmoniser les schémas entre sources hétérogènes et contrôler la qualité avant de passer à la modélisation. Cette étape est essentielle, car une classification performante ne peut pas compenser des incohérences structurelles dans les données d'entrée.

## Packages utilisés

Les bibliothèques sont organisées par rôle méthodologique. `data.table` et `dplyr` sont mobilisés pour la manipulation tabulaire, `stringr`, `stringi` et `quanteda` pour le traitement linguistique, `irlba` et `topicmodels` pour la réduction et l'analyse thématique, `pROC` pour l'évaluation probabiliste, puis `ggplot2` et `knitr` pour les visualisations et la restitution dans le rapport.

```{r packages}
required_packages <- c(
  "data.table", "dplyr", "stringr", "stringi", "ggplot2",
  "forcats", "scales", "knitr", "Matrix",
  "quanteda", "quanteda.textstats", "topicmodels", "irlba", "pROC"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

invisible(lapply(required_packages, library, character.only = TRUE))
```

## Localiser le dossier de données

Le code teste plusieurs chemins candidats pour rendre le rapport robuste selon l'organisation locale du dossier.

```{r locate-data}
candidate_dirs <- c(
  "datasets/datasets/train_drcat",
  "datasets/train_drcat"
)

data_dir <- candidate_dirs[file.exists(candidate_dirs)][1]

if (is.na(data_dir) || length(data_dir) == 0) {
  stop("Aucun dossier de données trouvé. Vérifie les chemins de datasets.")
}

data_dir
```

## Import des fichiers CSV

La fonction d'import applique une normalisation explicite : si une colonne n'existe pas dans un fichier source, elle est creee avec une valeur par defaut.  
Ainsi, le jeu final possede une structure homogene, ce qui simplifie toutes les etapes suivantes.

```{r import-data}
read_drcat_file <- function(path) {
  dt <- data.table::fread(path, encoding = "UTF-8")

  if (!"essay_id" %in% names(dt)) dt[, essay_id := NA_character_]
  if (!"prompt" %in% names(dt)) dt[, prompt := NA_character_]
  if (!"fold" %in% names(dt)) dt[, fold := NA_integer_]
  if (!"source" %in% names(dt)) dt[, source := "unknown"]

  dt[, dataset_file := basename(path)]
  dt[, .(essay_id, text, label, source, prompt, fold, dataset_file)]
}

drcat_paths <- file.path(data_dir, sprintf("train_drcat_0%d.csv", 1:4))
missing_files <- drcat_paths[!file.exists(drcat_paths)]
if (length(missing_files) > 0) {
  stop(
    "Fichiers manquants:\n",
    paste(missing_files, collapse = "\n")
  )
}

drcat_data <- data.table::rbindlist(
  lapply(drcat_paths, read_drcat_file),
  use.names = TRUE,
  fill = TRUE
)

official_path <- file.path(data_dir, "train_essays.csv")
official_data <- NULL

if (file.exists(official_path)) {
  tmp <- data.table::fread(official_path, encoding = "UTF-8")
  official_data <- tmp[, .(
    essay_id = as.character(id),
    text = text,
    label = as.integer(generated),
    source = "official_train_essays",
    prompt = NA_character_,
    fold = NA_integer_,
    dataset_file = "train_essays.csv"
  )]
}

full_data <- if (is.null(official_data)) {
  drcat_data
} else {
  data.table::rbindlist(
    list(drcat_data, official_data),
    use.names = TRUE,
    fill = TRUE
  )
}
```

## Nettoyage minimal et vérification

Cette étape assure la cohérence minimale du jeu d'étude. Les labels sont convertis dans un format binaire exploitable, les textes vides ou non valides sont retirés, puis une variable de classe lisible (`Humain`, `IA`) est construite pour rendre les analyses et les graphiques plus interprétables.

```{r clean-and-check}
full_data[, label := suppressWarnings(as.integer(label))]
full_data[, fold := suppressWarnings(as.integer(fold))]
full_data[, source := ifelse(is.na(source) | source == "", "unknown", source)]
full_data[, text := stringr::str_squish(text)]

data_tbl <- full_data[
  !is.na(text) & text != "" & label %in% c(0, 1)
]

data_tbl[, classe := factor(label, levels = c(0, 1), labels = c("Humain", "IA"))]
data_tbl <- tibble::as_tibble(data_tbl)

overview <- data_tbl %>%
  summarise(
    nb_essais = n(),
    nb_sources = n_distinct(source),
    nb_fichiers = n_distinct(dataset_file)
  )

knitr::kable(overview)
```

```{r preview}
preview_tbl <- data_tbl %>%
  transmute(
    extrait_texte = substr(text, 1, 140),
    label,
    classe,
    source,
    fold,
    dataset_file
  ) %>%
  head(5)

knitr::kable(preview_tbl)
```

## Exploration des données (EDA)

L'EDA ne sert pas seulement à décrire les données ; elle oriente aussi les choix de modélisation. Dans cette section, l'analyse vérifie simultanément l'équilibre des classes, l'hétérogénéité des sources et la structure statistique des longueurs textuelles, de manière à identifier précocement les risques de biais ou de sur-apprentissage.

### Distribution des classes

```{r class-distribution}
class_dist <- data_tbl %>%
  count(classe, sort = TRUE) %>%
  mutate(proportion = n / sum(n))

knitr::kable(
  class_dist %>%
    mutate(proportion = scales::percent(proportion, accuracy = 0.1))
)

ggplot(class_dist, aes(x = classe, y = n, fill = classe)) +
  geom_col(width = 0.65) +
  geom_text(aes(label = scales::comma(n)), vjust = -0.4, size = 4) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Distribution des classes (Humain vs IA)",
    x = NULL,
    y = "Nombre d'essais"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")
```

### Distribution par source

```{r source-distribution}
source_dist <- data_tbl %>%
  count(source, classe, sort = TRUE)

top_sources <- source_dist %>%
  group_by(source) %>%
  summarise(total = sum(n), .groups = "drop") %>%
  slice_max(total, n = 12)

source_plot_data <- source_dist %>%
  inner_join(top_sources, by = "source")

ggplot(
  source_plot_data,
  aes(
    x = forcats::fct_reorder(source, total),
    y = n,
    fill = classe
  )
) +
  geom_col(position = "fill") +
  coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Top 12 sources - proportion Humain/IA",
    x = "Source",
    y = "Proportion"
  ) +
  theme_minimal(base_size = 12)
```

### Variables textuelles de base sur un échantillon

Pour limiter le temps de calcul sur plus de 160k essais, on calcule les indicateurs textuels sur un echantillon stratifie.

```{r text-features-sample}
set.seed(4209)
target_n <- 80000L
sample_fraction <- min(1, target_n / nrow(data_tbl))

eda_sample <- data_tbl %>%
  group_by(classe) %>%
  slice_sample(prop = sample_fraction) %>%
  ungroup() %>%
  mutate(
    n_chars = stringr::str_length(text),
    n_words = stringr::str_count(text, "\\S+"),
    n_sentences = pmax(1L, stringr::str_count(text, "[.!?]+")),
    avg_words_per_sentence = n_words / n_sentences
  )

lexical_stats <- eda_sample %>%
  group_by(classe) %>%
  summarise(
    n = n(),
    mean_words = mean(n_words),
    median_words = median(n_words),
    sd_words = sd(n_words),
    mean_sentences = mean(n_sentences),
    mean_words_per_sentence = mean(avg_words_per_sentence),
    .groups = "drop"
  ) %>%
  mutate(
    mean_words = round(mean_words, 1),
    median_words = round(median_words, 1),
    sd_words = round(sd_words, 1),
    mean_sentences = round(mean_sentences, 1),
    mean_words_per_sentence = round(mean_words_per_sentence, 2)
  )

knitr::kable(lexical_stats)
```

### Visualisation des longueurs de textes

```{r words-hist}
ggplot(eda_sample %>% filter(n_words > 0), aes(x = n_words, fill = classe)) +
  geom_histogram(bins = 70, alpha = 0.55, position = "identity") +
  scale_x_log10(labels = scales::comma) +
  labs(
    title = "Distribution du nombre de mots (echelle log10)",
    x = "Nombre de mots",
    y = "Frequence"
  ) +
  theme_minimal(base_size = 12)
```

```{r words-boxplot}
ggplot(eda_sample %>% filter(n_words > 0), aes(x = classe, y = n_words, fill = classe)) +
  geom_boxplot(outlier.alpha = 0.12) +
  scale_y_log10(labels = scales::comma) +
  labs(
    title = "Comparaison des longueurs de texte par classe",
    x = NULL,
    y = "Nombre de mots (log10)"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")
```

# Extraction de caractéristiques (Feature Extraction)

Cette section constitue le cœur méthodologique du projet, car elle transforme un texte brut en variables quantitatives informatives. La démarche combine des indicateurs linguistiques interprétables, des représentations vectorielles de grande dimension (n-grammes et TF-IDF) et une lecture thématique globale par topics, afin de couvrir à la fois la forme du texte et son contenu sémantique.

## Constitution du jeu de travail

Pour conserver un temps de calcul raisonnable, les caractéristiques sont extraites sur un échantillon stratifié. Cette stratégie maintient la représentativité des classes tout en rendant les calculs reproductibles et compatibles avec un environnement de projet étudiant.

```{r feature-workset}
set.seed(4209)
max_docs_features <- 20000L
feature_fraction <- min(1, max_docs_features / nrow(data_tbl))

feature_data <- data_tbl %>%
  group_by(classe) %>%
  slice_sample(prop = feature_fraction) %>%
  ungroup() %>%
  mutate(
    doc_id = sprintf("doc_%07d", row_number())
  ) %>%
  select(doc_id, essay_id, label, classe, source, fold, dataset_file, text)

knitr::kable(
  feature_data %>%
    count(classe) %>%
    mutate(proportion = scales::percent(n / sum(n), accuracy = 0.1))
)
```

## Caractéristiques stylométriques et linguistiques

Les variables calculées couvrent plusieurs niveaux d'analyse complémentaires. Le premier niveau mesure la forme du texte à travers les mots, les caractères, la ponctuation et l'usage des majuscules. Le deuxième niveau quantifie la structure syntaxique à l'aide du nombre de phrases et de la variabilité de leurs longueurs. Le troisième niveau décrit la complexité lexicale via le TTR et le ratio de stopwords, puis la lisibilité est évaluée avec des indices classiques (Flesch, Flesch-Kincaid, FOG, SMOG, Coleman-Liau). Enfin, une perplexité unigramme approximée est calculée pour capter une forme d'incertitude lexicale.

```{r stylometric-features}
sentence_stats <- function(text_vector) {
  stats_list <- lapply(text_vector, function(txt) {
    sents <- stringi::stri_split_regex(
      txt,
      pattern = "(?<=[.!?])\\s+",
      omit_empty = TRUE
    )[[1]]

    sents <- stringi::stri_trim_both(sents)
    sents <- sents[!is.na(sents) & sents != ""]

    if (length(sents) == 0) {
      return(c(n_sentences = 1, mean_sentence_words = NA_real_, sd_sentence_words = NA_real_))
    }

    sent_word_counts <- stringr::str_count(sents, "\\S+")
    c(
      n_sentences = length(sents),
      mean_sentence_words = mean(sent_word_counts),
      sd_sentence_words = if (length(sent_word_counts) > 1) stats::sd(sent_word_counts) else 0
    )
  })

  tibble::as_tibble(do.call(rbind, stats_list))
}

stylometric_base <- feature_data %>%
  transmute(
    doc_id,
    label,
    classe,
    n_chars = stringr::str_length(text),
    n_words = stringr::str_count(text, "\\S+"),
    n_punct = stringr::str_count(text, "[[:punct:]]"),
    n_digits = stringr::str_count(text, "[0-9]"),
    n_alpha = stringr::str_count(text, "[A-Za-z]"),
    n_upper = stringr::str_count(text, "[A-Z]")
  ) %>%
  mutate(
    avg_word_len = n_alpha / pmax(n_words, 1),
    punctuation_ratio = n_punct / pmax(n_words, 1),
    uppercase_ratio = n_upper / pmax(n_alpha, 1)
  )

sent_features <- sentence_stats(feature_data$text)

stylometric_features <- dplyr::bind_cols(stylometric_base, sent_features) %>%
  mutate(
    cv_sentence_words = sd_sentence_words / pmax(mean_sentence_words, 1e-6)
  )
```

```{r readability-perplexity}
texts_named <- feature_data$text
names(texts_named) <- feature_data$doc_id

tokens_words <- quanteda::tokens(
  texts_named,
  what = "word",
  remove_punct = TRUE,
  remove_numbers = TRUE,
  remove_symbols = TRUE
) %>%
  quanteda::tokens_tolower()

n_tokens <- quanteda::ntoken(tokens_words)
n_types <- quanteda::ntype(tokens_words)

stop_tokens <- quanteda::tokens_select(
  tokens_words,
  pattern = quanteda::stopwords("en"),
  selection = "keep"
)
stop_ratio <- quanteda::ntoken(stop_tokens) / pmax(n_tokens, 1)

readability_raw <- quanteda.textstats::textstat_readability(
  texts_named,
  measure = c("Flesch", "Flesch.Kincaid", "FOG", "SMOG", "Coleman.Liau.grade")
)

readability_tbl <- tibble::as_tibble(readability_raw)
doc_col <- names(readability_tbl)[1]

readability_tbl <- readability_tbl %>%
  rename(doc_id = !!doc_col) %>%
  transmute(
    doc_id = as.character(doc_id),
    flesch = Flesch,
    flesch_kincaid = Flesch.Kincaid,
    gunning_fog = FOG,
    smog = SMOG,
    coleman_liau = Coleman.Liau.grade
  )

dfm_unigram <- quanteda::dfm(tokens_words)
unigram_freq <- Matrix::colSums(dfm_unigram)
unigram_prob <- (unigram_freq + 1) / (sum(unigram_freq) + length(unigram_freq))

doc_log_prob <- as.numeric(dfm_unigram %*% log(unigram_prob[colnames(dfm_unigram)]))
perplexity_unigram <- exp(-doc_log_prob / pmax(as.numeric(n_tokens), 1))

stylometric_features <- stylometric_features %>%
  mutate(
    n_tokens = as.numeric(n_tokens),
    n_types = as.numeric(n_types),
    ttr = n_types / pmax(n_tokens, 1),
    stopword_ratio = as.numeric(stop_ratio),
    perplexity_unigram = as.numeric(perplexity_unigram)
  ) %>%
  left_join(readability_tbl, by = "doc_id")

feature_summary <- stylometric_features %>%
  group_by(classe) %>%
  summarise(
    n_docs = n(),
    mean_words = mean(n_words, na.rm = TRUE),
    mean_sent_var = mean(cv_sentence_words, na.rm = TRUE),
    mean_ttr = mean(ttr, na.rm = TRUE),
    mean_flesch = mean(flesch, na.rm = TRUE),
    mean_fk = mean(flesch_kincaid, na.rm = TRUE),
    mean_perplexity = mean(perplexity_unigram, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  mutate(across(where(is.numeric), ~ round(.x, 3)))

knitr::kable(feature_summary)
```

## Distribution des n-grammes (unigrammes et bigrammes)

Cette analyse permet d'identifier les motifs lexicaux les plus differenciants entre classes.

```{r ngram-distribution}
tokens_1_2 <- quanteda::tokens_ngrams(tokens_words, n = 1:2)

dfm_1_2 <- quanteda::dfm(tokens_1_2) %>%
  quanteda::dfm_trim(min_termfreq = 15, min_docfreq = 10)

class_dfm <- quanteda::dfm_group(dfm_1_2, groups = feature_data$classe)

top_ngrams <- dplyr::bind_rows(
  lapply(quanteda::docnames(class_dfm), function(cl) {
    tibble::as_tibble(
      quanteda.textstats::textstat_frequency(class_dfm[cl, ], n = 15)
    ) %>%
      mutate(classe = cl)
  })
) %>%
  select(classe, feature, frequency)

knitr::kable(top_ngrams)
```

## Vectorisation TF-IDF

La vectorisation TF-IDF convertit chaque document en vecteur numerique sparse.
Le code applique ensuite une reduction du nombre de dimensions pour limiter le bruit et le cout calcul.

```{r tfidf-vectorization}
tfidf_matrix <- quanteda::dfm_tfidf(
  dfm_1_2,
  scheme_tf = "prop",
  scheme_df = "inverse",
  base = 10
)

max_tfidf_features <- 12000L
if (quanteda::nfeat(tfidf_matrix) > max_tfidf_features) {
  global_weight <- Matrix::colSums(tfidf_matrix)
  top_idx <- order(global_weight, decreasing = TRUE)[seq_len(max_tfidf_features)]
  tfidf_matrix <- tfidf_matrix[, top_idx]
}

tfidf_overview <- tibble::tibble(
  nb_documents = quanteda::ndoc(tfidf_matrix),
  nb_features = quanteda::nfeat(tfidf_matrix),
  sparsity_pct = round(
    100 * (1 - Matrix::nnzero(tfidf_matrix) / (nrow(tfidf_matrix) * ncol(tfidf_matrix))),
    2
  )
)

knitr::kable(tfidf_overview)
```

## Visualisation des sujets (topics)

Pour visualiser les themes dominants, on applique un modele de topics (LDA) sur une projection bag-of-words echantillonnee.

```{r topic-visualization}
set.seed(4209)
topic_k <- 6L
topic_lda_model <- NULL
topic_terms_plot <- NULL
topic_doc_topics <- NULL

topic_dfm <- quanteda::dfm(tokens_words) %>%
  quanteda::dfm_trim(min_termfreq = 25, min_docfreq = 20)

max_docs_topic <- 6000L
if (quanteda::ndoc(topic_dfm) > max_docs_topic) {
  sampled_docs <- sample(seq_len(quanteda::ndoc(topic_dfm)), max_docs_topic)
  topic_dfm <- topic_dfm[sampled_docs, ]
}

if (quanteda::ndoc(topic_dfm) > topic_k && quanteda::nfeat(topic_dfm) > 100) {
  topic_dtm <- quanteda::convert(topic_dfm, to = "topicmodels")

  topic_lda_model <- topicmodels::LDA(
    topic_dtm,
    k = topic_k,
    method = "Gibbs",
    control = list(seed = 4209, burnin = 500, iter = 1500, thin = 100)
  )

  topic_post <- topicmodels::posterior(topic_lda_model)
  topic_term_probs <- topic_post$terms
  topic_doc_topics <- as.data.frame(topic_post$topics)
  topic_doc_topics$doc_id <- rownames(topic_post$topics)

  top_n_terms <- min(10L, ncol(topic_term_probs))
  topic_terms_plot <- dplyr::bind_rows(
    lapply(seq_len(nrow(topic_term_probs)), function(i) {
      top_idx <- order(topic_term_probs[i, ], decreasing = TRUE)[seq_len(top_n_terms)]
      tibble::tibble(
        topic = paste0("Topic ", i),
        terme = colnames(topic_term_probs)[top_idx],
        prob = as.numeric(topic_term_probs[i, top_idx])
      )
    })
  ) %>%
    group_by(topic) %>%
    arrange(desc(prob), .by_group = TRUE) %>%
    mutate(term_topic = paste(topic, terme, sep = "__")) %>%
    ungroup() %>%
    mutate(term_topic = factor(term_topic, levels = rev(unique(term_topic))))

  knitr::kable(
    topic_terms_plot %>%
      group_by(topic) %>%
      slice_head(n = 5) %>%
      ungroup() %>%
      select(topic, terme, prob)
  )

  ggplot(topic_terms_plot, aes(x = term_topic, y = prob, fill = topic)) +
    geom_col(show.legend = FALSE) +
    facet_wrap(~ topic, scales = "free") +
    coord_flip() +
    scale_x_discrete(labels = function(x) sub("^.*__", "", x)) +
    labs(
      title = "Top termes par topic (LDA)",
      x = "Termes",
      y = "Probabilite dans le topic"
    ) +
    theme_minimal(base_size = 11)
} else {
  cat("Conditions insuffisantes pour la modélisation de topics.")
}
```

## Option BERT (facultatif)

Le projet demande TF-IDF ou BERT. Ici, la vectorisation TF-IDF est implementee et operationnelle. Le bloc suivant montre une piste BERT, laissee en option.

```{r bert-optional, eval=FALSE}
if (!requireNamespace("text", quietly = TRUE)) {
  install.packages("text", repos = "https://cloud.r-project.org")
}

library(text)

bert_embeddings <- text::textEmbed(
  texts = feature_data$text,
  model = "bert-base-uncased"
)$texts

dim(bert_embeddings)
```

## Sauvegarde des artefacts

```{r save-features}
dir.create("artifacts", showWarnings = FALSE)

feature_metadata <- feature_data %>%
  select(doc_id, essay_id, label, classe, source, fold, dataset_file)

saveRDS(feature_metadata, "artifacts/feature_metadata.rds")
saveRDS(stylometric_features, "artifacts/stylometric_features.rds")
saveRDS(tfidf_matrix, "artifacts/tfidf_matrix_1_2gram.rds")

if (!is.null(topic_lda_model)) {
  saveRDS(topic_lda_model, "artifacts/topic_lda_model.rds")
}
if (!is.null(topic_terms_plot)) {
  saveRDS(topic_terms_plot, "artifacts/topic_terms_plot.rds")
}
if (!is.null(topic_doc_topics)) {
  saveRDS(topic_doc_topics, "artifacts/topic_doc_topics.rds")
}
```

# Analyse des facteurs discriminants (Réduction de la dimensionnalité)

L'objectif de cette partie est de projeter les documents dans un espace plus compact tout en conservant l'information nécessaire à la séparation entre textes humains et textes générés. Concrètement, l'espace TF-IDF est d'abord compressé par SVD, puis fusionné avec les variables stylométriques avant l'apprentissage des axes discriminants `LD*` par AFD/LDA.

## Fondements mathématiques de l'AFD

L'Analyse Factorielle Discriminante (AFD), équivalente ici à la LDA supervisée, cherche des combinaisons linéaires de variables qui maximisent la séparation inter-classes tout en minimisant la dispersion intra-classes. Dans cette logique, \(S_W\) désigne la matrice de dispersion intra-classes, \(S_B\) la matrice de dispersion inter-classes, et \(w\) la direction de projection optimale.

Le critère de Fisher maximisé s'écrit :
\[
J(w) = \frac{w^T S_B w}{w^T S_W w}
\]

Le problème se ramène à une décomposition spectrale de \(S_W^{-1}S_B\). Avec deux classes (Humain vs IA), on obtient principalement un axe discriminant (`LD1`) qui concentre l'essentiel du pouvoir séparateur.

Dans l'esprit du cours, cette étape s'interprète aussi comme un compromis entre séparation géométrique et stabilité statistique. En pratique, les tests de significativité de type Wilks sont pertinents pour valider la discrimination des axes ; ici, l'accent est mis sur la qualité de projection et la performance prédictive finale, car la dimension initiale des variables textuelles est très élevée.

## Préparation de l'espace de travail AFD

L'AFD linéaire est sensible quand le nombre de variables est très élevé. On projette donc d'abord la partie TF-IDF sur des composantes SVD (LSA), puis on combine avec les variables stylométriques.

```{r afd-prepare}
tfidf_sparse <- methods::as(tfidf_matrix, "dgCMatrix")

svd_rank <- min(120L, nrow(tfidf_sparse) - 1L, ncol(tfidf_sparse) - 1L)
if (svd_rank < 2L) {
  stop("Rang SVD insuffisant pour l'AFD.")
}

tfidf_svd <- irlba::irlba(
  tfidf_sparse,
  nv = svd_rank,
  nu = svd_rank
)

tfidf_doc_coords <- sweep(tfidf_svd$u, 2, tfidf_svd$d, `*`)
colnames(tfidf_doc_coords) <- sprintf("svd_%03d", seq_len(ncol(tfidf_doc_coords)))

tfidf_svd_tbl <- tibble::as_tibble(tfidf_doc_coords) %>%
  mutate(doc_id = quanteda::docnames(tfidf_matrix), .before = 1)

impute_median <- function(x) {
  med <- stats::median(x, na.rm = TRUE)
  if (!is.finite(med)) med <- 0
  x[!is.finite(x)] <- NA_real_
  x[is.na(x)] <- med
  x
}

stylometric_model_tbl <- stylometric_features %>%
  select(
    doc_id, classe, label, n_words, avg_word_len, punctuation_ratio,
    uppercase_ratio, mean_sentence_words, sd_sentence_words,
    cv_sentence_words, ttr, stopword_ratio, flesch, flesch_kincaid,
    gunning_fog, smog, coleman_liau, perplexity_unigram
  ) %>%
  mutate(across(where(is.numeric), impute_median))

afd_dataset <- stylometric_model_tbl %>%
  inner_join(tfidf_svd_tbl, by = "doc_id")

afd_feature_cols <- setdiff(names(afd_dataset), c("doc_id", "classe", "label"))
afd_X <- scale(as.matrix(afd_dataset[, afd_feature_cols]))

afd_ready <- tibble::as_tibble(afd_X) %>%
  mutate(
    doc_id = afd_dataset$doc_id,
    classe = afd_dataset$classe,
    label = afd_dataset$label,
    .before = 1
  )

knitr::kable(
  tibble::tibble(
    n_docs = nrow(afd_ready),
    n_features_for_afd = ncol(afd_X),
    svd_rank = svd_rank
  )
)
```

## AFD linéaire (LDA)

```{r afd-lda-fit}
afd_lda <- MASS::lda(
  x = as.matrix(afd_ready %>% select(-doc_id, -classe, -label)),
  grouping = afd_ready$classe,
  prior = c(0.5, 0.5)
)

afd_pred <- predict(afd_lda)
afd_scores <- as.data.frame(afd_pred$x)
if (!"LD1" %in% names(afd_scores)) {
  names(afd_scores)[1] <- "LD1"
}

post_ia <- afd_pred$posterior[, "IA"]
if (is.null(post_ia)) {
  post_ia <- afd_pred$posterior[, ncol(afd_pred$posterior)]
}

afd_projection <- afd_ready %>%
  select(doc_id, classe, label) %>%
  bind_cols(tibble::as_tibble(afd_scores)) %>%
  mutate(
    pred_classe = afd_pred$class,
    post_ia = as.numeric(post_ia)
  )

lda_accuracy <- mean(afd_projection$pred_classe == afd_projection$classe)
ld1_gap <- abs(
  mean(afd_projection$LD1[afd_projection$classe == "IA"]) -
    mean(afd_projection$LD1[afd_projection$classe == "Humain"])
)

afd_metrics <- tibble::tibble(
  metric = c("Accuracy_in_sample", "Mean_gap_LD1"),
  valeur = c(round(lda_accuracy, 4), round(ld1_gap, 4))
)

knitr::kable(afd_metrics)
```

## Projection discriminante et interprétation

Pour deux classes (Humain vs IA), l'AFD linéaire produit un seul axe discriminant (`LD1`).

```{r afd-visual}
ggplot(afd_projection, aes(x = LD1, fill = classe, color = classe)) +
  geom_density(alpha = 0.22) +
  labs(
    title = "Projection AFD sur l'axe discriminant LD1",
    x = "Score discriminant LD1",
    y = "Densite"
  ) +
  theme_minimal(base_size = 12)
```

```{r afd-loadings}
ld1_loadings <- tibble::tibble(
  variable = rownames(afd_lda$scaling),
  poids = as.numeric(afd_lda$scaling[, 1])
) %>%
  mutate(abs_poids = abs(poids)) %>%
  arrange(desc(abs_poids)) %>%
  slice_head(n = 20) %>%
  select(variable, poids)

knitr::kable(ld1_loadings)
```

## Variante noyau (non linéaire) - optionnelle

Si la frontière entre classes n'est pas linéaire, on peut utiliser une projection noyau (RBF) puis refaire une AFD linéaire dans cet espace.

```{r afd-kernel-optional}
kernel_summary <- NULL

if (requireNamespace("kernlab", quietly = TRUE)) {
  set.seed(4209)
  n_kernel <- min(5000L, nrow(afd_ready))
  idx_kernel <- sample(seq_len(nrow(afd_ready)), n_kernel)

  kernel_input <- as.matrix(
    afd_ready[idx_kernel, setdiff(names(afd_ready), c("doc_id", "classe", "label"))]
  )
  kernel_y <- afd_ready$classe[idx_kernel]

  kpca_model <- kernlab::kpca(
    kernel_input,
    kernel = "rbfdot",
    kpar = list(sigma = 0.08),
    features = 20
  )

  kpca_scores <- as.data.frame(kernlab::rotated(kpca_model))
  colnames(kpca_scores) <- sprintf("KPC%02d", seq_len(ncol(kpca_scores)))

  kernel_lda <- MASS::lda(x = as.matrix(kpca_scores), grouping = kernel_y, prior = c(0.5, 0.5))
  kernel_pred <- predict(kernel_lda)$class

  kernel_summary <- tibble::tibble(
    methode = "KPCA(RBF) + LDA",
    n_docs = n_kernel,
    n_kernel_features = ncol(kpca_scores),
    accuracy_in_sample = round(mean(kernel_pred == kernel_y), 4)
  )

  knitr::kable(kernel_summary)
} else {
  cat("Package 'kernlab' non installe : variante noyau sautee.")
}
```

## Sauvegarde des artefacts AFD

```{r afd-save}
saveRDS(afd_lda, "artifacts/afd_lda_model.rds")
saveRDS(afd_projection, "artifacts/afd_projection_lda.rds")
saveRDS(tfidf_svd, "artifacts/tfidf_svd_model.rds")
```

# Classification bayésienne

Dans cette section, les axes discriminants obtenus à l'étape précédente sont utilisés comme variables d'entrée du classifieur. Le modèle principal est un classifieur bayésien gaussien, retenu parce qu'il reste simple à estimer, qu'il produit naturellement des probabilités a posteriori et qu'il s'aligne directement avec les métriques probabilistes du challenge, notamment ROC-AUC et Brier.

Le principe suit directement la règle de Bayes : pour une classe \(C_k\) et un vecteur de caractéristiques \(x\), on estime \(P(C_k \mid x) \propto P(x \mid C_k) P(C_k)\). Dans l'implémentation retenue, \(P(x \mid C_k)\) est modélisée par une loi gaussienne par composante, ce qui conduit à une forme de classifieur bayésien gaussien de type « naive » sur l'espace AFD réduit.
## Jeu de caractéristiques réduit (sortie AFD)

On utilise les axes discriminants `LD*` issus de l'AFD comme espace réduit pour le classifieur bayésien.

```{r bayes-data}
ld_cols <- grep("^LD", names(afd_projection), value = TRUE)
if (length(ld_cols) == 0) {
  stop("Aucun axe LD trouve dans afd_projection.")
}

bayes_data <- afd_projection %>%
  select(doc_id, classe, label, all_of(ld_cols)) %>%
  mutate(label = as.integer(label))

set.seed(4209)
bayes_data <- bayes_data %>%
  group_by(classe) %>%
  slice_sample(prop = 1) %>%
  mutate(split = ifelse(row_number() <= floor(0.8 * n()), "train", "test")) %>%
  ungroup()

train_df <- bayes_data %>% filter(split == "train")
test_df <- bayes_data %>% filter(split == "test")

knitr::kable(
  bayes_data %>%
    count(split, classe) %>%
    group_by(split) %>%
    mutate(proportion = scales::percent(n / sum(n), accuracy = 0.1))
)
```

## Classifieur bayésien gaussien

Le code estime, pour chaque classe, les parametres gaussiens par variable (`mu`, `sigma^2`) puis applique la regle de Bayes pour obtenir des posteriori.

```{r bayes-model-utils}
safe_auc <- function(y_true_bin, prob) {
  if (length(unique(y_true_bin)) < 2 || length(unique(prob)) < 2) {
    return(NA_real_)
  }
  as.numeric(pROC::auc(response = y_true_bin, predictor = prob, quiet = TRUE))
}

calc_binary_metrics <- function(y_true, prob_ia, threshold = 0.5) {
  y_true <- factor(y_true, levels = c("Humain", "IA"))
  y_bin <- ifelse(y_true == "IA", 1, 0)

  pred <- ifelse(prob_ia >= threshold, "IA", "Humain")
  pred <- factor(pred, levels = c("Humain", "IA"))

  tp <- sum(pred == "IA" & y_true == "IA")
  fp <- sum(pred == "IA" & y_true == "Humain")
  fn <- sum(pred == "Humain" & y_true == "IA")
  tn <- sum(pred == "Humain" & y_true == "Humain")

  precision <- tp / pmax(tp + fp, 1)
  recall <- tp / pmax(tp + fn, 1)
  specificity <- tn / pmax(tn + fp, 1)
  f1 <- if ((precision + recall) == 0) 0 else 2 * precision * recall / (precision + recall)
  acc <- mean(pred == y_true)
  brier <- mean((y_bin - prob_ia)^2)
  auc <- safe_auc(y_bin, prob_ia)

  tibble::tibble(
    accuracy = acc,
    precision = precision,
    recall = recall,
    specificity = specificity,
    f1 = f1,
    roc_auc = auc,
    brier = brier
  ) %>%
    mutate(across(where(is.numeric), ~ round(.x, 4)))
}

fit_gaussian_bayes <- function(df, feature_cols, class_col = "classe", alpha = 1) {
  y <- factor(df[[class_col]], levels = c("Humain", "IA"))
  classes <- levels(y)

  prior_tab <- table(y)
  priors <- (as.numeric(prior_tab) + alpha) / (length(y) + alpha * length(classes))

  params <- lapply(classes, function(cl) {
    x <- as.matrix(df[y == cl, feature_cols, drop = FALSE])
    mu <- colMeans(x)
    sigma2 <- apply(x, 2, var)
    sigma2[!is.finite(sigma2) | sigma2 < 1e-8] <- 1e-8
    list(mu = mu, sigma2 = sigma2)
  })
  names(params) <- classes

  list(
    classes = classes,
    features = feature_cols,
    priors = priors,
    params = params
  )
}

predict_gaussian_bayes <- function(model, df_new) {
  x <- as.matrix(df_new[, model$features, drop = FALSE])

  log_post <- sapply(seq_along(model$classes), function(i) {
    cl <- model$classes[i]
    p <- model$params[[cl]]
    base::rowSums(stats::dnorm(x, mean = p$mu, sd = sqrt(p$sigma2), log = TRUE)) +
      log(model$priors[i])
  })

  if (!is.matrix(log_post)) {
    log_post <- matrix(log_post, ncol = length(model$classes))
  }
  colnames(log_post) <- model$classes

  row_max <- apply(log_post, 1, max)
  post <- exp(log_post - row_max)
  post <- post / rowSums(post)

  pred_class <- model$classes[max.col(post, ties.method = "first")]
  prob_ia <- post[, "IA"]

  list(
    class = factor(pred_class, levels = model$classes),
    prob_ia = as.numeric(prob_ia),
    posterior = post
  )
}
```

```{r bayes-train-eval}
bayes_model <- fit_gaussian_bayes(train_df, ld_cols)
bayes_pred_test <- predict_gaussian_bayes(bayes_model, test_df)

metrics_holdout <- calc_binary_metrics(
  y_true = test_df$classe,
  prob_ia = bayes_pred_test$prob_ia
) %>%
  mutate(model = "Gaussian Bayes (AFD reduced)") %>%
  relocate(model)

knitr::kable(metrics_holdout)
```

## Validation croisée (5-fold) du modèle bayésien

La validation croisée stratifiée évite de conclure sur un unique split train/test.
Chaque fold conserve la proportion des classes afin de stabiliser l'estimation des performances.

```{r bayes-cv}
set.seed(4209)
k_folds <- 5

cv_data <- bayes_data %>%
  select(classe, all_of(ld_cols)) %>%
  group_by(classe) %>%
  mutate(cv_fold = sample(rep(seq_len(k_folds), length.out = n()))) %>%
  ungroup()

cv_results <- lapply(seq_len(k_folds), function(fold_i) {
  cv_train <- cv_data %>% filter(cv_fold != fold_i)
  cv_valid <- cv_data %>% filter(cv_fold == fold_i)

  cv_model <- fit_gaussian_bayes(cv_train, ld_cols)
  cv_pred <- predict_gaussian_bayes(cv_model, cv_valid)

  calc_binary_metrics(cv_valid$classe, cv_pred$prob_ia) %>%
    mutate(fold = fold_i, .before = 1)
})

cv_results <- dplyr::bind_rows(cv_results)

cv_summary <- cv_results %>%
  summarise(
    across(
      .cols = c(accuracy, precision, recall, specificity, f1, roc_auc, brier),
      .fns = ~ round(mean(.x, na.rm = TRUE), 4)
    )
  ) %>%
  mutate(model = "Gaussian Bayes CV-5") %>%
  relocate(model)

knitr::kable(cv_summary)
```

## Technique bayésienne avancée : MCMC (MCMClogit)

```{r bayes-mcmc}
mcmc_metrics <- NULL
mcmc_posterior_summary <- NULL

if (requireNamespace("MCMCpack", quietly = TRUE)) {
  mcmc_formula <- stats::as.formula(
    paste("label ~", paste(ld_cols, collapse = " + "))
  )

  mcmc_fit <- MCMCpack::MCMClogit(
    formula = mcmc_formula,
    data = train_df,
    burnin = 2000,
    mcmc = 8000,
    thin = 5,
    b0 = 0,
    B0 = 0.01,
    seed = 4209,
    verbose = 0
  )

  draws <- as.matrix(mcmc_fit)
  post_mean <- colMeans(draws)
  x_test <- stats::model.matrix(mcmc_formula, data = test_df)
  prob_mcmc <- stats::plogis(as.numeric(x_test %*% post_mean))

  mcmc_metrics <- calc_binary_metrics(test_df$classe, prob_mcmc) %>%
    mutate(model = "Bayesian Logit (MCMC)") %>%
    relocate(model)

  mcmc_posterior_summary <- tibble::tibble(
    terme = colnames(draws),
    mean = colMeans(draws),
    q025 = apply(draws, 2, stats::quantile, probs = 0.025),
    q975 = apply(draws, 2, stats::quantile, probs = 0.975)
  ) %>%
    mutate(across(where(is.numeric), ~ round(.x, 4)))

  knitr::kable(mcmc_metrics)
  knitr::kable(mcmc_posterior_summary)

  saveRDS(mcmc_fit, "artifacts/bayes_mcmc_model.rds")
} else {
  cat("Package 'MCMCpack' non installe : bloc MCMC saute.")
}
```

## Technique bayésienne avancée : inférence variationnelle (option)

```{r bayes-vi}
vi_metrics <- NULL

if (requireNamespace("rstanarm", quietly = TRUE)) {
  vi_formula <- stats::as.formula(
    paste("label ~", paste(ld_cols, collapse = " + "))
  )

  vi_fit <- rstanarm::stan_glm(
    formula = vi_formula,
    data = train_df,
    family = stats::binomial(link = "logit"),
    algorithm = "meanfield",
    iter = 1500,
    chains = 1,
    seed = 4209,
    refresh = 0
  )

  prob_vi <- as.numeric(stats::predict(vi_fit, newdata = test_df, type = "response"))
  vi_metrics <- calc_binary_metrics(test_df$classe, prob_vi) %>%
    mutate(model = "Bayesian Logit (VI meanfield)") %>%
    relocate(model)

  knitr::kable(vi_metrics)
  saveRDS(vi_fit, "artifacts/bayes_vi_model.rds")
} else {
  cat("Package 'rstanarm' non installe : bloc VI saute.")
}
```

## Sauvegarde des artefacts bayésiens

```{r bayes-save}
saveRDS(bayes_model, "artifacts/bayes_gaussian_model.rds")
saveRDS(metrics_holdout, "artifacts/bayes_holdout_metrics.rds")
saveRDS(cv_results, "artifacts/bayes_cv_fold_metrics.rds")
saveRDS(cv_summary, "artifacts/bayes_cv_summary_metrics.rds")
```

# Évaluation et résultats

L'évaluation est structurée pour répondre au cahier des charges. Les métriques de classification usuelles (accuracy, précision, rappel et F1) sont analysées en parallèle des métriques probabilistes (ROC-AUC et score de Brier). La robustesse est ensuite contrôlée par validation croisée stratifiée k-fold, en version simple puis répétée.

## Mesures de performance sur holdout

```{r eval-holdout-details}
test_pred_class <- ifelse(bayes_pred_test$prob_ia >= 0.5, "IA", "Humain")
test_pred_class <- factor(test_pred_class, levels = c("Humain", "IA"))

conf_matrix <- table(
  Reference = factor(test_df$classe, levels = c("Humain", "IA")),
  Prediction = test_pred_class
)

knitr::kable(as.data.frame.matrix(conf_matrix))
knitr::kable(metrics_holdout)
```

## ROC-AUC et calibration probabiliste

```{r eval-roc-calibration}
y_test_bin <- ifelse(test_df$classe == "IA", 1, 0)

roc_obj <- pROC::roc(
  response = y_test_bin,
  predictor = bayes_pred_test$prob_ia,
  quiet = TRUE
)
auc_holdout <- as.numeric(pROC::auc(roc_obj))

roc_curve_df <- tibble::tibble(
  fpr = 1 - roc_obj$specificities,
  tpr = roc_obj$sensitivities
)

ggplot(roc_curve_df, aes(x = fpr, y = tpr)) +
  geom_path(color = "#1f77b4", linewidth = 1) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(
    title = paste0("Courbe ROC (AUC = ", round(auc_holdout, 4), ")"),
    x = "False Positive Rate",
    y = "True Positive Rate"
  ) +
  theme_minimal(base_size = 12)

calibration_tbl <- tibble::tibble(
  prob_ia = bayes_pred_test$prob_ia,
  y = y_test_bin
) %>%
  mutate(bin = cut(prob_ia, breaks = seq(0, 1, by = 0.1), include.lowest = TRUE)) %>%
  group_by(bin) %>%
  summarise(
    mean_pred = mean(prob_ia),
    obs_rate = mean(y),
    n = n(),
    .groups = "drop"
  ) %>%
  filter(is.finite(mean_pred), is.finite(obs_rate))

ggplot(calibration_tbl, aes(x = mean_pred, y = obs_rate)) +
  geom_point(aes(size = n), color = "#2ca02c", alpha = 0.85) +
  geom_line(color = "#2ca02c") +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed") +
  labs(
    title = "Calibration des probabilites (reliability curve)",
    x = "Probabilite predite moyenne",
    y = "Frequence observee (IA)"
  ) +
  theme_minimal(base_size = 12)

knitr::kable(calibration_tbl)
```

## Validation croisée stratifiée k-fold robuste

```{r eval-repeated-cv}
set.seed(4209)
k_folds_eval <- 5L
n_repeats_eval <- 3L

cv_repeated_results <- lapply(seq_len(n_repeats_eval), function(rep_i) {
  cv_data_rep <- bayes_data %>%
    select(classe, all_of(ld_cols)) %>%
    group_by(classe) %>%
    mutate(cv_fold = sample(rep(seq_len(k_folds_eval), length.out = n()))) %>%
    ungroup()

  fold_metrics <- lapply(seq_len(k_folds_eval), function(fold_i) {
    cv_train <- cv_data_rep %>% filter(cv_fold != fold_i)
    cv_valid <- cv_data_rep %>% filter(cv_fold == fold_i)

    cv_model <- fit_gaussian_bayes(cv_train, ld_cols)
    cv_pred <- predict_gaussian_bayes(cv_model, cv_valid)

    calc_binary_metrics(cv_valid$classe, cv_pred$prob_ia) %>%
      mutate(repeat_id = rep_i, fold = fold_i, .before = 1)
  })

  dplyr::bind_rows(fold_metrics)
}) %>%
  dplyr::bind_rows()

cv_repeated_summary <- cv_repeated_results %>%
  summarise(
    across(
      .cols = c(accuracy, precision, recall, specificity, f1, roc_auc, brier),
      .fns = list(mean = ~ round(mean(.x, na.rm = TRUE), 4), sd = ~ round(sd(.x, na.rm = TRUE), 4)),
      .names = "{.col}_{.fn}"
    )
  ) %>%
  mutate(
    model = paste0("Gaussian Bayes Repeated Stratified ", n_repeats_eval, "x", k_folds_eval),
    .before = 1
  )

knitr::kable(cv_repeated_summary)
```

```{r eval-repeated-cv-plots}
ggplot(cv_repeated_results, aes(x = factor(repeat_id), y = f1)) +
  geom_boxplot(fill = "#ff7f0e", alpha = 0.75) +
  labs(
    title = "Stabilité du F1 sur validation croisée répétée",
    x = "Repetition",
    y = "F1 par fold"
  ) +
  theme_minimal(base_size = 12)

ggplot(cv_repeated_results, aes(x = factor(repeat_id), y = roc_auc)) +
  geom_boxplot(fill = "#1f77b4", alpha = 0.75) +
  labs(
    title = "Stabilité du ROC-AUC sur validation croisée répétée",
    x = "Repetition",
    y = "ROC-AUC par fold"
  ) +
  theme_minimal(base_size = 12)
```

## Synthèse des résultats d'évaluation

```{r eval-summary}
eval_summary_table <- dplyr::bind_rows(
  metrics_holdout %>% mutate(evaluation = "Holdout 80/20"),
  cv_summary %>% mutate(evaluation = "Stratified 5-fold"),
  cv_repeated_results %>%
    summarise(
      accuracy = mean(accuracy, na.rm = TRUE),
      precision = mean(precision, na.rm = TRUE),
      recall = mean(recall, na.rm = TRUE),
      specificity = mean(specificity, na.rm = TRUE),
      f1 = mean(f1, na.rm = TRUE),
      roc_auc = mean(roc_auc, na.rm = TRUE),
      brier = mean(brier, na.rm = TRUE)
    ) %>%
    mutate(
      model = paste0("Gaussian Bayes Repeated ", n_repeats_eval, "x", k_folds_eval),
      evaluation = "Repeated stratified k-fold"
    )
) %>%
  select(evaluation, model, accuracy, precision, recall, specificity, f1, roc_auc, brier) %>%
  mutate(across(where(is.numeric), ~ round(.x, 4)))

if (!is.null(mcmc_metrics)) {
  eval_summary_table <- dplyr::bind_rows(
    eval_summary_table,
    mcmc_metrics %>%
      mutate(evaluation = "Holdout 80/20 (advanced)") %>%
      select(evaluation, model, accuracy, precision, recall, specificity, f1, roc_auc, brier)
  )
}

if (!is.null(vi_metrics)) {
  eval_summary_table <- dplyr::bind_rows(
    eval_summary_table,
    vi_metrics %>%
      mutate(evaluation = "Holdout 80/20 (advanced)") %>%
      select(evaluation, model, accuracy, precision, recall, specificity, f1, roc_auc, brier)
  )
}

knitr::kable(eval_summary_table)
```

## Sauvegarde des artefacts d'évaluation

```{r eval-save}
saveRDS(conf_matrix, "artifacts/eval_confusion_matrix_holdout.rds")
saveRDS(roc_curve_df, "artifacts/eval_roc_curve_holdout.rds")
saveRDS(calibration_tbl, "artifacts/eval_calibration_holdout.rds")
saveRDS(cv_repeated_results, "artifacts/eval_repeated_cv_metrics.rds")
saveRDS(cv_repeated_summary, "artifacts/eval_repeated_cv_summary.rds")
saveRDS(eval_summary_table, "artifacts/eval_summary_table.rds")
```

# Conclusion

## Principales constatations

L'approche retenue repose sur un pipeline en cinq blocs articulés de façon progressive : harmonisation des données multi-sources, EDA et vérification de qualité, extraction de caractéristiques linguistiques et stylométriques couplée à TF-IDF et aux topics, réduction dimensionnelle par AFD après SVD, puis classification bayésienne avec évaluation probabiliste.

Cette architecture fournit un bon compromis entre performance et interprétabilité. Les axes discriminants `LD*` restent lisibles, les probabilités sont bien calibrées (Brier faible), et la stabilité observée en validation croisée stratifiée confirme la cohérence de la démarche.

## Résultats clés

```{r report-key-results}
key_results <- eval_summary_table %>%
  filter(evaluation %in% c("Holdout 80/20", "Repeated stratified k-fold")) %>%
  mutate(across(where(is.numeric), ~ round(.x, 4)))

knitr::kable(key_results)
```

Les résultats montrent que le modèle bayésien sur espace réduit AFD atteint un ROC-AUC proche de 0.9985, avec un score de Brier autour de 0.007, ce qui indique une excellente capacité de discrimination ainsi qu'une bonne qualité probabiliste. La proximité des performances entre holdout et validation croisée répétée confirme que ces résultats ne reposent pas sur un seul découpage favorable des données.

## Défis rencontrés et limites

```{r report-challenges}
challenges_tbl <- tibble::tibble(
  defis = c(
    "Hétérogénéité des schémas entre fichiers",
    "Dimension très élevée de TF-IDF",
    "Risque de singularité pour l'AFD",
    "Évaluation potentiellement instable sur un seul split",
    "Disponibilité partielle des packages bayésiens avancés"
  ),
  impacts = c(
    "Colonnes manquantes ou types différents selon les sources",
    "Coût mémoire/temps et risque de sur-ajustement",
    "Instabilité numérique pour les matrices de covariance",
    "Performance surestimée ou sous-estimée selon le split",
    "MCMC/VI non exécutables dans tous les environnements"
  ),
  reponses = c(
    "Harmonisation explicite des colonnes et nettoyage contrôlé",
    "Trim des n-grammes + réduction SVD (LSA) avant modélisation",
    "AFD appliquée sur espace réduit et standardisé",
    "Validation croisée stratifiée k-fold puis répétée (3x5)",
    "Blocs optionnels robustes avec fallback explicite"
  )
)

knitr::kable(challenges_tbl)
```

Les métriques présentées sont obtenues sur un sous-ensemble de travail, choix imposé par les contraintes de calcul. La variante noyau (KPCA/LDA) est bien implémentée mais n'a pas encore fait l'objet d'une optimisation complète d'hyperparamètres. Enfin, les extensions MCMC et inférence variationnelle sont prêtes dans le code, mais leur exécution dépend des bibliothèques disponibles dans l'environnement local.

# Travaux futurs

Les prolongements les plus utiles concernent d'abord la recherche systématique d'hyperparamètres, notamment le rang SVD, les seuils de trim TF-IDF et les choix de régularisation bayésienne. Une deuxième priorité consiste à renforcer la calibration post-modèle, par exemple avec Platt scaling ou isotonic regression. Il sera également pertinent de comparer, sur le même espace AFD, d'autres modèles probabilistes comme une régression logistique bayésienne complète, une QDA bayésienne et des ensembles calibrés. Enfin, une comparaison formelle MCMC versus inférence variationnelle, ainsi que des validations par prompts ou par découpage temporel, permettraient de mieux quantifier la robustesse en présence de dérive de domaine.
