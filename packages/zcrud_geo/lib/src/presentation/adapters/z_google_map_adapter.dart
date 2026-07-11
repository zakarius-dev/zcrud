/// `ZGoogleMapAdapter` — implémentation Google Maps du port [ZMapAdapter] via
/// `google_maps_flutter` (E11b-1, AD-1/AD-12).
///
/// **CONFINEMENT SDK (AD-1)** : c'est le SEUL fichier de `zcrud_geo` qui importe
/// `google_maps_flutter`. Les types SDK (`GoogleMap`, `GoogleMapController`,
/// `LatLng`, `Marker`, `Polygon`, `Circle`, `CameraPosition`…) restent
/// **internes** : l'API publique de cette classe (`implements ZMapAdapter`) ne
/// parle QUE de types neutres (`ZGeoPoint`/`ZGeoShape`/`ZGeoCircle`/`Widget`).
/// Ce fichier n'est PAS exporté par le barrel principal `lib/zcrud_geo.dart` — il
/// est atteint via l'entrée dédiée `package:zcrud_geo/adapters/google.dart`.
///
/// **AD-12 : ZÉRO clé/secret.** Aucune clé API Google Maps n'apparaît dans ce
/// package : la clé vit dans la **config plateforme** de l'app hôte (manifest
/// Android `com.google.android.geo.API_KEY` / `AppDelegate` iOS — E1-5). Le
/// [mapStyleJson] (style de carte) est **surchargeable** par l'app ; aucun
/// endpoint privé en dur, aucun `badCertificateCallback`.
///
/// **Cycle de vie (learning E5, MAJEUR-1)** : l'adaptateur possède un
/// `GoogleMapController` natif (obtenu de façon asynchrone via un `Completer`),
/// disposé en [dispose] (idempotent). Une instance est **à usage unique par
/// montage de champ** (fabrique `ZGoogleMapAdapter.new`), jamais aliasée.
///
/// **Testabilité** : `google_maps_flutter` s'affiche via une **PlatformView
/// native** non peinte sous `flutter test` (headless). La preuve automatisée se
/// limite à : conformité de signature neutre, confinement SDK, no-secret,
/// `dispose` idempotent, `buildMap(...)` sans exception au build. Le rendu
/// interactif réel est validé hors CI (appareil/intégration).
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/z_geo_circle.dart';
import '../../domain/z_geo_map_options.dart';
import '../../domain/z_geo_point.dart';
import '../../domain/z_geo_shape.dart';
import '../z_map_adapter.dart';

/// Adaptateur carte Google Maps (clé API = config plateforme, jamais ici — AD-12).
/// Possède un `GoogleMapController` natif disposé via [dispose] (learning E5).
class ZGoogleMapAdapter implements ZMapAdapter {
  /// Construit l'adaptateur. [fallbackCenter] est le centre neutre si aucun
  /// point/cercle n'est fourni ([initialZoom] : zoom initial) ; [mapStyleJson]
  /// est le style de carte **surchargeable** (jamais un secret).
  ZGoogleMapAdapter({
    this.fallbackCenter = const ZGeoPoint(lat: 0, lng: 0),
    this.initialZoom = 13,
    this.mapStyleJson,
  });

  /// Centre par défaut si aucun point/cercle n'est fourni (neutre — AD-12).
  final ZGeoPoint fallbackCenter;

  /// Zoom initial de la caméra.
  final double initialZoom;

  /// Style JSON de carte **surchargeable** (jamais un secret ; `null` = défaut).
  final String? mapStyleJson;

  /// Complète dès que la carte native est créée (`onMapCreated`). Sert à obtenir
  /// le `GoogleMapController` pour le libérer en [dispose].
  final Completer<GoogleMapController> _controllerCompleter =
      Completer<GoogleMapController>();
  bool _disposed = false;

