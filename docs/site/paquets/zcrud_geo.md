---
title: zcrud_geo
description: Champ géo riche — point/cercle/aire neutre, adaptateurs carte pluggables (OSM/Google), édition sur carte.
---

# zcrud_geo

## Rôle

`zcrud_geo` porte les types de champ `location` (point) et `geoArea`
(polygone), ainsi qu'une géométrie `circle` additive, autour d'un modèle de
valeur **pur-Dart** (`ZGeoPoint`/`ZGeoCircle`/`ZGeoShape`) qui n'expose jamais
un type de SDK carte. Le rendu passe par le port `ZMapAdapter`, implémenté par
un adaptateur OpenStreetMap (`flutter_map`, sans clé API) et un adaptateur
Google Maps optionnel — chacun confiné à sa propre entrée d'import dédiée,
jamais exposée par le barrel principal (invariant
[AD-1](../concepts/invariants.md#ad-1)). Le widget de champ
(`ZGeoFieldWidget`) suit le patron réactif granulaire du cœur
(invariant [AD-2](../concepts/invariants.md#ad-2)).

## Quand l'utiliser

- Pour un champ de formulaire saisissant une **position**, un **cercle** ou
  une **zone géographique** — avec édition sur carte, barre d'outils,
  plein écran, style de forme et chip de métriques (aire/périmètre).
- Pour afficher plusieurs valeurs géo sur une carte hors formulaire
  (`ZGeoMapView`), sans passer par un champ d'édition.
- Pour lire des valeurs géo persistées par un format JSON historique
  polymorphe, sans script de migration (voir
  [doc/migration-legacy-dodlp-geo.md](../../packages/zcrud_geo/doc/migration-legacy-dodlp-geo.md)).

## Quand ne pas l'utiliser

- Pour une simple résolution « ma position » côté hôte sans champ de
  formulaire : passez par `zcrud_geo_location`, qui fournit un
  `ZGeoLocationResolver` clé en main.
- Pour un rendu de carte totalement indépendant du moteur de formulaire
  zcrud, si votre application a déjà une intégration carte dédiée.

## Types clés

| Type | Rôle |
|---|---|
| `ZGeoPoint` / `ZGeoCircle` / `ZGeoShape` | Modèle de valeur neutre : point, cercle, aire ou tracé — sérialisation défensive (invariant [AD-10](../concepts/invariants.md#ad-10)). |
| `ZGeoFieldConfig` / `ZGeoGeometry` / `ZGeoPresentation` | Config additive du champ (invariant [AD-4](../concepts/invariants.md#ad-4)) : géométrie, défauts de carte, présentation, capacités opt-in. |
| `ZGeoFieldWidget` | Champ d'édition géo complet, servi via `ZWidgetRegistry`. |
| `ZMapAdapter` / `ZOsmMapAdapter` / `ZGoogleMapAdapter` | Port de rendu carte en types neutres, et ses deux adaptateurs concrets. |
| `ZGeoMapView` | Vue de lecture multi-formes hors formulaire. |

## Voir aussi

- [README du paquet](../../packages/zcrud_geo/README.md) — installation, démarrage rapide, API complète.
- [`zcrud_geo_location`](./zcrud_geo_location.md) — resolver « ma position » clé en main pour ce paquet.
- [Réactivité granulaire](../concepts/reactivite-granulaire.md) — AD-2 en pratique.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
