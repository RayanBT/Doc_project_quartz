---
title: "TD4"
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
# TD 4 : Partie II - ANALYSE FACTORIELLE DISCRIMINANTE 

```r
knitr::opts_chunk$set(echo = TRUE)
# Ensure pandoc is available when knitting outside RStudio
if (!rmarkdown::pandoc_available()) {
  candidates <- c(
    "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools",
    "C:/Program Files/RStudio/bin/pandoc",
    "C:/Program Files/Quarto/bin/tools",
    "C:/Program Files/Pandoc"
  )
  hit <- candidates[file.exists(file.path(candidates, "pandoc.exe"))]
  if (length(hit) > 0) {
    Sys.setenv(RSTUDIO_PANDOC = hit[1])
  }
}
```

<FONT color='#0066CC' size = 4 >

**Fouille de données avec R pour la data science et l'intelligence artificielle**

</FONT>

<FONT color='#0066CC' size = 4 >

*Badr TAJINI -- ESIEE Paris*\
*Source : Bertrand Roudier -- ESIEE Paris*

</FONT>


<hr style="border: 1px  solid gray">

</hr>

<DIV align = justify>

<!--- /////////////////////////////////////////////////////////////////////--->
### <FONT color='#0066CC'><FONT size = 4> 1. Introduction </FONT></FONT>

Ce TD a pour objectif de réaliser la classification supervisée à l'aide de l'analyse factorielle discriminante.

Dans le précédent TD, nous avons réalisé: 

* Une diminution de dimension en calculant des axes de projections qui maximisent la dispersion inter groupe. Les vecteurs directeurs de ces axes factoriels correspondent aux vecteurs propres normalisés de la matrice : $\frac{B}{W}$ (méthode Anglo-saxone)   

* Les statistiques inférentielles relatives à la discrimination des groupes selon les axes (tests de Wilks)

* Le calcul des Scores. Ces derniers correspondent à la représentation des individus dans le plan formé par les (deux) premiers axes factoriels

Dans ce TD final, nous allons réaliser une classification de chaque individu dans le plan factoriel. Pour y parvenir: 

* Nous calculons le centre de gravité de chaque groupe dans le plan factoriel.
* Pour chaque individu, nous calculons les distances le séparant des centres de chaque groupe.  
* Nous affectons l'individu à la classe dont le centre de gravité est le plus proche.  

Pour évaluer la  qualité de la méthode de classification, nous réalisons une matrice de confusion. 

<U> **Rmq** </U>:  *Ce type de classification est possible que si la statistique montre préalablement l'existence significative d'une discrimination des groupes selon les axes factoriels*


<!--- /////////////////////////////////////////////////////////////////////--->

</DIV>

</FONT></FONT>

<hr style="border: 1px  solid gray">

</hr>

### <FONT color='#0066CC'><FONT size = 4> 2. Prérequis </FONT></FONT>


Nous effectuons la classification en reprenant dans un premier temps les données <VIN_QUALITES.txt>. Vous utiliserez les fonctions que vous avez développées dans le TD précédent (*MANOVA* et *AFD*)   
Pour rappel, la fonction (*AFD* ) retourne une liste avec les Scores (coordonnées des individus sur les axes factoriels).



```r
rm(list = ls()) # pour effacer les toutes les objets en mémoire
library(kableExtra)
library(ggplot2)
library(dplyr)
df <- read.table('VIN_QUALITE.txt', header = T)
```

* La fonction permettant de réaliser le graphique est la suivante


```r
#fonction graphique
AFD_graph1 <- function(Scores, label = T, center = F)
{ 
  colnames(Scores)[3] <- 'Class'
  
  gr <- ggplot()
  if (label == F)
     {
       gr <- gr + geom_point(data = Scores  ,aes(x = Axe_1, y = Axe_2), colour = '#0066CC', size = 1)     
     }else
     {
       gr <- gr + geom_point(data = Scores  ,aes(x = Axe_1, y = Axe_2, colour = Class), size = 2)
     }  
   
  if(center == T)
  {
    df_center <- aggregate(Scores[,-3], by = list(Scores$Class ), mean)
    gr <- gr + geom_point(data = df_center, aes(x = Axe_1, y = Axe_2, colour = Group.1 ), shape = 23, size = 4)
    
  }
  gr <- gr + geom_hline(yintercept = 0 , size = 0.1, colour = 'red') +
             geom_vline(xintercept = 0 , size = 0.1, colour = 'red') 
return(gr)
}

```




