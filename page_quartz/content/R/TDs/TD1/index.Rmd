
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



```{=html}
<style type="text/css">
body, td {font-size: 17px;}
code.r{font-size: 5px;}

pre { font-size: 15px;}
</style>
```


```{r setup, include=FALSE}
knitr::opts_chunk$set(echo = TRUE)
```

<FONT color='#0066CC'><FONT size = 4 >

::: {align="center"}
Fouille de données avec R pour la data science et l'intelligence artificielle\

TD 2 : II. CONSTRUCTION D'UN CLASSIFIEUR BAYESIEN NAIF EN R
:::


</FONT></FONT>

<FONT color='#0066CC'><FONT size = 4 >

::: {align="center"}
Badr TAJINI -- ESIEE Paris\
Source : Bertrand Roudier -- ESIEE Paris
:::

</FONT></FONT>

<hr style="border: 1px  solid gray">

</hr>
Il s'agit de développer un script complet en R  permettant de réaliser une classification bayésienne analogue à celles fournies par différents paquets R  
Pour y parvenir, il est nécessaire de bien comprendre le "fonctionnement" d'une classification Bayésienne (développé dans le cours) en décomposant les différents calculs par étape:  
  
  * Calcul des probabilités conditionnelles (Vraisemblance)  
  * Calcul des probabilités a postériori en fonction du niveau de la variable à prédire
  * Maximisation de la fonction *ln(h<SUB>map </SUB>)*

<br>
Dans un premier temps, nous développerons l'algorithme à l'aide d'un jeu de données très simple: celui fourni en cours. Les résultats de toutes les étapes seront fournies, à vous de développer les scripts pour y parvenir.
Une fois le programme mis au point (que nous considérerons comme la phase de développement), Vous testerez votre programme sur un jeu de données plus conséquent. Les résultats que vous obtiendrez seront comparés à des fonction R déjà implémenté. Nous évaluerons ensuite, à l'aide de matrices de confusion les résultats obtenus.

<hr style="border: 1px  solid gray">

### <FONT color='#000033'><FONT size = 3> 1. RAPPELS  </FONT></FONT> 


-   Le classifieur bayesien naïf est une méthode d'apprentissage supervisé fondée sur le théorème de Bayes. Elle repose sur une hypothèse forte : les descripteurs (Xj) sont deux à deux indépendants conditionnellement aux valeurs de la variable à prédire (Y).

-   Cette méthode simple à implémenter, se révèle cependant très robuste par rapport à un écart d'indépendance et ses performances sont comparables aux autres techniques d'apprentissage souvent bien plus complexes pour des grands volumes de données.

remarque importante. Cette présentation est inspiré des remarquables cours de Ricco RAKOTOMALA disponible sur le blog TANAGRA : http://tutoriels-data-mining.blogspot.com


##### <FONT color='#000033'> <FONT size = 3> 1.1 Définition </FONT> </FONT>

-  Deux évènements A et B sont indépendants si la connaissance de l'un ne modifie pas la connaissance de l'autre. Dans ces conditions (indépendance) :

$$\left. \begin{array}{l}
P(A/B) = P(A)\\
P(B/A) = P(B)\\
P(A \cap B) = P(A)P(B)
\end{array} \right\}P(A/B) = \frac{{P(B/A)P(A)}}{{P(B)}}$$

##### <FONT color='#000033'><FONT size = 3> 1.2 Classifieur et règle bayésienne </FONT> </FONT>

-   Soit un jeux de données (matrice prédictive) composée de n prédicteurs X (n variables). La variable à prédire Y est composée de k classes C.

