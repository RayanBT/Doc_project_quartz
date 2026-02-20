---
title: "MiniProjet 1"
output:
  html_document:
    highlight: textmate
    theme: readable
    toc: yes
    toc_depth: 6
    toc_float: yes
---


<style type="text/css">
body, td {font-size: 15px;}
code.r{font-size: 5px;}
pre { font-size: 12px;}
</style>
# Classification bayésienne
```r
knitr::opts_chunk$set(echo = TRUE)
```

<FONT color='#0066CC'><FONT size = 4 >


**Fouille de données avec R pour la data science et l'intelligence artificielle**


</FONT></FONT>

<hr style="border: 1px  solid gray">

</hr>

<DIV align = justify>

### <FONT color='#0066CC'><FONT size = 5> 1. Introduction </FONT></FONT>

#### <FONT color='#0066CC'><FONT size = 4> 1.1 Objectifs du projet </FONT></FONT>

L'objectif de ce projet est de mettre en place un modèle Naive Bayes capable de prédire des émotions à partir de textes. 
Dans ce rapport, nous appliquons et expliquons le modèle d'apprentissage, puis nous évaluons sa performance. Enfin, nous essayons aussi 
d'apporter des améliorations. Ce travail nous permet de parcourir tout le cycle d'un projet de data science : du nettoyage 
des données brutes jusqu'à l'analyse des résultats via des métriques, dans le langage de programmation R.

<br>

#### <FONT color='#0066CC'><FONT size = 4> 1.2 Description de l'ensemble de données </FONT></FONT>

Les données utilisées dans ce projet proviennent d'un fichier CSV téléchargé de Kaggle, "Emotion Dataset", publié par 
Abdallah Wagih Ibrahim. Le dataset contient deux colonnes principales : "Comment", qui regroupe les phrases, et "Emotion", 
qui leur associe un sentiment (peur, colère ou joie). C'est une base solide pour entraîner des modèles de classification, 
dans le domaine de NLP (Natural Language Processing).

<br>

#### <FONT color='#0066CC'><FONT size = 4> 1.3 Packages utilisés </FONT></FONT>

```r
# Chargement des bibliothèques nécessaires
if (!require("ggplot2")) {
  install.packages("ggplot2", repos = "https://cran.rstudio.com/")
  library(ggplot2)
}
if (!require("knitr")) {
  install.packages("knitr", repos = "https://cran.rstudio.com/")
  library(knitr)
}
if (!require("gridExtra")) {
  install.packages("gridExtra", repos = "https://cran.rstudio.com/")
  library(gridExtra)
}
if (!require("tm")) {
  install.packages("tm", repos = "https://cran.rstudio.com/")
  library(tm)
}
if (!require("SnowballC")) {
  install.packages("SnowballC", repos = "https://cran.rstudio.com/")
  library(SnowballC)
}
if (!require("e1071")) {
  install.packages("e1071", repos = "https://cran.rstudio.com/")
  library(e1071)
}
if (!require("caret")) {
  install.packages("caret", repos = "https://cran.rstudio.com/")
  library(caret)
}
if (!require("textstem")) {
  install.packages("textstem", repos = "https://cran.rstudio.com/")
  library(textstem)
}
```

<br>

<hr style="border: 1px  solid gray">

### <FONT color='#0066CC'><FONT size = 5> 2. Méthodologie </FONT></FONT>

#### <FONT color='#0066CC'><FONT size = 4> 2.1 Chargement et exploration des données </FONT></FONT>

```r
# Chargement des données
data <- read.csv("Emotion_classify_Data.csv", header = TRUE)
kable(head(data, 5))
```


```r
# Aperçu des données
summary(data)
```

Il y a 2 colonnes (Comment et Emotion) et 5937 observations / lignes dans le dataset. Tous de classe 'character'.

```r

# Distribution des classes (émotions)
emotion_table <- table(data$Emotion)
emotion_df <- as.data.frame(emotion_table)
colnames(emotion_df) <- c("Émotion", "Nombre d'observations")
emotion_df$Pourcentage <- round(emotion_df$`Nombre d'observations` / sum(emotion_df$`Nombre d'observations`) * 100, 2)

# Calcul du nombre de mots par Commentaire
data$text_length_words <- sapply(strsplit(data$Comment, " "), length)

# Statistiques descriptives par émotion
emotions <- unique(data$Emotion)
stats_list <- list()

for (emotion in emotions) {
  subset_data <- data[data$Emotion == emotion, ]
  stats_list[[emotion]] <- data.frame(
    Émotion = emotion,
    Minimum = min(subset_data$text_length_words),
    Maximum = max(subset_data$text_length_words),
    Moyenne = round(mean(subset_data$text_length_words), 2),
    Médiane = round(median(subset_data$text_length_words), 2),
    "Écart-type" = round(sd(subset_data$text_length_words), 2),
    check.names = FALSE
  )
}

# Statistiques sur le total
stats_list[["Total"]] <- data.frame(
  Émotion = "Total",
  Minimum = min(data$text_length_words),
  Maximum = max(data$text_length_words),
  Moyenne = round(mean(data$text_length_words), 2),
  Médiane = round(median(data$text_length_words), 2),
  "Écart-type" = round(sd(data$text_length_words), 2),
  check.names = FALSE
)

# Combinaison des statistiques pour l'affichage
stats_combined <- do.call(rbind, stats_list)
rownames(stats_combined) <- NULL
```


