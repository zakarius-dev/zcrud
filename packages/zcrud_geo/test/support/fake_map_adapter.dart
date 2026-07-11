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
  String? lastMapStyleJson;
  double? lastDefaultZoom;

  /// Dernières options de carte neutres reçues (DP-7 : preuve du plombage
  /// barre d'outils → `buildMap`). `null` quand aucune barre d'outils.
  ZGeoMapOptions? lastMapOptions;

  /// Dernier signal « rendre la forme en tracé ouvert » reçu (DP-21/M13).
  bool? lastRenderShapeAsPolyline;

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
    String? mapStyleJson,
    double? defaultZoom,
    ZGeoMapOptions? mapOptions,
    bool renderShapeAsPolyline = false,
  }) {
    buildCount++;
    lastCenter = center;
    lastShape = shape;
    lastCircle = circle;
    lastInteractive = interactive;
    lastTileUrlTemplate = tileUrlTemplate;
    lastMapStyleJson = mapStyleJson;
    lastDefaultZoom = defaultZoom;
    lastMapOptions = mapOptions;
    lastRenderShapeAsPolyline = renderShapeAsPolyline;
    sawOnTap = onTap != null;
    return GestureDetector(
      key: mapKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null ? null : () => onTap(tapPoint),
      child: const SizedBox(width: double.infinity, height: 200),
    );
  }

  @override
  void dispose() => disposed = true;
}
