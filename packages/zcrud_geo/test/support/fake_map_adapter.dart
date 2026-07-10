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
  bool? lastInteractive;
  bool sawOnTap = false;

  /// Clé de la surface carte fake.
  static const Key mapKey = Key('fake-map');

  @override
  Widget buildMap(
    BuildContext context, {
    ZGeoPoint? center,
    ZGeoShape? shape,
    ValueChanged<ZGeoPoint>? onTap,
    bool interactive = true,
  }) {
    buildCount++;
    lastCenter = center;
    lastShape = shape;
    lastInteractive = interactive;
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
