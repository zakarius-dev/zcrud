// MEDIUM-1 (code-review E3-2) — COUVERTURE SÉMANTIQUE du `ZValidatorCompiler`.
//
// `ZValidatorCompiler` est PUBLIC (barrel `zcrud_core.dart`) et réutilisé par
// E3-5. `analyze` prouve seulement l'existence des symboles `FormBuilderValidators`;
// il ne prouve PAS que chaque famille de `ZValidatorSpec` est projetée sur le BON
// validateur. Ce fichier exerce le mapping ~20 familles → `FormFieldValidator`
// SÉMANTIQUEMENT : pour chaque famille champ-locale, une entrée VALIDE ⇒ `null`
// (aucune erreur) ET une entrée INVALIDE ⇒ message non-null (l'`errorText` fourni).
//
// Couvre aussi :
//   - liste vide ⇒ `null` (aucun validateur, aucune surcharge du TextFormField) ;
//   - composition de plusieurs specs ⇒ la 1re erreur (ordre préservé) remonte ;
//   - familles INTER-CHAMPS déférées (E3-5/E3-6) `minKey`/`maxKey`/`match` ⇒
//     IGNORÉES silencieusement (branche null-guardée `refKey` ⇒ `null`).
//
// Pur-données → pur-Dart : le compilateur retourne un `String? Function(String?)`,
// invocable SANS widget. On passe TOUJOURS un `errorText` explicite : cela évite
// toute dépendance à `FormBuilderLocalizations.current` (message par défaut) et
// asservit du même coup la PROPAGATION de l'`errorText`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  // Compile une SEULE spec et renvoie le validateur exécutable (non-null attendu
  // pour les familles champ-locales).
  String? Function(String?) v(ZValidatorSpec spec) {
    final compiled = ZValidatorCompiler.compile(<ZValidatorSpec>[spec]);
    expect(compiled, isNotNull,
        reason: 'famille champ-locale ${spec.kind.name} : validateur produit');
    return compiled!;
  }

  // Helper d'assertion valide→null / invalide→message pour UNE famille.
  void checks(
    String kind,
    ZValidatorSpec spec, {
    required String valid,
    required String invalid,
    required String msg,
  }) {
    final validator = v(spec);
    expect(validator(valid), isNull,
        reason: '$kind : entrée valide "$valid" ⇒ aucune erreur');
    expect(validator(invalid), msg,
        reason: '$kind : entrée invalide "$invalid" ⇒ message propagé');
  }

  group('ZValidatorCompiler — familles champ-locales (valide→null / invalide→msg)',
      () {
    test('required', () {
      checks('required', const ZValidatorSpec.required(errorText: 'E'),
          valid: 'x', invalid: '', msg: 'E');
    });

    test('minLength', () {
      checks('minLength', const ZValidatorSpec.minLength(3, errorText: 'E'),
          valid: 'abcd', invalid: 'ab', msg: 'E');
    });

    test('maxLength', () {
      checks('maxLength', const ZValidatorSpec.maxLength(3, errorText: 'E'),
          valid: 'ab', invalid: 'abcd', msg: 'E');
    });

    test('min (littéral)', () {
      checks('min', const ZValidatorSpec.min(5, errorText: 'E'),
          valid: '10', invalid: '2', msg: 'E');
    });

    test('max (littéral)', () {
      checks('max', const ZValidatorSpec.max(5, errorText: 'E'),
          valid: '2', invalid: '10', msg: 'E');
    });

    test('equal', () {
      checks('equal', const ZValidatorSpec.equal('foo', errorText: 'E'),
          valid: 'foo', invalid: 'bar', msg: 'E');
    });

    test('notEqual', () {
      checks('notEqual', const ZValidatorSpec.notEqual('foo', errorText: 'E'),
          valid: 'bar', invalid: 'foo', msg: 'E');
    });

    test('email', () {
      checks('email', const ZValidatorSpec.email(errorText: 'E'),
          valid: 'a@b.com', invalid: 'nope', msg: 'E');
    });

    test('url', () {
      checks('url', const ZValidatorSpec.url(errorText: 'E'),
          valid: 'https://example.com', invalid: 'not a url', msg: 'E');
    });

    test('ip', () {
      checks('ip', const ZValidatorSpec.ip(errorText: 'E'),
          valid: '192.168.0.1', invalid: '999.999.999.999', msg: 'E');
    });

    test('creditCard (Luhn)', () {
      checks('creditCard', const ZValidatorSpec.creditCard(errorText: 'E'),
          valid: '4111111111111111', invalid: '1234567890123456', msg: 'E');
    });

    test('phone → phoneNumber', () {
      checks('phone', const ZValidatorSpec.phone(errorText: 'E'),
          valid: '+14155552671', invalid: 'abc', msg: 'E');
    });

    test('numeric', () {
      checks('numeric', const ZValidatorSpec.numeric(errorText: 'E'),
          valid: '123', invalid: 'abc', msg: 'E');
    });

    test('integer', () {
      checks('integer', const ZValidatorSpec.integer(errorText: 'E'),
          valid: '123', invalid: '1.5', msg: 'E');
    });

    test('dateString → date', () {
      checks('dateString', const ZValidatorSpec.dateString(errorText: 'E'),
          valid: '2020-01-01', invalid: 'not-a-date', msg: 'E');
    });

    test('address → street', () {
      checks('address', const ZValidatorSpec.address(errorText: 'E'),
          valid: '123 Main Street', invalid: '@@@', msg: 'E');
    });

    test('percentage → between(0,100)', () {
      final validator = v(const ZValidatorSpec.percentage(errorText: 'E'));
      expect(validator('50'), isNull, reason: 'percentage : 50 dans [0,100]');
      expect(validator('0'), isNull, reason: 'percentage : borne basse incluse');
      expect(validator('100'), isNull, reason: 'percentage : borne haute incluse');
      expect(validator('150'), 'E', reason: 'percentage : 150 hors [0,100]');
    });

    test('password', () {
      checks('password', const ZValidatorSpec.password(errorText: 'E'),
          valid: 'Passw0rd!', invalid: 'abc', msg: 'E');
    });

    test('pattern → match(RegExp)', () {
      checks('pattern', const ZValidatorSpec.pattern(r'^[a-z]+$', errorText: 'E'),
          valid: 'abc', invalid: '123', msg: 'E');
    });
  });

  group('ZValidatorCompiler — liste vide & composition', () {
    test('liste vide ⇒ null (aucun validateur)', () {
      expect(ZValidatorCompiler.compile(const <ZValidatorSpec>[]), isNull);
    });

    test('un seul validateur ⇒ renvoyé tel quel (non-null, fonctionnel)', () {
      final validator =
          ZValidatorCompiler.compile(const <ZValidatorSpec>[
        ZValidatorSpec.required(errorText: 'R'),
      ]);
      expect(validator, isNotNull);
      expect(validator!(''), 'R');
      expect(validator('x'), isNull);
    });

    test('composition (compose) : 1re erreur remonte, ordre préservé', () {
      final validator = ZValidatorCompiler.compile(const <ZValidatorSpec>[
        ZValidatorSpec.required(errorText: 'REQUIS'),
        ZValidatorSpec.minLength(3, errorText: 'COURT'),
      ]);
      expect(validator, isNotNull);
      // Vide ⇒ échoue d'abord sur `required` (1er de la liste).
      expect(validator!(''), 'REQUIS');
      // Non vide mais trop court ⇒ échoue sur `minLength` (2e).
      expect(validator('ab'), 'COURT');
      // Valide sur les deux ⇒ null.
      expect(validator('abcd'), isNull);
    });
  });

  group('ZValidatorCompiler — inter-champs DÉFÉRÉS (E3-5/E3-6) ignorés', () {
    test('minKey (refKey, bound null) ⇒ null (ignoré silencieusement)', () {
      expect(
        ZValidatorCompiler.compile(
            const <ZValidatorSpec>[ZValidatorSpec.minKey('other')]),
        isNull,
      );
    });

    test('maxKey (refKey, bound null) ⇒ null (ignoré silencieusement)', () {
      expect(
        ZValidatorCompiler.compile(
            const <ZValidatorSpec>[ZValidatorSpec.maxKey('other')]),
        isNull,
      );
    });

    test('match (inter-champ) ⇒ null (ignoré silencieusement)', () {
      expect(
        ZValidatorCompiler.compile(
            const <ZValidatorSpec>[ZValidatorSpec.match('other')]),
        isNull,
      );
    });

    test('spec déférée mêlée à une locale ⇒ seule la locale subsiste', () {
      // [required, minKey] : minKey ignoré ⇒ un seul validateur effectif
      // (required), fonctionnel, sans compose.
      final validator = ZValidatorCompiler.compile(const <ZValidatorSpec>[
        ZValidatorSpec.required(errorText: 'R'),
        ZValidatorSpec.minKey('other'),
      ]);
      expect(validator, isNotNull);
      expect(validator!(''), 'R');
      expect(validator('x'), isNull);
    });
  });
}