```r
MANOVA <- function (X,Y)
{ 
  Xk <- split(X,Y)
  Gk <- lapply(Xk, function(x) sapply(x,mean) )
  G  <-  sapply(X,mean)
  P  <-  ncol(X)
  N  <-  nrow(X)
  Nk <- sapply(Xk, function(x) nrow(x))
  K  <- length(unique(Y))

  mat_G <- matrix(G, nrow = N, ncol = P, byrow = T)
  mat_X <- as.matrix(X)

  SS_Tot <- t(mat_X - mat_G) %*% (mat_X - mat_G)

  SS_partiel_Intra <- lapply(1:K, 
            function(x){ delta <- as.matrix(Xk[[x]]) - matrix(Gk[[x]], nrow = nrow(Xk[[x]]), ncol = ncol(Xk[[x]]), byrow = T )  
                        t(delta) %*% delta
                      })
  SS_Intra <- matrix(0, ncol = P, nrow = P)
  for (i in 1:K){SS_Intra <- SS_Intra + SS_partiel_Intra[[i]]}

  SS_Inter <- SS_Tot - SS_Intra
 
  Lam <- det(SS_Intra) / det(SS_Tot)
  V_crit <- -(N - 1 - (P + K)/2) * log(Lam)
  ddl <- P*(K-1)   ; proba <- dchisq( V_crit, ddl)

  ret <- list(
    'SS_tot'   = SS_Tot  ,
    'SS_Intra' = SS_Intra,
    'SS_Inter' = SS_Inter,
    'GK'       = G      ,
    'G'        = G       ,
    'NK'       = Nk      ,
    'P'        = P       ,
    'N'        = N       ,
    'Lambda'   = Lam     ,
    'Proba'    = proba
  )  
  
  return(ret)
}
```


```r
AFD <- function(X,Y,SS_tot, SS_intra, SS_inter, nb_axes = 2)
{  
  
# nombre d'individus
N   <- nrow(X) 
# nombre de classes
k   <- length(unique(Y)) 
# nombre de variables
p   <- ncol(X)
# les entêtes des dataframes
name_axes <- paste0('Axe_', 1: ncol(X))

# matrice B/W
ratio <- SS_inter %*% solve(SS_intra) 

# diagonalisation
res_2    <- eigen(ratio)

# vecteur propres et sélection de la partie réelle
VectP    <- Re(res_2$vectors)
df_VectP <- data.frame(VectP)
colnames(df_VectP) <- rownames(df_VectP) <- name_axes 

# normalisation des vecteurs propres
U   <- VectP
W   <- SS_intra
num <- diag(sqrt(diag(t(U) %*% W %*% U)))

Un  <- U %*% solve(num)
df_Un <- data.frame(Un) ; colnames(df_Un) <- name_axes 

# Valeur propres
ValP <- Re(res_2$values)
df_ValP <- data.frame(VP = ValP) ; rownames(df_ValP) <- name_axes 

# Inertie
Inertie <-  df_ValP / sum(df_ValP) * 100

# Coordonnées des individus dans le plan factoriel
Z <- scale(X,center = T, scale = F)
Scores <- data.frame(Z %*% Un) ; names(Scores) <-  name_axes
Scores <- Scores[,1:nb_axes]

# Attention la colonne 3 doit s'appele
Scores_df <- data.frame(cbind(Scores, Class = Y)) 

result     <- matrix(0, nrow = nb_axes, ncol = 6)
result[,1] <- ValP[1:nb_axes]
result[,2] <- ValP[1:nb_axes]/sum(ValP) *100                                      #  valeurs propres et % inertie
result[,3] <- sqrt(ValP[1:nb_axes]/(1+ValP[1:nb_axes]))                                      #  corr?lation cannonique
result[,4] <- cumprod(1 - result[,3]^2) 
result[,5] <- -(N - (p + k)/2 - 1) * log(result[,4])   
result[,6] <-  1- pchisq(result[,5],p * (k-1) )    


result <- data.frame(result)

colnames(result) <- c('valeur propres',' % inertie','correlation',' Wilks',' Kh Deux','p.value')

return(list( Unorm = df_Un,
             Val_P = ValP ,
             Scores = Scores_df,
             Result = result
            ))

}

```


```r


X1 = df[,1:4]
Y1 = factor(df$Qualite)

res <- MANOVA(X1,Y1)
afd <- AFD(X1,Y1, res$SS_tot, res$SS_Intra, res$SS_Inter)

```


Les Scores sont les suivants: 


```r
knitr::kable(head(afd$Scores, 20), digits = 3, format = 'html')

```

<!--- /////////////////////////////////////////////////////////////////////--->

</FONT></FONT>

<hr style="border: 1px  solid gray">

</hr>
<!--------------------------------------------------------------------->

