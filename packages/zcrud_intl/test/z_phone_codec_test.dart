// AC3/AC5/AC10 — pont interne `ZPhoneCodec` : normalisation E.164 confinée +
// défensif (AD-10). Import INTERNE (le codec n'est jamais exporté par le barrel).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_intl/src/presentation/z_phone_codec.dart';

void main() {
  group('ZPhoneCodec.dialCodeOf', () {
    test('code connu → indicatif', () {
      expect(ZPhoneCodec.dialCodeOf('NE'), '+227');
      expect(ZPhoneCodec.dialCodeOf('fr'), '+33');
    });
    test('code inconnu → null (jamais de throw)', () {
      expect(() => ZPhoneCodec.dialCodeOf('ZZ'), returnsNormally);
      expect(ZPhoneCodec.dialCodeOf('ZZ'), isNull);
    });
  });

  group('ZPhoneCodec.parse', () {
    test('numéro FR valide → E.164 neutre', () {
      final p = ZPhoneCodec.parse('612345678', iso: 'FR');
      expect(p.e164, '+33612345678');
      expect(p.isoCode, 'FR');
      expect(p.dialCode, '+33');
    });

    test('numéro non parsable → neutre sans E.164, pas de throw', () {
      late final dynamic p;
      expect(() => p = ZPhoneCodec.parse('abc', iso: 'FR'), returnsNormally);
      expect(p.e164, isNull);
      expect(p.dialCode, '+33');
    });

    test('pays inconnu → neutre brut, pas de throw', () {
      final p = ZPhoneCodec.parse('123', iso: 'ZZ');
      expect(p.e164, isNull);
      expect(p.nationalNumber, '123');
    });

    test('saisie vide → neutre isEmpty', () {
      final p = ZPhoneCodec.parse('', iso: 'FR');
      expect(p.isEmpty, isTrue);
      expect(p.dialCode, '+33');
    });
  });
}
