// AD-54 / FR-38 / FR-26 — tokens d'aération : `ZcrudTheme.formPadding` consommé
// par `DynamicEdition` (repli du thème, jamais un littéral), `ZResponsiveGrid.
// runGutter` additif (gouttière inter-rangées), relayé par `DynamicEdition.
// gridRunGutter`. API additive NON-CASSANTE (défauts = comportement d'avant).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZcrudTheme.formPadding', () {
    test('défaut = EdgeInsetsDirectional.all(12), copyWith, lerp', () {
      const t = ZcrudTheme();
      expect(t.formPadding, const EdgeInsetsDirectional.all(12));

      final t2 = t.copyWith(
          formPadding: const EdgeInsetsDirectional.all(24));
      expect(t2.formPadding, const EdgeInsetsDirectional.all(24));
      // copyWith sans formPadding préserve la valeur.
      expect(t.copyWith().formPadding, const EdgeInsetsDirectional.all(12));

      final mid = t.lerp(t2, 0.5);
      expect(mid.formPadding, const EdgeInsetsDirectional.all(18));
    });
  });

  group('ZResponsiveGrid.runGutter', () {
    testWidgets('runGutter distinct → Wrap.runSpacing ; spacing = gutter',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZResponsiveGrid(
            gutter: 16,
            runGutter: 8,
            spans: const <ZResponsiveSpan>[ZResponsiveSpan(), ZResponsiveSpan()],
            children: const <Widget>[Text('a'), Text('b')],
          ),
        ),
      ));
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 16);
      expect(wrap.runSpacing, 8);
    });

    testWidgets('runGutter null → repli symétrique sur gutter (non-cassant)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZResponsiveGrid(
            gutter: 10,
            spans: const <ZResponsiveSpan>[ZResponsiveSpan()],
            children: const <Widget>[Text('a')],
          ),
        ),
      ));
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 10);
      expect(wrap.runSpacing, 10);
    });
  });

  group('DynamicEdition — consommation des tokens', () {
    testWidgets(
        'padding == null → LIT réellement ZcrudTheme.formPadding (valeur '
        'NON-défaut all(29), pas un littéral all(12))', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'t': ''},
        visibleFields: <String>['t'],
      );
      addTearDown(controller.dispose);
      // Token NON-défaut (29 ≠ 12) : distingue la lecture-du-token d'un littéral
      // codé en dur. Sous l'injection `widget.padding ?? const all(12)` (token
      // sévré) le padding retomberait sur all(12) ≠ all(29) → test rouge.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            theme: const ZcrudTheme(
                formPadding: EdgeInsetsDirectional.all(29)),
            child: DynamicEdition(
              controller: controller,
              fields: const <ZFieldSpec>[
                ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsetsDirectional.all(29));
    });

    testWidgets('padding explicite PRIME sur le token', (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'t': ''},
        visibleFields: <String>['t'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            child: DynamicEdition(
              controller: controller,
              padding: const EdgeInsets.all(30),
              fields: const <ZFieldSpec>[
                ZFieldSpec(name: 't', type: EditionFieldType.text, label: 'T'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.padding, const EdgeInsets.all(30));
    });

    testWidgets('gridRunGutter relayé à ZResponsiveGrid.runGutter',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'a': '', 'b': ''},
        visibleFields: <String>['a', 'b'],
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            child: DynamicEdition(
              controller: controller,
              gridGutter: 16,
              gridRunGutter: 8,
              layout: const <String, ZResponsiveSpan>{
                'a': ZResponsiveSpan.all(6),
                'b': ZResponsiveSpan.all(6),
              },
              fields: const <ZFieldSpec>[
                ZFieldSpec(name: 'a', type: EditionFieldType.text, label: 'A'),
                ZFieldSpec(name: 'b', type: EditionFieldType.text, label: 'B'),
              ],
            ),
          ),
        ),
      ));
      await tester.pump();
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.spacing, 16);
      expect(wrap.runSpacing, 8);
    });
  });
}
