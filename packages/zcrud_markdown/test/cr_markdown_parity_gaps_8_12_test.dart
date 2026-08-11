// CR parité éditeur legacy DODLP (2026-08-11) — GAP-8 à GAP-12 (finitions).
//
// GAP-8  : barré RETIRÉ des défauts (`full`/constructeur/`markdown`) — parité
//          `qmew:85` ; opt-in `copyWith(showStrikethrough: true)`.
// GAP-9  : habillage de barre OPT-IN — icônes `*_rounded` (SANS tooltip posé :
//          ceux de Quill, localisés, restent), multi-rangées, fond thémé
//          (rôles du thème, zéro couleur en dur). Défauts inchangés.
// GAP-10 : icône du bouton tableau = `table_chart_rounded` (parité `qmew:249`).
// GAP-11 : lecture seule — appui long OPT-IN = copie (payload encodé codec) +
//          retour SnackBar si libellé INJECTÉ et messenger présent ; silencieux
//          sinon. `Semantics` du geste exposé.
// GAP-12 : état vide de lecture enrichi OPT-IN (icône/sous-titre/builder) —
//          défaut HISTORIQUE strictement gardé.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
// Traduction interne toolbar (légitime : tests du package porteur de Quill).
import 'package:zcrud_markdown/src/presentation/z_rich_text_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillSimpleToolbarConfig _translated(ZRichTextToolbarConfig config) =>
    buildZToolbarConfig(
      onInsertLatex: () {},
      onInsertTable: () {},
      config: config,
    );

/// Capture les appels `Clipboard.setData` (canal platform mocké).
List<String> _mockClipboard(WidgetTester tester) {
  final captured = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      if (call.method == 'Clipboard.setData') {
        captured.add((call.arguments as Map)['text'] as String);
      }
      return null;
    },
  );
  return captured;
}

