// E6-3 — Embed LaTeX : rendu (`Math`), insertion/édition via toolbar+dialogue,
// rendu DÉFENSIF (AD-10 : formule invalide/vide/non-String → placeholder, jamais
// de throw), neutralité runtime de la tranche (AC7), SM-1 non régressé (AC8) et
// a11y/RTL/thème (AC9).
//
// Les frappes/insertions empruntent le `QuillController` RÉEL rendu par le champ
// (membre public de flutter_quill) — EXACTEMENT la voie interne. `Math` provient
// de `flutter_math_fork` (dép de test légitime de ce package).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
// Import CIBLÉ de l'impl (même package) : le barrel n'exporte pas
// `ZLatexEmbedBuilder`/`kLatexInvalidLabel` (isolation AD-1). Un test INTERNE au
// package a le droit de câbler l'`EmbedBuilder` réel pour prouver le rendu
// readOnly (F1) et le label a11y (F3) directement, sans passer par la surface
// publique.
import 'package:zcrud_markdown/src/presentation/z_latex_embed.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'fixtures/rich_corpus.dart';

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr, ThemeData? theme}) =>
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

/// Déclenche le bouton « Formule » de la toolbar en invoquant SON callback RÉEL
/// (`options.onPressed` = `_promptAndInsertLatex` du champ) — voie de production
/// exacte, robuste au défilement/hit-test de la toolbar Quill.
void _pressLatexButton(WidgetTester tester) {
  // E6-4 : la toolbar porte désormais DEUX boutons custom (Formule + Tableau) —
  // on cible celui de la formule par son tooltip (voie de production exacte).
  final btn = tester
      .widgetList<QuillToolbarCustomButton>(
          find.byType(QuillToolbarCustomButton))
      .firstWhere((b) => b.options.tooltip == 'Insérer une formule');
  btn.options.onPressed!.call();
}

const _fieldA = ZFieldSpec(name: 'notes', type: EditionFieldType.text);
const _fieldB = ZFieldSpec(name: 'autre', type: EditionFieldType.text);

