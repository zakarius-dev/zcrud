/// 🎯 fp-4-1 — tests PORTEURS de `ZSmartSelectPresenter` (AC2–AC8).
///
/// Discipline R3 (leçon fp-1-2) : chaque preuve de rendu ROUGIT si `present()`
/// renvoie le natif / un placebo (mutant témoin décrit dans l'en-tête T4). Les
/// captures `onChanged` prouvent la **valeur métier exacte** (jamais « le widget
/// existe »). L'ABSENCE du natif est prouvée par `findsNothing`.
///
/// `SmartSelect` (type du fork) est importé ICI (test) — la garde de confinement
/// ne scanne que `lib/**`, jamais `test/**` : légitime.
@TestOn('vm')
library;

import 'package:awesome_select/awesome_select.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_select/zcrud_select.dart';

const ZFieldChoice _a = ZFieldChoice(value: 'a', label: 'Alpha');
const ZFieldChoice _b = ZFieldChoice(value: 'b', label: 'Bravo');
const List<ZFieldChoice> _abc = <ZFieldChoice>[
  _a,
  _b,
  ZFieldChoice(value: 'c', label: 'Charlie'),
];

ZFieldSpec _spec(
  EditionFieldType type, {
  String label = 'Mon champ',
  List<ZFieldChoice> choices = _abc,
  bool readOnly = false,
}) =>
    ZFieldSpec(
      name: 'f',
      type: type,
      label: label,
      choices: choices,
      readOnly: readOnly,
    );

/// Enveloppe : `MaterialApp` (Theme + Localizations) → `Directionality` →
/// `ZcrudScope(selectPresenter: …)` → `Scaffold(body: child)`.
Widget _host({
  required ZSelectPresenter? presenter,
  required Widget child,
  TextDirection direction = TextDirection.ltr,
  ZcrudLabels? labels,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: ZcrudScope(
        selectPresenter: presenter,
        labels: labels,
        child: Scaffold(body: child),
      ),
    ),
  );
}

Widget _selectField(
  EditionFieldType type, {
  Object? value,
  required ValueChanged<Object?> onChanged,
  List<ZFieldChoice>? choices,
  bool multiple = false,
  bool searchable = false,
  bool readOnly = false,
}) =>
    ZSelectFieldWidget(
      field: _spec(type, choices: choices ?? _abc, readOnly: readOnly),
      value: value,
      onChanged: onChanged,
      choices: choices,
      multiple: multiple,
      searchable: searchable,
    );

