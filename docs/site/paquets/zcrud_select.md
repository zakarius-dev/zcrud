---
title: zcrud_select
description: Présentateur de sélection riche (modal, recherche) pour zcrud, adossé au fork vendorisé awesome_select.
---

# zcrud_select

## Rôle

`zcrud_select` fournit `ZSmartSelectPresenter`, un présentateur riche pour
les familles `select`/`radio`/`checkbox`/`multiselect`/`relation`, adossé au
fork vendorisé `awesome_select`. Il rend un modal en bottom-sheet avec
recherche optionnelle, avec une apparence de référence par défaut
entièrement personnalisable via une chaîne paramètre/jeton/référence.

## Quand l'utiliser

- Pour un rendu de sélection riche (modal, recherche) sur les champs de type
  choix, plutôt que le rendu natif du cœur.

## Quand ne pas l'utiliser

- Si le rendu natif du cœur suffit : sans enrôlement du présentateur, ces
  familles conservent leur rendu natif sans aucune régression.

## Types clés

| Type | Rôle |
|---|---|
| `ZSmartSelectPresenter` | Présentateur riche, à injecter via `ZcrudScope.selectPresenter`. |
| `ZSelectTileSpec` | Surcharge par paramètre de l'apparence. |
| `ZSelectTileReference` | Valeurs de référence auditées (dimensions uniquement). |
| `ZSelectChoiceStyle` / `ZSelectModalShape` | Formes des options et du conteneur de modal. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_select/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
