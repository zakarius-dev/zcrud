---
title: zcrud_chat_syncfusion
description: Coquille Syncfusion AI AssistView et normalisation d'un fil textuel IFFD pour le chat zcrud, satellite opt-in.
---

# zcrud_chat_syncfusion

## Rôle

`zcrud_chat_syncfusion` porte deux frontières d'intégration du chat :
la coquille `SfAIAssistView` de Syncfusion (`ZSfAssistShellRenderer`,
backend du port `ZChatShellRenderer` — jamais une vue de conversation
concurrente) et la normalisation d'un fil textuel encodé selon la
convention IFFD vers les événements typés du kernel
(`ZIffdLexer`/`ZIffdStreamNormalizer`/`ZIffdTextStreamPort`).
`syncfusion_flutter_chat` est une arête de ce seul paquet du monorepo.

## Quand l'utiliser

- Pour afficher le chat avec le widget `SfAIAssistView` de Syncfusion,
  sans perdre la région live, le dépli inline ou le rendu de message du
  socle.
- Pour brancher un backend de génération qui n'expose qu'un flux de texte
  brut (marqueurs de ligne, sentinelles pseudo-XML, erreurs écrites en
  clair) plutôt que des événements typés.

## Quand ne pas l'utiliser

- Si votre application n'utilise ni Syncfusion, ni un backend émettant ce
  format de fil : monter `zcrud_chat` seul ne tire aucun octet de ce
  paquet.
- Pour du rendu Markdown/LaTeX riche : c'est le rôle de
  `zcrud_chat_markdown`, un satellite distinct.

## Types clés

| Type | Rôle |
|---|---|
| `ZSfAssistShellRenderer` | Backend Syncfusion du port `ZChatShellRenderer`. |
| `ZIffdTextStreamPort` | Port de streaming adossé au fil textuel IFFD. |
| `ZIffdLexer` | Découpage incrémental du fil brut en segments. |
| `ZIffdStreamNormalizer` | Classement des segments en canaux et production des événements typés. |
| `ZIffdChannel` | Le canal logique d'une balise (réponse, trace, échec, charge utile). |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat_syncfusion/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat` — le socle Flutter dont ce paquet implémente le port `ZChatShellRenderer`.
