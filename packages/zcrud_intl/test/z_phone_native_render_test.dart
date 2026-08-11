// CR-DODLP-PHONE-NATIF (2026-08-10) — le RENDU du champ `phoneNumber` provient
// du paquet `intl_phone_number_input`, absorbé par `zcrud_intl` (AD-1/AD-7), et
// la valeur de tranche devient une `String` internationale.
//
// Ces gardes couvrent ce que l'adoption d'un TIERS met en jeu :
//   - le CONTRAT de la chaîne exposée (invariant `^\+[0-9]+$`, E.164 si valide) ;
//   - les trois chemins du paquet MESURÉS crashants (AD-10) — chacun avec son
//     repli défini ;
//   - la stabilité de la graine d'amorçage (AD-2 : taper ne réinitialise pas) ;
//   - le pays par défaut PARAMÉTRABLE (aucun code pays en dur, AD-12) ;
//   - la cible tactile portée par la CONTRAINTE LIANTE (AD-13), jamais par une
//     taille rendue constatée après coup.
//
// Import INTERNE du pont : le confinement AD-1 vaut aussi pour les tests — une
// garde de `zcrud_intl` ne doit jamais importer `intl_phone_number_input`.
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/src/presentation/z_intl_phone_input_bridge.dart';
import 'package:zcrud_intl/src/presentation/z_phone_codec.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

import 'support/z_sources.dart' show stripComments;

ZFieldSpec _field({ZFieldConfig? config, bool readOnly = false}) => ZFieldSpec(
      name: 'f',
      type: EditionFieldType.phoneNumber,
      label: 'Téléphone',
      config: config,
      readOnly: readOnly,
    );

ZFormController _ctrl({Object? value}) => ZFormController(
      initialValues: <String, Object?>{'f': value},
      visibleFields: <String>['f'],
    );