### <FONT color='#0066CC' size = 4> 3. Classification </FONT>

<br>

#### <FONT color='#0066CC'><FONT size = 4> 3.1 Centres de gravité </FONT></FONT>

* Nous calculons les centres de gravité de chaque groupe dans le plan factoriel. Nous pouvons, par exemple utiliser la fonction *aggregate*.  

```r
# centres de gravité (barycentres) par classe
df_center <- aggregate(afd$Scores[, c("Axe_1", "Axe_2")],
                       by = list(Class = afd$Scores$Class),
                       FUN = mean)

df_center

```

<br>

* La représentation des centres de gravité et des individus

```r
AFD_graph1(afd$Scores, label = TRUE, center = TRUE)

```


#### <FONT color='#0066CC'><FONT size = 4> 3.2 Distances </FONT></FONT>


* Nous calculons les distances euclidiennes de chaque individu aux différents centre de gravité de chaque groupe.

```r
Scores <- afd$Scores
Scores$Class <- as.factor(Scores$Class)

# centres de gravité (barycentres)
df_center <- aggregate(Scores[, c("Axe_1", "Axe_2")],
                       by = list(Class = Scores$Class),
                       FUN = mean)

# matrice centres (lignes = classes)
cent_mat <- as.matrix(df_center[, c("Axe_1", "Axe_2")])
rownames(cent_mat) <- df_center$Class

# distances euclidiennes : (n_individus x n_classes)
dist_mat <- sapply(rownames(cent_mat), function(cl){
  dx <- Scores$Axe_1 - cent_mat[cl, "Axe_1"]
  dy <- Scores$Axe_2 - cent_mat[cl, "Axe_2"]
  sqrt(dx^2 + dy^2)
})

dist_mat <- as.data.frame(dist_mat)
head(dist_mat)

```

<br>


* Comme le montre la figure, L'affectation d'un individu correspond à la distance minimale entre cet individu et le centre de gravité d'un groupe (figure = groupe 3)


<br>


```r
knitr::include_graphics('Distance.jpg')
```


<!------------------------------------------------------------------------->
#### <FONT color='#0066CC'><FONT size = 4> 3.3 Classification </FONT></FONT>

Le dataframe suivant compare la classification obtenue par l'AFD et les observations (Gold Standard)


```r
Scores <- afd$Scores
Scores$Class <- factor(Scores$Class)

# 1) Centres de gravité (barycentres)
df_center <- aggregate(Scores[, c("Axe_1", "Axe_2")],
                       by = list(Class = Scores$Class),
                       FUN = mean)

# 2) Distances euclidiennes aux centres
cent_mat <- as.matrix(df_center[, c("Axe_1", "Axe_2")])
rownames(cent_mat) <- df_center$Class

dist_mat <- sapply(rownames(cent_mat), function(cl){
  dx <- Scores$Axe_1 - cent_mat[cl, "Axe_1"]
  dy <- Scores$Axe_2 - cent_mat[cl, "Axe_2"]
  sqrt(dx^2 + dy^2)
})
dist_mat <- as.data.frame(dist_mat)

# 3) Classe prédite = centre le plus proche
Scores$Pred <- colnames(dist_mat)[max.col(-as.matrix(dist_mat))]
Scores$Pred <- factor(Scores$Pred, levels = levels(Scores$Class))

df_compare <- data.frame(
  Individu  = seq_len(nrow(Scores)),
  Observed  = Scores$Class,
  Predicted = Scores$Pred,
  Correct   = Scores$Class == Scores$Pred
)


```

```r
df_compare %>% kbl() %>% kable_styling(full_width = FALSE) %>% scroll_box(height = "250px")


```

#### <FONT color='#0066CC'><FONT size = 4> 3.4 Qualité </FONT></FONT>

* Nous pouvons maintenant réaliser la matrice des confusions en utilisant la fonction *confusionMatrix* du package *caret*

```r
# install.packages("caret")  # si besoin
library(caret)

# Si tu utilises df_compare (Observed / Predicted)
df_compare$Observed  <- factor(df_compare$Observed)
df_compare$Predicted <- factor(df_compare$Predicted, levels = levels(df_compare$Observed))

cm <- confusionMatrix(data = df_compare$Predicted,
                      reference = df_compare$Observed)

cm          # résumé complet
cm$table    # matrice de confusion seule
cm$overall  # Accuracy, Kappa, etc.

```

<!------------------------------------------------------------------------->
#### <FONT color='#0066CC'><FONT size = 4> 3.5 Encapsulation </FONT></FONT>

* On construit une fonction ( que nous appelerons *AFD_Classif*) et qui "encapsule" le code 

La fonction doit retourner :

