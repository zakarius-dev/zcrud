---
title: zcrud_navigation
description: Politique de présentation d'édition dérivée du breakpoint pour zcrud, et son exécution pluggable.
---

# zcrud_navigation

## Rôle

`zcrud_navigation` dérive la présentation d'un formulaire d'édition
(`page`/`sheet`/`dialog`) du breakpoint courant, via une politique pure
(`ZPresentationPolicy`) et l'exécute via un port pluggable
(`ZFormPresenter`/`ZAdaptivePresenter`). Il ajoute un chrome interne opt-in
(`ZEditionChrome`) et une feuille contrainte et encadrée par défaut en mode
`sheet`.

## Quand l'utiliser

- Pour présenter un formulaire d'édition de façon adaptative, avec une règle
  breakpoint → surface centralisée plutôt que figée au call-site.
- Pour un chrome interne (titre, actions submit/discard) cohérent entre les
  trois modes de présentation.

## Quand ne pas l'utiliser

- Si votre application gère déjà entièrement sa propre présentation modale
  et n'a pas besoin de la dériver du breakpoint : le port `ZFormPresenter`
  reste substituable, mais `presentEdition` n'est alors pas nécessaire.

## Types clés

| Type | Rôle |
|---|---|
| `presentEdition` | Helper de câblage complet breakpoint → politique → mode → surface. |
| `ZPresentationPolicy` | Politique pure dérivant le mode d'un `ZWindowSizeClass`. |
| `ZFormPresenter` / `ZAdaptivePresenter` | Port pluggable d'exécution et son implémentation par défaut. |
| `ZEditionChrome` / `ZEditionScaffold` | Chrome interne opt-in, rendu par mode. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_navigation/README.md) — installation, démarrage rapide, API complète.
- Matrice de paramètres : `packages/zcrud_navigation/doc/parameter-matrix-z-adaptive-presenter.md`.
- [zcrud_get](zcrud_get.md) — implémentation manager du port `ZFormPresenter`.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
