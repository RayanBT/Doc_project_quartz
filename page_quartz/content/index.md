---
title: "DevOps Lab - Groupe"
---

# DevOps Lab - GRP3_DevOps_DSIA

Bienvenue sur notre portfolio de travaux pratiques DevOps réalisés dans le cadre du cours DSIA à l'ESIEE Paris.

## Présentation du groupe

**Nom du groupe:** GRP3_DevOps_DSIA

**Membres:**
- BEN TANFOUS Rayan (Leader)
- DA CRUZ PEREIRA Antoine
- CHEN Antoine
- MATSUMOTO Lucca
- SOUPRAYEN Soen

## À propos de ce site

Ce site a été développé avec **Quartz**, un générateur de site statique basé sur Obsidian, et déployé sur **Cloudflare Pages** avec une intégration continue via GitHub Actions.

### Objectifs du projet

Ce portfolio centralise l'ensemble de nos travaux pratiques (TD1 à TD6) du cours DevOps. Chaque lab explore des aspects fondamentaux de l'infrastructure moderne et du déploiement applicatif :

- **Infrastructure as Code (IaC)** avec Terraform/OpenTofu
- **Gestion de configuration** avec Ansible
- **Conteneurisation** avec Docker
- **Orchestration** avec Kubernetes
- **Cloud Computing** sur AWS (EC2, EKS, Lambda, ECR)
- **CI/CD** et automatisation des déploiements
- **Sécurité** et gestion des accès

## Sécurité et accès

L'accès au site est **sécurisé et restreint** aux membres de l'ESIEE Paris via **Cloudflare Access**. Seules les adresses email **@esiee.fr** et **@edu.esiee.fr** peuvent consulter le contenu après authentification.

Cette restriction garantit que nos travaux et rapports restent confidentiels et accessibles uniquement à la communauté éducative de l'ESIEE.

## Structure des labs

Chaque TD comprend :
- Un **compte-rendu détaillé** avec captures d'écran et explications
- Les **réponses aux questions** posées dans les sujets
- Les **scripts et configurations** utilisés (Ansible, Terraform, Docker, Kubernetes)
- Les **problèmes rencontrés** et leurs solutions
- Le **sujet original** en PDF pour référence

### Labs disponibles

- **[Index des labs](./labs)** - Vue d'ensemble de tous les travaux pratiques
- **[TD1 - Introduction AWS](./labs/td1)** - Premiers pas avec AWS CLI et déploiement d'instances EC2
- **[TD2 - Automatisation avec Ansible](./labs/td2)** - Déploiement automatisé avec Ansible, Packer et OpenTofu
- **[TD3 - Infrastructure avancée](./labs/td3)** - ASG, Load Balancers, Kubernetes (EKS), Lambda et conteneurisation
- **[TD4](./labs/td4)** - Approfondissement des concepts DevOps
- **[TD5](./labs/td5)** - Pratiques avancées
- **[TD6](./labs/td6)** - Projet final et intégration

### Partie R (en cours de finalisation)

> **Note :** La section R est actuellement en cours de finalisation. L'insertion des résultats dans les comptes-rendus est en cours de réalisation.

- **[Index R](./R)** - Travaux dirigés, mini projets et projet final

## Technologies utilisées

### Infrastructure et Cloud
- **AWS** (EC2, EKS, Lambda, ECR, VPC, Security Groups)
- **Terraform/OpenTofu** pour l'Infrastructure as Code
- **Ansible** pour la gestion de configuration

### Conteneurisation et orchestration
- **Docker** et Docker Compose
- **Kubernetes** (local avec Docker Desktop + EKS)
- **Auto Scaling Groups** et Load Balancers

### CI/CD et déploiement
- **GitHub Actions** pour l'intégration continue
- **Cloudflare Pages** pour l'hébergement
- **Cloudflare Access** pour la sécurité

### Outils de développement
- **Quartz** (générateur de site statique)
- **Packer** pour la création d'images AMI
- **PM2** pour la gestion de processus Node.js

## Configuration et déploiement

Pour en savoir plus sur la mise en place de ce site :

- **[Déploiement Cloudflare Pages](./setup/deploy)** - Configuration du build et déploiement automatisé
- **[Configuration Cloudflare Access](./setup/access)** - Mise en place des restrictions d'accès par email

## Contact

Pour toute question concernant ce projet ou nos travaux, n'hésitez pas à contacter les membres du groupe via les canaux de communication de l'ESIEE Paris.

---

*Dernière mise à jour : Février 2026 | ESIEE Paris - DSIA*
