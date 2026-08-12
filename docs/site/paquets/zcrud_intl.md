---
title: zcrud_intl
description: Champs téléphone, pays, devise, état/province et adresse — valeurs de tranche neutres, catalogues paresseux, assets bundlés.
---

# zcrud_intl

## Rôle

`zcrud_intl` sert cinq champs additifs à `zcrud_core` : téléphone
(`phoneNumber`, rendu natif), pays (`country`), adresse (`address`/
`addressSearchField`, sous-formulaire structuré) via `ZWidgetRegistry`, et
deux champs composables — devise ([ZCurrencyField]) et état/province
([ZStateField]) — que l'app enregistre elle-même sous le `kind` de son
choix. Chaque champ émet une valeur de tranche **neutre** (`String` ou
modèle pur-Dart de ce paquet) : aucun type d'une lib téléphone tierce ne
fuit jamais dans le formulaire. Les catalogues pays/devise/subdivisions
sont servis depuis des assets JSON bundlés, chargés paresseusement.

## Quand l'utiliser

- Pour ajouter un **champ téléphone international**, un **sélecteur
  pays**, une **adresse structurée** (avec recherche géo optionnelle), un
  **sélecteur devise** ou un **champ état/province** à un formulaire
  `zcrud_core`.
- Pour manipuler des valeurs neutres ([ZPhoneNumber], [ZPostalAddress],
  [ZMoney]) hors formulaire, avec une (dé)sérialisation qui ne lève jamais.

## Quand ne pas l'utiliser

- Pour du formatage de date localisé seul : c'est un **point d'entrée
  séparé** (`package:zcrud_intl/date_formatter.dart`), afin qu'un hôte qui
  n'a besoin que des champs de ce paquet ne paie pas le poids des données
  CLDR.
- Pour des champs géographiques (coordonnées, carte) : c'est le rôle de
  `zcrud_geo`.

## Types clés

| Type | Rôle |
|---|---|
| `ZPhoneFieldWidget` | Champ téléphone international — rendu natif, valeur de tranche `String` en forme internationale. |
| `ZAddressFieldWidget` / `ZPostalAddress` | Sous-formulaire adresse structuré et son modèle neutre, avec recherche géo optionnelle. |
| `ZCountryFieldWidget` / `ZCountryCatalog` | Champ pays et son catalogue paresseux + caché, chargé depuis un asset bundlé. |
| `ZCurrencyField` / `ZStateField` | Champs composables devise et état/province, dépendant du catalogue et du pays courant. |
| `ZIntlFieldConfig` | Config additive par champ — défauts nationaux surchargeables, jamais codés en dur. |

## Voir aussi

- [README du paquet](https://github.com/zakarius-dev/zcrud/blob/main/packages/zcrud_intl/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
