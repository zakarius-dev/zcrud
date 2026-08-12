---
title: zcrud_flashcard
description: Flashcards en répétition espacée — modèle canonique, planificateur SRS remplaçable, état séparé de la carte.
---

# zcrud_flashcard

## Rôle

`zcrud_flashcard` fournit l'entité canonique `ZFlashcard` (six types de
carte, provenance ouverte), un planificateur de répétition espacée
remplaçable (`ZSrsScheduler`, implémentation par défaut `ZSm2Scheduler` —
SuperMemo-2) et un dépôt offline-first `ZFlashcardRepository` composé sur les
ports neutres de `zcrud_core`. L'organisation en dossiers d'étude et la
sélection de session sont portées par `zcrud_study_kernel` et réexportées. Le
paquet ajoute une couche de présentation Flutter additive : widgets d'édition
servis par le registre du cœur et `ZFlashcardReviewCard`, une carte de
révision qui affiche les six types et bascule question/réponse par tap.

## Quand l'utiliser

- Pour modéliser des flashcards à choix multiples, vrai/faux, question
  ouverte, exercice, texte à trous ou réponse courte, avec provenance
  traçable.
- Pour planifier la révision d'une carte via un algorithme de répétition
  espacée remplaçable, sans coupler l'état SRS au corps de la carte
  (invariant [AD-9](../concepts/invariants.md#ad-9)).
- Pour éditer et afficher des flashcards dans une application Flutter, en
  s'appuyant sur un dépôt offline-first déjà composé sur les ports du cœur.

## Quand ne pas l'utiliser

- Pour orchestrer une session de révision complète (minuteur, notation,
  enchaînement de cartes, port d'évaluation) : cette couche vit dans
  `zcrud_session`, en aval de ce paquet.
- Pour représenter une échéance datée générale (examen, rappel) : voir
  [`zcrud_exam`](./zcrud_exam.md), un domaine voisin qui suit le même patron
  de séparation entre entité et état dérivé.

## Types clés

| Type | Rôle |
|---|---|
| `ZFlashcard` | Entité canonique — contenu, type, choix, provenance ; jamais l'état SRS. |
| `ZFlashcardType` | Les six types canoniques de carte. |
| `ZRepetitionInfo` | État de répétition espacée, persisté séparément de la carte. |
| `ZSrsScheduler` / `ZSm2Scheduler` | Contrat de planification SRS et son implémentation SuperMemo-2. |
| `ZFlashcardRepository` | Dépôt offline-first ; `reviewCard`/`initRepetition` comme voie d'écriture SRS unique. |
| `ZFlashcardReviewCard` | Carte de révision Flutter — rendu par type, révélation par tap. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_flashcard/README.md) — installation,
  démarrage rapide, API complète.
- [`zcrud_exam`](./zcrud_exam.md) — domaine voisin d'échéance d'étude.
- [Invariants d'architecture](../concepts/invariants.md) — définitions
  canoniques AD-1 à AD-16.
