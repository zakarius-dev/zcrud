/// `ZOsmMapAdapter` — implémentation OSM du port [ZMapAdapter] via
/// `flutter_map`.
///
/// **Confinement SDK (invariant AD-1)** : c'est le seul fichier de
/// `zcrud_geo` qui importe `flutter_map`/`latlong2`. Les types SDK (`LatLng`,
/// `MapController`, `FlutterMap`…) restent **internes** : l'API publique de
/// cette classe (`implements ZMapAdapter`) ne parle que de types neutres
/// (`ZGeoPoint`/`ZGeoShape`/`Widget`). Ce fichier n'est pas exporté par le
/// barrel principal `lib/zcrud_geo.dart` — il est atteint via l'entrée dédiée
/// `package:zcrud_geo/adapters/osm.dart` (voie d'import explicite).
///
/// **Invariant AD-12 : zéro clé/secret.** OSM ne requiert aucune clé API. Le
/// `urlTemplate` des tuiles est le point de terminaison public OSM standard,
/// **surchargeable** par l'application hôte via [tileUrlTemplate] (jamais un
/// endpoint privé en dur, jamais de `badCertificateCallback`).
library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/z_geo_circle.dart';
import '../../domain/z_geo_map_options.dart';
import '../../domain/z_geo_point.dart';
import '../../domain/z_geo_shape.dart';
import '../../domain/z_geo_shape_style.dart';
import '../../domain/z_geo_tile_reference.dart';
import '../z_map_adapter.dart';

/// Traduit un entier ARGB neutre (`0xAARRGGBB`) en `Color` SDK — **confiné** à
/// cet adaptateur (AD-1 : aucune couleur SDK ne fuit dans le domaine). `null` →
/// `null` (l'appelant retombe sur le thème injecté).
Color? _argb(int? argb) => argb == null ? null : Color(argb);

