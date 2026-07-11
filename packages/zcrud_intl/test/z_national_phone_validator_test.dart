// DP-20 (M9) — Validateur téléphone national paramétrable (AC1..AC8).
//   - AC1 : ZNationalPhoneValidator const paramétrable (prefixes + length),
//           discriminant longueur/préfixe/requis ;
//   - AC3 : défensif AD-10 (validate ne throw jamais) ;
//   - AC4 : message l10n de présentation (repli français, surchargeable) ;
//   - AC5 : câblage opt-in sur ZIntlFieldConfig.nationalPhone (rétro-compat) ;
//   - AC7 : recette Togo (chiffres nus / formaté) prouvée ;
//   - AC8 : isolation (voir isolation_gates_test.dart pour l'assert statique).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

// Politique Togo (parité DODLP tgPhoneNumber) — vit SEULEMENT dans le test/doc,
// jamais en défaut du package (AD-12).
const _togoPrefixes = <String>[
  '70', '71', '77', '78', '79', '90', '91', '92', '93', '96', '97', '98', '99',
];

const _togoNationalPhone = ZNationalPhoneValidator(
  prefixes: _togoPrefixes,
  length: 8, // 8 chiffres nus
  required: true,
);

const _togoNationalPhoneFormatted = ZNationalPhoneValidator(
  prefixes: _togoPrefixes,
  length: 11, // "90 12 34 56" = 11 caractères
  required: true,
  digitsOnly: false,
);

ZCountryCatalog _catalog() => ZCountryCatalog.fromList(const <ZCountryInfo>[
      ZCountryInfo(isoCode: 'TG', name: 'Togo', dialCode: '+228', flagEmoji: '🇹🇬'),
      ZCountryInfo(isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
    ]);

ZFieldSpec _phoneField({ZFieldConfig? config}) => ZFieldSpec(
      name: 'f',
      type: EditionFieldType.phoneNumber,
      label: 'Téléphone',
      config: config,
    );

ZFormController _ctrl({Object? value}) => ZFormController(
      initialValues: <String, Object?>{'f': value},
      visibleFields: <String>['f'],
    );

Widget _app(ZFormController controller, ZFieldSpec field, ZWidgetRegistry reg) =>
    MaterialApp(
      home: ZcrudScope(
        widgetRegistry: reg,
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[field],
          ),
        ),
      ),
    );

ZWidgetRegistry _reg() => ZWidgetRegistry()
  ..register('phoneNumber', ZPhoneFieldWidget.builder(catalog: _catalog()));

