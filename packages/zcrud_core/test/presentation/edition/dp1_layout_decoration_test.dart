// DP-1 (parité DODLP B1 + B2 + M2) : variante `large` en Card, `minLines`/
// `maxLines` réellement lus, fabrique `ZcrudTheme.inputDecoration` dérivée de
// tokens + override app effectivement consommé. AD-2/SM-1 non régressé (large).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Pompe un unique [ZFieldWidget] lié à un [ZFormController] jetable.
Future<ZFormController> _pumpField(
  WidgetTester tester,
  ZFieldSpec field, {
  Object? initial,
  List<ThemeExtension<dynamic>> extensions = const <ThemeExtension<dynamic>>[],
  VoidCallback? onBuild,
}) async {
  final controller = ZFormController(
    initialValues: <String, Object?>{field.name: initial},
    visibleFields: <String>[field.name],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(extensions: extensions),
      home: Scaffold(
        body: KeyedSubtree(
          key: ValueKey<String>(field.name),
          child: ZFieldWidget(controller: controller, field: field, onBuild: onBuild),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

InputDecoration _decorationOf(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).decoration!;

void main() {
  group('M2 — fabrique inputDecoration (AC9/AC10/AC13)', () {
    testWidgets('défauts dérivés des tokens DODLP', (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'L'),
        initial: '',
      );
      final deco = _decorationOf(tester);
      final border = deco.border! as OutlineInputBorder;
      expect(border.borderRadius.topLeft, const Radius.circular(12));
      expect(border.borderSide.width, 1);
      final focused = deco.focusedBorder! as OutlineInputBorder;
      expect(focused.borderSide.width, 2);
      final pad = deco.contentPadding! as EdgeInsetsDirectional;
      expect(pad, const EdgeInsetsDirectional.symmetric(horizontal: 16, vertical: 16));
      expect(deco.filled, isTrue);
      expect(deco.helperMaxLines, 2);
      expect(deco.floatingLabelStyle!.fontWeight, FontWeight.bold);
      // DP-12 : la famille passe désormais un label ENRICHI (`ZFieldLabel`) via
      // `label:` (Widget), et non plus `labelText` (String nu) — AC7.
      expect(deco.labelText, isNull);
      expect(deco.label, isA<ZFieldLabel>());
    });

    testWidgets('couleurs dérivées du ColorScheme (outline/primary/error)',
        (tester) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            scheme = Theme.of(context).colorScheme;
            final deco = ZcrudTheme.of(context).inputDecoration(context, label: 'L');
            final enabled = deco.enabledBorder! as OutlineInputBorder;
            final focused = deco.focusedBorder! as OutlineInputBorder;
            final error = deco.errorBorder! as OutlineInputBorder;
            expect(enabled.borderSide.color, scheme.outline);
            expect(focused.borderSide.color, scheme.primary);
            expect(error.borderSide.color, scheme.error);
            expect(deco.fillColor, scheme.surfaceContainerHighest);
            return const SizedBox();
          }),
        ),
      );
    });

    testWidgets('mode bare : borderless, isDense, padding zéro, sans label',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) {
            final deco =
                ZcrudTheme.of(context).inputDecoration(context, label: 'L', bare: true);
            expect(deco.border, InputBorder.none);
            expect(deco.enabledBorder, InputBorder.none);
            expect(deco.focusedBorder, InputBorder.none);
            expect(deco.isDense, isTrue);
            expect(deco.contentPadding, EdgeInsets.zero);
            expect(deco.filled, isFalse);
            expect(deco.labelText, isNull);
            return const SizedBox();
          }),
        ),
      );
    });
  });

  group('M2 — override app effectivement consommé (AC12)', () {
    testWidgets('inputRadius / inputContentPadding overridés reflétés',
        (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'L'),
        initial: '',
        extensions: <ThemeExtension<dynamic>>[
          const ZcrudTheme(
            inputRadius: Radius.circular(4),
            inputContentPadding:
                EdgeInsetsDirectional.symmetric(horizontal: 3, vertical: 3),
          ),
        ],
      );
      final deco = _decorationOf(tester);
      final border = deco.border! as OutlineInputBorder;
      expect(border.borderRadius.topLeft, const Radius.circular(4));
      expect(
        deco.contentPadding,
        const EdgeInsetsDirectional.symmetric(horizontal: 3, vertical: 3),
      );
    });
  });

  group('B2 — minLines/maxLines réellement lus (AC6/AC7/AC8)', () {
    testWidgets('ZTextConfig(minLines:2,maxLines:4) honoré', (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(
          name: 't',
          type: EditionFieldType.multiline,
          label: 'L',
          config: ZTextConfig(minLines: 2, maxLines: 4),
        ),
        initial: '',
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 2);
      expect(field.maxLines, 4);
      expect(field.keyboardType, TextInputType.multiline);
    });

    testWidgets('text sans config → défauts 1/1', (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'L'),
        initial: '',
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 1);
      expect(field.maxLines, 1);
    });

    testWidgets('multiline sans config → 3 / null (multiligne)', (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(
            name: 't', type: EditionFieldType.multiline, label: 'L'),
        initial: '',
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 3);
      expect(field.maxLines, isNull);
      expect(field.keyboardType, TextInputType.multiline);
    });

    testWidgets('password : config multi-ligne ignorée → 1/1 (garde AC8)',
        (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(
          name: 'p',
          type: EditionFieldType.password,
          label: 'L',
          config: ZTextConfig(minLines: 3, maxLines: 6),
        ),
        initial: '',
      );
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 1);
      expect(field.maxLines, 1);
      expect(field.obscureText, isTrue);
    });

    testWidgets('MEDIUM-1 : maxLines < repli minLines → clampé (0 assertion)',
        (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(
          name: 't',
          type: EditionFieldType.multiline,
          label: 'L',
          config: ZTextConfig(maxLines: 2), // sans minLines → repli 3 > 2
        ),
        initial: '',
      );
      expect(tester.takeException(), isNull,
          reason: 'minLines clampé à maxLines → pas d\'assertion Flutter');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.maxLines, 2);
      expect(field.minLines, lessThanOrEqualTo(2));
    });

    testWidgets('MEDIUM-2 : variante large annonce le label UNE fois (a11y)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpField(
        tester,
        const ZFieldSpec(
          name: 't',
          type: EditionFieldType.text,
          label: 'MonLabel',
          fieldSize: ZFieldSize.large,
        ),
        initial: '',
      );
      await tester.pump();
      // Le Text visible est ExcludeSemantics → seul le Semantics conteneur porte
      // le label (pas de double annonce).
      expect(find.bySemanticsLabel('MonLabel'), findsOneWidget);
      handle.dispose();
    });
  });

  group('B1 — variante large en Card (AC3/AC4/AC5)', () {
    testWidgets('large monte une Card + ConstrainedBox minHeight>=64 + label',
        (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(
          name: 't',
          type: EditionFieldType.text,
          label: 'Grand',
          fieldSize: ZFieldSize.large,
        ),
        initial: '',
      );
      expect(find.byType(ZLargeFieldCard), findsOneWidget);
      expect(find.byType(Card), findsWidgets);
      expect(find.text('Grand'), findsOneWidget);
      final boxes = tester
          .widgetList<ConstrainedBox>(find.descendant(
            of: find.byType(ZLargeFieldCard),
            matching: find.byType(ConstrainedBox),
          ))
          .toList();
      expect(boxes.any((b) => b.constraints.minHeight >= 64), isTrue);
    });

    testWidgets('champ interne bare (border none, sans labelText)',
        (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(
          name: 't',
          type: EditionFieldType.text,
          label: 'Grand',
          fieldSize: ZFieldSize.large,
        ),
        initial: '',
      );
      final deco = _decorationOf(tester);
      expect(deco.border, InputBorder.none);
      expect(deco.isDense, isTrue);
      expect(deco.labelText, isNull);
    });

    testWidgets('normal (défaut) : aucun wrapper Card', (tester) async {
      await _pumpField(
        tester,
        const ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'L'),
        initial: '',
      );
      expect(find.byType(ZLargeFieldCard), findsNothing);
      // Décor inline standard (bordure présente).
      expect(_decorationOf(tester).border, isA<OutlineInputBorder>());
    });
  });

  group('SM-1 / AD-2 non régressé en large (AC15)', () {
    testWidgets('frappe char-par-char en large → focus conservé, rebuild ciblé',
        (tester) async {
      var builds = 0;
      final controller = await _pumpField(
        tester,
        const ZFieldSpec(
          name: 't',
          type: EditionFieldType.text,
          label: 'Grand',
          fieldSize: ZFieldSize.large,
        ),
        initial: '',
        onBuild: () => builds++,
      );
      final editable = find.byType(EditableText);
      await tester.tap(editable);
      await tester.pump();
      final buildsBefore = builds;
      const text = 'HELLO_LARGE';
      for (var i = 1; i <= text.length; i++) {
        await tester.enterText(editable, text.substring(0, i));
        await tester.pump();
        // Focus JAMAIS perdu pendant la frappe (AD-2).
        expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      }
      // Valeur propagée à la tranche + rebuilds bornés à CE champ (au moins un
      // rebuild par frappe, aucun rebuild d'un autre champ — il n'y en a qu'un).
      expect(controller.valueOf('t'), text);
      expect(builds, greaterThan(buildsBefore));
      // La Card reste montée une seule fois (wrapper statique, hors voie de frappe).
      expect(find.byType(ZLargeFieldCard), findsOneWidget);
    });
  });
}
