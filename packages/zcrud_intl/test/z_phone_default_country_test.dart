// CR-DODLP-PHONE-DEFAUT (2026-08-10) — le pays présélectionné du champ
// `phoneNumber` n'est plus une donnée FABRIQUÉE.
//
// Défaut corrigé : sans `ZIntlFieldConfig.defaultCountryIso`, le paquet de rendu
// `intl_phone_number_input` retombait sur le PREMIER pays de son catalogue par
// ordre alphabétique — l'Afghanistan, `+93` — que ni l'hôte ni l'utilisateur
// n'avait choisi. Un formulaire togolais s'ouvrait sur « +93 ».
//
// Ces gardes mesurent la CHAÎNE DE PRIORITÉ documentée en tête de
// `z_phone_field_widget.dart` :
//   valeur déjà saisie > config de l'hôte > locale ambiante > locales de
//   l'appareil > repli défini (AUCUN pays transmis).
//
// 🔴 La propriété la plus importante n'est pas l'indicatif affiché mais le fait
// qu'AUCUNE valeur déjà saisie ne soit réécrite par un changement de pays
// initial — groupe « invariant de la valeur persistée ».
//
// Harnais : `zcrud_intl` ne dépend pas de `flutter_localizations` ; les deux
// délégués ci-dessous servent UNIQUEMENT à monter un `TextField` sous une locale
// non anglaise (sans eux, `MaterialLocalizations` manque et le champ ne monte
// pas — un test VACANT). Ils ne portent aucune propriété mesurée.
import 'dart:io';

import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

import 'support/z_sources.dart' show stripComments;

class _AnyLocaleMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterialDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<MaterialLocalizations> o) =>
      false;
}

class _AnyLocaleCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _AnyLocaleCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);
  @override
  bool shouldReload(covariant LocalizationsDelegate<CupertinoLocalizations> o) =>
      false;
}

ZFieldSpec _field({ZFieldConfig? config}) => ZFieldSpec(
      name: 'f',
      type: EditionFieldType.phoneNumber,
      label: 'Téléphone',
      config: config,
    );

ZFormController _ctrl({Object? value}) => ZFormController(
      initialValues: <String, Object?>{'f': value},
      visibleFields: <String>['f'],
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  Locale? locale,
  String? builderDefaultIso,
  ThemeData? theme,
}) =>
    MaterialApp(
      locale: locale,
      theme: theme,
      supportedLocales: locale == null
          ? const <Locale>[Locale('en', 'US')]
          : <Locale>[locale],
      localizationsDelegates: const <LocalizationsDelegate<Object?>>[
        _AnyLocaleMaterialDelegate(),
        _AnyLocaleCupertinoDelegate(),
        DefaultWidgetsLocalizations.delegate,
      ],
      home: ZcrudScope(
        widgetRegistry: ZWidgetRegistry()
          ..register(
            'phoneNumber',
            ZPhoneFieldWidget.builder(defaultIsoCode: builderDefaultIso),
          ),
        child: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[field],
          ),
        ),
      ),
    );

Finder get _number => find.byKey(const Key('z-phone-number'));

String _text(WidgetTester t) => t
    .widget<EditableText>(
      find.descendant(of: _number, matching: find.byType(EditableText)),
    )
    .controller
    .text;

/// Indicatif RENDU par le sélecteur du paquet (l'unique texte visible qui
/// commence par `+`). Oracle direct du pays d'amorçage retenu.
String _dialCode(WidgetTester t) {
  final codes = t
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data)
      .whereType<String>()
      .where((s) => RegExp(r'^\+[0-9]+$').hasMatch(s))
      .toSet();
  expect(codes, hasLength(1),
      reason: 'un seul indicatif doit être rendu, trouvé : $codes');
  return codes.single;
}

/// Force les locales de l'APPAREIL (étape 5 de la chaîne) et les restaure.
void _deviceLocales(WidgetTester t, List<Locale> locales) {
  t.platformDispatcher.localesTestValue = locales;
  t.platformDispatcher.localeTestValue = locales.first;
  addTearDown(() {
    t.platformDispatcher.clearLocalesTestValue();
    t.platformDispatcher.clearLocaleTestValue();
  });
}

