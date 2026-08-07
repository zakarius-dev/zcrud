// CR-IFFD-73 — le rendu riche DIFFÈRE RÉELLEMENT du rendu neutre.
//
// 🔴 La garde qui compte n'est pas « le renderer est monté » : c'est que, sur le
// MÊME message, le pixel change. Chaque test ci-dessous monte DEUX fois le même
// `ZChatBlockView` — une fois sans scope (rendu neutre du socle), une fois avec
// `ZChatMarkdownRenderer` — et compare ce qui est PEINT.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_markdown/zcrud_chat_markdown.dart';

import 'support/render_probe.dart';

ZChatBlockRenderRequest _req(
  ZContentBlock block, {
  ZChatRole role = ZChatRole.assistant,
}) => ZChatBlockRenderRequest(
  block: block,
  message: ZChatMessage(id: 'm1', conversationId: 'c1', role: role),
);

Future<void> _mount(
  WidgetTester tester,
  ZContentBlock block, {
  ZChatMarkdownRenderer? renderer,
  ZChatRole role = ZChatRole.assistant,
}) async {
  final Widget view = ZChatBlockView(request: _req(block, role: role));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: renderer == null
              ? view
              : ZChatRendererScope(renderer: renderer, child: view),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const String kMessage =
      '**Introduction**\n\nLe commerce international est essentiel.';

  group('🔴 CR-IFFD-73 — le rendu riche DIFFÈRE du rendu neutre', () {
    testWidgets(
      'RÉFÉRENCE NEUTRE : le socle peint le texte SOURCE, sans gras',
      (WidgetTester tester) async {
        await _mount(tester, const ZTextBlock(text: kMessage));
        final String painted = paintedText(tester);
        expect(
          painted,
          contains('**Introduction**'),
          reason:
              'C\'est le défaut mesuré sur appareil par CR-IFFD-73 : le rendu '
              'neutre peint les astérisques. Si cette assertion tombe, le socle '
              'a changé et la comparaison ci-dessous perd son point de départ.',
        );
        expect(
          hasBold(tester, 'Introduction'),
          isFalse,
          reason: 'Le rendu neutre ne met rien en gras — il n\'interprète pas '
              'le Markdown (z_chat_block_view.dart, dartdoc de tête).',
        );
      },
    );

    testWidgets(
      'RICHE : les astérisques DISPARAISSENT et « Introduction » est en GRAS',
      (WidgetTester tester) async {
        await _mount(
          tester,
          const ZTextBlock(text: kMessage),
          renderer: const ZChatMarkdownRenderer(),
        );
        final String painted = paintedText(tester);
        // (1) la syntaxe a été CONSOMMÉE, pas affichée.
        expect(
          painted,
          isNot(contains('**')),
          reason: '🔴 le rendu riche peint encore la syntaxe source : '
              'peint = "$painted"',
        );
        // (2) le texte est toujours là.
        expect(painted, contains('Introduction'));
        expect(painted, contains('Le commerce international est essentiel.'));
        // (3) et il est réellement PEINT EN GRAS — la propriété que le rendu
        //     neutre ne peut pas produire.
        expect(
          hasBold(tester, 'Introduction'),
          isTrue,
          reason: '🔴 « Introduction » n\'est pas peint en gras. '
              'Spans: ${paintedSpans(tester)}',
        );
      },
    );

    testWidgets('les DEUX rendus ne peignent PAS la même chose', (
      WidgetTester tester,
    ) async {
      await _mount(tester, const ZTextBlock(text: kMessage));
      final String neutral = paintedText(tester);
      final bool neutralBold = hasBold(tester, 'Introduction');

      await _mount(
        tester,
        const ZTextBlock(text: kMessage),
        renderer: const ZChatMarkdownRenderer(),
      );
      final String rich = paintedText(tester);
      final bool richBold = hasBold(tester, 'Introduction');

      expect(
        rich,
        isNot(equals(neutral)),
        reason: 'Si les deux chaînes peintes sont identiques, le satellite '
            'n\'a AUCUN effet — c\'est exactement la vacance que CR-IFFD-73 '
            'reproche à la table d\'implémentations du port.',
      );
      expect(neutralBold, isFalse);
      expect(richBold, isTrue);
    });
  });

  group('🔴 CR-IFFD-73 — le texte TAPÉ par l\'utilisateur reste LITTÉRAL', () {
    testWidgets('un message `user` n\'est PAS interprété (asté­risques gardés)',
        (WidgetTester tester) async {
      await _mount(
        tester,
        const ZTextBlock(text: kMessage),
        renderer: const ZChatMarkdownRenderer(),
        role: ZChatRole.user,
      );
      expect(
        paintedText(tester),
        contains('**Introduction**'),
        reason: '🔴 L\'utilisateur a TAPÉ ces astérisques. Les manger, c\'est '
            'une perte silencieuse sur la seule donnée dont il connaît la '
            'forme exacte.',
      );
      expect(hasBold(tester, 'Introduction'), isFalse);
    });

    testWidgets('… et un message `assistant`, LUI, est interprété (contraste)',
        (WidgetTester tester) async {
      await _mount(
        tester,
        const ZTextBlock(text: kMessage),
        renderer: const ZChatMarkdownRenderer(),
      );
      expect(paintedText(tester), isNot(contains('**')));
      expect(hasBold(tester, 'Introduction'), isTrue);
    });

    testWidgets('`roles` explicite permet d\'INCLURE `user` (effet observable)',
        (WidgetTester tester) async {
      await _mount(
        tester,
        const ZTextBlock(text: kMessage),
        renderer: const ZChatMarkdownRenderer(
          roles: <ZChatRole>{ZChatRole.user},
        ),
        role: ZChatRole.user,
      );
      expect(paintedText(tester), isNot(contains('**')));
      expect(hasBold(tester, 'Introduction'), isTrue);
    });

    testWidgets('un rôle `unknown` EST interprété (repli du kernel)', (
      WidgetTester tester,
    ) async {
      await _mount(
        tester,
        const ZTextBlock(text: kMessage),
        renderer: const ZChatMarkdownRenderer(),
        role: ZChatRole.unknown,
      );
      expect(paintedText(tester), isNot(contains('**')));
    });
  });

  group('CR-IFFD-73 — l\'étendue du Markdown réellement rendue', () {
    testWidgets('titres, listes, citation, italique : syntaxe consommée', (
      WidgetTester tester,
    ) async {
      const String md = '## Titre\n\n'
          '- premier\n- second\n\n'
          '> citation\n\n'
          'du *penché* et du **gras**';
      await _mount(
        tester,
        const ZTextBlock(text: md),
        renderer: const ZChatMarkdownRenderer(),
      );
      final String painted = paintedText(tester);
      for (final String syntax in <String>['##', '**', '> ']) {
        expect(
          painted,
          isNot(contains(syntax)),
          reason: 'syntaxe « $syntax » encore peinte : "$painted"',
        );
      }
      expect(painted, contains('Titre'));
      expect(painted, contains('premier'));
      expect(painted, contains('citation'));
      expect(
        paintedSpans(tester).any(
          (PaintedSpan s) =>
              s.text.contains('penché') && s.style == FontStyle.italic,
        ),
        isTrue,
        reason: 'l\'italique n\'est pas peint : ${paintedSpans(tester)}',
      );
    });
  });

  group('CR-IFFD-73 — LaTeX : déclaré par défaut, débrayable', () {
    testWidgets('par défaut, `\$\$…\$\$` n\'est plus peint littéralement', (
      WidgetTester tester,
    ) async {
      await _mount(
        tester,
        const ZTextBlock(text: r'Valeur en douane : $$V = P + F + A$$'),
        renderer: const ZChatMarkdownRenderer(),
      );
      final String painted = paintedText(tester);
      expect(
        painted,
        isNot(contains(r'$$')),
        reason: '🔴 la formule est peinte en source : "$painted"',
      );
      expect(painted, contains('Valeur en douane'));
    });

    testWidgets('`latex: false` REMET la formule en texte littéral', (
      WidgetTester tester,
    ) async {
      await _mount(
        tester,
        const ZTextBlock(text: r'Valeur en douane : $$V = P + F + A$$'),
        renderer: const ZChatMarkdownRenderer(latex: false),
      );
      expect(
        paintedText(tester),
        contains(r'$$V = P + F + A$$'),
        reason: 'Le drapeau doit avoir un effet OBSERVABLE, sinon il ment.',
      );
    });

    testWidgets('un PRIX n\'est pas transformé en formule (garde mesurée)', (
      WidgetTester tester,
    ) async {
      await _mount(
        tester,
        const ZTextBlock(text: r'Le prix va de 5$ a 9$ selon le fournisseur.'),
        renderer: const ZChatMarkdownRenderer(),
      );
      expect(
        paintedText(tester),
        contains(r'5$ a 9$'),
        reason: '🔴 le pont LaTeX a mangé un montant — c\'est l\'ambiguïté du '
            '`\$` que `zLatexPayloadLooksLikeFormula` doit arbitrer.',
      );
    });
  });

  group('CR-IFFD-73 — périmètre de blocs : ce qui n\'est pas couvert RETOMBE',
      () {
    // 🔴 Relevé sur le dépôt : `ZTextBlock` est le SEUL `kind` PRODUIT par une
    // ligne de code (ZChatController + z_iffd_stream_port). Les autres n'existent
    // qu'au bout d'une désérialisation. Ils doivent retomber sur le neutre.
    final List<ZContentBlock> notCovered = <ZContentBlock>[
      const ZTableBlock(
        title: 'T',
        headers: <String>['a', 'b'],
        rows: <List<String>>[
          <String>['1', '2'],
        ],
      ),
      const ZKeyDefinitionBlock(term: 'OMC', definition: 'Organisation.'),
      const ZAlertBlock(level: 'info', title: 'Att', message: 'Message.'),
      const ZMermaidDiagramBlock(title: 'D', code: 'graph TD; A_1-->B_2;'),
      const ZTimelineBlock(
        title: 'Chrono',
        events: <ZTimelineEvent>[ZTimelineEvent(date: '1995', title: 'OMC')],
      ),
      ZCustomContentBlock('legalReference', const <String, dynamic>{'a': 1}),
    ];

    for (final ZContentBlock block in notCovered) {
      testWidgets('« ${block.kind} » rend EXACTEMENT comme sans satellite', (
        WidgetTester tester,
      ) async {
        await _mount(tester, block);
        final String neutral = paintedText(tester);
        await _mount(
          tester,
          block,
          renderer: const ZChatMarkdownRenderer(),
        );
        expect(
          paintedText(tester),
          equals(neutral),
          reason: 'AD-10/AD-57 : un `kind` non couvert doit DÉCLINER et laisser '
              'le rendu neutre intact, jamais le remplacer ni casser.',
        );
      });
    }

    testWidgets(
      '🔬 CONTRÔLE POSITIF : la comparaison ci-dessus SAIT voir une différence',
      (WidgetTester tester) async {
        // Sans ce contrôle, les tests de repli seraient verts même si
        // `paintedText` rendait toujours la chaîne vide.
        await _mount(tester, const ZTextBlock(text: kMessage));
        final String neutral = paintedText(tester);
        await _mount(
          tester,
          const ZTextBlock(text: kMessage),
          renderer: const ZChatMarkdownRenderer(),
        );
        expect(paintedText(tester), isNot(equals(neutral)));
        expect(neutral, isNotEmpty);
      },
    );

    testWidgets('un code Mermaid n\'est PAS altéré par le satellite', (
      WidgetTester tester,
    ) async {
      // Le `_` d'un identifiant serait de l'italique en Markdown : le décliner
      // n'est pas une économie, c'est ce qui PRÉSERVE la donnée.
      const ZContentBlock block = ZMermaidDiagramBlock(
        code: 'graph TD; noeud_a-->noeud_b;',
      );
      await _mount(tester, block, renderer: const ZChatMarkdownRenderer());
      expect(paintedText(tester), contains('noeud_a-->noeud_b'));
    });
  });

  group('CR-IFFD-73 — AD-10 : jamais de throw, jamais d\'écran rouge', () {
    const List<String> malformed = <String>[
      '**',
      '***',
      '```dart\nfinal x = 1;',
      '| a | b |',
      '| a | b |\n|---|---|',
      'voir [OMC](https://',
      r'valeur $$V = P',
      r'$$\frac{',
      '##########',
      '> > >',
      '**_~~`',
      '&amp',
      '<div>',
    ];

    for (final String frag in malformed) {
      testWidgets('fragment ${jsonish(frag)} ne lève pas', (
        WidgetTester tester,
      ) async {
        await _mount(
          tester,
          ZTextBlock(text: frag),
          renderer: const ZChatMarkdownRenderer(),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '🔴 AD-10 : un fragment de Markdown incomplet ne doit JAMAIS '
              'lever — c\'est l\'état normal pendant un flux.',
        );
      });
    }

    testWidgets('un texte VIDE décline (aucun libellé inventé — FR-26)', (
      WidgetTester tester,
    ) async {
      await _mount(tester, const ZTextBlock());
      final String neutral = paintedText(tester);
      await _mount(
        tester,
        const ZTextBlock(),
        renderer: const ZChatMarkdownRenderer(),
      );
      expect(paintedText(tester), equals(neutral));
      expect(paintedText(tester), isNot(contains('Aucun contenu')));
    });
  });
}

/// Représentation compacte d'un fragment pour un nom de test.
String jsonish(String s) => '«${s.replaceAll('\n', r'\n')}»';