void main() {
  group('AC1/AC7 — recette Togo sur CHIFFRES NUS (length 8, digitsOnly)', () {
    test('accepte les numéros DODLP valides', () {
      for (final n in <String>['90123456', '77123456', '70999999', '99000000']) {
        expect(_togoNationalPhone.validate(n), isNull, reason: n);
      }
    });

    test('rejette une mauvaise LONGUEUR', () {
      expect(_togoNationalPhone.validate('9012345'),
          ZNationalPhoneError.invalidLength);
      expect(_togoNationalPhone.validate('901234567'),
          ZNationalPhoneError.invalidLength);
    });

    test('rejette un PRÉFIXE hors-règle', () {
      expect(_togoNationalPhone.validate('10123456'),
          ZNationalPhoneError.invalidPrefix);
      expect(_togoNationalPhone.validate('12345678'),
          ZNationalPhoneError.invalidPrefix);
    });

    test('normalise l\'entrée formatée en chiffres nus (digitsOnly)', () {
      expect(_togoNationalPhone.validate('90 12 34 56'), isNull);
      expect(_togoNationalPhone.validate('90-12-34-56'), isNull);
    });

    test('ordre requis → longueur → préfixe (longueur prime sur préfixe)', () {
      // "101234" : mauvais préfixe ET mauvaise longueur → longueur signalée d'abord.
      expect(_togoNationalPhone.validate('101234'),
          ZNationalPhoneError.invalidLength);
    });
  });

  group('AC7 — recette Togo FORMATÉE (length 11, digitsOnly:false)', () {
    test('accepte la chaîne nationale formatée', () {
      expect(_togoNationalPhoneFormatted.validate('90 12 34 56'), isNull);
      expect(_togoNationalPhoneFormatted.validate('77 12 34 56'), isNull);
    });

    test('rejette une chaîne formatée incomplète', () {
      expect(_togoNationalPhoneFormatted.validate('90 12 34 5'),
          ZNationalPhoneError.invalidLength);
    });
  });

  group('AC3 — défensif AD-10 : validate ne throw JAMAIS', () {
    test('null → requis si required, sinon valide', () {
      expect(_togoNationalPhone.validate(null), ZNationalPhoneError.required);
      const optional = ZNationalPhoneValidator(prefixes: <String>['9'], length: 8);
      expect(optional.validate(null), isNull);
      expect(optional.validate(''), isNull);
    });

    test('type inattendu (int) → normalisé défensivement, jamais de throw', () {
      expect(() => _togoNationalPhone.validate(42), returnsNormally);
      // 42 n'est ni String/ZPhoneNumber/Map → partie nationale vide → requis.
      expect(_togoNationalPhone.validate(42), ZNationalPhoneError.required);
    });

    test('caractères non numériques (digitsOnly) → vide → requis', () {
      expect(_togoNationalPhone.validate('abc'), ZNationalPhoneError.required);
    });

    test('Map sérialisée → lit nationalNumber', () {
      final ok = const ZPhoneNumber(nationalNumber: '90123456').toMap();
      expect(_togoNationalPhone.validate(ok), isNull);
      final bad = const ZPhoneNumber(nationalNumber: '10123456').toMap();
      expect(_togoNationalPhone.validate(bad), ZNationalPhoneError.invalidPrefix);
      expect(() => _togoNationalPhone.validate(<String, Object?>{'x': 1}),
          returnsNormally);
    });

    test('ZPhoneNumber d\'entrée → lecture de nationalNumber', () {
      expect(_togoNationalPhone.validate(
          const ZPhoneNumber(nationalNumber: '90123456')), isNull);
      expect(
          _togoNationalPhone
              .validate(const ZPhoneNumber(nationalNumber: '9012345')),
          ZNationalPhoneError.invalidLength);
      // ZPhoneNumber neutre (aucun nationalNumber) → requis.
      expect(_togoNationalPhone.validate(const ZPhoneNumber()),
          ZNationalPhoneError.required);
    });
  });

  group('AC1 — == / hashCode du validateur', () {
    test('égalité structurelle (prefixes, length, required, digitsOnly)', () {
      const a = ZNationalPhoneValidator(prefixes: <String>['90'], length: 8);
      const b = ZNationalPhoneValidator(prefixes: <String>['90'], length: 8);
      const c = ZNationalPhoneValidator(prefixes: <String>['90'], length: 11);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('AC5 — == / hashCode de ZIntlFieldConfig avec/sans nationalPhone', () {
    test('rétro-compat : sans nationalPhone reste égal', () {
      const a = ZIntlFieldConfig(defaultCountryIso: 'TG');
      const b = ZIntlFieldConfig(defaultCountryIso: 'TG');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('nationalPhone intégré dans l\'égalité', () {
      const a = ZIntlFieldConfig(nationalPhone: _togoNationalPhone);
      const b = ZIntlFieldConfig(nationalPhone: _togoNationalPhone);
      const c = ZIntlFieldConfig();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == c, isFalse);
    });
  });

  group('AC4/AC5 — câblage widget opt-in + message annoncé', () {
    testWidgets('nationalPhone non-null : numéro invalide → errorText présent',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _phoneField(config: const ZIntlFieldConfig(nationalPhone: _togoNationalPhone)),
        _reg(),
      ));
      await t.pump();
      // Champ vide + required → message requis annoncé d'emblée.
      expect(find.text('Numéro de téléphone requis'), findsOneWidget);

      // Préfixe invalide.
      await t.enterText(find.byKey(const Key('z-phone-number')), '10123456');
      await t.pump();
      expect(find.text('Numéro de téléphone invalide'), findsOneWidget);

      // Longueur invalide.
      await t.enterText(find.byKey(const Key('z-phone-number')), '9012345');
      await t.pump();
      expect(find.text('Numéro de téléphone incomplet'), findsOneWidget);

      // Valide → aucun message d'erreur national.
      await t.enterText(find.byKey(const Key('z-phone-number')), '90123456');
      await t.pump();
      expect(find.text('Numéro de téléphone incomplet'), findsNothing);
      expect(find.text('Numéro de téléphone invalide'), findsNothing);
      expect(find.text('Numéro de téléphone requis'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('nationalPhone null → AUCUN message (rétro-compat E11a-2)',
        (t) async {
      await t.pumpWidget(_app(_ctrl(), _phoneField(), _reg()));
      await t.pump();
      expect(find.text('Numéro de téléphone requis'), findsNothing);
      await t.enterText(find.byKey(const Key('z-phone-number')), '10123456');
      await t.pump();
      expect(find.text('Numéro de téléphone invalide'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('SM-1 : la frappe ne perd pas le focus (rebuild ciblé)',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _phoneField(config: const ZIntlFieldConfig(nationalPhone: _togoNationalPhone)),
        _reg(),
      ));
      await t.pump();
      final numberFinder = find.byKey(const Key('z-phone-number'));
      await t.tap(numberFinder);
      await t.pump();
      // Frappe successive : le champ reste focalisé malgré le recalcul d'erreur.
      for (final chunk in <String>['9', '90', '901', '9012']) {
        await t.enterText(numberFinder, chunk);
        await t.pump();
        final editable = t.widget<EditableText>(
          find.descendant(of: numberFinder, matching: find.byType(EditableText)),
        );
        expect(editable.focusNode.hasFocus, isTrue,
            reason: 'focus perdu après frappe "$chunk" (SM-1/AD-2)');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('errorText annoncé via la sémantique du TextField (AD-13)',
        (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_app(
        _ctrl(),
        _phoneField(config: const ZIntlFieldConfig(nationalPhone: _togoNationalPhone)),
        _reg(),
      ));
      await t.pump();
      // Le message d'erreur est présent dans l'arbre sémantique (annonçable).
      expect(
        find.bySemanticsLabel('Numéro de téléphone requis'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
