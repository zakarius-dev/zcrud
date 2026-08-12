---
title: zcrud_session
description: Runtime de session d'étude Flutter-natif — trois moteurs (SRS, linéaire, examen blanc) et une voie d'écriture SRS unique.
---

# zcrud_session

## Rôle

`zcrud_session` porte le **runtime** d'une session d'étude : une fois
qu'un lot de cartes a été sélectionné et trié en amont (par
`zcrud_flashcard`), ce paquet le fait progresser jusqu'à la fin — cycle de
répétition espacée, parcours linéaire avec ou sans re-boucle des ratés, ou
examen blanc à scoring différé. Chacun des trois moteurs
(`ZStudySessionEngine`, `ZLinearSessionState`, `ZWhiteExamSessionEngine`)
est un `ChangeNotifier` pur Flutter, sans gestionnaire d'état (invariant
[AD-2](../concepts/invariants.md#ad-2)). Le paquet fournit aussi les widgets
de présentation d'une session : sélecteur de mode, saisie notée, pile
swipeable, rangée de notation SRS, dialog de filtres et écran de fin.

## Quand l'utiliser

- Pour construire l'**écran de session** d'un module d'étude — de la
  sélection du mode jusqu'au bilan de fin — sans reconstruire le cycle de
  réinsertion des cartes ratées ni la voie d'écriture SRS.
- Pour brancher une **surface de saisie notée** (`ZFlashcardAnswerInput`)
  sur un port d'évaluation IA ou une évaluation locale déterministe (QCM,
  Vrai/Faux), avec indices plafonnés et minuteur.
- Pour composer un **examen blanc** — pile swipeable ou liste défilante —
  qui n'écrit structurellement aucun état SRS, la notation restant
  entièrement portée par `ZSrsQualityButtons`.

## Quand ne pas l'utiliser

- Pour **sélectionner ou filtrer** un lot de cartes : cette responsabilité
  vit en amont, dans `zcrud_flashcard` (invariant
  [AD-1](../concepts/invariants.md#ad-1) — un paquet ne re-décide jamais ce
  qu'un paquet amont a déjà décidé).
- Pour **calculer un intervalle de répétition** ou modifier l'algorithme
  SM-2 : c'est le rôle du planificateur de `zcrud_flashcard`, jamais de ce
  paquet, qui ne fait que consommer son résultat via le seam
  `ZSessionReviewer`.

## Types clés

| Type | Rôle |
|---|---|
| `ZStudySessionEngine` | Moteur SRS en cycle — seul détenteur possible d'un seam d'écriture SRS (`ZSessionReviewer`), réinsère une carte ratée à un offset déterministe. |
| `ZLinearSessionState` / `ZWhiteExamSessionEngine` | Runtimes linéaire et d'examen blanc — zéro écriture SRS par construction (aucun seam au constructeur). |
| `ZFlashcardAnswerInput` | Surface de saisie notée — QCM/Vrai-Faux/rédigée, sans tap-to-reveal, correction causée par la soumission. |
| `ZSrsQualityButtons` | Rangée de boutons de notation SM-2, échelle dérivée de `ZSrsConfig`, unique voie de notation. |
| `ZSessionModeSelector` / `ZSessionSummaryView` | Sélecteur de session (produit une file, ne démarre rien) et écran de bilan (assemble, ne recalcule rien). |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_session/README.md) — installation, démarrage rapide, API complète.
- [`zcrud_flashcard`](./zcrud_flashcard.md) — modèle de carte, planificateur SM-2, sélection en amont.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Offline-first](../concepts/offline-first.md) — AD-9 en pratique (voie d'écriture SRS unique).
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