```r

# 1. Diagramme circulaire de la distribution des émotions
p1 <- ggplot(emotion_df, aes(x = "", y = `Nombre d'observations`, fill = Émotion)) +
  geom_bar(stat = "identity", width = 1) +
  coord_polar("y", start = 0) +
  geom_text(aes(label = paste0(`Nombre d'observations`, "\n(", Pourcentage, "%)")), 
            position = position_stack(vjust = 0.5),
            size = 4,
            fontface = "bold") +
  labs(title = "Distribution des émotions dans le dataset",
       fill = "Émotions") +
  theme_void() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 12),
        legend.position = "right",
        legend.text = element_text(size = 10))

# 2. Histogramme de la longueur des textes
p2 <- ggplot(data, aes(x = text_length_words)) +
  geom_histogram(bins = 50, fill = "#0066CC", alpha = 0.7, color = "black") +
  labs(title = "Distribution de la longueur des textes",
       x = "Nombre de mots",
       y = "Fréquence") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold"))

# Affichage des graphiques
grid.arrange(p1, p2, ncol = 2)
```

```r
kable(stats_combined, caption = "Statistiques sur la longueur des textes en mots par émotion")
```

**Observations principales :**

- La distribution des classes montre **3 émotions différentes** (colère, peur et joie), qui sont plus ou moins équilibrées
- Les statistiques par émotion montrent peu de différences
- Mais la longueur des phrases varie tout de même, ce qui pourrait influencer la performance du modèle de classification

<br>

#### <FONT color='#0066CC'><FONT size = 4> 2.2 Prétraitement des données </FONT></FONT>

<br>

##### <FONT color='#0066CC'><FONT size = 4> 2.2.1 Nettoyage des données </FONT></FONT>

```r
# Vérification des valeurs manquantes
print(colSums(is.na(data)))
```

Aucune valeur manquante dans les données, nous pouvons donc procéder au nettoyage.

```r
# Fonction de nettoyage de base du texte
basic_text_cleaning <- function(text) {
  # Conversion en minuscules pour uniformiser
  text <- tolower(text)
  # Suppression des chiffres
  text <- gsub("[0-9]+", "", text)
  # Suppression des caractères spéciaux (garder uniquement lettres et espaces)
  text <- gsub("[^a-z ]", " ", text)
  # Normalisation des espaces multiples en un seul espace
  text <- gsub("\\s+", " ", text)
  # Suppression des espaces en début et fin
  trimws(text)
}

# Application du nettoyage de base
data$Comment_clean <- basic_text_cleaning(data$Comment)
```

Nettoyage basique effectué : les textes sont maintenant en minuscules, sans chiffres ni caractères spéciaux, et les 
espaces sont normalisés. Nous allons maintenant appliquer la tokenization et le stemming pour préparer les données pour la classification.

<br>

##### <FONT color='#0066CC'><FONT size = 4> 2.2.2 Tokenization et Stemming </FONT></FONT>

```r
# Fonction de prétraitement : tokenization + stemming
preprocess_text <- function(text_clean) {
  # Chargement des stopwords anglais
  stopwords_en <- stopwords("en")

  # Tokenization + stemming
  # Réduction des mots à leur racine (ex: running -> run)
  result <- sapply(text_clean, function(txt) {
    # Séparation en mots
    words <- unlist(strsplit(txt, " "))
    # Suppression des stopwords
    words_filtered <- words[!words %in% stopwords_en & nchar(words) > 0]

    # Application du stemming
    if(length(words_filtered) > 0) {
      words_stemmed <- wordStem(words_filtered, language = "en")
      paste(words_stemmed, collapse = " ")
    } else {
      ""
    }
  })
  return(result)
}

# Application du prétraitement avec stemming sur le texte nettoyé
data$Comment_stemmed <- preprocess_text(data$Comment_clean)

# Création des tokens pour l'affichage
data$tokens <- lapply(data$Comment_stemmed, function(x) unlist(strsplit(x, " ")))
data$tokens_stemmed <- data$tokens
```

Affichage d'une phrase après chaque étape de prétraitement et analyse du texte avant/après nettoyage et stemming :
```r
# Affichage des exemples de transformation
exemple_output <- sprintf(
  "Comment 1:\n  Original: %s\n  Tokens: %s\n  Stemmed: %s\n",
  data$Comment[1],
  paste(data$tokens[[1]], collapse = ", "),
  data$Comment_stemmed[1]
)
cat(exemple_output)

