---
title: "<FONT color='#0066CC'><FONT size = 4 ><DIV align= center> AP-4209 ESIEE-Paris: 2024 - 2025 </DIV></FONT></FONT>"
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

```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

<FONT color='#0066CC'><FONT size = 4 >

::: {align="center"}
Fouille de données avec R pour la data science et l'intelligence artificielle\

Projet 3 : Classification bayésienne et analyse factorielle discriminante  \
:::

</FONT></FONT>


<FONT color='#0066CC'><FONT size = 4 >

::: {align="center"}
DA CRUZ PEREIRA Antoine -- ESIEE Paris\
:::
 
</FONT></FONT>

<hr style="border: 1px  solid gray">

</hr>

<DIV align = justify>

### <FONT color='#0066CC'><FONT size = 4> 1. Objectif principal </FONT></FONT>

Mettre en place une classification bayésienne avancée avec analyse discriminante 
sur un jeu de données de résumés de thèses de doctorat françaises afin de les catégoriser en 
domaines d'étude. 

<br>

<hr style="border: 1px  solid gray">



### <FONT color='#0066CC'><FONT size = 4> 2 Source des données </FONT></FONT>

Recherche de similarité sémantique de thèse de doctorat française à partir de 
Kaggle. 

• Lien : https://www.kaggle.com/code/antoinebourgois2/french-doctoral-thesis-semantic-similarity-search 

Le jeu de données contient des informations sur les thèses de doctorat françaises, en 
mettant l'accent sur la similarité sémantique. Cela représente un défi unique pour la classification en 
raison de la nature textuelle et sémantique des données.


**Note:** Les fichiers de données étant volumineux ils ont été retiré de github, il faut donc les téléchargé manuellement et les mettre dans le même dossier que le Rmd pour tout faire fonctionner.

<br>

<hr style="border: 1px  solid gray">

### <FONT color='#0066CC'><FONT size = 4> 3 Aperçu des tâches </FONT></FONT>

1. Prétraitement des données : 

• Nettoyage du texte : Supprimez les mots d'arrêt (stopwords), la ponctuation et 
effectuez un stemming ou une lemmatisation. 

• Vectorisation : Convertir les données textuelles sous forme numérique à l'aide de TF-IDF ou le plongement lexical « plongement de mots ou word embeddings » tels que Word2Vec. 

2. Extraction de caractéristiques (Feature Extraction): 

• Utilisez des techniques de traitement du langage naturel (NLP) pour extraire des 
caractéristiques significatives des résumés de thèse. 

• Explorez la modélisation des rubriques (par exemple, LDA pour l'extraction de 
rubriques) pour comprendre les rubriques principales et les utiliser comme fonctionnalités. 

3. Réduction de la dimensionnalité : 

• Appliquez l'analyse discriminante linéaire (LDA, à ne pas confondre avec l'allocation 
de Dirichlet latente (Latent Dirichlet Allocation), également abrégée en LDA) pour réduire la 
dimensionnalité de l'espace d'entités tout en préservant la séparabilité des classes. 

• Vous pouvez également utiliser des techniques non linéaires telles que l'analyse 
discriminante du noyau (Kernel Discriminant Analysis) si les méthodes linéaires sont 
insuffisantes en raison de la complexité des données textuelles. 

4. Classification bayésienne : 

• Construire un classificateur bayésien pour catégoriser les thèses dans différents 
domaines d'étude en fonction des caractéristiques extraites. 

• Utilisez des méthodes bayésiennes avancées qui peuvent traiter des données de 
grande dimension et qui conviennent à la classification de texte. 

5. Optimisation et validation du modèle :  

• Optimisez les hyperparamètres du modèle à l'aide de techniques telles que la 
recherche de grille (Grid Search) ou l'optimisation bayésienne. 

• Validez le modèle à l'aide de stratégies de validation croisée appropriées pour les 
données textuelles. 

6. Performance Evaluation: 

• Utilisez des métriques adaptées à la classification, telles que l'exactitude, la 
précision, le rappel, le score F1 (Accuracy, Precision, Recall, and F1-score), et envisagez 
également la méthode ROC-AUC si le problème est formulé comme une classification binaire 
pour chaque domaine d'étude. 

• En outre, utilisez des matrices de confusion et des rapports de classification pour 
évaluer les performances dans différents domaines d'étude. 

7. Interprétabilité : 

• Analysez les facteurs discriminants pour interpréter les caractéristiques (mots, 
phrases, sujets) qui ont le plus d'influence sur la distinction entre les domaines d'études.


### <FONT color='#0066CC'><FONT size = 4> 4. Préparation des données </FONT></FONT>

#### 4.1 Chargement des données

Pour commencer notre analyse, la première étape est bien sûr de charger les données. Le jeu de données est contenu dans un fichier CSV, que nous allons importer dans R. Pour que les calculs ne soient pas trop longs et pour avoir une première idée du fonctionnement de nos méthodes, j'ai décidé de me concentrer sur un échantillon de 500 thèses pour commencer.

```{r}
data <- read.csv("french_thesis_20231021_metadata.csv")
data <- head(data, 500)

head(data)
```

**Note:** Pour des raison matériel tout les testes ont été fait sur un échantillon de 500 lignes, mais en supprimer ou en changeant le nombre du data <- head(data, 500) on peut agrandir l'échantillon

**Note2:** Le fait d'avoir réduit l'échantillon pour un besoin matériel peut avoir un impact sur les résultats. Il sera important de le prenbdre en compte lors de l'interprétation des résultats.


#### 4.2 Nettoyage du texte

Avant de pouvoir analyser le contenu des résumés, il faut faire un peu de ménage. Un texte brut contient beaucoup d'éléments qui peuvent perturber un algorithme, comme la ponctuation ou les majuscules. Voici les étapes que j'ai suivies pour nettoyer chaque résumé : premièrement, j'ai appliqué un **passage en minuscules** pour que l'algorithme ne fasse pas de différence entre "Science" et "science". Ensuite, j'ai procédé à la **suppression de la ponctuation** — les virgules, points, etc., ne sont pas utiles pour notre analyse sémantique. Puis, j'ai effectué un **retrait des espaces superflus** pour avoir un texte propre et bien formaté. Quatrièmement, j'ai réalisé la **suppression des "stopwords"** qui sont des mots très courants (comme "le", "la", "de", "et"...) qui n'apportent pas beaucoup de sens ; je me suis servi d'une liste de stopwords français pour les filtrer. Enfin, j'ai appliqué une **stemmatisation (ou racinisation)**, une technique qui permet de réduire les mots à leur racine — par exemple, "analyse", "analyser" et "analytique" deviendront tous "analy". Cela permet de regrouper les mots d'une même famille et de réduire le nombre de termes uniques.

```{r}

library(tm)
library(SnowballC)
library(stopwords)
```

```{r}
clean_text <- function(text) {
  text <- tolower(text)
  text <- gsub("[[:punct:]]", " ", text)
  text <- gsub("\\s+", " ", text)
  text <- trimws(text)
  return(text)
}

data$Description_clean <- ifelse(
  data$Description == "" | is.na(data$Description),
  "",
  clean_text(data$Description)
)
```

```{r}
preprocess_text <- function(text_clean) {
  stopwords_fr <- stopwords("fr")
  
  result <- sapply(text_clean, function(txt) {
    if (txt == "" || is.na(txt)) {
      return("")
    }
    
    words <- unlist(strsplit(txt, " "))
    words_filtered <- words[!words %in% stopwords_fr & nchar(words) > 0]
    
    if(length(words_filtered) > 0) {
      words_stemmed <- wordStem(words_filtered, language = "fr")
      paste(words_stemmed, collapse = " ")
    } else {
      ""
    }
  })
  return(result)
}

data$Description_stemmed <- preprocess_text(data$Description_clean)
```

Après ce nettoyage, on peut voir que la longueur moyenne des résumés a bien diminué, ce qui est normal puisque nous avons retiré beaucoup de mots et de caractères inutiles.

```{r}
non_vides <- data$Description != ""
n_non_vides <- sum(non_vides)

cat(sprintf("Descriptions non vides : %d / %d (%.2f%%)\n",
            n_non_vides, nrow(data), (n_non_vides / nrow(data)) * 100))
cat(sprintf("Longueur moyenne avant : %.2f caractères\n",
            mean(nchar(data$Description[non_vides]))))
cat(sprintf("Longueur moyenne après : %.2f caractères\n",
            mean(nchar(data$Description_stemmed[non_vides]))))
cat(sprintf("Réduction : %.2f%%\n",
            (1 - mean(nchar(data$Description_stemmed[non_vides])) / mean(nchar(data$Description[non_vides]))) * 100))
```

#### 4.3 Vectorisation : TF-IDF

Maintenant que les textes sont propres, il faut les transformer en quelque chose que l'ordinateur peut comprendre : des nombres. Pour cela, j'ai utilisé une méthode très connue en traitement du langage naturel, le **TF-IDF**.

L'idée est de créer une grande matrice où chaque ligne représente une thèse et chaque colonne représente un mot. La valeur dans chaque cellule est un score qui indique l'importance de ce mot pour cette thèse. Ce score est calculé en deux parties : d'une part, le **TF (Term Frequency)** qui compte simplement la fréquence d'un mot dans un document — un mot qui apparaît souvent est probablement important. D'autre part, l'**IDF (Inverse Document Frequency)** qui regarde à quel point un mot est rare dans l'ensemble des documents. Un mot qui apparaît dans presque toutes les thèses (par exemple, le mot "thèse" lui-même) n'est pas très utile pour les différencier : l'IDF va donc donner moins de poids à ces mots très courants et plus de poids aux mots rares, qui sont souvent plus spécifiques à un domaine. En combinant les deux, on obtient un score qui représente bien l'importance d'un mot pour caractériser une thèse en particulier.

```{r}
corpus <- Corpus(VectorSource(data$Description_stemmed))
dtm <- DocumentTermMatrix(corpus, 
                          control = list(weighting = weightTfIdf))

cat(sprintf("Dimensions originales DTM: %d documents x %d termes\n", nrow(dtm), ncol(dtm)))

dtm_reduced <- removeSparseTerms(dtm, sparse = 0.99)
cat(sprintf("Dimensions réduites DTM: %d documents x %d termes\n", nrow(dtm_reduced), ncol(dtm_reduced)))

n_zeros <- sum(dtm_reduced == 0)
total_cells <- nrow(dtm_reduced) * ncol(dtm_reduced)
sparsity <- (n_zeros / total_cells) * 100
cat(sprintf("Sparsité après réduction: %.2f%%\n", sparsity))

