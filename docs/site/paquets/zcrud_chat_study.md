---
title: zcrud_chat_study
description: Pont entre une conversation zcrud et le domaine d'étude par répétition espacée, satellite opt-in sans dépendance croisée.
---

# zcrud_chat_study

## Rôle

`zcrud_chat_study` relie une conversation IA au domaine d'étude par
répétition espacée sans faire dépendre l'un de l'autre : `zcrud_chat`/
`zcrud_chat_kernel` ignorent `zcrud_flashcard`, et réciproquement. Ce
paquet fournit le mapper (conversation → requête de génération), le pool
de session dédoublonné (cartes du dossier union cartes de la conversation)
et la sélection des modes offerts par un parcours « commencer à
apprendre » — sans redéclarer aucun des contrats existants du domaine
d'étude.

## Quand l'utiliser

- Pour générer des flashcards depuis un message ou une conversation, en
  s'appuyant sur un `ZFlashcardGenerationPort` déjà implémenté par
  l'application.
- Pour construire une session de révision qui mélange des cartes déjà
  rangées et des cartes tout juste produites par l'assistant, sans exiger
  que ces dernières soient d'abord persistées dans un dossier.

## Quand ne pas l'utiliser

- Si votre chat n'a aucun usage d'étude : montez seulement `zcrud_chat`/
  `zcrud_chat_kernel`, qui ne tirent jamais ce paquet ni le domaine
  flashcards.
- Pour du rendu Flutter du parcours d'étude lui-même : ce paquet est du
  domaine pur (mapper et pool), l'écran appartient à l'application ou à
  `zcrud_study`.

## Types clés

| Type | Rôle |
|---|---|
| `ZChatFlashcardGenerator` | Câble un port de génération existant sur un message ou une conversation. |
| `zChatMessageGenerationRequest` / `zChatConversationGenerationRequest` | Construisent la requête de génération. |
| `ZStudyPoolRequest` / `ZStudyPool` / `zBuildStudyPool` | Constitution du pool de session dédoublonné. |
| `kZChatStudyLaunchModes` | Les modes offerts par un parcours « commencer à apprendre ». |

## Voir aussi

- [README du paquet](../../packages/zcrud_chat_study/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_chat_kernel` — le domaine pur de conversation, source du mapper.
