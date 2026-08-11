---
title: zcrud_responsive
description: Infrastructure UI responsive transverse — classe de fenêtre Material 3, valeur par breakpoint et grille adaptative (réordonnable).
---

# zcrud_responsive

## Rôle

`zcrud_responsive` fournit les primitives responsives que le reste de la
couche UI construit ensuite : [ZWindowSizeClass] (classe de fenêtre
Material 3 en enum, 3 paliers) pour un choix de présentation, et
[ZBreakpointValue] (valeur générique par breakpoint fin, cascade
mobile-first) bâtie sur l'enum `ZBreakpoint` déjà fourni par `zcrud_core`.
Il fournit aussi deux widgets qui consomment ces primitives :
[ZResponsiveLayout] (aiguilleur de disposition à 3 builders) et
[ZAdaptiveGrid] / [ZReorderableAdaptiveGrid] (grille d'items adaptative,
éventuellement réordonnable par glisser-déposer, bâtie uniquement sur le
SDK Flutter).

## Quand l'utiliser

- Pour classer une **largeur de fenêtre ou de conteneur** en trois paliers
  (`compact`/`medium`/`expanded`) et piloter un choix de présentation.
- Pour porter une **valeur d'authoring par palier fin** (padding, span,
  nombre de colonnes…) sur les cinq breakpoints Bootstrap déjà définis par
  `zcrud_core`, sans dupliquer les seuils.
- Pour construire une **grille d'items adaptative** — avec ou sans
  réordonnancement par appui long — dont le nombre de colonnes découle de
  la largeur **locale** du conteneur, jamais de l'écran entier.

## Quand ne pas l'utiliser

- Pour la **grille 12 colonnes de formulaire** : c'est `ZResponsiveGrid`,
  dans `zcrud_core` — notion distincte des cartes d'items de ce paquet.
- Pour un rendu de liste virtualisée hors grille (`SfDataGrid`) : c'est le
  rôle de `zcrud_list`.

## Types clés

| Type | Rôle |
|---|---|
| `ZWindowSizeClass` | Classe de fenêtre Material 3 (`compact`/`medium`/`expanded`) — résolution pure + helper `of(context)`. |
| `ZBreakpointValue<T>` | Valeur générique par breakpoint (cascade mobile-first), bâtie sur `ZBreakpoint` de `zcrud_core`. |
| `computeCrossAxisCount` | Fonction pure : nombre de colonnes borné (`≥ 1` garanti) à partir d'une largeur disponible. |
| `ZResponsiveLayout` | Aiguilleur à 3 builders (compact/medium/expanded) en cascade descendante, mesure locale. |
| `ZAdaptiveGrid` / `ZReorderableAdaptiveGrid` | Grille d'items adaptative — constructeurs `children:`/`.builder`, et sa variante réordonnable. |

## Voir aussi

- [README du paquet](../../packages/zcrud_responsive/README.md) — installation, démarrage rapide, API complète.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
