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
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/z_geo_circle.dart';
import '../../domain/z_geo_map_options.dart';
import '../../domain/z_geo_point.dart';
import '../../domain/z_geo_shape.dart';
import '../../domain/z_geo_shape_style.dart';
import '../z_map_adapter.dart';

/// Traduit un entier ARGB neutre (`0xAARRGGBB`) en `Color` SDK — **confiné** à
/// cet adaptateur (AD-1 : aucune couleur SDK ne fuit dans le domaine). `null` →
/// `null` (l'appelant retombe sur le thème injecté, FR-26).
Color? _argb(int? argb) => argb == null ? null : Color(argb);

/// Adaptateur carte Google Maps (clé API = config plateforme, jamais ici — AD-12).
/// Possède un `GoogleMapController` natif disposé via [dispose] (learning E5).
///
/// **G7/G11/G13** : opte pour [ZMapCameraCapable] (via `GoogleMapController.
/// animateCamera`) et [ZMapGesturesCapable] (marqueurs **draggables natifs** du
/// SDK : `Marker(draggable: true, onDragEnd:)` — même mécanique que le legacy
/// `gma`). Handler `null` ⇒ rendu strictement inchangé (AD-4).
class ZGoogleMapAdapter
    implements ZMapAdapter, ZMapCameraCapable, ZMapGesturesCapable {
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

  /// G13 — fin de drag d'un sommet (`null` → aucun marqueur de sommet rendu,
  /// comportement antérieur strict : cet adaptateur ne rendait PAS les sommets).
  @override
  ZGeoVertexDragEnd? onVertexDragEnd;

  /// G13 — fin de déplacement de forme via le marqueur au centroïde.
  @override
  ZGeoShapeDragEnd? onShapeDragEnd;

  /// G11 — fin de drag de la poignée de rayon du cercle.
  @override
  ZGeoRadiusDragEnd? onCircleRadiusDragEnd;

  /// G7 — déplace la caméra (parité `UnifiedMapController.moveCamera`).
  /// Contrôleur natif pas encore créé (carte jamais montée) / disposé / point
  /// invalide → **no-op silencieux** (AD-10 : jamais de throw, jamais un await
  /// suspendu sur un `Completer` qui ne complètera pas).
  @override
  Future<void> moveCamera(ZGeoPoint center, {double? zoom}) async {
    if (_disposed || !center.isValid || !_controllerCompleter.isCompleted) {
      return;
    }
    try {
      final GoogleMapController controller = await _controllerCompleter.future;
      final LatLng target = LatLng(center.lat, center.lng);
      await controller.animateCamera(
        zoom == null
            ? CameraUpdate.newLatLng(target)
            : CameraUpdate.newLatLngZoom(target, zoom),
      );
    } catch (_) {
      // Plateforme indisponible (headless/démontage) → no-op (AD-10).
    }
  }

  /// G7 — cadre la caméra sur la boîte SW→NE. Mêmes garanties que [moveCamera].
  @override
  Future<void> fitBounds(ZGeoPoint southWest, ZGeoPoint northEast) async {
    if (_disposed ||
        !southWest.isValid ||
        !northEast.isValid ||
        !_controllerCompleter.isCompleted) {
      return;
    }
    try {
      final GoogleMapController controller = await _controllerCompleter.future;
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(southWest.lat, southWest.lng),
            northeast: LatLng(northEast.lat, northEast.lng),
          ),
          24,
        ),
      );
    } catch (_) {
      // Plateforme indisponible → no-op (AD-10).
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
    String? tileUrlTemplate, // ignoré (spécifique OSM) — Google n'a pas de tuiles URL
    // G3 : ignoré aussi — Google rend satellite/hybride/terrain NATIVEMENT via
    // `mapOptions.mapType` (contrat honoré-si-supporté).
    Map<ZGeoMapType, String>? tileUrlTemplates,
    String? mapStyleJson,
    double? defaultZoom,
    ZGeoMapOptions? mapOptions,
    bool renderShapeAsPolyline = false,
    // G23 : bornes de zoom honorées via `minMaxZoomPreference`.
    double? minZoom,
    double? maxZoom,
    // G6 : couches de lecture multi-formes + sélection par tap marqueur.
    List<ZGeoMapOverlay>? overlays,
    ValueChanged<String>? onOverlayMarkerTap,
  }) {
    // Surcharges par-champ : priment sur les défauts du constructeur (E11b-1).
    final String? effectiveStyle = mapStyleJson ?? this.mapStyleJson;
    final double effectiveZoom = defaultZoom ?? initialZoom;
    // Centre effectif : centre explicite, sinon centre du cercle (si valide),
    // sinon repli neutre. Aucun défaut « national » en dur (AD-12).
    final ZGeoPoint c = center ??
        (circle != null && circle.isValid ? circle.center : fallbackCenter);

    // G9/G14/G17 : le marqueur central honore le style porté par la valeur
    // (point → `center.style` ; cercle → `circle.style`). `style == null` →
    // marqueur d'origine strictement inchangé (AD-4).
    final Set<Marker> markers = <Marker>{
      if (center != null)
        _styledMarker(LatLng(center.lat, center.lng), center.style)
      else if (circle != null && circle.isValid)
        _styledMarker(
          LatLng(circle.center.lat, circle.center.lng),
          circle.style,
        ),
    };

    // DP-21/M13 : style de forme neutre honoré (couleurs ARGB → `Color` confiné
    // à ce fichier, AD-1). Repli sur les défauts SDK d'origine quand `style` est
    // `null` → rétro-compat E11b-1 stricte (mêmes valeurs qu'auparavant).
    const Color sdkDefault = Color(0xFF000000); // = Colors.black (défaut SDK)
    final ZGeoShapeStyle? shapeStyle = shape?.style;
    final Color fillColor = _argb(shapeStyle?.fillColorArgb) ?? sdkDefault;
    final Color strokeColor = _argb(shapeStyle?.strokeColorArgb) ?? sdkDefault;
    final int strokeWidth = shapeStyle?.strokeWidth ?? 10; // défaut SDK = 10
    final bool geodesic = shapeStyle?.geodesic ?? false;
    final bool visible = shapeStyle?.visible ?? true;
    final int zIndex = shapeStyle?.zIndex ?? 0;
    final bool consumeTapEvents = shapeStyle?.consumeTapEvents ?? false;

    final List<LatLng> shapePoints = <LatLng>[
      if (shape != null)
        for (final ZGeoPoint v in shape.vertices) LatLng(v.lat, v.lng),
    ];

    // DP-21/M13 : trous intérieurs du polygone (≥3 sommets par trou honoré).
    final List<List<LatLng>> holes = <List<LatLng>>[
      if (shape?.holes != null)
        for (final List<ZGeoPoint> hole in shape!.holes!)
          if (hole.length >= 3)
            <LatLng>[for (final ZGeoPoint v in hole) LatLng(v.lat, v.lng)],
    ];

    // G13 : sommets DRAGGABLES natifs quand un handler est posé (`null` ⇒
    // aucun marqueur de sommet — comportement antérieur strict, AD-4).
    if (onVertexDragEnd != null) {
      for (int i = 0; i < shapePoints.length; i++) {
        final int index = i;
        markers.add(
          Marker(
            markerId: MarkerId('z-geo-vertex-$i'),
            position: shapePoints[i],
            draggable: true,
            zIndexInt: 2,
            onDragEnd: (LatLng ll) {
              final ZGeoPoint p = ZGeoPoint(lat: ll.latitude, lng: ll.longitude);
              if (p.isValid) onVertexDragEnd?.call(index, p);
            },
          ),
        );
      }
    }
    // G13 : marqueur de déplacement au CENTROÏDE (parité legacy `gff:647-664`,
    // `move_handle`) — fin de drag → delta appliqué par le champ.
    if (onShapeDragEnd != null && shapePoints.isNotEmpty) {
      final LatLng centroid = _centroid(shapePoints);
      markers.add(
        Marker(
          markerId: const MarkerId('z-geo-move-handle'),
          position: centroid,
          draggable: true,
          zIndexInt: 3,
          onDragEnd: (LatLng ll) => onShapeDragEnd?.call(
            ll.latitude - centroid.latitude,
            ll.longitude - centroid.longitude,
          ),
        ),
      );
    }
    // G11 : poignée de rayon draggable sur le périmètre EST du cercle — fin de
    // drag → nouveau rayon = distance haversine centre→poignée.
    if (onCircleRadiusDragEnd != null && circle != null && circle.isValid) {
      final LatLng? edge = _circleEastEdge(circle);
      if (edge != null) {
        final ZGeoPoint circleCenter = circle.center;
        markers.add(
          Marker(
            markerId: const MarkerId('z-geo-radius-handle'),
            position: edge,
            draggable: true,
            zIndexInt: 3,
            onDragEnd: (LatLng ll) {
              final double radius = circleCenter
                  .distanceMetersTo(ZGeoPoint(lat: ll.latitude, lng: ll.longitude));
              if (radius.isFinite && radius > 0) {
                onCircleRadiusDragEnd?.call(radius);
              }
            },
          ),
        );
      }
    }

    // Polygone FERMÉ (≥3 sommets) sauf si `renderShapeAsPolyline` (DP-21).
    final Set<Polygon> polygons = <Polygon>{
      if (shape != null && !renderShapeAsPolyline && shapePoints.length >= 3)
        Polygon(
          polygonId: const PolygonId('z-geo-area'),
          points: shapePoints,
          holes: holes,
          fillColor: fillColor,
          strokeColor: strokeColor,
          strokeWidth: strokeWidth,
          geodesic: geodesic,
          visible: visible,
          zIndex: zIndex,
          consumeTapEvents: consumeTapEvents,
        ),
    };

    // DP-21/M13 : polyligne (tracé OUVERT, ≥2 sommets) quand demandé — pas de
    // remplissage, pas de segment de fermeture (honoré-si-supporté).
    final Set<Polyline> polylines = <Polyline>{
      if (shape != null && renderShapeAsPolyline && shapePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('z-geo-polyline'),
          points: shapePoints,
          color: strokeColor,
          width: strokeWidth,
          geodesic: geodesic,
          visible: visible,
          zIndex: zIndex,
          consumeTapEvents: consumeTapEvents,
        ),
    };

    // G9 : le cercle honore `circle.style` — chaque propriété absente retombe
    // EXACTEMENT sur le défaut SDK antérieur (style `null` ⇒ `Circle` identique
    // à E11b-1, AD-4). NB : les défauts SDK (noir/transparent) restent ceux du
    // SDK ; la voie thémée passe par un `style` posé sur la valeur.
    final Set<Circle> circles = <Circle>{
      if (circle != null && circle.isValid)
        Circle(
          circleId: const CircleId('z-geo-circle'),
          center: LatLng(circle.center.lat, circle.center.lng),
          radius: circle.radiusMeters,
          fillColor:
              _argb(circle.style?.fillColorArgb) ?? const Color(0x00000000),
          strokeColor:
              _argb(circle.style?.strokeColorArgb) ?? const Color(0xFF000000),
          strokeWidth: circle.style?.strokeWidth ?? 10,
          visible: circle.style?.visible ?? true,
          zIndex: circle.style?.zIndex ?? 0,
          consumeTapEvents: circle.style?.consumeTapEvents ?? false,
        ),
    };

    // G6 : couches de lecture multi-formes (styles portés par les valeurs,
    // marqueur d'ancrage tappable). Valeur inconnue/invalide → ignorée (AD-10).
    if (overlays != null) {
      for (int i = 0; i < overlays.length; i++) {
        final ZGeoMapOverlay overlay = overlays[i];
        final Object value = overlay.value;
        if (value is ZGeoShape && value.isNotEmpty) {
          final ZGeoShapeStyle? style = value.style;
          final List<LatLng> pts = <LatLng>[
            for (final ZGeoPoint v in value.vertices) LatLng(v.lat, v.lng),
          ];
          if (overlay.renderAsPolyline && pts.length >= 2) {
            polylines.add(Polyline(
              polylineId: PolylineId('z-geo-overlay-line-${overlay.id}'),
              points: pts,
              color: _argb(style?.strokeColorArgb) ?? sdkDefault,
              width: style?.strokeWidth ?? 10,
              visible: style?.visible ?? true,
            ));
          } else if (pts.length >= 3) {
            polygons.add(Polygon(
              polygonId: PolygonId('z-geo-overlay-area-${overlay.id}'),
              points: pts,
              holes: <List<LatLng>>[
                if (value.holes != null)
                  for (final List<ZGeoPoint> hole in value.holes!)
                    if (hole.length >= 3)
                      <LatLng>[
                        for (final ZGeoPoint v in hole) LatLng(v.lat, v.lng),
                      ],
              ],
              fillColor: _argb(style?.fillColorArgb) ?? sdkDefault,
              strokeColor: _argb(style?.strokeColorArgb) ?? sdkDefault,
              strokeWidth: style?.strokeWidth ?? 10,
              visible: style?.visible ?? true,
            ));
          }
          double latSum = 0, lngSum = 0;
          for (final LatLng p in pts) {
            latSum += p.latitude;
            lngSum += p.longitude;
          }
          markers.add(_overlayMarker(
            overlay.id,
            LatLng(latSum / pts.length, lngSum / pts.length),
            style,
            onOverlayMarkerTap,
          ));
        } else if (value is ZGeoCircle && value.isValid) {
          circles.add(Circle(
            circleId: CircleId('z-geo-overlay-circle-${overlay.id}'),
            center: LatLng(value.center.lat, value.center.lng),
            radius: value.radiusMeters,
            fillColor:
                _argb(value.style?.fillColorArgb) ?? const Color(0x00000000),
            strokeColor:
                _argb(value.style?.strokeColorArgb) ?? const Color(0xFF000000),
            strokeWidth: value.style?.strokeWidth ?? 10,
            visible: value.style?.visible ?? true,
          ));
          markers.add(_overlayMarker(
            overlay.id,
            LatLng(value.center.lat, value.center.lng),
            value.style,
            onOverlayMarkerTap,
          ));
        } else if (value is ZGeoPoint && value.isValid) {
          markers.add(_overlayMarker(
            overlay.id,
            LatLng(value.lat, value.lng),
            value.style,
            onOverlayMarkerTap,
          ));
        }
      }
    }

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
      // G21 : point bleu natif + bouton — opt-in (`false` par défaut : la
      // permission de localisation appartient à l'app hôte, cf. ZGeoMapOptions).
      myLocationEnabled: mapOptions?.myLocationEnabled ?? false,
      myLocationButtonEnabled: mapOptions?.myLocationButtonEnabled ?? true,
      // G23 : bornes de zoom surchargeables (`null`/`null` → non bornées,
      // comportement antérieur strict).
      minMaxZoomPreference: (minZoom == null && maxZoom == null)
          ? MinMaxZoomPreference.unbounded
          : MinMaxZoomPreference(minZoom, maxZoom),
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
      polylines: polylines,
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

  /// Marqueur central **stylé** (G9/G14/G17). `style == null` → `Marker`
  /// d'origine strictement inchangé (AD-4).
  ///
  /// **Écart documenté vs legacy (`gma:185-233`)** : le legacy peint un bitmap
  /// texte (pastille) de façon **asynchrone** (`PictureRecorder` → `await
  /// toImage`) — impossible dans ce `buildMap` synchrone et sans état. Ici,
  /// `infoWindowTitle`/`infoWindowSnippet` passent par l'**`InfoWindow` natif**
  /// (libellé affiché au tap, pas en continu) ; `iconColorArgb` est traduit en
  /// **teinte de marqueur** (`defaultMarkerWithHue`, la teinte HSV la plus
  /// proche — pas un tint exact) ; `iconRotation`/`iconAnchor` sont honorés
  /// nativement (G17). `iconAsset` exigerait un chargement d'asset asynchrone →
  /// **ignoré** par cet adaptateur (contrat honoré-si-supporté ; l'adaptateur
  /// OSM, lui, le rend).
  Marker _styledMarker(LatLng position, ZGeoShapeStyle? style) {
    if (style == null) {
      return Marker(markerId: const MarkerId('z-geo-center'), position: position);
    }
    final int? tint = style.iconColorArgb;
    return Marker(
      markerId: const MarkerId('z-geo-center'),
      position: position,
      visible: style.visible,
      icon: tint == null
          ? BitmapDescriptor.defaultMarker
          : BitmapDescriptor.defaultMarkerWithHue(_hueOf(tint)),
      infoWindow: (style.infoWindowTitle == null &&
              style.infoWindowSnippet == null)
          ? InfoWindow.noText
          : InfoWindow(
              title: style.infoWindowTitle,
              snippet: style.infoWindowSnippet,
            ),
      rotation: style.iconRotation,
      anchor: style.iconAnchor == null
          // Défaut SDK : bas-centre du pictogramme.
          ? const Offset(0.5, 1.0)
          // Parité de lecture legacy : `GeoPoint(lat→dy, lng→dx)` normalisé.
          : Offset(
              style.iconAnchor!.lng.clamp(0.0, 1.0),
              style.iconAnchor!.lat.clamp(0.0, 1.0),
            ),
      zIndexInt: style.zIndex,
    );
  }

  /// G6 — marqueur d'ancrage d'un overlay : même chaîne de style que
  /// [_styledMarker] (teinte/InfoWindow), MarkerId stable dérivé de l'[id],
  /// tap → [onTapId] (sélection `ZGeoMapView`, parité mesurée `gfv:132-139`).
  Marker _overlayMarker(
    String id,
    LatLng position,
    ZGeoShapeStyle? style,
    ValueChanged<String>? onTapId,
  ) {
    final int? tint = style?.iconColorArgb;
    return Marker(
      markerId: MarkerId('z-geo-overlay-$id'),
      position: position,
      visible: style?.visible ?? true,
      icon: tint == null
          ? BitmapDescriptor.defaultMarker
          : BitmapDescriptor.defaultMarkerWithHue(_hueOf(tint)),
      infoWindow: (style?.infoWindowTitle == null &&
              style?.infoWindowSnippet == null)
          ? InfoWindow.noText
          : InfoWindow(
              title: style?.infoWindowTitle,
              snippet: style?.infoWindowSnippet,
            ),
      onTap: onTapId == null ? null : () => onTapId(id),
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

  /// Teinte HSV `[0,360)` la plus proche d'une couleur ARGB (confinée ici —
  /// `defaultMarkerWithHue` ne prend qu'un hue, pas une couleur exacte).
  static double _hueOf(int argb) {
    final Color color = Color(argb);
    return HSVColor.fromColor(color).hue;
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
