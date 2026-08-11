/// G1(c) — `ZGeoValue.fromMapSafe` : routage discriminé sur la clé `type`
/// legacy (`point|circle|polygon|polyline`, camelCase — DODLP
/// `data_crud/models/geo_shape.dart`, enum `GeoShapeType.name`).
///
/// Échantillons copiés de la forme EXACTE du writer legacy
/// (`GeoShape.toJson()` → enveloppe String, style toujours émis, couleurs int
/// ARGB `Color.value`).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  const int legacyFill = 0x334285F4;
  const int legacyStroke = 0xFF4285F4;

  Map<String, Object?> style({int? fill, int? stroke}) => <String, Object?>{
        'fillColor': ?fill,
        'strokeColor': ?stroke,
        'strokeWidth': 3,
        'visible': true,
        'zIndex': 0,
        'geodesic': false,
        'opacity': 1.0,
        'iconRotation': 0.0,
        'showInfoWindow': false,
        'draggable': false,
        'consumeTapEvents': true,
      };

  String legacyJson(String type, List<Map<String, Object?>> points,
          {double? radius}) =>
      jsonEncode(<String, Object?>{
        'type': type,
        'points': points,
        'radius': ?radius,
        'style': style(fill: legacyFill, stroke: legacyStroke),
      });

  const p1 = <String, Object?>{'lat': 6.1319, 'lng': 1.2228};
  const p2 = <String, Object?>{'lat': 6.1402, 'lng': 1.2101};
  const p3 = <String, Object?>{'lat': 6.1205, 'lng': 1.2050};

  group('G1(c) — routage discriminé sur `type` (String JSON legacy)', () {
    test('type point → ZGeoPoint', () {
      final v = ZGeoValue.fromMapSafe(legacyJson('point', const [p1]));
      expect(v, isA<ZGeoPoint>(),
          reason: 'une valeur legacy typée point doit devenir un ZGeoPoint');
      expect((v! as ZGeoPoint).lat, 6.1319);
    });

    test('type circle → ZGeoCircle (points[0]+radius routés, JAMAIS une '
        'forme à 1 sommet)', () {
      final v =
          ZGeoValue.fromMapSafe(legacyJson('circle', const [p1], radius: 250));
      expect(v, isA<ZGeoCircle>(),
          reason: 'le piège G1 : le cercle legacy doit être ROUTÉ, pas '
              'aplati en forme (perte du rayon)');
      final c = v! as ZGeoCircle;
      expect(c.radiusMeters, 250.0);
      expect(c.center.lat, 6.1319);
      expect(c.center.lng, 1.2228);
    });

    test('type polygon → ZGeoShape avec sommets et style traduits', () {
      final v = ZGeoValue.fromMapSafe(legacyJson('polygon', const [p1, p2, p3]));
      expect(v, isA<ZGeoShape>());
      final s = v! as ZGeoShape;
      expect(s.vertices, hasLength(3));
      expect(s.style?.fillColorArgb, legacyFill);
      expect(s.style?.strokeColorArgb, legacyStroke);
    });

    test('type polyline → ZGeoShape (tracé ouvert : même type de valeur que '
        'le widget consomme pour ZGeoGeometry.polyline)', () {
      final v = ZGeoValue.fromMapSafe(legacyJson('polyline', const [p1, p2]));
      expect(v, isA<ZGeoShape>(),
          reason: 'mesuré : le widget zcrud rend polygon ET polyline depuis '
              'une ZGeoShape (_shapeOf) — l\'ouverture vient de la géométrie '
              'du champ, pas de la valeur');
      expect((v! as ZGeoShape).vertices, hasLength(2));
    });
  });

  group('G1(c) — replis défensifs (AD-10)', () {
    test('instance déjà typée rendue telle quelle', () {
      const point = ZGeoPoint(lat: 1, lng: 2);
      expect(ZGeoValue.fromMapSafe(point), same(point));
      final shape = ZGeoShape(vertices: const [point]);
      expect(ZGeoValue.fromMapSafe(shape), same(shape));
      const circle = ZGeoCircle(center: point, radiusMeters: 5);
      expect(ZGeoValue.fromMapSafe(circle), same(circle));
    });

    test('List JSON nue (lecteur legacy fromDynamic) : 1 → point, 3 → forme',
        () {
      expect(ZGeoValue.fromMapSafe(jsonEncode([p1])), isA<ZGeoPoint>());
      final v = ZGeoValue.fromMapSafe(jsonEncode([p1, p2, p3]));
      expect(v, isA<ZGeoShape>());
      expect((v! as ZGeoShape).vertices, hasLength(3));
    });

    test('valeur zcrud SANS type : détection structurelle inchangée', () {
      final shape = ZGeoShape(
          vertices: const [ZGeoPoint(lat: 1, lng: 2), ZGeoPoint(lat: 3, lng: 4)]);
      expect(ZGeoValue.fromMapSafe(shape.toMap()), shape);
      const circle =
          ZGeoCircle(center: ZGeoPoint(lat: 1, lng: 2), radiusMeters: 9);
      expect(ZGeoValue.fromMapSafe(circle.toMap()), circle);
      const point = ZGeoPoint(lat: 1, lng: 2, label: 'l');
      expect(ZGeoValue.fromMapSafe(point.toMap()), point);
    });

    test('rayon présent sans type → cercle, jamais une forme qui perd le '
        'rayon', () {
      final v = ZGeoValue.fromMapSafe(<String, Object?>{
        'points': <Object?>[p1],
        'radius': 120.0,
      });
      expect(v, isA<ZGeoCircle>());
      expect((v! as ZGeoCircle).radiusMeters, 120.0);
    });

    test('type inconnu (schéma futur) → repli structurel additif', () {
      final v = ZGeoValue.fromMapSafe(<String, Object?>{
        'type': 'rectangle',
        'points': <Object?>[p1, p2],
      });
      expect(v, isA<ZGeoShape>(),
          reason: 'AD-10 additif : un discriminant inconnu ne jette pas la '
              'donnée si la structure reste exploitable');
    });

    test('anomalies → null, jamais throw', () {
      expect(ZGeoValue.fromMapSafe(null), isNull);
      expect(ZGeoValue.fromMapSafe('{invalide'), isNull);
      expect(ZGeoValue.fromMapSafe(42), isNull);
      expect(ZGeoValue.fromMapSafe(jsonEncode('juste une chaine')), isNull);
      expect(ZGeoValue.fromMapSafe(const <String, Object?>{}), isNull);
      expect(
          ZGeoValue.fromMapSafe(
              const <String, Object?>{'type': 'circle'}),
          isNull,
          reason: 'cercle legacy sans centre ni rayon → null (état neutre)');
    });
  });
}