void main() {
  group('Chaîne de priorité — le pays est DÉRIVÉ, jamais inventé', () {
    // 🔴 LE défaut corrigé. Sans cette dérivation, le paquet rendrait `+93`
    // (mesuré le 2026-08-10 sur `intl_phone_number_input 0.7.5`, dont le
    // catalogue est trié alphabétiquement : Afghanistan en tête).
    testWidgets('étape 4 — locale ambiante fr_TG, aucune config → +228',
        (t) async {
      await t.pumpWidget(
          _app(_ctrl(), _field(), locale: const Locale('fr', 'TG')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+228');
    });

    // Le pays vient bien de la LOCALE et non d'un défaut zcrud : deux locales
    // différentes donnent deux indicatifs différents.
    testWidgets('étape 4 — locale ambiante fr_FR → +33 (rien n\'est figé)',
        (t) async {
      await t.pumpWidget(
          _app(_ctrl(), _field(), locale: const Locale('fr', 'FR')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+33');
    });

    testWidgets('étape 2 — la config de l\'hôte PRIME sur la locale ambiante',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'NE')),
        locale: const Locale('fr', 'TG'),
      ));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+227');
    });

    testWidgets('étape 3 — defaultIsoCode du builder PRIME sur la locale',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(),
        locale: const Locale('fr', 'TG'),
        builderDefaultIso: 'NE',
      ));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+227');
    });

    testWidgets('étape 2 > étape 3 — la config du champ prime sur le builder',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'FR')),
        locale: const Locale('fr', 'TG'),
        builderDefaultIso: 'NE',
      ));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+33');
    });

    // Étape 1 : la donnée de l'UTILISATEUR l'emporte sur tout le reste — c'est
    // le premier rempart contre la réécriture d'une valeur déjà saisie.
    testWidgets('étape 1 — le pays de la valeur saisie prime sur TOUT',
        (t) async {
      final c = _ctrl(value: '+33612345678');
      await t.pumpWidget(_app(
        c,
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'NE')),
        locale: const Locale('fr', 'TG'),
      ));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+33');
      expect(c.valueOf('f'), '+33612345678');
    });

    // Étape 5 — le cas COURANT explicitement demandé : une app force
    // `Locale('fr')`, qui ne porte AUCUN pays. La locale de l'appareil, elle,
    // en porte un : c'est une information réelle, pas une invention.
    testWidgets('étape 5 — locale sans pays (fr) + appareil fr_TG → +228',
        (t) async {
      _deviceLocales(t, const <Locale>[Locale('fr', 'TG')]);
      await t.pumpWidget(_app(_ctrl(), _field(), locale: const Locale('fr')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+228');
    });

    testWidgets('étape 5 — première locale appareil PORTEUSE d\'un pays retenue',
        (t) async {
      _deviceLocales(
          t, const <Locale>[Locale('fr'), Locale('es'), Locale('fr', 'NE')]);
      await t.pumpWidget(_app(_ctrl(), _field(), locale: const Locale('fr')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+227');
    });
  });

  group('Étape 6 — aucune source honnête : zcrud ne CHOISIT rien', () {
    // 🔴 LA règle écrite, et sa preuve la plus utile : quand plus aucune source
    // ne porte de pays, `zcrud_intl` ne DÉDUIT PAS le pays de la LANGUE (`fr` →
    // France, `de` → Allemagne serait une invention : le français n'est pas la
    // France). Il transmet `null`, et le paquet applique son artefact de tri.
    //
    // Cette garde rougit dans les DEUX sens : si quelqu'un « corrige » le repli
    // en devinant le pays d'après la langue, les deux indicatifs divergent ; si
    // quelqu'un code un pays en dur, l'un des deux `isNot` tombe.
    testWidgets('langues différentes, aucun pays → MÊME repli, jamais la langue',
        (t) async {
      _deviceLocales(t, const <Locale>[Locale('fr')]);
      await t.pumpWidget(_app(_ctrl(), _field(), locale: const Locale('fr')));
      await t.pumpAndSettle();
      final frRepli = _dialCode(t);
      expect(frRepli, isNot('+33'), reason: 'la langue fr ne fait pas la France');

      await t.pumpWidget(const SizedBox());
      t.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
      t.platformDispatcher.localeTestValue = const Locale('de');
      await t.pumpWidget(_app(_ctrl(), _field(), locale: const Locale('de')));
      await t.pumpAndSettle();
      final deRepli = _dialCode(t);
      expect(deRepli, isNot('+49'),
          reason: 'la langue de ne fait pas l\'Allemagne');
      expect(deRepli, frRepli,
          reason: 'le repli est DÉFINI et indépendant de la langue');
    });

    // …et le repli n'écrit RIEN dans la tranche : un champ jamais touché reste
    // vide, quel que soit l'indicatif que le tiers affiche.
    testWidgets('le repli n\'écrit aucune valeur dans la tranche', (t) async {
      _deviceLocales(t, const <Locale>[Locale('fr')]);
      final c = _ctrl();
      await t.pumpWidget(_app(c, _field(), locale: const Locale('fr')));
      await t.pumpAndSettle();
      expect(c.valueOf('f'), isNull);
      expect(_text(t), isEmpty);
    });
  });

  group('AD-10 — pays inconnu, malformé, macro-région : repli DÉFINI', () {
    // Assainissement PAR CANDIDAT : un code pays inconnu n'annule pas la
    // chaîne, il passe la main au candidat suivant.
    testWidgets('config inconnue (ZZ) → passe la main à la locale (fr_TG)',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'ZZ')),
        locale: const Locale('fr', 'TG'),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_dialCode(t), '+228');
    });

    // `es_419` (Amérique latine) est une locale RÉELLE dont le « pays » est une
    // macro-région ONU, inconnue de tout catalogue ISO 3166-1.
    testWidgets('locale de macro-région (es_419) → ignorée, appareil retenu',
        (t) async {
      _deviceLocales(t, const <Locale>[Locale('fr', 'TG')]);
      await t.pumpWidget(
          _app(_ctrl(), _field(), locale: const Locale('es', '419')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_dialCode(t), '+228');
    });

    testWidgets('code pays malformé dans la locale → aucune exception',
        (t) async {
      for (final bad in const <String>['zz', '1', 'XXXXX', '']) {
        _deviceLocales(t, const <Locale>[Locale('fr')]);
        await t.pumpWidget(
            _app(_ctrl(), _field(), locale: Locale('fr', bad)));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull, reason: 'countryCode=$bad');
        expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
        await t.pumpWidget(const SizedBox());
      }
    });
  });

  group('🔴 Invariant de la valeur persistée — jamais réécrite', () {
    // Le risque principal de ce lot : déplacer le pays d'amorçage change le
    // pays servant à ré-amorcer l'affichage d'une valeur non canonique. La
    // valeur de tranche, elle, ne doit PAS bouger au montage.
    testWidgets('valeur non canonique + locale porteuse → tranche INCHANGÉE',
        (t) async {
      for (final stored in const <String>[
        '+000', // aucun pays déductible
        '+9', // aucun pays déductible
        '+228901', // TG, partiel
        '+3361', // FR, partiel
        '+33612345678', // FR, valide
      ]) {
        final c = _ctrl(value: stored);
        await t.pumpWidget(
            _app(c, _field(), locale: const Locale('fr', 'FR')));
        await t.pumpAndSettle();
        expect(c.valueOf('f'), stored,
            reason: 'le montage a réécrit la valeur $stored');
        expect(c.valueOf('f'), matches(RegExp(r'^\+[0-9]+$')));
        await t.pumpWidget(const SizedBox());
      }
    });

    // Un changement de locale APRÈS le montage ne redéplace ni le pays ni la
    // valeur : la chaîne n'est parcourue qu'une fois (drapeau `_bootstrapped`).
    testWidgets('changement de locale après montage → pays ET valeur figés',
        (t) async {
      final c = _ctrl();
      await t.pumpWidget(
          _app(c, _field(), locale: const Locale('fr', 'TG')));
      await t.pumpAndSettle();
      await t.enterText(_number, '90123456');
      await t.pumpAndSettle();
      expect(c.valueOf('f'), '+22890123456');
      expect(_dialCode(t), '+228');

      await t.pumpWidget(
          _app(c, _field(), locale: const Locale('fr', 'FR')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+228', reason: 'le pays a été redéplacé');
      expect(c.valueOf('f'), '+22890123456',
          reason: 'la valeur a été réécrite par le changement de locale');
    });

    // 🔴 Garde ISOLANTE du drapeau `_bootstrapped`. Mesuré pendant la campagne
    // R3 : sur un champ DÉJÀ RENSEIGNÉ, rejouer l'amorçage ne change rien —
    // l'étape 1 (le pays de la valeur) redonne le même pays. Les deux gardes
    // ci-dessus sont donc protégées par un AUTRE mécanisme et ne prouvent PAS
    // que l'amorçage n'a lieu qu'une fois (injection « amorçage rejoué » :
    // VERTE). Sur un champ VIDE, en revanche, seul le drapeau empêche le pays
    // de changer sous les yeux de l'utilisateur — c'est cette garde-là qui mord.
    testWidgets('champ VIDE : changement de locale après montage → pays figé',
        (t) async {
      final c = _ctrl();
      await t.pumpWidget(_app(c, _field(), locale: const Locale('fr', 'TG')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+228');

      await t.pumpWidget(_app(c, _field(), locale: const Locale('fr', 'FR')));
      await t.pumpAndSettle();
      expect(_dialCode(t), '+228',
          reason: 'le pays a bougé sous l\'utilisateur après le montage');
      expect(c.valueOf('f'), isNull);
    });

    // `didChangeDependencies` est rappelé pour bien d'autres raisons que la
    // locale (thème, média, texte). L'amorçage ne doit pas y rejouer : il
    // réinitialiserait la saisie en cours (AD-2, objectif produit n°1).
    testWidgets('didChangeDependencies rejoué (thème) → saisie non réinitialisée',
        (t) async {
      final c = _ctrl();
      await t.pumpWidget(_app(c, _field(),
          locale: const Locale('fr', 'TG'), theme: ThemeData.light()));
      await t.pumpAndSettle();
      await t.enterText(_number, '90123456');
      await t.pumpAndSettle();
      await t.pumpWidget(_app(c, _field(),
          locale: const Locale('fr', 'TG'), theme: ThemeData.dark()));
      await t.pumpAndSettle();
      expect(_text(t), isNotEmpty, reason: 'la saisie a été effacée');
      expect(c.valueOf('f'), '+22890123456');
    });
  });

  group('FR-26 — aucun code pays en dur dans la résolution', () {
    // Preuve NÉGATIVE : la chaîne ne contient AUCUN littéral ISO/indicatif.
    // (Le champ est déjà couvert par la garde de `z_phone_native_render_test`
    // pour `TG`/`+228` ; celle-ci élargit à tout littéral de pays plausible.)
    test('le champ ne contient aucun indicatif littéral', () {
      final src = _readPackageFile(
          'lib/src/presentation/z_phone_field_widget.dart');
      // 🔴 P0D2 : stripComments (scanner caractère par caractère, // avant /*)
      // remplace l'ancien filtre par préfixe de ligne — celui-ci ne retirait ni
      // les commentaires de bloc ni un `//` en fin de ligne de code.
      final code = stripComments(src);
      expect(RegExp(r"""'\+[0-9]{1,4}'""").hasMatch(code), isFalse,
          reason: 'indicatif codé en dur dans la résolution du pays');
      expect(RegExp(r"""'[A-Z]{2}'""").hasMatch(code), isFalse,
          reason: 'code pays ISO codé en dur dans la résolution du pays');
    });
  });
}

String _readPackageFile(String relative) {
  final file = File(relative);
  expect(file.existsSync(), isTrue,
      reason: '$relative introuvable depuis ${Directory.current.path} — '
          'lancer `flutter test` DEPUIS le dossier du paquet');
  return file.readAsStringSync();
}
