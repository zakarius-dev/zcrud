// MIN-1 — LaTeX bloc (display centré) vs inline + dialogue enrichi (aperçu live,
// exemples, bascule inline/bloc). Prouve : rendu Math du nouvel embed
// `latexBlock` (MathStyle.display), builder câblé en édition ET lecture,
// insertion via bascule, pré-remplissage de la bascule à l'édition, rétro-compat
// de l'embed `latex` inline (INCHANGÉ), défensif (AD-10).
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillEditor _editor(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor).first);

void _pressLatexButton(WidgetTester tester) {
  final btn = tester
      .widgetList<QuillToolbarCustomButton>(find.byType(QuillToolbarCustomButton))
      .firstWhere((b) => b.options.tooltip == 'Insérer une formule');
  btn.options.onPressed!.call();
}

const _field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

List<Map<String, dynamic>> _blockSeed(String src) => <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{'latexBlock': src},
      },
      <String, dynamic>{'insert': '\n'},
    ];

void main() {
  group('MIN-1 — embed LaTeX bloc (latexBlock, display)', () {
    testWidgets('op {insert:{latexBlock:...}} → widget Math rendu (display)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _blockSeed('E=mc^2')},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Math), findsWidgets);
      // Le builder `latexBlock` est câblé dans les embedBuilders.
      final builders = _editor(tester).config.embedBuilders;
      expect(builders!.any((b) => b.key == 'latexBlock'), isTrue);
      // L'embed inline `latex` reste câblé lui aussi (rétro-compat).
      expect(builders.any((b) => b.key == 'latex'), isTrue);
      await _settle(tester);
    });

    testWidgets('latexBlock malformé → placeholder d\'erreur, aucun throw (AD-10)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _blockSeed(r'\frac{')},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      await _settle(tester);
    });
  });

  group('MIN-1 — dialogue LaTeX enrichi', () {
    testWidgets('bascule « bloc » ON → op {insert:{latexBlock:...}} insérée',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _pressLatexButton(tester);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'a+b');
      // Active le mode bloc.
      await tester.tap(find.byKey(const Key('zlatex-block-toggle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final hasBlock = value.any((op) {
        final ins = op['insert'];
        return ins is Map && ins['latexBlock'] == 'a+b';
      });
      expect(hasBlock, isTrue, reason: 'op latexBlock absente après bascule ON');
      await _settle(tester);
    });

    testWidgets('bascule « bloc » OFF (défaut) → op {insert:{latex:...}} inline',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _pressLatexButton(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'x^2');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final hasInline = value.any((op) {
        final ins = op['insert'];
        return ins is Map && ins['latex'] == 'x^2';
      });
      expect(hasInline, isTrue, reason: 'défaut inline non conservé (rétro-compat)');
      await _settle(tester);
    });

    testWidgets('exemples cliquables : tap chip → champ pré-rempli', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _pressLatexButton(tester);
      await tester.pumpAndSettle();

      expect(find.byType(ActionChip), findsWidgets);
      const example = 'E = mc^2';
      await tester.tap(find.byKey(const ValueKey('zlatex-example-$example')));
      await tester.pumpAndSettle();
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller!.text, example);
      // Aperçu live : la formule valide est rendue (Math dans le dialogue).
      expect(find.byType(Math), findsWidgets);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _settle(tester);
    });

    testWidgets('édition d\'un latexBlock existant → bascule PRÉ-cochée',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': _blockSeed('E=mc^2')},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _editor(tester).controller.updateSelection(
            const TextSelection.collapsed(offset: 1),
            ChangeSource.local,
          );
      await tester.pump();
      _pressLatexButton(tester);
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller!.text, 'E=mc^2');
      final sw = tester
          .widget<SwitchListTile>(find.byKey(const Key('zlatex-block-toggle')));
      expect(sw.value, isTrue, reason: 'bascule bloc non pré-cochée à l\'édition');

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _settle(tester);
    });
  });
}