void main() {
  group('GAP-8 — barré retiré des défauts (parité qmew:85)', () {
    test('full, constructeur nu et markdown ont showStrikethrough=false', () {
      expect(ZRichTextToolbarConfig.full.showStrikethrough, isFalse);
      expect(const ZRichTextToolbarConfig().showStrikethrough, isFalse);
      expect(ZRichTextToolbarConfig.markdown.showStrikethrough, isFalse);
      expect(ZRichTextToolbarConfig.minimal.showStrikethrough, isFalse);
    });

    test('la traduction Quill du préset full masque le bouton barré, et '
        'l\'opt-in copyWith le réactive', () {
      expect(_translated(ZRichTextToolbarConfig.full).showStrikeThrough,
          isFalse);
      expect(
        _translated(ZRichTextToolbarConfig.full
                .copyWith(showStrikethrough: true))
            .showStrikeThrough,
        isTrue,
      );
    });
  });

  group('GAP-9 — habillage de barre opt-in', () {
    test('défaut : icônes Quill inchangées, mono-rangée, aucune option posée',
        () {
      final QuillSimpleToolbarConfig cfg =
          _translated(ZRichTextToolbarConfig.full);
      expect(cfg.multiRowsDisplay, isFalse);
      expect(cfg.buttonOptions.bold.iconData, isNull,
          reason: 'sans opt-in, AUCUNE icône custom ne doit être posée');
      expect(ZRichTextToolbarConfig.full.roundedIcons, isFalse);
      // CR 2026-08-11 : `multiRow` est devenu TRI-ÉTAT — défaut `null` = AUTO
      // par surface (une rangée en flux, multi-rangées en plein écran). La
      // traduction SANS surface déclarée (`autoMultiRow` par défaut) reste
      // mono-rangée (assertion `multiRowsDisplay` ci-dessus, inchangée).
      expect(ZRichTextToolbarConfig.full.multiRow, isNull);
      expect(ZRichTextToolbarConfig.full.themedBarBackground, isFalse);
    });

    test('roundedIcons : jeu legacy mesuré posé, SANS tooltip (l10n Quill '
        'préservée) ; multiRow traduit', () {
      final QuillSimpleToolbarConfig cfg = _translated(
        ZRichTextToolbarConfig.full
            .copyWith(roundedIcons: true, multiRow: true),
      );
      expect(cfg.multiRowsDisplay, isTrue);
      final o = cfg.buttonOptions;
      expect(o.bold.iconData, Icons.format_bold_rounded);
      expect(o.italic.iconData, Icons.format_italic_rounded);
      expect(o.underLine.iconData, Icons.format_underlined_rounded);
      expect(o.strikeThrough.iconData, Icons.format_strikethrough_rounded);
      expect(o.inlineCode.iconData, Icons.code_rounded);
      expect(o.codeBlock.iconData, Icons.integration_instructions_rounded);
      expect(o.quote.iconData, Icons.format_quote_rounded);
      expect(o.listNumbers.iconData, Icons.format_list_numbered_rounded);
      expect(o.listBullets.iconData, Icons.format_list_bulleted_rounded);
      expect(o.toggleCheckList.iconData, Icons.checklist_rounded);
      expect(o.indentIncrease.iconData, Icons.format_indent_increase_rounded);
      expect(o.indentDecrease.iconData, Icons.format_indent_decrease_rounded);
      expect(o.linkStyle.iconData, Icons.link_rounded);
      expect(o.undoHistory.iconData, Icons.undo_rounded);
      expect(o.redoHistory.iconData, Icons.redo_rounded);
      expect(o.clearFormat.iconData, Icons.format_clear_rounded);
      // ignore: experimental_member_use
      expect(o.clipboardCopy.iconData, Icons.copy_rounded);
      // ignore: experimental_member_use
      expect(o.clipboardPaste.iconData, Icons.paste_rounded);
      // 🔴 AUCUN libellé posé : les tooltips restent ceux de Quill (localisés).
      expect(o.bold.tooltip, isNull);
      expect(o.italic.tooltip, isNull);
      expect(o.undoHistory.tooltip, isNull);
      // Bouton custom LaTeX : variante rounded sous le même opt-in.
      final Icon latexIcon = cfg.customButtons.first.icon! as Icon;
      expect(latexIcon.icon, Icons.functions_rounded);
    });

    testWidgets('themedBarBackground : fond + liseré dérivés des RÔLES du '
        'thème (opt-in), absent par défaut', (tester) async {
      Widget bar(bool on) => Builder(
            builder: (context) => zDecorateToolbar(
              context,
              ZRichTextToolbarConfig.full
                  .copyWith(themedBarBackground: on),
              const SizedBox(width: 10, height: 10),
            ),
          );
      await tester.pumpWidget(_host(bar(false)));
      expect(find.byType(DecoratedBox), findsNothing,
          reason: 'défaut : AUCUN wrapper — rendu historique');
      await tester.pumpWidget(_host(bar(true)));
      final DecoratedBox box =
          tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final BoxDecoration deco = box.decoration as BoxDecoration;
      final ColorScheme scheme = ThemeData().colorScheme;
      expect(deco.color, scheme.surfaceContainerLow);
      expect(deco.border!.bottom.color, scheme.outlineVariant);
    });
  });

  group('GAP-10 — icône du bouton tableau', () {
    test('bouton custom tableau = table_chart_rounded (parité qmew:249)', () {
      final QuillSimpleToolbarConfig cfg =
          _translated(ZRichTextToolbarConfig.full);
      final QuillToolbarCustomButtonOptions table = cfg.customButtons
          .firstWhere((b) => b.tooltip == 'Insérer un tableau');
      expect((table.icon! as Icon).icon, Icons.table_chart_rounded);
    });
  });

  group('GAP-11 — copie en lecture seule (appui long, opt-in)', () {
    const String md = 'Bonjour **gras**';

    testWidgets('opt-in + ZMarkdownCodec : appui long copie le string '
        'Markdown encodé + SnackBar au libellé INJECTÉ', (tester) async {
      final captured = _mockClipboard(tester);
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: md,
        codec: ZMarkdownCodec(),
        copyOnLongPress: true,
        copiedFeedbackText: 'Contenu copié',
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.longPress(
          find.byKey(const Key('z-markdown-reader-copy-gesture')));
      await tester.pump();
      expect(captured, hasLength(1));
      expect(captured.single, contains('**gras**'),
          reason: 'payload = valeur ENCODÉE par le codec (Markdown, parité '
              'legacy « Contenu Markdown copié »)');
      await tester.pump();
      expect(find.text('Contenu copié'), findsOneWidget,
          reason: 'retour SnackBar via ScaffoldMessenger + libellé injecté');
      await _settle(tester);
    });

    testWidgets('libellé absent ⇒ copie SILENCIEUSE (aucun SnackBar, aucun '
        'crash)', (tester) async {
      final captured = _mockClipboard(tester);
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: md,
        codec: ZMarkdownCodec(),
        copyOnLongPress: true,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.longPress(
          find.byKey(const Key('z-markdown-reader-copy-gesture')));
      await tester.pump();
      expect(captured, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      await _settle(tester);
    });

    testWidgets('codec Delta (encodage non-String) : payload = Delta JSON '
        'sérialisé — on ne FABRIQUE pas un Markdown', (tester) async {
      final captured = _mockClipboard(tester);
      final List<Map<String, dynamic>> delta = <Map<String, dynamic>>[
        <String, dynamic>{'insert': 'Texte\n'},
      ];
      await tester.pumpWidget(_host(ZMarkdownReader(
        value: delta,
        copyOnLongPress: true,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.longPress(
          find.byKey(const Key('z-markdown-reader-copy-gesture')));
      await tester.pump();
      expect(captured, hasLength(1));
      expect(jsonDecode(captured.single), delta);
      await _settle(tester);
    });

    testWidgets('défaut (sans opt-in) : AUCUN geste de copie monté',
        (tester) async {
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: md,
        codec: ZMarkdownCodec(),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('z-markdown-reader-copy-gesture')),
          findsNothing);
      await _settle(tester);
    });

    testWidgets('Semantics : action longPress exposée + hint INJECTÉ',
        (tester) async {
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: md,
        codec: ZMarkdownCodec(),
        copyOnLongPress: true,
        copySemanticsLabel: 'Copier le contenu',
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final SemanticsNode node = tester.getSemantics(
          find.byKey(const Key('z-markdown-reader-copy-gesture')));
      expect(node.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue);
      await _settle(tester);
    });
  });

  group('GAP-12 — état vide de lecture enrichi (opt-in)', () {
    testWidgets('défaut STRICTEMENT inchangé : placeholder seul, aucune icône',
        (tester) async {
      await tester.pumpWidget(_host(const ZMarkdownReader(value: null)));
      await tester.pump();
      expect(find.text('Aucun contenu'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(Center), findsNothing,
          reason: 'le défaut reste aligné début, pas centré');
      await _settle(tester);
    });

    testWidgets('emptyIcon + emptySubtitle : icône + deux lignes (libellés '
        'INJECTÉS)', (tester) async {
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: null,
        placeholder: 'Rien ici',
        emptyIcon: Icons.notes_rounded,
        emptySubtitle: 'Appuyez sur Rédiger',
      )));
      await tester.pump();
      expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
      expect(find.text('Rien ici'), findsOneWidget);
      expect(find.text('Appuyez sur Rédiger'), findsOneWidget);
      // Couleur de l'icône : rôle du thème (FR-26), pas une couleur en dur.
      final Icon icon = tester.widget<Icon>(find.byIcon(Icons.notes_rounded));
      expect(icon.color, ThemeData().colorScheme.onSurfaceVariant);
      await _settle(tester);
    });

    testWidgets('emptyBuilder : PRIORITAIRE sur icône/sous-titre',
        (tester) async {
      await tester.pumpWidget(_host(ZMarkdownReader(
        value: null,
        emptyIcon: Icons.notes_rounded,
        emptyBuilder: (context) =>
            const Text('Vide custom', key: Key('custom-empty')),
      )));
      await tester.pump();
      expect(find.byKey(const Key('custom-empty')), findsOneWidget);
      expect(find.byIcon(Icons.notes_rounded), findsNothing);
      await _settle(tester);
    });

    testWidgets('valeur NON vide : aucun état vide (enrichi ou non)',
        (tester) async {
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: 'Du contenu',
        codec: ZMarkdownCodec(),
        emptyIcon: Icons.notes_rounded,
        emptySubtitle: 'jamais montré',
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.notes_rounded), findsNothing);
      expect(find.text('jamais montré'), findsNothing);
      await _settle(tester);
    });
  });
}
