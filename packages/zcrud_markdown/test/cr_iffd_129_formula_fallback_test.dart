// CR-IFFD-129 — couture d'échec de formule : `ZRichTextFormulaSpec.fallbackBuilder`.
//
// Trois angles :
//   1. INERTIE — sans repli déclaré, une formule que le moteur refuse rend
//      EXACTEMENT le placeholder du socle (icône `error_outline` + label a11y),
//      arbre inchangé.
//   2. EFFET — avec un repli déclaré, c'est LUI qui rend, à la place du
//      placeholder, et il reçoit la source ET l'erreur.
//   3. ROBUSTESSE (AD-10) — un repli qui LÈVE ne casse rien : le placeholder du
//      socle reprend la main, aucune exception ne remonte.
//
// La spec voyage par champ : une seule déclaration couvre lecteur et éditeur —
// c'est ce que prouve le second groupe, qui monte les deux.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Import CIBLÉ de l'impl (même package) : le barrel n'exporte pas
// `kLatexInvalidLabel` (isolation AD-1).
import 'package:zcrud_markdown/src/presentation/z_latex_embed.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Formule structurellement valide (une `String`) mais que le moteur refuse.
const List<Map<String, dynamic>> _seed = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{'latex': r'\frac{'},
  },
  <String, dynamic>{'insert': '\n'},
];

Iterable<Semantics> _semanticsLabelled(WidgetTester tester, String label) =>
    tester
        .widgetList<Semantics>(find.byType(Semantics))
        .where((s) => s.properties.label == label);

void main() {
  group('CR-IFFD-129 — inertie : sans repli, placeholder du socle', () {
    testWidgets('icône + label a11y, exactement comme avant', (tester) async {
      await tester.pumpWidget(_host(
        const ZMarkdownReader(value: _seed),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsWidgets,
          reason: 'placeholder d\'erreur du socle attendu');
      expect(_semanticsLabelled(tester, kLatexInvalidLabel), isNotEmpty,
          reason: 'le placeholder porte son label a11y');
    });

    testWidgets('une spec SANS repli ne change rien non plus', (tester) async {
      await tester.pumpWidget(_host(
        const ZMarkdownReader(
          value: _seed,
          formulaSpec: ZRichTextFormulaSpec(inlineScaleFactor: 1.2),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.error_outline), findsWidgets);
      expect(_semanticsLabelled(tester, kLatexInvalidLabel), isNotEmpty);
    });
  });

  group('CR-IFFD-129 — effet : le repli rend à la place du placeholder', () {
    testWidgets('LECTEUR : repli rendu, placeholder absent, source+erreur reçues',
        (tester) async {
      String? source;
      Object? error;
      await tester.pumpWidget(_host(
        ZMarkdownReader(
          value: _seed,
          formulaSpec: ZRichTextFormulaSpec(
            fallbackBuilder: (BuildContext context, String s, Object e) {
              source = s;
              error = e;
              return const Text('SECOURS', key: Key('cr129-secours'));
            },
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('cr129-secours')), findsOneWidget,
          reason: 'le repli déclaré doit rendre');
      expect(find.byIcon(Icons.error_outline), findsNothing,
          reason: 'le placeholder du socle ne doit PAS être rendu en plus');
      expect(source, r'\frac{',
          reason: 'le repli reçoit la source soumise au moteur');
      expect(error, isNotNull, reason: 'le repli reçoit l\'erreur du moteur');
    });

    testWidgets('ÉDITEUR : la MÊME déclaration couvre la voie d\'édition',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      const field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);
      controller.setValue('notes', _seed);

      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: const ValueKey<String>('notes'),
          controller: controller,
          field: field,
          showToolbar: false,
          formulaSpec: ZRichTextFormulaSpec(
            fallbackBuilder: (BuildContext context, String s, Object e) =>
                const Text('SECOURS', key: Key('cr129-secours-edition')),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('cr129-secours-edition')), findsOneWidget,
          reason: 'la spec par champ couvre l\'éditeur comme le lecteur');
      expect(find.byIcon(Icons.error_outline), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  });

  group('CR-IFFD-129 — robustesse (AD-10) : un repli qui lève', () {
    testWidgets('retombe sur le placeholder, aucune exception ne remonte',
        (tester) async {
      await tester.pumpWidget(_host(
        ZMarkdownReader(
          value: _seed,
          formulaSpec: ZRichTextFormulaSpec(
            fallbackBuilder: (BuildContext context, String s, Object e) =>
                throw StateError('repli cassé'),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull,
          reason: 'un repli d\'appelant qui casse ne doit pas casser le rendu');
      expect(find.byIcon(Icons.error_outline), findsWidgets,
          reason: 'le placeholder du socle reprend la main');
    });
  });
}
