# zcrud_geo_location

Resolver « ma position » clé en main pour [zcrud_geo](../zcrud_geo) : un
`ZGeoLocationResolver` adossé à [geolocator](https://pub.dev/packages/geolocator),
avec des causes d'échec distinctes — invariant [AD-1](../../docs/site/concepts/invariants.md#ad-1)
(`geolocator` vit exclusivement ici, jamais dans `zcrud_geo`).

## Aperçu {#apercu}

`zcrud_geo` expose le port `ZGeoLocationResolver`
(`Future<ZGeoPoint?> Function()`) mais n'embarque aucun SDK de
géolocalisation ni permission plateforme. Ce paquet satellite fournit
l'implémentation prête à l'emploi : l'application hôte injecte
`zcrudGeolocatorResolver()` sans jamais importer `geolocator` elle-même —
aucun type `geolocator` n'apparaît dans l'API publique.

**Utilisez ce paquet** si votre champ géo doit proposer un bouton « ma
position » adossé au plugin `geolocator`, avec des causes d'échec
exploitables côté hôte pour informer l'utilisateur. **N'utilisez pas ce
paquet** si vous fournissez déjà votre propre implémentation du seam
`ZGeoLocationResolver`, ou si votre application n'a pas besoin de
géolocalisation.

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`. Déclarez en outre les permissions plateforme
décrites ci-dessous : ce paquet n'embarque aucun manifeste.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:zcrud_geo/zcrud_geo.dart';
import 'package:zcrud_geo_location/zcrud_geo_location.dart';

/// Injecté dans le seam neutre du champ géo (le champ masque le bouton « ma
/// position » quand le resolver est absent, et recentre au zoom 16 sur la
/// position résolue).
ZGeoLocationResolver buildLocationResolver() {
  return zcrudGeolocatorResolver(
    onFailure: (ZGeoLocationFailureCause cause) {
      // Le message affiché à l'utilisateur reste à la charge de l'hôte
      // (l10n applicative) : par exemple informer sur `serviceDisabled`,
      // rester silencieux sur un refus de permission.
    },
  );
}

// Puis, côté widget : ZGeoFieldWidget.builder(locationResolver: buildLocationResolver())
```

## Concepts clés {#concepts-cles}

- **Le resolver ne throw jamais** ([AD-10](../../docs/site/concepts/invariants.md#ad-10))
  — tout échec complète avec `null` (le contrat nominal du port), après avoir
  notifié `onFailure` avec une cause distincte.
- **Causes d'échec distinctes** — `ZGeoLocationFailureCause` sépare service
  désactivé, permission refusée, permission refusée définitivement et erreur
  générique, pour que l'hôte adapte son message.
- **Port injectable pour les tests** — `ZGeoLocationGateway` isole la couche
  plugin ; un faux de ce port suffit à exercer toutes les branches sans
  toucher au canal de plateforme natif.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `zcrudGeolocatorResolver({onFailure, gateway})` | Fabrique du `ZGeoLocationResolver` clé en main, adossé à `geolocator`. |
| `ZGeoLocationFailureCause` | Cause distincte d'un échec (`serviceDisabled`, `permissionDenied`, `permissionDeniedForever`, `error`). |
| `ZGeoLocationFailureListener` | Signature du callback `onFailure`. |
| `ZGeoLocationGateway` | Port neutre injectable vers la couche plugin, pour fake en test. |
| `ZGeoLocationPermission` | État de permission neutre (projection des valeurs du plugin). |
| `GeolocatorGateway` | Implémentation réelle de `ZGeoLocationGateway`, adossée à `geolocator`. |

## Cas limites et invariants {#cas-limites}

Le resolver ne throw **jamais** (invariant AD-10). Toute défaillance complète
avec `null` — le contrat nominal du port — après avoir notifié `onFailure`
avec exactement une cause distincte :

| Cause | Signification |
|---|---|
| `serviceDisabled` | Le service de localisation de l'appareil est désactivé — un hôte informe généralement l'utilisateur. |
| `permissionDenied` | `denied` au contrôle, encore `denied` après l'unique redemande — un hôte reste généralement silencieux. |
| `permissionDeniedForever` | Refusée définitivement (au contrôle — sans redemande — ou après elle) ; seuls les réglages système peuvent la rouvrir. |
| `error` | Exception du plugin, timeout de lecture (10 s), ou position hors-bornes/non finie. |

Sur un succès, `onFailure` n'est jamais appelé. La lecture utilise
`LocationAccuracy.high`, `distanceFilter: 10`, `timeLimit: 10 s`. Chaque appel
du resolver rejoue le cycle complet (le service et la permission sont
re-vérifiés à chaque fois — l'utilisateur a pu les changer entre-temps).

**Permissions plateforme — à la charge de l'application hôte.** Ce paquet
n'embarque **aucun manifeste et ne déclare aucune permission**. Sans ces
déclarations, la demande de permission échoue au niveau du système
d'exploitation et le resolver rapporte `permissionDenied`/`error` — il ne
throw toujours pas.

**Android** — `android/app/src/main/AndroidManifest.xml` :

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<!-- Repli grossier optionnel : -->
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

**iOS** — `ios/Runner/Info.plist` :

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Expliquez ici pourquoi votre application a besoin de la position de l'utilisateur.</string>
```

**Tester côté hôte** : la couche plugin est injectable — implémentez le port
neutre `ZGeoLocationGateway` (indicateur de service, états de permission,
position) et passez-le via `zcrudGeolocatorResolver(gateway: fake)` pour
exercer chaque branche sans toucher au canal de plateforme.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_geo_location.md`](../../docs/site/paquets/zcrud_geo_location.md)
- [`zcrud_geo`](../zcrud_geo/README.md) — le champ géo dont ce paquet fournit le resolver « ma position ».
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.

## Licence {#licence}

MIT — voir la racine du dépôt.