/// Adaptateur carte OSM (sans clé API). Possède un `MapController` natif
/// disposé via [dispose].
///
/// Opte pour les capacités [ZMapCameraCapable] (caméra pilotée via
/// `MapController.move`/`fitCamera`) et [ZMapGesturesCapable]. `flutter_map`
/// n'a **aucun marqueur draggable natif** : le drag est implémenté ici par
/// geste custom ([_ZOsmDraggableMarker]) — conversion écran↔coordonnées via
/// `MapCamera.of(context)` (`latLngToScreenOffset`/`screenOffsetToLatLng`),
/// position appliquée en **fin de drag** (contrat `*DragEnd`).
class ZOsmMapAdapter
    implements ZMapAdapter, ZMapCameraCapable, ZMapGesturesCapable {
  /// Construit l'adaptateur. [tileUrlTemplate] est surchargeable (défaut : OSM
  /// public) ; [userAgentPackageName] identifie l'app hôte auprès d'OSM.
  ZOsmMapAdapter({
    this.tileUrlTemplate = _defaultOsmTiles,
    this.userAgentPackageName = 'com.example.app',
    this.fallbackCenter = const ZGeoPoint(lat: 0, lng: 0),
    this.initialZoom = 13,
    this.tileUrlTemplates,
  });

  /// Point de terminaison public standard des tuiles OSM (aucun secret) —
  /// valeur de référence auditée (`ZGeoTileReference.osmStandard`).
  static const String _defaultOsmTiles = ZGeoTileReference.osmStandard;

  /// Gabarit d'URL de tuiles (surchargeable ; défaut OSM public — AD-12).
  /// S'applique au type `normal` (et à toute carte sans `mapOptions`).
  final String tileUrlTemplate;

  /// Gabarits de tuiles **par type de carte**, surchargeables au
  /// constructeur ; primés par le paramètre `tileUrlTemplates` de `buildMap`.
  /// `null`/type absent → défauts audités `ZGeoTileReference.defaults`.
  final Map<ZGeoMapType, String>? tileUrlTemplates;

  /// User-agent transmis au serveur de tuiles (politique d'usage OSM).
  final String userAgentPackageName;

  /// Centre par défaut si aucun point/sommet n'est fourni.
  final ZGeoPoint fallbackCenter;

  /// Zoom initial.
  final double initialZoom;

  final MapController _controller = MapController();
  bool _disposed = false;

  /// Fin de drag d'un sommet (`null` → sommets non draggables, rendu
  /// inchangé).
  @override
  ZGeoVertexDragEnd? onVertexDragEnd;

  /// Fin de déplacement de forme via le marqueur au centroïde (`null` →
  /// aucun marqueur de déplacement).
  @override
  ZGeoShapeDragEnd? onShapeDragEnd;

  /// Fin de drag de la poignée de rayon (`null` → aucune poignée).
  @override
  ZGeoRadiusDragEnd? onCircleRadiusDragEnd;

  /// Déplace la caméra. Carte non montée / adaptateur disposé / point
  /// invalide → no-op silencieux (défensif, invariant AD-10, jamais de
  /// throw).
  @override
  Future<void> moveCamera(ZGeoPoint center, {double? zoom}) async {
    if (_disposed || !center.isValid) return;
    try {
      final double effectiveZoom = zoom ?? _controller.camera.zoom;
      _controller.move(LatLng(center.lat, center.lng), effectiveZoom);
    } catch (_) {
      // Carte jamais montée : `camera`/`move` throw → no-op (AD-10).
    }
  }

  /// Cadre la caméra sur la boîte sud-ouest→nord-est. Mêmes garanties que
  /// [moveCamera].
  @override
  Future<void> fitBounds(ZGeoPoint southWest, ZGeoPoint northEast) async {
    if (_disposed || !southWest.isValid || !northEast.isValid) return;
    try {
      _controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(southWest.lat, southWest.lng),
            LatLng(northEast.lat, northEast.lng),
          ),
          padding: const EdgeInsets.all(24),
        ),
      );
    } catch (_) {
      // Carte jamais montée → no-op (AD-10).
    }
  }

  @override
  Widget buildMap(
    BuildContext context, {
    ZGeoPoint? center,
    ZGeoShape? shape,
    ZGeoCircle? circle,
    ValueChanged<ZGeoPoint>? onTap,
    bool interactive = true,
    String? tileUrlTemplate,
    Map<ZGeoMapType, String>? tileUrlTemplates,
    String? mapStyleJson, // ignoré (spécifique Google) — OSM n'a pas de style JSON
    double? defaultZoom,
    // G3/DP-7 : `mapOptions.mapType` est désormais HONORÉ en commutant le jeu
    // de tuiles (parité legacy `oma:53-110` : ESRI World Imagery pour
    // satellite/hybride, OpenTopoMap pour terrain). Les autres options
    // (trafic/bâtiments/indoor/boussole…) restent sans équivalent raster →
    // ignorées (contrat « honoré-si-supporté, ignore le reste »).
    ZGeoMapOptions? mapOptions,
    bool renderShapeAsPolyline = false,
    // G23 : bornes de zoom honorées via `MapOptions.minZoom/maxZoom`.
    double? minZoom,
    double? maxZoom,
    // G6 : couches de lecture multi-formes + sélection par tap marqueur.
    List<ZGeoMapOverlay>? overlays,
    ValueChanged<String>? onOverlayMarkerTap,
  }) {
    // Tuiles résolues par type de carte. Chaîne de priorité (paramètre >
    // config > référence) : `tileUrlTemplates[type]` (par-champ) >
    // constructeur `this.tileUrlTemplates[type]` > pour `normal` (ou sans
    // options) le gabarit [tileUrlTemplate] > défaut audité
    // `ZGeoTileReference.defaults[type]`.
    final ZGeoMapType mapType = mapOptions?.mapType ?? ZGeoMapType.normal;
    final String effectiveTiles = tileUrlTemplates?[mapType] ??
        this.tileUrlTemplates?[mapType] ??
        (mapType == ZGeoMapType.normal
            ? (tileUrlTemplate ?? this.tileUrlTemplate)
            : ZGeoTileReference.defaults[mapType]!);
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

    // DP-21/M13 : style de forme neutre honoré (couleurs ARGB → `Color` confiné
    // à ce fichier, AD-1) avec repli sur le thème injecté (aucune couleur
    // en dur). `visible == false` → la forme n'est pas rendue.
    final ZGeoShapeStyle? shapeStyle = shape?.style;
    final bool shapeVisible = shapeStyle?.visible ?? true;
    final Color themePrimary = Theme.of(context).colorScheme.primary;
    final Color shapeStroke =
        _argb(shapeStyle?.strokeColorArgb) ?? themePrimary;
    final Color shapeFill = _argb(shapeStyle?.fillColorArgb) ??
        themePrimary.withValues(alpha: 0.2);
    final double shapeStrokeWidth =
        (shapeStyle?.strokeWidth ?? 3).toDouble();

    // DP-21/M13 : trous intérieurs du polygone (`holePointsList`), honorés si
    // fournis et non triviaux (≥3 sommets par trou) ; sinon ignorés (AD-10).
    final List<List<LatLng>>? holePointsList = (shape?.holes == null)
        ? null
        : <List<LatLng>>[
            for (final List<ZGeoPoint> hole in shape!.holes!)
              if (hole.length >= 3)
                <LatLng>[
                  for (final ZGeoPoint v in hole) LatLng(v.lat, v.lng),
                ],
          ];

    // E11b-1 : cercle rendu via `CircleLayer`/`CircleMarker` (rayon en mètres)
    // uniquement si le cercle est valide (AD-10 : jamais un rayon ≤0/non fini).
    final bool hasCircle = circle != null && circle.isValid;

    // G6 : couches de lecture multi-formes (styles portés par les valeurs,
    // marqueur d'ancrage tappable par overlay). Valeur d'un type inconnu ou
    // invalide → ignorée sans erreur (AD-10).
    final List<Polygon> overlayPolygons = <Polygon>[];
    final List<Polyline> overlayPolylines = <Polyline>[];
    final List<CircleMarker> overlayCircles = <CircleMarker>[];
    final List<Marker> overlayMarkers = <Marker>[];
    if (overlays != null) {
      for (final ZGeoMapOverlay overlay in overlays) {
        final Object value = overlay.value;
        if (value is ZGeoShape && value.isNotEmpty) {
          final ZGeoShapeStyle? style = value.style;
          if (style?.visible == false) continue;
          final List<LatLng> pts = <LatLng>[
            for (final ZGeoPoint v in value.vertices) LatLng(v.lat, v.lng),
          ];
          final Color stroke = _argb(style?.strokeColorArgb) ?? themePrimary;
          final Color fill = _argb(style?.fillColorArgb) ??
              themePrimary.withValues(alpha: 0.2);
          final double width = (style?.strokeWidth ?? 3).toDouble();
          if (overlay.renderAsPolyline && pts.length >= 2) {
            overlayPolylines.add(
              Polyline(points: pts, color: stroke, strokeWidth: width),
            );
          } else if (pts.length >= 3) {
            overlayPolygons.add(
              Polygon(
                points: pts,
                holePointsList: value.holes == null
                    ? null
                    : <List<LatLng>>[
                        for (final List<ZGeoPoint> hole in value.holes!)
                          if (hole.length >= 3)
                            <LatLng>[
                              for (final ZGeoPoint v in hole)
                                LatLng(v.lat, v.lng),
                            ],
                      ],
                color: fill,
                borderColor: stroke,
                borderStrokeWidth: width,
              ),
            );
          }
          // Marqueur d'ancrage au CENTROÏDE (sélection par tap — parité
          // mesurée gfv:132-139 : la sélection legacy passe par le marqueur).
          double latSum = 0, lngSum = 0;
          for (final LatLng p in pts) {
            latSum += p.latitude;
            lngSum += p.longitude;
          }
          overlayMarkers.add(_styledMarker(
            context,
            LatLng(latSum / pts.length, lngSum / pts.length),
            style,
            overlayId: overlay.id,
            onTapId: onOverlayMarkerTap,
          ));
        } else if (value is ZGeoCircle && value.isValid) {
          final ZGeoShapeStyle? style = value.style;
          if (style?.visible == false) continue;
          overlayCircles.add(
            CircleMarker(
              point: LatLng(value.center.lat, value.center.lng),
              radius: value.radiusMeters,
              useRadiusInMeter: true,
              color: _argb(style?.fillColorArgb) ??
                  themePrimary.withValues(alpha: 0.2),
              borderColor: _argb(style?.strokeColorArgb) ?? themePrimary,
              borderStrokeWidth: (style?.strokeWidth ?? 2).toDouble(),
            ),
          );
          overlayMarkers.add(_styledMarker(
            context,
            LatLng(value.center.lat, value.center.lng),
            style,
            overlayId: overlay.id,
            onTapId: onOverlayMarkerTap,
          ));
        } else if (value is ZGeoPoint && value.isValid) {
          overlayMarkers.add(_styledMarker(
            context,
            LatLng(value.lat, value.lng),
            value.style,
            overlayId: overlay.id,
            onTapId: onOverlayMarkerTap,
          ));
        }
      }
    }

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: effectiveZoom,
        // G23 : bornes de zoom surchargeables par-champ (`null` → défaut SDK).
        minZoom: minZoom,
        maxZoom: maxZoom,
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
        // DP-21/M13 : polyligne (tracé OUVERT, ≥2 sommets) quand demandé —
        // aucun remplissage, aucun segment de fermeture.
        if (shapeVisible && renderShapeAsPolyline && vertices.length >= 2)
          PolylineLayer(
            polylines: <Polyline>[
              Polyline(
                points: vertices,
                color: shapeStroke,
                strokeWidth: shapeStrokeWidth,
              ),
            ],
          )
        // Sinon polygone FERMÉ (≥3 sommets) : style + trous honorés (DP-21).
        else if (shapeVisible && vertices.length >= 3)
          PolygonLayer(
            polygons: <Polygon>[
              Polygon(
                points: vertices,
                holePointsList: holePointsList,
                color: shapeFill,
                borderColor: shapeStroke,
                borderStrokeWidth: shapeStrokeWidth,
              ),
            ],
          ),
        // G9 : le cercle honore `circle.style` (fill/stroke/épaisseur/
        // visibilité) — chaîne style > thème injecté (le `colorScheme.primary`
        // n'est plus qu'un REPLI, jamais un écrasement du style porté).
        if (hasCircle && (circle.style?.visible ?? true))
          CircleLayer(
            circles: <CircleMarker>[
              CircleMarker(
                point: LatLng(circle.center.lat, circle.center.lng),
                radius: circle.radiusMeters,
                useRadiusInMeter: true,
                color: _argb(circle.style?.fillColorArgb) ??
                    themePrimary.withValues(alpha: 0.2),
                borderColor:
                    _argb(circle.style?.strokeColorArgb) ?? themePrimary,
                borderStrokeWidth:
                    (circle.style?.strokeWidth ?? 2).toDouble(),
              ),
            ],
          ),
        // G6 : couches de lecture multi-formes (rendues APRÈS la forme éditée).
        if (overlayPolygons.isNotEmpty)
          PolygonLayer(polygons: overlayPolygons),
        if (overlayPolylines.isNotEmpty)
          PolylineLayer(polylines: overlayPolylines),
        if (overlayCircles.isNotEmpty) CircleLayer(circles: overlayCircles),
        MarkerLayer(
          markers: <Marker>[
            ...overlayMarkers,
            // G9/G14/G17 : le marqueur central honore le style porté par la
            // valeur (point → `center.style` ; cercle → `circle.style`).
            if (center != null)
              _styledMarker(context, initialCenter, center.style),
            if (hasCircle && center == null)
              _styledMarker(
                context,
                LatLng(circle.center.lat, circle.center.lng),
                circle.style,
              ),
            // G13 : sommets draggables UNIQUEMENT quand un handler est posé
            // (`null` ⇒ rendu antérieur strictement inchangé — AD-4).
            for (int i = 0; i < vertices.length; i++)
              onVertexDragEnd == null
                  ? Marker(
                      point: vertices[i],
                      width: 24,
                      height: 24,
                      child: const Icon(Icons.circle, size: 12),
                    )
                  : Marker(
                      point: vertices[i],
                      width: 32,
                      height: 32,
                      child: _ZOsmDraggableMarker(
                        key: ValueKey<String>('z-geo-osm-vertex-$i'),
                        point: vertices[i],
                        onDragEnd: _vertexDragEndFor(i),
                        child: const Icon(Icons.circle, size: 12),
                      ),
                    ),
            // G13 : marqueur de déplacement au CENTROÏDE (parité legacy
            // `gff:647-664`, `move_handle`) — rendu seulement quand le mode
            // « Déplacer » est actif (handler posé) et qu'il y a des sommets.
            if (onShapeDragEnd != null && vertices.isNotEmpty)
              Marker(
                point: _centroid(vertices),
                width: 48,
                height: 48,
                child: _ZOsmDraggableMarker(
                  key: const ValueKey<String>('z-geo-osm-move-handle'),
                  point: _centroid(vertices),
                  onDragEnd: _shapeDragEndFrom(_centroid(vertices)),
                  child: const Icon(Icons.open_with),
                ),
              ),
            // G11 : poignée de rayon draggable sur le périmètre EST du cercle
            // (fin de drag → nouveau rayon = distance haversine centre→poignée).
            if (onCircleRadiusDragEnd != null && hasCircle)
              if (_circleEastEdge(circle) case final LatLng edge)
                Marker(
                  point: edge,
                  width: 48,
                  height: 48,
                  child: _ZOsmDraggableMarker(
                    key: const ValueKey<String>('z-geo-osm-radius-handle'),
                    point: edge,
                    onDragEnd: _radiusDragEndFor(circle),
                    child: const Icon(Icons.drag_indicator),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  /// Centroïde (moyenne arithmétique) des sommets — parité legacy `gff:648-655`.
  static LatLng _centroid(List<LatLng> vertices) {
    double lat = 0, lng = 0;
    for (final LatLng v in vertices) {
      lat += v.latitude;
      lng += v.longitude;
    }
    return LatLng(lat / vertices.length, lng / vertices.length);
  }

  /// Point du périmètre du cercle plein EST du centre (poignée de rayon G11).
  /// `null` si la conversion dégénère (proximité des pôles — AD-10).
  static LatLng? _circleEastEdge(ZGeoCircle circle) {
    final double latRad = circle.center.lat * math.pi / 180;
    final double cosLat = math.cos(latRad);
    if (cosLat.abs() < 1e-9) return null;
    final double dLng = (circle.radiusMeters /
            (ZGeoPoint.earthRadiusMeters * cosLat)) *
        (180 / math.pi);
    final double lng = circle.center.lng + dLng;
    if (!lng.isFinite || lng < ZGeoPoint.minLng || lng > ZGeoPoint.maxLng) {
      return null;
    }
    return LatLng(circle.center.lat, lng);
  }

  /// Fin de drag d'un sommet → handler neutre (coordonnée validée — AD-10).
  ValueChanged<LatLng> _vertexDragEndFor(int index) => (LatLng ll) {
        final ZGeoPoint p = ZGeoPoint(lat: ll.latitude, lng: ll.longitude);
        if (p.isValid) onVertexDragEnd?.call(index, p);
      };

  /// Fin de drag du marqueur centroïde → delta (parité `gff:1615-1620`).
  ValueChanged<LatLng> _shapeDragEndFrom(LatLng centroid) => (LatLng ll) {
        onShapeDragEnd?.call(
          ll.latitude - centroid.latitude,
          ll.longitude - centroid.longitude,
        );
      };

  /// Fin de drag de la poignée de rayon → nouveau rayon haversine (G11).
  ValueChanged<LatLng> _radiusDragEndFor(ZGeoCircle circle) => (LatLng ll) {
        final double radius = circle.center
            .distanceMetersTo(ZGeoPoint(lat: ll.latitude, lng: ll.longitude));
        if (radius.isFinite && radius > 0) {
          onCircleRadiusDragEnd?.call(radius);
        }
      };

  /// Marqueur central **stylé** (G9/G14/G17). `style == null` → marqueur
  /// d'origine strictement inchangé (`Icon(Icons.place)` 40dp — AD-4).
  ///
  /// Parité legacy `gma:185-233` : quand `infoWindowTitle` est renseigné, le
  /// legacy REMPLACE le marqueur par une pastille de texte (fond blanc bordé
  /// noir, rayon 16). Ici la pastille reprend cette géométrie mais ses couleurs
  /// viennent du **thème injecté** (`surface`/`onSurface`), jamais de
  /// littéraux. `iconAsset` → image d'asset de l'app hôte (repli défensif sur
  /// l'icône par défaut si l'asset manque — AD-10) ; `iconColorArgb` → teinte ;
  /// `iconSize` → taille ; `iconRotation` → rotation en degrés (G17).
  /// `iconAnchor` n'a pas d'équivalent direct `flutter_map` ici → ignoré
  /// (contrat honoré-si-supporté, écart documenté).
  ///
  /// **G6** : [overlayId] + [onTapId] non-`null` → le contenu du marqueur est
  /// enveloppé d'un `GestureDetector` remontant l'[overlayId] au tap
  /// (sélection de `ZGeoMapView`, parité mesurée `gfv:132-139`).
  Marker _styledMarker(
    BuildContext context,
    LatLng point,
    ZGeoShapeStyle? style, {
    String? overlayId,
    ValueChanged<String>? onTapId,
  }) {
    Widget tappable(Widget child) =>
        (overlayId == null || onTapId == null)
            ? child
            : GestureDetector(
                key: ValueKey<String>('z-geo-osm-overlay-$overlayId'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onTapId(overlayId),
                child: child,
              );
    if (style == null || (style.visible == false)) {
      // Rendu d'origine (style absent) ; `visible: false` → marqueur transparent
      // (une forme invisible ne peint rien — G9).
      return Marker(
        point: point,
        width: 40,
        height: 40,
        child: style == null
            ? tappable(const Icon(Icons.place))
            : const SizedBox.shrink(),
      );
    }
    final String? title = style.infoWindowTitle;
    if (title != null && title.isNotEmpty) {
      // G14 : pastille de libellé (parité géométrique gma:208-218, couleurs
      // par rôles de thème).
      final ColorScheme scheme = Theme.of(context).colorScheme;
      return Marker(
        point: point,
        width: 140,
        height: 48,
        child: tappable(Center(
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.onSurface, width: 2),
            ),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
          ),
        )),
      );
    }
    final double size = style.iconSize ?? 40;
    final Color? tint = _argb(style.iconColorArgb);
    Widget icon = style.iconAsset != null
        ? Image.asset(
            style.iconAsset!,
            width: size,
            height: size,
            color: tint,
            // AD-10 : asset absent/corrompu → repli icône par défaut, jamais
            // d'exception au rendu.
            errorBuilder: (BuildContext _, Object _, StackTrace? _) =>
                Icon(Icons.place, size: size, color: tint),
          )
        : Icon(Icons.place, size: size, color: tint);
    if (style.iconRotation != 0.0) {
      icon = Transform.rotate(
        angle: style.iconRotation * (math.pi / 180),
        child: icon,
      );
    }
    return Marker(
      point: point,
      width: size,
      height: size,
      child: tappable(icon),
    );
  }

  @override
  void dispose() {
    if (_disposed) return; // idempotent (contrat ZMapAdapter)
    _disposed = true;
    _controller.dispose();
  }
}

/// Marqueur **draggable custom** pour `flutter_map` (G11/G13) — le SDK n'offre
/// aucun marqueur draggable natif. Pendant le pan, le child est translaté
/// visuellement ([Transform.translate]) ; en **fin de drag**, la position
/// écran d'origine du marqueur + le delta cumulé sont reconvertis en
/// coordonnées via `MapCamera.of(context)` et remontés par [onDragEnd]
/// (contrat `*DragEnd` : une seule écriture, en fin de geste). Conversion qui
/// échoue (carte démontée en plein geste) → drag abandonné sans throw (AD-10).
class _ZOsmDraggableMarker extends StatefulWidget {
  const _ZOsmDraggableMarker({
    required this.point,
    required this.onDragEnd,
    required this.child,
    super.key,
  });

  /// Position carte du marqueur (sert d'origine à la conversion écran).
  final LatLng point;

  /// Fin de drag : nouvelle position carte.
  final ValueChanged<LatLng> onDragEnd;

  /// Contenu visuel du marqueur.
  final Widget child;

  @override
  State<_ZOsmDraggableMarker> createState() => _ZOsmDraggableMarkerState();
}

class _ZOsmDraggableMarkerState extends State<_ZOsmDraggableMarker> {
  /// Delta écran cumulé du geste en cours (retour à zéro en fin de drag).
  Offset _dragDelta = Offset.zero;

  void _endDrag() {
    final Offset delta = _dragDelta;
    setState(() => _dragDelta = Offset.zero);
    if (delta == Offset.zero) return;
    try {
      final MapCamera camera = MapCamera.of(context);
      final Offset origin = camera.latLngToScreenOffset(widget.point);
      widget.onDragEnd(camera.screenOffsetToLatLng(origin + delta));
    } catch (_) {
      // Caméra indisponible (démontage en plein geste) → abandon (AD-10).
    }
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        // Recognizer « impatient » (victoire d'arène immédiate au pointer-down) :
        // la surface `FlutterMap` enrôle ses recognizers dans une TEAM avec
        // captain — un `GestureDetector.onPan*` enfant PERD systématiquement
        // l'arène (mesuré : 0 événement reçu). Même parti que les plugins de
        // drag-marker flutter_map.
        gestures: <Type, GestureRecognizerFactory>{
          _ZOsmEagerPanRecognizer: GestureRecognizerFactoryWithHandlers<
              _ZOsmEagerPanRecognizer>(
            _ZOsmEagerPanRecognizer.new,
            (_ZOsmEagerPanRecognizer r) {
              r.onStart = (DragStartDetails _) {
                setState(() => _dragDelta = Offset.zero);
              };
              r.onUpdate = (DragUpdateDetails d) {
                setState(() => _dragDelta += d.delta);
              };
              r.onEnd = (DragEndDetails _) => _endDrag();
              r.onCancel = _endDrag;
            },
          ),
        },
        child: Transform.translate(offset: _dragDelta, child: widget.child),
      );
}

/// [PanGestureRecognizer] qui **gagne l'arène dès le pointer-down** : sans
/// cela, la team (captain) de la surface `FlutterMap` remporte tout geste de
/// pan et la poignée ne reçoit jamais le drag (G11/G13).
class _ZOsmEagerPanRecognizer extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