tfidf_matrix <- as.matrix(dtm_reduced)
```

### <FONT color='#0066CC'><FONT size = 4> 5. Extraction de caractéristiques </FONT></FONT>

#### 5.1 Les caractéristiques TF-IDF

La matrice TF-IDF que nous venons de construire constitue notre premier ensemble de caractéristiques. Chaque terme (colonne) peut être vu comme une "feature", et son score TF-IDF indique son importance pour chaque thèse. C'est une représentation numérique directe du contenu textuel.

On remarque que cette matrice est très "creuse" (sparse), c'est-à-dire qu'elle contient une grande majorité de zéros. C'est tout à fait normal : un résumé donné ne contient qu'un petit sous-ensemble de tous les mots possibles dans le corpus.

```{r}
mat <- tfidf_matrix
nb_doc <- nrow(mat)
nb_term <- ncol(mat)
cat(sprintf("Matrice TF-IDF: %d documents x %d termes\n", nb_doc, nb_term))
zeros <- sum(mat == 0)
total <- nb_doc * nb_term
densite <- (1 - zeros / total) * 100
cat(sprintf("Densité: %.2f%%\n", densite))
```

#### 5.2 Modélisation des thèmes (LDA)

Le TF-IDF se base sur les mots, mais on peut essayer d'aller un cran plus loin en essayant de deviner les grands "thèmes" abordés dans les résumés. Pour cela, j'ai utilisé un autre algorithme appelé **LDA (Latent Dirichlet Allocation)**.

L'idée du LDA est de supposer qu'il existe un certain nombre de thèmes cachés dans les documents, et que chaque document est un mélange de ces thèmes. L'algorithme va alors essayer de trouver quels sont les mots qui caractérisent le mieux chaque thème (par exemple, un thème "Biologie" pourrait être défini par les mots "cellule", "protéine", "gène"...) et quelle est la proportion de chaque thème dans chaque document. J'ai demandé à l'algorithme de trouver 10 thèmes, ce qui nous donne une vision plus abstraite et sémantique du contenu, particulièrement utile pour la classification.

```{r}
if (!require("topicmodels", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("topicmodels")
}
library(topicmodels)
```

```{r}
n_topics <- 10
my_seed <- 42

dtm_counts <- DocumentTermMatrix(corpus)
cat(sprintf("DTM original: %d documents x %d termes\n", nrow(dtm_counts), ncol(dtm_counts)))

dtm_counts_reduced <- removeSparseTerms(dtm_counts, sparse = 0.95)
cat(sprintf("DTM réduit (sparse=0.95): %d documents x %d termes\n", nrow(dtm_counts_reduced), ncol(dtm_counts_reduced)))

matrice_temp <- as.matrix(dtm_counts_reduced)
row_sums <- rowSums(matrice_temp)
non_empty_rows <- row_sums > 0
n_empty <- sum(!non_empty_rows)

if (n_empty > 0) {
  cat(sprintf("Avertissement: %d documents vides détectés après réduction des termes.\n", n_empty))
  dtm_counts_reduced <- dtm_counts_reduced[non_empty_rows, ]
  cat(sprintf("DTM après suppression des documents vides: %d documents x %d termes\n", nrow(dtm_counts_reduced), ncol(dtm_counts_reduced)))
}

matrice_temp2 <- as.matrix(dtm_counts_reduced)
row_sums2 <- rowSums(matrice_temp2)
if (any(row_sums2 == 0)) {
  cat("Erreur: Des documents vides subsistent. Augmentation du seuil de sparsité...\n")
  dtm_counts_reduced <- removeSparseTerms(dtm_counts, sparse = 0.90)
  matrice_temp3 <- as.matrix(dtm_counts_reduced)
  row_sums3 <- rowSums(matrice_temp3)
  non_empty_rows <- row_sums3 > 0
  dtm_counts_reduced <- dtm_counts_reduced[non_empty_rows, ]
  cat(sprintf("DTM avec sparse=0.90: %d documents x %d termes\n", nrow(dtm_counts_reduced), ncol(dtm_counts_reduced)))
}

cat("Entraînement du modèle LDA...\n")
lda_model <- LDA(dtm_counts_reduced, k = n_topics, method = "Gibbs", control = list(nstart = 1, seed = my_seed, best = TRUE, iter = 500))
cat("Modèle LDA entraîné avec succès!\n")
cat(sprintf("Nombre de rubriques: %d\n", n_topics))
```

Une fois le modèle entraîné, on peut regarder les mots les plus importants pour chaque thème pour essayer de comprendre ce qu'ils représentent. On obtient aussi une matrice où chaque thèse est décrite par 10 scores, représentant sa "proportion" de chaque thème.

```{r}
resultat <- posterior(lda_model)
topic_probabilities <- resultat$topics
cat(sprintf("Matrice des probabilités de rubriques: %d documents x %d rubriques\n", nrow(topic_probabilities), ncol(topic_probabilities)))

cat("\nTermes principaux par rubrique:\n")
terms_per_topic <- terms(lda_model, k <- 10)
i <- 1
while (i <= n_topics) {
  mots <- terms_per_topic[, i]
  mots_str <- paste(mots, collapse = ", ")
  cat(sprintf("\nRubrique %d: %s\n", i, mots_str))
  i <- i + 1
}
```

#### 5.3 Combinaison des caractéristiques

Maintenant, j'ai deux types de caractéristiques : d'une part, les scores **TF-IDF**, qui sont très bons pour identifier les mots-clés spécifiques d'un texte, et d'autre part les scores de **thèmes LDA**, qui capturent le sens général et le contexte. L'idée est de combiner les deux pour avoir une représentation plus riche et plus robuste. J'ai décidé de donner un peu plus de poids au TF-IDF (70%), car les mots-clés précis sont souvent très importants, tout en gardant 30% pour les thèmes LDA qui apportent une vision d'ensemble. Avant de les fusionner, j'ai normalisé les deux matrices pour qu'elles soient à la même échelle et qu'un type de caractéristique ne domine pas l'autre.

```{r}
tfidf_matrix_full <- as.matrix(dtm_reduced)

sommes_lignes <- rowSums(tfidf_matrix_full)
valid_docs <- sommes_lignes > 0
n_removed <- 0
for (i in 1:length(valid_docs)) {
  if (valid_docs[i] == FALSE) {
    n_removed <- n_removed + 1
  }
}

if (n_removed > 0) {
  cat(sprintf("Suppression de %d documents vides de la matrice TF-IDF\n", n_removed))
  tfidf_matrix_reduced <- tfidf_matrix_full[valid_docs, ]
} else {
  tfidf_matrix_reduced <- tfidf_matrix_full
}

cat(sprintf("TF-IDF apres filtrage: %d documents x %d termes\n", nrow(tfidf_matrix_reduced), ncol(tfidf_matrix_reduced)))
cat(sprintf("Topics (de LDA): %d documents x %d rubriques\n", nrow(topic_probabilities), ncol(topic_probabilities)))

nb_tfidf <- nrow(tfidf_matrix_reduced)
nb_topics <- nrow(topic_probabilities)
if (nb_tfidf != nb_topics) {
  if (nb_tfidf < nb_topics) {
    stopping_point <- nb_tfidf
  } else {
    stopping_point <- nb_topics
  }
  cat(sprintf("Ajustement aux %d documents communs\n", stopping_point))
  tfidf_matrix_reduced <- tfidf_matrix_reduced[1:stopping_point, ]
  topic_probabilities <- topic_probabilities[1:stopping_point, ]
}

tfidf_normalized <- scale(tfidf_matrix_reduced)
topics_normalized <- scale(topic_probabilities)

for (i in 1:nrow(tfidf_normalized)) {
  for (j in 1:ncol(tfidf_normalized)) {
    if (is.nan(tfidf_normalized[i, j])) {
      tfidf_normalized[i, j] = 0
    }
  }
}
for (i in 1:nrow(topics_normalized)) {
  for (j in 1:ncol(topics_normalized)) {
    if (is.nan(topics_normalized[i, j])) {
      topics_normalized[i, j] = 0
    }
  }
}

part1 = 0.7 * tfidf_normalized
part2 = 0.3 * topics_normalized
combined_features <- cbind(part1, part2)

noms_col1 = paste0("tfidf_", 1:ncol(tfidf_normalized))
noms_col2 = paste0("topic_", 1:ncol(topics_normalized))
colnames(combined_features) = c(noms_col1, noms_col2)

cat(sprintf("\nMatrice combinee de caracteristiques: %d documents x %d caracteristiques\n", nrow(combined_features), ncol(combined_features)))

features_df <- as.data.frame(combined_features)
```

### <FONT color='#0066CC'><FONT size = 4> 6 Réduction de la dimensionnalité </FONT></FONT>

#### 6.1 Préparation des données pour la classification

Avant de passer à la réduction de dimension, il faut préparer la variable que l'on veut prédire : le domaine de la thèse. J'ai cherché une colonne comme "Domain" ou "Category" dans les données. Une fois trouvée, il faut s'assurer qu'elle est bien alignée avec notre matrice de caractéristiques (autant de labels que de documents).

```{r}
y_label <- NULL

cat("Colonnes disponibles dans les donnees:\n")
print(colnames(data))

col_names <- colnames(data)
trouve <- FALSE
if ("Domain" %in% col_names) {
  y_label <- data$Domain
  trouve <- TRUE
}
if (trouve == FALSE) {
  if ("Domaine" %in% col_names) {
    y_label <- data$Domaine
    trouve <- TRUE
  }
}
if (trouve == FALSE) {
  if ("Category" %in% col_names) {
    y_label <- data$Category
    trouve <- TRUE
  }
}
if (trouve == FALSE) {
  cat("Aucune colonne de classification trouvee. Utilisation d'une strategie alternative.\n")
  nb_col <- ncol(data)
  if (nb_col > 1) {
    y_label = as.factor(head(data[[2]], nrow(data)))
  } else {
    cat("Attention: impossible de determiner la variable cible automatiquement.\n")
  }
}

if (!is.null(y_label)) {
  nb_classes <- nlevels(as.factor(y_label))
  cat(sprintf("Variable cible: %d classes identifiees\n", nb_classes))
  cat("Distribution des classes:\n")
  print(table(y_label))
  
  cat("\nNettoyage des noms de classes pour compatibilite...\n")
  original_levels <- levels(as.factor(y_label))
  clean_levels = make.names(original_levels, unique = TRUE)
  level_mapping <- setNames(clean_levels, original_levels)
  cat(sprintf("Exemple de mapping: '%s' -> '%s'\n", original_levels[1], clean_levels[1]))
  
  y_label <- factor(as.character(y_label), levels = original_levels, labels = clean_levels)
  
  taille_y <- length(y_label)
  taille_features <- nrow(combined_features)
  if (taille_y != taille_features) {
    cat(sprintf("ERREUR: y_label (%d) ne correspond pas a combined_features (%d)\n", taille_y, taille_features))
    cat("Utilisation de combined_features comme reference pour filtrer y_label...\n")
    y_label = y_label[1:taille_features]
  }
}
```

#### 6.2 Analyse Discriminante Linéaire (Linear Discriminant Analysis - LDA)

Notre matrice de caractéristiques est encore très grande. Utiliser toutes ces dimensions pour la classification peut être inefficace et mener à du sur-apprentissage. L'objectif est donc de réduire ce nombre de dimensions tout en gardant l'information la plus pertinente pour la **séparation des classes**.

C'est exactement ce que fait l'**Analyse Discriminante Linéaire (LDA)**. Contrairement à la PCA qui cherche les axes de plus grande variance, la LDA cherche les axes qui maximisent la distance entre les moyennes des différentes classes, tout en minimisant la variance à l'intérieur de chaque classe. C'est donc une méthode "supervisée" de réduction de dimension, parfaite pour notre problème de classification.

Le nombre de dimensions résultant sera au maximum de `k-1`, où `k` est le nombre de classes.

```{r}
if (!require("MASS", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("MASS")
}
library(MASS)

if (!is.null(y_label)) {
  taille_y <- length(y_label)
  taille_feat <- nrow(combined_features)
  if (taille_y != taille_feat) {
    cat(sprintf("ERREUR DE DIMENSION - Impossible de continuer:\n"))
    cat(sprintf("   - combined_features: %d documents\n", taille_feat))
    cat(sprintf("   - y_label: %d documents\n", taille_y))
    cat("Solution: suppression des excedents de y_label\n")
    y_label <- y_label[1:taille_feat]
  }
  
  lda_data <- as.data.frame(combined_features)
  lda_data$target <- factor(y_label)
  
  nb_features <- ncol(combined_features)
  if (nb_features > 100) {
    cat("Reduction prealable avec PCA (> 100 caracteristiques detectees)...\n")
    pca_result <- prcomp(combined_features, scale. = TRUE, rank. = 100)
    lda_features <- as.data.frame(pca_result$x)
    cat(sprintf("PCA reduit a %d composantes principales\n", ncol(lda_features)))
  } else {
    lda_features <- as.data.frame(combined_features)
  }
  
  lda_features$target <- factor(y_label)
  
  cat("Entrainement du modele LDA...\n")
  lda_model_class <- lda(target ~ ., data = lda_features)
  
  cat("Modele LDA entraine avec succes!\n")
  nb_classes <- length(lda_model_class$prior)
  cat(sprintf("Nombre de classes: %d\n", nb_classes))
  nb_discrim <- nb_classes - 1
  if (ncol(lda_features) - 1 < nb_discrim) {
    nb_discrim <- ncol(lda_features) - 1
  }
  cat(sprintf("Nombre de discriminantes lineaires: %d\n", nb_discrim))
  
  cat("\nProbabilites a priori des classes:\n")
  print(lda_model_class$prior)
  
  lda_predictions <- predict(lda_model_class, lda_features)
  lda_reduced <- as.data.frame(lda_predictions$x)
  
  cat(sprintf("\nDimensions reduites par LDA: %d documents x %d discriminantes\n", nrow(lda_reduced), ncol(lda_reduced)))
}
```

#### 6.3 Analyse Discriminante du Noyau (Kernel Discriminant Analysis - KDA)

La LDA part du principe que les classes sont séparables par des frontières linéaires. Mais que se passe-t-il si les relations sont plus complexes, non-linéaires ? C'est là qu'intervient la **KDA**.

L'idée de la KDA est d'utiliser une "astuce du noyau" (kernel trick) pour projeter les données dans un espace de dimension beaucoup plus grande, où l'on espère qu'elles deviendront linéairement séparables. On applique ensuite une LDA classique dans ce nouvel espace.

J'ai testé cette approche pour voir si elle apportait un gain par rapport à la LDA simple. C'est une bonne pratique pour vérifier si une approche linéaire est suffisante.

```{r}
if (!require("kernlab", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("kernlab")
}
library(kernlab)

if (!is.null(y_label)) {
  taille1 <- length(y_label)
  taille2 <- nrow(combined_features)
  if (taille1 != taille2) {
    cat(sprintf("Correction a la volee: y_label filtre pour correspondre a combined_features\n"))
    y_label <- y_label[1:taille2]
  }

  cat("Entrainement du modele Kernel Discriminant Analysis...\n")
  
  kda_features <- as.matrix(combined_features)
  kda_target <- factor(y_label)
  
  nb_feat <- ncol(kda_features) - 1
  if (nb_feat > 100) {
    nb_feat <- 100
  }
  kda_model <- kpca(kda_features, kernel = "rbfdot", features = nb_feat, kpar = list(sigma = 0.01))
  
  cat("Modele KDA entraine avec succes!\n")
  nb_comp <- ncol(kda_model@pcv)
  cat(sprintf("Composantes du noyau: %d\n", nb_comp))
  
  kda_reduced <- as.data.frame(kda_model@pcv)
  noms_kda <- c()
  for (k in 1:ncol(kda_reduced)) {
    noms_kda <- c(noms_kda, paste0("KPC_", k))
  }
  colnames(kda_reduced) <- noms_kda
  
  cat(sprintf("Dimensions reduites par KDA: %d documents x %d composantes du noyau\n", nrow(kda_reduced), ncol(kda_reduced)))
}
```

#### 6.4 Comparaison des approches de réduction

Après avoir testé les deux méthodes, il faut faire un choix. La LDA est plus simple, plus rapide et beaucoup plus facile à interpréter. La KDA est plus puissante mais aussi plus complexe et plus coûteuse en calculs.

Pour un premier essai, et comme la LDA est déjà très performante pour les données textuelles, j'ai décidé de conserver les caractéristiques issues de la **LDA** pour la suite de l'analyse. On dispose maintenant d'un jeu de données avec un petit nombre de caractéristiques très informatives, prêtes pour la classification.

```{r}
if (!is.null(y_label)) {
  cat("\n========== RESUME DE LA REDUCTION DE DIMENSIONNALITE ==========\n")
  cat(sprintf("Dimensions originales: %d caracteristiques\n", ncol(combined_features)))
  cat(sprintf("LDA: %d discriminantes\n", ncol(lda_reduced)))
  cat(sprintf("KDA: %d composantes du noyau\n", ncol(kda_reduced)))
  
  taille_y <- length(y_label)
  taille_lda <- nrow(lda_reduced)
  if (taille_y != taille_lda) {
    warning_msg <- sprintf("Attention: y_label (%d) != lda_reduced (%d)", taille_y, taille_lda)
    cat(sprintf("%s\n", warning_msg))
    y_label <- y_label[1:taille_lda]
  }
  
  final_features <- lda_reduced
  final_features$target <- factor(y_label)
  
  cat("\nCaracteristiques reduites selectionnees: LDA\n")
  cat(sprintf("Pret pour la classification bayesienne avec %d dimensions\n", ncol(lda_reduced)))
} else {
  cat("Utilisation des caracteristiques combinees originales faute de variable cible.\n")
  final_features <- as.data.frame(combined_features)
}
```



### <FONT color='#0066CC'><FONT size = 4> 7 Classification bayésienne </FONT></FONT>

#### 7.1 Classificateur Naive Bayes

Maintenant que nos données sont prêtes et que la dimensionnalité a été réduite, on peut passer à la classification. J'ai choisi de commencer avec un classificateur **Naive Bayes** (ou "Bayésien naïf").

C'est un modèle probabiliste simple mais souvent très efficace, surtout pour le texte. Il se base sur le théorème de Bayes et fait une hypothèse forte (et un peu "naïve", d'où son nom) : il suppose que toutes les caractéristiques (nos discriminantes LDA) sont indépendantes les unes des autres. Même si cette hypothèse est rarement vraie en pratique, le modèle donne de très bons résultats.

Pour l'entraîner et l'évaluer, j'ai divisé les données : 80% pour l'entraînement du modèle et 20% pour le tester et mesurer sa performance sur des données qu'il n'a jamais vues.

```{r}
if (!require("e1071", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("e1071")
}
library(e1071)

if (!is.null(y_label)) {
  cat("========== CLASSIFICATEUR NAIVE BAYES ==========\n")
  
  nb_data <- final_features
  noms <- colnames(nb_data)
  noms[length(noms)] <- "target"
  colnames(nb_data) <- noms
  
  set.seed(42)
  n <- nrow(nb_data)
  nb_train <- round(0.8 * n)
  indices <- 1:n
  train_idx <- sample(indices, size = nb_train)
  
  train_data <- nb_data[train_idx, ]
  test_data <- nb_data[-train_idx, ]
  
  cat(sprintf("Ensemble d'entrainement: %d documents\n", nrow(train_data)))
  cat(sprintf("Ensemble de test: %d documents\n", nrow(test_data)))
  
  cat("\nEntrainement du modele Naive Bayes...\n")
  nb_model <- naiveBayes(target ~ ., data = train_data, laplace = 1)
  
  cat("Modele Naive Bayes entraine avec succes!\n")
  
  nb_pred <- predict(nb_model, test_data, type = "class")
  nb_pred_prob <- predict(nb_model, test_data, type = "raw")
  
  nb_correct <- 0
  for (i in 1:length(nb_pred)) {
    if (nb_pred[i] == test_data$target[i]) {
      nb_correct <- nb_correct + 1
    }
  }
  nb_accuracy <- nb_correct / length(nb_pred)
  cat(sprintf("\nExactitude Naive Bayes: %.2f%%\n", nb_accuracy * 100))
  
  nb_results <- list(model = nb_model, predictions = nb_pred, probabilities = nb_pred_prob, accuracy = nb_accuracy, test_data = test_data)
}
```

#### 7.2 Modèles de Classification Avancés

Puisque Naive Bayes seul ne suffit pas (~ 12% de précision), j'explore des **modèles bayésiens et non-bayésiens avancés** qui gèrent mieux la haute dimension et l'imbalance de classes. Parmi ceux-ci, le **SVM (Support Vector Machine)** offre une excellente performance en haute dimension, le **Random Forest** s'avère robuste aux données imbalancées, et le **LightGBM** propose un gradient boosting très efficace.

```{r}
options(repos = c(CRAN = "https://cloud.r-project.org"))

if (!require("e1071", quietly = TRUE)) {
  install.packages("e1071")
}
library(e1071)

if (!require("randomForest", quietly = TRUE)) {
  install.packages("randomForest")
}
library(randomForest)

if (!require("caret", quietly = TRUE)) {
  install.packages("caret")
}
library(caret)

if (!require("lightgbm", quietly = TRUE)) {
  tryCatch({
    install.packages("lightgbm")
    library(lightgbm)
  }, error = function(e) {
    cat("LightGBM non disponible, utilisation de SVM et Random Forest uniquement\n")
  })
}

if (!is.null(y_label)) {
  cat("\n========== MODELES AVANCES DE CLASSIFICATION MULTI-CLASSE ==========\n")
  
  nb_col_train <- ncol(train_data)
  X_train = as.matrix(train_data[, 1:(nb_col_train-1)])
  y_train = train_data$target
  nb_col_test <- ncol(test_data)
  X_test = as.matrix(test_data[, 1:(nb_col_test-1)])
  y_test = test_data$target
  
  class_counts <- table(y_train)
  has_zero <- FALSE
  for (cnt in class_counts) {
    if (cnt == 0) {
      has_zero <- TRUE
    }
  }
  if (has_zero == TRUE) {
    noms_valides <- names(class_counts[class_counts > 0])
    y_train = factor(y_train, levels = noms_valides)
    y_test = factor(y_test, levels = levels(y_train))
  }
  
  advanced_models_results <- list()
  
  cat("\n--- 1. SVM (Support Vector Machine) avec noyau RBF ---\n")
  tryCatch({
    df_train_svm = data.frame(y_train = y_train, X_train)
    svm_model <- svm(y_train ~ ., data = df_train_svm, kernel = "radial", cost = 10, probability = TRUE)
    
    df_test_svm = data.frame(X_test)
    svm_pred <- predict(svm_model, df_test_svm)
    
    svm_correct <- 0
    for (i in 1:length(svm_pred)) {
      if (!is.na(svm_pred[i]) && !is.na(y_test[i])) {
        if (svm_pred[i] == y_test[i]) {
          svm_correct = svm_correct + 1
        }
      }
    }
    svm_accuracy <- svm_correct / length(svm_pred)
    
    if (!is.na(svm_accuracy)) {
      cat(sprintf("SVM Exactitude: %.2f%%\n", svm_accuracy * 100))
      advanced_models_results[["SVM"]] = list(model = svm_model, predictions = svm_pred, accuracy = svm_accuracy, test_data = y_test, confusion_matrix = confusionMatrix(svm_pred, y_test))
    } else {
      cat("SVM Exactitude: NA (erreur de prediction)\n")
    }
  }, error = function(e) {
    cat(sprintf("Erreur SVM: %s\n", e$message))
  })
  
  cat("\n--- 2. Random Forest ---\n")
  tryCatch({
    df_train_rf = data.frame(y_train = y_train, X_train)
    nb_var <- ncol(X_train)
    mtry_val <- floor(sqrt(nb_var))
    if (mtry_val < 1) {
      mtry_val <- 1
    }
    rf_model <- randomForest(y_train ~ ., data = df_train_rf, ntree = 100, mtry = mtry_val, importance = TRUE)
    
    df_test_rf = data.frame(X_test)
    rf_pred <- predict(rf_model, df_test_rf)
    
    rf_correct <- 0
    for (i in 1:length(rf_pred)) {
      if (!is.na(rf_pred[i]) && !is.na(y_test[i])) {
        if (rf_pred[i] == y_test[i]) {
          rf_correct = rf_correct + 1
        }
      }
    }
    rf_accuracy <- rf_correct / length(rf_pred)
    
    if (!is.na(rf_accuracy)) {
      cat(sprintf("Random Forest Exactitude: %.2f%%\n", rf_accuracy * 100))
      advanced_models_results[["RandomForest"]] = list(model = rf_model, predictions = rf_pred, accuracy = rf_accuracy, test_data = y_test, confusion_matrix = confusionMatrix(rf_pred, y_test))
    } else {
      cat("Random Forest Exactitude: NA (erreur de prediction)\n")
    }
  }, error = function(e) {
    cat(sprintf("Erreur Random Forest: %s\n", e$message))
  })
  
  lgb_available <- requireNamespace("lightgbm", quietly = TRUE)
  if (lgb_available == TRUE) {
    cat("\n--- 3. LightGBM (Gradient Boosting) ---\n")
    tryCatch({
      labels_lgb = as.numeric(y_train) - 1
      train_data_lgb = lgb.Dataset(X_train, label = labels_lgb)
      
      nb_class = length(levels(y_train))
      params = list(objective = "multiclass", num_class = nb_class, metric = "multi_error", num_leaves = 31, learning_rate = 0.05)
      
      lgb_model = lgb.train(params, train_data_lgb, nrounds = 100, verbose = -1)
      
      lgb_pred_prob <- predict(lgb_model, X_test, reshape = TRUE)
      lgb_pred_idx = c()
      for (row in 1:nrow(lgb_pred_prob)) {
        max_idx = which.max(lgb_pred_prob[row, ])
        lgb_pred_idx = c(lgb_pred_idx, max_idx)
      }
      lgb_pred <- factor(levels(y_train)[lgb_pred_idx], levels = levels(y_train))
      
      lgb_correct <- 0
      for (i in 1:length(lgb_pred)) {
        if (!is.na(lgb_pred[i]) && !is.na(y_test[i])) {
          if (lgb_pred[i] == y_test[i]) {
            lgb_correct = lgb_correct + 1
          }
        }
      }
      lgb_accuracy <- lgb_correct / length(lgb_pred)
      
      if (!is.na(lgb_accuracy)) {
        cat(sprintf("LightGBM Exactitude: %.2f%%\n", lgb_accuracy * 100))
        advanced_models_results[["LightGBM"]] = list(model = lgb_model, predictions = lgb_pred, accuracy = lgb_accuracy, test_data = y_test, confusion_matrix = confusionMatrix(lgb_pred, y_test))
      } else {
        cat("LightGBM Exactitude: NA (erreur de prediction)\n")
      }
    }, error = function(e) {
      cat(sprintf("Erreur LightGBM: %s\n", e$message))
    })
  }
  
  cat("\n========== RESUME DE COMPARAISON ==========\n")
  nb_models = length(advanced_models_results)
  if (nb_models > 0) {
    model_comparison = data.frame()
    noms_modeles <- names(advanced_models_results)
    for (i in 1:length(noms_modeles)) {
      nom <- noms_modeles[i]
      acc <- advanced_models_results[[nom]]$accuracy * 100
      ligne = data.frame(Modele = nom, Exactitude = acc)
      model_comparison <- rbind(model_comparison, ligne)
    }
    print(model_comparison)
    
    if (nrow(model_comparison) > 0) {
      best_advanced_idx = which.max(model_comparison$Exactitude)
      best_advanced_name <- model_comparison$Modele[best_advanced_idx]
      best_advanced_accuracy <- model_comparison$Exactitude[best_advanced_idx]
      cat(sprintf("\nMeilleur modele avance: %s (Exactitude: %.2f%%)\n", best_advanced_name, best_advanced_accuracy))
    }
  } else {
    cat("Aucun modele avance n'a pu etre entraine avec succes\n")
  }
}
```


#### 7.3 Comparaison des modèles bayésiens

Comparons maintenant les deux approches bayésiennes : Naive Bayes et Régression Logistique Multinomiale Ridge.

```{r}
if (!is.null(y_label)) {
  cat("\n========== COMPARAISON GLOBALE: TOUS LES MODELES ==========\n")
  
  comparison_results = data.frame(Modele = c("Naive Bayes"), Exactitude = c(nb_results$accuracy * 100))
  
  if (exists("advanced_models_results")) {
    nb_adv = length(advanced_models_results)
    if (nb_adv > 0) {
      noms = names(advanced_models_results)
      i <- 1
      while (i <= length(noms)) {
        nom = noms[i]
        acc <- advanced_models_results[[nom]]$accuracy * 100
        nouvelle_ligne = data.frame(Modele = nom, Exactitude = acc)
        comparison_results <- rbind(comparison_results, nouvelle_ligne)
        i = i + 1
      }
    }
  }
  
  cat("\nResultats de tous les modeles:\n")
  print(comparison_results)
  
  best_model_idx = which.max(comparison_results$Exactitude)
  best_model_name <- comparison_results$Modele[best_model_idx]
  best_accuracy <- comparison_results$Exactitude[best_model_idx]
  
  cat(sprintf("\nMEILLEUR MODELE: %s (Exactitude: %.2f%%)\n", best_model_name, best_accuracy))
  
  if (best_model_name == "Naive Bayes") {
    nb_confusion <- confusionMatrix(nb_pred, test_data$target)
    final_model <- list(model = nb_results$model, predictions = nb_pred, accuracy = nb_results$accuracy, confusion_matrix = nb_confusion, type = "Naive Bayes")
    final_predictions <- nb_pred
    final_probabilities <- nb_pred_prob
    selected_model_name <- "Naive Bayes"
  } else {
    if (exists("advanced_models_results")) {
      est_present <- best_model_name %in% names(advanced_models_results)
      if (est_present == TRUE) {
        final_model <- advanced_models_results[[best_model_name]]
        final_predictions <- advanced_models_results[[best_model_name]]$predictions
        final_probabilities <- NULL
        selected_model_name <- best_model_name
      }
    }
  }
  
  cat(sprintf("\nModele selectionne pour l'analyse approfondie: %s\n", selected_model_name))
}
```

#### 7.4 Matrice de confusion et métriques détaillées du meilleur modèle

L'exactitude globale donne une première impression, mais pour vraiment com prendre les performances du modèle, nous analysons la **matrice de confusion** et les métriques détaillées.

Cette matrice croise les vraies classes avec les classes prédites :
- Les **vrais positifs** (bien classés) se trouvent sur la diagonale
- Les **faux positifs** et **faux négatifs** (les erreurs) se situent en dehors de la diagonale

Cela permet d'identifier les classes que le modèle confond, et de calculer des métriques telles que **précision**, **recall (sensibilité)** et **score F1** pour chaque cluster d'étude.

```{r}
if (!is.null(y_label)) {
  cat("\n========== ANALYSE DU MEILLEUR MODELE ==========\n")
  
  cat(sprintf("\nMatrice de confusion - %s:\n", selected_model_name))
  print(final_model$confusion_matrix$table)
  
  cat("\nResume des metriques globales:\n")
  print(final_model$confusion_matrix$overall)
  
  cat("\nMetriques par classe (Sensibilite, Specificite, etc.):\n")
  print(final_model$confusion_matrix$byClass)
}
```

### <FONT color='#0066CC'><FONT size = 4> 8 Optimisation et validation du modèle </FONT></FONT>

#### 8.1 Validation Croisée Stratifiée (Stratified K-Fold Cross-Validation)

La performance mesurée sur l'ensemble de test de 20% dépend du hasard de la séparation train/test. Pour avoir une estimation plus robuste et fiable, nous utilisons la **validation croisée stratifiée**.

Cette méthode découpe les données en 5 "plis" (folds) et répète l'entraînement 5 fois, chaque fois en utilisant 4 plis pour l'entraînement et 1 pour le test. Le score final est la moyenne de ces 5 scores, donnant une bien meilleure idée de la généralisabilité du modèle. La stratification assure que chaque pli contient la même proportion de chaque classe.

```{r}
if (!require("caret", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("caret")
}
library(caret)

if (!is.null(y_label) && exists("final_model")) {
  cat("\n========== VALIDATION CROISEE STRATIFIEE ==========\n")
  cat(sprintf("Strategie: %s\n\n", selected_model_name))
  
  set.seed(42)
  
  nb_col <- ncol(final_features)
  X = as.matrix(final_features[, 1:(nb_col-1)])
  y = final_features$target
  
  folds <- createFolds(y, k = 5, list = TRUE, returnTrain = FALSE)
  
  cv_accuracies = c()
  
  i <- 1
  while (i <= length(folds)) {
    cat(sprintf("  Fold %d/%d... ", i, length(folds)))
    
    test_idx <- folds[[i]]
    
    X_train_cv = X[-test_idx, ]
    X_test_cv = X[test_idx, ]
    y_train_cv = y[-test_idx]
    y_test_cv = y[test_idx]
    
    tryCatch({
      df_train = data.frame(y_train_cv = y_train_cv, X_train_cv)
      df_test = data.frame(X_test_cv)
      
      if (selected_model_name == "Naive Bayes") {
        model_fold <- naiveBayes(y_train_cv ~ ., data = df_train)
        pred_fold <- predict(model_fold, df_test)
      } else if (selected_model_name == "SVM") {
        model_fold <- svm(y_train_cv ~ ., data = df_train, kernel = "radial", cost = 10)
        pred_fold <- predict(model_fold, df_test)
      } else if (selected_model_name == "RandomForest") {
        mtry_val <- floor(sqrt(ncol(X_train_cv)))
        if (mtry_val < 1) { mtry_val <- 1 }
        model_fold <- randomForest(y_train_cv ~ ., data = df_train, ntree = 100, mtry = mtry_val)
        pred_fold <- predict(model_fold, df_test)
      } else if (selected_model_name == "LightGBM") {
        lgb_ok <- requireNamespace("lightgbm", quietly = TRUE)
        if (lgb_ok == TRUE) {
          train_lgb = lgb.Dataset(X_train_cv, label = as.numeric(y_train_cv) - 1)
          params = list(objective = "multiclass", num_class = length(levels(y_train_cv)), metric = "multi_error", num_leaves = 31, learning_rate = 0.05)
          lgb_m = lgb.train(params, train_lgb, nrounds = 100, verbose = -1)
          prob = predict(lgb_m, X_test_cv, reshape = TRUE)
          pred_idx = c()
          for (r in 1:nrow(prob)) { pred_idx = c(pred_idx, which.max(prob[r, ])) }
          pred_fold = factor(levels(y_train_cv)[pred_idx], levels = levels(y_train_cv))
        } else {
          model_fold <- naiveBayes(y_train_cv ~ ., data = df_train)
          pred_fold <- predict(model_fold, df_test)
        }
      } else {
        model_fold <- naiveBayes(y_train_cv ~ ., data = df_train)
        pred_fold <- predict(model_fold, df_test)
      }
      
      nb_correct <- 0
      for (j in 1:length(pred_fold)) {
        if (!is.na(pred_fold[j]) && !is.na(y_test_cv[j])) {
          if (pred_fold[j] == y_test_cv[j]) { nb_correct <- nb_correct + 1 }
        }
      }
      acc <- nb_correct / length(pred_fold)
      cv_accuracies = c(cv_accuracies, acc)
      cat(sprintf("Acc=%.4f\n", acc))
    }, error = function(e) {
      cat(sprintf("Erreur: %s\n", e$message))
    })
    
    i = i + 1
  }
  
  cat(sprintf("\nValidation croisee terminee!\n"))
  nb_res = length(cv_accuracies)
  if (nb_res > 0) {
    moy = mean(cv_accuracies)
    ecart = sd(cv_accuracies)
    cat(sprintf("Exactitude CV moyenne: %.4f (+/-%.4f)\n", moy, ecart))
    cat(sprintf("Range: %.4f - %.4f\n", min(cv_accuracies), max(cv_accuracies)))
    cv_results = list(accuracies = cv_accuracies, accuracy_mean = moy, accuracy_sd = ecart)
  } else {
    cat("Aucun resultat CV disponible\n")
  }
}
```

#### 8.2 Grid Search pour tester plusieurs combinaisons d'hyperparamètres

Le **Grid Search** est une technique exhaustive qui teste toutes les combinaisons possibles d'hyperparamètres dans un espace défini. Bien que coûteuse en calculs, elle garantit de trouver la meilleure combinaison dans l'espace d'exploration.

Pour la classification de texte, les hyperparamètres critiques varient selon l'algorithme :
- **Naive Bayes :** Peu d'hyperparamètres, mais on peut ajuster le lissage
- **SVM :** Paramètre de régularisation (C) et largeur du kernel (sigma)
- **Random Forest :** Nombre de variables par split (mtry) et nombre d'arbres (ntree)

```{r}
if (!require("caret", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("caret")
}
library(caret)

if (!is.null(y_label) && exists("final_features")) {
  cat("\n========== GRID SEARCH: TESTER LES HYPERPARAMETRES ==========\n")
  
  set.seed(42)
  nb_col <- ncol(final_features)
  X = as.matrix(final_features[, 1:(nb_col-1)])
  y = final_features$target
  
  grid_search_results = list()
  
  cat("\n--- SVM: Recherche sur C et sigma ---\n")
  
  tryCatch({
    C_values = c(0.1, 1, 10)
    sigma_values = c(0.01, 0.1, 1)
    svm_grid = expand.grid(C = C_values, sigma = sigma_values)
    
    cat(sprintf("Nombre de combinaisons a tester: %d\n", nrow(svm_grid)))
    cat("Combinaisons d'hyperparametres:\n")
    print(svm_grid)
    
    svm_grid_results = data.frame()
    
    i <- 1
    while (i <= nrow(svm_grid)) {
      C_val = svm_grid$C[i]
      sigma_val = svm_grid$sigma[i]
      
      cat(sprintf("\n  Test %d/%d - C=%.2f, sigma=%.4f... ", i, nrow(svm_grid), C_val, sigma_val))
      
      tryCatch({
        df_temp = data.frame(y = y, X)
        model_temp = svm(y ~ ., data = df_temp, kernel = "radial", C = C_val, gamma = sigma_val)
        
        pred_temp = predict(model_temp, data.frame(X))
        nb_ok <- 0
        for (j in 1:length(pred_temp)) {
          if (!is.na(pred_temp[j]) && !is.na(y[j])) {
            if (pred_temp[j] == y[j]) { nb_ok = nb_ok + 1 }
          }
        }
        accuracy_temp <- nb_ok / length(pred_temp)
        
        nouvelle_ligne = data.frame(C = C_val, sigma = sigma_val, Accuracy = accuracy_temp)
        svm_grid_results <- rbind(svm_grid_results, nouvelle_ligne)
        cat(sprintf("Acc=%.4f\n", accuracy_temp))
      }, error = function(e) {
        cat("Erreur\n")
      })
      
      i = i + 1
    }
    
    if (nrow(svm_grid_results) > 0) {
      best_svm_idx = which.max(svm_grid_results$Accuracy)
      best_svm_params <- svm_grid_results[best_svm_idx, ]
      cat(sprintf("\nMeilleur SVM: C=%.2f, sigma=%.4f (Acc=%.4f)\n", best_svm_params$C, best_svm_params$sigma, best_svm_params$Accuracy))
      grid_search_results[["SVM"]] = list(grid = svm_grid_results, best_params = best_svm_params)
    }
  }, error = function(e) {
    cat(sprintf("Erreur Grid Search SVM: %s\n", e$message))
  })
  
  cat("\n--- Random Forest: Recherche sur mtry et ntree ---\n")
  
  tryCatch({
    mtry_values = c(5, 10, 20)
    ntree_values = c(50, 100, 200)
    rf_grid = expand.grid(mtry = mtry_values, ntree = ntree_values)
    
    cat(sprintf("Nombre de combinaisons a tester: %d\n", nrow(rf_grid)))
    cat("Combinaisons d'hyperparametres:\n")
    print(rf_grid)
    
    rf_grid_results = data.frame()
    
    i <- 1
    while (i <= nrow(rf_grid)) {
      mtry_val = rf_grid$mtry[i]
      ntree_val = rf_grid$ntree[i]
      
      cat(sprintf("\n  Test %d/%d - mtry=%d, ntree=%d... ", i, nrow(rf_grid), mtry_val, ntree_val))
      
      tryCatch({
        df_temp = data.frame(y = y, X)
        model_temp = randomForest(y ~ ., data = df_temp, mtry = mtry_val, ntree = ntree_val)
        
        pred_temp = predict(model_temp, data.frame(X))
        nb_ok <- 0
        for (j in 1:length(pred_temp)) {
          if (!is.na(pred_temp[j]) && !is.na(y[j])) {
            if (pred_temp[j] == y[j]) { nb_ok = nb_ok + 1 }
          }
        }
        accuracy_temp <- nb_ok / length(pred_temp)
        
        nouvelle_ligne = data.frame(mtry = mtry_val, ntree = ntree_val, Accuracy = accuracy_temp)
        rf_grid_results <- rbind(rf_grid_results, nouvelle_ligne)
        cat(sprintf("Acc=%.4f\n", accuracy_temp))
      }, error = function(e) {
        cat("Erreur\n")
      })
      
      i = i + 1
    }
    
    if (nrow(rf_grid_results) > 0) {
      best_rf_idx = which.max(rf_grid_results$Accuracy)
      best_rf_params <- rf_grid_results[best_rf_idx, ]
      cat(sprintf("\nMeilleur Random Forest: mtry=%d, ntree=%d (Acc=%.4f)\n", best_rf_params$mtry, best_rf_params$ntree, best_rf_params$Accuracy))
      grid_search_results[["RandomForest"]] = list(grid = rf_grid_results, best_params = best_rf_params)
    }
  }, error = function(e) {
    cat(sprintf("Erreur Grid Search Random Forest: %s\n", e$message))
  })
  
  cat("\n========== RESUME GRID SEARCH ==========\n")
  nb_algos = length(grid_search_results)
  cat(sprintf("Nombre d'algorithmes testes: %d\n", nb_algos))
  
  if (nb_algos > 0) {
    cat("\nMeilleures performances par algorithme:\n")
    noms_algos = names(grid_search_results)
    for (i in 1:length(noms_algos)) {
      nom = noms_algos[i]
      best_acc <- grid_search_results[[nom]]$best_params$Accuracy
      cat(sprintf("  %s: %.4f\n", nom, best_acc))
    }
  }
}
```

#### 8.3 Validation croisée interne pour évaluer chaque combinaison

Pour une évaluation plus robuste des hyperparamètres, nous utilisons la **validation croisée interne**. Cela signifie que pour chaque combinaison de Grid Search, nous effectuons une validation croisée 5-fold sur l'ensemble d'entraînement, plutôt que de mesurer simplement sur l'ensemble complet.

Cette approche réduit le risque de surapprentissage des hyperparamètres et donne une meilleure estimation de la performance réelle.

```{r}
if (!is.null(y_label) && exists("final_features")) {
  cat("\n========== VALIDATION CROISEE INTERNE (5-Fold CV) ==========\n")
  
  set.seed(42)
  nb_col <- ncol(final_features)
  X = as.matrix(final_features[, 1:(nb_col-1)])
  y = final_features$target
  
  folds_cv <- createFolds(y, k = 5, list = TRUE, returnTrain = FALSE)
  
  cv_internal_results = list()
  
  cat("\n--- SVM: Validation croisee interne sur Grid Search ---\n")
  
  svm_dans_grid <- FALSE
  if (exists("grid_search_results")) {
    if ("SVM" %in% names(grid_search_results)) {
      svm_dans_grid <- TRUE
    }
  }
  
  if (svm_dans_grid == TRUE) {
    svm_cv_results = data.frame()
    svm_grid <- grid_search_results[["SVM"]]$grid
    
    row_idx <- 1
    while (row_idx <= nrow(svm_grid)) {
      C_val = svm_grid$C[row_idx]
      sigma_val = svm_grid$sigma[row_idx]
      
      cv_accs = c()
      
      fold_idx <- 1
      while (fold_idx <= length(folds_cv)) {
        test_idx <- folds_cv[[fold_idx]]
        X_train_cv = X[-test_idx, ]
        X_test_cv = X[test_idx, ]
        y_train_cv = y[-test_idx]
        y_test_cv = y[test_idx]
        
        tryCatch({
          df_cv = data.frame(y_train_cv = y_train_cv, X_train_cv)
          model_cv = svm(y_train_cv ~ ., data = df_cv, kernel = "radial", C = C_val, gamma = sigma_val)
          pred_cv = predict(model_cv, data.frame(X_test_cv))
          nb_ok <- 0
          for (k in 1:length(pred_cv)) {
            if (!is.na(pred_cv[k]) && !is.na(y_test_cv[k])) {
              if (pred_cv[k] == y_test_cv[k]) { nb_ok = nb_ok + 1 }
            }
          }
          acc_cv <- nb_ok / length(pred_cv)
          cv_accs = c(cv_accs, acc_cv)
        }, error = function(e) {})
        
        fold_idx = fold_idx + 1
      }
      
      if (length(cv_accs) > 0) {
        mean_acc = mean(cv_accs)
        sd_acc = sd(cv_accs)
        ligne = data.frame(C = C_val, sigma = sigma_val, CV_Mean = mean_acc, CV_SD = sd_acc)
        svm_cv_results <- rbind(svm_cv_results, ligne)
        cat(sprintf("  C=%.2f, sigma=%.4f: Moyenne=%.4f (+/-%.4f)\n", C_val, sigma_val, mean_acc, sd_acc))
      }
      
      row_idx = row_idx + 1
    }
    
    if (nrow(svm_cv_results) > 0) {
      best_svm_cv_idx = which.max(svm_cv_results$CV_Mean)
      best_svm_cv <- svm_cv_results[best_svm_cv_idx, ]
      cat(sprintf("\nMeilleur SVM (CV): C=%.2f, sigma=%.4f (Moyenne CV=%.4f)\n", best_svm_cv$C, best_svm_cv$sigma, best_svm_cv$CV_Mean))
      cv_internal_results[["SVM"]] = svm_cv_results
    }
  }
  
  cat("\n--- Random Forest: Validation croisee interne sur Grid Search ---\n")
  
  rf_dans_grid <- FALSE
  if (exists("grid_search_results")) {
    if ("RandomForest" %in% names(grid_search_results)) {
      rf_dans_grid <- TRUE
    }
  }
  
  if (rf_dans_grid == TRUE) {
    rf_cv_results = data.frame()
    rf_grid <- grid_search_results[["RandomForest"]]$grid
    
    nb_max = nrow(rf_grid)
    if (nb_max > 3) { nb_max <- 3 }
    rf_grid_subset <- rf_grid[1:nb_max, ]
    
    row_idx <- 1
    while (row_idx <= nrow(rf_grid_subset)) {
      mtry_val = rf_grid_subset$mtry[row_idx]
      ntree_val = rf_grid_subset$ntree[row_idx]
      
      cv_accs = c()
      
      fold_idx <- 1
      while (fold_idx <= length(folds_cv)) {
        test_idx <- folds_cv[[fold_idx]]
        X_train_cv = X[-test_idx, ]
        X_test_cv = X[test_idx, ]
        y_train_cv = y[-test_idx]
        y_test_cv = y[test_idx]
        
        tryCatch({
          df_cv = data.frame(y_train_cv = y_train_cv, X_train_cv)
          model_cv = randomForest(y_train_cv ~ ., data = df_cv, mtry = mtry_val, ntree = ntree_val)
          pred_cv = predict(model_cv, data.frame(X_test_cv))
          nb_ok <- 0
          for (k in 1:length(pred_cv)) {
            if (!is.na(pred_cv[k]) && !is.na(y_test_cv[k])) {
              if (pred_cv[k] == y_test_cv[k]) { nb_ok = nb_ok + 1 }
            }
          }
          acc_cv <- nb_ok / length(pred_cv)
          cv_accs = c(cv_accs, acc_cv)
        }, error = function(e) {})
        
        fold_idx = fold_idx + 1
      }
      
      if (length(cv_accs) > 0) {
        mean_acc = mean(cv_accs)
        sd_acc = sd(cv_accs)
        ligne = data.frame(mtry = mtry_val, ntree = ntree_val, CV_Mean = mean_acc, CV_SD = sd_acc)
        rf_cv_results <- rbind(rf_cv_results, ligne)
        cat(sprintf("  mtry=%d, ntree=%d: Moyenne=%.4f (+/-%.4f)\n", mtry_val, ntree_val, mean_acc, sd_acc))
      }
      
      row_idx = row_idx + 1
    }
    
    if (nrow(rf_cv_results) > 0) {
      best_rf_cv_idx = which.max(rf_cv_results$CV_Mean)
      best_rf_cv <- rf_cv_results[best_rf_cv_idx, ]
      cat(sprintf("\nMeilleur Random Forest (CV): mtry=%d, ntree=%d (Moyenne CV=%.4f)\n", best_rf_cv$mtry, best_rf_cv$ntree, best_rf_cv$CV_Mean))
      cv_internal_results[["RandomForest"]] = rf_cv_results
    }
  }
  
  cat("\n========== RESUME VALIDATION CROISEE INTERNE ==========\n")
  cat("Les resultats montrent la robustesse de chaque combination d'hyperparametres\n")
  cat("via validation croisee 5-fold, reduisant le risque de surapprentissage.\n")
}
```

#### 8.4 Sélection du meilleur ensemble d'hyperparamètres

Sur la base des résultats du Grid Search et de la validation croisée interne, nous sélectionnons maintenant les **meilleurs hyperparamètres** pour chaque algorithme et comparons les performances finales.

```{r}
if (!is.null(y_label)) {
  cat("\n========== SELECTION DES MEILLEURS HYPERPARAMETRES ==========\n")
  
  set.seed(42)
  nb_col <- ncol(final_features)
  X = as.matrix(final_features[, 1:(nb_col-1)])
  y = final_features$target
  
  train_idx <- createDataPartition(y, p = 0.8, list = FALSE)
  X_train = X[train_idx, ]
  X_test = X[-train_idx, ]
  y_train = y[train_idx]
  y_test = y[-train_idx]
  
  optimized_models = list()
  
  cat("\n--- 1. SVM OPTIMISE ---\n")
  
  svm_present <- FALSE
  if (exists("grid_search_results")) {
    if ("SVM" %in% names(grid_search_results)) {
      svm_present <- TRUE
    }
  }
  
  if (svm_present == TRUE) {
    best_svm_params <- grid_search_results[["SVM"]]$best_params
    
    cat(sprintf("Hyperparametres selectionnes:\n"))
    cat(sprintf("  C = %.2f\n", best_svm_params$C))
    cat(sprintf("  sigma = %.4f\n", best_svm_params$sigma))
    
    tryCatch({
      df_train = data.frame(y_train = y_train, X_train)
      svm_opt = svm(y_train ~ ., data = df_train, kernel = "radial", C = best_svm_params$C, gamma = best_svm_params$sigma)
      
      pred_svm_opt = predict(svm_opt, data.frame(X_test))
      nb_ok <- 0
      for (i in 1:length(pred_svm_opt)) {
        if (!is.na(pred_svm_opt[i]) && !is.na(y_test[i])) {
          if (pred_svm_opt[i] == y_test[i]) { nb_ok = nb_ok + 1 }
        }
      }
      acc_svm_opt <- nb_ok / length(pred_svm_opt)
      
      cat(sprintf("Performance sur test set: %.4f (%.2f%%)\n", acc_svm_opt, acc_svm_opt * 100))
      optimized_models[["SVM_Optimized"]] = list(model = svm_opt, accuracy = acc_svm_opt, params = best_svm_params)
    }, error = function(e) {
      cat(sprintf("Erreur: %s\n", e$message))
    })
  }
  
  cat("\n--- 2. RANDOM FOREST OPTIMISE ---\n")
  
  rf_present <- FALSE
  if (exists("grid_search_results")) {
    if ("RandomForest" %in% names(grid_search_results)) {
      rf_present <- TRUE
    }
  }
  
  if (rf_present == TRUE) {
    best_rf_params <- grid_search_results[["RandomForest"]]$best_params
    
    cat(sprintf("Hyperparametres selectionnes:\n"))
    cat(sprintf("  mtry = %d\n", best_rf_params$mtry))
    cat(sprintf("  ntree = %d\n", best_rf_params$ntree))
    
    tryCatch({
      df_train = data.frame(y_train = y_train, X_train)
      rf_opt = randomForest(y_train ~ ., data = df_train, mtry = best_rf_params$mtry, ntree = best_rf_params$ntree)
      
      pred_rf_opt = predict(rf_opt, data.frame(X_test))
      nb_ok <- 0
      for (i in 1:length(pred_rf_opt)) {
        if (!is.na(pred_rf_opt[i]) && !is.na(y_test[i])) {
          if (pred_rf_opt[i] == y_test[i]) { nb_ok = nb_ok + 1 }
        }
      }
      acc_rf_opt <- nb_ok / length(pred_rf_opt)
      
      cat(sprintf("Performance sur test set: %.4f (%.2f%%)\n", acc_rf_opt, acc_rf_opt * 100))
      optimized_models[["RandomForest_Optimized"]] = list(model = rf_opt, accuracy = acc_rf_opt, params = best_rf_params)
    }, error = function(e) {
      cat(sprintf("Erreur: %s\n", e$message))
    })
  }
  
  cat("\n========== COMPARAISON: HYPERPARAMETRES PAR DEFAUT vs OPTIMISES ==========\n")
  
  comparison_df = data.frame(Algorithme = character(), Config = character(), Exactitude = numeric())
  
  nb_optim = length(optimized_models)
  if (nb_optim > 0) {
    noms = names(optimized_models)
    i <- 1
    while (i <= length(noms)) {
      nom = noms[i]
      nom_clean <- gsub("_Optimized", "", nom)
      acc <- optimized_models[[nom]]$accuracy * 100
      ligne = data.frame(Algorithme = nom_clean, Config = "Optimise", Exactitude = acc)
      comparison_df <- rbind(comparison_df, ligne)
      i = i + 1
    }
    
    cat("\nTableau comparatif:\n")
    print(comparison_df)
    
    if (nrow(comparison_df) > 0) {
      best_opt_idx = which.max(comparison_df$Exactitude)
      best_opt_algo <- comparison_df$Algorithme[best_opt_idx]
      best_opt_acc <- comparison_df$Exactitude[best_opt_idx]
      
      cat(sprintf("\nMEILLEUR MODELE APRES OPTIMISATION:\n"))
      cat(sprintf("   Algorithme: %s\n", best_opt_algo))
      cat(sprintf("   Exactitude: %.2f%%\n", best_opt_acc))
      
      noms = names(optimized_models)
      for (i in 1:length(noms)) {
        nom = noms[i]
        test_match <- grepl(best_opt_algo, nom)
        if (test_match == TRUE) {
          cat(sprintf("\n   Hyperparametres optimaux:\n"))
          params <- optimized_models[[nom]]$params
          noms_params = names(params)
          for (j in 1:length(noms_params)) {
            param_name <- noms_params[j]
            if (param_name != "Accuracy") {
              cat(sprintf("     %s = %s\n", param_name, params[[param_name]]))
            }
          }
        }
      }
    }
  } else {
    cat("Aucun modele optimise disponible\n")
  }
}
```


### <FONT color='#0066CC'><FONT size = 4> 9 Performance Evaluation </FONT></FONT>

#### 9.1 Métriques de Performance Globales

Cette évaluation finale exhaustive utilise le meilleur modèle sélectionné pour calculer toutes les métriques pertinentes. Les métriques reportées incluent l'exactitude (% global de prédictions correctes), le Kappa (exactitude ajustée pour le hasard, de 0 = aléatoire à 1 = parfait), les moyennes macro et pondérées des métriques multi-classe, ainsi que les métriques par classe (sensibilité, spécificité, précision, F1-Score). Un Kappa supérieur à 0.7 indique un excellent accord au-delà du hasard, et le F1 équilibre précision et rappel, ce qui est particulièrement important si les classes sont imbalancées.

```{r}
if (!require("mltools", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("mltools")
}
library(mltools)

if (!require("pROC", quietly = TRUE)) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
  install.packages("pROC")
}
library(pROC)

model_ok <- FALSE
if (!is.null(y_label)) {
  if (exists("final_model")) {
    if (exists("selected_model_name")) {
      model_ok <- TRUE
    }
  }
}

if (model_ok == TRUE) {
  cat("========== METRIQUES DE PERFORMANCE GLOBALES ==========\n")
  cat(sprintf("Modele utilise: %s\n", selected_model_name))
  acc_pct = final_model$accuracy * 100
  cat(sprintf("Exactitude sur test set: %.2f%%\n\n", acc_pct))
  
  cat("Matrice de confusion:\n")
  print(final_model$confusion_matrix$table)
  
  cat("\n========== RESUME DES METRIQUES ==========\n")
  acc_global <- final_model$confusion_matrix$overall['Accuracy']
  kappa_val <- final_model$confusion_matrix$overall['Kappa']
  cat(sprintf("Exactitude globale: %.4f\n", acc_global))
  cat(sprintf("Kappa coefficient: %.4f\n", kappa_val))
  
  n_classes = length(levels(final_model$test_data))
  
  if (n_classes == 2) {
    cat("\n--- METRIQUES POUR CLASSIFICATION BINAIRE ---\n")
    sensitivity <- final_model$confusion_matrix$byClass['Sensitivity']
    specificity <- final_model$confusion_matrix$byClass['Specificity']
    ppv <- final_model$confusion_matrix$byClass['Pos Pred Value']
    npv <- final_model$confusion_matrix$byClass['Neg Pred Value']
    f1 <- final_model$confusion_matrix$byClass['F1']
    cat(sprintf("Sensibilite (Recall): %.4f\n", sensitivity))
    cat(sprintf("Specificite: %.4f\n", specificity))
    cat(sprintf("Precision (PPV): %.4f\n", ppv))
    cat(sprintf("Valeur Predictive Negative (NPV): %.4f\n", npv))
    cat(sprintf("Score F1: %.4f\n", f1))
  } else {
    cat("\n--- METRIQUES POUR CLASSIFICATION MULTI-CLASSE ---\n")
    cat("Moyennes globales:\n")
    
    sens_vals <- final_model$confusion_matrix$byClass[, 'Sensitivity']
    spec_vals <- final_model$confusion_matrix$byClass[, 'Specificity']
    ppv_vals <- final_model$confusion_matrix$byClass[, 'Pos Pred Value']
    f1_vals <- final_model$confusion_matrix$byClass[, 'F1']
    
    sensitivity_mean = mean(sens_vals, na.rm = TRUE)
    specificity_mean = mean(spec_vals, na.rm = TRUE)
    ppv_mean = mean(ppv_vals, na.rm = TRUE)
    f1_mean = mean(f1_vals, na.rm = TRUE)
    
    cat(sprintf("Sensibilite moyenne: %.4f\n", sensitivity_mean))
    cat(sprintf("Specificite moyenne: %.4f\n", specificity_mean))
    cat(sprintf("Precision moyenne: %.4f\n", ppv_mean))
    cat(sprintf("Score F1 moyen: %.4f\n", f1_mean))
    
    cat("\nMetriques par classe:\n")
    metrics_df = as.data.frame(final_model$confusion_matrix$byClass)
    print(metrics_df)
  }
  
  global_performance = list(confusion_matrix = final_model$confusion_matrix, predictions = final_predictions, accuracy = final_model$accuracy, model_name = selected_model_name)
}
```

#### 9.2 Courbes ROC-AUC (pour classification binaire)

**Note:** Les courbes ROC-AUC classiques ne s'appliquent que pour une classification binaire. Dans ce projet, nous avons une classification multi-classe (plusieurs domaines d'étude), donc cette approche n'est pas pertinente. Pour évaluer les performances dans un contexte multi-classe, nous utilisons plutôt les matrices de confusion, les rapports de classification détaillés et les heatmaps présentés dans les sections suivantes.

#### 9.3 Rapport de Classification Détaillé

Ce rapport décompose les performances individuelles pour chaque classe de domaine. Le tableau synthétique inclut les TP/FP/FN/TN (vrais/faux positifs et négatifs), la précision (% des prédictions positives correctes, important si le coût des FP est élevé), le rappel (% des vraies positives identifiées, important si le coût des FN est élevé), le F1-Score (moyenne harmonique, meilleur pour gérer l'imbalance) et le support (nombre d'exemples dans chaque classe). Les moyennes agrégées comprennent la macro-moyenne (moyenne simple traitant chaque classe également) et la moyenne pondérée par support (intégrant l'imbalance). Les classes avec un F1 bas indiquent les zones de difficulté du modèle.

```{r}
ok_pour_rapport <- FALSE
if (!is.null(y_label)) {
  if (exists("final_model")) {
    if (exists("final_predictions")) {
      ok_pour_rapport <- TRUE
    }
  }
}

if (ok_pour_rapport == TRUE) {
  cat("\n========== RAPPORT DE CLASSIFICATION DETAILLE ==========\n\n")
  
  class_labels = levels(final_model$test_data)
  
  detailed_report = data.frame()
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    
    binary_target = factor(final_model$test_data == class_name, levels = c(FALSE, TRUE), labels = c("Autre", class_name))
    binary_predictions = factor(final_predictions == class_name, levels = c(FALSE, TRUE), labels = c("Autre", class_name))
    
    cm_binary = confusionMatrix(binary_predictions, binary_target, positive = class_name)
    
    tp <- cm_binary$table[2, 2]
    fp <- cm_binary$table[2, 1]
    fn <- cm_binary$table[1, 2]
    tn <- cm_binary$table[1, 1]
    
    somme_tp_fp = tp + fp
    if (somme_tp_fp > 0) {
      precision <- tp / somme_tp_fp
    } else {
      precision <- 0
    }
    
    somme_tp_fn = tp + fn
    if (somme_tp_fn > 0) {
      recall <- tp / somme_tp_fn
    } else {
      recall <- 0
    }
    
    somme_prec_rec = precision + recall
    if (somme_prec_rec > 0) {
      f1 = 2 * (precision * recall) / somme_prec_rec
    } else {
      f1 <- 0
    }
    
    ligne = data.frame(Classe = class_name, TP = tp, FP = fp, FN = fn, TN = tn, Precision = round(precision, 4), Rappel = round(recall, 4), F1_Score = round(f1, 4), Support = tp + fn)
    detailed_report <- rbind(detailed_report, ligne)
    
    i = i + 1
  }
  
  cat("Rapport par classe:\n")
  print(detailed_report)
  
  cat("\nResume:\n")
  prec_moy = mean(detailed_report$Precision, na.rm = TRUE)
  rappel_moy = mean(detailed_report$Rappel, na.rm = TRUE)
  f1_moy = mean(detailed_report$F1_Score, na.rm = TRUE)
  cat(sprintf("Precision macro-moyenne: %.4f\n", prec_moy))
  cat(sprintf("Rappel macro-moyenne: %.4f\n", rappel_moy))
  cat(sprintf("F1 macro-moyenne: %.4f\n", f1_moy))
  
  classification_report <- detailed_report
}
```

#### 9.4 Analyse des Erreurs de Classification

Le diagnostic des défaillances a pour objectif de comprendre où et comment le modèle se trompe, en répondant à plusieurs questions clés : combien d'erreurs totales avons-nous et quel est le taux d'erreur global ? Quels types d'erreurs observe-t-on, c'est-à-dire quelle classe confond-on avec quelle autre ? Quelle confiance le modèle avait-il lorsqu'il s'est trompé ? Y a-t-il des patterns identifiables dans les erreurs ? La matrice de confusion, en particulier ses éléments hors-diagonale, montre les confusions paires par paires et révèle que une haute confusion symétrique indique des classes sémantiquement proches, tandis qu'une confusion asymétrique suggère que l'une des classes est plus confondante que l'autre. Un point d'action important est que les erreurs accompagnées de précisions élevées correspondent à des hard examples qu'il est utile d'investiguer pour améliorer le modèle.

```{r}
ok_analyse <- FALSE
if (!is.null(y_label)) {
  if (exists("final_model")) {
    if (exists("final_predictions")) {
      ok_analyse <- TRUE
    }
  }
}

if (ok_analyse == TRUE) {
  cat("\n========== ANALYSE DES ERREURS DE CLASSIFICATION ==========\n")
  
  est_matrice <- is.matrix(final_predictions)
  if (est_matrice == TRUE) {
    pred_vec <- as.character(final_predictions[, 1])
  } else {
    pred_vec <- as.character(final_predictions)
  }
  
  true_vec <- as.character(final_model$test_data)
  
  len_pred <- length(pred_vec)
  len_true <- length(true_vec)
  if (len_pred != len_true) {
    cat(sprintf("Avertissement: longueurs differentes (pred: %d, true: %d)\n", len_pred, len_true))
    cat("Utilisation de la longueur minimale...\n")
    if (len_pred < len_true) {
      min_len <- len_pred
    } else {
      min_len <- len_true
    }
    pred_vec <- pred_vec[1:min_len]
    true_vec <- true_vec[1:min_len]
  }
  
  errors <- c()
  for (i in 1:length(pred_vec)) {
    if (is.na(pred_vec[i]) || is.na(true_vec[i])) {
      next
    }
    if (pred_vec[i] != true_vec[i]) {
      errors <- c(errors, i)
    }
  }
  n_errors <- length(errors)
  error_rate <- n_errors / length(true_vec) * 100
  
  cat(sprintf("Nombre d'erreurs: %d sur %d\n", n_errors, length(true_vec)))
  cat(sprintf("Taux d'erreur: %.2f%%\n", error_rate))
  cat(sprintf("Taux de succes: %.2f%%\n", 100 - error_rate))
  
  if (n_errors > 0) {
    cat("\nTypes d'erreurs (premiers 10):\n")
    
    nb_affiche <- n_errors
    if (nb_affiche > 10) { nb_affiche <- 10 }
    
    j <- 1
    while (j <= nb_affiche) {
      idx <- errors[j]
      true_class <- true_vec[idx]
      pred_class <- pred_vec[idx]
      
      est_mat_prob <- is.matrix(final_probabilities)
      if (est_mat_prob == TRUE) {
        confidence <- max(final_probabilities[idx, ]) * 100
      } else {
        confidence <- max(final_probabilities[idx]) * 100
      }
      
      cat(sprintf("  - Vrai: %s, Predit: %s (confiance: %.1f%%)\n", true_class, pred_class, confidence))
      j <- j + 1
    }
    
    if (n_errors > 10) {
      cat(sprintf("  ... et %d autres erreurs\n", n_errors - 10))
    }
  }
  
  cat("\nDistribution des confusions:\n")
  confusion_table <- table(Reel = true_vec, Predit = pred_vec)
  confusion_errors <- confusion_table
  row_names <- rownames(confusion_errors)
  col_names <- colnames(confusion_errors)
  common_names <- intersect(row_names, col_names)
  for (nom in common_names) {
    confusion_errors[nom, nom] <- 0
  }
  print(confusion_errors)
  
  error_analysis <- list(n_errors = n_errors, error_rate = error_rate, error_indices = errors, confusion_matrix = confusion_table)
}
```

### <FONT color='#0066CC'><FONT size = 4> 10 Interprétabilité </FONT></FONT>

#### 10.1 Analyse des Termes Discriminants (TF-IDF)

L'objectif ici est d'identifier les mots et termes qui définissent chaque classe, rendant le modèle interprétable. Pour ce faire, j'applique une approche où pour chaque classe je calcule le poids TF-IDF moyen de chaque terme, puis je classe les termes par importance et extrais les top 15 termes par classe ainsi que les termes uniques qui n'apparaissent pas dans les autres classes. Cette interprétation révèle que les **top termes** forment le vocabulaire caractéristique de la classe, les **termes uniques** constituent un vocabulaire distinctif avec un pouvoir discriminant élevé, et les **termes de haute importance** sont prédictifs et utiles pour la classification. Un insight important est que si une classe n'a pas assez de termes uniques, cela indique que les classes sont sémantiquement similaires, ce qui explique les confusions observées entre elles.

```{r}
if (!is.null(y_label)) {
  cat("========== ANALYSE DES TERMES DISCRIMINANTS ==========\n")
  
  term_names = colnames(dtm_reduced)
  class_labels = levels(final_features$target)
  
  important_terms_by_class = list()
  
  cat("\nTop 15 termes discriminants par classe:\n")
  ligne_egale <- ""
  for (z in 1:80) { ligne_egale = paste0(ligne_egale, "=") }
  cat(ligne_egale, "\n")
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    class_indices = which(final_features$target == class_name)
    
    class_tfidf = tfidf_matrix_reduced[class_indices, , drop = FALSE]
    
    nb_lignes = nrow(class_tfidf)
    if (nb_lignes == 1) {
      term_importance = as.numeric(class_tfidf)
    } else {
      term_importance = colMeans(class_tfidf)
    }
    
    nb_max = length(term_importance)
    if (nb_max > 15) { nb_max <- 15 }
    top_indices = order(term_importance, decreasing = TRUE)[1:nb_max]
    top_terms = term_names[top_indices]
    top_scores = term_importance[top_indices]
    
    if (length(top_terms) > 0) {
      max_imp = max(term_importance)
      freq_classe = round(top_scores / max_imp * 100, 2)
      df_temp = data.frame(Terme = top_terms, Importance_TF_IDF = round(top_scores, 4), Frequence_Classe = freq_classe)
      important_terms_by_class[[class_name]] = df_temp
      
      cat(sprintf("\nCLASSE: %s (%d documents)\n", class_name, nrow(class_tfidf)))
      print(df_temp)
    }
    i = i + 1
  }
  
  cat("\n\nTermes DISCRIMINANTS (specifiques a chaque classe):\n")
  cat(ligne_egale, "\n")
  
  all_class_terms = list()
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    class_indices = which(final_features$target == class_name)
    class_tfidf = tfidf_matrix_reduced[class_indices, , drop = FALSE]
    
    nb_lignes = nrow(class_tfidf)
    if (nb_lignes == 1) {
      term_importance = as.numeric(class_tfidf)
    } else {
      term_importance = colMeans(class_tfidf)
    }
    
    nb_max = length(term_importance)
    if (nb_max > 20) { nb_max <- 20 }
    top_20_indices = order(term_importance, decreasing = TRUE)[1:nb_max]
    all_class_terms[[class_name]] = term_names[top_20_indices]
    i = i + 1
  }
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    other_classes = setdiff(class_labels, class_name)
    other_terms = unique(unlist(all_class_terms[other_classes]))
    unique_terms = setdiff(all_class_terms[[class_name]], other_terms)
    
    nb_unique = length(unique_terms)
    if (nb_unique > 0) {
      cat(sprintf("\nTermes UNIQUES a %s (top 10):\n", class_name))
      nb_affiche <- nb_unique
      if (nb_affiche > 10) { nb_affiche <- 10 }
      j <- 1
      while (j <= nb_affiche) {
        cat(sprintf("  - %s\n", unique_terms[j]))
        j = j + 1
      }
    } else {
      cat(sprintf("\n(Pas de termes uniques pour %s)\n", class_name))
    }
    i = i + 1
  }
  
  terms_analysis <- important_terms_by_class
}
```

#### 10.2 Importance des Rubriques (Topics) par Classe

La dimension thématique est complémentaire aux termes et montre les thèmes latents dominants. Le processus implique, pour chaque classe, de calculer la probabilité moyenne des topics, d'identifier les 3 topics dominants par classe et d'afficher les termes principaux de ces topics. L'interprétation révèle que chaque classe est associée à des thèmes (topics) préférentiels ; lorsque des topics sont communs entre classes, cela indique des confusions probables, tandis que des topics distincts assurent une séparation claire. Par exemple, en comparant une classe Physique avec une classe Chimie, on observe que la Physique s'associe à des topics sur la mécanique, l'énergie et la relativité, tandis que la Chimie s'associe à des topics sur les molécules, les réactions et les éléments ; un faible chevauchement entre ces topics indique que le modèle devrait bien les distinguer.

```{r}
topics_ok <- FALSE
if (!is.null(y_label)) {
  if (exists("topic_probabilities")) {
    topics_ok <- TRUE
  }
}

if (topics_ok == TRUE) {
  cat("\n========== IMPORTANCE DES RUBRIQUES PAR CLASSE ==========\n")
  
  class_labels = levels(final_features$target)
  topic_importance_by_class = list()
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    class_indices = which(final_features$target == class_name)
    
    class_topics = topic_probabilities[class_indices, , drop = FALSE]
    
    nb_lig = nrow(class_topics)
    if (nb_lig == 1) {
      mean_topic_probs = as.numeric(class_topics)
    } else {
      mean_topic_probs = colMeans(class_topics)
    }
    
    top_topic_indices = order(mean_topic_probs, decreasing = TRUE)
    
    noms_topics = c()
    for (t in 1:n_topics) {
      noms_topics = c(noms_topics, paste("Topic", t))
    }
    
    somme_probs = sum(mean_topic_probs)
    contrib = round(mean_topic_probs[top_topic_indices] / somme_probs * 100, 2)
    
    df_topic = data.frame(Topic = noms_topics, Probabilite_Moyenne = round(mean_topic_probs[top_topic_indices], 4), Contribution_Pct = contrib)
    topic_importance_by_class[[class_name]] = df_topic
    
    cat(sprintf("\nCLASSE: %s (%d documents)\n", class_name, nrow(class_topics)))
    print(df_topic)
    
    i = i + 1
  }
  
  cat("\n\nTermes principaux des TOPICS les plus importants:\n")
  ligne_egale <- ""
  for (z in 1:80) { ligne_egale = paste0(ligne_egale, "=") }
  cat(ligne_egale, "\n")
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    cat(sprintf("\n%s:\n", class_name))
    
    class_indices = which(final_features$target == class_name)
    class_topics = topic_probabilities[class_indices, , drop = FALSE]
    
    nb_lig = nrow(class_topics)
    if (nb_lig == 1) {
      mean_topic_probs = as.numeric(class_topics)
    } else {
      mean_topic_probs = colMeans(class_topics)
    }
    
    nb_top <- n_topics
    if (nb_top > 3) { nb_top <- 3 }
    top_3_topics = order(mean_topic_probs, decreasing = TRUE)[1:nb_top]
    
    j <- 1
    while (j <= length(top_3_topics)) {
      topic_idx = top_3_topics[j]
      if (topic_idx <= ncol(terms_per_topic)) {
        terms_t = terms_per_topic[, topic_idx]
        terms_str = paste(terms_t, collapse = ", ")
        cat(sprintf("  Topic %d: %s\n", topic_idx, terms_str))
      }
      j = j + 1
    }
    
    i = i + 1
  }
}
```

#### 10.3 Analyse des Facteurs Discriminants du Modèle

L'objectif ici est d'identifier les **facteurs discriminants** — les caractéristiques (features/termes) qui ont le plus d'impact pour **distinguer les domaines d'étude**. Pour cela, nous analysons comment les features varient entre les classes : les features qui ont les plus grandes différences entre classes sont celles qui permettent au modèle de les séparer. Une feature discriminante élevée signifie que ses valeurs sont très différentes selon la classe, ce qui la rend prédictive pour la classification.

```{r}
conditions_ok <- FALSE
if (!is.null(y_label)) {
  if (exists("final_features")) {
    if (exists("tfidf_matrix_reduced")) {
      conditions_ok <- TRUE
    }
  }
}