void main() {
  group('AC2 — rendu de l\'embed via flutter_math_fork', () {
    testWidgets('op {insert:{latex:...}} → widget Math (pas le texte brut)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': latexTypeEmbedOps},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      // La formule est rendue comme un widget mathématique, jamais comme le
      // littéral "latex" ni la source brute affichée en texte.
      expect(find.byType(Math), findsWidgets);
      await _settle(tester);
    });

    testWidgets('les embedBuilders sont câblés (édition ET lecture, même config)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': latexTypeEmbedOps},
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
      expect(builders!.any((b) => b.key == 'latex'), isTrue,
          reason: 'un EmbedBuilder de clé `latex` doit servir édition + lecture');
      await _settle(tester);
    });

    testWidgets(
        'RENDU RÉEL en LECTURE (readOnly) : embed latex → widget Math affiché (F1)',
        (tester) async {
      // AC2 exige un rendu prouvé « en édition ET en LECTURE ». Ici on monte un
      // `QuillEditor` en LECTURE SEULE (`QuillController.readOnly == true`) câblé
      // sur l'`EmbedBuilder` RÉEL (`ZLatexEmbedBuilder`) avec un document
      // contenant un embed `latex` : on vérifie que la formule est EFFECTIVEMENT
      // rendue (`Math`) — pas seulement qu'un builder est câblé dans la config.
      final controller = QuillController(
        document: Document.fromJson(latexTypeEmbedOps),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      addTearDown(controller.dispose);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);

      await tester.pumpWidget(MaterialApp(
        // `QuillEditor` exige `FlutterQuillLocalizations` (fourni par le champ en
        // prod via `Localizations.override` ; ici on le câble explicitement).
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
                embedBuilders: <EmbedBuilder>[ZLatexEmbedBuilder()],
              ),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));

      expect(controller.readOnly, isTrue,
          reason: 'le controller doit être en mode LECTURE');
      expect(find.byType(Math), findsWidgets,
          reason: 'la formule doit être RÉELLEMENT rendue en lecture (readOnly)');
      await _settle(tester);
    });
  });

  group('AC3 — insertion / édition via toolbar + dialogue', () {
    testWidgets('bouton toolbar → dialogue → op latex insérée + rendu Math',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.functions), findsOneWidget,
          reason: 'bouton « Formule » absent de la toolbar');
      _pressLatexButton(tester);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'E=mc^2');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final hasLatex = value.any((op) {
        final ins = op['insert'];
        return ins is Map && ins['latex'] == 'E=mc^2';
      });
      expect(hasLatex, isTrue, reason: 'op {insert:{latex:E=mc^2}} absente');
      expect(find.byType(Math), findsWidgets);

      // AC7 — la tranche reste NEUTRE + JSON-safe après insertion d'un embed.
      expect(value, isA<List<Map<String, dynamic>>>());
      expect(jsonDecode(jsonEncode(value)), equals(value));

      await _settle(tester);
    });

    testWidgets('édition d\'un embed existant : dialogue PRÉ-REMPLI → op remplacée',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': latexTypeEmbedOps},
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

      _pressLatexButton(tester);
      await tester.pumpAndSettle();

      // Dialogue PRÉ-REMPLI avec la source existante.
      final tf = tester.widget<TextField>(find.byType(TextField));
      expect(tf.controller!.text, 'E = mc^2');

      await tester.enterText(find.byType(TextField), 'a+b');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final value = controller.valueOf('notes')! as List<Map<String, dynamic>>;
      final sources = value
          .map((op) => op['insert'])
          .whereType<Map<String, dynamic>>()
          .map((m) => m['latex'])
          .toList();
      expect(sources, contains('a+b'));
      expect(sources, isNot(contains('E = mc^2')),
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

      _pressLatexButton(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ignored');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(controller.valueOf('notes'), before);
      expect(find.byType(Math), findsNothing);
      await _settle(tester);
    });

    testWidgets('OK sur champ VIDE/BLANC → annulation : AUCUN embed inséré (F2)',
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

      // Cas 1 : champ laissé VIDE puis OK → traité comme une annulation.
      _pressLatexButton(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(controller.valueOf('notes'), before,
          reason: 'OK sur champ vide ne doit RIEN insérer');
      expect(find.byType(Math), findsNothing);

      // Cas 2 : saisie BLANCHE (espaces seuls) puis OK → également annulée (trim).
      _pressLatexButton(tester);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(controller.valueOf('notes'), before,
          reason: 'OK sur saisie blanche ne doit RIEN insérer');
      expect(find.byType(Math), findsNothing,
          reason: 'aucun embed vide (placeholder d\'erreur persistant) inséré');

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

    // Embeds LaTeX STRUCTURELLEMENT valides (String) mais au rendu impossible :
    // le placeholder d'erreur inline DOIT apparaître, sans throw.
    final placeholderSeeds = <String, Object?>{
      'malformé (\\frac{ tronqué)': <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': r'\frac{'},
        },
        <String, dynamic>{'insert': '\n'},
      ],
      'vide ("")': <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': ''},
        },
        <String, dynamic>{'insert': '\n'},
      ],
    };
    placeholderSeeds.forEach((label, seed) {
      testWidgets('$label → placeholder d\'erreur inline, aucun throw',
          (tester) async {
        await pumpSeed(tester, seed);
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.error_outline), findsWidgets,
            reason: 'placeholder d\'erreur attendu');
        await _settle(tester);
      });
    });

    // Données inattendues sous `insert.latex` : au pire dégradation défensive du
    // document (AD-10) — JAMAIS de throw, champ toujours montable.
    final safeSeeds = <String, Object?>{
      'data null': <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': null},
        },
        <String, dynamic>{'insert': '\n'},
      ],
      'data non-String (nombre)': <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': 42},
        },
        <String, dynamic>{'insert': '\n'},
      ],
    };
    safeSeeds.forEach((label, seed) {
      testWidgets('$label → aucun throw, éditeur montable', (tester) async {
        await pumpSeed(tester, seed);
        expect(tester.takeException(), isNull);
        expect(find.byType(ZMarkdownField), findsOneWidget);
        await _settle(tester);
      });
    });

    testWidgets('placeholder d\'erreur rendu sous RTL sans exception',
        (tester) async {
      await pumpSeed(
        tester,
        <Map<String, dynamic>>[
          <String, dynamic>{
            'insert': <String, dynamic>{'latex': r'\frac{'},
          },
          <String, dynamic>{'insert': '\n'},
        ],
        dir: TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.error_outline), findsWidgets);
      await _settle(tester);
    });
  });

  group('AC8 — SM-1 / AD-2 non régressés (embedBuilder actif + stable)', () {
    testWidgets(
        'taper 100 caractères ne reconstruit QUE ce champ ; controller jamais '
        'recréé ; focus/caret préservés ; embedBuilders STABLES',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{'notes': latexTypeEmbedOps},
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
      expect(buildersBefore!.any((b) => b.key == 'latex'), isTrue);

      focus.requestFocus();
      await tester.pump();
      // Place le caret en fin de document (après l'embed + texte), point sûr.
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
          'notes': <Map<String, dynamic>>[
            <String, dynamic>{
              'insert': <String, dynamic>{'latex': r'\frac{'},
            },
            <String, dynamic>{'insert': '\n'},
          ],
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
        'placeholder d\'erreur : porte le label a11y kLatexInvalidLabel (F3)',
        (tester) async {
      final controller = ZFormController(
        initialValues: <String, Object?>{
          'notes': <Map<String, dynamic>>[
            <String, dynamic>{
              'insert': <String, dynamic>{'latex': r'\frac{'},
            },
            <String, dynamic>{'insert': '\n'},
          ],
        },
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      // Inspecte directement le widget `Semantics` du placeholder (robuste, sans
      // dépendre de l'activation de l'arbre sémantique) : son `label` DOIT être
      // `kLatexInvalidLabel` (« formule invalide ») — invariant a11y AD-13/AC9.
      final labelled = tester
          .widgetList<Semantics>(find.byType(Semantics))
          .where((s) => s.properties.label == kLatexInvalidLabel);
      expect(labelled, isNotEmpty,
          reason: 'placeholder d\'erreur sans label a11y kLatexInvalidLabel');
      await _settle(tester);
    });

    testWidgets('bouton « Formule » présent + toolbar ≥ 48 dp', (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _fieldA,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.functions), findsOneWidget);
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

      _pressLatexButton(tester);
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

      // Referme le dialogue avant démontage.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _settle(tester);
    });
  });
}
