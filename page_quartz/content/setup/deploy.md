---
title: "Deploiement Cloudflare Pages"
---

# Deploiement Cloudflare Pages

## Etape 1: creer un projet Pages

1) Cloudflare Dashboard > Pages > Create a project
2) Lier le repo GitHub `devops-lab`
3) Build command: `npx quartz build -d public`
4) Output directory: `public`
5) Variable Node: `NODE_VERSION=22`

## Etape 2: secrets GitHub Actions

Dans GitHub > Settings > Secrets and variables:
- Secret `CLOUDFLARE_API_TOKEN`
- Secret `CLOUDFLARE_ACCOUNT_ID`
- Variable `CLOUDFLARE_PROJECT_NAME`

## Etape 3: baseUrl Quartz

Mettre a jour `page_quartz/quartz.config.ts`:

```
baseUrl: "<votre-domaine>.pages.dev"
```
