// CR parité éditeur legacy DODLP (2026-08-11) — priorités 1 et 2 du pilote :
// GAP-3 (placeholder par champ), GAP-4 (boutons Copier/Coller), GAP-1 (interop
// LaTeX `formula`/`formula_inline`), GAP-2 (interop tableau `x-embed-table`).
//
// 🔴 Les Delta d'interop sont COPIÉS du legacy RÉEL (formes MESURÉES) :
// - `formula_embed.dart:250,266` : `CustomBlockEmbed(formulaType, data)` avec
//   `data` = String LaTeX nue → op `{"insert": {"formula": "<latex>"}}` /
//   `{"insert": {"formula_inline": "<latex>"}}` ;
// - `markdown_quill/embeddable_table_syntax.dart:101,104` +
//   `table_view_embed.dart:23,30` : `EmbeddableTable(tableMarkdown)` avec
//   `tableType = 'x-embed-table'` → op `{"insert": {"x-embed-table": "<gfm>"}}`.
// Ils n'épousent PAS notre implémentation : ils épousent l'écriture legacy.
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
// `QuillToolbarClipboardButton` est `@experimental` chez Quill 11.x — même
// justification (locale, mesurée) que le câblage dans `buildZToolbarConfig` :
// si Quill retire l'API, ce fichier rougit et désigne le point exact.
// ignore_for_file: experimental_member_use
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Imports CIBLÉS de l'impl (mêmes règles que z_table_embed_test.dart : un test
// INTERNE au package peut câbler les symboles non exportés par le barrel).
import 'package:zcrud_markdown/src/data/z_table_markdown.dart';
import 'package:zcrud_markdown/src/presentation/z_divider_embed.dart'
    show kUnknownEmbedLabel;
import 'package:zcrud_markdown/src/presentation/z_latex_embed.dart'
    show kLatexInvalidLabel;
import 'package:zcrud_markdown/src/presentation/z_table_embed.dart'
    show kTableInvalidLabel;
import 'package:zcrud_markdown/zcrud_markdown.dart';

// ───────────────────────── Échantillons LEGACY (mesurés) ────────────────────

/// Bloc display legacy : `FormulaBlockEmbed.fromFormula(r'\frac{a}{b}')`.
const List<Map<String, dynamic>> legacyFormulaBlockOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{'formula': r'\frac{a}{b}'},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Inline legacy dans un flux de texte : `FormulaInlineEmbed.fromFormula(...)`.
const List<Map<String, dynamic>> legacyFormulaInlineOps =
    <Map<String, dynamic>>[
  <String, dynamic>{'insert': 'Voir '},
  <String, dynamic>{
    'insert': <String, dynamic>{'formula_inline': 'E=mc^2'},
  },
  <String, dynamic>{'insert': ' ici\n'},
];

/// Markdown GFM tel que le legacy le porte dans `EmbeddableTable(data)`.
const String legacyTableMarkdown =
    '| Col A | Col B |\n|---|---|\n| a1 | b1 |\n| a2 | b2 |\n';

const List<Map<String, dynamic>> legacyTableOps = <Map<String, dynamic>>[
  <String, dynamic>{
    'insert': <String, dynamic>{'x-embed-table': legacyTableMarkdown},
  },
  <String, dynamic>{'insert': '\n'},
];

/// Cellule LaTeX portant un `|` DANS `$...$` — cas que le parseur legacy
/// (`table_view_embed.dart:91-155`) préserve explicitement.
const String legacyTableMathPipe =
    '| Formule | Sens |\n|---|---|\n| \$P(A|B)\$ | proba conditionnelle |\n';

Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillController _quillOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

String? _editorPlaceholder(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).config.placeholder;

/// Callback RÉEL d'un bouton custom de la toolbar rendue (0=LaTeX, 1=table).
VoidCallback _customButtonCallback(WidgetTester tester, int index) {
  final QuillSimpleToolbar toolbar =
      tester.widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar));
  return toolbar.config.customButtons[index].onPressed!;
}


