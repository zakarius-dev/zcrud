// Import/export GeoJSON (§2) — RFC 7946. Périmètre mesuré : le legacy n'a
// AUCUN code GeoJSON (grep négatif `geojson|kml` sur data_crud/ : 0 occurrence
// géo) → API seulement, aucun bouton de champ à copier. ⚠️ Piège d'ordre
// lon,lat gardé SPÉCIFIQUEMENT (RFC 7946 §3.1.1 : [longitude, latitude]).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('⚠️ Ordre lon,lat (RFC 7946 §3.1.1) — garde spécifique du piège', () {
    test('export Point : coordinates = [lng, lat], PAS [lat, lng]', () {
      const ZGeoPoint p = ZGeoPoint(lat: 6.136, lng: 1.285);
      final Map<String, Object?> geo = p.toGeoJson();
      expect(geo['type'], 'Point');
      // Lomé : lat 6.136 / lng 1.285 — une inversion serait invisible sur un
      // point symétrique, ces valeurs asymétriques la débusquent.
      expect(geo['coordinates'], <double>[1.285, 6.136]);
    });

    test('import Point : [lng, lat] relu dans le BON sens', () {
      final Object? v = ZGeoJson.fromGeoJsonSafe(<String, Object?>{
        'type': 'Point',
        'coordinates': <double>[1.285, 6.136],
      });
      expect(v, const ZGeoPoint(lat: 6.136, lng: 1.285));
    });

    test('coordonnées INVERSÉES hors-bornes → null, jamais une valeur fausse '
        '(lat 91 impossible)', () {
      final Object? v = ZGeoJson.fromGeoJsonSafe(<String, Object?>{
        'type': 'Point',
        'coordinates': <double>[6.136, 191.0],
      });
      expect(v, isNull);
    });
  });

  group('Polygon — anneaux fermés + trous', () {
    final ZGeoShape holed = ZGeoShape(
      vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 0, lng: 1),
        ZGeoPoint(lat: 1, lng: 1),
        ZGeoPoint(lat: 1, lng: 0),
      ],
      holes: const <List<ZGeoPoint>>[
        <ZGeoPoint>[
          ZGeoPoint(lat: 0.4, lng: 0.4),
          ZGeoPoint(lat: 0.4, lng: 0.6),
          ZGeoPoint(lat: 0.6, lng: 0.6),
          ZGeoPoint(lat: 0.6, lng: 0.4),
        ],
      ],
    );

    test('export : anneaux FERMÉS (1re position == dernière, RFC §3.1.6)', () {
      final Map<String, Object?> geo = holed.toGeoJson();
      expect(geo['type'], 'Polygon');
      final List<Object?> rings = geo['coordinates']! as List<Object?>;
      expect(rings, hasLength(2)); // extérieur + 1 trou
      final List<Object?> outer = rings.first! as List<Object?>;
      expect(outer, hasLength(5)); // 4 sommets + fermeture
      expect(outer.first, equals(outer.last));
    });

    test('aller-retour : sommets/trous restitués, fermeture RETIRÉE', () {
      final Object? back =
          ZGeoJson.fromGeoJsonSafe(jsonEncode(holed.toGeoJson()));
      expect(back, isA<ZGeoShape>());
      final ZGeoShape shape = back! as ZGeoShape;
      expect(shape.vertices, holed.vertices); // 4, pas 5
      expect(shape.holes, hasLength(1));
      expect(shape.holes!.single, holed.holes!.single);
    });

    test('position corrompue d\'un anneau → ignorée, jamais de throw (AD-10)',
        () {
      final Object? v = ZGeoJson.fromGeoJsonSafe(<String, Object?>{
        'type': 'Polygon',
        'coordinates': <Object?>[
          <Object?>[
            <double>[0, 0],
            'garbage',
            <double>[1, 0],
            <double>[1, 1],
            <double>[0, 0],
          ],
        ],
      });
      expect((v! as ZGeoShape).vertices, hasLength(3));
    });
  });

  group('LineString (polyligne)', () {
    test('export ouvert (pas de fermeture) + aller-retour', () {
      final ZGeoShape line = ZGeoShape(vertices: const <ZGeoPoint>[
        ZGeoPoint(lat: 0, lng: 0),
        ZGeoPoint(lat: 1, lng: 1),
      ]);
      final Map<String, Object?> geo = line.toGeoJson(asLineString: true);
      expect(geo['type'], 'LineString');
      expect(geo['coordinates'], hasLength(2)); // AUCUNE fermeture ajoutée
      expect(ZGeoJson.fromGeoJsonSafe(geo), equals(line));
    });
  });

  group('Cercle — convention Feature + radius_m (hors RFC, documentée)', () {
    const ZGeoCircle circle = ZGeoCircle(
      center: ZGeoPoint(lat: 6.13, lng: 1.28),
      radiusMeters: 250,
    );

    test('export : Feature{Point, properties.radius_m} — le rayon survit', () {
      final Map<String, Object?> geo = circle.toGeoJson();
      expect(geo['type'], 'Feature');
      expect((geo['geometry']! as Map<String, Object?>)['type'], 'Point');
      expect(
        (geo['properties']! as Map<String, Object?>)['radius_m'],
        250,
      );
    });

    test('aller-retour : relu en ZGeoCircle (jamais un point qui perdrait le '
        'rayon — pendant du piège G1)', () {
      final Object? back = ZGeoJson.fromGeoJsonSafe(circle.toGeoJson());
      expect(back, isA<ZGeoCircle>());
      expect((back! as ZGeoCircle).radiusMeters, 250);
      expect((back as ZGeoCircle).center, circle.center);
    });

    test('Feature Point SANS rayon → simple ZGeoPoint', () {
      final Object? v = ZGeoJson.fromGeoJsonSafe(<String, Object?>{
        'type': 'Feature',
        'geometry': <String, Object?>{
          'type': 'Point',
          'coordinates': <double>[1.28, 6.13],
        },
        'properties': <String, Object?>{'name': 'poste'},
      });
      expect(v, isA<ZGeoPoint>());
    });
  });

  group('AD-10 — un GeoJSON invalide rend null, ne throw JAMAIS', () {
    test('entrées invalides → null', () {
      expect(ZGeoJson.fromGeoJsonSafe(null), isNull);
      expect(ZGeoJson.fromGeoJsonSafe('{pas du json'), isNull);
      expect(ZGeoJson.fromGeoJsonSafe(42), isNull);
      expect(ZGeoJson.fromGeoJsonSafe(<String, Object?>{'type': 'Volcano'}),
          isNull);
      expect(
        ZGeoJson.fromGeoJsonSafe(
            <String, Object?>{'type': 'Point', 'coordinates': 'x'}),
        isNull,
      );
      // Type Multi* non porté par le modèle mono-forme → null (documenté).
      expect(
        ZGeoJson.fromGeoJsonSafe(<String, Object?>{
          'type': 'MultiPolygon',
          'coordinates': <Object?>[],
        }),
        isNull,
      );
    });

    test('FeatureCollection → PREMIÈRE feature exploitable (documenté)', () {
      final Object? v = ZGeoJson.fromGeoJsonSafe(<String, Object?>{
        'type': 'FeatureCollection',
        'features': <Object?>[
          <String, Object?>{'type': 'Feature', 'geometry': null},
          <String, Object?>{
            'type': 'Feature',
            'geometry': <String, Object?>{
              'type': 'Point',
              'coordinates': <double>[1.0, 2.0],
            },
          },
        ],
      });
      expect(v, const ZGeoPoint(lat: 2, lng: 1));
    });

    test('String JSON acceptée en entrée (même canal que fromMapSafe G1)', () {
      final Object? v = ZGeoJson.fromGeoJsonSafe(
        '{"type":"Point","coordinates":[1.285,6.136]}',
      );
      expect(v, const ZGeoPoint(lat: 6.136, lng: 1.285));
    });
  });
}
