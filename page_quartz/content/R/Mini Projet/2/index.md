---
title: "MiniProjet 2"
output:
  html_document:
    theme: readable
    highlight: textmate
    toc: true
    toc_depth: 3
    toc_float: true
    number_sections: true
    df_print: paged
---

<style type="text/css">
body { font-size: 15px; line-height: 1.65; }
h1, h2, h3 { color: #0d4f8b; }
pre, code { font-size: 12px; }
.cover-box {
  border-top: 2px solid #aab7c4;
  border-bottom: 2px solid #aab7c4;
  padding: 12px 4px 8px 4px;
  margin-bottom: 16px;
}
.note-box {
  background: #f5f8fb;
  border-left: 4px solid #0d4f8b;
  padding: 10px 12px;
  margin: 8px 0 14px 0;
}
</style>
# Analyse factorielle discriminante (AFD) sur tweets
```r
knitr::opts_chunk$set(
  echo = TRUE,
  warning = FALSE,
  message = FALSE,
  fig.align = "center",
  fig.width = 8,
  fig.height = 5
)

required_packages <- c(
  "dplyr", "readr", "stringr", "tidyr", "tibble", "tidytext",
  "Matrix", "MASS", "ggplot2", "cluster", "topicmodels", "broom"
)

missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages) > 0) {
  install.packages(missing_packages, repos = "https://cloud.r-project.org")
}

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(stringr)
  library(tidyr)
  library(tibble)
  library(tidytext)
  library(Matrix)
  library(MASS)
  library(ggplot2)
  library(cluster)
  library(topicmodels)
})

theme_set(theme_minimal(base_size = 12))
set.seed(42)
```

<div class="cover-box">
<strong>Fouille de données avec R - Projet 2</strong><br/>
Twitter Entity Sentiment Analysis (Kaggle)<br/>
Objectif: appliquer une AFD/LDA pour analyser et visualiser la séparation des sentiments.
</div>

# Introduction

Ce rapport présente une démarche complète de classification de sentiments à partir de tweets.
Le contexte est celui du jeu de données **Twitter Entity Sentiment Analysis**, dans lequel
chaque tweet est associé à une entité et à une étiquette de sentiment.

Le fil directeur du travail consiste à transformer le texte brut en variables
quantitatives exploitables, puis à appliquer l'AFD (via `MASS::lda`) afin de séparer
les classes de sentiment. Les tweets sont ensuite projetés dans un espace de dimension
réduite pour interpréter la structure des groupes, et cette projection est complétée
par des métriques permettant d'évaluer à la fois la classification et la qualité
d'agrégation.

L'enjeu n'est pas seulement d'obtenir des scores, mais de documenter clairement la
**dynamique méthode -> code -> résultat -> interprétation**.

# Méthodologie

La méthodologie est organisée en cinq étapes: paramétrage, chargement des données,
prétraitement du texte, extraction TF-IDF, puis encodage de la variable cible.

D'un point de vue technique, cette décomposition permet de séparer proprement les
responsabilités du pipeline et d'éviter les erreurs de fuite d'information entre train
et validation. D'un point de vue pédagogique, elle rend la démarche lisible et
reproductible: chaque étape transforme les données d'une façon explicable.

## Paramètres et fonctions utilitaires

Le bloc suivant regroupe l'ensemble des briques techniques de base: les hyperparamètres
principaux (`max_train_docs`, `top_terms`, `validation_ratio`), les fonctions de
nettoyage et de tokenisation, la construction de la représentation TF-IDF, ainsi que
les fonctions utilitaires qui rendent le chargement des fichiers CSV plus robuste.

Le choix de fonctions modularisées facilite la vérification scientifique du travail:
on peut tester chaque transformation isolément, puis valider l'effet cumulé sur les
métriques finales.

```r
max_train_docs <- 12000L
top_terms <- 350L
validation_ratio <- 0.20
topic_top_terms <- 10L

col_names <- c("tweet_id", "entity", "sentiment", "tweet")

find_dataset_file <- function(base_dirs, expected_name) {
  for (base_dir in base_dirs) {
    direct <- file.path(base_dir, expected_name)
    if (file.exists(direct) && !dir.exists(direct)) {
      return(normalizePath(direct, winslash = "/", mustWork = FALSE))
    }
    if (!dir.exists(base_dir)) next
    matches <- list.files(
      path = base_dir,
      pattern = paste0("^", expected_name, "$"),
      recursive = TRUE,
      full.names = TRUE,
      ignore.case = TRUE
    )
    matches <- matches[!dir.exists(matches)]
    if (length(matches) > 0) {
      return(normalizePath(matches[[1]], winslash = "/", mustWork = FALSE))
    }
  }
  NULL
}

read_dataset <- function(path) {
  readr::read_csv(
    file = path,
    col_names = col_names,
    show_col_types = FALSE,
    na = c("", "NA")
  ) %>%
    mutate(
      tweet = coalesce(tweet, ""),
      sentiment = coalesce(sentiment, "Unknown")
    ) %>%
    filter(tweet != "")
}

clean_text <- function(text) {
  text %>%
    tolower() %>%
    str_replace_all("http[s]?://\\S+|www\\.\\S+", " ") %>%
    str_replace_all("@\\w+", " ") %>%
    str_replace_all("#\\w+", " ") %>%
    str_replace_all("[^a-z\\s]", " ") %>%
    str_squish()
}

prepare_dataset <- function(df) {
  df %>%
    mutate(clean_text = clean_text(tweet)) %>%
    filter(clean_text != "") %>%
    mutate(doc_id = row_number())
}

split_train_validation <- function(df, ratio = 0.20, seed = 42L) {
  set.seed(seed)
  valid_df <- df %>%
    group_by(sentiment) %>%
    group_modify(~ {
      n_class <- nrow(.x)
      if (n_class <= 1) return(.x[0, , drop = FALSE])
      n_valid <- max(1L, floor(n_class * ratio))
      n_valid <- min(n_valid, n_class - 1L)
      slice_sample(.x, n = n_valid)
    }) %>%
    ungroup()

  train_df <- df %>%
    anti_join(valid_df %>% dplyr::select(doc_id), by = "doc_id")

  list(train = train_df, valid = valid_df)
}

tokenize_dataset <- function(df, stop_words_vec) {
  df %>%
    dplyr::select(doc_id, clean_text) %>%
    tidytext::unnest_tokens(term, clean_text) %>%
    filter(
      nchar(term) >= 3,
      str_detect(term, "^[a-z]+$"),
      !term %in% stop_words_vec
    )
}

build_train_tfidf <- function(df, top_n, stop_words_vec) {
  tokens <- tokenize_dataset(df, stop_words_vec)
  if (nrow(tokens) == 0) stop("No valid tokens found after preprocessing.")

  counts <- tokens %>%
    count(doc_id, term, name = "tf")

  vocab <- counts %>%
    count(term, wt = tf, sort = TRUE, name = "global_tf") %>%
    slice_head(n = top_n) %>%
    pull(term)

  counts <- counts %>% filter(term %in% vocab)

  doc_freq <- counts %>%
    distinct(doc_id, term) %>%
    count(term, name = "doc_freq")

  idf_map <- doc_freq %>%
    mutate(idf = log((nrow(df) + 1) / (doc_freq + 1)) + 1) %>%
    dplyr::select(term, idf)

  tfidf <- counts %>%
    left_join(idf_map, by = "term") %>%
    mutate(weight = tf * idf)

  row_idx <- match(tfidf$doc_id, df$doc_id)
  col_idx <- match(tfidf$term, vocab)

  mat <- Matrix::sparseMatrix(
    i = row_idx,
    j = col_idx,
    x = tfidf$weight,
    dims = c(nrow(df), length(vocab)),
    dimnames = list(as.character(df$doc_id), vocab)
  )

  list(matrix = mat, vocab = vocab, idf_map = idf_map, tokens = tokens)
}

build_tfidf_from_vocab <- function(df, vocab, idf_map, stop_words_vec) {
  tokens <- tokenize_dataset(df, stop_words_vec)
  if (nrow(tokens) == 0) {
    return(Matrix::Matrix(
      0,
      nrow = nrow(df),
      ncol = length(vocab),
      sparse = TRUE,
      dimnames = list(as.character(df$doc_id), vocab)
    ))
  }

  counts <- tokens %>%
    count(doc_id, term, name = "tf") %>%
    filter(term %in% vocab)

  if (nrow(counts) == 0) {
    return(Matrix::Matrix(
      0,
      nrow = nrow(df),
      ncol = length(vocab),
      sparse = TRUE,
      dimnames = list(as.character(df$doc_id), vocab)
    ))
  }

  tfidf <- counts %>%
    left_join(idf_map, by = "term") %>%
    mutate(
      idf = ifelse(is.na(idf), 0, idf),
      weight = tf * idf
    )

  row_idx <- match(tfidf$doc_id, df$doc_id)
  col_idx <- match(tfidf$term, vocab)

  Matrix::sparseMatrix(
    i = row_idx,
    j = col_idx,
    x = tfidf$weight,
    dims = c(nrow(df), length(vocab)),
    dimnames = list(as.character(df$doc_id), vocab)
  )
}

sample_training_data <- function(df, max_docs) {
  if (nrow(df) <= max_docs) return(df)
  sampled <- df %>%
    group_by(sentiment) %>%
    slice_sample(prop = max_docs / nrow(df)) %>%
    ungroup()
  if (nrow(sampled) > max_docs) sampled <- sampled %>% slice_sample(n = max_docs)
  sampled
}
```

## Chargement des données

La logique de chargement est volontairement robuste. Le script cherche automatiquement
`twitter_training.csv` et `twitter_validation.csv` dans les repertoires candidats.
Si le fichier de validation est absent, un split interne stratifié est applique.
Enfin, les niveaux de classes sont harmonises entre train et validation pour garantir
la cohérence de la phase d'apprentissage supervisé.

Le point important pour le prof est le suivant: la stratification conserve la structure
relative des classes, ce qui limite les biais d'évaluation. Pour un non expert, cela
revient à dire qu'on évite de comparer le modèle sur un jeu de test qui n'aurait pas
la même "proportion de sentiments" que les données d'entraînement.

```r
report_path <- tryCatch(knitr::current_input(dir = TRUE), error = function(e) "")
report_dir <- if (nzchar(report_path)) dirname(report_path) else getwd()
candidate_roots <- unique(c(
  normalizePath(getwd(), winslash = "/", mustWork = FALSE),
  normalizePath(report_dir, winslash = "/", mustWork = FALSE),
  normalizePath(file.path(report_dir, ".."), winslash = "/", mustWork = FALSE)
))
candidate_data_dirs <- unique(file.path(candidate_roots, "data"))

train_path <- find_dataset_file(candidate_data_dirs, "twitter_training.csv")
valid_path <- find_dataset_file(candidate_data_dirs, "twitter_validation.csv")

if (is.null(train_path)) {
  stop(
    "twitter_training.csv not found.\n",
    "Expected in one of:\n - ", paste(candidate_data_dirs, collapse = "\n - ")
  )
}

if (is.null(valid_path)) {
  all_data <- read_dataset(train_path) %>% prepare_dataset()
  split_sets <- split_train_validation(all_data, ratio = validation_ratio, seed = 42L)
  train_df <- split_sets$train
  valid_df <- split_sets$valid
  split_mode <- "Split interne stratifié (80/20) depuis twitter_training.csv"
} else {
  train_df <- read_dataset(train_path) %>% prepare_dataset()
  valid_df <- read_dataset(valid_path) %>% prepare_dataset()
  split_mode <- "Split officiel Kaggle (training + validation)"
}

all_levels <- sort(unique(c(as.character(train_df$sentiment), as.character(valid_df$sentiment))))
train_df <- train_df %>% mutate(sentiment = factor(sentiment, levels = all_levels))
valid_df <- valid_df %>% mutate(sentiment = factor(sentiment, levels = all_levels))

train_model <- sample_training_data(train_df, max_train_docs) %>%
  mutate(sentiment = droplevels(sentiment))
valid_df <- valid_df %>%
  filter(sentiment %in% levels(train_model$sentiment)) %>%
  mutate(sentiment = factor(sentiment, levels = levels(train_model$sentiment)))

if (n_distinct(train_model$sentiment) < 2) stop("Less than 2 sentiment classes in training set.")
if (nrow(valid_df) == 0) stop("Validation set is empty after filtering levels.")
if (any(table(train_model$sentiment) < 2)) stop("At least one class has less than 2 training samples.")

dataset_overview <- tibble(
  split = c("Training", "Validation"),
  n_tweets = c(nrow(train_model), nrow(valid_df)),
  n_classes = c(n_distinct(train_model$sentiment), n_distinct(valid_df$sentiment))
)
knitr::kable(dataset_overview)
```

Mode de séparation utilisé: <strong>`r split_mode`</strong>


## Prétraitement détaillé

Le nettoyage est conçu pour réduire le bruit sans détruire l'information lexicale utile
à la discrimination des classes.

Concrètement, le pipeline commence par une normalisation de la casse (`tolower`), puis
supprime URLs, mentions, hashtags et caractères non alphabétiques. Le texte propre est
ensuite tokenisé mot par mot, et seuls les tokens pertinents sont conservés grâce au
filtrage des stop words et des termes trop courts.

Techniquement, ce choix diminue la variance inutile introduite par le bruit typographique.
Pédagogiquement, on peut l'interpréter comme une standardisation: deux tweets qui disent
la même chose avec des formes d'écriture différentes deviennent comparables.

```r
clean_preview <- train_model %>%
  dplyr::select(tweet, clean_text) %>%
  slice_head(n = min(5, nrow(train_model)))
knitr::kable(clean_preview)
```

```r
clean_step_demo <- train_model %>%
  dplyr::select(tweet) %>%
  slice_head(n = min(3, nrow(train_model))) %>%
  mutate(
    lower = tolower(tweet),
    no_url = str_replace_all(lower, "http[s]?://\\S+|www\\.\\S+", " "),
    no_mentions = str_replace_all(no_url, "@\\w+", " "),
    no_hashtags = str_replace_all(no_mentions, "#\\w+", " "),
    alpha_only = str_replace_all(no_hashtags, "[^a-z\\s]", " "),
    clean_text = str_squish(alpha_only)
  )
knitr::kable(clean_step_demo)
```

## Extraction des caractéristiques (TF-IDF)

L'idée est de représenter chaque tweet par un vecteur numérique TF-IDF. La composante
TF mesure la fréquence d'un terme dans un tweet, tandis que la composante IDF réduit le
poids des termes trop communs dans l'ensemble du corpus. Cette représentation favorise
les mots les plus informatifs pour la discrimination des sentiments.

Dans le vocabulaire du cours, cette étape remplace l'espace textuel brut par un espace
euclidien exploitable par les modèles linéaires. Pour quelqu'un de non expert, TF-IDF
attribue simplement plus d'importance aux mots spécifiques et moins aux mots banals.

```r
stop_words_vec <- unique(tidytext::stop_words$word)

train_tfidf <- build_train_tfidf(train_model, top_terms, stop_words_vec)
valid_tfidf <- build_tfidf_from_vocab(valid_df, train_tfidf$vocab, train_tfidf$idf_map, stop_words_vec)

x_train <- as.matrix(train_tfidf$matrix)
keep_cols <- apply(x_train, 2, function(v) stats::var(v) > 0)
if (!any(keep_cols)) stop("All TF-IDF features have zero variance.")

x_train <- x_train[, keep_cols, drop = FALSE]
x_valid <- as.matrix(valid_tfidf[, keep_cols, drop = FALSE])

tfidf_summary <- tibble(
  item = c("Documents train", "Documents validation", "Features TF-IDF retenues"),
  value = c(nrow(x_train), nrow(x_valid), ncol(x_train))
)
knitr::kable(tfidf_summary)
```

## Conversion des étiquettes de sentiment pour l'AFD

`MASS::lda` attend une variable de groupe de type `factor`. Pour respecter cette
contrainte, les niveaux de `sentiment` sont d'abord harmonises entre train et
validation, puis les niveaux non presents dans le train final sont elimines avant de
realigner explicitement la validation sur les niveaux du modèle appris.

Ce détail est technique mais crucial: un encodage incohérent des classes peut fausser
la prédiction et la matrice de confusion. En version simple: on s'assure que le modèle
et les données parlent exactement le même "langage de classes".

```r
sentiment_mapping <- tibble(
  sentiment = levels(train_model$sentiment),
  sentiment_code = seq_along(levels(train_model$sentiment))
)
knitr::kable(sentiment_mapping)
```

```r
numeric_encoding_preview <- train_model %>%
  dplyr::select(doc_id, sentiment) %>%
  mutate(sentiment_code = as.integer(sentiment)) %>%
  slice_head(n = min(10, nrow(train_model)))
knitr::kable(numeric_encoding_preview)
```

# Implémentation de l'AFD

L'AFD (LDA) calcule des axes qui maximisent la séparation entre classes.
Le principe de decision est donne par:

\[
\delta_k(x) = x^\top \Sigma^{-1}\mu_k - \frac{1}{2}\mu_k^\top \Sigma^{-1}\mu_k + \log(\pi_k)
\]

La dimension maximale de l'espace discriminant est \(\min(p, K-1)\), ou \(p\) est
le nombre de variables TF-IDF et \(K\) le nombre de classes de sentiment.

Sur le plan mathématique, on cherche des combinaisons linéaires des variables qui
augmentent la dispersion inter-classes tout en reduisant la dispersion intra-classe.
Sur le plan intuitif, on construit une nouvelle vue des données ou les tweets de même
sentiment sont, autant que possible, rapproches les uns des autres.

```r
class_priors <- prop.table(table(train_model$sentiment))

lda_model <- MASS::lda(
  x = x_train,
  grouping = train_model$sentiment,
  prior = as.numeric(class_priors)
)

pred_train <- predict(lda_model, x_train)
pred_valid <- predict(lda_model, x_valid)

train_accuracy <- mean(pred_train$class == train_model$sentiment)
valid_accuracy <- mean(pred_valid$class == valid_df$sentiment)

projection_df <- tibble(
  doc_id = train_model$doc_id,
  sentiment = train_model$sentiment,
  LD1 = as.numeric(pred_train$x[, 1]),
  LD2 = if (ncol(pred_train$x) >= 2) as.numeric(pred_train$x[, 2]) else 0
)

confusion_tbl <- as.data.frame.matrix(table(
  Actual = valid_df$sentiment,
  Predicted = pred_valid$class
))
confusion_tbl <- tibble::rownames_to_column(confusion_tbl, var = "Actual")
```

## Espace discriminant obtenu

Le tableau suivant met en relation la dimension theorique maximale autorisee par l'AFD,
la dimension effectivement obtenue sur les données, ainsi que l'importance relative de
chaque axe discriminant.

Cette lecture est importante dans un rendu technique: elle montre que la projection
n'est pas arbitraire mais contrainte par la théorie (nombre de classes) et par la
structure empirique des données.

```r
n_classes <- nlevels(train_model$sentiment)
n_features <- ncol(x_train)
n_axes_max <- min(n_features, n_classes - 1L)
n_axes_obtained <- ncol(pred_train$x)

eig <- lda_model$svd^2
axis_summary <- tibble(
  axis = paste0("LD", seq_along(eig)),
  singular_value = lda_model$svd,
  relative_discrimination = eig / sum(eig)
)

afd_summary <- tibble(
  item = c(
    "Nombre de classes (K)",
    "Nombre de variables TF-IDF (p)",
    "Nombre max d'axes min(p, K-1)",
    "Nombre d'axes obtenus",
    "Projection utilisée dans la figure"
  ),
  value = c(n_classes, n_features, n_axes_max, n_axes_obtained, "2D (LD1, LD2)")
)

knitr::kable(afd_summary)
knitr::kable(axis_summary, digits = 4)
```

## Facteurs discriminants (coefficients)

Les coefficients de `lda_model$scaling` indiquent quels termes poussent la séparation
des classes sur chaque axe.

Interpretes pédagogiquement, ces coefficients sont des "poids directionnels": un poids
positif fort sur LD1 pousse un tweet vers un côté de l'axe, un poids negatif fort le
pousse vers l'autre côté.

```r
lda_scaling <- as.data.frame(lda_model$scaling) %>%
  tibble::rownames_to_column(var = "term")

if ("LD1" %in% colnames(lda_scaling)) {
  top_ld1_terms <- lda_scaling %>%
    mutate(abs_ld1 = abs(LD1)) %>%
    slice_max(order_by = abs_ld1, n = 15) %>%
    arrange(abs_ld1)

  ggplot(top_ld1_terms, aes(x = reorder(term, abs_ld1), y = LD1, fill = LD1 > 0)) +
    geom_col(show.legend = FALSE) +
    labs(
      title = "Top termes contributeurs au facteur discriminant LD1",
      x = "Terme",
      y = "Coefficient LD1"
    ) +
    coord_flip()
}
```

# Résultats

Cette section rassemble les sorties directement exploitables pour évaluer la performance
du modèle et la qualité de la projection.

Pour rester à la fois rigoureux et lisible, les résultats sont analysés sur deux plans
complémentaires: la performance predictive (classification) et la structure géométrique
de l'espace projeté (visualisation et silhouette).

## Métriques de classification

```r
silhouette_score <- NA_real_

if (n_distinct(projection_df$sentiment) > 1 && nrow(projection_df) >= 4) {
  idx <- sample(seq_len(nrow(projection_df)), size = min(1500, nrow(projection_df)))
  coords <- scale(projection_df[idx, c("LD1", "LD2"), drop = FALSE])
  diss <- dist(coords)
  sil <- cluster::silhouette(as.integer(projection_df$sentiment[idx]), diss)
  silhouette_score <- mean(sil[, "sil_width"])
}

metrics_tbl <- tibble(
  metric = c(
    "train_accuracy",
    "validation_accuracy",
    "silhouette_score",
    "n_train_docs",
    "n_validation_docs",
    "n_features"
  ),
  value = c(
    train_accuracy,
    valid_accuracy,
    silhouette_score,
    nrow(train_model),
    nrow(valid_df),
    ncol(x_train)
  )
)

knitr::kable(metrics_tbl, digits = 4)
```

La `validation_accuracy` mesure directement la performance de classification supervisée.
Le `silhouette_score`, calculé dans l'espace projeté (LD1, LD2), renseigne quant à lui
la qualité de séparation géométrique des groupes de tweets.

Autrement dit, l'accuracy répond à la question "combien de tweets sont bien classés?",
alors que la silhouette répond à la question "les groupes forment-ils des amas nets
dans l'espace réduit?".

## Matrice de confusion

```r
confusion_long <- confusion_tbl %>%
  pivot_longer(cols = -Actual, names_to = "Predicted", values_to = "n")

ggplot(confusion_long, aes(x = Predicted, y = Actual, fill = n)) +
  geom_tile() +
  geom_text(aes(label = n), size = 3) +
  scale_fill_gradient(low = "#f2f2f2", high = "#1f77b4") +
  labs(
    title = "Matrice de confusion",
    x = "Classe predite",
    y = "Classe reelle",
    fill = "Effectif"
  )
```

## Visualisation des facteurs discriminants (projection AFD)

```r
ggplot(projection_df, aes(x = LD1, y = LD2, color = sentiment)) +
  geom_point(alpha = 0.5, size = 1.1) +
  labs(
    title = "Projection des tweets dans l'espace discriminant",
    subtitle = "AFD/LDA sur caractéristiques TF-IDF",
    x = "LD1",
    y = "LD2",
    color = "Sentiment"
  )
```

Ce graphique permet d'observer visuellement le regroupement (ou le chevauchement)
des classes de sentiment dans l'espace réduit.

Ce point est didactiquement essentiel: un modèle peut avoir une accuracy acceptable tout
en gardant des zones de chevauchement importantes, ce que seule la projection permet de
voir clairement.

## Visualisation des sujets

Pour compléter la lecture discriminante, on ajoute une vue thématique non supervisée
(LDA topic model) afin de visualiser les termes dominants par sujet.

Note de clarification importante: ici, `topicmodels::LDA` désigne le modèle de sujets
Latent Dirichlet Allocation, différent de la LDA discriminante (`MASS::lda`) utilisée
plus haut pour la classification supervisée.

```r
topic_counts <- train_tfidf$tokens %>%
  count(doc_id, term, name = "n")

topic_plot_ready <- FALSE
if (nrow(topic_counts) > 0) {
  dtm_topics <- tidytext::cast_dtm(topic_counts, doc_id, term, n)
  k_topics <- max(2L, min(6L, n_distinct(train_model$sentiment)))

  topic_model <- topicmodels::LDA(dtm_topics, k = k_topics, control = list(seed = 42))
  topic_terms <- broom::tidy(topic_model, matrix = "beta")

  top_topic_terms <- topic_terms %>%
    group_by(topic) %>%
    slice_max(order_by = beta, n = topic_top_terms, with_ties = FALSE) %>%
    ungroup() %>%
    mutate(term = tidytext::reorder_within(term, beta, topic))

  topic_plot_ready <- TRUE
}

if (topic_plot_ready) {
  ggplot(top_topic_terms, aes(x = term, y = beta, fill = factor(topic))) +
    geom_col(show.legend = FALSE) +
    tidytext::scale_x_reordered() +
    coord_flip() +
    facet_wrap(~ topic, scales = "free") +
    labs(
      title = "Top termes par sujet (LDA non supervisée)",
      x = "Terme",
      y = "Poids du terme (beta)"
    )
} else {
  cat("Visualisation des sujets indisponible (données insuffisantes).")
}
```

# Discussion & Conclusion

Le modèle obtient une **validation accuracy** de `r round(valid_accuracy, 4)` et un
**silhouette score** de `r round(silhouette_score, 4)`.

Ces deux indicateurs racontent une histoire coherente. D'un côté, la classification
apprend un signal exploitable mais imparfait; de l'autre, la projection 2D conserve
une partie de la structure avec un chevauchement non négligeable entre classes proches
lexicalement. Les coefficients discriminants et la visualisation des sujets apportent
alors une lecture sémantique complémentaire des décisions du modèle.

En synthèse, l'AFD/LDA fournit une base interprétable pour l'analyse de sentiment, mais
la complexité linguistique des tweets limite la séparabilité linéaire stricte.

Cette conclusion est techniquement conforme au cours: l'AFD est performante lorsque les
frontières entre classes sont bien approximées par des séparations linéaires dans
l'espace des variables. Or, les tweets contiennent ironie, contexte implicite et bruit,
ce qui introduit naturellement des recouvrements.

# Travaux futurs

Les résultats obtenus montrent que le modèle capte un signal de sentiment, mais que la
séparation reste partielle dans l'espace discriminant. La suite du travail peut donc se
concentrer sur trois leviers complémentaires.

Le premier levier est la représentation du texte. Dans ce projet, nous avons utilisé une
représentation TF-IDF classique, efficace mais limitée pour des messages courts et
bruités comme les tweets. Une amélioration naturelle consiste à enrichir les variables
avec des n-grams, une gestion explicite de la négation, ainsi qu'une meilleure prise en
compte des emojis et des hashtags, qui portent souvent l'information de sentiment.

Le deuxième levier est le modèle de classification. L'AFD/LDA apporte une lecture
interprétable et reliée au cours, mais elle repose sur une séparation linéaire. Il sera
pertinent de comparer cette base à des modèles supervisés alternatifs (regr. logistique,
SVM, Random Forest, XGBoost) en conservant le même protocole d'évaluation pour une
comparaison juste.

Le troisième levier est l'évaluation. Au-delà de l'accuracy globale, il est utile
d'ajouter une validation croisée stratifiée, des métriques par classe (précision, rappel,
F1) et une analyse d'erreurs par entité. Cette étape permet d'identifier les cas de
confusion récurrente et de guider les choix de prétraitement ou de modélisation.

Enfin, une extension plus avancée consistera à tester des embeddings contextuels
(ex. BERT multilingue), afin de mieux capter le sens contextuel des tweets lorsque la
séparation linéaire devient insuffisante.

# Annexes {-}

## Reproductibilité

```r
report_path_safe <- if (exists("report_path") && nzchar(report_path)) {
  report_path
} else {
  normalizePath(getwd(), winslash = "/", mustWork = FALSE)
}

report_dir_abs <- normalizePath(dirname(report_path_safe), winslash = "/", mustWork = FALSE)
project_root <- if (basename(report_dir_abs) %in% c("rapport", "report")) {
  normalizePath(file.path(report_dir_abs, ".."), winslash = "/", mustWork = FALSE)
} else {
  report_dir_abs
}

output_dir <- file.path(project_root, "outputs")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

readr::write_csv(metrics_tbl, file.path(output_dir, "metrics.csv"))
readr::write_csv(confusion_tbl, file.path(output_dir, "confusion_matrix.csv"))
readr::write_csv(projection_df, file.path(output_dir, "train_projection.csv"))
```

```r
sessionInfo()
```
