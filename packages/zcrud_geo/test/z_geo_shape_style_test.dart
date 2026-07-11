// DP-21/M13 — `ZGeoShapeStyle` : style de forme NEUTRE (couleurs ARGB, aucun
// `Color` SDK), round-trip, ==/copyWith, et parse DÉFENSIF (AD-10) : map
// corrompue → null, clés corrompues → défauts neutres, opacité bornée, JAMAIS
// de throw.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('ZGeoShapeStyle round-trip + valeurs neutres', () {
    test('style par défaut = neutre (couleurs null, opacité 1, non draggable)',
        () {
      const style = ZGeoShapeStyle();
      expect(style.fillColorArgb, isNull);
      expect(style.strokeColorArgb, isNull);
      expect(style.strokeWidth, 3);
      expect(style.opacity, 1.0);
      expect(style.visible, isTrue);
      expect(style.draggable, isFalse);
      expect(style.showInfoWindow, isFalse);
      expect(style.consumeTapEvents, isTrue);
    });

    test('toMap → fromMapSafe stable (couleurs ARGB entières)', () {
      const style = ZGeoShapeStyle(
        fillColorArgb: 0x33FF0000,
        strokeColorArgb: 0xFF0000FF,
        strokeWidth: 5,
        visible: false,
        zIndex: 2,
        geodesic: true,
        opacity: 0.5,
        draggable: true,
        consumeTapEvents: false,
        iconAsset: 'assets/pin.png',
        iconColorArgb: 0xFF00FF00,
        showInfoWindow: true,
        infoWindowTitle: 'Titre',
        infoWindowSnippet: 'Détail',
      );
      final back = ZGeoShapeStyle.fromMapSafe(style.toMap());
      expect(back, equals(style));
      // Aucune couleur exposée n'est un type SDK : ce sont des `int?` (ARGB).
      expect(back!.fillColorArgb, isA<int?>());
      expect(back.fillColorArgb, 0x33FF0000);
    });

    test('== et hashCode cohérents ; copyWith substitue le seul champ visé', () {
      const a = ZGeoShapeStyle(strokeColorArgb: 0xFF112233, strokeWidth: 4);
      const b = ZGeoShapeStyle(strokeColorArgb: 0xFF112233, strokeWidth: 4);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));

      final c = a.copyWith(opacity: 0.25, draggable: true);
      expect(c.strokeColorArgb, 0xFF112233); // préservé
      expect(c.strokeWidth, 4); // préservé
      expect(c.opacity, 0.25);
      expect(c.draggable, isTrue);
      expect(c, isNot(equals(a)));
    });
  });

  group('ZGeoShapeStyle parse défensif AD-10 — JAMAIS de throw', () {
    test('non-Map → null', () {
      expect(ZGeoShapeStyle.fromMapSafe(null), isNull);
      expect(ZGeoShapeStyle.fromMapSafe('garbage'), isNull);
      expect(ZGeoShapeStyle.fromMapSafe(42), isNull);
    });

    test('clés corrompues → défauts neutres', () {
      final style = ZGeoShapeStyle.fromMapSafe(<String, Object?>{
        'fillColorArgb': 'not-a-color',
        'strokeWidth': 'x',
        'visible': 'nope',
        'opacity': 'NaN',
        'iconAsset': 999,
      });
      expect(style, isNotNull);
      expect(style!.fillColorArgb, isNull); // couleur illisible → null
      expect(style.strokeWidth, 3); // défaut
      expect(style.visible, isTrue); // défaut
      expect(style.opacity, 1.0); // défaut (non finie)
      expect(style.iconAsset, isNull); // non-String → null
    });

    test('couleur ARGB acceptée en hex string (#/0x) et décimale', () {
      expect(
        ZGeoShapeStyle.fromMapSafe(
          <String, Object?>{'strokeColorArgb': '#FF112233'},
        )!.strokeColorArgb,
        0xFF112233,
      );
      expect(
        ZGeoShapeStyle.fromMapSafe(
          <String, Object?>{'strokeColorArgb': '0xFF445566'},
        )!.strokeColorArgb,
        0xFF445566,
      );
      expect(
        ZGeoShapeStyle.fromMapSafe(
          <String, Object?>{'fillColorArgb': 255},
        )!.fillColorArgb,
        255,
      );
    });

    test('opacité hors [0,1] bornée défensivement', () {
      expect(
        ZGeoShapeStyle.fromMapSafe(<String, Object?>{'opacity': 5.0})!.opacity,
        1.0,
      );
      expect(
        ZGeoShapeStyle.fromMapSafe(<String, Object?>{'opacity': -3.0})!.opacity,
        0.0,
      );
      expect(
        ZGeoShapeStyle.fromMapSafe(
          <String, Object?>{'opacity': double.infinity},
        )!.opacity,
        1.0,
      );
    });
  });
}