# Statistiques sur le traitement du texte
stats_output <- sprintf(
  "Analyse post-nettoyage :\n- Longueur moyenne avant : %.2f caractères\n- Longueur moyenne après : %.2f caractères\n- Réduction moyenne : %.2f%%\n- Nombre moyen de tokens par texte : %.2f\n",
  mean(nchar(data$Comment)),
  mean(nchar(data$Comment_stemmed)),
  (1 - mean(nchar(data$Comment_stemmed)) / mean(nchar(data$Comment))) * 100,
  mean(sapply(data$tokens_stemmed, length))
)
cat(stats_output)
```

Ces transformations permettent de standardiser le texte et de réduire la taille, tout en conservant le sens essentiel pour faciliter 
la classification des émotions.

<br>

##### <FONT color='#0066CC'><FONT size = 4> 2.2.3 Vectorisation du texte à l'aide de la fréquence des termes et de la fréquence inverse du document (TF-IDF) </FONT></FONT>

Pour que le modèle de machine learning puissent traiter le texte, il est nécessaire de le transformer en représentation numérique.
Nous utilisons ici la méthode TF-IDF qui pondère l'importance de chaque terme dans les textes. Cette approche permet de capturer 
les mots les plus significatifs pour distinguer les différentes émotions.

```r
# Fonction de création de la matrice TF-IDF avec filtrage
create_tfidf_matrix <- function(text_clean, sparse_threshold = 0.999, 
                                verbose = FALSE) {
  # Création du corpus à partir du texte nettoyé
  corpus <- Corpus(VectorSource(text_clean))

  # Création de la matrice Document-Term (DTM)
  dtm <- DocumentTermMatrix(corpus, control = list(
    weighting = weightTf
  ))
  if (verbose) cat(sprintf("Nombre de termes avant filtrage de sparsité : %d\n", ncol(dtm)))

  # Filtrage par sparsité : supprime les termes trop rares
  # sparse = 0.999 signifie que les termes absents dans plus de 99.9% des documents sont supprimés
  dtm <- removeSparseTerms(dtm, sparse = sparse_threshold)
  
  if (verbose) cat(sprintf("Nombre de termes après filtrage (sparse=%.3f) : %d\n", 
                          sparse_threshold, ncol(dtm)))
  
  # Application de la pondération TF-IDF
  # Donne plus de poids aux termes fréquents dans un document mais rares dans le corpus
  dtm_tfidf <- weightTfIdf(dtm)
  tfidf_matrix <- as.matrix(dtm_tfidf)
  
  # Détection des textes vides (tous leurs termes ont été filtrés)
  row_sums <- rowSums(tfidf_matrix)
  empty_docs <- which(row_sums == 0)
  
  if (length(empty_docs) > 0 && verbose) {
    cat(sprintf("\nTextes vides détectés (tous termes filtrés) : %d\n", length(empty_docs)))
    cat("Ces textes contenaient uniquement des termes très rares.\n")
  }
  
  # Remplacement des valeurs manquantes par 0
  tfidf_matrix[is.na(tfidf_matrix)] <- 0
  
  # Retourne la matrice TF-IDF, les indices des textes vides, et le nombre de features
  list(matrix = tfidf_matrix, empty_docs = empty_docs, n_features = ncol(tfidf_matrix))
}

# Application de la vectorisation TF-IDF
# sparse=0.999 : compromis optimal entre réduction dimensionnalité et préservation sémantique
tfidf_result <- create_tfidf_matrix(data$Comment_stemmed, 
                                     sparse_threshold = 0.999, 
                                     verbose = TRUE)

```


**Statistiques** de la vectorisation TF-IDF :
```r
# Calcul des statistiques et des termes les plus fréquents
term_freq <- colSums(tfidf_result$matrix > 0)
top_terms <- sort(term_freq, decreasing = TRUE)[1:10]

# Création de la liste des top termes
top_terms_text <- paste(sprintf("%d. %s (%d)", 1:10, names(top_terms), as.numeric(top_terms)), collapse = "\n   ")

# Statistiques complètes
stats_tfidf <- sprintf(
  "Nombre de termes uniques (vocabulaire) : %d\n\nTop 10 des termes les plus fréquents dans le corpus :\n   %s\n",
  ncol(tfidf_result$matrix),
  top_terms_text
)
cat(stats_tfidf)
```

<br>

#### <FONT color='#0066CC'><FONT size = 4> 2.3 Feature Engineering et division des données </FONT></FONT>

```r
# Fonction de préparation des features + split train/test
prepare_train_test <- function(tfidf_result, emotion_labels, test_size = 0.2, seed = 123) {
  m <- tfidf_result$matrix
  empty_docs <- tfidf_result$empty_docs
  
  # Retrait des textes vides (détectés lors de la création TF-IDF)
  if (length(empty_docs) > 0) {
    m <- m[-empty_docs, ]
    emotion_labels <- emotion_labels[-empty_docs]
    cat(sprintf("Textes vides retirés : %d\n", length(empty_docs)))
    cat(sprintf("Observations restantes : %d\n\n", length(emotion_labels)))
  }
  
  # Feature engineering : conversion en data frame
  tfidf_df <- as.data.frame(m)
  tfidf_df$Emotion <- as.factor(emotion_labels)
  
  # Division train/test
  set.seed(seed)
  trainIndex <- createDataPartition(tfidf_df$Emotion, p = 1 - test_size, list = FALSE)
  trainData <- tfidf_df[trainIndex, ]
  testData <- tfidf_df[-trainIndex, ]
  
  # Retourne les données prêtées et quelques statistiques
  list(
    full_data = tfidf_df,
    train = trainData,
    test = testData,
    n_features = ncol(tfidf_df) - 1,  # -1 pour exclure la colonne Emotion
    n_obs = nrow(tfidf_df)
  )
}

# Préparation des features et division train/test
data_split <- prepare_train_test(tfidf_result, data$Emotion, test_size = 0.2, seed = 123)

# Récupération des ensembles
tfidf_df <- data_split$full_data
trainData <- data_split$train
testData <- data_split$test

