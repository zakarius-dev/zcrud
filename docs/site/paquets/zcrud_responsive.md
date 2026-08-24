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
SDK Flutter). Sur cette dernière est bâti [ZDefaultReorderRenderer], le
**défaut zéro-dépendance** du port de réordonnancement de `zcrud_core`.

## Quand l'utiliser

- Pour classer une **largeur de fenêtre ou de conteneur** en trois paliers
  (`compact`/`medium`/`expanded`) et piloter un choix de présentation.
- Pour porter une **valeur d'authoring par palier fin** (padding, span,
  nombre de colonnes…) sur les cinq breakpoints Bootstrap déjà définis par
  `zcrud_core`, sans dupliquer les seuils.
- Pour construire une **grille d'items adaptative** — avec ou sans
  réordonnancement par appui long — dont le nombre de colonnes découle de
  la largeur **locale** du conteneur, jamais de l'écran entier.
- Pour donner au port `ZReorderRenderer` une implémentation **sans dépendance
  tierce** — y compris pour les sous-listes du moteur d'édition.

## Quand ne pas l'utiliser

- Pour la **grille 12 colonnes de formulaire** : c'est `ZResponsiveGrid`,
  dans `zcrud_core` — notion distincte des cartes d'items de ce paquet.
- Pour un rendu de liste virtualisée hors grille (`SfDataGrid`) : c'est le
  rôle de `zcrud_list`.

## Le défaut zéro-dépendance du port de réordonnancement {#reorder-renderer}

`ZDefaultReorderRenderer` est l'implémentation de repli du port
`ZReorderRenderer` de `zcrud_core` : bâtie sur le seul SDK Flutter, elle donne
une capacité de réordonnancement **fonctionnelle** à un hôte qui n'installe
aucun satellite dédié. Elle réordonne par **appui long**, autoscroll compris
près des bords du `Scrollable` englobant (`autoScrollEdgeExtent`,
`autoScrollStep`), tient un ordre optimiste local resynchronisé sur la liste
reçue, et expose les **actions sémantiques de déplacement** qu'exige le contrat
du port — la voie non gestuelle n'est jamais facultative.

Ce port a désormais un consommateur de premier plan : la **sous-liste du moteur
d'édition** (`subItems`) rend son glisser-déposer à travers lui. L'injecter à la
racine change donc le rendu de toutes les sous-listes réordonnables du
sous-arbre :

```dart
ZcrudScope(
  reorderRenderer: const ZDefaultReorderRenderer(),
  child: monFormulaire,
);
```

Sans injection, rien ne manque : `zcrud_core` porte pour ce cas un repli
**interne** zéro-configuration (il ne peut pas dépendre d'un satellite), plus
sobre — une colonne, pas d'autoscroll. Le comparatif des trois implémentations
et l'arbitrage entre elles sont sur la fiche
[zcrud_reorder](zcrud_reorder.md#sous-liste) ; le détail de la sous-liste
elle-même est documenté avec le moteur d'édition, voir
[zcrud_core](zcrud_core.md).

## Types clés

| Type | Rôle |
|---|---|
| `ZWindowSizeClass` | Classe de fenêtre Material 3 (`compact`/`medium`/`expanded`) — résolution pure + helper `of(context)`. |
| `ZBreakpointValue<T>` | Valeur générique par breakpoint (cascade mobile-first), bâtie sur `ZBreakpoint` de `zcrud_core`. |
| `computeCrossAxisCount` | Fonction pure : nombre de colonnes borné (`≥ 1` garanti) à partir d'une largeur disponible. |
| `ZResponsiveLayout` | Aiguilleur à 3 builders (compact/medium/expanded) en cascade descendante, mesure locale. |
| `ZAdaptiveGrid` / `ZReorderableAdaptiveGrid` | Grille d'items adaptative — constructeurs `children:`/`.builder`, et sa variante réordonnable. |
| `ZDefaultReorderRenderer` | Défaut zéro-dépendance du port `ZReorderRenderer`, à injecter via `ZcrudScope.reorderRenderer`. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_responsive/README.md) — installation, démarrage rapide, API complète.
- [zcrud_reorder](zcrud_reorder.md) — l'implémentation opt-in du même port, adossée à un paquet de l'écosystème.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
