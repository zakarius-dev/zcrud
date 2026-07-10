// AC1/AC5/AC11 — `ZGeoPoint` : round-trip neutre + parse DÉFENSIF (AD-10) :
// absent/non numérique/hors-bornes/non fini → `null`, JAMAIS de throw.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_geo/zcrud_geo.dart';

void main() {
  group('ZGeoPoint round-trip (AC1)', () {
    test('toMap → fromMapSafe est stable (avec métadonnées)', () {
      const p = ZGeoPoint(
        lat: 13.5137,
        lng: 2.1098,
        label: 'Niamey',
        address: 'Niger',
      );
      final back = ZGeoPoint.fromMapSafe(p.toMap());
      expect(back, equals(p));
    });

    test('toMap omet les métadonnées nulles', () {
      const p = ZGeoPoint(lat: 0, lng: 0);
      expect(p.toMap().containsKey('label'), isFalse);
      expect(p.toMap().containsKey('address'), isFalse);
      expect(ZGeoPoint.fromMapSafe(p.toMap()), equals(p));
    });

    test('fromMap est un alias défensif de fromMapSafe', () {
      const p = ZGeoPoint(lat: -1.5, lng: 30.0);
      expect(ZGeoPoint.fromMap(p.toMap()), equals(p));
    });

    test('accepte les coordonnées en String numérique', () {
      final back = ZGeoPoint.fromMapSafe(<String, Object?>{
        'lat': '13.5',
        'lng': '2.1',
      });
      expect(back, equals(const ZGeoPoint(lat: 13.5, lng: 2.1)));
    });
  });

  group('ZGeoPoint parse défensif AD-10 (AC5) — JAMAIS de throw', () {
    test('entrée non-Map → null', () {
      expect(ZGeoPoint.fromMapSafe(null), isNull);
      expect(ZGeoPoint.fromMapSafe('garbage'), isNull);
      expect(ZGeoPoint.fromMapSafe(42), isNull);
      expect(ZGeoPoint.fromMapSafe(<Object?>[1, 2]), isNull);
    });

    test('coordonnée absente → null', () {
      expect(ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 1.0}), isNull);
      expect(ZGeoPoint.fromMapSafe(<String, Object?>{'lng': 1.0}), isNull);
      expect(ZGeoPoint.fromMapSafe(<String, Object?>{}), isNull);
    });

    test('coordonnée non numérique → null', () {
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 'x', 'lng': 2.0}),
        isNull,
      );
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 1.0, 'lng': true}),
        isNull,
      );
    });

    test('coordonnée non finie (NaN/Inf) → null', () {
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{
          'lat': double.nan,
          'lng': 2.0,
        }),
        isNull,
      );
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{
          'lat': 1.0,
          'lng': double.infinity,
        }),
        isNull,
      );
    });

    test('hors-bornes (×4 signes) → null', () {
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 200.0, 'lng': 0.0}),
        isNull,
      );
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': -200.0, 'lng': 0.0}),
        isNull,
      );
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 0.0, 'lng': 999.0}),
        isNull,
      );
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 0.0, 'lng': -999.0}),
        isNull,
      );
    });

    test('label/address non-String → dégradés à null (pas de throw)', () {
      final p = ZGeoPoint.fromMapSafe(<String, Object?>{
        'lat': 1.0,
        'lng': 2.0,
        'label': 123,
        'address': <Object?>[],
      });
      expect(p, isNotNull);
      expect(p!.label, isNull);
      expect(p.address, isNull);
    });

    test('bornes exactes acceptées', () {
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': 90.0, 'lng': 180.0}),
        equals(const ZGeoPoint(lat: 90, lng: 180)),
      );
      expect(
        ZGeoPoint.fromMapSafe(<String, Object?>{'lat': -90.0, 'lng': -180.0}),
        equals(const ZGeoPoint(lat: -90, lng: -180)),
      );
    });
  });

  test('isValid reflète les bornes', () {
    expect(const ZGeoPoint(lat: 0, lng: 0).isValid, isTrue);
    expect(const ZGeoPoint(lat: 200, lng: 0).isValid, isFalse);
    expect(const ZGeoPoint(lat: double.nan, lng: 0).isValid, isFalse);
  });
}
