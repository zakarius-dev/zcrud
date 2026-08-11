/// G1 (CR geo-field-parity-legacy 2026-08-11) — lecture des documents
/// Firestore LEGACY (DODLP `data_crud/models/geo_shape.dart`).
///
/// Les échantillons ci-dessous sont la reproduction EXACTE de ce que le writer
/// legacy émet (`GeoShape.toJson()` = `json.encode(toMap())`, gs:581-666) :
/// enveloppe **String JSON**, clés `type`/`points`/`radius`/`style`/`holes`,
/// couleurs `fillColor`/`strokeColor`/`iconColor` en **int ARGB**
/// (`Color.value`), style TOUJOURS émis (non-nullable côté legacy).
///
/// Chaque garde ici doit être ROUGE sur le code d'origine (v0.80.0) — la
/// lecture stricte refusait toute String et ignorait `points`/`radius`/
/// `fillColor`. La non-régression zcrud (lecture stricte inchangée) est gardée
/// en fin de fichier.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

/// Style legacy tel qu'émis par `GeoShapeStyle.toMap()` (gs:180-201) :
/// scalaires toujours présents, couleurs en int ARGB décimal.
Map<String, Object?> legacyStyleMap({int? fill, int? stroke, int? icon}) =>
    <String, Object?>{
      'fillColor': ?fill,
      'strokeColor': ?stroke,
      'strokeWidth': 2,
      'visible': true,
      'zIndex': 0,
      'geodesic': false,
      'opacity': 1.0,
      'iconColor': ?icon,
      'iconSize': 32.0, // inconnu de zcrud — doit être ignoré sans throw
      'iconAnchor': <String, Object?>{'lat': 0.5, 'lng': 1.0}, // idem
      'iconRotation': 0.0, // idem
      'showInfoWindow': false,
      'draggable': false,
      'consumeTapEvents': true,
    };

