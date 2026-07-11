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

    // M11 (DP-16) : `address` no-op par défaut ; format vérifié en opt-in seul.
    test('address (enforceFormat: true) → street', () {
      checks('address',
          const ZValidatorSpec.address(enforceFormat: true, errorText: 'E'),
          valid: '123 Main Street', invalid: '@@@', msg: 'E');
    });

    // M11 (DP-16) : `percentage` no-op par défaut ; plage vérifiée en opt-in seul.
    test('percentage (enforceRange: true) → between(0,100)', () {
      final validator =
          v(const ZValidatorSpec.percentage(enforceRange: true, errorText: 'E'));
      expect(validator('50'), isNull, reason: 'percentage : 50 dans [0,100]');
      expect(validator('0'), isNull, reason: 'percentage : borne basse incluse');
      expect(validator('100'), isNull, reason: 'percentage : borne haute incluse');
      expect(validator('150'), 'E', reason: 'percentage : 150 hors [0,100]');
    });

    // M10 (DP-16) : défaut password = politique DODLP (maj+min, ni chiffre ni
    // spécial). `Abcdefgh` (valide DODLP) est ACCEPTÉ ; `abc` (trop court, pas de
    // maj) est rejeté.
    test('password (défaut DODLP)', () {
      checks('password', const ZValidatorSpec.password(errorText: 'E'),
          valid: 'Abcdefgh', invalid: 'abc', msg: 'E');
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

  // ── DP-16 : password paramétrable (M10) ────────────────────────────────────
  group('ZValidatorCompiler — password défaut DODLP (M10, AC2)', () {
    test('accepte un mot de passe DODLP-valide sans chiffre ni spécial', () {
      final validator = v(const ZValidatorSpec.password(errorText: 'E'));
      // 8 car., maj+min, ni chiffre ni spécial ⇒ VALIDE (parité DODLP restaurée).
      expect(validator('Abcdefgh'), isNull);
      // < 8 car.
      expect(validator('Abcdefg'), 'E', reason: 'trop court (< 8)');
      // > 20 car. (21).
      expect(validator('Abcdefghijklmnopqrstu'), 'E', reason: 'trop long (> 20)');
      // Sans majuscule.
      expect(validator('abcdefgh'), 'E', reason: 'pas de majuscule');
      // Sans minuscule.
      expect(validator('ABCDEFGH'), 'E', reason: 'pas de minuscule');
    });

    test('DP-16-M1 : password NON requis laissé vide reste VALIDE', () {
      // Parité DODLP « vide + non requis ⇒ null » : le validateur password ne
      // porte PAS implicitement la présence (checkNullOrEmpty: false). La vacuité
      // est gouvernée séparément par ZValidatorKind.required.
      final validator = v(const ZValidatorSpec.password(errorText: 'E'));
      expect(validator(''), isNull, reason: 'vide + non requis ⇒ valide');
      expect(validator(null), isNull, reason: 'null + non requis ⇒ valide');
      // La présence reste imposable via un `required` séparé.
      final withRequired = ZValidatorCompiler.compile(const <ZValidatorSpec>[
        ZValidatorSpec.required(errorText: 'R'),
        ZValidatorSpec.password(errorText: 'E'),
      ])!;
      expect(withRequired(''), 'R', reason: 'required séparé ⇒ vide rejeté');
    });
  });

  group('ZValidatorCompiler — password strict opt-in (M10, AC3)', () {
    test('politique stricte rejette Abcdefgh et accepte un mdp fort', () {
      final validator = v(const ZValidatorSpec.password(
        minLength: 12,
        requireDigit: true,
        requireSpecial: true,
        errorText: 'E',
      ));
      expect(validator('Abcdefgh'), 'E',
          reason: 'trop court + sans chiffre/spécial');
      expect(validator('Abcdefgh1!xy'), isNull,
          reason: '12 car., maj+min+chiffre+spécial');
    });
  });

  // ── DP-16 : address/percentage no-op par défaut (M11) ──────────────────────
  group('ZValidatorCompiler — address no-op / opt-in (M11, AC4)', () {
    test('défaut ⇒ compile null (aucune surcharge), toute valeur acceptée', () {
      expect(
        ZValidatorCompiler.compile(const <ZValidatorSpec>[
          ZValidatorSpec.address(),
        ]),
        isNull,
      );
    });

    test('enforceFormat: true ⇒ street (rejette @@@, accepte une rue)', () {
      final validator = v(const ZValidatorSpec.address(
        enforceFormat: true,
        errorText: 'E',
      ));
      expect(validator('@@@'), 'E');
      expect(validator('123 Main Street'), isNull);
    });
  });

  group('ZValidatorCompiler — percentage no-op / opt-in (M11, AC5)', () {
    test('défaut ⇒ compile null ; 150/-5/abc acceptés', () {
      expect(
        ZValidatorCompiler.compile(const <ZValidatorSpec>[
          ZValidatorSpec.percentage(),
        ]),
        isNull,
      );
    });

    test('enforceRange: true ⇒ between(0,100)', () {
      final validator = v(const ZValidatorSpec.percentage(
        enforceRange: true,
        errorText: 'E',
      ));
      expect(validator('150'), 'E');
      expect(validator('50'), isNull);
      expect(validator('0'), isNull);
      expect(validator('100'), isNull);
    });

    test('plage surchargée (min:10,max:90) rejette 95', () {
      final validator = v(const ZValidatorSpec.percentage(
        enforceRange: true,
        min: 10,
        max: 90,
        errorText: 'E',
      ));
      expect(validator('95'), 'E');
      expect(validator('50'), isNull);
    });
  });

  // ── DP-16 : défensif (AC7) ─────────────────────────────────────────────────
  group('ZValidatorCompiler — défensif, ne lève jamais (AC7)', () {
    test('password(minLength: 30, maxLength: 10) ⇒ refuse proprement, pas de throw',
        () {
      late final String? Function(String?) validator;
      expect(
        () => validator = v(const ZValidatorSpec.password(
          minLength: 30,
          maxLength: 10,
          errorText: 'E',
        )),
        returnsNormally,
      );
      // Toute valeur échoue (contrainte incohérente) mais sans exception.
      expect(validator('Abcdefghij'), 'E');
    });

    test('percentage(enforceRange, min:100, max:0) ⇒ pas de throw', () {
      late final String? Function(String?) validator;
      expect(
        () => validator = v(const ZValidatorSpec.percentage(
          enforceRange: true,
          min: 100,
          max: 0,
          errorText: 'E',
        )),
        returnsNormally,
      );
      expect(validator('50'), 'E', reason: 'plage inversée ⇒ refuse');
    });

    test('liste réduite à des no-op (address()/percentage()) ⇒ compile null', () {
      expect(
        ZValidatorCompiler.compile(const <ZValidatorSpec>[
          ZValidatorSpec.address(),
          ZValidatorSpec.percentage(),
        ]),
        isNull,
      );
    });
  });

  // ── DP-16 : composition (AC10) ─────────────────────────────────────────────
  group('ZValidatorCompiler — composition avec password (AC10)', () {
    test('[required, password] compose dans l\'ordre', () {
      final validator = ZValidatorCompiler.compile(const <ZValidatorSpec>[
        ZValidatorSpec.required(errorText: 'R'),
        ZValidatorSpec.password(errorText: 'P'),
      ]);
      expect(validator, isNotNull);
      expect(validator!(''), 'R', reason: 'required échoue en premier');
      expect(validator('abc'), 'P', reason: 'puis password');
      expect(validator('Abcdefgh'), isNull, reason: 'les deux satisfaits');
    });
  });
}
