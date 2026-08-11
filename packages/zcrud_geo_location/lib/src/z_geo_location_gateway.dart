/// Port **neutre** vers la couche plugin de géolocalisation (G10).
///
/// origine: `geolocator` est un plugin à canal de plateforme — il ne tourne
/// pas en test widget. Le resolver ne parle donc JAMAIS au plugin en direct :
/// il traverse ce port pur (types `zcrud_geo` + types Dart), dont
/// l'implémentation réelle (`GeolocatorGateway`, `src/geolocator_gateway_impl.dart`)
/// confine `geolocator` à son propre fichier (AD-1 : aucun type geolocator en
/// signature publique). Un FAKE de ce port suffit à tester toutes les branches
/// de cause.
library;

import 'package:zcrud_geo/zcrud_geo.dart';

/// État de permission **neutre** (projection des 5 valeurs de
/// `LocationPermission` du plugin — mapping documenté sur l'implémentation).
enum ZGeoLocationPermission {
  /// Refusée — une redemande est possible.
  denied,

  /// Refusée définitivement — redemander est inutile.
  deniedForever,

  /// Accordée (ou indéterminable : le legacy tente alors la lecture,
  /// `gff:232-241` ne court-circuite que `denied`/`deniedForever`).
  granted,
}

/// Port d'accès à la plateforme de localisation. Chaque méthode PEUT throw
/// (plugin, canal natif, timeout) : c'est le resolver qui confine tout throw
/// en cause [`error`] (AD-10) — le port n'a pas à être défensif lui-même.
abstract class ZGeoLocationGateway {
  /// `true` si le service de localisation de l'appareil est actif.
  Future<bool> isServiceEnabled();

  /// État courant de la permission, sans interaction utilisateur.
  Future<ZGeoLocationPermission> checkPermission();

  /// Demande la permission à l'utilisateur et renvoie l'état résultant.
  Future<ZGeoLocationPermission> requestPermission();

  /// Lit la position courante (précision haute, parité legacy `gff:241-247` :
  /// `LocationAccuracy.high`, `distanceFilter: 10`, timeout 10 s).
  Future<ZGeoPoint> currentPosition();
}
