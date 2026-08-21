---
title: zcrud_select
description: Présentateur de sélection riche (modal, recherche) pour zcrud, adossé au fork vendorisé awesome_select.
---

# zcrud_select

## Rôle

`zcrud_select` fournit `ZSmartSelectPresenter`, un présentateur riche pour
les familles `select`/`radio`/`checkbox`/`multiselect`/`relation`, adossé au
fork vendorisé `awesome_select`. Il rend un modal avec recherche optionnelle,
dont la forme est **adaptative** par défaut (`ZSelectModalShape.adaptive`) :
boîte de dialogue au-delà de 600 dp de largeur utile, feuille par le bas en
deçà — un critère mesuré, jamais un détecteur de plateforme. Les formes fixes
`bottomSheet`, `popupDialog` et `fullPage` restent déclarables. L'apparence de
référence est entièrement personnalisable via une chaîne
paramètre/jeton/référence.

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
| `ZSelectTileReference` | Point d'audit unique des valeurs de référence : dimensions, seuil adaptatif (600 dp), pagination des options, délai de garde d'un chargeur, et formes par défaut. Aucune couleur. |
| `ZSelectChoiceStyle` / `ZSelectModalShape` | Formes des options et du conteneur de modal. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_select/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
