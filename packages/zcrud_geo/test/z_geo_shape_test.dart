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

  group('ZGeoShape attributs DP-21/M13 (id/style/holes/metadata) — additifs', () {
    test('forme SANS attributs = Map E11a-1 strictement inchangée (rétro-compat)',
        () {
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 13.5, lng: 2.1),
          ZGeoPoint(lat: 13.6, lng: 2.2),
        ],
        label: 'zone',
      );
      // Aucune clé id/style/holes/metadata émise quand null (schéma additif).
      expect(shape.toMap().keys, containsAll(<String>['vertices', 'label']));
      expect(
        shape.toMap().keys,
        isNot(anyElement(isIn(<String>['id', 'style', 'holes', 'metadata']))),
      );
      expect(shape.id, isNull);
      expect(shape.style, isNull);
      expect(shape.holes, isNull);
      expect(shape.metadata, isNull);
    });

    test('round-trip complet id/style/holes/metadata', () {
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[
          ZGeoPoint(lat: 13.5, lng: 2.1),
          ZGeoPoint(lat: 13.6, lng: 2.2),
          ZGeoPoint(lat: 13.7, lng: 2.3),
        ],
        label: 'zone',
        id: 'shape-42',
        style: const ZGeoShapeStyle(
          fillColorArgb: 0x33FF0000,
          strokeColorArgb: 0xFF0000FF,
          strokeWidth: 4,
        ),
        holes: const <List<ZGeoPoint>>[
          <ZGeoPoint>[
            ZGeoPoint(lat: 13.55, lng: 2.15),
            ZGeoPoint(lat: 13.56, lng: 2.16),
            ZGeoPoint(lat: 13.57, lng: 2.17),
          ],
        ],
        metadata: const <String, Object?>{'kind': 'zone', 'severity': 3},
      );
      final back = ZGeoShape.fromMapSafe(shape.toMap());
      expect(back, equals(shape));
      expect(back!.id, 'shape-42');
      expect(back.style!.strokeWidth, 4);
      expect(back.holes, hasLength(1));
      expect(back.holes!.first, hasLength(3));
      expect(back.metadata!['kind'], 'zone');
    });

    test('== distingue deux formes aux holes/metadata différents', () {
      final base = ZGeoShape(
        vertices: const <ZGeoPoint>[ZGeoPoint(lat: 1, lng: 1)],
        metadata: const <String, Object?>{'k': 'v'},
      );
      final other = ZGeoShape(
        vertices: const <ZGeoPoint>[ZGeoPoint(lat: 1, lng: 1)],
        metadata: const <String, Object?>{'k': 'w'},
      );
      expect(base, isNot(equals(other)));
      // Même contenu → égales même si maps/holes sont des instances distinctes.
      final clone = ZGeoShape(
        vertices: const <ZGeoPoint>[ZGeoPoint(lat: 1, lng: 1)],
        metadata: <String, Object?>{'k': 'v'},
      );
      expect(base, equals(clone));
      expect(base.hashCode, equals(clone.hashCode));
    });

    test('copyWith préserve les attributs optionnels non substitués', () {
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[ZGeoPoint(lat: 1, lng: 1)],
        id: 'a',
        style: const ZGeoShapeStyle(strokeWidth: 7),
        metadata: const <String, Object?>{'k': 'v'},
      );
      final copy = shape.copyWith(label: 'nouveau');
      expect(copy.label, 'nouveau');
      expect(copy.id, 'a'); // préservé
      expect(copy.style!.strokeWidth, 7); // préservé
      expect(copy.metadata!['k'], 'v'); // préservé
    });

    test('holes/metadata sont non modifiables (immutabilité)', () {
      final shape = ZGeoShape(
        vertices: const <ZGeoPoint>[ZGeoPoint(lat: 1, lng: 1)],
        holes: const <List<ZGeoPoint>>[
          <ZGeoPoint>[ZGeoPoint(lat: 2, lng: 2)],
        ],
        metadata: const <String, Object?>{'k': 'v'},
      );
      expect(
        () => shape.holes!.add(const <ZGeoPoint>[]),
        throwsUnsupportedError,
      );
      expect(
        () => shape.holes!.first.add(const ZGeoPoint(lat: 3, lng: 3)),
        throwsUnsupportedError,
      );
      expect(() => shape.metadata!['x'] = 1, throwsUnsupportedError);
    });
  });

  group('ZGeoShape parse défensif DP-21/M13 — JAMAIS de throw', () {
    test('style/metadata corrompus → null (sans faire échouer la forme)', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[
          <String, Object?>{'lat': 1.0, 'lng': 1.0},
        ],
        'style': 'garbage', // non-Map → style null
        'metadata': 42, // non-Map → metadata null
        'id': 999, // non-String → id null
      });
      expect(shape, isNotNull);
      expect(shape!.vertices, hasLength(1));
      expect(shape.style, isNull);
      expect(shape.metadata, isNull);
      expect(shape.id, isNull);
    });

    test('holes corrompus : trou non-List ignoré, sommets invalides filtrés', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[],
        'holes': <Object?>[
          'not-a-list', // trou corrompu → ignoré
          <Object?>[
            <String, Object?>{'lat': 2.0, 'lng': 2.0}, // ok
            <String, Object?>{'lat': 200.0, 'lng': 0.0}, // hors-bornes → filtré
            'garbage', // non-Map → filtré
          ],
        ],
      });
      expect(shape, isNotNull);
      // Un seul trou conservé (le premier, non-List, a été ignoré).
      expect(shape!.holes, hasLength(1));
      expect(shape.holes!.first, hasLength(1)); // seul le sommet valide reste
    });

    test('holes non-List → null (rétro-compat : aucun trou)', () {
      final shape = ZGeoShape.fromMapSafe(<String, Object?>{
        'vertices': <Object?>[],
        'holes': 7,
      });
      expect(shape!.holes, isNull);
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
