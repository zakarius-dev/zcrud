// DP-16 — `ZValidatorSpec` enrichi (M10/M11) : password paramétrable (défaut
// DODLP), address/percentage no-op par défaut. Vérifie la nature **pur-données
// const** (AC1/AC6), l'intégration des nouveaux champs dans `==`/`hashCode`, et le
// **catalogue fermé** `ZValidatorKind` (AD-3). + l10n additive `invalidPassword`
// (AC9).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZValidatorSpec.password — paramétrable, const, ==/hashCode (AC1)', () {
    test('const-instanciable + défauts DODLP portés par les champs', () {
      const spec = ZValidatorSpec.password();
      expect(spec.kind, ZValidatorKind.password);
      expect(spec.passwordMinLength, 8);
      expect(spec.passwordMaxLength, 20);
      expect(spec.requireUppercase, isTrue);
      expect(spec.requireLowercase, isTrue);
      expect(spec.requireDigit, isFalse);
      expect(spec.requireSpecial, isFalse);
    });

    test('mêmes paramètres ⇒ == et même hashCode', () {
      const a = ZValidatorSpec.password(minLength: 12, requireDigit: true);
      const b = ZValidatorSpec.password(minLength: 12, requireDigit: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('paramètres différents ⇒ non égaux', () {
      const a = ZValidatorSpec.password();
      const b = ZValidatorSpec.password(requireDigit: true);
      expect(a, isNot(b));
    });
  });

  group('ZValidatorSpec.address/percentage — opt-in, const, ==/hashCode', () {
    test('address const + enforceFormat porté ; == / != ', () {
      const noop = ZValidatorSpec.address();
      const enforced = ZValidatorSpec.address(enforceFormat: true);
      expect(noop.enforceFormat, isFalse);
      expect(enforced.enforceFormat, isTrue);
      expect(noop, isNot(enforced));
      expect(const ZValidatorSpec.address(enforceFormat: true), enforced);
      expect(const ZValidatorSpec.address(enforceFormat: true).hashCode,
          enforced.hashCode);
    });

    test('percentage const + plage portée ; == / != ', () {
      const noop = ZValidatorSpec.percentage();
      const ranged = ZValidatorSpec.percentage(
        enforceRange: true,
        min: 0,
        max: 50,
      );
      expect(noop.enforceRange, isFalse);
      expect(ranged.enforceRange, isTrue);
      expect(ranged.rangeMin, 0);
      expect(ranged.rangeMax, 50);
      expect(noop, isNot(ranged));
      expect(
        const ZValidatorSpec.percentage(enforceRange: true, min: 0, max: 50),
        ranged,
      );
      expect(
        const ZValidatorSpec.percentage(enforceRange: true, min: 10, max: 90),
        isNot(ranged),
      );
    });
  });

  group('ZValidatorKind — catalogue FERMÉ (AD-3, AC6)', () {
    test('20 valeurs, ensemble de noms inchangé', () {
      expect(ZValidatorKind.values, hasLength(20));
      expect(
        ZValidatorKind.values.map((k) => k.name).toSet(),
        <String>{
          'required',
          'minLength',
          'maxLength',
          'min',
          'max',
          'equal',
          'notEqual',
          'match',
          'email',
          'url',
          'ip',
          'creditCard',
          'phone',
          'numeric',
          'integer',
          'dateString',
          'address',
          'percentage',
          'password',
          'pattern',
        },
      );
    });

    test('rétro-compat : fabriques historiques toujours const', () {
      // Compile-time const (aucun paramètre requis nouveau) — AC8.
      const specs = <ZValidatorSpec>[
        ZValidatorSpec.password(),
        ZValidatorSpec.address(),
        ZValidatorSpec.percentage(),
      ];
      expect(specs, hasLength(3));
    });
  });

  group('l10n — clé additive invalidPassword (D7, AC9)', () {
    Future<ZcrudLocalizations> load(Locale locale) =>
        const ZcrudLocalizationsDelegate().load(locale);

    test('présente en `en` et `fr`', () async {
      final en = await load(const Locale('en'));
      final fr = await load(const Locale('fr'));
      expect(en.maybeResolve('invalidPassword'), 'Invalid password');
      expect(fr.maybeResolve('invalidPassword'), 'Mot de passe invalide');
    });

    test('repli défensif : clé absente d\'un registre ⇒ jamais de throw', () async {
      final fr = await load(const Locale('fr'));
      // Une clé inconnue retombe sur la clé brute (aucun throw).
      expect(fr.resolve('__unknown_key__'), '__unknown_key__');
      expect(fr.maybeResolve('__unknown_key__'), isNull);
    });
  });
}
