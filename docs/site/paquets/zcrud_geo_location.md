---
title: zcrud_geo_location
description: Resolver « ma position » clé en main pour zcrud_geo, adossé à geolocator, sans fuite de type SDK.
---

# zcrud_geo_location

## Rôle

`zcrud_geo` expose le port `ZGeoLocationResolver`
(`Future<ZGeoPoint?> Function()`) mais n'embarque aucun SDK de
géolocalisation ni permission plateforme. `zcrud_geo_location` fournit
l'implémentation prête à l'emploi : `zcrudGeolocatorResolver()` adosse ce
port à [geolocator](https://pub.dev/packages/geolocator), avec des causes
d'échec distinctes (`ZGeoLocationFailureCause`) remontées via `onFailure`.
Aucun type `geolocator` n'apparaît dans l'API publique (invariant
[AD-1](../concepts/invariants.md#ad-1) : le plugin vit exclusivement dans ce
paquet, jamais dans `zcrud_geo`).

## Quand l'utiliser

- Pour proposer un bouton « ma position » sur un champ géo (`ZGeoFieldWidget`)
  sans réécrire la logique service/permission/lecture.
- Pour distinguer côté hôte les causes d'un échec de résolution — service
  désactivé, permission refusée, refusée définitivement, erreur générique —
  et adapter le message affiché à l'utilisateur.

## Quand ne pas l'utiliser

- Si vous fournissez déjà votre propre implémentation du seam
  `ZGeoLocationResolver` (ex. un service de localisation maison).
- Si votre application n'a pas besoin de géolocalisation : le seam du champ
  géo est optionnel, laissez-le simplement absent.

## Types clés

| Type | Rôle |
|---|---|
| `zcrudGeolocatorResolver({onFailure, gateway})` | Fabrique du `ZGeoLocationResolver` clé en main. |
| `ZGeoLocationFailureCause` | Cause distincte d'un échec (`serviceDisabled`, `permissionDenied`, `permissionDeniedForever`, `error`). |
| `ZGeoLocationGateway` | Port neutre injectable vers la couche plugin, pour fake en test. |
| `GeolocatorGateway` | Implémentation réelle du port, adossée à `geolocator`. |

## Voir aussi

- [README du paquet](../../packages/zcrud_geo_location/README.md) — installation, permissions plateforme, démarrage rapide.
- [`zcrud_geo`](./zcrud_geo.md) — le champ géo dont ce paquet fournit le resolver « ma position ».
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
