---
title: zcrud_document
description: Document d'étude partageable, état de lecture personnel et annotations accessibles au-dessus de n'importe quel moteur de rendu.
---

# zcrud_document

## Rôle

`zcrud_document` est le paquet **satellite** de la capacité document : il
dépend de `zcrud_study_kernel` pour le dossier et la palette de couleurs,
et porte le modèle propre au document — `ZStudyDocument` (contenu
partageable : nom, chemin de stockage, statut, taille), `ZDocumentReadingState`
(état de lecture personnel, séparé par construction du contenu), les
préférences de lecture (`ZDocumentViewerPrefs`, pur-Dart), et l'annotation
partageable (`ZDocumentAnnotation`, surlignage ou note ancrée). Il fournit
aussi la présentation accessible (WCAG) de la toolbar et du panneau
d'annotation, ainsi qu'une coquille de viewer neutre — aucune dépendance à
un moteur de rendu PDF concret.

## Quand l'utiliser

- Pour porter le **modèle document** d'une application d'étude — contenu
  partageable, état de lecture personnel (page, zoom, pages maîtrisées) et
  annotations.
- Pour composer une **UI d'annotation accessible** (sélection de nature,
  palette de couleurs, panneau de navigation) au-dessus du viewer PDF de
  votre choix, sans réimplémenter le contraste WCAG ni les cibles tactiles.
- Pour une **coquille de viewer neutre** (barres, états de chargement/
  erreur/vide, navigation de page) que vous remplissez avec votre propre
  moteur de rendu.

## Quand ne pas l'utiliser

- Pour le seul dossier d'organisation ou la sélection de session : passez
  directement par `zcrud_study_kernel`, dont ce paquet dépend.
- Pour un rendu PDF concret : ce paquet ne dépend d'aucun moteur de rendu
  — l'hôte fournit le contenu affiché via `ZDocumentViewerChrome.document`.

## Types clés

| Type | Rôle |
|---|---|
| `ZStudyDocument` / `ZDocumentStatus` | Document d'étude — contenu partageable et son cycle de vie. |
| `ZDocumentReadingState` / `ZDocumentViewerPrefs` | État de lecture personnel et préférences de viewer, jamais colocalisés avec le document. |
| `ZDocumentAnnotation` / `ZAnnotationBounds` | Annotation partageable et son rectangle d'ancrage borné `[0,1]`. |
| `ZAnnotationToolbar` / `ZAnnotationPanel` | Présentation accessible (WCAG) de la sélection de nature/couleur et de la liste d'annotations. |
| `ZDocumentViewerChrome` | Coquille de viewer composable, indépendante de tout moteur de rendu. |

## Voir aussi

- [README du paquet](../../packages/zcrud_document/README.md) — installation, démarrage rapide, API complète.
- [Architecture hexagonale](../concepts/architecture-hexagonale.md) — le patron kernel/satellite.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- [`zcrud_study_kernel`](./zcrud_study_kernel.md) — le kernel dont ce paquet dépend.
