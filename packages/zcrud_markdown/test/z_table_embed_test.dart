// E6-4 — Embed tableau : rendu (`Table` natif), insertion/édition via
// toolbar+dialogue, rendu DÉFENSIF (AD-10 : structure invalide/vide/absente/
// irrégulière → placeholder, jamais de throw), neutralité runtime de la tranche
// (AC7), SM-1 non régressé (AC8) et a11y/RTL/thème (AC9).
//
// Les frappes/insertions empruntent le `QuillController` RÉEL rendu par le champ
// (membre public de flutter_quill) — EXACTEMENT la voie interne. Le widget
// `Table` provient du framework Flutter (zéro dépendance ajoutée — AD-1).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Import CIBLÉ de l'impl (même package) : le barrel n'exporte pas
// `ZTableEmbedBuilder`/`kTableInvalidLabel` (isolation AD-1). Un test INTERNE au
// package a le droit de câbler l'`EmbedBuilder` réel pour prouver le rendu
// readOnly (AC2) et le label a11y (AC9) directement.
import 'package:zcrud_markdown/src/presentation/z_table_embed.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'fixtures/rich_corpus.dart';

Widget _host(Widget child,
        {TextDirection dir = TextDirection.ltr, ThemeData? theme}) =>
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: dir,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillController _quillOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(QuillEditor)
      : find.descendant(
          of: find.byKey(ofKey), matching: find.byType(QuillEditor));
  return tester.widget<QuillEditor>(finder).controller;
}

FocusNode _focusOf(WidgetTester tester, {Key? ofKey}) {
  final finder = ofKey == null
      ? find.byType(QuillEditor)
      : find.descendant(
          of: find.byKey(ofKey), matching: find.byType(QuillEditor));
  return tester.widget<QuillEditor>(finder).focusNode;
}

Iterable<EmbedBuilder>? _embedBuildersOf(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor)).config.embedBuilders;

/// Déclenche le bouton « Tableau » de la toolbar en invoquant SON callback RÉEL
/// (`options.onPressed` = `_promptAndInsertTable` du champ) — voie de production
/// exacte, robuste au défilement/hit-test de la toolbar Quill (2 boutons custom).
void _pressTableButton(WidgetTester tester) {
  final btn = tester
      .widgetList<QuillToolbarCustomButton>(
          find.byType(QuillToolbarCustomButton))
      .firstWhere((b) => b.options.tooltip == 'Insérer un tableau');
  btn.options.onPressed!.call();
}

const _fieldA = ZFieldSpec(name: 'notes', type: EditionFieldType.text);
const _fieldB = ZFieldSpec(name: 'autre', type: EditionFieldType.text);

/// Construit un seed d'op tableau `{insert:{table:<struct>}}` + `\n`.
List<Map<String, dynamic>> _tableSeed(Object? structure) => <Map<String, dynamic>>[
      <String, dynamic>{
        'insert': <String, dynamic>{'table': structure},
      },
      <String, dynamic>{'insert': '\n'},
    ];

