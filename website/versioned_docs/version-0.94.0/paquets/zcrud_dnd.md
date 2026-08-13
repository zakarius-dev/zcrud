---
title: zcrud_dnd
description: Dépôt natif opt-in (fichiers, images, textes, adresses) pour zcrud, adossé à super_drag_and_drop.
---

# zcrud_dnd

## Rôle

`zcrud_dnd` est l'implémentation opt-in du port `ZDropRegionRenderer` de
`zcrud_core` : il reçoit des dépôts **natifs**, c'est-à-dire venus du système
ou d'une autre application (fichier glissé depuis l'explorateur, image
déposée depuis un navigateur). Il est adossé au paquet tiers
`super_drag_and_drop`, dont le code natif et les binaires précompilés ne sont
téléchargés que si ce paquet est ajouté.

## Quand l'utiliser

- Pour recevoir des fichiers, images, adresses ou textes déposés depuis le
  système d'exploitation ou une autre application.
- Pour un hôte prêt à assumer le coût de build d'une dépendance native
  (`super_drag_and_drop`) en échange de ce dépôt natif.

## Quand ne pas l'utiliser

- Pour réordonner une collection **interne** à l'application (glisser une
  carte dans une liste) : c'est le rôle de `zcrud_reorder`, sans aucune
  chaîne de compilation native.
- Si l'application n'a besoin d'aucun dépôt : le port a un défaut
  zéro-dépendance dans `zcrud_core` (`ZNoDropRegionRenderer`).

## Types clés

| Type | Rôle |
|---|---|
| `ZNativeDropRegionRenderer` | Implémentation native du port, seul point d'entrée du paquet. |
| `ZDropItemSource` | Couture neutre qui confine le paquet tiers, testable sans engine natif. |
| `ZDropReadFailure` | Échec porté par la future de lecture des octets d'un élément déposé. |
| `zBuildDroppedItems` / `zCandidateDropKinds` / `zSelectDropKind` | Fonctions pures de traduction et de filtrage par nature de dépôt. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_dnd/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
