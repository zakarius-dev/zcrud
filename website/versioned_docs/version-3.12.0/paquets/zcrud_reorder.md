---
title: zcrud_reorder
description: Réordonnancement interne opt-in par glisser-déposer pour zcrud, adossé à reorderable_grid_view.
---

# zcrud_reorder

## Rôle

`zcrud_reorder` est l'implémentation opt-in du port `ZReorderRenderer` de
`zcrud_core` : il réordonne une collection **interne** à l'application par
glisser-déposer, adossé au paquet tiers `reorderable_grid_view`. Le port a un
défaut zéro-dépendance dans `zcrud_responsive` ; les deux implémentations
sont interchangeables.

## Quand l'utiliser

- Pour réordonner une grille d'éléments par glisser-déposer, avec une voie
  accessible non gestuelle intégrée.
- Quand le rendu de `reorderable_grid_view` est préféré au repli par défaut
  de `zcrud_responsive`.

## Quand ne pas l'utiliser

- Pour recevoir un dépôt venu du système ou d'une autre application : c'est
  le rôle de `zcrud_dnd`, une capacité distincte.
- Si le repli zéro-dépendance de `zcrud_responsive` suffit déjà : ce paquet
  reste un choix, jamais une obligation.

## Types clés

| Type | Rôle |
|---|---|
| `ZPackageReorderRenderer` | Seul point d'entrée du paquet, injecté via `ZcrudScope.reorderRenderer`. |
| `kDefaultMoveBeforeLabel` / `kDefaultMoveAfterLabel` | Repli des libellés des actions sémantiques de déplacement quand l'hôte n'en fournit pas — deux littéraux **français** (`'Déplacer avant'` / `'Déplacer après'`), pas des clés résolues par la l10n. Une application non francophone déclare les siens plutôt que de subir ce repli. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_reorder/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