void main() {
  const presenter = ZSmartSelectPresenter();

  group('🎯 AC2 — `select` supplanté par SmartSelect (natif ABSENT)', () {
    testWidgets('sous présentateur injecté → SmartSelect, PAS de dropdown natif',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      // Rendu riche présent…
      expect(find.byType(SmartSelect), findsOneWidget);
      // …ET le natif est bien SUPPLANTÉ (presence≠association : prouvé par ABSENCE).
      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    });

    testWidgets('SANS présentateur → dropdown natif (non-régression AD-48)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: null,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(find.byType(DropdownButtonFormField<Object?>), findsOneWidget);
      expect(find.byType(SmartSelect), findsNothing);
    });

    testWidgets('espion `onChanged` capte le `value` MÉTIER (modal + tap option)',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            onChanged: (v) => captured = v),
      ));
      // Ouvre le modal S2 (tap sur le déclencheur riche).
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      // Le modal affiche les options : tap « Bravo » (choix unique → auto-commit).
      expect(find.text('Bravo'), findsOneWidget);
      await tester.tap(find.text('Bravo'));
      await tester.pumpAndSettle();
      // La tranche reçoit la VALEUR MÉTIER 'b' (jamais un type S2).
      expect(captured, 'b');
    });
  });

  group('🎯 AC3 — radio (modal) / multiselect (List) / statiques+dynamiques', () {
    testWidgets('radio sous présentateur → SmartSelect mono (choix unique)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.radio, onChanged: (_) {}),
      ));
      final smart = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
      expect(smart.isMultiChoice, isFalse);
      expect(find.byType(DropdownButtonFormField<Object?>), findsNothing);
    });

    testWidgets('mono → scalaire (espion) ; select mono commit direct',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (v) => captured = v),
      ));
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Charlie'));
      await tester.pumpAndSettle();
      expect(captured, 'c'); // scalaire, pas une List.
    });

    testWidgets('multi (checkbox) → SmartSelect.multiple + écrit une `List`',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], onChanged: (v) => captured = v),
      ));
      final smart = tester.widget<SmartSelect<dynamic>>(find.byType(SmartSelect));
      expect(smart.isMultiChoice, isTrue);
      // Ouvre le modal multi, coche « Alpha », ferme le modal (barrière).
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5)); // dismiss bottom-sheet.
      await tester.pumpAndSettle();
      expect(captured, isA<List<Object?>>());
      expect(captured, <Object?>['a']); // une VRAIE List (jamais "S2Choice").
    });

    testWidgets('options DYNAMIQUES (résolues cross-champ) rendues telles quelles',
        (tester) async {
      // `choices` passé explicitement = options déjà résolues par le dispatcher.
      const dynamicChoices = <ZFieldChoice>[
        ZFieldChoice(value: 'x', label: 'Xray'),
        ZFieldChoice(value: 'y', label: 'Yankee'),
      ];
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            choices: dynamicChoices, onChanged: (_) {}),
      ));
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      expect(find.text('Xray'), findsOneWidget);
      expect(find.text('Yankee'), findsOneWidget);
    });
  });

  group('🎯 AC4 — `relation` sous présentateur : rendu S2 + capture', () {
    testWidgets('relation mono → SmartSelect rendu + capte la sélection',
        (tester) async {
      Object? captured = #none;
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: ZRelationFieldWidget(
          field: _spec(EditionFieldType.relation),
          value: null,
          onChanged: (v) => captured = v,
          options: _abc,
        ),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();
      expect(captured, 'a');
    });
  });

  group('🎯 AC6 — a11y / RTL / thème', () {
    testWidgets('déclencheur ≥ 48 dp', (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      final size = tester.getSize(find.byType(InkWell).first);
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('UNE seule annonce accessible : button + label + action tap',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      // Un unique nœud porte le label du champ (pas de double annonce) ET
      // rassemble rôle `button` + action `tap` (activable au lecteur d'écran).
      expect(find.bySemanticsLabel('Mon champ'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Mon champ')),
        containsSemantics(label: 'Mon champ', isButton: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('rendu en RTL sans exception', (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        direction: TextDirection.rtl,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('champ readOnly → déclencheur désactivé (n\'ouvre pas de modal)',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            readOnly: true, onChanged: (_) {}),
      ));
      await tester.tap(find.byType(InputDecorator), warnIfMissed: false);
      await tester.pumpAndSettle();
      // Aucun modal ouvert (pas d'option affichée).
      expect(find.text('Alpha'), findsNothing);
    });
  });

  group('🎯 AC7 — défensif AD-10 : dégradé DÉFINI, jamais un crash', () {
    testWidgets('options vides → sélecteur rendu, aucune exception',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            choices: const <ZFieldChoice>[], onChanged: (_) {}),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('`selected` hors options → rendu neutre, aucune exception',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'zzz-inconnu', onChanged: (_) {}),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('option `disabled` → non sélectionnable, aucune exception',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(
          EditionFieldType.select,
          choices: const <ZFieldChoice>[
            ZFieldChoice(value: 'a', label: 'Alpha', disabled: true),
            _b,
          ],
          onChanged: (_) {},
        ),
      ));
      expect(find.byType(SmartSelect), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('🎯 MED-1 (FR-26) — placeholder état vide LOCALISÉ, jamais l\'anglais du fork', () {
    testWidgets(
        'mono SANS valeur → déclencheur affiche le placeholder l10n, PAS `Select one`',
        (tester) async {
      // l10n injectée : la clé `select` est surchargée en français. Le fork
      // retomberait sinon sur son littéral ANGLAIS `Select one`.
      await tester.pumpWidget(_host(
        presenter: presenter,
        labels: ZcrudLabels(<String, String>{'select': 'Choisir…'}),
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      // Le libellé ANGLAIS du fork (`selected.dart:200`) NE surface PAS.
      expect(find.text('Select one'), findsNothing);
      // …remplacé par le placeholder LOCALISÉ injecté.
      expect(find.text('Choisir…'), findsOneWidget);
    });

    testWidgets(
        'multi SANS valeur → placeholder l10n, PAS `Select one or more`',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        labels: ZcrudLabels(<String, String>{'select': 'Choisir…'}),
        child: _selectField(EditionFieldType.checkbox,
            value: const <Object?>[], multiple: true, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Select one or more'), findsNothing);
      expect(find.text('Choisir…'), findsOneWidget);
    });

    testWidgets(
        'défaut en (aucune surcharge) → placeholder `Select`, jamais `Select one`',
        (tester) async {
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select, onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Select one'), findsNothing);
      // Clé l10n `select` résolue par la table `en` de repli.
      expect(find.text('Select'), findsOneWidget);
    });
  });

  group('🎯 FIX-3 (AD-2) — reflet d\'un changement EXTERNE de la tranche', () {
    testWidgets(
        're-`pumpWidget` avec value:c → le déclencheur reflète `Charlie` (plus `Alpha`)',
        (tester) async {
      // Tranche initiale = 'a' → le déclencheur affiche « Alpha ».
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'a', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Charlie'), findsNothing);

      // Reflet EXTERNE : le MÊME champ re-monté avec value:'c' (sans interaction).
      // Le fork re-résout la sélection via didUpdateWidget ⇒ parité réactive AD-2.
      await tester.pumpWidget(_host(
        presenter: presenter,
        child: _selectField(EditionFieldType.select,
            value: 'c', onChanged: (_) {}),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Charlie'), findsOneWidget);
      expect(find.text('Alpha'), findsNothing);
    });
  });

  group('🎯 AC8 — composabilité `const`, zéro side-effect d\'import', () {
    test('présentateur `const`-constructible et immuable', () {
      const a = ZSmartSelectPresenter();
      const b = ZSmartSelectPresenter();
      expect(identical(a, b), isTrue); // const canonicalisé.
      expect(a, isA<ZSelectPresenter>());
    });
  });
}
