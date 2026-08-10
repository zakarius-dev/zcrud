// CR-DODLP-INTL-DECORATION (2026-08-10) — les champs `phoneNumber` / `country`
// / `address` de `zcrud_intl` passent par la décoration THÉMÉE du cœur
// (`zFieldDecoration` → `ZcrudTheme.inputDecoration`), au lieu d'une
// `InputDecoration` nue.
//
// Ces gardes couvrent les quatre demandes de la CR :
//   1. jetons EXISTANTS honorés (`fieldFillColor`, `fieldBorderColor`,
//      `fieldFocusedBorderColor`, `inputRadius`) — aucun jeton nouveau ;
//   2. UN SEUL libellé (le doublon mesuré annonçait « Téléphone / Téléphone /
//      Numéro » sur un seul nœud sémantique) ;
//   3. mode `bare` (`fieldSize == large`) honoré, à PARITÉ mesurée avec le
//      champ `text` du cœur ;
//   4. AD-10 : sans thème, repli `ColorScheme` et aucune exception.
// + AD-13 : la cible tactile est lue sur la CONTRAINTE LIANTE, jamais sur
//   `getSize()`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_intl/zcrud_intl.dart';

const Color _fill = Color(0xFF102030);
const Color _border = Color(0xFF405060);
const Color _focus = Color(0xFF708090);
const Radius _radius = Radius.circular(21);

ZCountryCatalog _catalog() => ZCountryCatalog.fromList(const <ZCountryInfo>[
      ZCountryInfo(isoCode: 'NE', name: 'Niger', dialCode: '+227', flagEmoji: '🇳🇪'),
      ZCountryInfo(isoCode: 'FR', name: 'France', dialCode: '+33', flagEmoji: '🇫🇷'),
    ]);

ZWidgetRegistry _registry() {
  final cat = _catalog();
  return ZWidgetRegistry()
    ..register('phoneNumber', ZPhoneFieldWidget.builder(catalog: cat))
    ..register('country', ZCountryFieldWidget.builder(catalog: cat))
    ..register('address', ZAddressFieldWidget.builder(catalog: cat));
}

/// Thème de test : uniquement des jetons **déjà existants** (v0.60.0).
const ZcrudTheme _tokens = ZcrudTheme(
  fieldFillColor: _fill,
  fieldBorderColor: _border,
  fieldFocusedBorderColor: _focus,
  inputRadius: _radius,
);

