// CR-IFFD-132 — `extraEmbedRenderers` : les types d'embed du socle sont un
// plancher, pas un plafond.
//
// Quatre angles :
//   1. INERTIE — liste vide sur les TROIS points de montage publics : la liste
//      d'`EmbedBuilder`s passée à l'éditeur est la CONSTANTE du socle, à
//      l'IDENTITÉ près (pas seulement égale : la même instance — AD-2).
//   2. EFFET, clé neuve — un type inconnu du socle est rendu par le rendu
//      déclaré, au lieu du repli d'embed inconnu.
//   3. EFFET, collision — sur une clé que le socle rend DÉJÀ, c'est le rendu
//      déclaré qui gagne. C'est la règle, et elle est gardée ici, pas seulement
//      écrite.
//   4. ROBUSTESSE (AD-10) — un rendu déclaré qui LÈVE ne casse pas le document.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Import CIBLÉ de l'impl (même package) : la constante du socle n'est pas
// publique (isolation AD-1).
import 'package:zcrud_markdown/src/presentation/z_rich_text_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

List<Map<String, dynamic>> _seed(String type, Object? data) =>
    <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{type: data},
      },
      <String, dynamic>{'insert': '\n'},
    ];

Iterable<EmbedBuilder>? _buildersOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).config.embedBuilders;

Future<void> _drain(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

void main() {
  const field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

  group('CR-IFFD-132 — inertie : liste vide ⇒ la CONSTANTE du socle', () {
    testWidgets('LECTEUR', (tester) async {
      await tester.pumpWidget(_host(
        const ZMarkdownReader(
          // Contenu non vide : le lecteur ne rend un `QuillEditor` que
          // lorsqu'il a quelque chose à rendre (sinon, état vide).
          value: <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'texte\n'},
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(identical(_buildersOf(tester), kZEmbedBuilders), isTrue,
          reason: 'aucune allocation : la référence doit rester la constante');
    });

    testWidgets('ÉDITEUR', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: const ValueKey<String>('notes'),
          controller: controller,
          field: field,
          showToolbar: false,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(identical(_buildersOf(tester), kZEmbedBuilders), isTrue);
      await _drain(tester);
    });

    testWidgets('DIALOGUE plein-écran', (tester) async {
      await tester.pumpWidget(_host(
        const ZRichTextFullscreenDialog(initialValue: <Map<String, dynamic>>[]),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(identical(_buildersOf(tester), kZEmbedBuilders), isTrue);
      await _drain(tester);
    });
  });

  group('CR-IFFD-132 — effet : une clé NEUVE est rendue', () {
    testWidgets('un type inconnu du socle rend le widget déclaré',
        (tester) async {
      Object? recue;
      await tester.pumpWidget(_host(
        ZMarkdownReader(
          value: _seed('x-iffd-widget', 'charge'),
          extraEmbedRenderers: <ZEmbedRenderer>[
            ZEmbedRenderer(
              type: 'x-iffd-widget',
              build: (BuildContext c, Object? data, TextStyle s) {
                recue = data;
                return const Text('NEUF', key: Key('cr132-neuf'));
              },
            ),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('cr132-neuf')), findsOneWidget);
      expect(recue, 'charge',
          reason: 'le rendu déclaré reçoit la charge BRUTE de l\'op');
    });
  });

  group('CR-IFFD-132 — effet : sur COLLISION de clé, l\'appelant gagne', () {
    testWidgets('`latex` : le rendu déclaré remplace celui du socle',
        (tester) async {
      await tester.pumpWidget(_host(
        ZMarkdownReader(
          value: _seed('latex', r'\frac{a}{b}'),
          extraEmbedRenderers: <ZEmbedRenderer>[
            ZEmbedRenderer(
              type: 'latex',
              build: (BuildContext c, Object? data, TextStyle s) =>
                  Text('REMPLACE:$data', key: const Key('cr132-collision')),
            ),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const Key('cr132-collision')), findsOneWidget,
          reason: 'le rendu déclaré doit gagner sur celui du socle');
      expect(find.text(r'REMPLACE:\frac{a}{b}'), findsOneWidget);
    });

    test('la règle tient à la PLACE : les rendus déclarés viennent en TÊTE', () {
      // L'éditeur retient le PREMIER builder dont la clé correspond ; c'est
      // cette place, et rien d'autre, qui fait gagner l'appelant.
      final resolus = zEmbedBuildersWith(<ZEmbedRenderer>[
        ZEmbedRenderer(
          type: 'latex',
          build: (BuildContext c, Object? d, TextStyle s) =>
              const SizedBox.shrink(),
        ),
      ]);
      final premierLatex = resolus.firstWhere((b) => b.key == 'latex');
      expect(identical(premierLatex, resolus.first), isTrue);
      expect(kZEmbedBuilders.any((b) => identical(b, premierLatex)), isFalse,
          reason: 'le premier `latex` résolu n\'est PAS celui du socle');
      // Le socle n'est pas amputé : son builder reste dans la liste, derrière.
      expect(resolus.where((b) => b.key == 'latex').length, 2);
    });

    test('entre deux rendus déclarés à même clé, le PREMIER gagne', () {
      final a = ZEmbedRenderer(
        type: 'dup',
        build: (BuildContext c, Object? d, TextStyle s) =>
            const SizedBox.shrink(),
      );
      final b = ZEmbedRenderer(
        type: 'dup',
        build: (BuildContext c, Object? d, TextStyle s) =>
            const SizedBox.shrink(),
      );
      final resolus = zEmbedBuildersWith(<ZEmbedRenderer>[a, b]);
      expect(resolus.firstWhere((x) => x.key == 'dup'), resolus.first);
    });
  });

  group('CR-IFFD-132 — robustesse (AD-10) : un rendu déclaré qui lève', () {
    testWidgets('aucune exception ne remonte, le document reste montable',
        (tester) async {
      await tester.pumpWidget(_host(
        ZMarkdownReader(
          value: _seed('x-casse', 'charge'),
          extraEmbedRenderers: <ZEmbedRenderer>[
            ZEmbedRenderer(
              type: 'x-casse',
              build: (BuildContext c, Object? d, TextStyle s) =>
                  throw StateError('rendu cassé'),
            ),
          ],
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      expect(find.byType(QuillEditor), findsOneWidget);
    });
  });
}
