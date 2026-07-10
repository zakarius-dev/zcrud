// AC1/AC2/AC5/AC7 — modèles neutres E11b-2 (pur-Dart) : round-trip stable +
// table défensive AD-10 (jamais de throw, état neutre/null).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

void main() {
  group('AC2 — ZMoney : round-trip + défensif (AD-14/AD-10)', () {
    test('round-trip stable (code + montant + formatted)', () {
      const m = ZMoney(currencyCode: 'XOF', amount: 1500, formatted: '1 500 CFA');
      final back = ZMoney.fromMap(m.toMap());
      expect(back, m);
      expect(back!.currencyCode, 'XOF');
      expect(back.amount, 1500);
    });

    test('map non-Map → null', () {
      expect(ZMoney.fromMapSafe('nope'), isNull);
      expect(ZMoney.fromMapSafe(42), isNull);
      expect(ZMoney.fromMapSafe(null), isNull);
    });

    test('tous champs vides → null (neutre)', () {
      expect(ZMoney.fromMapSafe(<String, Object?>{}), isNull);
      expect(
          ZMoney.fromMapSafe(<String, Object?>{'currencyCode': '', 'formatted': ''}),
          isNull);
    });

    test('amount non fini (NaN/Infinity) → rejeté (dégradé)', () {
      final nan = ZMoney.fromMapSafe(
          <String, Object?>{'currencyCode': 'EUR', 'amount': double.nan});
      expect(nan, isNotNull);
      expect(nan!.amount, isNull);
      expect(nan.currencyCode, 'EUR');
      final inf = ZMoney.fromMapSafe(
          <String, Object?>{'currencyCode': 'EUR', 'amount': double.infinity});
      expect(inf!.amount, isNull);
    });

    test('amount depuis String numérique acceptée ; non numérique → null', () {
      expect(
          ZMoney.fromMapSafe(
              <String, Object?>{'currencyCode': 'EUR', 'amount': '12.5'})!.amount,
          12.5);
      expect(
          ZMoney.fromMapSafe(
              <String, Object?>{'currencyCode': 'EUR', 'amount': 'abc'})!.amount,
          isNull);
    });

    test('alias currency/code + == / hashCode', () {
      final a = ZMoney.fromMapSafe(<String, Object?>{'currency': 'usd'});
      expect(a!.currencyCode, 'usd');
      const x = ZMoney(currencyCode: 'EUR', amount: 1);
      const y = ZMoney(currencyCode: 'EUR', amount: 1);
      expect(x, y);
      expect(x.hashCode, y.hashCode);
    });
  });

  group('AC3 — ZCurrencyInfo : défensif', () {
    test('round-trip + code absent → null', () {
      const c = ZCurrencyInfo(code: 'EUR', name: 'Euro', symbol: '€', decimalDigits: 2);
      expect(ZCurrencyInfo.fromMap(c.toMap()), c);
      expect(ZCurrencyInfo.fromMapSafe(<String, Object?>{'name': 'x'}), isNull);
      expect(ZCurrencyInfo.fromMapSafe('nope'), isNull);
    });

    test('decimalDigits non entier → null ; code normalisé majuscule', () {
      final c = ZCurrencyInfo.fromMapSafe(
          <String, Object?>{'code': 'eur', 'decimalDigits': 'x'});
      expect(c!.code, 'EUR');
      expect(c.decimalDigits, isNull);
    });
  });

  group('AC5/AC7 — ZSubdivision : défensif', () {
    test('round-trip + code/pays requis', () {
      const s = ZSubdivision(code: 'NE-2', countryIso: 'NE', name: 'Diffa', type: 'region');
      expect(ZSubdivision.fromMap(s.toMap()), s);
      expect(ZSubdivision.fromMapSafe(<String, Object?>{'name': 'x'}), isNull);
      expect(ZSubdivision.fromMapSafe('nope'), isNull);
    });

    test('countryIso de contexte (bucket) sert de repli', () {
      final s = ZSubdivision.fromMapSafe(
          <String, Object?>{'code': 'ne-2', 'name': 'Diffa'},
          countryIso: 'ne');
      expect(s!.code, 'NE-2');
      expect(s.countryIso, 'NE');
    });

    test('code présent mais aucun pays (ni raw ni contexte) → null', () {
      expect(ZSubdivision.fromMapSafe(<String, Object?>{'code': 'NE-2'}), isNull);
    });
  });

  group('AC1 — ZIntlFieldConfig : pur-données const, == / hashCode', () {
    test('défauts neutres', () {
      const cfg = ZIntlFieldConfig();
      expect(cfg.defaultCountryIso, isNull);
      expect(cfg.preferredCountryIsos, isEmpty);
      expect(cfg.showDialCode, isTrue);
      expect(cfg.searchable, isTrue);
      expect(cfg.defaultCurrencyCode, isNull);
    });

    test('== / hashCode (y compris preferredCountryIsos)', () {
      const a = ZIntlFieldConfig(
          defaultCountryIso: 'NE', preferredCountryIsos: <String>['NE', 'FR']);
      const b = ZIntlFieldConfig(
          defaultCountryIso: 'NE', preferredCountryIsos: <String>['NE', 'FR']);
      const c = ZIntlFieldConfig(
          defaultCountryIso: 'NE', preferredCountryIsos: <String>['FR', 'NE']);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });
}
