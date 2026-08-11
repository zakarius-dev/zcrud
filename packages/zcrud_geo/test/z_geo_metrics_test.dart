// G12 + « point-dans-zone » (§2) — métriques PURES : aire SPHÉRIQUE de
// polygone (parité stricte gs:504-522, R=6371000, trous NON déduits), aire
// PLANAIRE de cercle (π·r², gs:424-426), périmètre haversine fermé
// (gs:524-533) / longueur ouverte (gs:535-541), bounds (gs:469-498, cercle
// étendu de 1/111320 °/m), centroïde (gs:405-415), containsPoint (ray casting
// pair-impair, frontière inclusive, trous), tri angulaire G16 (gff:922-959).
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

/// Carré ~111 m de côté à l'équateur (0.001° de pas).
final ZGeoShape _smallSquare = ZGeoShape(vertices: const <ZGeoPoint>[
  ZGeoPoint(lat: 0, lng: 0),
  ZGeoPoint(lat: 0, lng: 0.001),
  ZGeoPoint(lat: 0.001, lng: 0.001),
  ZGeoPoint(lat: 0.001, lng: 0),
]);

/// Carré unitaire 0..1° (containsPoint / tri angulaire).
const List<ZGeoPoint> _unitSquare = <ZGeoPoint>[
  ZGeoPoint(lat: 0, lng: 0),
  ZGeoPoint(lat: 0, lng: 1),
  ZGeoPoint(lat: 1, lng: 1),
  ZGeoPoint(lat: 1, lng: 0),
];