  @override
  Widget buildMap(
    BuildContext context, {
    ZGeoPoint? center,
    ZGeoShape? shape,
    ZGeoCircle? circle,
    ValueChanged<ZGeoPoint>? onTap,
    bool interactive = true,
    String? tileUrlTemplate, // ignoré (spécifique OSM) — Google n'a pas de tuiles URL
    String? mapStyleJson,
    double? defaultZoom,
    ZGeoMapOptions? mapOptions,
  }) {
    // Surcharges par-champ : priment sur les défauts du constructeur (E11b-1).
    final String? effectiveStyle = mapStyleJson ?? this.mapStyleJson;
    final double effectiveZoom = defaultZoom ?? initialZoom;
    // Centre effectif : centre explicite, sinon centre du cercle (si valide),
    // sinon repli neutre. Aucun défaut « national » en dur (AD-12).
    final ZGeoPoint c = center ??
        (circle != null && circle.isValid ? circle.center : fallbackCenter);

    final Set<Marker> markers = <Marker>{
      if (center != null)
        Marker(
          markerId: const MarkerId('z-geo-center'),
          position: LatLng(center.lat, center.lng),
        )
      else if (circle != null && circle.isValid)
        Marker(
          markerId: const MarkerId('z-geo-center'),
          position: LatLng(circle.center.lat, circle.center.lng),
        ),
    };

    final Set<Polygon> polygons = <Polygon>{
      if (shape != null && shape.vertices.length >= 3)
        Polygon(
          polygonId: const PolygonId('z-geo-area'),
          points: <LatLng>[
            for (final ZGeoPoint v in shape.vertices) LatLng(v.lat, v.lng),
          ],
        ),
    };

    final Set<Circle> circles = <Circle>{
      if (circle != null && circle.isValid)
        Circle(
          circleId: const CircleId('z-geo-circle'),
          center: LatLng(circle.center.lat, circle.center.lng),
          radius: circle.radiusMeters,
        ),
    };

    // DP-7 : options de carte neutres → traduites vers le SDK Google (honoré-si-
    // supporté). `null` → comportement inchangé (défauts du widget GoogleMap
    // préservés via `?? <défaut widget>`).
    return GoogleMap(
      mapType: _toGoogleMapType(mapOptions?.mapType),
      trafficEnabled: mapOptions?.trafficEnabled ?? false,
      buildingsEnabled: mapOptions?.buildingsEnabled ?? true,
      indoorViewEnabled: mapOptions?.indoorViewEnabled ?? true,
      compassEnabled: mapOptions?.compassEnabled ?? true,
      zoomControlsEnabled: mapOptions?.zoomControlsEnabled ?? true,
      mapToolbarEnabled: mapOptions?.mapToolbarEnabled ?? true,
      initialCameraPosition: CameraPosition(
        target: LatLng(c.lat, c.lng),
        zoom: effectiveZoom,
      ),
      style: effectiveStyle,
      onMapCreated: (GoogleMapController controller) {
        // Idempotent : ne compléter qu'une fois, et jamais après dispose.
        if (_disposed) {
          controller.dispose();
          return;
        }
        if (!_controllerCompleter.isCompleted) {
          _controllerCompleter.complete(controller);
        }
      },
      onTap: onTap == null
          ? null
          : (LatLng ll) =>
              onTap(ZGeoPoint(lat: ll.latitude, lng: ll.longitude)),
      markers: markers,
      polygons: polygons,
      circles: circles,
      // `interactive: false` → aperçu non manipulable (lecture seule). Rotation/
      // tilt sont en outre pilotables par la barre d'outils (DP-7) : gardés à
      // `interactive` quand aucune option n'est fournie (comportement inchangé),
      // sinon `interactive && <toggle>`.
      zoomGesturesEnabled: interactive,
      scrollGesturesEnabled: interactive,
      rotateGesturesEnabled:
          interactive && (mapOptions?.rotateGesturesEnabled ?? true),
      tiltGesturesEnabled:
          interactive && (mapOptions?.tiltGesturesEnabled ?? true),
    );
  }

  /// Traduit le type de carte **neutre** [ZGeoMapType] vers le `MapType` du SDK
  /// Google (confiné à ce fichier — AD-1). `null` → `MapType.normal`.
  MapType _toGoogleMapType(ZGeoMapType? type) => switch (type) {
        ZGeoMapType.hybrid => MapType.hybrid,
        ZGeoMapType.satellite => MapType.satellite,
        ZGeoMapType.terrain => MapType.terrain,
        ZGeoMapType.normal || null => MapType.normal,
      };

  @override
  void dispose() {
    if (_disposed) return; // idempotent (contrat ZMapAdapter)
    _disposed = true;
    // Libère le contrôleur natif s'il a déjà été créé ; sinon rien à libérer
    // (la carte n'a jamais été montée — cas fabrique appelée puis démontage
    // immédiat). Fire-and-forget : `dispose` ne doit pas être asynchrone.
    if (_controllerCompleter.isCompleted) {
      unawaited(
        _controllerCompleter.future.then((GoogleMapController c) => c.dispose()),
      );
    }
  }
}