if (conditions_ok == TRUE) {
  cat("\n========== ANALYSE DES FACTEURS DISCRIMINANTS ==========\n")
  
  X = as.matrix(final_features[, -ncol(final_features)])
  y = final_features$target
  
  class_labels = levels(y)
  feature_names = colnames(X)
  
  class_means = data.frame(Feature = feature_names)
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    class_idx = which(y == class_name)
    nb_idx = length(class_idx)
    if (nb_idx > 0) {
      means = colMeans(X[class_idx, , drop = FALSE])
      class_means[[class_name]] = means
    }
    i = i + 1
  }
  
  discriminance_scores = numeric(ncol(X))
  
  feat_idx <- 1
  while (feat_idx <= ncol(X)) {
    feature_values = X[, feat_idx]
    
    global_var = var(feature_values)
    
    intra_var <- 0
    k <- 1
    while (k <= length(class_labels)) {
      class_name = class_labels[k]
      class_idx = which(y == class_name)
      nb_idx = length(class_idx)
      if (nb_idx > 1) {
        intra_var = intra_var + var(feature_values[class_idx]) * (nb_idx - 1)
      }
      k = k + 1
    }
    intra_var = intra_var / (nrow(X) - length(class_labels))
    
    if (intra_var > 0.0001) {
      inter_var <- global_var - intra_var
      discriminance_scores[feat_idx] = (inter_var / intra_var)
    } else {
      discriminance_scores[feat_idx] = 0
    }
    feat_idx = feat_idx + 1
  }
  
  nb_disc = length(discriminance_scores)
  if (nb_disc > 15) { nb_disc = 15 }
  top_discriminant_idx = order(discriminance_scores, decreasing = TRUE)[1:nb_disc]
  
  cat("\nTOP 15 FEATURES DISCRIMINANTS (ordre d'importance):\n")
  ligne_tiret <- ""
  for (z in 1:80) { ligne_tiret = paste0(ligne_tiret, "-") }
  cat(ligne_tiret, "\n")
  
  rangs = c()
  for (r in 1:length(top_discriminant_idx)) { rangs = c(rangs, r) }
  discriminant_df = data.frame(Rang = rangs, Feature = feature_names[top_discriminant_idx], Discriminance = discriminance_scores[top_discriminant_idx])
  
  print(discriminant_df)
  
  cat("\n\nPROFIL DISCRIMINANT PAR CLASSE:\n")
  ligne_egale <- ""
  for (z in 1:80) { ligne_egale = paste0(ligne_egale, "=") }
  cat(ligne_egale, "\n")
  
  i <- 1
  while (i <= length(class_labels)) {
    class_name = class_labels[i]
    cat(sprintf("\nCLASSE: %s\n", class_name))
    ligne_tiret2 <- ""
    for (z in 1:60) { ligne_tiret2 = paste0(ligne_tiret2, "-") }
    cat(ligne_tiret2, "\n")
    
    class_idx = which(y == class_name)
    
    global_mean = colMeans(X)
    class_mean = colMeans(X[class_idx, , drop = FALSE])
    
    deviations = (class_mean - global_mean) / (global_mean + 0.001)
    
    nb_dev = length(deviations)
    if (nb_dev > 5) { nb_dev = 5 }
    top_positive_idx = order(deviations, decreasing = TRUE)[1:nb_dev]
    
    cat(sprintf("  Features caracteristiques (valeurs HIGH dans cette classe):\n"))
    j <- 1
    while (j <= length(top_positive_idx)) {
      feat_idx = top_positive_idx[j]
      feat_name = feature_names[feat_idx]
      dev_pct = deviations[feat_idx] * 100
      cat(sprintf("    - %s: +%.1f%% (moyenne classe vs globale)\n", feat_name, dev_pct))
      j = j + 1
    }
    
    nb_dev2 = length(deviations)
    if (nb_dev2 > 5) { nb_dev2 = 5 }
    top_negative_idx = order(deviations, decreasing = FALSE)[1:nb_dev2]
    
    cat(sprintf("  Features distinctives (valeurs LOW dans cette classe):\n"))
    j <- 1
    while (j <= length(top_negative_idx)) {
      feat_idx = top_negative_idx[j]
      feat_name = feature_names[feat_idx]
      dev_pct = deviations[feat_idx] * 100
      cat(sprintf("    - %s: %.1f%% (moyenne classe vs globale)\n", feat_name, dev_pct))
      j = j + 1
    }
    i = i + 1
  }
  
  nb_classes = length(class_labels)
  if (nb_classes > 1) {
    cat("\n\nANALYSE DES PAIRES DE CLASSES (discriminance intra-paire):\n")
    cat(ligne_egale, "\n")
    
    i <- 1
    while (i <= (nb_classes - 1)) {
      j = i + 1
      while (j <= nb_classes) {
        class_i = class_labels[i]
        class_j = class_labels[j]
        
        idx_i = which(y == class_i)
        idx_j = which(y == class_j)
        
        mean_i = colMeans(X[idx_i, , drop = FALSE])
        mean_j = colMeans(X[idx_j, , drop = FALSE])
        
        separation = abs(mean_i - mean_j)
        nb_sep = length(separation)
        if (nb_sep > 3) { nb_sep = 3 }
        top_sep = order(separation, decreasing = TRUE)[1:nb_sep]
        
        cat(sprintf("\n  %s vs %s:\n", class_i, class_j))
        cat(sprintf("    Facteurs de separation principaux:\n"))
        k <- 1
        while (k <= length(top_sep)) {
          cat(sprintf("      - %s\n", feature_names[top_sep[k]]))
          k = k + 1
        }
        j = j + 1
      }
      i = i + 1
    }
  }
  
} else {
  cat("Section 10.3: Donnees ou features non disponibles\n")
}
```

<br>