Future<ZFormController> _pump(
  WidgetTester tester,
  EditionFieldType type, {
  ZFieldSize size = ZFieldSize.normal,
  Object? value,
  ZcrudTheme? theme = _tokens,
  String label = 'Téléphone',
  bool required = false,
}) async {
  final controller = ZFormController(
    initialValues: <String, Object?>{'f': value},
    visibleFields: const <String>['f'],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: ZcrudScope(
      theme: theme,
      widgetRegistry: _registry(),
      child: Scaffold(
        body: DynamicEdition(
          controller: controller,
          fields: <ZFieldSpec>[
            ZFieldSpec(
              name: 'f',
              type: type,
              label: label,
              fieldSize: size,
              validators: required
                  ? const <ZValidatorSpec>[
                      ZValidatorSpec.required()
                    ]
                  : const <ZValidatorSpec>[],
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

/// Décoration EFFECTIVEMENT rendue par le champ téléphone : celle du `TextField`
/// monté par le paquet natif (le paquet la reprend telle quelle, en n'y
/// substituant que le `prefixIcon` drapeau/indicatif).
InputDecoration _phoneDecoration(WidgetTester tester) => tester
    .widget<TextField>(find.descendant(
      of: find.byKey(const Key('z-phone-number')),
      matching: find.byType(TextField),
    ))
    .decoration!;

InputDecoration _triggerDecoration(WidgetTester tester, Key key) => tester
    .widget<InputDecorator>(find.descendant(
      of: find.byKey(key),
      matching: find.byType(InputDecorator),
    ))
    .decoration;

InputDecoration _lineDecoration(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).decoration!;

Color _restBorderColor(InputDecoration d) =>
    (d.enabledBorder! as OutlineInputBorder).borderSide.color;

BorderRadius _borderRadius(InputDecoration d) =>
    (d.enabledBorder! as OutlineInputBorder).borderRadius;

/// 🔴 AD-13 : cible tactile lue sur la contrainte **LIANTE** posée par NOTRE
/// widget — jamais sur `getSize()`, et jamais sur le maximum des
/// `ConstrainedBox` descendants.
///
/// Motif daté (2026-08-10, campagne R3) : la première version prenait le max
/// des descendants ; l'injection « `minHeight: 48` → `24` » est restée VERTE
/// parce que le **bouton sélecteur du paquet tiers** pose son propre 48×48. La
/// garde mesurait donc le plancher du TIERS. Elle vise désormais la contrainte
/// nommée, qui est la nôtre et rien d'autre.
double _bindingMinHeight(WidgetTester tester, Key key) =>
    tester.widget<ConstrainedBox>(find.byKey(key)).constraints.minHeight;

void main() {
  group('CR-INTL-DECO-1 · jetons EXISTANTS honorés (aucun jeton nouveau)', () {
    testWidgets('téléphone : fill / bordure / rayon viennent du thème',
        (tester) async {
      await _pump(tester, EditionFieldType.phoneNumber);
      final d = _phoneDecoration(tester);
      expect(d.filled, isTrue, reason: 'le champ doit être REMPLI (inputFilled)');
      expect(d.fillColor, _fill, reason: 'fieldFillColor doit atteindre le tél.');
      expect(_restBorderColor(d), _border, reason: 'fieldBorderColor au repos');
      expect(
        (d.focusedBorder! as OutlineInputBorder).borderSide.color,
        _focus,
        reason: 'fieldFocusedBorderColor sur le focus',
      );
      expect(_borderRadius(d), const BorderRadius.all(_radius),
          reason: 'inputRadius doit piloter le rayon');
    });

    testWidgets('pays : le déclencheur est un InputDecorator thémé',
        (tester) async {
      await _pump(tester, EditionFieldType.country, value: 'FR');
      final d =
          _triggerDecoration(tester, const Key('z-country-picker-trigger'));
      expect(d.fillColor, _fill);
      expect(_restBorderColor(d), _border);
      expect(_borderRadius(d), const BorderRadius.all(_radius));
      // Le chevron d'affordance reste posé, mais DANS le cadre.
      expect(d.suffixIcon, isA<Icon>());
    });

    testWidgets('adresse : chaque sous-champ porte la décoration thémée',
        (tester) async {
      await _pump(tester, EditionFieldType.address);
      for (final key in const <Key>[
        Key('z-address-line1'),
        Key('z-address-line2'),
        Key('z-address-city'),
        Key('z-address-region'),
        Key('z-address-postal'),
      ]) {
        final d = _lineDecoration(tester, key);
        expect(d.fillColor, _fill, reason: 'fill manquant sur $key');
        expect(_restBorderColor(d), _border, reason: 'bordure manquante sur $key');
        expect(_borderRadius(d), const BorderRadius.all(_radius),
            reason: 'rayon manquant sur $key');
      }
      // Le sélecteur pays du GROUPE aussi.
      final country =
          _triggerDecoration(tester, const Key('z-country-picker-trigger'));
      expect(country.fillColor, _fill);
      expect(_restBorderColor(country), _border);
    });
  });

  group('CR-INTL-DECO-2 · UN SEUL libellé', () {
    testWidgets('téléphone : le nœud annonce le libellé UNE fois, et rien de plus',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, EditionFieldType.phoneNumber);
      final node = tester.getSemantics(find.byKey(const Key('z-phone-number')));
      // 🔴 Égalité STRICTE : le doublon mesuré valait
      // « Téléphone\nTéléphone\nNuméro » — un `contains` l'aurait laissé passer.
      expect(node.label, 'Téléphone');
      // Le libellé interne « Numéro » a disparu (il n'était ni le libellé du
      // champ, ni un placeholder déclaré par l'hôte).
      expect(find.text('Numéro'), findsNothing);
      // …et il n'est rendu qu'une fois à l'écran (libellé flottant).
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('téléphone : le libellé flottant est le ZFieldLabel du cœur '
        '(astérisque requis inclus)', (tester) async {
      await _pump(tester, EditionFieldType.phoneNumber, required: true);
      final d = _phoneDecoration(tester);
      expect(d.label, isA<ZFieldLabel>());
      expect(d.labelText, isNull,
          reason: 'label (Widget) et labelText sont mutuellement exclusifs');
      expect(find.text(' *'), findsOneWidget,
          reason: 'astérisque « requis » du cœur, décoratif');
    });

    testWidgets('pays : le nœud annonce le libellé UNE fois', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, EditionFieldType.country, value: 'FR');
      final node =
          tester.getSemantics(find.byKey(const Key('z-country-picker-trigger')));
      expect(node.label, 'Téléphone');
      expect(node.value, 'France');
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('adresse : le libellé du GROUPE est rendu UNE fois et annoncé '
        'UNE fois', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, EditionFieldType.address);
      expect(find.text('Téléphone'), findsOneWidget);
      final node = tester.getSemantics(find.byType(ZAddressFieldWidget));
      expect(node.label, 'Téléphone');
      handle.dispose();
    });
  });

  group('CR-INTL-DECO-3 · mode `bare` (fieldSize.large) — parité cœur mesurée',
      () {
    testWidgets('téléphone : bordures none, aucun libellé propre, libellé '
        'rendu une seule fois (par la Card)', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, EditionFieldType.phoneNumber,
          size: ZFieldSize.large);
      final d = _phoneDecoration(tester);
      expect(d.border, InputBorder.none);
      expect(d.enabledBorder, InputBorder.none);
      expect(d.focusedBorder, InputBorder.none);
      expect(d.filled, isFalse);
      expect(d.label, isNull);
      expect(d.labelText, isNull);
      // Parité mesurée avec le champ `text` du cœur en `large` : le nœud du
      // champ ne porte AUCUN libellé, la Card ancêtre le porte.
      final node = tester.getSemantics(find.byKey(const Key('z-phone-number')));
      expect(node.label, isEmpty);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('pays : bordures none et libellé porté par la Card',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, EditionFieldType.country,
          size: ZFieldSize.large, value: 'FR');
      final d =
          _triggerDecoration(tester, const Key('z-country-picker-trigger'));
      expect(d.border, InputBorder.none);
      expect(d.filled, isFalse);
      expect(d.label, isNull);
      expect(d.labelText, isNull);
      final node =
          tester.getSemantics(find.byKey(const Key('z-country-picker-trigger')));
      expect(node.label, isEmpty,
          reason: 'sinon la Card ET le déclencheur annoncent le libellé');
      // 🔴 En `bare` la Card n'affiche rien d'autre : la VALEUR doit rester
      // visible dans le corps (règle reprise de ZDecoratedFieldTrigger).
      expect(find.text('France'), findsOneWidget);
      expect(find.text('Téléphone'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('adresse : en-tête retiré, sous-champs TOUJOURS décorés',
        (tester) async {
      await _pump(tester, EditionFieldType.address, size: ZFieldSize.large);
      // Le libellé du groupe n'est rendu QUE par la Card.
      expect(find.text('Téléphone'), findsOneWidget);
      // 🔴 Les sous-champs ne sont JAMAIS `bare` : leur libellé n'est porté par
      // personne d'autre.
      final d = _lineDecoration(tester, const Key('z-address-city'));
      expect(d.enabledBorder, isA<OutlineInputBorder>());
      expect(d.fillColor, _fill);
      expect(find.text('Ville'), findsOneWidget);
    });
  });

  group('CR-INTL-DECO-4 · AD-10 — sans thème, repli ColorScheme, aucun throw',
      () {
    testWidgets('les 3 champs se montent sans ZcrudTheme et retombent sur '
        'ColorScheme', (tester) async {
      for (final type in const <EditionFieldType>[
        EditionFieldType.phoneNumber,
        EditionFieldType.country,
        EditionFieldType.address,
      ]) {
        await _pump(tester, type, theme: null, value: null);
        expect(tester.takeException(), isNull, reason: 'AD-10 sur $type');
      }
      // Dernier montage : `address`. Bordure = rôle `outline` du ColorScheme.
      final scheme =
          Theme.of(tester.element(find.byType(ZAddressFieldWidget))).colorScheme;
      final d = _lineDecoration(tester, const Key('z-address-city'));
      expect(_restBorderColor(d), scheme.outline);
      expect(d.fillColor, scheme.surfaceContainerHighest);
    });
  });

  group('CR-INTL-DECO-5 · AD-13 — cible tactile LIANTE conservée', () {
    testWidgets('téléphone et pays gardent une contrainte minHeight ≥ 48',
        (tester) async {
      await _pump(tester, EditionFieldType.phoneNumber);
      expect(_bindingMinHeight(tester, const Key('z-phone-tap-target')),
          greaterThanOrEqualTo(48));
      await _pump(tester, EditionFieldType.country, value: 'FR');
      expect(_bindingMinHeight(tester, const Key('z-country-tap-target')),
          greaterThanOrEqualTo(48));
    });
  });

  group('CR-INTL-DECO-6 · FR-26 — plus aucune InputDecoration nue en source',
      () {
    test('les widgets intl ne construisent plus d\'InputDecoration littérale',
        () {
      const files = <String>[
        'lib/src/presentation/z_phone_field_widget.dart',
        'lib/src/presentation/z_country_field_widget.dart',
        'lib/src/presentation/z_address_field_widget.dart',
        'lib/src/presentation/z_country_picker_field.dart',
        'lib/src/presentation/z_option_picker_field.dart',
      ];
      for (final path in files) {
        final source = File('${_packageRoot()}/$path').readAsStringSync();
        // Seules les lignes de CODE comptent (les commentaires citent le motif).
        final offending = <String>[
          for (final line in source.split('\n'))
            if (!line.trimLeft().startsWith('//') &&
                RegExp(r'InputDecoration\s*\(').hasMatch(line))
              line.trim(),
        ];
        expect(offending, isEmpty,
            reason: '$path construit encore une InputDecoration nue : '
                'la décoration doit venir de zFieldDecoration / '
                'ZcrudTheme.inputDecoration');
      }
    });
  });
}

/// Racine du package, ancrée sur le `pubspec.yaml` de `zcrud_intl` (jamais un
/// `../` relatif : `flutter test` s'exécute depuis le dossier du package).
String _packageRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    if (File('${dir.path}/pubspec.yaml').existsSync() &&
        File('${dir.path}/pubspec.yaml')
            .readAsStringSync()
            .contains('name: zcrud_intl')) {
      return dir.path;
    }
    dir = dir.parent;
  }
  throw StateError('racine de zcrud_intl introuvable depuis ${Directory.current}');
}