# Statistiques sur les features
stats_features <- sprintf(
  "Features créées pour le modèle :\n- Nombre total de features : %d\n- Variable cible : Emotion (3 classes)\n- Nombre d'observations : %d\n",
  data_split$n_features,
  data_split$n_obs
)
# Affichage complet des statistiques
cat(sprintf(
  "%s\nDivision des données :\n- Ensemble d'entraînement : %d observations (%.1f%%)\n- Ensemble de test : %d observations (%.1f%%)\n\nDistribution des classes (entraînement) :%s\n\nDistribution des classes (test) :%s\n",
  stats_features,
  nrow(trainData), 100 * nrow(trainData) / data_split$n_obs,
  nrow(testData), 100 * nrow(testData) / data_split$n_obs,
  paste(capture.output(print(table(trainData$Emotion))), collapse = "\n"),
  paste(capture.output(print(table(testData$Emotion))), collapse = "\n")
))
```

**Explication du Feature Engineering :**

Après avoir appliqué le TF-IDF, nous préparons les données pour l'apprentissage du modèle.

Concernant la préparation des données :

Variable cible : Nous avons choisi la colonne “Emotion” (regroupant la colère, la peur et la joie) comme un facteur pour la classification.

Découpage des données : Nous avons séparé le dataset avec un ratio 80/20 pour l'entraînement et le test. Pour éviter tout biais, nous avons 
utilisé une division stratifiée avec la fonction createDataPartition. Cela nous garantit que la répartition des différentes émotions reste 
la même dans les deux groupes pour que le modèle apprenne de façon équilibrée.

**Note sur la reproductibilité :**
Pour garantir la reproductibilité des résultats, nous avons fixé la graine aléatoire (seed) à 123 avant toutes les étapes impliquant de 
l'aléatoire. Le code permet maintenant d'être exécuté par tout le monde et d'obtenir les mêmes résultats. C'est aussi important pour conserver 
une cohérence dans l'analyse des résultats.

Cette vectorisation permet ensuite au modèle de calculer les probabilités d'apparition de chaque mot pour chaque catégorie d'émotion.
<br>

#### <FONT color='#0066CC'><FONT size = 4> 2.4 Choix du modèle : Naive Bayes </FONT></FONT>

**Pourquoi Naive Bayes est approprié pour ce problème :**

Conformément aux directives du projet, nous avons implémenté le classifieur Naive Bayes. Ce choix s'explique par la pertinence de ce modèle 
pour la classification de texte. Son principal atout est son efficacité computationnelle : même avec un vocabulaire très étendu, il reste 
extrêmement rapide car il repose sur des calculs de probabilités simples.

Même si le modèle repose sur l'hypothèse d'indépendance conditionnelle, il donne généralement de très bons résultats en NLP. C'est un bon 
point de départ pour ce projet car il permet d'obtenir des prédictions fiables avec peu de données, tout en restant très interprétable pour 
analyser quels mots influencent le plus chaque émotion.

<br>

<hr style="border: 1px  solid gray">

### <FONT color='#0066CC'><FONT size = 5> 3. Résultats </FONT></FONT>

#### <FONT color='#0066CC'><FONT size = 4> 3.1 Construction du modèle Naive Bayes </FONT></FONT>

```r
# Fonction d'entraînement du modèle Naive Bayes
train_naive_bayes <- function(trainData) {
  # Entraînement du modèle Naive Bayes avec e1071
  model_nb <- naiveBayes(Emotion ~ ., data = trainData)
  return(model_nb)
}

# Entraînement du modèle
model_nb <- train_naive_bayes(trainData)

# Affichage des informations du modèle
cat("Modèle Naive Bayes entraîné avec succès !\n\n")
cat("Probabilités a priori des classes :\n")
print(model_nb$apriori)
```

Le modèle a été entraîné sur l'ensemble d'apprentissage. Les probabilités a priori reflètent la distribution des classes dans les données d'entraînement.

<br>

#### <FONT color='#0066CC'><FONT size = 4> 3.2 Prédictions </FONT></FONT>

```r
# Prédictions sur l'ensemble de test
predictions <- predict(model_nb, testData)

# Prédictions avec probabilités
predictions_prob <- predict(model_nb, testData, type = "raw")

# Affichage des premières prédictions
cat("Exemples de prédictions (5 premiers cas) :\n\n")
for(i in 1:5) {
  cat(sprintf("Observation %d:\n", i))
  cat(sprintf("  Vraie classe : %s\n", testData$Emotion[i]))
  cat(sprintf("  Prédiction : %s\n", predictions[i]))
  cat(sprintf("  Probabilités : anger=%.3f, fear=%.3f, joy=%.3f\n\n", 
              predictions_prob[i,1], predictions_prob[i,2], predictions_prob[i,3]))
}
```

<br>

#### <FONT color='#0066CC'><FONT size = 4> 3.3 Évaluation du modèle </FONT></FONT>

##### <FONT color='#0066CC'><FONT size = 4> 3.3.1 Matrice de confusion </FONT></FONT>

```r
# Fonction d'évaluation complète du modèle
evaluate_model <- function(model, testData, show_details = TRUE) {
  # Prédictions sur l'ensemble de test
  predictions <- predict(model, testData)
  
  # Prédictions avec probabilités pour chaque classe
  predictions_prob <- predict(model, testData, type = "raw")
  
  # Création de la matrice de confusion et calcul des métriques
  conf_matrix <- confusionMatrix(predictions, testData$Emotion)
  
  # Extraction des métriques principales
  accuracy <- conf_matrix$overall['Accuracy']
  kappa <- conf_matrix$overall['Kappa']
  precision_macro <- mean(conf_matrix$byClass[, 'Precision'], na.rm = TRUE)
  recall_macro <- mean(conf_matrix$byClass[, 'Recall'], na.rm = TRUE)
  f1_macro <- mean(conf_matrix$byClass[, 'F1'], na.rm = TRUE)
  
  # Affichage des métriques si demandé
  if (show_details) {
    cat(sprintf("\nMétriques de performance :\n"))
    cat(sprintf("- Accuracy : %.4f (%.2f%%)\n", accuracy, accuracy * 100))
    cat(sprintf("- F1-Score moyen : %.4f\n", f1_macro))
  }
  
  # Retourne toutes les informations utiles
  list(
    predictions = predictions,
    predictions_prob = predictions_prob,
    conf_matrix = conf_matrix,
    accuracy = accuracy,
    kappa = kappa,
    precision_macro = precision_macro,
    recall_macro = recall_macro,
    f1_macro = f1_macro
  )
}

