// DP-8 — AC1/AC2/AC3/AC6 : `ZAddressCodec` (String legacy ⇄ `ZPostalAddress`),
// round-trip fidèle, composition ordonnée, perte structure→String documentée,
// défensif (ne throw jamais).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

void main() {
  group('AC1/AC2 — decodeString (String legacy → formatted)', () {
    test('String non vide → ZPostalAddress(formatted: raw), sous-champs null', () {
      final a = ZAddressCodec.decodeString('12 rue X, Niamey');
      expect(a, isNotNull);
      expect(a!.formatted, '12 rue X, Niamey');
      expect(a.line1, isNull);
      expect(a.line2, isNull);
      expect(a.city, isNull);
      expect(a.region, isNull);
      expect(a.postalCode, isNull);
      expect(a.countryCode, isNull);
    });

    test('null / vide / blanc → null (état neutre)', () {
      expect(ZAddressCodec.decodeString(null), isNull);
      expect(ZAddressCodec.decodeString(''), isNull);
      expect(ZAddressCodec.decodeString('   '), isNull);
      expect(ZAddressCodec.decodeString('\t\n '), isNull);
    });

    test('valeurs non-String (Map/int/List/bool/double) → null, jamais de throw',
        () {
      expect(ZAddressCodec.decodeString(<String, Object?>{'line1': 'x'}), isNull);
      expect(ZAddressCodec.decodeString(42), isNull);
      expect(ZAddressCodec.decodeString(<int>[1, 2, 3]), isNull);
      expect(ZAddressCodec.decodeString(true), isNull);
      expect(ZAddressCodec.decodeString(3.14), isNull);
      expect(ZAddressCodec.decodeString(Object()), isNull);
    });

    test('la String legacy est portée TELLE QUELLE (espaces conservés)', () {
      const raw = '  12  rue   X  ';
      expect(ZAddressCodec.decodeString(raw)!.formatted, raw);
    });
  });

  group('AC2 — round-trip String (fidélité migration DODLP)', () {
    test('encodeToString(decodeString(s)) == s pour toute String non vide', () {
      for (final s in <String>[
        '12 rue X, Niamey',
        'Unnamed Road, Tillabéri',
        'Résidence Les Palmiers, Apt 4B, Niamey 8001',
        'a',
        '  espaces autour  ',
        'virgules, multiples, ici',
      ]) {
        expect(ZAddressCodec.encodeToString(ZAddressCodec.decodeString(s)), s,
            reason: 'round-trip doit préserver « $s » à l\'octet près');
      }
    });
  });

  group('AC1/AC3 — encodeToString', () {
    test('null / adresse vide → null', () {
      expect(ZAddressCodec.encodeToString(null), isNull);
      expect(ZAddressCodec.encodeToString(const ZPostalAddress()), isNull);
      expect(
        ZAddressCodec.encodeToString(const ZPostalAddress(formatted: '   ')),
        isNull,
      );
    });

    test('préfère formatted quand présent', () {
      const a = ZPostalAddress(
        line1: '12 rue X',
        city: 'Niamey',
        formatted: 'RENDU PRÉFÉRÉ',
      );
      expect(ZAddressCodec.encodeToString(a), 'RENDU PRÉFÉRÉ');
    });

    test('compose depuis les sous-champs (ordre canonique, joint ", ")', () {
      const a = ZPostalAddress(
        line1: '12 rue X',
        line2: 'Apt 4B',
        city: 'Niamey',
        region: 'Niamey',
        postalCode: '8001',
        countryCode: 'NE',
      );
      expect(
        ZAddressCodec.encodeToString(a),
        '12 rue X, Apt 4B, Niamey, Niamey, 8001, NE',
      );
    });

    test('composition ignore les sous-champs vides/blancs, garde l\'ordre', () {
      const a = ZPostalAddress(line1: '12 rue X', city: 'Niamey');
      expect(ZAddressCodec.encodeToString(a), '12 rue X, Niamey');
    });
  });

  group('AC3 — round-trip structuré + perte structure→String documentée', () {
    test('(a) formatted round-trippe à l\'octet près', () {
      const a = ZPostalAddress(
        line1: '12 rue X',
        formatted: '12 rue X, Niamey, Niger',
      );
      final back = ZAddressCodec.decodeString(ZAddressCodec.encodeToString(a));
      expect(back!.formatted, a.formatted);
    });

    test('(b) structuré SANS formatted : re-décodage lossy → seul formatted', () {
      const a = ZPostalAddress(
        line1: '12 rue X',
        city: 'Niamey',
        countryCode: 'NE',
      );
      final composed = ZAddressCodec.encodeToString(a);
      expect(composed, '12 rue X, Niamey, NE');
      final back = ZAddressCodec.decodeString(composed);
      // La structure est PERDUE : seul `formatted` est renseigné (documenté).
      expect(back!.formatted, '12 rue X, Niamey, NE');
      expect(back.line1, isNull);
      expect(back.city, isNull);
      expect(back.countryCode, isNull);
    });
  });

  group('AC6 — compat String au bord de persistance (round-trip stable)', () {
    test('ingestion String → formatted ; ré-encodage → même String', () {
      const legacy = 'Rond-point 6e, Niamey';
      final ingested = ZAddressCodec.decodeString(legacy);
      expect(ingested!.formatted, legacy);
      // Une story « compat String » réémet une String via encodeToString.
      expect(ZAddressCodec.encodeToString(ingested), legacy);
    });
  });
}
