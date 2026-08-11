/// Fabrique du `ZGeoLocationResolver` clé en main (G10, parité legacy
/// `gff:219-265` `centerOnCurrentLocation`).
///
/// origine: `zcrud_geo` expose le port `ZGeoLocationResolver`
/// (`Future<ZGeoPoint?> Function()`) mais n'embarque AUCUN SDK de
/// géolocalisation ni permission (AD-1). Ce satellite fournit
/// l'implémentation : l'hôte fait `locationResolver: zcrudGeolocatorResolver()`
/// sans importer `geolocator`. Le champ recentre déjà (zoom 16) sur la
/// position résolue — rien d'autre à câbler côté hôte.
///
/// **Contrat d'échec (AD-10)** : le resolver ne throw JAMAIS. Tout échec rend
/// `null` (contrat nominal du port) après avoir notifié sa cause distincte à
/// l'éventuel [ZGeoLocationFailureListener] — service désactivé, permission
/// refusée, refusée à vie, ou erreur plugin/timeout/position invalide. Le
/// MESSAGE utilisateur (le legacy affiche un SnackBar quand le service est
/// désactivé) reste à la charge de l'hôte : ce paquet expose la cause,
/// jamais un libellé (FR-26/l10n hôte).
library;

import 'package:zcrud_geo/zcrud_geo.dart';

import 'geolocator_gateway_impl.dart';
import 'z_geo_location_cause.dart';
import 'z_geo_location_gateway.dart';

/// Construit un [ZGeoLocationResolver] adossé à `geolocator`.
///
/// - [onFailure] : notifié de la [ZGeoLocationFailureCause] (au plus une par
///   appel) juste avant que le resolver rende `null`. Jamais appelé en succès.
///   Un throw dans ce callback est avalé (AD-10).
/// - [gateway] : couche plugin injectable — un fake en test, la passerelle
///   `geolocator` réelle par défaut (le plugin ne tourne pas en test widget).
///
/// Cycle mesuré sur le legacy (`gff:219-265`) :
/// 1. service désactivé → cause [ZGeoLocationFailureCause.serviceDisabled] ;
/// 2. permission `denied` → UNE redemande ; encore `denied` → cause
///    [ZGeoLocationFailureCause.permissionDenied] ;
/// 3. `deniedForever` (au contrôle — sans redemande — ou après la redemande)
///    → cause [ZGeoLocationFailureCause.permissionDeniedForever] ;
/// 4. lecture en précision haute (10 s max) ; throw ou position hors-bornes →
///    cause [ZGeoLocationFailureCause.error] ;
/// 5. succès → `ZGeoPoint` (le champ recentre, zoom 16 — parité `gff:255`).
ZGeoLocationResolver zcrudGeolocatorResolver({
  ZGeoLocationFailureListener? onFailure,
  ZGeoLocationGateway? gateway,
}) {
  final ZGeoLocationGateway effective = gateway ?? const GeolocatorGateway();

  void notify(ZGeoLocationFailureCause cause) {
    try {
      onFailure?.call(cause);
    } catch (_) {
      // AD-10 : un listener hôte défaillant ne fait jamais throw le resolver.
    }
  }

  return () async {
    try {
      if (!await effective.isServiceEnabled()) {
        notify(ZGeoLocationFailureCause.serviceDisabled);
        return null;
      }

      var permission = await effective.checkPermission();
      if (permission == ZGeoLocationPermission.denied) {
        // Parité gff:234-237 : une SEULE redemande.
        permission = await effective.requestPermission();
        if (permission == ZGeoLocationPermission.denied) {
          notify(ZGeoLocationFailureCause.permissionDenied);
          return null;
        }
      }
      if (permission == ZGeoLocationPermission.deniedForever) {
        notify(ZGeoLocationFailureCause.permissionDeniedForever);
        return null;
      }

      final point = await effective.currentPosition();
      if (!point.isValid) {
        // Position non finie / hors-bornes : jamais réinjectée dans le champ.
        notify(ZGeoLocationFailureCause.error);
        return null;
      }
      return point;
    } catch (_) {
      // AD-10 / parité gff:262-264 : tout throw (plugin, canal natif, timeout)
      // est confiné en échec propre.
      notify(ZGeoLocationFailureCause.error);
      return null;
    }
  };
}
