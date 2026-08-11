import 'package:flutter/material.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

/// Fake [ZMapAdapter] pour les tests widget — prouve le CONTRAT (rendu/tap/
/// dispose) SANS aucun SDK carte réel (cœur de l'isolation AD-1). Rend une
/// surface tappable identifiée par la clé `fake-map` ; un tap remonte
/// [tapPoint] via `onTap`. Enregistre `disposed`, le nombre de `buildMap` et les
/// derniers paramètres neutres reçus.
class FakeMapAdapter implements ZMapAdapter {
  FakeMapAdapter({this.tapPoint = const ZGeoPoint(lat: 12.5, lng: 34.5)});

  /// Point neutre remonté au tap.
  final ZGeoPoint tapPoint;

  /// Surcharge **mutable** du point de tap (G11 : simuler deux taps à des
  /// points différents). `null` → [tapPoint] (comportement historique).
  ZGeoPoint? tapOverride;

  /// `true` après un appel à [dispose].
  bool disposed = false;

  /// Nombre d'appels à [buildMap].
  int buildCount = 0;

  /// Derniers paramètres neutres reçus (preuve : aucun type SDK).
  ZGeoPoint? lastCenter;
  ZGeoShape? lastShape;
  ZGeoCircle? lastCircle;
  bool? lastInteractive;
  bool sawOnTap = false;

  /// Dernières surcharges par-champ reçues (preuve du plombage config→buildMap).
  String? lastTileUrlTemplate;
  Map<ZGeoMapType, String>? lastTileUrlTemplates;
  String? lastMapStyleJson;
  double? lastDefaultZoom;

  /// Dernières options de carte neutres reçues (DP-7 : preuve du plombage
  /// barre d'outils → `buildMap`). `null` quand aucune barre d'outils.
  ZGeoMapOptions? lastMapOptions;

  /// Dernier signal « rendre la forme en tracé ouvert » reçu (DP-21/M13).
  bool? lastRenderShapeAsPolyline;

  /// G23 : dernières bornes de zoom reçues.
  double? lastMinZoom;
  double? lastMaxZoom;

  /// G6 : derniers overlays reçus + dernier callback de tap marqueur (les
  /// tests l'invoquent directement pour simuler un tap d'ancrage).
  List<ZGeoMapOverlay>? lastOverlays;
  ValueChanged<String>? lastOnOverlayMarkerTap;

  /// Clé de la surface carte fake.
  static const Key mapKey = Key('fake-map');

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
    String? mapStyleJson,
    double? defaultZoom,
    ZGeoMapOptions? mapOptions,
    bool renderShapeAsPolyline = false,
    double? minZoom,
    double? maxZoom,
    List<ZGeoMapOverlay>? overlays,
    ValueChanged<String>? onOverlayMarkerTap,
  }) {
    buildCount++;
    lastMinZoom = minZoom;
    lastMaxZoom = maxZoom;
    lastOverlays = overlays;
    lastOnOverlayMarkerTap = onOverlayMarkerTap;
    lastCenter = center;
    lastShape = shape;
    lastCircle = circle;
    lastInteractive = interactive;
    lastTileUrlTemplate = tileUrlTemplate;
    lastTileUrlTemplates = tileUrlTemplates;
    lastMapStyleJson = mapStyleJson;
    lastDefaultZoom = defaultZoom;
    lastMapOptions = mapOptions;
    lastRenderShapeAsPolyline = renderShapeAsPolyline;
    sawOnTap = onTap != null;
    return GestureDetector(
      key: mapKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap(tapOverride ?? tapPoint),
      child: const SizedBox(width: double.infinity, height: 200),
    );
  }

  @override
  void dispose() => disposed = true;
}

/// Fake **capacitaire** (G7/G11/G13) : même surface que [FakeMapAdapter] MAIS
/// opte pour [ZMapCameraCapable] + [ZMapGesturesCapable]. Enregistre les appels
/// caméra et expose les handlers de gestes posés par le champ (les tests les
/// invoquent directement pour simuler une fin de drag adaptateur, sans SDK).
///
/// NB : [FakeMapAdapter] (ci-dessus) reste volontairement SANS capacités — il
/// tient lieu d'implémenteur externe minimal du port pur : s'il compile, un
/// adaptateur externe existant compile (AD-4, contrainte n°1), et le champ doit
/// dégrader en no-op (honoré-si-supporté) face à lui.
class FakeCameraGestureMapAdapter extends FakeMapAdapter
    implements ZMapCameraCapable, ZMapGesturesCapable {
  FakeCameraGestureMapAdapter({super.tapPoint});

  /// Appels `moveCamera` reçus (point, zoom).
  final List<(ZGeoPoint, double?)> movedCameras = <(ZGeoPoint, double?)>[];

  /// Dernier `fitBounds` reçu (SW, NE) — `null` si jamais appelé.
  (ZGeoPoint, ZGeoPoint)? lastFitBounds;

  @override
  ZGeoVertexDragEnd? onVertexDragEnd;

  @override
  ZGeoShapeDragEnd? onShapeDragEnd;

  @override
  ZGeoRadiusDragEnd? onCircleRadiusDragEnd;

  @override
  Future<void> moveCamera(ZGeoPoint center, {double? zoom}) async {
    movedCameras.add((center, zoom));
  }

  @override
  Future<void> fitBounds(ZGeoPoint southWest, ZGeoPoint northEast) async {
    lastFitBounds = (southWest, northEast);
  }
}
