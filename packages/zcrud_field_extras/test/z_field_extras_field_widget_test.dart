/// 🎯 fp-5-2 — widgets riches `zcrud_field_extras` (PIN / autocomplete / table
/// éditable) via le VRAI dispatcher cœur `ZFieldWidget`/`DynamicEdition`.
///
/// 🔴 **Leçon fp-4-2 (NON-NÉGOCIABLE)** : les `kind` doivent être ATTEIGNABLES
/// par le dispatcher (`ZcrudScope(widgetRegistry)` → `ZFieldWidget(type:…)` →
/// famille `registryOrFallback` → `registry.tryBuilderFor(field.type.name)`),
/// **jamais** via `reg.builderFor(kind)` en direct (qui masquerait un misrouting).
/// FALSIFIABLE (R3) : registre vide / pas de scope ⇒ `ZUnsupportedFieldWidget`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_field_extras/zcrud_field_extras.dart';

ZFieldSpec _field(
  EditionFieldType type, {
  String name = 'f',
  String? label,
  String? hintText,
  List<ZFieldChoice> choices = const <ZFieldChoice>[],
}) =>
    ZFieldSpec(
      name: name,
      type: type,
      label: label ?? 'Champ',
      hintText: hintText,
      choices: choices,
    );

/// Monte [fields] via le VRAI dispatcher sous un [ZcrudScope] portant [registry].
Widget _mount(
  ZFormController controller,
  List<ZFieldSpec> fields,
  ZWidgetRegistry? registry,
) =>
    ZcrudScope(
      widgetRegistry: registry,
      child: MaterialApp(
        home: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

ZFormController _controllerFor(
  ZFieldSpec field, {
  Object? initialValue,
}) {
  final c = ZFormController(
    initialValues: <String, Object?>{field.name: initialValue},
    visibleFields: <String>[field.name],
  );
  return c;
}

void main() {
  group('🔴 alignement des kind sur EditionFieldType.<type>.name', () {
    test('les 3 kinds sont ancrés aux noms d\'enum (jamais un littéral)', () {
      expect(pinFieldKind, EditionFieldType.pin.name);
      expect(autocompleteFieldKind, EditionFieldType.autocomplete.name);
      expect(editableTableFieldKind, EditionFieldType.editableTable.name);
    });
  });

  group('🔴 enrôlement (ZWidgetRegistry réel)', () {
    test('registerZFieldExtrasFields enrôle les 3 kinds une seule fois', () {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      expect(reg.isRegistered(pinFieldKind), isTrue);
      expect(reg.isRegistered(autocompleteFieldKind), isTrue);
      expect(reg.isRegistered(editableTableFieldKind), isTrue);
    });

    test('double enrôlement → ZDuplicateRegistrationError (pas last-wins)', () {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      expect(
        () => registerZFieldExtrasFields(reg),
        throwsA(isA<ZDuplicateRegistrationError>()),
      );
    });
  });

  group('🔴 PIN — atteignable via le VRAI dispatcher (AC-A1/A2)', () {
    testWidgets('pin + registre peuplé → ZPinFieldWidget, PAS Unsupported',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.pin, name: 'pin', label: 'Code');
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();
      expect(find.byType(ZPinFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('FALSIFIABLE — registre VIDE ⇒ ZUnsupportedFieldWidget',
        (t) async {
      final field = _field(EditionFieldType.pin, name: 'pin');
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], ZWidgetRegistry()));
      await t.pump();
      expect(find.byType(ZPinFieldWidget), findsNothing);
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('FALSIFIABLE — aucun ZcrudScope/registre ⇒ repli contrôlé',
        (t) async {
      final field = _field(EditionFieldType.pin, name: 'pin');
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], null));
      await t.pump();
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('🔴 PIN — a11y (≥48 dp + progression Semantics unique) (AC-A3)', () {
    testWidgets('cellules ≥ 48 dp + un SEUL nœud de progression', (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      // hintText encode la longueur (4 chiffres).
      final field =
          _field(EditionFieldType.pin, name: 'pin', label: 'Code', hintText: '4');
      final c = _controllerFor(field, initialValue: '12');
      addTearDown(c.dispose);
      final handle = t.ensureSemantics();
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();

      // La hauteur du Pinput (rangée unique) reflète la cellule ≥ 48 dp.
      final size = t.getSize(find.byKey(const Key('z-pin-input')));
      expect(size.height, greaterThanOrEqualTo(48));

      // Progression UNIQUE (« 2 / 4 … ») — pas de double annonce.
      expect(find.bySemanticsLabel(RegExp(r'2 / 4')), findsOneWidget);
      handle.dispose();
    });
  });

  group('🔴 PIN — value-in-slice + SM-1 (AC-A4)', () {
    testWidgets('frappe dans un champ voisin NE reconstruit PAS le PIN',
        (t) async {
      var pinBuilds = 0;
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg, onBuild: () => pinBuilds++);
      final pin = _field(EditionFieldType.pin, name: 'pin', label: 'Code');
      final other = _field(EditionFieldType.text, name: 'other', label: 'Autre');
      final c = ZFormController(
        initialValues: <String, Object?>{'pin': '', 'other': ''},
        visibleFields: const <String>['pin', 'other'],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[pin, other], reg));
      await t.pump();
      expect(pinBuilds, 1);

      // Le voisin change → le PIN ne se reconstruit pas (SM-1).
      c.setValue('other', 'x');
      await t.pump();
      expect(pinBuilds, 1);

      // Sa propre tranche change → un rebuild ciblé.
      c.setValue('pin', '1');
      await t.pump();
      expect(pinBuilds, 2);
    });

    testWidgets('valeur externe non-String ⇒ champ VIDE, aucun crash (AD-10)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      // hintText encode la longueur (4) pour ancrer la progression attendue.
      final field = _field(EditionFieldType.pin, name: 'pin', hintText: '4');
      final c = _controllerFor(field, initialValue: 42);
      addTearDown(c.dispose);
      final handle = t.ensureSemantics();
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();
      expect(find.byType(ZPinFieldWidget), findsOneWidget);
      // 🔴 REPLI AD-10 PROUVÉ : une valeur non-String (42) ⇒ tranche vide ⇒
      // ZÉRO cellule remplie ⇒ progression « 0 / 4 » (jamais « 2 / 4 »).
      // Falsifiable : muter le repli `: ''` → `: v.toString()` ferait afficher
      // '42' ⇒ filled=2 ⇒ « 2 / 4 » ⇒ ce test rougit.
      expect(find.bySemanticsLabel(RegExp(r'\b0 / 4\b')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'\b2 / 4\b')), findsNothing);
      expect(find.text('4'), findsNothing);
      expect(find.text('2'), findsNothing);
      expect(t.takeException(), isNull);
      handle.dispose();
    });
  });

  group('🔴 autocomplete — dispatcher réel + filtrage (AC-B1/B2/B3)', () {
    testWidgets('autocomplete + registre peuplé → ZAutocompleteFieldWidget',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.autocomplete, name: 'ac');
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();
      expect(find.byType(ZAutocompleteFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('FALSIFIABLE — registre vide ⇒ ZUnsupportedFieldWidget',
        (t) async {
      final field = _field(EditionFieldType.autocomplete, name: 'ac');
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], ZWidgetRegistry()));
      await t.pump();
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    });

    testWidgets('saisie filtre les suggestions (options depuis field.choices)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(
        EditionFieldType.autocomplete,
        name: 'ac',
        choices: const <ZFieldChoice>[
          ZFieldChoice(value: 'apple', label: 'Apple'),
          ZFieldChoice(value: 'apricot', label: 'Apricot'),
          ZFieldChoice(value: 'banana', label: 'Banana'),
        ],
      );
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();

      await t.enterText(find.byType(TextField), 'ap');
      await t.pumpAndSettle();
      // Les 2 « Ap* » apparaissent dans la liste d'options ; « Banana » non.
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Apricot'), findsOneWidget);
      expect(find.text('Banana'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'ré-injection externe ctx.value post-montage s\'affiche dans le champ (LOW)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.autocomplete, name: 'ac');
      final c = _controllerFor(field, initialValue: '');
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();

      // 🔴 Ré-injection externe (le doc-comment affirme « lit ctx.value »).
      c.setValue('ac', 'X');
      await t.pump();
      expect(find.text('X'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets(
        'options — label sémantique annoncé UNE seule fois (pas de double) (MED-3)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(
        EditionFieldType.autocomplete,
        name: 'ac',
        choices: const <ZFieldChoice>[
          ZFieldChoice(value: 'apple', label: 'Apple'),
        ],
      );
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      final handle = t.ensureSemantics();
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();

      await t.enterText(find.byType(TextField), 'app');
      await t.pumpAndSettle();
      // 🔴 Le label 'Apple' du bouton d'option apparaît UNE fois — le Text enfant
      // ne DOIT PAS émettre un second nœud (excludeSemantics sur l'option).
      expect(find.bySemanticsLabel('Apple'), findsOneWidget);
      expect(t.takeException(), isNull);
      handle.dispose();
    });
  });

  group('🔴 editableTable — dispatcher réel + virtualisation + défensif', () {
    testWidgets('editableTable + registre peuplé → ZEditableTableFieldWidget',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.editableTable, name: 'tbl');
      final c = _controllerFor(field, initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'foo'},
      ]);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();
      expect(find.byType(ZEditableTableFieldWidget), findsOneWidget);
      expect(find.byKey(const Key('z-editable-table-rows')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('FALSIFIABLE — registre vide ⇒ ZUnsupportedFieldWidget',
        (t) async {
      final field = _field(EditionFieldType.editableTable, name: 'tbl');
      final c = _controllerFor(field);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], ZWidgetRegistry()));
      await t.pump();
      expect(find.byType(ZUnsupportedFieldWidget), findsOneWidget);
    });

    testWidgets('édition d\'une cellule met à jour la valeur de tranche',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.editableTable, name: 'tbl');
      final c = _controllerFor(field, initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'foo'},
      ]);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();

      await t.enterText(find.byType(TextFormField).first, 'bar');
      await t.pump();
      final rows = zParseTableRows(c.valueOf('tbl'));
      expect(rows, hasLength(1));
      expect(rows.first['name'], 'bar');
    });

    testWidgets(
        'ré-injection externe d\'une cellule EXISTANTE re-synchronise l\'affichage (MED-1)',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.editableTable, name: 'tbl');
      final c = _controllerFor(field, initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'foo'},
      ]);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();
      expect(find.text('foo'), findsOneWidget);

      // 🔴 Ré-injection externe (reset / autre entité) : la MÊME ligne change de
      // valeur. La cellule DOIT refléter 'bar' (pas rester bloquée sur 'foo').
      c.setValue('tbl', const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'bar'},
      ]);
      await t.pump();
      expect(find.text('bar'), findsOneWidget);
      expect(find.text('foo'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('ajout de ligne écrit une nouvelle List<Map>', (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      final field = _field(EditionFieldType.editableTable, name: 'tbl');
      final c = _controllerFor(field, initialValue: const <Map<String, dynamic>>[
        <String, dynamic>{'name': 'foo'},
      ]);
      addTearDown(c.dispose);
      await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
      await t.pump();

      await t.tap(find.byKey(const Key('z-table-add-row')));
      await t.pump();
      expect(zParseTableRows(c.valueOf('tbl')), hasLength(2));
    });

    testWidgets('corpus corrompu (null / non-List / éléments non-Map) survit',
        (t) async {
      final reg = ZWidgetRegistry();
      registerZFieldExtrasFields(reg);
      for (final corrupt in <Object?>[
        null,
        'x',
        42,
        <Object?>[<String, dynamic>{'a': 1}, 42, 'nope'],
      ]) {
        final field = _field(EditionFieldType.editableTable, name: 'tbl');
        final c = _controllerFor(field, initialValue: corrupt);
        addTearDown(c.dispose);
        await t.pumpWidget(_mount(c, <ZFieldSpec>[field], reg));
        await t.pump();
        expect(find.byType(ZEditableTableFieldWidget), findsOneWidget);
        expect(t.takeException(), isNull);
      }
    });

    test('zParseTableRows défensif — types unitaires', () {
      expect(zParseTableRows(null), isEmpty);
      expect(zParseTableRows('x'), isEmpty);
      expect(zParseTableRows(42), isEmpty);
      expect(
        zParseTableRows(<Object?>[
          <String, dynamic>{'a': 1},
          42,
          <String, dynamic>{'b': 2},
        ]),
        hasLength(2),
      );
    });
  });

  group('🔴 virtualisation — grep négatif ListView(children:) (AC-C2)', () {
    test('le fichier table n\'utilise QUE ListView.builder', () {
      final root = Directory('packages').existsSync() ? '.' : '../..';
      final raw = File(
        '$root/packages/zcrud_field_extras/lib/src/presentation/'
        'z_editable_table_field_widget.dart',
      ).readAsStringSync();
      // Code seul (les commentaires `///`/`//`/`*` mentionnent le motif interdit).
      final code = raw
          .split('\n')
          .where((l) {
            final t = l.trim();
            return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
          })
          .join('\n');
      expect(code.contains('ListView.builder'), isTrue,
          reason: 'la table DOIT être virtualisée');
      expect(code.contains('ListView(children'), isFalse,
          reason: '🔴 AD-13 : jamais ListView(children:[...])');
    });
  });
}
