---
title: "Cloudflare Access"
---

# Cloudflare Access (restriction emails)

## Etape 1: activer Zero Trust

1) Cloudflare Dashboard > Zero Trust
2) Choisir ou creer une organisation

## Etape 2: creer une application Access

1) Access > Applications > Add an application
2) Type: Self-hosted
3) Domain: votre domaine Pages (ex: `devops-lab.pages.dev`)

## Etape 3: policy de protection

1) Add policy > Allow
2) Include > Email ends in:
   - `@esiee.fr`
   - `@edu.esiee.fr`
3) Save

## Etape 4: test

Ouvrir le site dans un navigateur prive. Seules les adresses autorisees doivent passer.