# Création de la matrice de confusion avec la fonction d'évaluation
result <- evaluate_model(model_nb, testData, show_details = FALSE)
conf_matrix <- result$conf_matrix
predictions <- result$predictions
predictions_prob <- result$predictions_prob

# Affichage de la matrice de confusion
cat("Matrice de confusion :\n\n")
print(conf_matrix$table)
cat("\n")

# Visualisation de la matrice de confusion
conf_df <- as.data.frame(conf_matrix$table)
colnames(conf_df) <- c("Prediction", "Reference", "Freq")

ggplot(conf_df, aes(x = Reference, y = Prediction, fill = Freq)) +
  geom_tile(color = "white") +
  geom_text(aes(label = Freq), size = 6, fontface = "bold") +
  scale_fill_gradient(low = "#FFFFFF", high = "#0066CC") +
  labs(title = "Matrice de confusion",
       x = "Vraie classe",
       y = "Prédiction") +
  theme_minimal() +
  theme(plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
        axis.text = element_text(size = 11),
        legend.position = "right")
```

**Interprétation de la matrice :**

La matrice de confusion montre le nombre de prédictions correctes (diagonale) et incorrectes (hors diagonale) pour chaque classe d'émotion. 
Les valeurs sur la diagonale représentent les prédictions correctes.

<br>

##### <FONT color='#0066CC'><FONT size = 4> 3.3.2 Métriques de performance </FONT></FONT>

```r
# Utilisation des métriques déjà calculées par la fonction evaluate_model
accuracy <- result$accuracy
kappa <- result$kappa
precision_macro <- result$precision_macro
recall_macro <- result$recall_macro
f1_macro <- result$f1_macro

# Extraction des métriques par classe (pour affichage détaillé)
metrics_by_class <- conf_matrix$byClass

# Affichage des métriques globales
stats_global <- sprintf(
  "Métriques de performance globales :\n- Accuracy (Exactitude) : %.4f (%.2f%%)\n- Kappa de Cohen : %.4f\n",
  accuracy,
  accuracy * 100,
  kappa
)
cat(stats_global)
cat("\n")

# Création d'un tableau récapitulatif des métriques par classe
metrics_summary <- data.frame(
  Emotion = rownames(metrics_by_class),
  Precision = round(metrics_by_class[, 'Precision'], 4),
  Recall = round(metrics_by_class[, 'Recall'], 4),
  F1_Score = round(metrics_by_class[, 'F1'], 4),
  Specificity = round(metrics_by_class[, 'Specificity'], 4)
)
rownames(metrics_summary) <- NULL

cat("Métriques par classe :\n\n")
kable(metrics_summary, caption = "Métriques de performance par émotion")

# Affichage des moyennes
cat("\n")
stats_macro <- sprintf(
  "Métriques moyennes (macro-average) :\n- Precision moyenne : %.4f (%.2f%%)\n- Recall moyen : %.4f (%.2f%%)\n- F1-Score moyen : %.4f (%.2f%%)\n",
  precision_macro,
  precision_macro * 100,
  recall_macro,
  recall_macro * 100,
  f1_macro,
  f1_macro * 100
)
cat(stats_macro)
```

**Explication des métriques :**

Pour évaluer notre modèle, on ne va pas se limiter à l'Accuracy (le taux global de bonnes réponses). On utilisera aussi la Précision et 
le Recall (Rappel) pour voir si le modèle ne confond pas certaines émotions entre elles. Le F1-Score nous servira d'indicateur de synthèse 
pour avoir un bon équilibre entre ces deux mesures, tandis que la Spécificité nous permettra de vérifier si le modèle identifie correctement 
les cas où une émotion n'est pas présente.

<br>

#### <FONT color='#0066CC'><FONT size = 4> 3.4 Amélioration et optimisation </FONT></FONT>

##### <FONT color='#0066CC'><FONT size = 4> 3.4.1 Expérimentation de techniques de prétraitement </FONT></FONT>

Nous comparons différentes approches de prétraitement et de paramétrage pour identifier celle qui offre les meilleures performances pour la 
classification des émotions. Notre modèle de base utilise **stemming et sparse = 0.999**. Nous testerons 4 variantes.

Pour ces expérimentations, nous allons modifier les fonctions existantes avec des options supplémentaires :

```r
# Fonction alternative de prétraitement : tokenization OU lemmatization
# (sans stemming - utilisée uniquement pour les expérimentations)
preprocess_alt <- function(text_clean, method = c("tokenization", "lemmatization")) {
  method <- match.arg(method)
  
  # Chargement des stopwords anglais
  stopwords_en <- stopwords("en")
  
  if (method == "tokenization") {
    # Tokenization seule (sans normalisation)
    # Divise le texte en mots et supprime les stopwords uniquement
    result <- sapply(text_clean, function(txt) {
      words <- unlist(strsplit(txt, " "))
      words_filtered <- words[!words %in% stopwords_en & nchar(words) > 0]
      paste(words_filtered, collapse = " ")
    })
    
  } else if (method == "lemmatization") {
    # Tokenization + lemmatization (nouvelle approche expérimentale)
    # Réduit les mots à leur forme canonique (ex: better -> good)
    result <- sapply(text_clean, function(txt) {
      words <- unlist(strsplit(txt, " "))
      words_filtered <- words[!words %in% stopwords_en & nchar(words) > 0]
      if(length(words_filtered) > 0) {
        words_lemmatized <- lemmatize_words(words_filtered)
        paste(words_lemmatized, collapse = " ")
      } else {
        ""
      }
    })
  }
  
  return(result)
}

