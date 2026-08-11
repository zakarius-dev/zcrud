/// Barrel d'API publique de `zcrud_geo_location`.
///
/// Satellite « ma position » clé en main (G10) : fournit un
/// `ZGeoLocationResolver` (port de `zcrud_geo`) adossé à `geolocator` —
/// `resolver: zcrudGeolocatorResolver()` suffit côté hôte, avec des causes
/// d'échec distinctes (`ZGeoLocationFailureCause`) via `onFailure`.
///
/// **AD-1 (isolation)** : ce barrel n'exporte AUCUN symbole `geolocator` — le
/// plugin est confiné à `src/geolocator_gateway_impl.dart` (jamais exporté).
/// L'API publique ne parle que les types de `zcrud_geo` (`ZGeoPoint`,
/// `ZGeoLocationResolver`) et les types neutres de ce paquet.
///
/// **Permissions plateforme** : AUCUNE n'est déclarée par ce paquet — l'app
/// hôte déclare AndroidManifest/Info.plist (cf. README).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/z_geo_location_cause.dart';
export 'src/z_geo_location_gateway.dart';
export 'src/zcrud_geolocator_resolver.dart';
