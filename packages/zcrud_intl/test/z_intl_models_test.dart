// AC1/AC5/AC10 — modèles de valeur NEUTRES : round-trip toMap→fromMap stable et
// parse DÉFENSIF (AD-10). Tests pur-Dart (aucun Flutter).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

void main() {
  group('ZPhoneNumber — round-trip & défensif', () {
    test('round-trip toMap→fromMap stable', () {
      const p = ZPhoneNumber(
        e164: '+22790000000',
        isoCode: 'NE',
        dialCode: '+227',
        nationalNumber: '90000000',
      );
      expect(ZPhoneNumber.fromMap(p.toMap()), equals(p));
    });

    test('champs vides omis à la sérialisation', () {
      const p = ZPhoneNumber(isoCode: 'NE');
      expect(p.toMap(), equals(<String, Object?>{'isoCode': 'NE'}));
    });

    test('fromMapSafe(non-map) → null, jamais de throw', () {
      expect(() => ZPhoneNumber.fromMapSafe('abc'), returnsNormally);
      expect(ZPhoneNumber.fromMapSafe('abc'), isNull);
      expect(ZPhoneNumber.fromMapSafe(42), isNull);
      expect(ZPhoneNumber.fromMapSafe(null), isNull);
    });

    test('champs non-String dégradés à null (défensif)', () {
      final p = ZPhoneNumber.fromMapSafe(<String, Object?>{
        'e164': 12345,
        'isoCode': 'NE',
        'nationalNumber': <int>[1, 2],
      });
      expect(p, isNotNull);
      expect(p!.e164, isNull);
      expect(p.isoCode, 'NE');
      expect(p.nationalNumber, isNull);
    });

    test('map sans champ significatif → neutre isEmpty', () {
      final p = ZPhoneNumber.fromMapSafe(<String, Object?>{'e164': ''});
      expect(p, isNotNull);
      expect(p!.isEmpty, isTrue);
    });
  });

  group('ZPostalAddress — round-trip & défensif', () {
    test('round-trip toMap→fromMap stable', () {
      const a = ZPostalAddress(
        line1: '12 rue X',
        city: 'Niamey',
        region: 'Niamey',
        postalCode: '8001',
        countryCode: 'NE',
      );
      expect(ZPostalAddress.fromMap(a.toMap()), equals(a));
    });

    test('fromMapSafe(non-map) → null, jamais de throw', () {
      expect(() => ZPostalAddress.fromMapSafe(3.14), returnsNormally);
      expect(ZPostalAddress.fromMapSafe(3.14), isNull);
      expect(ZPostalAddress.fromMapSafe(null), isNull);
    });

    test('map corrompue (types non-String) → adresse neutre vide', () {
      final a = ZPostalAddress.fromMapSafe(<String, Object?>{
        'line1': 99,
        'city': <String>['x'],
        'countryCode': true,
      });
      expect(a, isNotNull);
      expect(a!.isEmpty, isTrue);
    });

    test('tous champs vides → adresse neutre isEmpty', () {
      final a = ZPostalAddress.fromMapSafe(<String, Object?>{'line1': ''});
      expect(a, isNotNull);
      expect(a!.isEmpty, isTrue);
    });
  });

  group('ZCountryInfo — round-trip & défensif', () {
    test('round-trip toMap→fromMap stable', () {
      const c = ZCountryInfo(
        isoCode: 'NE',
        name: 'Niger',
        dialCode: '+227',
        flagEmoji: '🇳🇪',
      );
      expect(ZCountryInfo.fromMap(c.toMap()), equals(c));
    });

    test('fromMapSafe sans code ISO → null', () {
      expect(
        ZCountryInfo.fromMapSafe(<String, Object?>{'name': 'X'}),
        isNull,
      );
    });

    test('fromMapSafe(non-map) → null, jamais de throw', () {
      expect(() => ZCountryInfo.fromMapSafe(<int>[1]), returnsNormally);
      expect(ZCountryInfo.fromMapSafe(<int>[1]), isNull);
    });

    test('LOW-3 : toMap écrit les clés canoniques iso/flag, relues symétriquement',
        () {
      const c = ZCountryInfo(
        isoCode: 'NE',
        name: 'Niger',
        dialCode: '+227',
        flagEmoji: '🇳🇪',
      );
      final map = c.toMap();
      // Contrat de clés canoniques (alignées asset countries.json).
      expect(map.keys, containsAll(<String>['iso', 'name', 'dialCode', 'flag']));
      expect(map.containsKey('isoCode'), isFalse);
      expect(map.containsKey('flagEmoji'), isFalse);
      // Round-trip symétrique via ces mêmes clés canoniques.
      expect(ZCountryInfo.fromMap(map), equals(c));
    });

    test('alias iso/flag + normalisation majuscule', () {
      final c = ZCountryInfo.fromMapSafe(<String, Object?>{
        'iso': 'ne',
        'flag': '🇳🇪',
      });
      expect(c, isNotNull);
      expect(c!.isoCode, 'NE');
      expect(c.flagEmoji, '🇳🇪');
    });
  });
}
