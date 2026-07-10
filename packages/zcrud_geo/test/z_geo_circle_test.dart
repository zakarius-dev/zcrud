// AC1/AC2 — `ZGeoCircle` : modèle neutre pur-Dart, round-trip toMap/fromMapSafe,
// défensif AD-10 (rayon ≤0/NaN/Inf, centre absent/hors-bornes → null, jamais de
// throw), isValid/copyWith/==/hashCode. Aucun type SDK carte dans l'API.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  const center = ZGeoPoint(lat: 13.5, lng: 2.1);

  group('AC1 — round-trip & sérialisation neutre', () {
    test('toMap → fromMapSafe stable (round-trip)', () {
      const circle =
          ZGeoCircle(center: center, radiusMeters: 500, label: 'zone');
      final map = circle.toMap();
      expect(map['radius_m'], 500);
      expect(map['label'], 'zone');
      expect(map['center'], isA<Map<String, Object?>>());
      final back = ZGeoCircle.fromMapSafe(map);
      expect(back, equals(circle));
    });

    test('label null omis de la Map', () {
      const circle = ZGeoCircle(center: center, radiusMeters: 250);
      expect(circle.toMap().containsKey('label'), isFalse);
    });

    test('fromMap alias == fromMapSafe', () {
      const circle = ZGeoCircle(center: center, radiusMeters: 100);
      expect(ZGeoCircle.fromMap(circle.toMap()), equals(circle));
    });

    test('rayon en String numérique accepté (défensif tolérant)', () {
      final back = ZGeoCircle.fromMapSafe(<String, Object?>{
        'center': center.toMap(),
        'radius_m': '750.5',
      });
      expect(back, isNotNull);
      expect(back!.radiusMeters, 750.5);
    });
  });

  group('AC2 — défensif AD-10 : jamais de throw, état neutre', () {
    test('raw non-Map → null', () {
      expect(ZGeoCircle.fromMapSafe('garbage'), isNull);
      expect(ZGeoCircle.fromMapSafe(42), isNull);
      expect(ZGeoCircle.fromMapSafe(null), isNull);
    });

    test('centre absent → null', () {
      expect(
        ZGeoCircle.fromMapSafe(<String, Object?>{'radius_m': 100}),
        isNull,
      );
    });

    test('centre hors-bornes (lat=200) → null', () {
      expect(
        ZGeoCircle.fromMapSafe(<String, Object?>{
          'center': <String, Object?>{'lat': 200.0, 'lng': 0.0},
          'radius_m': 100,
        }),
        isNull,
      );
    });

    test('rayon absent → null', () {
      expect(
        ZGeoCircle.fromMapSafe(<String, Object?>{'center': center.toMap()}),
        isNull,
      );
    });

    test('rayon non numérique → null', () {
      expect(
        ZGeoCircle.fromMapSafe(<String, Object?>{
          'center': center.toMap(),
          'radius_m': 'abc',
        }),
        isNull,
      );
    });

    test('rayon 0 / négatif → null', () {
      for (final r in <Object?>[0, 0.0, -5, -0.001]) {
        expect(
          ZGeoCircle.fromMapSafe(<String, Object?>{
            'center': center.toMap(),
            'radius_m': r,
          }),
          isNull,
          reason: 'rayon $r doit être rejeté',
        );
      }
    });

    test('rayon NaN / Inf → null', () {
      for (final r in <double>[double.nan, double.infinity, -double.infinity]) {
        expect(
          ZGeoCircle.fromMapSafe(<String, Object?>{
            'center': center.toMap(),
            'radius_m': r,
          }),
          isNull,
          reason: 'rayon $r doit être rejeté',
        );
      }
    });

    test('isValid : faux pour rayon ≤0 ou centre hors-bornes', () {
      expect(
        const ZGeoCircle(center: center, radiusMeters: 500).isValid,
        isTrue,
      );
      expect(
        const ZGeoCircle(center: center, radiusMeters: 0).isValid,
        isFalse,
      );
      expect(
        const ZGeoCircle(center: center, radiusMeters: -1).isValid,
        isFalse,
      );
      expect(
        const ZGeoCircle(
          center: ZGeoPoint(lat: 200, lng: 0),
          radiusMeters: 500,
        ).isValid,
        isFalse,
      );
      expect(
        const ZGeoCircle(
          center: center,
          radiusMeters: double.infinity,
        ).isValid,
        isFalse,
      );
    });
  });

  group('copyWith / == / hashCode / toString', () {
    test('copyWith substitue les champs fournis', () {
      const circle = ZGeoCircle(center: center, radiusMeters: 100);
      final c2 = circle.copyWith(radiusMeters: 200);
      expect(c2.radiusMeters, 200);
      expect(c2.center, center);
    });

    test('== et hashCode par valeur', () {
      const a = ZGeoCircle(center: center, radiusMeters: 100, label: 'x');
      const b = ZGeoCircle(center: center, radiusMeters: 100, label: 'x');
      const c = ZGeoCircle(center: center, radiusMeters: 101, label: 'x');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });

    test('toString mentionne le rayon', () {
      expect(
        const ZGeoCircle(center: center, radiusMeters: 100).toString(),
        contains('radiusMeters: 100'),
      );
    });
  });
}