# Extension de create_tfidf_matrix pour supporter max_freq
create_tfidf_matrix <- function(text_clean, sparse_threshold = 0.999, 
                                max_freq = NULL, verbose = FALSE) {
  # Création du corpus à partir du texte nettoyé
  corpus <- Corpus(VectorSource(text_clean))
  
  # Création de la matrice Document-Term (DTM)
  dtm <- DocumentTermMatrix(corpus, control = list(
    weighting = weightTf
  ))
  
  if (verbose) cat(sprintf("Nombre de termes avant filtrage de sparsité : %d\n", ncol(dtm)))
  
  # Filtrage par sparsité
  dtm <- removeSparseTerms(dtm, sparse = sparse_threshold)
  
  if (verbose) cat(sprintf("Nombre de termes après filtrage (sparse=%.3f) : %d\n", 
                          sparse_threshold, ncol(dtm)))
  
  # Filtrage optionnel des termes très fréquents (nouvelle option pour expérimentation)
  # Permet de retirer les termes trop communs qui n'apportent pas d'information discriminante
  if (!is.null(max_freq)) {
    m_temp <- as.matrix(dtm)
    doc_freq <- colSums(m_temp > 0)  # Compte dans combien de documents chaque terme apparaît
    keep_terms <- doc_freq <= max_freq
    dtm <- dtm[, keep_terms]
    if (verbose) cat(sprintf("Termes après max_freq=%d : %d\n", max_freq, ncol(dtm)))
  }
  
  # Application TF-IDF
  dtm_tfidf <- weightTfIdf(dtm)
  m <- as.matrix(dtm_tfidf)
  
  # Détection des textes vides
  row_sums <- rowSums(m)
  empty_docs <- which(row_sums == 0)
  
  if (length(empty_docs) > 0 && verbose) {
    cat(sprintf("\nTextes vides détectés : %d\n", length(empty_docs)))
  }
  
  # Remplacement NA/NaN
  m[is.na(m)] <- 0
  
  list(matrix = m, empty_docs = empty_docs, n_features = ncol(m))
}
```

<br>

Maintenant, lançons les expérimentations avec ces fonctions modifiées :

```r
# Expérimentation 1 : Tokenization seule (sans stemming)

cat("\n=== Expérimentation 1 : Tokenization seule ===\n\n")

# Utilisation du texte nettoyé (mais pas stemmé) + tokenization
text_exp1 <- preprocess_alt(data$Comment_clean, method = "tokenization")

# TF-IDF
tfidf_exp1 <- create_tfidf_matrix(text_exp1, sparse_threshold = 0.999, verbose = TRUE)

# Train/test split
data_split_exp1 <- prepare_train_test(tfidf_exp1, data$Emotion, test_size = 0.2, seed = 123)

# Entraînement
model_exp1 <- train_naive_bayes(data_split_exp1$train)

# Évaluation
result_exp1 <- evaluate_model(model_exp1, data_split_exp1$test, show_details = TRUE)

# Expérimentation 2 : Lemmatization

cat("\n=== Expérimentation 2 : Lemmatization ===\n\n")

# Utilisation du texte nettoyé (mais pas stemmé) + lemmatization
text_exp2 <- preprocess_alt(data$Comment_clean, method = "lemmatization")
tfidf_exp2 <- create_tfidf_matrix(text_exp2, sparse_threshold = 0.999, verbose = TRUE)
data_split_exp2 <- prepare_train_test(tfidf_exp2, data$Emotion, test_size = 0.2, seed = 123)
model_exp2 <- train_naive_bayes(data_split_exp2$train)
result_exp2 <- evaluate_model(model_exp2, data_split_exp2$test, show_details = TRUE)

# Expérimentation 3 : Stemming + sparse plus strict (0.98)

cat("\n=== Expérimentation 3 : Stemming + sparse=0.98 ===\n\n")

# Réutilisation du texte déjà stemmé (même prétraitement que le modèle de base)
tfidf_exp3 <- create_tfidf_matrix(data$Comment_stemmed, sparse_threshold = 0.98, verbose = TRUE)
data_split_exp3 <- prepare_train_test(tfidf_exp3, data$Emotion, test_size = 0.2, seed = 123)
model_exp3 <- train_naive_bayes(data_split_exp3$train)
result_exp3 <- evaluate_model(model_exp3, data_split_exp3$test, show_details = TRUE)

# Expérimentation 4 : Stemming + filtrage termes très fréquents

cat("\n=== Expérimentation 4 : Stemming + max_freq=200 ===\n\n")

# Réutilisation du texte déjà stemmé (même prétraitement que le modèle de base)
tfidf_exp4 <- create_tfidf_matrix(data$Comment_stemmed, sparse_threshold = 0.999, max_freq = 200, verbose = TRUE)
data_split_exp4 <- prepare_train_test(tfidf_exp4, data$Emotion, test_size = 0.2, seed = 123)
model_exp4 <- train_naive_bayes(data_split_exp4$train)
result_exp4 <- evaluate_model(model_exp4, data_split_exp4$test, show_details = TRUE)

# Résumé comparatif

cat("COMPARAISON DES APPROCHES\n")

comparison_df <- data.frame(
  Approche = c(
    "Baseline (stemming + 0.999)",
    "Exp 1: Tokenization seule",
    "Exp 2: Lemmatization",
    "Exp 3: Stemming + sparse=0.98",
    "Exp 4: Stemming + max_freq=200"
  ),
  Features = c(
    data_split$n_features,  # Baseline
    data_split_exp1$n_features,
    data_split_exp2$n_features,
    data_split_exp3$n_features,
    data_split_exp4$n_features
  ),
  Observations = c(
    data_split$n_obs,  # Baseline
    data_split_exp1$n_obs,
    data_split_exp2$n_obs,
    data_split_exp3$n_obs,
    data_split_exp4$n_obs
  ),
  Accuracy = round(c(
    accuracy,
    result_exp1$accuracy,
    result_exp2$accuracy,
    result_exp3$accuracy,
    result_exp4$accuracy
  ), 4),
  F1_moyen = round(c(
    f1_macro,
    result_exp1$f1_macro,
    result_exp2$f1_macro,
    result_exp3$f1_macro,
    result_exp4$f1_macro
  ), 4)
)

