---
title: zcrud_study
description: Orchestration de présentation du domaine étude — sections composables, cartes par défaut, génération de flashcards par IA, session de révision, partage.
---

# zcrud_study

## Rôle

`zcrud_study` est le paquet **satellite Flutter** de la capacité étude : il
porte la **présentation** — hub d'ajout de contenu, page-détail de dossier,
sections d'outils composables, cartes de rendu par défaut, génération de
flashcards par IA, édition en lot, session de révision assemblée, examens et
rappels, partage communautaire optionnel — sur le domaine pur exposé par
`zcrud_study_kernel`. Le patron structurant est celui des **sections
composables** : `ZStudyToolsSectionSpec` décrit *quoi* rendre, et
`ZSectionedStudyLayout` compose une liste de ces descripteurs en sections
indépendantes, chacune dans son propre sous-arbre de rebuild.

## Quand l'utiliser

- Pour construire l'**interface d'une application d'étude** — page de
  dossier, hub d'ajout, session de révision, génération de flashcards — en
  assemblant des sections plutôt qu'en réécrivant un layout monolithique,
  sans risquer le rafraîchissement global du bug historique (invariant
  [AD-2](../concepts/invariants.md#ad-2)).
- Pour brancher une **capacité IA** (génération de flashcards, de carte
  mentale, de podcast, résumé, explication) via un port neutre que votre
  application implémente avec son propre routeur, sans qu'aucun prompt ni
  clé ne transite par ce paquet.
- Pour activer le **partage communautaire optionnel** d'un dossier d'étude
  — liens révocables, adhésions, galerie publique, modération — protégé par
  une garde d'autorisation pure que votre backend doit répliquer.

## Quand ne pas l'utiliser

- Pour du **domaine pur d'étude** sans aucune UI (agrégation des tâches du
  jour, calcul de proximité d'un examen, registre de cascade) : passez
  directement par `zcrud_study_kernel`, qui n'a aucune dépendance Flutter.
- Pour le **moteur de révision** lui-même (runtimes, glisseur, notation,
  résumé) : c'est le rôle de `zcrud_session`, que ce paquet assemble en
  écran mais ne réimplémente pas.

## Types clés

| Type | Rôle |
|---|---|
| `ZStudyToolsSectionSpec` / `ZSectionedStudyLayout` | Descripteur de section et échafaudage qui les rend comme des sous-arbres indépendants. |
| `ZStudyFolderDetail` | Page-détail d'un dossier : onglets Matériel/Progression, navigation de sous-dossiers adaptative. |
| `ZFlashcardListView` / `ZFlashcardGenerationController` | Liste de flashcards à réordonnancement manuel, et flux de génération par IA. |
| `ZStudySessionView` / `ZStudySessionHost` | Corps composable et détenteur du runtime de la session de révision assemblée. |
| `ZStudySharingAcl` / `ZStudySharingPort` | Garde d'autorisation pure du partage, et le port neutre que l'application implémente. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_study/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
