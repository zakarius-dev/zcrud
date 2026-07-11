/// `ZOsmMapAdapter` — implémentation OSM du port [ZMapAdapter] via `flutter_map`
/// (E11a-1, AD-1/AD-12).
///
/// **CONFINEMENT SDK (AD-1)** : c'est le SEUL fichier de `zcrud_geo` qui importe
/// `flutter_map`/`latlong2`. Les types SDK (`LatLng`, `MapController`,
/// `FlutterMap`…) restent **internes** : l'API publique de cette classe
/// (`implements ZMapAdapter`) ne parle QUE de types neutres (`ZGeoPoint`/
/// `ZGeoShape`/`Widget`). Ce fichier n'est PAS exporté par le barrel principal
/// `lib/zcrud_geo.dart` — il est atteint via l'entrée dédiée
/// `package:zcrud_geo/adapters/osm.dart` (voie d'import explicite).
///
/// **AD-12 : ZÉRO clé/secret.** OSM ne requiert aucune clé API. Le `urlTemplate`
/// des tuiles est le point de terminaison public OSM standard, **surchargeable**
/// par l'app hôte via [tileUrlTemplate] (jamais un endpoint privé en dur, jamais
/// de `badCertificateCallback`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/z_geo_circle.dart';
import '../../domain/z_geo_map_options.dart';
import '../../domain/z_geo_point.dart';
import '../../domain/z_geo_shape.dart';
import '../z_map_adapter.dart';

/// Adaptateur carte OSM (sans clé API). Possède un `MapController` natif disposé
/// via [dispose] (learning E5).
class ZOsmMapAdapter implements ZMapAdapter {
  /// Construit l'adaptateur. [tileUrlTemplate] est surchargeable (défaut : OSM
  /// public) ; [userAgentPackageName] identifie l'app hôte auprès d'OSM.
  ZOsmMapAdapter({
    this.tileUrlTemplate = _defaultOsmTiles,
    this.userAgentPackageName = 'com.example.app',
    this.fallbackCenter = const ZGeoPoint(lat: 0, lng: 0),
    this.initialZoom = 13,
  });

  /// Point de terminaison public standard des tuiles OSM (aucun secret).
  static const String _defaultOsmTiles =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Gabarit d'URL de tuiles (surchargeable ; défaut OSM public — AD-12).
  final String tileUrlTemplate;

  /// User-agent transmis au serveur de tuiles (politique d'usage OSM).
  final String userAgentPackageName;

  /// Centre par défaut si aucun point/sommet n'est fourni.
  final ZGeoPoint fallbackCenter;

  /// Zoom initial.
  final double initialZoom;

  final MapController _controller = MapController();
  bool _disposed = false;

  @override
  Widget buildMap(
    BuildContext context, {
    ZGeoPoint? center,
    ZGeoShape? shape,
    ZGeoCircle? circle,
    ValueChanged<ZGeoPoint>? onTap,
    bool interactive = true,
    String? tileUrlTemplate,
    String? mapStyleJson, // ignoré (spécifique Google) — OSM n'a pas de style JSON
    double? defaultZoom,
    // DP-7 : `flutter_map` (tuiles raster OSM) n'expose ni type satellite/hybride
    // ni trafic/bâtiments/indoor/boussole natifs → `mapOptions` est **ignoré**
    // ici (contrat « honoré-si-supporté, ignore le reste »). Le paramètre est
    // accepté pour l'uniformité du port ; un adaptateur raster ne le honore pas.
    ZGeoMapOptions? mapOptions,
  }) {
    // Surcharges par-champ : priment sur les défauts du constructeur (E11b-1).
    final String effectiveTiles = tileUrlTemplate ?? this.tileUrlTemplate;
    final double effectiveZoom = defaultZoom ?? initialZoom;
    // Centre effectif : priorité au centre explicite, puis au centre du cercle
    // (si valide), enfin au repli neutre.
    final ZGeoPoint c = center ??
        (circle != null && circle.isValid ? circle.center : fallbackCenter);
    final LatLng initialCenter = LatLng(c.lat, c.lng);

    final List<LatLng> vertices = <LatLng>[
      if (shape != null)
        for (final ZGeoPoint v in shape.vertices) LatLng(v.lat, v.lng),
    ];

    // E11b-1 : cercle rendu via `CircleLayer`/`CircleMarker` (rayon en mètres)
    // uniquement si le cercle est valide (AD-10 : jamais un rayon ≤0/non fini).
    final bool hasCircle = circle != null && circle.isValid;

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: effectiveZoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null
            ? null
            : (TapPosition _, LatLng ll) =>
                onTap(ZGeoPoint(lat: ll.latitude, lng: ll.longitude)),
      ),
      children: <Widget>[
        TileLayer(
          urlTemplate: effectiveTiles,
          userAgentPackageName: userAgentPackageName,
        ),
        if (vertices.length >= 3)
          PolygonLayer(
            polygons: <Polygon>[
              Polygon(points: vertices),
            ],
          ),
        if (hasCircle)
          CircleLayer(
            circles: <CircleMarker>[
              CircleMarker(
                point: LatLng(circle.center.lat, circle.center.lng),
                radius: circle.radiusMeters,
                useRadiusInMeter: true,
                color: Theme.of(context).colorScheme.primary.withValues(
                      alpha: 0.2,
                    ),
                borderColor: Theme.of(context).colorScheme.primary,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        MarkerLayer(
          markers: <Marker>[
            if (center != null)
              Marker(
                point: initialCenter,
                width: 40,
                height: 40,
                child: const Icon(Icons.place),
              ),
            if (hasCircle && center == null)
              Marker(
                point: LatLng(circle.center.lat, circle.center.lng),
                width: 40,
                height: 40,
                child: const Icon(Icons.place),
              ),
            for (final LatLng v in vertices)
              Marker(
                point: v,
                width: 24,
                height: 24,
                child: const Icon(Icons.circle, size: 12),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    if (_disposed) return; // idempotent (contrat ZMapAdapter)
    _disposed = true;
    _controller.dispose();
  }
}
