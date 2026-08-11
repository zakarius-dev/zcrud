---
title: zcrud_chat_markdown
description: Backend de rendu riche Markdown/LaTeX pour le chat zcrud, satellite opt-in adossé à zcrud_markdown.
---

# zcrud_chat_markdown

## Rôle

`zcrud_chat_markdown` est le paquet **satellite** qui branche un rendu
Markdown/LaTeX riche sur le port `ZChatRenderer` de `zcrud_chat`. Le rendu
neutre du socle affiche volontairement le Markdown comme du texte source ;
ce paquet fournit l'implémentation qui l'interprète réellement, avec une
politique de streaming pensée pour éviter le clignotement visuel et le
re-décodage coûteux d'un Markdown reçu fragment par fragment.

## Quand l'utiliser

- Pour rendre en gras/listes/tableaux/formules les réponses d'un modèle qui
  produit du Markdown ou du LaTeX, sans réécrire un rendu maison.
- Pour bénéficier d'une politique de streaming déjà arbitrée (neutre pendant
  le flux, riche à la complétion) plutôt que de gérer soi-même le
  clignotement d'un Markdown incomplet.

## Quand ne pas l'utiliser

- Si vos messages sont du texte brut sans mise en forme : le rendu neutre du
  socle suffit, sans dépendance supplémentaire.
- Si vous devez rendre du LaTeX/Markdown en dehors d'un contexte de chat :
  passez directement par `zcrud_markdown`, dont ce paquet n'est qu'un pont.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatMarkdownRenderer` | Le backend de rendu, injecté via `ZChatRendererScope` — politique de streaming, LaTeX, rôles couverts, style. |
| `ZChatMarkdownStreamingMode` | Politique de rendu pendant un flux en cours (`neutralWhileStreaming` par défaut). |
| `kZChatMarkdownDefaultRoles` | Les rôles dont le texte est interprété comme du Markdown — tout sauf `user`. |

## Voir aussi

- [README du paquet](../../packages/zcrud_chat_markdown/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — le socle Flutter dont ce paquet implémente le port `ZChatRenderer`.
- `zcrud_markdown` — l'éditeur/lecteur Markdown neutre sur lequel ce paquet s'appuie.