/// Nombre de [Semantics] portant exactement [label] (patron des tests existants
/// — pas de `bySemanticsLabel`, qui exige un arbre sémantique activé).
int _semanticsCount(WidgetTester tester, String label) => tester
    .widgetList<Semantics>(find.byType(Semantics))
    .where((Semantics s) => s.properties.label == label)
    .length;

ZFormController _seeded(Object? value) =>
    ZFormController(initialValues: <String, Object?>{'notes': value});

const ZFieldSpec _field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

void main() {
  group('GAP-1 — interop LaTeX legacy (formula / formula_inline)', () {
    testWidgets(
        'un Delta legacy {insert:{formula:...}} REND une formule (Math), '
        'pas le repli invisible ni le placeholder d\'erreur', (tester) async {
      final controller = _seeded(legacyFormulaBlockOps);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Math), findsOneWidget,
          reason: 'la formule legacy doit être rendue par flutter_math_fork');
      expect(_semanticsCount(tester, kUnknownEmbedLabel), 0,
          reason: 'elle ne doit PAS tomber sur le repli d\'embed inconnu');
      expect(_semanticsCount(tester, kLatexInvalidLabel), 0);
      await _settle(tester);
    });

    testWidgets(
        'un Delta legacy {insert:{formula_inline:...}} REND une formule inline '
        'dans le flux du texte', (tester) async {
      final controller = _seeded(legacyFormulaInlineOps);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Math), findsOneWidget);
      expect(_semanticsCount(tester, kUnknownEmbedLabel), 0);
      await _settle(tester);
    });

    testWidgets(
        'AD-10 : charge formula non-String / vide → placeholder annoté, '
        'jamais de throw', (tester) async {
      final controller = _seeded(const <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'formula': 42},
        },
        <String, dynamic>{
          'insert': <String, dynamic>{'formula_inline': '   '},
        },
        <String, dynamic>{'insert': '\n'},
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(_semanticsCount(tester, kLatexInvalidLabel), 2,
          reason: 'chaque charge illisible rend SON placeholder annoté');
      await _settle(tester);
    });

    testWidgets(
        'sens inverse (migration à SENS UNIQUE) : ÉDITER un embed legacy '
        'ré-écrit sur NOS clés (latexBlock), jamais sur formula', (tester) async {
      final controller = _seeded(legacyFormulaBlockOps);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      // Caret sur l'embed (index 0) puis bouton toolbar « formule » RÉEL.
      _quillOf(tester).updateSelection(
          const TextSelection.collapsed(offset: 0), ChangeSource.local);
      _customButtonCallback(tester, 0)();
      await tester.pump(const Duration(milliseconds: 50));

      // Le dialogue est PRÉ-REMPLI depuis l'embed legacy (détection étendue)…
      expect(find.text(r'\frac{a}{b}'), findsWidgets,
          reason: 'la source legacy doit pré-remplir le dialogue d\'édition');
      // …et la validation REMPLACE l'op par NOTRE clé.
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 50));

      final Object? persisted = controller.valueOf('notes');
      final String json = persisted.toString();
      expect(json, contains('latexBlock'),
          reason: 'l\'écriture doit porter NOTRE clé (mode display préservé)');
      expect(json, isNot(contains('formula')),
          reason: 'zcrud n\'écrit JAMAIS la clé legacy');
      await _settle(tester);
    });
  });

  group('GAP-2 — interop tableau legacy (x-embed-table, string Markdown)', () {
    testWidgets(
        'un Delta legacy {insert:{x-embed-table:"<gfm>"}} REND un Table natif '
        'avec les cellules du Markdown', (tester) async {
      final controller = _seeded(legacyTableOps);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Table), findsOneWidget);
      for (final String t in const <String>[
        'Col A', 'Col B', 'a1', 'b1', 'a2', 'b2', //
      ]) {
        expect(find.text(t), findsOneWidget, reason: 'cellule "$t" manquante');
      }
      // La ligne séparatrice |---|---| ne devient JAMAIS une ligne de cellules.
      final Table table = tester.widget<Table>(find.byType(Table));
      expect(table.children.length, 3, reason: 'en-tête + 2 lignes de corps');
      expect(_semanticsCount(tester, kUnknownEmbedLabel), 0);
      await _settle(tester);
    });

    testWidgets(
        'un `|` DANS `\$...\$` n\'est pas un séparateur de colonne '
        '(port fidèle du parseur legacy)', (tester) async {
      final controller = _seeded(const <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'x-embed-table': legacyTableMathPipe},
        },
        <String, dynamic>{'insert': '\n'},
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text(r'$P(A|B)$'), findsOneWidget,
          reason: 'la cellule LaTeX doit rester UNE cellule');
      final Table table = tester.widget<Table>(find.byType(Table));
      expect(table.children.first.children.length, 2,
          reason: '2 colonnes, pas 3 — le | de la formule ne découpe pas');
      await _settle(tester);
    });

    testWidgets(
        'AD-10 : charge x-embed-table non-String ou vide → placeholder annoté, '
        'jamais de throw', (tester) async {
      final controller = _seeded(const <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{
            'x-embed-table': <String, dynamic>{'pas': 'un string'},
          },
        },
        <String, dynamic>{
          'insert': <String, dynamic>{'x-embed-table': '   '},
        },
        <String, dynamic>{'insert': '\n'},
      ]);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(_semanticsCount(tester, kTableInvalidLabel), 2,
          reason: 'chaque charge illisible rend SON placeholder annoté');
      await _settle(tester);
    });

    testWidgets(
        'sens inverse : ÉDITER un tableau legacy pré-remplit la grille et '
        'ré-écrit un embed `table` structuré (nos clés)', (tester) async {
      final controller = _seeded(legacyTableOps);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _quillOf(tester).updateSelection(
          const TextSelection.collapsed(offset: 0), ChangeSource.local);
      _customButtonCallback(tester, 1)();
      await tester.pump(const Duration(milliseconds: 50));

      // Grille PRÉ-REMPLIE depuis le Markdown legacy converti.
      expect(find.widgetWithText(TextField, 'a1'), findsOneWidget,
          reason: 'la cellule legacy doit pré-remplir la grille d\'édition');
      await tester.tap(find.byType(FilledButton));
      await tester.pump(const Duration(milliseconds: 50));

      final String json = controller.valueOf('notes').toString();
      expect(json, contains('table'));
      expect(json, contains('cells'));
      expect(json, isNot(contains('x-embed-table')),
          reason: 'zcrud n\'écrit JAMAIS la clé legacy');
      await _settle(tester);
    });
  });

  group('GAP-2 — zParseLegacyMarkdownTable (unité, port fidèle)', () {
    test('GFM standard : séparateur ignoré, bords vides retirés, trim', () {
      final List<List<String>>? m =
          zParseLegacyMarkdownTable(legacyTableMarkdown);
      expect(m, isNotNull);
      expect(m, <List<String>>[
        <String>['Col A', 'Col B'],
        <String>['a1', 'b1'],
        <String>['a2', 'b2'],
      ]);
    });

    test(r'un | dans $...$, dans {...} ou échappé \| ne découpe pas', () {
      expect(
        zSplitLegacyTableRow(r'| $a|b$ | x |'),
        <String>[r'$a|b$', 'x'],
      );
      expect(
        zSplitLegacyTableRow(r'| \frac{a|b}{c} | y |'),
        <String>[r'\frac{a|b}{c}', 'y'],
      );
      expect(
        zSplitLegacyTableRow(r'| a\|b | z |'),
        <String>[r'a\|b', 'z'],
      );
      expect(
        zSplitLegacyTableRow(r'| $$u|v$$ | w |'),
        <String>[r'$$u|v$$', 'w'],
      );
    });

    test('lignes jagged NORMALISÉES à la largeur max (padding)', () {
      final List<List<String>>? m =
          zParseLegacyMarkdownTable('| a | b | c |\n| seul |\n');
      expect(m, isNotNull);
      expect(m!.every((List<String> r) => r.length == 3), isTrue,
          reason: 'jamais de matrice jagged (le rendu la refuserait)');
      expect(m[1], <String>['seul', '', '']);
    });

    test('AD-10 : vide / blanc → null (on ne FABRIQUE pas un tableau)', () {
      expect(zParseLegacyMarkdownTable(''), isNull);
      expect(zParseLegacyMarkdownTable('   \n  \n'), isNull);
    });
  });

  group('GAP-3 — placeholder par champ (paramètre > hintText l10n > rien)', () {
    testWidgets('field.hintText est RÉSOLU et câblé sur l\'éditeur',
        (tester) async {
      final controller = _seeded(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: const ZFieldSpec(
          name: 'notes',
          type: EditionFieldType.text,
          hintText: 'Texte indicatif du champ',
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_editorPlaceholder(tester), 'Texte indicatif du champ',
          reason: 'hintText (littéral : fallback == clé) doit être câblé');
      // Le placeholder est RENDU dans l'éditeur vide.
      expect(
        find.text('Texte indicatif du champ', findRichText: true),
        findsOneWidget,
      );
      await _settle(tester);
    });

    testWidgets('le paramètre `placeholder` L\'EMPORTE sur hintText',
        (tester) async {
      final controller = _seeded(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        placeholder: 'Priorité au paramètre',
        field: const ZFieldSpec(
          name: 'notes',
          type: EditionFieldType.text,
          hintText: 'Perdant',
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_editorPlaceholder(tester), 'Priorité au paramètre');
      await _settle(tester);
    });

    testWidgets('ni paramètre ni hintText → AUCUN placeholder (historique)',
        (tester) async {
      final controller = _seeded(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_editorPlaceholder(tester), isNull);
      await _settle(tester);
    });

    testWidgets('le dialog plein-écran porte le placeholder fourni',
        (tester) async {
      await tester.pumpWidget(_host(const ZRichTextFullscreenDialog(
        initialValue: null,
        placeholder: 'Placeholder plein-écran',
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_editorPlaceholder(tester), 'Placeholder plein-écran');
      await _settle(tester);
    });
  });

  group('GAP-4 — boutons Copier/Coller de la toolbar', () {
    testWidgets(
        'préset full (défaut voie controller) : Copier + Coller PRÉSENTS '
        '(2 boutons clipboard, pas de Couper)', (tester) async {
      final controller = _seeded(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(QuillToolbarClipboardButton), findsNWidgets(2),
          reason: 'full ⇒ Copier + Coller (parité legacy qmew:227-228)');
      await _settle(tester);
    });

    testWidgets('préset minimal : AUCUN bouton clipboard', (tester) async {
      final controller = _seeded(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
        toolbarConfig: ZRichTextToolbarConfig.minimal,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(QuillToolbarClipboardButton), findsNothing);
      await _settle(tester);
    });

    testWidgets('drapeaux individuels honorés (copy sans paste)',
        (tester) async {
      final controller = _seeded(null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
        toolbarConfig: const ZRichTextToolbarConfig(showClipboardPaste: false),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(QuillToolbarClipboardButton), findsOneWidget);
      await _settle(tester);
    });

    test('config : défauts, présets, copyWith, égalité', () {
      const ZRichTextToolbarConfig def = ZRichTextToolbarConfig();
      expect(def.showClipboardCopy, isTrue,
          reason: 'défaut true — cohérent avec le contrat du préset full');
      expect(def.showClipboardPaste, isTrue);
      expect(ZRichTextToolbarConfig.minimal.showClipboardCopy, isFalse);
      expect(ZRichTextToolbarConfig.minimal.showClipboardPaste, isFalse);
      expect(ZRichTextToolbarConfig.markdown.showClipboardCopy, isTrue);
      expect(ZRichTextToolbarConfig.markdown.showClipboardPaste, isTrue);

      final ZRichTextToolbarConfig noCopy =
          def.copyWith(showClipboardCopy: false);
      expect(noCopy.showClipboardCopy, isFalse);
      expect(noCopy.showClipboardPaste, isTrue);
      expect(noCopy, isNot(equals(def)));
      expect(noCopy.copyWith(showClipboardCopy: true), equals(def));
    });
  });
}
