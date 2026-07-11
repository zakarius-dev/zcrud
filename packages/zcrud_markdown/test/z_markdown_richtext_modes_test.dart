// DP-3 — Rich-text : lecture seule (B4) + modes inline/block (B6) + dialog
// plein-écran (ZRichTextFullscreenDialog). Vérifie :
//   AC1 lecture seule (0 toolbar / 0 bouton édition, contenu visible, onChanged
//       jamais appelé) ;
//   AC2 distinction inline (compact éditable en place) vs block (aperçu non
//       éditable + bouton Rédiger/Modifier) ;
//   AC3 toggle plein-écran + dialog Valider (mutation) / Annuler (no-op),
//       présentation 80%×70% (large) vs Scaffold (étroit) ;
//   AC5 SM-1 via la voie ctx (rebuild ciblé, focus, identité controller) ;
//   AC6 factory `registerZMarkdownFields` (kinds + collision) + a11y ≥48dp.
//
// Le contenu Quill est piloté via son `QuillController` PUBLIC (mêmes membres
// que les tests E6) — Quill rend via un `RenderEditor` maison (ni `Text` ni
// `EditableText`), donc `find.text` ne matche pas le contenu du document.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show ChangeSource, QuillController, QuillEditor, QuillSimpleToolbar;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'support/a11y_asserts.dart';

// ── Fixtures & helpers ──────────────────────────────────────────────────────

List<Map<String, dynamic>> _helloDelta() => <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'Bonjour\n'},
    ];

ZFieldSpec _field(
  String name, {
  EditionFieldType type = EditionFieldType.markdown,
  bool readOnly = false,
  String? label,
}) =>
    ZFieldSpec(name: name, type: type, readOnly: readOnly, label: label);

ZWidgetRegistry _registry() {
  final r = ZWidgetRegistry();
  registerZMarkdownFields(r);
  return r;
}

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

/// Premier `QuillController` rendu (éditeur unique / reader unique).
QuillController _quillFirst(WidgetTester t) =>
    t.widget<QuillEditor>(find.byType(QuillEditor).first).controller;

/// `QuillController` scellé au sous-arbre [scope].
QuillController _quillIn(WidgetTester t, Finder scope) => t
    .widget<QuillEditor>(
        find.descendant(of: scope, matching: find.byType(QuillEditor)).first)
    .controller;

/// `FocusNode` scellé au sous-arbre [scope].
FocusNode _focusIn(WidgetTester t, Finder scope) => t
    .widget<QuillEditor>(
        find.descendant(of: scope, matching: find.byType(QuillEditor)).first)
    .focusNode;

/// Nettoyage : démonte l'arbre (annule le Timer de clignotement du curseur).
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

Widget _appRegistry(
  ZFormController controller,
  List<ZFieldSpec> fields, {
  ZWidgetRegistry? registry,
  TextDirection dir = TextDirection.ltr,
  Size size = const Size(1200, 900),
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(
          textDirection: dir,
          child: ZcrudScope(
            widgetRegistry: registry,
            child: Scaffold(
              body: DynamicEdition(controller: controller, fields: fields),
            ),
          ),
        ),
      ),
    );