<br>
<center> 
     ![](Dessin_1.jpg){#id .class width="50%" height="50%"} 
</center>

<br>

**remarque importante**. Nous considérons dans cette exemple que les variables explicatives sont catégorielles. Chacunes d'elles possédent l modalités (l étant différent d'une variable à l'autre)

* La probabilité d'appartenance d'un individu à une classe connaissant à priori ses valeurs x (les observations pour cet individu) est donnée par la régle bayésienne :

 \[P({C_k}/{X_n}) = \frac{{P({X_n}/{C_k})P({C_k})}}{{P({X_n})}}\]


**1.2.1.** La probabilité d'observer une réalisation (un individu i - une ligne) connaissant sa classe d'appartenance k est la suivante :
<center>
\[P({X_1} = {x_1},{X_2} = {x_2},...,{X_n} = {x_n}/{C_k})\]
</center>

* Cette probabilité est appelée la vraisemblance. Sous hypothèse d'indépendance (condition nécessaire au développement suivant), nous avons le développement suivant:

<center>
\[P({X_1} = {x_1},{X_2} = {x_2},...,{X_n} = {x_n}/{C_k}) = P({X_1} = {x_1}/{C_k})P({X_2} = {x_2}/{C_k})...P({X_n} = {x_n}/{C_k}) = \prod\limits_{p = 1}^n {P({X_p}/{C_k})} \]
</center>

**1.2.2.**   La probabilité d'observer une réalisation (un individu i - une ligne) quelque-soit sa classe d'appartenance est : 
<center>
\[P({X_1} = {x_1},{X_2} = {x_2},...,{X_n} = {x_n}) = P({X_1} = {x_1})P({X_2} = {x_2})...P({X_n} = {x_n}) = \prod\limits_{p = 1}^n {P({X_p})} \]
</center>

**1.2.3.** La probabilité qu'un individus appartienne à la classe k est : $P({C_k})$

La probabilité d'appartenance est la suivante :

\[P({C_k}/{X_n}) = \frac{{P({C_k})\prod\limits_{p = 1}^n {P({X_p}/{C_k})} }}{{\prod\limits_{p = 1}^n {P({X_p})} }}\]

* rmq: Un exemple pratique de calcul des probabilités est fourni dans le cours **classification bayésienne** *

<hr>
<br>

##### <FONT color='#000033'><FONT size = 3> 1.3 Régles d'affectations </FONT></FONT>

* Pour chaque individus de la base, on calcule la probabilité d'appartenance $P({C_k}/{X_n})$ à TOUS les groupe k. l'affectation à un groupe sera :
<center>
 \[{h_{map}} = \arg {\max _k}\left( {\frac{{P({C_k})\prod\limits_{p = 1}^n {P({X_p}/{C_k})} }}{{\prod\limits_{p = 1}^n {P({X_p})} }}} \right)\]
</center>


* *rmq:*  hmap est aussi appelé maximum de vraisemblance à posteriori

* Sachant que $P({X_1} = {x_1},{X_2} = {x_2},...,{X_n} = {x_n}) = \prod\limits_{p = 1}^n {P({X_p})}$ est, pour un individu, **une constante**, elle n'intervient pas dans le calcul du maximum de
vraisemblance à postériori. La fonction précédente peut donc être simplifiée :

<center>
 \[{h_{map}} = \arg {\max _k}\left( {P({C_k})\prod\limits_{p = 1}^n {P({X_p}/{C_k})} } \right)\]
</center>


##### <FONT color='#000033'><FONT size = 3> 1.4 Corrections </FONT></FONT>


* Pour éviter d'obtenir des probabilités conditionnelles nulles ${P({X_p}/{C_k})}$ (Vraisemblance), on utilise aussi un facteur correctif.
Soit ${n_x}$ le nombre d'observations $X = {x_i}$ d'une variable X (nombre de modalités = ${x_i}$ pour une variable), ${n_{ki}}$ le nombre d'observations appartenant à *k* pour la modalité ${x_i}$ de X, le facteur correctif est le suivant:

<center>
\[P({X_p}/{C_k}) = \frac{{{n_{ki}} + m}}{{{n_k} + mk}}\]
</center>

Pour rappel ;

* *k* est le nombre de facteur de la variable à prédire 
* *m* est la facteur correctif de Laplace

##### <FONT color='#000033'><FONT size = 3> 1.5 Tranformation logarithmique  </FONT></FONT>

* La fonction hmap est passée en logarithme tel que :

\[{h_{map}} = \arg {\max _k}\left( {\ln \left( {P({C_k})} \right) + \sum\limits_{p = 1}^n {\ln \left( {P({X_p}/{C_k})} \right)} } \right)\]


D'un point de vue calculatoire, le produit de nombreuses probabilités (toutes bien évidemment inférieures à 1 !)  peut rapidement provoquer des débordements de mémoire. le passage en log permet d'éviter ce problème

<br>
<hr style="border: 1px  solid gray">

### <FONT color='#000033'><FONT size = 3> 2. PROGRAMMATION </FONT> 


Nous allons procéder en deux étapes    
  
  - Calcul des tableaux des probabilités conditionnelles puis stockage de ces derniers dans des listes. 
  - Calcul des probabilités *a posteriori* et affectation par argmax sur un jeu de données test
  
  
Au préalable, nous créons le dataframe contenant le jeu de données (simplissime !) fourni en cours.  

Nous utilisons :   

  * le package [kableExtra](https://cran.r-project.org/web/packages/kableExtra/vignettes/awesome_table_in_html.html) qui permet de réaliser des "beaux" tableaux au format html ou pdf.   
  * le package *caret* pour les matrices de confusion    
  * le paquest *e1071* qui réalise la classification Bayésienne. Les résultats développés dans vos scripts seront comparés à ceux fournis par cette librairie     
  
*rmq*: Ne jamais oublier d'effacer  toutes les variables en mémoire au début de votre script (réinitialiser l'environnement)


```{r}
# à compléter
rm(list = ls())
library(kableExtra)
library('e1071')
library('caret')
library(caret)
```


```{r, echo = T}
# à compléter
df = data.frame('Salaire'  = c('< 30', '30 - 50', '30 - 50', '30 - 50', '> 50'),
                'Impots'   = c('< 20','< 20','< 20','> 20','> 20'),
                'Etudiant' = c('Oui','Non','Oui','Non','Non')     ,
                'Controle' = c('Non','Oui','Oui','Non','Oui') 
               )
```

Affichage du tableau avec *kableExtra*

```{r}
# à compléter
df %>% kbl(digits=3) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped') %>% 
       scroll_box( height = "250px")
```


On scinde le dataFrame et l'on crée un dataFrame X (prédicteur) et un vecteur des catégories à prédire (Y)

```{r, echo = T}
# à compléter
X <- df[,-4] ; Y = df$Controle
```


```{r, echo = F}
# à compléter
X %>% kbl(digits=3) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped') %>% 
       scroll_box( height = "250px")
```

```{r, echo = T}
# à compléter
data.frame(Y = Y) %>% kbl(digits=3) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped') %>% 
       scroll_box( height = "250px")
```
<hr>

##### <FONT color='#000033'><FONT size = 3> 2.1 Probabilité conditionnelle </FONT></FONT>

###### <FONT color='#000033'><FONT size =3> 2.1.1 Tableau de contingence </FONT> </FONT> 

Dans un premier temp Nous cherchons ici à créer les tableaux de contingence entre les différentes variables du prédicteur et la variable à prédire. 
Nous créons ainsi 3 tableaux. A titre d'exemple, le tableau de contingence *contrôle* x *salaire* est le suivant: 



<center> 
     ![](Salaire.jpg){#id .class width="50%" height="50%"} 
</center>

<br>
     
     
les trois tableaux sont stockés dans une liste. Pour y parvenir, on utilise La fonction  *table* de R qui réalise les tableaux. Le calcul de chaque tableau ainsi que le stockage sont réalisés par une fonction *lapply*. 
Si vous éprouver des difficultés, il est possible d’utiliser dans un premier temps une boucle pour la mise au point, puis transformer la boucle et un *lapply*

* Chaque nom des objets de la liste (eq clés dictionnaires python) doit correspondre au nom de la variable ( ce qui est, en principe, automatiquement réalisée
* La structure des tables doit être la même:  la variable à expliquer en colonne et la variable explicative en ligne (cf. tableaux précédents)
* on nommera cette liste : "contingence"

les résultas R sont les suivants;

```{r, echo = T}
# à compléter
contingence<- lapply(X, function(x){  
  temp_1   <- table(Y,x)
}) 
contingence
```

###### <FONT color='#000033'><FONT size =3> 2.1.2 Probabilités conditionnelles corrigées </FONT> </FONT> 

- Pour palier au problème conditionnelle nulle, on corrige le tableau de contingence en ajoutant à toutes les valeurs la quantité m (par défaut = 1) 

- Pour calculer les probabilités conditionnelles corrigées, il suffit de diviser élément par élément les deux tableaux précédents : $P({a_i}/{c_k}) = \frac{{{n_{kl}} + m}}{{{n_k} + mk}}$ 

- Les différentes étapes de correction sont résumés, pour la variable salaire comme suit: 
  * Création du tableau de contingence 
  * Correction du tableau
  * Calcul de la somme nk + m*k
  * Calcul des probabilités conditionnelles corrigées 

<br>

<center> 
     ![](Test_Bayesien_processus.jpg){#id .class width="50%" height="50%"} 
</center>


<br>     
 
L'ensemble des calculs est réalisé en modifiant les tableaux de contingence de la liste.

A partir des tableaux de contingence stockés dans la liste, nous obtenons la liste des probabilités conditionnelles:
Nous appelons cette nouvelle liste  *prop_cond*

```{r, echo = T}
# à compléter
k <- length(unique(Y))
m <- 1

prob_cond <- lapply(X, function(x){  
                        temp_1 <- table(Y,x)
                        s      <- apply(temp_1,1, sum) +  m * k 
                        mat    <- matrix(s, ncol = ncol(temp_1), nrow = nrow(temp_1) )
                        out <- (temp_1 + m)/mat
                        })

prob_cond 
```


##### <FONT color='#000033'> <FONT size = 3> 2.2 Prédiction et Vraisemblance </FONT></FONT>
- Une fois les probabilités conditionnelles calculées, nous pouvons réaliser une prédiction sur un jeux de données test. 
Pour y parvenir :
- Nous cherchons à déterminer, pour chaque individus test, quelles sont les probabilités d'appartenances aux groupes (contrôle = Oui - contrôle = Non) connaissant les valeurs des variables prédictives.
- L'affectation à un groupe (contrôle = Oui - contrôle = Non) s'effectue en sélectionnant la probabilité max.

Nous devons calculer, pour chaque individus test, la probabilités à postériori (eq. max de vraisemblance a posteriori) :
<center>
\[\begin{gathered}
  P({C_{k = Oui}}/{X_p}) = P({C_k})\prod\limits_{p = 1}^n {P({X_p}/{C_{k = Oui}})}  \hfill \\
  P({C_{k = Non}}/{X_p}) = P({C_k})\prod\limits_{p = 1}^n {P({X_p}/{C_{k = Non}})}  \hfill \\ 
\end{gathered} \]
</center>

Pour éviter les problèmes de débordement de capacité mémoire nous calculerons  directement les log de la vraisemblance à postériori
<center>
\[\begin{gathered}
  \ln \left( {({C_{k = Oui}}/{X_p})} \right) = \ln \left( {P({C_k})} \right) + \sum\limits_{p = 1}^n {\ln \left( {P({X_p}/{C_{k = Oui}})} \right)}  \hfill \\
  \ln \left( {({C_{k = Non}}/{X_p})} \right) = \ln \left( {P({C_k})} \right) + \sum\limits_{p = 1}^n {\ln \left( {P({X_p}/{C_{k = Non}})} \right)}  \hfill \\ 
\end{gathered} \]
</center>

Le jeu des données test est le suivant (*data_test*) :

```{r, echo = T}
# à compléter
data_test = data.frame('Salaire'  = c('< 30', '30 - 50', '> 50', '> 50', '30 - 50'),
                       'Impots'   = c('< 20','< 20','> 20','< 20','> 20'),
                       'Etudiant' = c('Oui','Oui','Non','Oui','Non')     
                      )
```

```{r, echo = T}
# à compléter
data_test %>% kbl(digits=3) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped') %>% 
       scroll_box( height = "250px")
```

###### <FONT color='#000033'><FONT size = 3>  2.2.1 Appartenance *a priori* </FONT></FONT>

La probabilité d'appartenance à priori correspond à la probabilité qu'un individus ait un contrôle ou non. Elle est calculée à partir des données entraînement.  Les résultats sont stockés dans un vecteur *priori*. De plus, on stocke le "nom" des catégories dans un vecteur(ici il s'agit simplement de 'Oui' et 'Non')

```{r, echo = T}
# à compléter
priori <- prop.table(table(Y))
names_priori <- names(priori)
```

```{r}
# à compléter
priori
```
```{r}
# à compléter
names_priori
```


Les probabilités d'affectation pour chaque individus test sont stockées dans une matrice. Les résultats sont les suivants :

```{r, echo = T}

# à compléter
Test    <- NULL
LnTest  <- NULL
for (i_test in 1:nrow(data_test))
{ V    <- NULL
  lnV  <- NULL
  for(ic in 1:length(priori))
    {   somme <- 0 ; prod <- 1
        for(i in 1:ncol(X))
          {
           ar    <-  prob_cond[[i]]
           somme <- somme + log( ar[names_priori[ic],data_test[i_test,i]])
           prod  <- prod *   ar[names_priori[ic],data_test[i_test,i]]
      
        }
     V     <- c(V, priori[ic] * prod )
    lnV   <- c(lnV, log(priori[ic]) + somme ) 
  }  

Test  <- rbind(Test, V)    
LnTest <- rbind(LnTest, lnV)    

}

```


```{r, echo = T}

# à compléter
data.frame(LnTest)%>% kbl(digits=4) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped') 


```

Pour réalisér les calculs, la méthode est la suivante :

Réaliser 3 boucles "for" imbriquées   

  * la première boucle pour sélectionner chaque individu dans le dataframe *data_test*
  * la seconde boucle pour extraire la probabilité à priori (variable *priori*)
  * la troisième boucle pour extraire les tableaux de probabilités conditionnelles stockés dans la liste *prob_cond*
      *  on extrait les probabilités (par les noms des lignes et des colonnes)
      *  on calcule la somme des log

Exemple  
  
  * Boucle 1 : sélection de l'individu : Salaire = 30-50 , impot < 20 , Etudiant = Oui   
  * Boucle 2 : extraire la probabilités a priori : Priori = Oui  (qui correspond à contrôle = Oui) P = 0.6  
  * Boucle 3 :  
      - extraire les probabilités conditionnelles des tableaux   
        -  Salaire = 30-50 et contrôle = Oui  (= 0.5)  
        -  Impot < 20 et contrôle = Oui        
        -  Etudiant = Oui et Controle = Oui   
      - faire la somme des log des probabilités = logS  
  * Dans la boucle 2 (après la boucle 3) , on calculera les probabilités à posteriori d'affectation  
      - log(0.6) +  logS  
    
L'ensemble des résultats sera stocké dans un tableau (data.frame) 


On choisira max(hmap) pour prédire la présence ou l'absence de contrôle. Les résultats seront résumés dans un data.frame

```{r, echo = T}

# à compléter
resulTest <- data.frame(data_test, 'Pred' = colnames(LnTest)[apply(LnTest,1,which.max)] ) 

resulTest%>% kbl(digits=4) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped') 


```


<br>
<hr style="border: 1px  solid gray">

### <FONT color='#000033'><FONT size = 3> 3. FONCTIONS </FONT> 
               
Une fois les scripts validés, Nous allons écrire deux fonctions génériques qui nous permettront de réutiliser le code indépendamment du nombre de variables et du nombre de catégories (labels).

#### <FONT color='#000033'><FONT size = 3> 3.1 Naive_Bayes </FONT> 

La première fonction que nous appelerons *Naive_Bayes* declarée comme suit :


calculera les probabilités conditionnelles corrigées par le facteur m et les probabilités d'appartenance *priori*:   

> <FONT size = 3>  *Naive_Bayes <- fonction( X,Y, m=1){....}* </FONT>

Cette fonction devra retourner la liste suivante:  

> <FONT size = 3>  *out <- list('prob_cond' = prob_cond, 'priori' = priori)* </FONT>

* prob_cond est la liste des tableaux des probabilités conditionnelles pour chaque variable
* priori étant le tableau des probabilités d'appartenance au groupes (contrôle = Oui, Contrôle = Non)

```{r, echo = T}
# à compléter
Naive_Bayes <- function( X, Y, m=1){
  
  k <- length(unique(Y))
  
  prob_cond <- lapply(X, function(x){  
    temp_1 <- table(Y,x)
    s      <- apply(temp_1,1, sum) +  m * k
    mat    <- matrix(s, ncol = ncol(temp_1), nrow = nrow(temp_1) )
    out <- (temp_1 + m)/mat
  })
  
  priori <- prop.table(table(Y))
  
  out <- list('prob_cond' = prob_cond, 'priori' = priori)
  
  return(out)
}

```

Les résultats sont les suivants:

```{r}
# à compléter
model <-  Naive_Bayes(X,Y,m=1)
print(model)
```
<br>

#### <FONT color='#000033'><FONT size = 3> 3.2 Prédiction </FONT> 

Pour réaliser la prédiction, nous créons une fonction *Predict_Bay* qui retournera les prédictions (log_Vraiseemblance) et l'affectation sous forme de DataFrame. Cette fonction aura deux arguments: 

> <FONT size = 3>  *Predict_Bayes <- fonction(prob_cond, X_pred){....}* </FONT>

  * *prob_cond* qui correspond à la liste retournée par la fonction *naive_Bayes*
  * *X_pred* est le dataframe dont il faut prévoir les Y

les résultats sont les suivants


```{r, echo = T}
# à compléter
Predict_Bayes <- function(model, X_pred)
{
  priori <- model$priori
  priori_labels <- names(model$priori)
  prob_cond    <- model$prob_cond
  
Test    <- NULL
LnTest  <- NULL
for (i_test in 1:nrow(X_pred))
{ V    <- NULL
  lnV  <- NULL
  for(ic in 1:length(priori))
    {   somme <- 0 ; prod <- 1
        for(i in 1:ncol(X))
          {
           ar    <-  prob_cond[[i]]
           somme <- somme + log( ar[priori_labels[ic],X_pred[i_test,i]]) 
           prod  <- prod *   ar[priori_labels[ic],X_pred[i_test,i]]
        }
     V     <- c(V, priori[ic] * prod )
    lnV    <- c(lnV, log(priori[ic]) + somme ) 
  }  

Test   <- rbind(Test, V)    
LnTest <- rbind(LnTest, lnV)    
}

id <- apply(LnTest,1, which.max)
out <- data.frame(LnTest, 'pred' = colnames(LnTest)[id]) 
rownames(out) <- NULL

return(out)
}
```


```{r}
# à compléter
out_pred <- Predict_Bayes(model, data_test)
```


```{r, echo = T}
# à compléter
out_pred %>% kbl(digits=4) %>%    
       kable_styling(bootstrap_options = "striped", full_width = F, position = "center", latex_options = 'stripped')

```

 
 
<br>
<hr style="border: 1px  solid gray">

### <FONT color='#000033'><FONT size = 3> 4. DEPLOIEMENT </FONT>


#### <FONT color='#000033'><FONT size = 3> 4.1 Scripts </FONT>

Nous allons utiliser nos fonctions sur une jeu de données en situation réelle. **L'objectif n'est pas d'évaluer la qualité du classifieur** mais de comparer les résultats obtenus à l'aide de vos scripts avec ceux programmés dans un paquet de référence R :*e1071* qui est très utilisé en R. **Il n'est pas non plus question dans le cadre de cours de réaliser une technique d'apprentissage**

Le jeux de données comprend 12 attributs et 4000 instances (fichier *data_test.Rda*) On cherche à prédire la classe *event* puis à comparer les observations et les prédictions à l'aide d'une matrice de confusion.


On charge le fichier
```{r}
# à compléter
load('data_test.Rda')
```

En utilisant les scripts, vous devez obtenir les probabilités conditionnelles suivantes 

```{r, echo = T}
# à compléter
X <- data_test[,1:11]
obs <- data_test[,12] 
model  <- Naive_Bayes(X, obs, m = 1)
print(model)
```

On réalise maintenant la prédiction sur le jeux de données. Attention les calculs peuvent durer plusieurs minutes compte tenu du nombre d'instances !

```{r}
# à compléter
out_pred <- Predict_Bayes(model, X)
print(out_pred$pred, obs)
```


#### <FONT color='#000033'><FONT size = 3> 4.2 Fonctions R </FONT>

Nous utilisons maintenant la fonction NaivesBaye du paquet e1071

```{r}
# à compléter
model_e1071 <- naiveBayes(as.factor(event) ~ ., data = data_test)
pred_e1071  <- predict(model_e1071, data_test)
confusionMatrix(pred_e1071, obs)
```

Les résultats doivent être les mêmes.... ce qui prouve que vous avez bien travaillé !









