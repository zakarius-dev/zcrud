---
title: zcrud_list
description: Backend de rendu Syncfusion SfDataGrid du port ZListRenderer, seule arête Syncfusion du graphe.
---

# zcrud_list

## Rôle

`zcrud_list` **n'est pas « l'écran de liste »** : c'est le **backend de
rendu** Syncfusion du port `ZListRenderer` déclaré dans `zcrud_core`. Il
fournit `ZSfDataGridRenderer`, qui transforme une demande de rendu neutre en
grille `SfDataGrid` — sans barre d'application, sans recherche, sans
navigation vers l'édition. Pour un écran CRUD complet et assemblé, voir
[zcrud_screen](zcrud_screen.md), derrière lequel ce renderer s'injecte.

C'est la seule arête Syncfusion du graphe zcrud pour la liste : un
consommateur qui ne l'importe pas ne tire aucune dépendance Syncfusion.

## Quand l'utiliser

- Pour rendre les tableaux de `DynamicList` (ou de `zcrud_screen` en layout
  tableau) avec la grille de données Syncfusion, avec persistance de scroll et
  de sélection au rebuild.
- Pour les capacités tabulaires riches, toutes opt-in : pagination automatique
  au scroll (`onLoadMore`), pager numéroté (`rowsPerPage`), copie de cellule
  au long-press, actions révélées au swipe, en-têtes empilés
  (`stackedHeaders`), dimensionnement par colonne (`columnSizing`),
  redimensionnement interactif, hauteur de ligne adaptative et style
  conditionnel de cellule (`cellStyleBuilder`).

## Quand ne pas l'utiliser

- Si l'application n'affiche aucune liste tabulaire : évite d'embarquer
  Syncfusion.
- Si vous cherchez l'écran CRUD assemblé : c'est [zcrud_screen](zcrud_screen.md).
- Si une autre implémentation de `ZListRenderer` est fournie par l'hôte.

## Types clés

| Type | Rôle |
|---|---|
| `ZSfDataGridRenderer` | Renderer concret, injecté via `ZcrudScope.listRenderer`. |
| `ZSfCellStyle` | Style conditionnel d'une cellule (fond, texte, alignement, marge, `maxLines`). |
| `ZSfStackedHeader` | Groupe d'en-tête empilé : une clé de libellé couvrant plusieurs colonnes. |
| `ZSfColumnSizing` | Dimensionnement d'une colonne (largeur, min, max, mode, marge d'auto-ajustement). |

## Largeur de colonnes

`columnWidthMode` est nullable et `null` par défaut : le mode est alors dérivé
de la plateforme et du nombre de colonnes de données — `auto` au-delà de 3
colonnes en web et bureau, au-delà de 1 en mobile, `fill` en deçà. Une valeur
explicite écrase la dérivation : `columnWidthMode: ColumnWidthMode.fill` fige
la répartition sur toute la largeur disponible.

`ColumnWidthMode` est ré-exporté par le barrel du paquet — seul type
Syncfusion présent dans sa signature publique : cette échappatoire s'écrit
donc sans déclarer de dépendance Syncfusion dans l'application.

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_list/README.md) — installation, démarrage rapide, API complète.
- [zcrud_screen](zcrud_screen.md) — l'écran CRUD assemblé, à ne pas confondre avec ce backend de rendu.
- [zcrud_export](zcrud_export.md) — export tabulaire partageant le même formateur de colonne.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