kable(comparison_df, caption = "Comparaison des techniques de prétraitement et paramétrage")
```

<br>

##### <FONT color='#0066CC'><FONT size = 4> 3.4.2 Validation croisée k-fold </FONT></FONT>

Pour évaluer la robustesse du modèle et s'assurer qu'il généralise bien, nous utilisons la validation croisée à 10 plis (10-fold cross-validation). 
Cette technique divise les données en 10 sous-ensembles et entraîne le modèle 10 fois, en utilisant à chaque fois un sous-ensemble différent comme ensemble de test.

```r
# Configuration de la validation croisée 10-fold manuelle
set.seed(123)
k_folds <- 10

# Création des indices de plis
folds <- createFolds(tfidf_df$Emotion, k = k_folds, list = TRUE, returnTrain = FALSE)

# Initialisation des vecteurs pour stocker les résultats
accuracy_scores <- numeric(k_folds)
kappa_scores <- numeric(k_folds)
precision_scores <- numeric(k_folds)
recall_scores <- numeric(k_folds)
f1_scores <- numeric(k_folds)

# Boucle sur chaque pli
cat("Exécution de la validation croisée 10-fold...\n\n")
for(i in 1:k_folds) {
  # Séparation train/test pour ce pli
  test_indices <- folds[[i]]
  train_data_cv <- tfidf_df[-test_indices, ]
  test_data_cv <- tfidf_df[test_indices, ]
  
  # Entraînement du modèle avec e1071
  model_fold <- naiveBayes(Emotion ~ ., data = train_data_cv)
  
  # Prédictions
  predictions_fold <- predict(model_fold, test_data_cv)
  
  # Calcul des métriques
  conf_mat_fold <- confusionMatrix(predictions_fold, test_data_cv$Emotion)
  
  # Stockage des résultats
  accuracy_scores[i] <- conf_mat_fold$overall['Accuracy']
  kappa_scores[i] <- conf_mat_fold$overall['Kappa']
  
  # Métriques par classe (moyennées)
  precision_scores[i] <- mean(conf_mat_fold$byClass[, 'Precision'], na.rm = TRUE)
  recall_scores[i] <- mean(conf_mat_fold$byClass[, 'Recall'], na.rm = TRUE)
  f1_scores[i] <- mean(conf_mat_fold$byClass[, 'F1'], na.rm = TRUE)
  
  cat(sprintf("Pli %d/%d - Accuracy: %.4f\n", i, k_folds, accuracy_scores[i]))
}

cat("\n")

# Calcul des statistiques finales
mean_accuracy <- mean(accuracy_scores)
sd_accuracy <- sd(accuracy_scores)
mean_kappa <- mean(kappa_scores)
sd_kappa <- sd(kappa_scores)
mean_precision <- mean(precision_scores, na.rm = TRUE)
mean_recall <- mean(recall_scores, na.rm = TRUE)
mean_f1 <- mean(f1_scores, na.rm = TRUE)

# Affichage des résultats
cv_stats <- sprintf(
  "Résultats de la validation croisée 10-fold :\n\nPerformances moyennes sur 10 plis :\n- Accuracy : %.4f (± %.4f)\n- Kappa : %.4f (± %.4f)\n- Precision moyenne : %.4f\n- Recall moyen : %.4f\n- F1-Score moyen : %.4f\n",
  mean_accuracy,
  sd_accuracy,
  mean_kappa,
  sd_kappa,
  mean_precision,
  mean_recall,
  mean_f1
)
cat(cv_stats)
cat("\n")

# Tableau récapitulatif des résultats par pli
cv_results_df <- data.frame(
  Pli = 1:k_folds,
  Accuracy = round(accuracy_scores, 4),
  Kappa = round(kappa_scores, 4),
  F1_Score = round(f1_scores, 4)
)

