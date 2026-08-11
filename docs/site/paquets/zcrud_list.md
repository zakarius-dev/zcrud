---
title: zcrud_list
description: Backend Syncfusion SfDataGrid de DynamicList pour zcrud, seule arête Syncfusion du graphe.
---

# zcrud_list

## Rôle

`zcrud_list` fournit `ZSfDataGridRenderer`, l'implémentation concrète du port
`ZListRenderer` déclaré dans `zcrud_core`, adossée à Syncfusion `SfDataGrid`.
C'est la seule arête Syncfusion du graphe zcrud pour la liste : un
consommateur qui ne l'importe pas ne tire aucune dépendance Syncfusion.

## Quand l'utiliser

- Pour rendre `DynamicList` avec la grille de données Syncfusion, avec
  persistance de scroll et de sélection au rebuild.
- Pour la pagination automatique au scroll (`onLoadMore`) ou la coloration
  de cellule (`cellColorBuilder`), tous deux additifs et opt-in.

## Quand ne pas l'utiliser

- Si l'application n'affiche aucune liste : évite d'embarquer Syncfusion.
- Si une autre implémentation de `ZListRenderer` est fournie par l'hôte.

## Types clés

| Type | Rôle |
|---|---|
| `ZSfDataGridRenderer` | Seul point d'entrée du paquet, injecté via `ZcrudScope.listRenderer`. |

## Voir aussi

- [README du paquet](../../packages/zcrud_list/README.md) — installation, démarrage rapide, API complète.
- [zcrud_export](zcrud_export.md) — export tabulaire partageant le même formateur de colonne.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