void main() {
  group('AC2 — rendu de l\'embed via widget Table natif', () {
    testWidgets('op {insert:{table:...}} → widget Table (dims + textes)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': tableTypeEmbedOps},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(Table), findsOneWidget,
          reason: 'le tableau doit être rendu comme un widget Table');
      for (final t in const <String>['a', 'b', 'c', 'd']) {
        expect(find.text(t), findsOneWidget, reason: 'cellule "$t" manquante');
      }
      // Pas le littéral "table" affiché en texte brut.
      expect(find.text('table'), findsNothing);
      await _settle(tester);
    });

    testWidgets('les embedBuilders latex + table sont câblés (édition ET lecture)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': tableTypeEmbedOps},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final builders = _embedBuildersOf(tester);
      expect(builders, isNotNull);
      expect(builders!.any((b) => b.key == 'table'), isTrue,
          reason: 'un EmbedBuilder de clé `table` doit servir édition + lecture');
      expect(builders.any((b) => b.key == 'latex'), isTrue,
          reason: 'l\'embed LaTeX (E6-3) ne doit pas avoir disparu');
      await _settle(tester);
    });

    testWidgets(
        'RENDU RÉEL en LECTURE (readOnly) : embed table → widget Table affiché',
        (tester) async {
      // AC2 exige un rendu prouvé « en édition ET en LECTURE ». Ici on monte un
      // `QuillEditor` en LECTURE SEULE câblé sur l'`EmbedBuilder` RÉEL.
      final controller = QuillController(
        document: Document.fromJson(tableTypeEmbedOps),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      addTearDown(controller.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          FlutterQuillLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: QuillEditor(
              controller: controller,
              focusNode: focus,
              scrollController: scroll,
              config: const QuillEditorConfig(
                scrollable: false,
                embedBuilders: <EmbedBuilder>[ZTableEmbedBuilder()],
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.readOnly, isTrue);
      expect(find.byType(Table), findsOneWidget,
          reason: 'le tableau doit être RÉELLEMENT rendu en lecture (readOnly)');
      expect(find.text('a'), findsOneWidget);
      await _settle(tester);
    });
  });

  group('AC3 — insertion / édition via toolbar + dialogue', () {
    testWidgets('bouton toolbar → dialogue → op table insérée + rendu Table',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.grid_on), findsOneWidget,
          reason: 'bouton « Tableau » absent de la toolbar');
      _pressTableButton(tester);
      await tester.pumpAndSettle();

      // Dialogue par défaut 2×2 : remplit les 4 cellules keyées puis OK.
      const cellText = <String, String>{
        'ztable-cell-0-0': 'a',
        'ztable-cell-0-1': 'b',
        'ztable-cell-1-0': 'c',
        'ztable-cell-1-1': 'd',
      };
      for (final e in cellText.entries) {
        await tester.enterText(find.byKey(ValueKey<String>(e.key)), e.value);
      }
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final tableOp = value.firstWhere(
        (op) => op['insert'] is Map && (op['insert'] as Map)['table'] is Map,
        orElse: () => <String, dynamic>{},
      );
      expect(tableOp.isNotEmpty, isTrue, reason: 'op {insert:{table:...}} absente');
      final struct = (tableOp['insert'] as Map)['table'] as Map;
      expect(
        struct['cells'],
        equals(<List<String>>[
          <String>['a', 'b'],
          <String>['c', 'd'],
        ]),
      );
      expect(find.byType(Table), findsOneWidget);

      // AC7 — la tranche reste NEUTRE + JSON-safe après insertion d'un embed.
      expect(value, isA<List<Map<String, dynamic>>>());
      expect(jsonDecode(jsonEncode(value)), equals(value));

      await _settle(tester);
    });

    testWidgets(
        'édition d\'un embed existant : dialogue PRÉ-REMPLI → op remplacée',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': tableTypeEmbedOps},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      // Caret JUSTE APRÈS l'embed (offset 1) ⇒ cible d'édition détectée.
      _quillOf(tester).updateSelection(
        const TextSelection.collapsed(offset: 1),
        ChangeSource.local,
      );
      await tester.pump();

      _pressTableButton(tester);
      await tester.pumpAndSettle();

      // Dialogue PRÉ-REMPLI avec la structure existante.
      final tf =
          tester.widget<TextField>(find.byKey(const ValueKey('ztable-cell-0-0')));
      expect(tf.controller!.text, 'a');

      await tester.enterText(
          find.byKey(const ValueKey('ztable-cell-0-0')), 'Z');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final struct = value
          .map((op) => op['insert'])
          .whereType<Map<String, dynamic>>()
          .map((m) => m['table'])
          .whereType<Map<String, dynamic>>()
          .first;
      final cells = struct['cells'] as List;
      expect((cells.first as List).first, 'Z',
          reason: 'l\'ancienne op n\'a pas été remplacée (édition ratée)');
      await _settle(tester);
    });

    testWidgets('annuler le dialogue → AUCUNE mutation de la tranche',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final before = controller.valueOf('notes');

      _pressTableButton(tester);
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('ztable-cell-0-0')), 'ignored');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.valueOf('notes'), before);
      expect(find.byType(Table), findsNothing);
      await _settle(tester);
    });
  });

  group('AC4 — rendu DÉFENSIF (AD-10) : jamais de throw', () {
    Future<void> pumpSeed(WidgetTester tester, Object? seed,
        {TextDirection dir = TextDirection.ltr}) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': seed},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _fieldA,
        ),
        dir: dir,
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Structures STRUCTURELLEMENT décodables (data = Map) mais INVALIDES au rendu :
    // le placeholder d'erreur inline DOIT apparaître, sans throw.
    final placeholderSeeds = <String, Object?>{
      'table = {} vide': _tableSeed(<String, dynamic>{}),
      'cells absent': _tableSeed(<String, dynamic>{'rows': 2}),
      'cells vide []': _tableSeed(<String, dynamic>{'cells': <Object?>[]}),
      'cells non-List (nombre)': _tableSeed(<String, dynamic>{'cells': 5}),
      'lignes non-List': _tableSeed(<String, dynamic>{
        'cells': <Object?>[5, 6],
      }),
      'lignes irrégulières (jagged)': _tableSeed(<String, dynamic>{
        'cells': <List<String>>[
          <String>['a'],
          <String>['b', 'c'],
        ],
      }),
    };
    placeholderSeeds.forEach((label, seed) {
      testWidgets('$label → placeholder d\'erreur inline, aucun throw',
          (tester) async {
        await pumpSeed(tester, seed);
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.error_outline), findsWidgets,
            reason: 'placeholder d\'erreur attendu');
        expect(find.byType(Table), findsNothing);
        await _settle(tester);
      });
    });

    // Données inattendues sous `insert.table` : au pire dégradation défensive du
    // document (AD-10) — JAMAIS de throw, champ toujours montable.
    final safeSeeds = <String, Object?>{
      'table data null': _tableSeed(null),
      'table data non-Map (nombre)': _tableSeed(42),
    };
    safeSeeds.forEach((label, seed) {
      testWidgets('$label → aucun throw, éditeur montable', (tester) async {
        await pumpSeed(tester, seed);
        expect(tester.takeException(), isNull);
        expect(find.byType(ZMarkdownField), findsOneWidget);
        await _settle(tester);
      });
    });

    testWidgets(
        'cellules non-String COERCÉES en String → Table rendu, aucun throw',
        (tester) async {
      await pumpSeed(
        tester,
        _tableSeed(<String, dynamic>{
          'cells': <List<Object?>>[
            <Object?>[1, 2],
            <Object?>[3, null],
          ],
        }),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('placeholder d\'erreur rendu sous RTL sans exception',
        (tester) async {
      await pumpSeed(
        tester,
        _tableSeed(<String, dynamic>{'cells': <Object?>[]}),
        dir: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      await _settle(tester);
    });
  });

  group('AC8 — SM-1 / AD-2 non régressés (embedBuilders latex+table stables)', () {
    testWidgets(
        'taper 100 caractères ne reconstruit QUE ce champ ; controller jamais '
        'recréé ; focus/caret préservés ; embedBuilders STABLES',
        (tester) async {
      // Seed : tableau (bloc, ligne 0) + une ligne de texte (« z ») où l'on tape.
      // Le tableau reste sur sa propre ligne (jamais re-rendu inline à chaque
      // frappe) — on prouve la granularité du rebuild.
      final seed = <Map<String, dynamic>>[
        ...tableTypeEmbedOps.sublist(0, 1),
        <String, dynamic>{'insert': '\nz\n'},
      ];
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': seed},
      );
      addTearDown(controller.dispose);

      var initA = 0;
      var buildA = 0;
      var buildB = 0;
      var globalBuilds = 0;

      await tester.pumpWidget(_host(Column(children: <Widget>[
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            globalBuilds++;
            return const SizedBox.shrink();
          },
        ),
        ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _fieldA,
          onInit: () => initA++,
          onBuild: () => buildA++,
        ),
        ZMarkdownField(
          key: const ValueKey('autre'),
          controller: controller,
          field: _fieldB,
          onBuild: () => buildB++,
        ),
      ])));
      await tester.pump(const Duration(milliseconds: 50));

      final quill = _quillOf(tester, ofKey: const ValueKey('notes'));
      final focus = _focusOf(tester, ofKey: const ValueKey('notes'));
      final buildersBefore = tester
          .widget<QuillEditor>(find.descendant(
            of: find.byKey(const ValueKey('notes')),
            matching: find.byType(QuillEditor),
          ))
          .config
          .embedBuilders;
      expect(buildersBefore, isNotNull);
      expect(buildersBefore!.any((b) => b.key == 'table'), isTrue);
      expect(buildersBefore.any((b) => b.key == 'latex'), isTrue);

      focus.requestFocus();
      await tester.pump();
      // Caret en fin de document (dans la ligne de texte, après « z »).
      final end = quill.document.length - 1;
      quill.updateSelection(
        TextSelection.collapsed(offset: end),
        ChangeSource.local,
      );
      await tester.pump();

      final buildAAfterFocus = buildA;
      final buildBBefore = buildB;
      final globalBefore = globalBuilds;

      for (var i = 0; i < 100; i++) {
        final at = quill.selection.baseOffset;
        quill.replaceText(at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await tester.pump();
      }

      expect(initA, 1, reason: 'QuillController/State recréé (AD-2 violé)');
      expect(buildA, greaterThan(buildAAfterFocus));
      expect(buildB, buildBBefore, reason: 'rebuild du voisin (SM-1 violé)');
      expect(globalBuilds, globalBefore,
          reason: 'notifyListeners global sur frappe (AD-2 violé)');
      expect(focus.hasFocus, isTrue);
      expect(quill.selection.baseOffset, end + 100);
      expect(
        identical(_quillOf(tester, ofKey: const ValueKey('notes')), quill),
        isTrue,
      );
      // embedBuilders : MÊME instance (const canonicalisée) — aucune allocation
      // par (re)build de tranche (MED-1 préservé).
      final buildersAfter = tester
          .widget<QuillEditor>(find.descendant(
            of: find.byKey(const ValueKey('notes')),
            matching: find.byType(QuillEditor),
          ))
          .config
          .embedBuilders;
      expect(identical(buildersAfter, buildersBefore), isTrue,
          reason: 'embedBuilders ré-alloués au build de tranche (SM-1/MED-1)');

      await _settle(tester);
    });
  });

  group('AC9 — a11y / RTL / thème (AD-13)', () {
    testWidgets('placeholder d\'erreur : couleur du thème injecté (ZcrudTheme)',
        (tester) async {
      const custom = Color(0xFF00A0B0);
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _tableSeed(<String, dynamic>{'cells': <Object?>[]}),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZcrudScope(
        theme: const ZcrudTheme(errorColor: custom),
        child: ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _fieldA,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final icon = tester.widget<Icon>(find.byIcon(Icons.error_outline).first);
      expect(icon.color, custom, reason: 'couleur codée en dur (FR-26 violé)');
      await _settle(tester);
    });

    testWidgets(
        'placeholder d\'erreur : porte le label a11y kTableInvalidLabel',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': _tableSeed(<String, dynamic>{'cells': <Object?>[]}),
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final labelled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == kTableInvalidLabel);
      expect(labelled, isNotEmpty,
          reason: 'placeholder d\'erreur sans label a11y kTableInvalidLabel');
      await _settle(tester);
    });

    testWidgets('bouton « Tableau » présent + toolbar ≥ 48 dp', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      final toolbarSize = tester.getSize(find.byType(QuillSimpleToolbar));
      expect(toolbarSize.height, greaterThanOrEqualTo(48));
      await _settle(tester);
    });

    testWidgets('dialogue : boutons OK/Annuler ≥ 48 dp', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      _pressTableButton(tester);
      await tester.pumpAndSettle();

      for (final label in <String>['OK', 'Cancel']) {
        final box = tester.getSize(
          find
              .ancestor(
                of: find.text(label),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        expect(box.height, greaterThanOrEqualTo(48));
        expect(box.width, greaterThanOrEqualTo(48));
      }

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _settle(tester);
    });

    testWidgets('Table rendu sous RTL + thème sombre sans exception',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': tableTypeEmbedOps},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(
        ZMarkdownField(
          key: const ValueKey('notes'),
          controller: controller,
          field: _fieldA,
        ),
        dir: TextDirection.rtl,
        theme: ThemeData.dark(),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
      await _settle(tester);
    });
  });
}