cat("Détail des résultats par pli :\n\n")
kable(cv_results_df, caption = "Résultats de validation croisée par pli")
```

<br>

<hr style="border: 1px  solid gray">

### <FONT color='#0066CC'><FONT size = 5> 4. Discussion </FONT></FONT>

#### <FONT color='#0066CC'><FONT size = 4> 4.1 Interprétation des résultats </FONT></FONT>

**Comparaison des approches expérimentées :**

Après avoir testé quatre variantes de prétraitement (tokenization seule, lemmatization, sparse=0.98, max_freq=200), **l'approche originale (stemming + sparse=0.999)** 
semble être la plus performante avec une accuracy de **0.3848 (38.48%)** et un F1-Score moyen de **0.3705**.

**Analyse comparative des approches :**

1. **Tokenization seule (Exp 1)** : accuracy 0.3421
   - Conserve trop de diversité des mots (1373 features)
   - N'apporte pas valeur discriminante malgré le vocabulaire plus riche
   - Le modèle se perd plutôt que de recevoir de l'information utile pour différencier les émotions

2. **Lemmatization (Exp 2)** : accuracy 0.3662
   - Résultats intermédiaires entre tokenization et stemming
   - La normalisation linguistique est trop conservatrice pour ce contexte
   - Reste inférieure au stemming malgré sa précision linguistique

3. **Stemming + sparse=0.98 (Exp 3)** : accuracy 0.3831
   - Réduit énormément le vocabulaire (à seulement 49 features)
   - Perte massive d'information
   - Le filtrage trop agressif pourrait éliminer des termes pertinents pour distinguer les émotions

4. **Stemming + max_freq=200 (Exp 4)** : accuracy 0.3705
   - Le filtrage des termes fréquents n'améliore pas les performances
   - Certains termes communs restent pertinents pour la classification

**Pourquoi le modèle original est le plus équilibré**

En comparant les différentes approches, c'est la configuration Baseline (stemming + sparse à 0.999) qui s'est avérée la plus efficace. Elle offre 
le meilleur compromis sur plusieurs points :

- Gestion du volume de données : Avec environ 1313 variables, on garde un ratio par observation tout à fait correct, ce qui protège le modèle du surapprentissage.

- Simplification du vocabulaire : Le stemming a permis de regrouper les variantes d'un même mot de façon assez directe. C'est une normalisation 
efficace qui nettoie le texte sans perdre les nuances nécessaires pour distinguer les émotions.

- Résultats : C'est cette méthode qui affiche les meilleures métriques par rapport aux autres tests effectués.

**Analyse des performances globales**

Le modèle affiche une accuracy de 38.48%. Si ce score peut paraître moyen, il reste cohérent pour une classification d'émotions sur trois classes (colère, 
peur, joie). Plusieurs facteurs expliquent ce résultat :

- L'ambiguïté des textes : Les distinctions entre certaines émotions sont parfois très complexes, ce qui rend le classement difficile.

- Les limites : Le modèle ne prend pas en compte l'ordre des mots ou le contexte implicite, ce qui fait perdre une partie du sens.

- L'hypothèse Naive Bayes : En considérant que chaque mot est indépendant des autres, le modèle passe forcément à côté des relations sémantiques complexes entre les termes.

**Robustesse et généralisation : validation croisée 10-fold**

Pour vérifier la fiabilité de notre modèle, nous avons effectué une validation croisée 10-fold. Les résultats confirment la stabilité de notre approche :

Cohérence des scores : L'accuracy moyenne est de 0.3914, un score très proche de celui obtenu sur le test (0.3848). Cette similitude prouve que le modèle généralise bien et 
ne fait pas de surapprentissage.

Stabilité : L'écart-type est très faible (0.0157), ce qui montre que les performances varient très peu d'un sous-ensemble à l'autre. Le modèle n'est donc pas sensible aux variations des données d'entraînement.

Fiabilité : Avec un F1-score moyen de 0.3733 et un Kappa de 0.0872, les résultats sont stables sur différents sous-ensembles de données, validant la robustesse globale de notre classifieur face à la complexité des émotions traitées. La reproductibilité, quant à elle, est garantie par la graine aléatoire fixée à 123.


<br>

#### <FONT color='#0066CC'><FONT size = 4> 4.3 Défis rencontrés </FONT></FONT>

**Optimisation et gestion du biais de prédiction**

Lors des premiers tests, nous avons fait face à un problème majeur : le modèle prédisait systématiquement l'émotion "fear" (dans environ 85% des cas), peu importe le texte. Ce biais rendait le classifieur inutilisable.

**Origine du problème :**
Ce phénomène s'expliquait principalement par le "fléau de la dimensionnalité". Avec plus de 6 000 termes pour seulement 5 900 phrases, le modèle avait trop de variables/mots par rapport au nombre de commentaires/phrases. Cette 
abondance de mots rares créait du "bruit", empêchant Naive Bayes de calculer des probabilités fiables.

**Solutions et résultats :**
Pour stabiliser le modèle, nous avons procédé à un nettoyage ciblé :

Filtrage de la sparsité : Grâce à removeSparseTerms(sparse = 0.999), nous avons éliminé les mots présents dans moins de 0,1% des documents. Cela a réduit le vocabulaire de 78%, passant de 6 000 à environ 1 300 termes.

Nettoyage final : Nous avons supprimé une quarantaine de documents devenus "vides" après ce filtrage pour ne pas fausser l'entraînement.

Bilan : Ce réglage a été décisif. En ramenant le ratio variables/observations à 1:4.5, nous avons totalement éliminé le biais de prédiction. Les résultats sont désormais équilibrés entre les trois émotions (anger, fear, 
joy), prouvant que dans ce projet, "moins de mots" signifiait "plus de précision".

Cette démarche d'optimisation montre l'importance cruciale du prétraitement et du choix des paramètres, particulièrement lorsque le ratio features/observations est défavorable.

<br>

<hr style="border: 1px  solid gray">

### <FONT color='#0066CC'><FONT size = 5> 5. Conclusion et travaux à venir </FONT></FONT>

Ce projet nous a permis de voir concrètement qu'en NLP, la qualité du prétraitement compte autant, sinon plus, que le choix de l'algorithme lui-même. En passant d'un modèle initialement biaisé à un classifieur équilibré 
grâce à l'optimisation de la sparsité, nous avons pu obtenir des prédictions cohérentes sur les trois émotions étudiées. Bien que l'accuracy globale reste modeste (environ 38,5 %), elle représente bien la difficulté 
de capter la subjectivité humaine à travers un texte.

Pour aller plus loin, plusieurs pistes d'amélioration sont envisageables :

- **Utilisation de modèles plus complexes** : Des algorithmes qui pourraient mieux capturer les interactions entre les mots, même avec un vocabulaire réduit.
- **Incorporation de dictionnaire** : Des dictionnaires mis à disposition du modèle pour mieux associer les mots à des émotions spécifiques.
- **Enrichissement du dataset** : Plus de données d'entraînement pourraient aider à mieux apprendre les nuances entre les émotions.

</DIV>
