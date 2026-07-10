// AC3–7 (E3-3b-1) — Familles-feuilles avancées : chaque widget dédié est rendu
// (jamais le repli), l'interaction met à jour la TRANCHE (type attendu), et
// chaque famille rend sous RTL sans overflow/exception.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const List<ZFieldChoice> _choices = <ZFieldChoice>[
  ZFieldChoice(value: 'a', label: 'A'),
  ZFieldChoice(value: 'b', label: 'B'),
  ZFieldChoice(value: 'c', label: 'C'),
];

ZFormController _controller(String name, {Object? value}) => ZFormController(
      initialValues: <String, Object?>{name: value},
      visibleFields: <String>[name],
    );

Widget _app(
  ZFormController controller,
  ZFieldSpec field, {
  TextDirection dir = TextDirection.ltr,
}) =>
    MaterialApp(
      home: Directionality(
        textDirection: dir,
        child: Scaffold(
          body: DynamicEdition(controller: controller, fields: <ZFieldSpec>[field]),
        ),
      ),
    );

void main() {
  // ── tags (AC3) ────────────────────────────────────────────────────────────
  group('tags (AC3)', () {
    testWidgets('ajout puis retrait mettent à jour la List<String> en tranche',
        (tester) async {
      final controller = _controller('tg');
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'tg', type: EditionFieldType.tags, label: 'Tags');

      await tester.pumpWidget(_app(controller, field));
      await tester.pump();
      expect(find.byType(ZTagsFieldWidget), findsOneWidget);
      expect(find.byType(ZUnsupportedFieldWidget), findsNothing);

      // Ajout.
      await tester.enterText(find.byType(TextField), 'alpha');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(controller.valueOf('tg'), <String>['alpha']);

      // Un second (pas de doublon).
      await tester.enterText(find.byType(TextField), 'beta');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(controller.valueOf('tg'), <String>['alpha', 'beta']);

      // Retrait du premier.
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(controller.valueOf('tg'), <String>['beta']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rendu RTL sans overflow', (tester) async {
      final controller = _controller('tg', value: const <String>['x', 'y']);
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'tg', type: EditionFieldType.tags);
      await tester.pumpWidget(_app(controller, field, dir: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── rowChips (AC4) ────────────────────────────────────────────────────────
  group('rowChips (AC4)', () {
    testWidgets('sélection mono-choix écrit la valeur en tranche',
        (tester) async {
      final controller = _controller('rc');
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
          name: 'rc', type: EditionFieldType.rowChips, label: 'RC', choices: _choices);

      await tester.pumpWidget(_app(controller, field));
      await tester.pump();
      expect(find.byType(ZRowChipsFieldWidget), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.pump();
      expect(controller.valueOf('rc'), 'b');

      // Re-toucher la puce active → désélection (null).
      await tester.tap(find.widgetWithText(ChoiceChip, 'B'));
      await tester.pump();
      expect(controller.valueOf('rc'), isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rendu RTL sans overflow', (tester) async {
      final controller = _controller('rc', value: 'a');
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
          name: 'rc', type: EditionFieldType.rowChips, choices: _choices);
      await tester.pumpWidget(_app(controller, field, dir: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── rating (AC5) ──────────────────────────────────────────────────────────
  group('rating (AC5)', () {
    testWidgets('toucher une étoile écrit la note (num) en tranche',
        (tester) async {
      final controller = _controller('rt');
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'rt',
        type: EditionFieldType.rating,
        label: 'Note',
        config: ZRatingConfig(max: 5),
      );

      await tester.pumpWidget(_app(controller, field));
      await tester.pump();
      expect(find.byType(ZRatingFieldWidget), findsOneWidget);
      // 5 étoiles = 5 IconButton.
      expect(find.byType(IconButton), findsNWidgets(5));

      await tester.tap(find.byType(IconButton).at(2)); // 3e étoile
      await tester.pump();
      expect(controller.valueOf('rt'), 3);
      // Re-toucher l'étoile active → 0.
      await tester.tap(find.byType(IconButton).at(2));
      await tester.pump();
      expect(controller.valueOf('rt'), 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rendu RTL sans overflow', (tester) async {
      final controller = _controller('rt', value: 2);
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'rt', type: EditionFieldType.rating);
      await tester.pumpWidget(_app(controller, field, dir: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── slider (AC6) ──────────────────────────────────────────────────────────
  group('slider (AC6)', () {
    testWidgets('glisser le curseur écrit une valeur num en tranche',
        (tester) async {
      final controller = _controller('sl', value: 0);
      addTearDown(controller.dispose);
      const field = ZFieldSpec(
        name: 'sl',
        type: EditionFieldType.slider,
        label: 'Curseur',
        config: ZSliderConfig(divisions: 10),
      );

      await tester.pumpWidget(_app(controller, field));
      await tester.pump();
      expect(find.byType(ZSliderFieldWidget), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      await tester.drag(find.byType(Slider), const Offset(200, 0));
      await tester.pump();
      final v = controller.valueOf('sl');
      expect(v, isA<num>());
      expect((v! as num) > 0, isTrue, reason: 'le glissement augmente la valeur');
      expect(tester.takeException(), isNull);
    });

    testWidgets('rendu RTL sans overflow', (tester) async {
      final controller = _controller('sl', value: 0.5);
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'sl', type: EditionFieldType.slider);
      await tester.pumpWidget(_app(controller, field, dir: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  // ── color (AC7) ───────────────────────────────────────────────────────────
  group('color (AC7)', () {
    testWidgets('toucher un swatch écrit un int ARGB stable en tranche',
        (tester) async {
      final controller = _controller('cl');
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'cl', type: EditionFieldType.color, label: 'Couleur');

      await tester.pumpWidget(_app(controller, field));
      await tester.pump();
      expect(find.byType(ZColorFieldWidget), findsOneWidget);

      await tester.tap(find.byType(InkWell).first);
      await tester.pump();
      final v = controller.valueOf('cl');
      expect(v, isA<int>(), reason: 'encodage ARGB int documenté');
      expect(tester.takeException(), isNull);
    });

    testWidgets('rendu RTL sans overflow', (tester) async {
      final controller = _controller('cl');
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'cl', type: EditionFieldType.color);
      await tester.pumpWidget(_app(controller, field, dir: TextDirection.rtl));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
