---
title: zcrud_chat_kernel
description: Noyau Dart pur de conversation IA — modèle neutre de chat et contrat d'action de message.
---

# zcrud_chat_kernel

## Rôle

`zcrud_chat_kernel` est le paquet **kernel** de la capacité chat : il porte,
en Dart pur, le modèle neutre de conversation (`ZChatConversation`,
`ZChatMessage`, la famille ouverte `ZContentBlock`) et le contrat
d'**action** de message (intentions scellées + répartiteur unique). Il
déclare aussi les **ports** — génération, gestion de conversation, saisie
assistée, diffusion vocale — que les paquets satellites et les applications
hôtes implémentent. Il ne dépend que de `zcrud_core` (surface pur-Dart) et
n'importe ni Flutter, ni aucun autre paquet `zcrud_*`.

## Quand l'utiliser

- Pour traiter des conversations IA **hors Flutter** : migration de données,
  traitement serveur, script, test unitaire rapide sous `dart test`.
- Pour écrire un **nouveau satellite** de rendu ou d'intégration (un backend
  de génération, un adaptateur de persistance) qui n'a besoin que du modèle
  et des contrats, sans tirer de dépendance UI.
- Pour implémenter un **port** (`ZChatGenerationPort`, `ZChatDictationPort`…)
  côté application, en s'appuyant sur des types stables et testés.

## Quand ne pas l'utiliser

- Pour construire un écran de chat : passez par `zcrud_chat`, qui assemble ce
  kernel avec un contrôleur Flutter-natif à réactivité granulaire (invariant
  [AD-2](../concepts/invariants.md#ad-2)).
- Pour du rendu Markdown/LaTeX ou une intégration Syncfusion AI AssistView :
  ce sont les rôles de `zcrud_chat_markdown` et `zcrud_chat_syncfusion`, tous
  deux satellites de ce kernel.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatConversation` / `ZChatMessage` | Entités canoniques du chat, extensibles par composition (invariant [AD-4](../concepts/invariants.md#ad-4)). |
| `ZContentBlock` | Famille ouverte de blocs de contenu d'un message. |
| `ZChatAction` / `ZChatActionDispatcher` | Intentions scellées sur un message et répartiteur unique d'exécution. |
| `ZChatGenerationPort` / `ZChatStreamPort` | Ports de génération de réponse, one-shot et streaming. |
| `ZChatResponseConfidence` | Palier de confiance dérivé des verdicts serveur, jamais fabriqué sans signal. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_chat_kernel/README.md) — installation, démarrage rapide, API complète.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
