/// Implémentation `geolocator` du port [ZGeoLocationGateway] (G10).
///
/// **SEUL fichier du paquet qui importe `geolocator`** (AD-1 : SDK confiné,
/// jamais exporté par le barrel — aucun type geolocator ne fuit). Les valeurs
/// de lecture répliquent le legacy `gff:241-247` : `LocationAccuracy.high`,
/// `distanceFilter: 10`, `timeLimit: 10 s`.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:geolocator/geolocator.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

import 'z_geo_location_gateway.dart';

/// Passerelle réelle vers le plugin `geolocator`. Ses méthodes propagent les
/// exceptions du plugin telles quelles : le confinement AD-10 (throw → cause
/// `error`, jamais d'échappée) vit dans le resolver, pas ici.
class GeolocatorGateway implements ZGeoLocationGateway {
  /// Construit la passerelle réelle (sans état — le plugin est statique).
  const GeolocatorGateway();

  /// Réglages de lecture, parité legacy `gff:242-246` (`LocationAccuracy.high`,
  /// `distanceFilter: 10`, `timeLimit: 10 s`). Visibles pour que les tests
  /// affirment la parité SANS toucher au canal natif (les enums/const de
  /// `geolocator` sont du Dart pur).
  @visibleForTesting
  static const LocationSettings locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
    timeLimit: Duration(seconds: 10),
  );

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<ZGeoLocationPermission> checkPermission() async =>
      mapLocationPermission(await Geolocator.checkPermission());

  @override
  Future<ZGeoLocationPermission> requestPermission() async =>
      mapLocationPermission(await Geolocator.requestPermission());

  @override
  Future<ZGeoPoint> currentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: locationSettings,
    );
    return ZGeoPoint(lat: position.latitude, lng: position.longitude);
  }

  /// Projette les 5 valeurs de `LocationPermission` sur l'état neutre :
  /// `denied` → [ZGeoLocationPermission.denied] ; `deniedForever` →
  /// [ZGeoLocationPermission.deniedForever] ; `whileInUse`/`always` →
  /// [ZGeoLocationPermission.granted] ; `unableToDetermine` →
  /// [ZGeoLocationPermission.granted] (parité `gff:232-241` : le legacy ne
  /// court-circuite que `denied`/`deniedForever` et TENTE la lecture sinon —
  /// un échec réel devient alors la cause `error`).
  @visibleForTesting
  static ZGeoLocationPermission mapLocationPermission(
    LocationPermission permission,
  ) {
    switch (permission) {
      case LocationPermission.denied:
        return ZGeoLocationPermission.denied;
      case LocationPermission.deniedForever:
        return ZGeoLocationPermission.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
      case LocationPermission.unableToDetermine:
        return ZGeoLocationPermission.granted;
    }
  }
}