void main() {
  // 0.001° d'arc sur R=6371000 : (π/180)·R·0.001 ≈ 111.1949 m.
  final double side = math.pi / 180 * 6371000 * 0.001;

  group('G12 — aire de polygone (SPHÉRIQUE, parité gs:504-522)', () {
    test('carré ~111 m : aire ≈ côté² (formule d\'excès sphérique legacy)',
        () {
      final double? area = _smallSquare.areaSquareMeters;
      expect(area, isNotNull);
      // La formule sphérique converge vers l'aire planaire pour une petite
      // emprise équatoriale : tolérance 0.1 %.
      expect(area, closeTo(side * side, side * side * 0.001));
    });

    test('< 3 sommets → null (pas d\'aire)', () {
      expect(ZGeoShape().areaSquareMeters, isNull);
      expect(
        ZGeoShape(vertices: _unitSquare.sublist(0, 2)).areaSquareMeters,
        isNull,
      );
    });

    test(
        'PARITÉ DOCUMENTÉE : les trous ne sont PAS déduits (le legacy ignore '
        'holes dans area — écart assumé, pas un oubli)', () {
      final ZGeoShape holed = _smallSquare.copyWith(
        holes: const <List<ZGeoPoint>>[
          <ZGeoPoint>[
            ZGeoPoint(lat: 0.0004, lng: 0.0004),
            ZGeoPoint(lat: 0.0004, lng: 0.0006),
            ZGeoPoint(lat: 0.0006, lng: 0.0006),
            ZGeoPoint(lat: 0.0006, lng: 0.0004),
          ],
        ],
      );
      expect(holed.areaSquareMeters, equals(_smallSquare.areaSquareMeters));
    });
  });

  group('G12 — périmètre / longueur (haversine, parité gs:524-541)', () {
    test('carré : périmètre FERMÉ ≈ 4 côtés (segment de fermeture inclus)',
        () {
      expect(
        _smallSquare.perimeterMeters,
        closeTo(4 * side, 4 * side * 0.001),
      );
    });

    test('polyligne : longueur OUVERTE ≈ 3 côtés (sans fermeture)', () {
      expect(
        _smallSquare.lengthMeters,
        closeTo(3 * side, 3 * side * 0.001),
      );
    });

    test('< 2 sommets → null', () {
      expect(ZGeoShape().perimeterMeters, isNull);
      expect(ZGeoShape().lengthMeters, isNull);
    });
  });

  group('G12 — cercle (aire PLANAIRE π·r², parité gs:424-441)', () {
    const ZGeoCircle circle = ZGeoCircle(
      center: ZGeoPoint(lat: 6.13, lng: 1.28),
      radiusMeters: 100,
    );

    test('aire = π·r² (planaire, PAS sphérique — nature legacy documentée)',
        () {
      expect(circle.areaSquareMeters, closeTo(math.pi * 100 * 100, 1e-6));
    });

    test('circonférence = 2·π·r', () {
      expect(circle.perimeterMeters, closeTo(2 * math.pi * 100, 1e-6));
    });

    test('cercle invalide → null (AD-10)', () {
      const ZGeoCircle bad =
          ZGeoCircle(center: ZGeoPoint(lat: 0, lng: 0), radiusMeters: -1);
      expect(bad.areaSquareMeters, isNull);
      expect(bad.perimeterMeters, isNull);
      expect(bad.bounds, isNull);
    });
  });

  group('G12 — bounds (parité gs:469-498)', () {
    test('forme : min/max lat/lng en coins SW/NE', () {
      final ZGeoBounds? b = _smallSquare.bounds;
      expect(b, isNotNull);
      expect(b!.southWest, const ZGeoPoint(lat: 0, lng: 0));
      expect(b.northEast, const ZGeoPoint(lat: 0.001, lng: 0.001));
      expect(ZGeoShape().bounds, isNull);
    });

    test('cercle : expansion legacy 1/111320 °/m (gs:486)', () {
      const ZGeoCircle circle = ZGeoCircle(
        center: ZGeoPoint(lat: 0, lng: 0),
        radiusMeters: 1113.2, // = 0.01° exactement avec le facteur legacy
      );
      final ZGeoBounds b = circle.bounds!;
      expect(b.southWest.lat, closeTo(-0.01, 1e-9));
      expect(b.northEast.lng, closeTo(0.01, 1e-9));
    });

    test('centroïde = moyenne arithmétique (gs:405-415)', () {
      final ZGeoPoint? c = ZGeoShape(vertices: _unitSquare).centroid;
      expect(c, const ZGeoPoint(lat: 0.5, lng: 0.5));
      expect(ZGeoShape().centroid, isNull);
    });
  });

  group('Point-dans-zone — ray casting (frontière inclusive, trous)', () {
    final ZGeoShape square = ZGeoShape(vertices: _unitSquare);
    final ZGeoShape holed = square.copyWith(
      holes: const <List<ZGeoPoint>>[
        <ZGeoPoint>[
          ZGeoPoint(lat: 0.4, lng: 0.4),
          ZGeoPoint(lat: 0.4, lng: 0.6),
          ZGeoPoint(lat: 0.6, lng: 0.6),
          ZGeoPoint(lat: 0.6, lng: 0.4),
        ],
      ],
    );

    test('intérieur strict → true ; extérieur → false', () {
      expect(square.containsPoint(const ZGeoPoint(lat: 0.5, lng: 0.5)), isTrue);
      expect(
          square.containsPoint(const ZGeoPoint(lat: 1.5, lng: 0.5)), isFalse);
      expect(square.containsPoint(const ZGeoPoint(lat: -0.1, lng: -0.1)),
          isFalse);
    });

    test('LIMITE : sommet exact → true (frontière inclusive)', () {
      expect(square.containsPoint(const ZGeoPoint(lat: 0, lng: 0)), isTrue);
      expect(square.containsPoint(const ZGeoPoint(lat: 1, lng: 1)), isTrue);
    });

    test('LIMITE : point sur une arête → true (frontière inclusive)', () {
      expect(square.containsPoint(const ZGeoPoint(lat: 0, lng: 0.5)), isTrue);
      expect(square.containsPoint(const ZGeoPoint(lat: 0.5, lng: 1)), isTrue);
    });

    test('TROU : point dans le trou → false ; hors du trou → true ; sur le '
        'bord du trou → true (inclusif partout)', () {
      expect(holed.containsPoint(const ZGeoPoint(lat: 0.5, lng: 0.5)), isFalse);
      expect(holed.containsPoint(const ZGeoPoint(lat: 0.2, lng: 0.2)), isTrue);
      expect(holed.containsPoint(const ZGeoPoint(lat: 0.4, lng: 0.5)), isTrue);
    });

    test('dégénéré : < 3 sommets ou point invalide → false (AD-10)', () {
      expect(ZGeoShape().containsPoint(const ZGeoPoint(lat: 0, lng: 0)),
          isFalse);
      expect(
        square.containsPoint(const ZGeoPoint(lat: double.nan, lng: 0)),
        isFalse,
      );
    });

    test('cercle : haversine ≤ rayon, frontière inclusive', () {
      const ZGeoCircle circle = ZGeoCircle(
        center: ZGeoPoint(lat: 0, lng: 0),
        radiusMeters: 200,
      );
      // 0.001° ≈ 111.19 m < 200 m → dedans ; 0.003° ≈ 333.6 m → dehors.
      expect(
          circle.containsPoint(const ZGeoPoint(lat: 0.001, lng: 0)), isTrue);
      expect(
          circle.containsPoint(const ZGeoPoint(lat: 0.003, lng: 0)), isFalse);
      expect(circle.containsPoint(const ZGeoPoint(lat: 0, lng: 0)), isTrue);
    });
  });

  group('G16 — tri angulaire anti-auto-intersection (parité gff:922-959)', () {
    test('ordre « nœud papillon » réordonné en anneau convexe (tri atan2 '
        'autour du centroïde, ordre legacy exact)', () {
      final ZGeoShape bowtie = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 0, lng: 0),
          ZGeoPoint(lat: 1, lng: 1),
          ZGeoPoint(lat: 0, lng: 1),
          ZGeoPoint(lat: 1, lng: 0),
        ],
        label: 'zone',
      );
      final ZGeoShape sorted = bowtie.sortedByAngleAroundCentroid();
      // atan2(lat−0.5, lng−0.5) croissant : (0,0) → (0,1) → (1,1) → (1,0).
      expect(sorted.vertices, const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 0, lng: 1),
        ZGeoPoint(lat: 1, lng: 1),
        ZGeoPoint(lat: 1, lng: 0),
      ]);
      // Attributs préservés ; l'anneau trié retrouve l'aire pleine (le
      // nœud papillon auto-intersecté en perdait la moitié).
      expect(sorted.label, 'zone');
      expect(
        sorted.areaSquareMeters,
        greaterThan(bowtie.areaSquareMeters! * 1.5),
      );
    });

    test('< 3 sommets → forme inchangée (parité du garde gff:923)', () {
      final ZGeoShape line = ZGeoShape(vertices: _unitSquare.sublist(0, 2));
      expect(line.sortedByAngleAroundCentroid(), equals(line));
    });
  });
}