void main() {
  group('AC1 — lecture seule (B4) : reader non éditable, aucune voie de frappe',
      () {
    testWidgets('voie controller readOnly : reader, 0 toolbar, contenu lisible',
        (t) async {
      final c = _controller(<String, Object?>{'body': _helloDelta()});
      var changes = 0;
      c.fieldListenable('body').addListener(() => changes++);
      await t.pumpWidget(MaterialApp(
        home: ZcrudScope(
          child: Scaffold(
            body: ZMarkdownField(
              key: const ValueKey<String>('body'),
              controller: c,
              field: _field('body', readOnly: true),
            ),
          ),
        ),
      ));
      await t.pump();

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.byType(QuillSimpleToolbar), findsNothing,
          reason: 'aucune toolbar en lecture seule');
      expect(_quillFirst(t).document.toPlainText().contains('Bonjour'), isTrue,
          reason: 'le contenu est rendu (lisible)');
      expect(_quillFirst(t).readOnly, isTrue,
          reason: 'controller readOnly ⇒ aucune saisie');
      expect(changes, 0, reason: 'onChanged/setValue jamais émis en lecture');
      await _settle(t);
    });

    testWidgets('voie ctx/registre readOnly : reader, 0 toolbar/bouton édition',
        (t) async {
      final c = _controller(<String, Object?>{'body': _helloDelta()});
      var changes = 0;
      c.fieldListenable('body').addListener(() => changes++);
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', readOnly: true)],
        registry: _registry(),
      ));
      await t.pump();

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.byType(QuillSimpleToolbar), findsNothing);
      expect(find.byKey(const Key('z-markdown-block-edit')), findsNothing);
      expect(find.byKey(const Key('z-markdown-fullscreen-toggle')), findsNothing);
      expect(changes, 0);
      await _settle(t);
    });

    testWidgets('contenu vide/absent → placeholder propre, aucune exception',
        (t) async {
      final c = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', readOnly: true)],
        registry: _registry(),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Aucun contenu'), findsOneWidget);
      await _settle(t);
    });

    testWidgets('valeur corrompue (AD-10) → rendu vide, aucune exception',
        (t) async {
      final c = _controller(<String, Object?>{'body': 'not-a-delta-<<>>'});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', readOnly: true)],
        registry: _registry(),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(ZMarkdownReader), findsOneWidget);
      await _settle(t);
    });
  });

  group('AC2 — distinction inline (compact) vs block (aperçu + dialog)', () {
    testWidgets('inlineMarkdown → éditeur compact ÉDITABLE en place', (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineMarkdown)],
        registry: _registry(),
      ));
      await t.pump();

      expect(find.byType(QuillSimpleToolbar), findsOneWidget,
          reason: 'éditeur compact ⇒ toolbar présente');
      expect(find.byKey(const Key('z-markdown-fullscreen-toggle')),
          findsOneWidget);
      expect(find.byKey(const Key('z-markdown-block-edit')), findsNothing);

      // Frappe en place (via le controller Quill public) → tranche = Delta neutre.
      final quill = _quillFirst(t);
      quill.replaceText(0, 0, 'X', const TextSelection.collapsed(offset: 1));
      await t.pump();
      expect(c.valueOf('note'), isA<List<Object?>>(),
          reason: 'la frappe pousse du Delta neutre dans la tranche');
      await _settle(t);
    });

    testWidgets('markdown vide → aperçu NON éditable + bouton « Rédiger »',
        (t) async {
      final c = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
      ));
      await t.pump();

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.byType(QuillSimpleToolbar), findsNothing,
          reason: 'pas d\'édition en place en mode block');
      expect(find.byKey(const Key('z-markdown-block-edit')), findsOneWidget);
      expect(find.text('Rédiger'), findsOneWidget);
      await _settle(t);
    });

    testWidgets('markdown non vide → bouton « Modifier » + aperçu du contenu',
        (t) async {
      final c = _controller(<String, Object?>{'body': _helloDelta()});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
      ));
      await t.pump();
      expect(find.text('Modifier'), findsOneWidget);
      expect(_quillFirst(t).document.toPlainText().contains('Bonjour'), isTrue);
      await _settle(t);
    });
  });

  group('AC3 — dialog plein-écran : Valider (mutation) / Annuler (no-op)', () {
    testWidgets('block : Rédiger → dialog → Valider écrit la tranche', (t) async {
      final c = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
      ));
      await t.pump();

      await t.tap(find.byKey(const Key('z-markdown-block-edit')));
      await t.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget);

      final dialogQuill =
          _quillIn(t, find.byType(ZRichTextFullscreenDialog));
      dialogQuill.replaceText(
          0, 0, 'Ajouté', const TextSelection.collapsed(offset: 6));
      await t.pump();
      await t.tap(find.byKey(const Key('z-richtext-dialog-submit')));
      await t.pumpAndSettle();

      expect(find.byType(ZRichTextFullscreenDialog), findsNothing);
      final v = c.valueOf('body');
      expect(v, isA<List<Object?>>(), reason: 'Valider écrit du Delta neutre');
      expect(v.toString().contains('Ajouté'), isTrue);
      await _settle(t);
    });

    testWidgets('block : Annuler ne mute PAS la tranche', (t) async {
      final c = _controller(<String, Object?>{'body': _helloDelta()});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
      ));
      await t.pump();
      final before = c.valueOf('body');

      await t.tap(find.byKey(const Key('z-markdown-block-edit')));
      await t.pumpAndSettle();
      final dialogQuill = _quillIn(t, find.byType(ZRichTextFullscreenDialog));
      dialogQuill.replaceText(
          0, 0, 'PARASITE', const TextSelection.collapsed(offset: 8));
      await t.pump();
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();

      expect(find.byType(ZRichTextFullscreenDialog), findsNothing);
      expect(c.valueOf('body'), before, reason: 'Annuler = aucune mutation');
      await _settle(t);
    });

    testWidgets('inline : toggle plein-écran ouvre le dialog', (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineMarkdown)],
        registry: _registry(),
      ));
      await t.pump();
      await t.tap(find.byKey(const Key('z-markdown-fullscreen-toggle')));
      await t.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget);
      // Large (défaut 1200) ⇒ dialog dimensionné ⇒ action « Annuler » présente.
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();
      await _settle(t);
    });

    testWidgets('présentation : large ⇒ Dialog dimensionné ; étroit ⇒ Scaffold',
        (t) async {
      final cLarge = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        cLarge,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
        size: const Size(1200, 900),
      ));
      await t.pump();
      await t.tap(find.byKey(const Key('z-markdown-block-edit')));
      await t.pumpAndSettle();
      expect(
          t
              .widget<ZRichTextFullscreenDialog>(
                  find.byType(ZRichTextFullscreenDialog))
              .fullscreen,
          isFalse,
          reason: 'large ⇒ dialog dimensionné 80%×70%');
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();
      await _settle(t);

      final cNarrow = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        cNarrow,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
        size: const Size(400, 800),
      ));
      await t.pump();
      await t.tap(find.byKey(const Key('z-markdown-block-edit')));
      await t.pumpAndSettle();
      expect(
          t
              .widget<ZRichTextFullscreenDialog>(
                  find.byType(ZRichTextFullscreenDialog))
              .fullscreen,
          isTrue,
          reason: 'étroit ⇒ Scaffold plein-écran');
      expect(find.byKey(const Key('z-richtext-dialog-close')), findsOneWidget);
      await _settle(t);
    });
  });

  group('AC5 — SM-1 sur la voie ctx (rebuild ciblé, focus, controller stable)',
      () {
    testWidgets('inline : frappe 100 car. → voisin non reconstruit ; init==1',
        (t) async {
      final c = _controller(<String, Object?>{'a': null, 'b': null});
      var initA = 0;
      var buildB = 0;

      Widget host(String name, Key key,
              {VoidCallback? onInit, VoidCallback? onBuild}) =>
          KeyedSubtree(
            key: key,
            child: ValueListenableBuilder<Object?>(
              valueListenable: c.fieldListenable(name),
              builder: (context, value, _) => ZMarkdownField.fromContext(
                key: ValueKey<String>('z-markdown-$name'),
                ctx: ZFieldWidgetContext(
                  field: _field(name, type: EditionFieldType.inlineMarkdown),
                  value: value,
                  onChanged: (v) => c.setValue(name, v),
                ),
                mode: ZMarkdownFieldMode.inline,
                onInit: onInit,
                onBuild: onBuild,
              ),
            ),
          );

      await t.pumpWidget(MaterialApp(
        home: ZcrudScope(
          child: Scaffold(
            body: ListView(children: <Widget>[
              host('a', const Key('hostA'), onInit: () => initA++),
              host('b', const Key('hostB'), onBuild: () => buildB++),
            ]),
          ),
        ),
      ));
      await t.pump();

      final quillA = _quillIn(t, find.byKey(const Key('hostA')));
      final focusA = _focusIn(t, find.byKey(const Key('hostA')));
      focusA.requestFocus();
      await t.pump();
      final buildBBefore = buildB;

      for (var i = 0; i < 100; i++) {
        final at = quillA.selection.baseOffset;
        quillA.replaceText(
            at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await t.pump();
      }

      expect(initA, 1, reason: 'State/QuillController non recréé (SM-1/AD-2)');
      expect(buildB, buildBBefore, reason: 'le voisin n\'est PAS reconstruit');
      expect(focusA.hasFocus, isTrue, reason: 'focus préservé pendant la frappe');
      expect(identical(_quillIn(t, find.byKey(const Key('hostA'))), quillA),
          isTrue,
          reason: 'identité du QuillController stable');
      expect((c.valueOf('a')! as List).isNotEmpty, isTrue);
      await _settle(t);
    });

    testWidgets('déplacement de curseur seul → aucun setValue superflu (MED-1)',
        (t) async {
      final c = _controller(<String, Object?>{'a': _helloDelta()});
      var changes = 0;
      c.fieldListenable('a').addListener(() => changes++);
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('a', type: EditionFieldType.inlineMarkdown)],
        registry: _registry(),
      ));
      await t.pump();
      final debug = t.state<State<ZMarkdownField>>(
          find.byType(ZMarkdownField)) as ZMarkdownFieldDebug;
      final quill = _quillFirst(t);
      _focusIn(t, find.byType(ZMarkdownField)).requestFocus();
      await t.pump();
      final changesBefore = changes;
      final docChangeBefore = debug.debugDocChangeCount;

      quill.updateSelection(
          const TextSelection.collapsed(offset: 3), ChangeSource.local);
      await t.pump();

      expect(changes, changesBefore, reason: 'sélection seule ⇒ aucun setValue');
      expect(debug.debugDocChangeCount, docChangeBefore,
          reason: 'document.changes n\'émet pas sur déplacement de curseur');
      await _settle(t);
    });
  });

  group('AC6 — factory registre + a11y ≥48dp + thème', () {
    test('registerZMarkdownFields enregistre les 3 kinds', () {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(r);
      expect(r.isRegistered('markdown'), isTrue);
      expect(r.isRegistered('inlineMarkdown'), isTrue);
      expect(r.isRegistered('richText'), isTrue);
    });

    test('collision de kind → throw (contrat ZWidgetRegistry)', () {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(r);
      expect(() => registerZMarkdownFields(r), throwsA(anything));
    });

    testWidgets('inline : toggle plein-écran opérable + ≥48dp', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineMarkdown)],
        registry: _registry(),
      ));
      await t.pump();
      final toggle = find.byKey(const Key('z-markdown-fullscreen-toggle'));
      assertMinTapTarget(t, toggle, 48);
      await assertSemanticActionTap(t, toggle);
      await t.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget,
          reason: 'le tap sémantique a ouvert le dialog');
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();
      handle.dispose();
      await _settle(t);
    });

    testWidgets('block : bouton Rédiger opérable + ≥48dp', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
      ));
      await t.pump();
      assertMinTapTarget(t, find.byKey(const Key('z-markdown-block-edit')), 48);
      handle.dispose();
      await _settle(t);
    });

    testWidgets('dialog : actions Valider/Annuler ≥48dp', (t) async {
      final c = _controller(<String, Object?>{'body': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', type: EditionFieldType.markdown)],
        registry: _registry(),
      ));
      await t.pump();
      await t.tap(find.byKey(const Key('z-markdown-block-edit')));
      await t.pumpAndSettle();
      assertMinTapTarget(t, find.byKey(const Key('z-richtext-dialog-submit')), 48);
      assertMinTapTarget(t, find.byKey(const Key('z-richtext-dialog-cancel')), 48);
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();
      await _settle(t);
    });

    testWidgets('rendu RTL des 3 modes sans exception', (t) async {
      for (final type in <EditionFieldType>[
        EditionFieldType.markdown,
        EditionFieldType.inlineMarkdown,
        EditionFieldType.richText,
      ]) {
        final c = _controller(<String, Object?>{'f': _helloDelta()});
        await t.pumpWidget(_appRegistry(
          c,
          <ZFieldSpec>[_field('f', type: type)],
          registry: _registry(),
          dir: TextDirection.rtl,
        ));
        await t.pump();
        expect(t.takeException(), isNull);
        await _settle(t);
      }
    });
  });
}