/// Délégués PERMISSIFS (`isSupported => true`) : ils acceptent n'importe quelle
/// locale sans ajouter `flutter_localizations` en `dev_dependency` (le paquet
/// n'en dépend pas et ne doit pas se mettre à en dépendre). Patron repris tel
/// quel de `z_phone_default_country_test.dart`, où il est déjà éprouvé.
class _AnyLocaleMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterialDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);
  @override
  bool shouldReload(_AnyLocaleMaterialDelegate old) => false;
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
  bool shouldReload(_AnyLocaleCupertinoDelegate old) => false;
}

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  Locale? locale,
  VoidCallback? onInit,
}) =>
    MaterialApp(
      locale: locale,
      // 🔴 CORRECTION DE GARDE VACANTE (2026-08-10). Sans `supportedLocales`,
      // `MaterialApp` n'en déclare qu'une (`en_US`) et RÉSOUT toute locale
      // demandée vers elle : `Locale('qq')` — et même `Locale('fr','FR')` —
      // n'atteignait JAMAIS le champ. Mesuré, sonde supprimée :
      //   déclarées=[en_US] · demandée=qq    ⇒ résolue **en_US**
      //   déclarées=[en_US] · demandée=fr_FR ⇒ résolue **en_US**
      //   déclarées=[locale] · demandée=qq    ⇒ résolue **qq**
      //   déclarées=[locale] · demandée=fr_FR ⇒ résolue **fr_FR**
      // `locale == null` (tous les autres tests de ce fichier) ⇒ chemin
      // strictement INCHANGÉ.
      supportedLocales:
          locale == null ? const <Locale>[Locale('en', 'US')] : <Locale>[locale],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        _AnyLocaleMaterialDelegate(),
        _AnyLocaleCupertinoDelegate(),
      ],
      home: ZcrudScope(
        widgetRegistry: ZWidgetRegistry()
          ..register('phoneNumber', ZPhoneFieldWidget.builder(onInit: onInit)),
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

void main() {
  group('Confinement — le catalogue du paquet reste lisible (tripwire)', () {
    // Le pont lit `Countries.countryList` par un import d'IMPLÉMENTATION,
    // délibéré et épinglé (^0.7.5) : sans lui, impossible d'assainir la
    // restriction `countries:` — et le `RangeError` mesuré passerait en prod.
    // Cette garde rougit si le paquet déplace/renomme ce catalogue, AU LIEU de
    // laisser le repli silencieux « tous les pays » masquer la régression.
    test('supportedIsoCodes est peuplé et contient TG/FR', () {
      final iso = ZIntlPhoneInputBridge.supportedIsoCodes;
      expect(iso, isNotEmpty);
      expect(iso.length, greaterThan(200));
      expect(iso, containsAll(<String>['TG', 'FR', 'NE']));
    });
  });

  group('AD-10 — assainissement des entrées confiées au tiers', () {
    test('sanitizeCountries : normalise, déduplique, conserve l\'ordre', () {
      expect(ZIntlPhoneInputBridge.sanitizeCountries(const <String>['tg', ' FR ', 'tg']),
          <String>['TG', 'FR']);
    });

    // Repli MESURÉ : `countries: ['XX']` fait lever un RangeError au paquet
    // (`countries[0]` sur une liste filtrée vide). On retombe sur `null`
    // = tous les pays, qui est le chemin sûr.
    test('sanitizeCountries : ISO tous inconnus → null (= tous les pays)', () {
      expect(ZIntlPhoneInputBridge.sanitizeCountries(const <String>['XX', 'ZZ']),
          isNull);
      expect(ZIntlPhoneInputBridge.sanitizeCountries(const <String>[]), isNull);
    });

    test('sanitizeIso : inconnu → null, connu → majuscules', () {
      expect(ZIntlPhoneInputBridge.sanitizeIso('tg'), 'TG');
      expect(ZIntlPhoneInputBridge.sanitizeIso('ZZ'), isNull);
      expect(ZIntlPhoneInputBridge.sanitizeIso(null), isNull);
      expect(ZIntlPhoneInputBridge.sanitizeIso(''), isNull);
    });
  });

  group('Contrat de la valeur exposée — forme internationale, jamais ambiguë', () {
    final invariant = matches(RegExp(r'^\+[0-9]+$'));

    test('numéro valide → E.164 canonique', () {
      final v = ZPhoneCodec.toInternationalString('+22890123456',
          dialCode: '+228', iso: 'TG');
      expect(v, '+22890123456');
      expect(v, invariant);
    });

    // MESURÉ sur le paquet : une saisie partielle rend `dialCode + saisie`,
    // donc `'+228901'`. On le conserve — c'est interprétable — mais on garantit
    // l'invariant de forme.
    test('numéro partiel → même forme internationale, incomplète', () {
      final v = ZPhoneCodec.toInternationalString('+228901',
          dialCode: '+228', iso: 'TG');
      expect(v, '+228901');
      expect(v, invariant);
    });

    // MESURÉ : pour une saisie `'+++++'` le paquet rend littéralement
    // `'+228+++++'`. Persister cela donnerait une donnée ininterprétable.
    test('saisie absurde → aucun chiffre → null (jamais "+228+++++")', () {
      expect(
          ZPhoneCodec.toInternationalString('+228+++++',
              dialCode: '+228', iso: 'TG'),
          isNull);
    });

    test('indicatif indéterminable → null (jamais de national nu)', () {
      expect(ZPhoneCodec.toInternationalString('90123456'), isNull);
    });

    test('chiffres surnuméraires → forme internationale conservée, pas de throw',
        () {
      final v = ZPhoneCodec.toInternationalString('+228000000000000000',
          dialCode: '+228', iso: 'TG');
      expect(v, invariant);
    });

    // 🔴 CETTE GARDE MANQUAIT (ajoutée après une campagne R3 : l'injection
    // « désactiver la normalisation `phone_numbers_parser` » laissait TOUT vert,
    // preuve qu'aucune garde ne mesurait ce que le moteur apporte).
    //
    // Ce qu'il apporte, mesuré : une saisie NATIONALE à préfixe interurbain
    // (`0` en France, au Japon…) ne peut PAS être concaténée telle quelle après
    // l'indicatif — `'+33' + '0612345678'` donnerait `'+330612345678'`, un
    // numéro FAUX. `phone_numbers_parser` retire le préfixe et rend l'E.164
    // canonique. C'est la raison pour laquelle les DEUX moteurs restent en
    // service : le paquet natif rend l'UI, `phone_numbers_parser` décide de la
    // VALEUR.
    test('préfixe interurbain national → E.164 canonique (le moteur SERT)', () {
      expect(
          ZPhoneCodec.toInternationalString('0612345678',
              dialCode: '+33', iso: 'FR'),
          '+33612345678');
      expect(
          ZPhoneCodec.toInternationalString('09012345678',
              dialCode: '+81', iso: 'JP'),
          '+819012345678');
      // Sans normalisation, la concaténation nue produirait ceci — la garde
      // rougit donc si le moteur est débranché.
      expect(
          ZPhoneCodec.toInternationalString('0612345678',
              dialCode: '+33', iso: 'FR'),
          isNot('+330612345678'));
    });

    // 🔴 CAS DÉCOUVERT EN RELECTURE, pas par une garde existante : le paquet
    // rend l'E.164 RÉEL du numéro saisi, qui peut appartenir à un AUTRE pays
    // que celui du sélecteur. Re-préfixer par l'indicatif sélectionné donnerait
    // `'+22833612345678'` — un numéro inexistant, persisté sans que rien ne
    // signale l'erreur.
    test('numéro international d\'un AUTRE pays → son propre indicatif conservé',
        () {
      expect(
          ZPhoneCodec.toInternationalString('+33612345678',
              dialCode: '+228', iso: 'TG'),
          '+33612345678');
      expect(
          ZPhoneCodec.toInternationalString('+33612345678',
              dialCode: '+228', iso: 'TG'),
          isNot(startsWith('+228')));
    });

    test('lecture inverse : national et ISO déduits sans throw', () {
      expect(ZPhoneCodec.nationalDigitsOf('+33612345678', iso: 'FR'), '612345678');
      expect(ZPhoneCodec.isoOfInternational('+33612345678'), 'FR');
      expect(ZPhoneCodec.isoOfInternational('garbage'), isNull);
      expect(ZPhoneCodec.nationalDigitsOf(null), '');
      expect(ZPhoneCodec.isValidInternational('+228901', iso: 'TG'), isFalse);
      expect(ZPhoneCodec.isValidInternational('+22890123456', iso: 'TG'), isTrue);
    });
  });

  group('AD-10 — le champ ne lève JAMAIS sur une entrée hostile', () {
    // Cas 1 mesuré : un `initialValue` porteur d'un numéro SANS code pays fait
    // lever un `_TypeError` DANS `initState` du paquet. Le champ n'y expose
    // donc jamais un numéro sans pays résolu.
    testWidgets('valeur persistée non valide → pré-remplie, aucune exception',
        (t) async {
      await t.pumpWidget(_app(_ctrl(value: '+228901'), _field()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_text(t), '901');
    });

    testWidgets('valeur de tranche absurde (String) → aucune exception',
        (t) async {
      await t.pumpWidget(_app(_ctrl(value: 'garbage!!'), _field()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
    });

    testWidgets('valeur de tranche d\'un type inattendu → aucune exception',
        (t) async {
      await t.pumpWidget(_app(_ctrl(value: 42), _field()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_text(t), isEmpty);
    });

    // Cas 2 mesuré : `countries: ['XX']` fait lever un `RangeError`.
    testWidgets('allowedCountryIsos tous inconnus → aucune exception',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(allowedCountryIsos: <String>['XX'])),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
    });

    testWidgets('pays par défaut inconnu → aucune exception', (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'ZZ')),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    // 🔴 Garde RÉPARÉE (2026-08-10). Elle était VACANTE : le harnais ne
    // déclarait aucune `supportedLocales`, donc `Locale('qq')` se résolvait en
    // `en_US` et n'atteignait jamais le champ — elle re-testait le cas par
    // défaut, déjà couvert juste au-dessus, et n'assertait RIEN sur les noms
    // que son titre annonce. Elle mesure désormais les deux choses :
    //   (a) la locale demandée atteint bien le champ ;
    //   (b) le paquet natif retombe sur `country.name` (repli) faute de
    //       traduction — et c'est la garde JUMELLE `fr_FR` ci-dessous qui rend
    //       ce constat discriminant (sans elle, « Albania » serait vert même
    //       si la locale était ignorée).
    testWidgets('locale inconnue (qq) → noms de pays en REPLI, aucune exception',
        (t) async {
      await t.pumpWidget(_app(_ctrl(), _field(), locale: const Locale('qq')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.byType(ZPhoneFieldWidget), findsOneWidget);
      // La locale demandée atteint réellement le champ (c'était le trou).
      expect(
        Localizations.maybeLocaleOf(t.element(find.byType(ZPhoneFieldWidget))),
        const Locale('qq'),
        reason: 'sans supportedLocales déclarées, la locale se résolvait en '
            'en_US et la garde ne testait rien',
      );
      await _openCountryDialog(t);
      expect(find.text('Albania'), findsOneWidget,
          reason: 'repli mesuré = `country.name` du catalogue natif');
      expect(find.text('Albanie'), findsNothing);
    });

    testWidgets('locale connue (fr_FR) → noms de pays TRADUITS '
        '(jumelle discriminante de la garde ci-dessus)', (t) async {
      await t.pumpWidget(
          _app(_ctrl(), _field(), locale: const Locale('fr', 'FR')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _openCountryDialog(t);
      expect(find.text('Albanie'), findsOneWidget,
          reason: 'le champ transmet la LANGUE de la locale ambiante au '
              'paquet natif (FR-26 : donnée de locale, jamais un littéral)');
      expect(find.text('Albania'), findsNothing);
    });

    testWidgets('saisie absurde → tranche NON écrite avec une valeur ambiguë',
        (t) async {
      final c = _ctrl();
      await t.pumpWidget(_app(c, _field()));
      await t.pumpAndSettle();
      await t.enterText(_number, '+++++');
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(c.valueOf('f'), isNull);
    });

    // Ingestion sans réécriture : une valeur legacy `ZPhoneNumber` (contrat
    // d'avant la CR) reste lisible et se ré-émet en `String`.
    testWidgets('valeur legacy ZPhoneNumber → ingérée puis ré-émise en String',
        (t) async {
      final c = _ctrl(
          value: const ZPhoneNumber(
              e164: '+33612345678',
              isoCode: 'FR',
              dialCode: '+33',
              nationalNumber: '612345678'));
      await t.pumpWidget(_app(c, _field()));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(_text(t), isNotEmpty);
      await t.enterText(_number, '612345679');
      await t.pumpAndSettle();
      expect(c.valueOf('f'), isA<String>());
      expect(c.valueOf('f'), '+33612345679');
    });
  });

  group('AD-12/FR-26 — pays par défaut PARAMÉTRABLE, jamais codé en dur', () {
    testWidgets('defaultCountryIso: TG → indicatif +228 affiché', (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'TG')),
      ));
      await t.pumpAndSettle();
      expect(find.text('+228'), findsWidgets);
    });

    testWidgets('defaultCountryIso: NE → indicatif +227 (rien n\'est figé)',
        (t) async {
      await t.pumpWidget(_app(
        _ctrl(),
        _field(config: const ZIntlFieldConfig(defaultCountryIso: 'NE')),
      ));
      await t.pumpAndSettle();
      expect(find.text('+227'), findsWidgets);
      expect(find.text('+228'), findsNothing);
    });

    // Preuve NÉGATIVE que le défaut vient bien de la config et non du code :
    // aucun code/indicatif du Togo n'est écrit dans `lib/`.
    test('aucun indicatif ni code pays en dur dans le champ téléphone', () {
      for (final path in const <String>[
        'lib/src/presentation/z_phone_field_widget.dart',
        'lib/src/presentation/z_intl_phone_input_bridge.dart',
      ]) {
        final src = _stripComments(_readPackageFile(path));
        expect(src.contains('+228'), isFalse, reason: '$path : indicatif en dur');
        expect(RegExp(r"'TG'").hasMatch(src), isFalse,
            reason: '$path : code pays en dur');
      }
    });
  });

  group('AD-2/SM-1 — la frappe ne reconstruit ni ne réinitialise le champ', () {
    // Le paquet compare `initialValue.hash`, un ENTIER ALÉATOIRE tiré à la
    // construction : reconstruire la graine à chaque `build` relancerait son
    // `initialiseWidget()` — qui RÉÉCRIT le contrôleur — à chaque frappe.
    // Cette garde mord précisément là-dessus.
    testWidgets('frappes successives → texte conservé, initState une seule fois',
        (t) async {
      var inits = 0;
      final c = _ctrl();
      await t.pumpWidget(_app(c, _field(), onInit: () => inits++));
      await t.pumpAndSettle();
      await t.enterText(_number, '9');
      await t.pumpAndSettle();
      await t.enterText(_number, '90');
      await t.pumpAndSettle();
      await t.enterText(_number, '901');
      await t.pumpAndSettle();
      expect(inits, 1);
      expect(_text(t).replaceAll(RegExp(r'[^0-9]'), ''), '901');
    });

    testWidgets('écriture de tranche UNIQUE par frappe (voie unique)', (t) async {
      final writes = <Object?>[];
      final c = ZFormController(
        initialValues: const <String, Object?>{'f': null},
        visibleFields: const <String>['f'],
      );
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<Object?>(
            valueListenable: c.fieldListenable('f'),
            builder: (context, value, _) => ZPhoneFieldWidget(
              ctx: ZFieldWidgetContext(
                field: _field(config: const ZIntlFieldConfig(defaultCountryIso: 'TG')),
                value: value,
                onChanged: (v) {
                  writes.add(v);
                  c.setValue('f', v);
                },
              ),
              catalog: sharedDefaultCountryCatalog(),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      await t.enterText(_number, '90123456');
      await t.pumpAndSettle();
      expect(writes, <Object?>['+22890123456']);
    });
  });

  group('AD-13 — cible tactile sur la CONTRAINTE LIANTE', () {
    testWidgets('le champ est contraint à minHeight >= 48 dp', (t) async {
      await t.pumpWidget(_app(_ctrl(), _field()));
      await t.pumpAndSettle();
      // On lit la CONTRAINTE imposée, pas la taille rendue : une taille
      // constatée peut dépasser 48 pour des raisons sans rapport (erreur
      // affichée, densité), et ne prouverait donc pas la règle.
      final box = t.widget<ConstrainedBox>(
        find.ancestor(of: _number, matching: find.byType(ConstrainedBox)).last,
      );
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48.0));
    });

    testWidgets('le libellé du champ reste annoncé (Semantics conteneur)',
        (t) async {
      final handle = t.ensureSemantics();
      await t.pumpWidget(_app(_ctrl(), _field()));
      await t.pumpAndSettle();
      final node = t.getSemantics(find.byType(ZPhoneFieldWidget));
      expect(node.label, contains('Téléphone'));
      handle.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Lecture de source cwd-robuste (même convention que `isolation_gates_test`).
// ---------------------------------------------------------------------------

String _readPackageFile(String packageRelative) {
  for (final c in <String>[
    packageRelative,
    'packages/zcrud_intl/$packageRelative',
    '../../packages/zcrud_intl/$packageRelative',
  ]) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour la garde : $packageRelative');
}

/// 🔴 P0D2 : déléguée à `support/z_sources.dart` (l'ancienne regex bloc
/// locale pouvait avaler tout le fichier sur une citation de chemin du type
/// `packages/*/lib`, laissant la garde silencieusement vacuelle).
String _stripComments(String src) => stripComments(src);

/// Ouvre le dialogue de sélection de pays du paquet natif (le bouton sélecteur
/// est posé en `prefixIcon` du champ). Les noms de pays n'apparaissent QUE là :
/// le déclencheur ne montre que drapeau + indicatif.
Future<void> _openCountryDialog(WidgetTester t) async {
  await t.tap(find.descendant(of: _number, matching: find.byType(InkWell)).first,
      warnIfMissed: false);
  await t.pumpAndSettle();
}
