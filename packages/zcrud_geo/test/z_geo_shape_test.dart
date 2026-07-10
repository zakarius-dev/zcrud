// AC1/AC5 — `ZGeoShape` : round-trip + parse DÉFENSIF (AD-10) : sommet invalide
// IGNORÉ (jamais fatal), map corrompue → null, tous sommets invalides → aire
// vide (état neutre), JAMAIS de throw.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('ZGeoShape round-trip (AC1)', () {
    test('toMap → fromMapSafe stable', () {
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 13.5, lng: 2.1),
          ZGeoPoint(lat: 13.6, lng: 2.2),
          ZGeoPoint(lat: 13.7, lng: 2.3),
        ],
        label: 'zone',
      );
      final back = ZGeoShape.fromMapSafe(shape.toMap());
      expect(back, equals(shape));
    });

    test('aire vide round-trip', () {
      final shape = ZGeoShape();
      expect(ZGeoShape.fromMapSafe(shape.toMap()), equals(shape));
      expect(shape.isEmpty, isTrue);
    });

    test('point unique = cas dégénéré exploitable', () {
      final shape = ZGeoShape(vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 1, lng: 2),
      ]);
      expect(shape.vertices, hasLength(1));
      expect(ZGeoShape.fromMapSafe(shape.toMap()), equals(shape));
    });
  });

  group('ZGeoShape parse défensif AD-10 (AC5) — JAMAIS de throw', () {
    test('non-Map → null', () {
      expect(ZGeoShape.fromMapSafe(null), isNull);
      expect(ZGeoShape.fromMapSafe('garbage'), isNull);
      expect(ZGeoShape.fromMapSafe(7), isNull);
    });

    test('sommet invalide ignoré, valides conservés', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[
          <String, Object?>{'lat': 13.5, 'lng': 2.1}, // ok
          <String, Object?>{'lat': 200.0, 'lng': 0.0}, // hors-bornes → ignoré
          'garbage', // non-Map → ignoré
          <String, Object?>{'lat': 'x', 'lng': 'y'}, // non num → ignoré
          <String, Object?>{'lat': 13.6, 'lng': 2.2}, // ok
        ],
      });
      expect(shape, isNotNull);
      expect(shape!.vertices, hasLength(2));
      expect(shape.vertices.first, equals(const ZGeoPoint(lat: 13.5, lng: 2.1)));
    });

    test('tous sommets invalides → aire VIDE (neutre), pas null', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[
          <String, Object?>{'lat': 200.0, 'lng': 0.0},
          'garbage',
        ],
      });
      expect(shape, isNotNull);
      expect(shape!.isEmpty, isTrue);
    });

    test('vertices absent/non-List → aire vide', () {
      expect(ZGeoShape.fromMapSafe(<String, Object?>{})!.isEmpty, isTrue);
      expect(
        ZGeoShape.fromMapSafe(<String, Object?>{'vertices': 42})!.isEmpty,
        isTrue,
      );
    });

    test('label non-String → null (pas de throw)', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[],
        'label': 999,
      });
      expect(shape!.label, isNull);
    });
  });

  test('addVertex retourne une copie augmentée (immutabilité)', () {
    final a = ZGeoShape(vertices: const <ZGeoPoint>[ZGeoPoint(lat: 1, lng: 1)]);
    final b = a.addVertex(const ZGeoPoint(lat: 2, lng: 2));
    expect(a.vertices, hasLength(1));
    expect(b.vertices, hasLength(2));
  });

  test('vertices est non modifiable', () {
    final shape = ZGeoShape(vertices: const <ZGeoPoint>[
      ZGeoPoint(lat: 1, lng: 1),
    ]);
    expect(
      () => shape.vertices.add(const ZGeoPoint(lat: 2, lng: 2)),
      throwsUnsupportedError,
    );
  });
}
