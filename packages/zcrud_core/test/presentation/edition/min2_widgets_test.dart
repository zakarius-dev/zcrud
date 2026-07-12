// MIN-2 — gaps MINEURS de parité DODLP (comportements widget) :
// croix d'effacement date, reset select mono, radio en modal, sous-titre rowChips,
// mapping text→multiline, fallback image, helpers layout (cohérence clés + gap
// type-dépendant), persistance du repli de sections via seam neutre.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const List<ZFieldChoice> _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'A'),
  ZFieldChoice(value: 'b', label: 'B', subtitle: 'Deuxième'),
  ZFieldChoice(value: 'c', label: 'C'),
];

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _app(
  ZFormController controller,
  List<ZFieldSpec> fields, {
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: fields),
        ),
      ),
    );

void main() {
  group('MIN-2 · date — croix d\'effacement (non requis)', () {
    testWidgets('champ non requis avec valeur ⇒ croix efface (→ null)',
        (tester) async {
      final controller = _controller(<String, Object?>{'d': '2024-01-02T00:00:00.000'});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'd', type: EditionFieldType.dateTime, label: 'D');
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();

      final clear = find.byIcon(Icons.clear);
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pump();
      expect(controller.valueOf('d'), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('champ requis ⇒ aucune croix', (tester) async {
      final controller = _controller(<String, Object?>{'d': '2024-01-02T00:00:00.000'});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        validators: <ZValidatorSpec>[ZValidatorSpec.required()],
      );
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('champ vide ⇒ aucune croix (rien à effacer)', (tester) async {
      final controller = _controller(<String, Object?>{'d': null});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'd', type: EditionFieldType.dateTime);
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsNothing);
    });
  });

  group('MIN-2 · select — reset (→ null) + radio en modal', () {
    testWidgets('select mono non requis avec valeur ⇒ reset efface',
        (tester) async {
      final controller = _controller(<String, Object?>{'s': 'a'});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
          name: 's', type: EditionFieldType.select, label: 'S', choices: _choices);
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();

      final reset = find.byIcon(Icons.clear);
      expect(reset, findsOneWidget);
      await tester.tap(reset);
      await tester.pump();
      expect(controller.valueOf('s'), isNull);
    });

    testWidgets('radioAsModal ⇒ pas de RadioListTile inline, déclencheur modal',
        (tester) async {
      final controller = _controller(<String, Object?>{'r': 'a'});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'r',
        type: EditionFieldType.radio,
        label: 'R',
        choices: _choices,
        config: ZSelectConfig(radioAsModal: true),
      );
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      expect(find.byType(RadioListTile<Object?>), findsNothing);
      // Le déclencheur modal ouvre une feuille de sélection au tap.
      await tester.tap(find.text('A'));
      await tester.pumpAndSettle();
      expect(find.text('Confirm'), findsOneWidget);
    });

    testWidgets('radio sans config ⇒ RadioListTile inline (rétro-compat)',
        (tester) async {
      final controller = _controller(<String, Object?>{'r': 'a'});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
          name: 'r', type: EditionFieldType.radio, choices: _choices);
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      expect(find.byType(RadioListTile<Object?>), findsNWidgets(3));
    });
  });

  group('MIN-2 · rowChips — sous-titre', () {
    testWidgets('sous-titre rendu + sélection fonctionnelle', (tester) async {
      final controller = _controller(<String, Object?>{'rc': null});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
          name: 'rc', type: EditionFieldType.rowChips, choices: _choices);
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      // Le sous-titre de l'option B est rendu.
      expect(find.text('Deuxième'), findsOneWidget);
      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.pump();
      expect(controller.valueOf('rc'), 'b');
      expect(tester.takeException(), isNull);
    });
  });

  group('MIN-2 · text → multiline (mapping minLines>1)', () {
    testWidgets('text + minLines:2 ⇒ TextField multi-ligne (min respecté)',
        (tester) async {
      final controller = _controller(<String, Object?>{'t': ''});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 't',
        type: EditionFieldType.text,
        config: ZTextConfig(minLines: 2),
      );
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.minLines, 2);
      // maxLines n'est plus figé à 1 (extensible) — la config n'est plus écrasée.
      expect(tf.maxLines, isNot(1));
    });

    testWidgets('text sans config ⇒ mono-ligne (rétro-compat stricte)',
        (tester) async {
      final controller = _controller(<String, Object?>{'t': ''});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 't', type: EditionFieldType.text);
      await tester.pumpWidget(_app(controller, <ZFieldSpec>[field]));
      await tester.pump();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.minLines, 1);
      expect(tf.maxLines, 1);
    });
  });

  group('MIN-2 · helpers layout purs', () {
    test('zUnknownLayoutKeys détecte les clés orphelines', () {
      final unknown = zUnknownLayoutKeys(
        <String>{'a', 'b'},
        <String, ZResponsiveSpan>{
          'a': const ZResponsiveSpan(),
          'ghost': const ZResponsiveSpan(),
        },
      );
      expect(unknown, <String>{'ghost'});
    });

    test('zUnknownLayoutKeys vide quand cohérent', () {
      expect(
        zUnknownLayoutKeys(<String>{'a'},
            <String, ZResponsiveSpan>{'a': const ZResponsiveSpan()}),
        isEmpty,
      );
    });

    test('zFieldGapAfter : 0 par défaut, base pour les types blocs', () {
      // base 0 ⇒ toujours 0 (rétro-compat).
      expect(zFieldGapAfter(EditionFieldType.multiline), 0);
      // base > 0 ⇒ gap pour un type bloc, 0 pour un compact.
      expect(zFieldGapAfter(EditionFieldType.multiline, base: 12), 12);
      expect(zFieldGapAfter(EditionFieldType.subItems, base: 12), 12);
      expect(zFieldGapAfter(EditionFieldType.text, base: 12), 0);
      expect(zFieldGapAfter(EditionFieldType.boolean, base: 12), 0);
    });
  });

  group('MIN-2 · persistance du repli des sections (seam neutre)', () {
    test('ZInMemorySectionCollapseStore round-trip par formId', () {
      final store = ZInMemorySectionCollapseStore();
      expect(store.loadCollapsed('f1'), isEmpty);
      store.saveCollapsed('f1', <String>{'Section A'});
      expect(store.loadCollapsed('f1'), <String>{'Section A'});
      // Isolation par formId.
      expect(store.loadCollapsed('f2'), isEmpty);
    });

    testWidgets('DynamicEdition persiste le repli via le store injecté',
        (tester) async {
      final store = ZInMemorySectionCollapseStore();
      final controller = _controller(<String, Object?>{'x': ''});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'x', type: EditionFieldType.text);
      const sections = <ZEditionSection>[
        ZEditionSection(
          title: 'Section A',
          fields: <String>['x'],
          collapsible: true,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[field],
            sections: sections,
            collapseStore: store,
            formId: 'form-1',
          ),
        ),
      ));
      await tester.pump();

      // Replie la section via l'en-tête accessible.
      await tester.tap(find.text('Section A'));
      await tester.pump();
      expect(store.loadCollapsed('form-1'), <String>{'Section A'});
    });

    testWidgets('le repli persisté est ré-appliqué au montage',
        (tester) async {
      final store = ZInMemorySectionCollapseStore()
        ..saveCollapsed('form-2', <String>{'Section A'});
      final controller = _controller(<String, Object?>{'x': ''});
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'x', type: EditionFieldType.text);
      const sections = <ZEditionSection>[
        ZEditionSection(
          title: 'Section A',
          fields: <String>['x'],
          collapsible: true,
        ),
      ];

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DynamicEdition(
            controller: controller,
            fields: const <ZFieldSpec>[field],
            sections: sections,
            collapseStore: store,
            formId: 'form-2',
          ),
        ),
      ));
      await tester.pump();
      // Section repliée ⇒ le champ membre n'est pas monté.
      expect(find.byType(ZFieldWidget), findsNothing);
    });
  });
}