* les centre de gravités
* les distances de chaque individus aux centre des classes (groupes)
* la comparaison entre la classification réalisée par l'AFD et le gold standard
* la matrice de confusion (obtenue à l'aide de la fonction caret)

```r

AFD_Classif <- function(Scores,
                        axes = c("Axe_1", "Axe_2"),
                        class_col = "Class") {

  if (!is.data.frame(Scores)) stop("Scores doit être un data.frame.")
  if (!all(axes %in% names(Scores))) {
    stop(paste0("Colonnes d'axes manquantes : ",
                paste(setdiff(axes, names(Scores)), collapse = ", ")))
  }
  if (!(class_col %in% names(Scores))) stop(paste0("Colonne de classe '", class_col, "' introuvable."))

  Scores[[class_col]] <- factor(Scores[[class_col]])
  X <- as.matrix(Scores[, axes, drop = FALSE])

  centres <- aggregate(Scores[, axes, drop = FALSE],
                       by = list(Class = Scores[[class_col]]),
                       FUN = mean)
  names(centres)[1] <- class_col

  cent_mat <- as.matrix(centres[, axes, drop = FALSE])
  rownames(cent_mat) <- centres[[class_col]]

  dist_mat <- sapply(rownames(cent_mat), function(cl) {
    mu <- matrix(cent_mat[cl, ], nrow = nrow(X), ncol = ncol(X), byrow = TRUE)
    sqrt(rowSums((X - mu)^2))
  })

  Pred <- colnames(dist_mat)[max.col(-dist_mat)]
  Pred <- factor(Pred, levels = levels(Scores[[class_col]]))

  df_compare <- data.frame(
    Individu  = seq_len(nrow(Scores)),
    Observed  = Scores[[class_col]],
    Predicted = Pred,
    Correct   = Scores[[class_col]] == Pred
  )

  if (!requireNamespace("caret", quietly = TRUE)) {
    stop("Le package 'caret' n'est pas installé. Fais: install.packages('caret')")
  }
  cm <- caret::confusionMatrix(data = df_compare$Predicted,
                               reference = df_compare$Observed)

  dist_df <- as.data.frame(dist_mat)
  dist_df$Individu <- seq_len(nrow(Scores))
  dist_df <- dist_df[, c("Individu", colnames(dist_mat)), drop = FALSE]

  list(
    centres   = centres,
    distances = dist_df,
    compare   = df_compare,
    confusion = cm
  )
}


```

<!--------------------------------------------------------------------->
### <FONT color='#0066CC'><FONT size = 4> 4. Déploiement </FONT></FONT>

* Pour déployer le code, on utilisera le fichier *iris* fournit par défaut  dans R

```r
library(caret)  # si pas déjà chargé

data(iris)  # dataset fourni par défaut (voir ?iris)
X_iris <- iris[, 1:4]
Y_iris <- iris$Species

# MANOVA + AFD
res_iris <- MANOVA(X_iris, Y_iris)
afd_iris <- AFD(X_iris, Y_iris,
                res_iris$SS_tot, res_iris$SS_Intra, res_iris$SS_Inter,
                nb_axes = 2)

# Graphique individus + centres
AFD_graph1(afd_iris$Scores, label = TRUE, center = TRUE)

# Classification + confusion matrix (caret)
out_iris <- AFD_Classif(afd_iris$Scores)

out_iris$centres
head(out_iris$distances, 10)
head(out_iris$compare, 20)

out_iris$confusion
out_iris$confusion$table


```
Les résultats sur le fichier *iris* sont les suivants

* Centres de gravité

```r
# Centres de gravité (iris)
out_iris$centres %>% 
  kbl(digits = 3) %>% 
  kable_styling(bootstrap_options = "striped",
                full_width = FALSE,
                position = "center")

```

<br> 

* Distances 


```r
out_iris$distances %>% 
  kbl(digits = 3) %>% 
  kable_styling(bootstrap_options = "striped",
                full_width = FALSE,
                position = "center") %>% 
  scroll_box(height = "350px")

```

<br> 

* Classification 


```r
out_iris$compare %>% 
  kbl() %>% 
  kable_styling(bootstrap_options = "striped",
                full_width = FALSE,
                position = "center") %>% 
  scroll_box(height = "350px")

```

* Confusion

```r
out_iris$confusion$table %>% 
  as.data.frame.matrix() %>% 
  kbl() %>% 
  kable_styling(bootstrap_options = "striped",
                full_width = FALSE,
                position = "center")

```

```rmd
install.packages("rmarkdown")
rmarkdown::find_pandoc()  # Check if pandoc is available via RStudio
rmarkdown::pandoc_available()
```