void main() {
  // Couleurs de référence legacy (presets gs:154-177, `Color.value` → int).
  const int legacyFill = 0x334285F4;
  const int legacyStroke = 0xFF4285F4;

  /// Polygone legacy complet, copié de la forme writer (gs:581-593).
  final Map<String, Object?> legacyPolygonMap = <String, Object?>{
    'type': 'polygon',
    'points': <Object?>[
      <String, Object?>{'lat': 6.1319, 'lng': 1.2228},
      <String, Object?>{'lat': 6.1402, 'lng': 1.2101},
      <String, Object?>{'lat': 6.1205, 'lng': 1.2050},
    ],
    'style': legacyStyleMap(fill: legacyFill, stroke: legacyStroke),
    'label': 'Zone portuaire',
    'holes': <Object?>[
      <Object?>[
        <String, Object?>{'lat': 6.1310, 'lng': 1.2210},
        <String, Object?>{'lat': 6.1320, 'lng': 1.2220},
        <String, Object?>{'lat': 6.1315, 'lng': 1.2215},
      ],
    ],
  };

  /// Cercle legacy : centre = points[0], rayon = `radius` (gs:337-350).
  final Map<String, Object?> legacyCircleMap = <String, Object?>{
    'type': 'circle',
    'points': <Object?>[
      <String, Object?>{'lat': 6.1319, 'lng': 1.2228},
    ],
    'radius': 250.0,
    'style': legacyStyleMap(fill: legacyFill, stroke: legacyStroke),
    'label': 'Rayon de contrôle',
  };

  /// Point legacy : type point, points[0] (gs:325-334).
  final Map<String, Object?> legacyPointMap = <String, Object?>{
    'type': 'point',
    'points': <Object?>[
      <String, Object?>{'lat': 6.1319, 'lng': 1.2228},
    ],
    'style': legacyStyleMap(icon: legacyStroke),
    'label': 'Port de Lomé',
  };

  group('G1(a) — enveloppe String JSON (legacy toJson, gs:666)', () {
    test('ZGeoShape.fromMapSafe accepte la chaîne JSON legacy du polygone', () {
      final shape = ZGeoShape.fromMapSafe(jsonEncode(legacyPolygonMap));
      expect(shape, isNotNull,
          reason: 'une String JSON legacy doit être décodée (jsonDecode '
              'défensif), pas refusée comme non-Map');
      expect(shape!.vertices, hasLength(3),
          reason: 'les 3 sommets legacy `points` doivent être lus');
      expect(shape.vertices.first.lat, 6.1319);
      expect(shape.vertices.first.lng, 1.2228);
    });

    test('ZGeoCircle.fromMapSafe accepte la chaîne JSON legacy du cercle', () {
      final circle = ZGeoCircle.fromMapSafe(jsonEncode(legacyCircleMap));
      expect(circle, isNotNull,
          reason: 'String JSON legacy → cercle non-null');
      expect(circle!.radiusMeters, 250.0,
          reason: 'le rayon legacy `radius` (mètres) doit être lu');
      expect(circle.center.lat, 6.1319,
          reason: 'le centre legacy est points[0]');
    });

    test('ZGeoPoint.fromMapSafe accepte la chaîne JSON legacy du point', () {
      final point = ZGeoPoint.fromMapSafe(jsonEncode(legacyPointMap));
      expect(point, isNotNull, reason: 'String JSON legacy → point non-null');
      expect(point!.lat, 6.1319);
      expect(point.lng, 1.2228);
      expect(point.label, 'Port de Lomé',
          reason: 'le label porté par la forme legacy doit suivre');
    });

    test('JSON invalide → null, jamais throw (AD-10)', () {
      expect(ZGeoShape.fromMapSafe('{pas du json'), isNull);
      expect(ZGeoCircle.fromMapSafe('{"type":'), isNull);
      expect(ZGeoPoint.fromMapSafe('###'), isNull);
      expect(ZGeoShape.fromMapSafe('42'), isNull,
          reason: 'un JSON scalaire n\'est pas une forme');
    });
  });

  group('G1(b) — alias de LECTURE legacy', () {
    test('points → vertices : une Map legacy ne rend plus une forme vide', () {
      final shape = ZGeoShape.fromMapSafe(legacyPolygonMap);
      expect(shape, isNotNull);
      expect(shape!.vertices, hasLength(3),
          reason: 'PERTE SILENCIEUSE G1 : la clé legacy `points` doit être '
              'lue quand `vertices` est absente');
      expect(shape.label, 'Zone portuaire');
      expect(shape.holes, hasLength(1),
          reason: 'les holes legacy (mêmes clés) doivent suivre');
      expect(shape.holes!.first, hasLength(3));
    });

    test('radius → radius_m + centre depuis points[0] (cercle legacy)', () {
      final circle = ZGeoCircle.fromMapSafe(legacyCircleMap);
      expect(circle, isNotNull,
          reason: 'un cercle legacy (points[0]+radius) doit être lisible');
      expect(circle!.radiusMeters, 250.0);
      expect(circle.center.lat, 6.1319);
      expect(circle.center.lng, 1.2228);
      expect(circle.label, 'Rayon de contrôle');
    });

    test('fillColor/strokeColor (int ARGB legacy) → *Argb', () {
      final shape = ZGeoShape.fromMapSafe(legacyPolygonMap);
      expect(shape?.style, isNotNull,
          reason: 'le style legacy (toujours émis) doit être parsé');
      expect(shape!.style!.fillColorArgb, legacyFill,
          reason: 'alias de lecture fillColor → fillColorArgb (int mesuré '
              'dans le JSON legacy : Color.value)');
      expect(shape.style!.strokeColorArgb, legacyStroke,
          reason: 'alias strokeColor → strokeColorArgb');
      expect(shape.style!.strokeWidth, 2,
          reason: 'les scalaires communs se lisent inchangés');
    });

    test('iconColor legacy → iconColorArgb ; clés inconnues ignorées', () {
      final point = ZGeoPoint.fromMapSafe(legacyPointMap);
      expect(point, isNotNull);
      final style =
          ZGeoShapeStyle.fromMapSafe(legacyStyleMap(icon: legacyStroke));
      expect(style, isNotNull,
          reason: 'iconSize/iconAnchor/iconRotation inconnus ne font '
              'jamais échouer le parse (AD-10)');
      expect(style!.iconColorArgb, legacyStroke,
          reason: 'alias iconColor → iconColorArgb');
    });

    test('latitude/longitude (variante lue par le lecteur legacy) → lat/lng',
        () {
      final point = ZGeoPoint.fromMapSafe(
          <String, Object?>{'latitude': 6.1319, 'longitude': 1.2228});
      expect(point, isNotNull,
          reason: 'variante legacy latitude/longitude acceptée en lecture');
      expect(point!.lat, 6.1319);
      expect(point.lng, 1.2228);
    });
  });

  group('G1 — routage du cercle (le piège nommé)', () {
    test('ZGeoShape.fromMapSafe REFUSE une Map legacy de type circle (null, '
        'jamais une forme à 1 sommet qui perdrait le rayon)', () {
      expect(ZGeoShape.fromMapSafe(legacyCircleMap), isNull,
          reason: 'parser un cercle legacy comme forme = perte silencieuse '
              'du rayon — la classe exacte du bug G1 ; null oblige le '
              'routage par ZGeoValue');
    });

    test('un point legacy typé reste lisible comme forme dégénérée (1 sommet, '
        'sans perte)', () {
      final shape = ZGeoShape.fromMapSafe(legacyPointMap);
      expect(shape, isNotNull);
      expect(shape!.vertices, hasLength(1));
    });
  });

  group('G1 — NON-RÉGRESSION : la lecture stricte zcrud est INCHANGÉE', () {
    test('round-trip zcrud shape : toMap → fromMapSafe identique', () {
      final original = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 1.0, lng: 2.0),
          ZGeoPoint(lat: 3.0, lng: 4.0),
        ],
        label: 'l',
        id: 'i',
        style: const ZGeoShapeStyle(fillColorArgb: 0x11223344),
        metadata: const <String, Object?>{'k': 'v'},
      );
      expect(ZGeoShape.fromMapSafe(original.toMap()), original);
    });

    test('vertices prime TOUJOURS sur points quand les deux existent', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[
          <String, Object?>{'lat': 9.0, 'lng': 9.0},
        ],
        'points': <Object?>[
          <String, Object?>{'lat': 1.0, 'lng': 1.0},
          <String, Object?>{'lat': 2.0, 'lng': 2.0},
        ],
      });
      expect(shape!.vertices, hasLength(1));
      expect(shape.vertices.single.lat, 9.0);
    });

    test('radius_m corrompu ne se fait PAS secourir par un alias', () {
      expect(
        ZGeoCircle.fromMapSafe(<String, Object?>{
          'center': <String, Object?>{'lat': 1.0, 'lng': 1.0},
          'radius_m': 'garbage',
          'radius': 250.0,
        }),
        isNull,
        reason: 'radius_m présent-mais-corrompu → null comme avant (la '
            'lecture élargie ne fait pas mentir la lecture stricte)',
      );
    });

    test('fillColorArgb présent prime sur fillColor', () {
      final style = ZGeoShapeStyle.fromMapSafe(<String, Object?>{
        'fillColorArgb': 0x0A0B0C0D,
        'fillColor': 0x334285F4,
      });
      expect(style!.fillColorArgb, 0x0A0B0C0D);
    });

    test('lat/lng zcrud priment sur latitude/longitude', () {
      final point = ZGeoPoint.fromMapSafe(<String, Object?>{
        'lat': 5.0,
        'lng': 6.0,
        'latitude': 1.0,
        'longitude': 2.0,
      });
      expect(point!.lat, 5.0);
      expect(point.lng, 6.0);
    });

    test('non-Map non-String non-List → toujours null (AD-10)', () {
      expect(ZGeoShape.fromMapSafe(42), isNull);
      expect(ZGeoCircle.fromMapSafe(true), isNull);
      expect(ZGeoPoint.fromMapSafe(3.14), isNull);
      expect(ZGeoShape.fromMapSafe(null), isNull);
      expect(ZGeoCircle.fromMapSafe(null), isNull);
      expect(ZGeoPoint.fromMapSafe(null), isNull);
    });
  });
}
