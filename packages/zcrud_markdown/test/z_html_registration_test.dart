// DP-4 / B5 — `registerZHtmlFields` : kinds `html`/`inlineHtml` servis via
// ZWidgetRegistry (AC2), lecture seule HTML (AC3), réactivité SM-1 sur la voie
// HTML (AC4), a11y ≥48dp (AC5). Réutilise l'infra rich-text isolée de DP-3 ;
// SEUL delta = le `ZHtmlCodec` (format persisté HTML), hors chemin chaud.
//
// Rappel architecture (AD-7/AD-2) : la TRANCHE porte une valeur NEUTRE (Delta) ;
// le format persisté HTML vit à la COUTURE de persistance
// (`ZMarkdownField.persistedValueOf(..., codec: ZHtmlCodec())`), jamais dans le
// chemin chaud de frappe (sinon violation AC4/SM-1).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show QuillController, QuillEditor, QuillSimpleToolbar;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

import 'support/a11y_asserts.dart';

// ── Fixtures & helpers ──────────────────────────────────────────────────────

/// Un fragment HTML non trivial (persisté DODLP typique).
const _htmlValue = '<p><strong>gras</strong> et <em>italique</em></p>';

ZFieldSpec _field(
  String name, {
  EditionFieldType type = EditionFieldType.html,
  bool readOnly = false,
  String? label,
}) =>
    ZFieldSpec(name: name, type: type, readOnly: readOnly, label: label);

ZWidgetRegistry _registry({ZCodec? codec}) {
  final r = ZWidgetRegistry();
  registerZHtmlFields(r, codec: codec);
  return r;
}

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

QuillController _quillFirst(WidgetTester t) =>
    t.widget<QuillEditor>(find.byType(QuillEditor).first).controller;

QuillController _quillIn(WidgetTester t, Finder scope) => t
    .widget<QuillEditor>(
        find.descendant(of: scope, matching: find.byType(QuillEditor)).first)
    .controller;

FocusNode _focusIn(WidgetTester t, Finder scope) => t
    .widget<QuillEditor>(
        find.descendant(of: scope, matching: find.byType(QuillEditor)).first)
    .focusNode;

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

/// Codec de comptage : délègue à [ZHtmlCodec] et compte les invocations
/// `encode`/`decode` (preuve AC4 : le codec n'est PAS appelé par frappe).
class _CountingCodec implements ZCodec {
  int encodes = 0;
  int decodes = 0;
  final ZHtmlCodec _inner = const ZHtmlCodec();

  @override
  Object? encode(List<Map<String, dynamic>> deltaOps) {
    encodes++;
    return _inner.encode(deltaOps);
  }

  @override
  List<Map<String, dynamic>> decode(Object? persisted) {
    decodes++;
    return _inner.decode(persisted);
  }
}

void main() {
  group('AC2 — kinds html/inlineHtml enregistrés + collision', () {
    test('registerZHtmlFields enregistre html + inlineHtml', () {
      final r = ZWidgetRegistry();
      registerZHtmlFields(r);
      expect(r.isRegistered('html'), isTrue);
      expect(r.isRegistered('inlineHtml'), isTrue);
    });

    test('collision de kind → ZDuplicateRegistrationError', () {
      final r = ZWidgetRegistry();
      registerZHtmlFields(r);
      expect(() => registerZHtmlFields(r),
          throwsA(isA<ZDuplicateRegistrationError>()));
    });

    test('collision avec un kind déjà présent → throw', () {
      final r = ZWidgetRegistry();
      r.register('html', (context, ctx) => const SizedBox.shrink());
      expect(() => registerZHtmlFields(r), throwsA(anything));
    });
  });

  group('AC2 — rendu via DynamicEdition (block vs inline) + format persisté', () {
    testWidgets('html (block) : aperçu NON éditable + bouton édition', (t) async {
      final c = _controller(<String, Object?>{'body': _htmlValue});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body')],
        registry: _registry(),
      ));
      await t.pump();

      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.byType(QuillSimpleToolbar), findsNothing,
          reason: 'pas d\'édition en place en mode block');
      expect(find.byKey(const Key('z-markdown-block-edit')), findsOneWidget);
      // Le contenu HTML est décodé et rendu lisible.
      expect(_quillFirst(t).document.toPlainText().contains('gras'), isTrue);
      await _settle(t);
    });

    testWidgets('inlineHtml (inline) : éditeur compact ÉDITABLE en place',
        (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineHtml)],
        registry: _registry(),
      ));
      await t.pump();

      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
      expect(find.byKey(const Key('z-markdown-fullscreen-toggle')),
          findsOneWidget);
      expect(find.byKey(const Key('z-markdown-block-edit')), findsNothing);
      await _settle(t);
    });

    testWidgets(
        'format persisté = HTML (String) via persistedValueOf(ZHtmlCodec)',
        (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineHtml)],
        registry: _registry(),
      ));
      await t.pump();

      // Frappe en place → la tranche porte du Delta NEUTRE (AD-7, hors codec).
      final quill = _quillFirst(t);
      quill.replaceText(0, 0, 'Salut', const TextSelection.collapsed(offset: 5));
      await t.pump();
      expect(c.valueOf('note'), isA<List<Object?>>(),
          reason: 'la tranche porte du Delta neutre (codec hors chemin chaud)');

      // Le format PERSISTÉ, lui, est du HTML (String) à la couture de persistance.
      final persisted = ZMarkdownField.persistedValueOf(c, 'note',
          codec: const ZHtmlCodec());
      expect(persisted, isA<String>());
      expect(persisted! as String, contains('Salut'));
      expect((persisted as String).trimLeft(), startsWith('<'),
          reason: 'le format persisté est bien du HTML');
      await _settle(t);
    });

    testWidgets('codec injecté custom (ZDeltaCodec) honoré sans changer le widget',
        (t) async {
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineHtml)],
        registry: _registry(codec: const ZDeltaCodec()),
      ));
      await t.pump();
      // Un codec injecté (Delta pur) est accepté : le champ se rend sans erreur.
      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
      expect(t.takeException(), isNull);
      await _settle(t);
    });
  });

  group('AC3 — lecture seule HTML (readOnly)', () {
    testWidgets('readOnly : reader, 0 toolbar/bouton, contenu lisible, no onChanged',
        (t) async {
      final c = _controller(<String, Object?>{'body': _htmlValue});
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
      expect(_quillFirst(t).document.toPlainText().contains('gras'), isTrue,
          reason: 'le HTML est décodé et lisible');
      expect(_quillFirst(t).readOnly, isTrue);
      expect(changes, 0, reason: 'onChanged jamais émis en lecture seule');
      await _settle(t);
    });

    testWidgets('readOnly HTML corrompu → rendu vide propre, aucune exception',
        (t) async {
      final c = _controller(<String, Object?>{'body': '<not/valid'});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body', readOnly: true)],
        registry: _registry(),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(ZMarkdownReader), findsOneWidget);
      expect(find.text('Aucun contenu'), findsOneWidget);
      await _settle(t);
    });
  });

  group('AC4 — SM-1 sur la voie HTML (rebuild ciblé, focus, codec hors frappe)',
      () {
    testWidgets('frappe 100 car. : init==1, voisin non reconstruit, focus, codec borné',
        (t) async {
      final c = _controller(<String, Object?>{'a': null, 'b': null});
      final codec = _CountingCodec();
      var initA = 0;
      var buildB = 0;

      Widget host(String name, Key key,
              {VoidCallback? onInit, VoidCallback? onBuild}) =>
          KeyedSubtree(
            key: key,
            child: ValueListenableBuilder<Object?>(
              valueListenable: c.fieldListenable(name),
              builder: (context, value, _) => ZMarkdownField.fromContext(
                key: ValueKey<String>('z-html-$name'),
                ctx: ZFieldWidgetContext(
                  field: _field(name, type: EditionFieldType.inlineHtml),
                  value: value,
                  onChanged: (v) => c.setValue(name, v),
                ),
                mode: ZMarkdownFieldMode.inline,
                codec: codec,
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
      final codecCallsBefore = codec.encodes + codec.decodes;

      for (var i = 0; i < 100; i++) {
        final at = quillA.selection.baseOffset;
        quillA.replaceText(at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await t.pump();
      }

      expect(initA, 1, reason: 'State/QuillController non recréé (SM-1/AD-2)');
      expect(buildB, buildBBefore, reason: 'le voisin n\'est PAS reconstruit');
      expect(focusA.hasFocus, isTrue, reason: 'focus préservé pendant la frappe');
      expect(identical(_quillIn(t, find.byKey(const Key('hostA'))), quillA),
          isTrue,
          reason: 'identité du QuillController stable');
      final codecCallsDuringTyping =
          (codec.encodes + codec.decodes) - codecCallsBefore;
      expect(codecCallsDuringTyping, lessThan(100),
          reason: 'le codec n\'est PAS invoqué à chaque frappe (hors chemin chaud)');
      expect((c.valueOf('a')! as List).isNotEmpty, isTrue);
      await _settle(t);
    });
  });

  group('AC5 — a11y ≥48dp + RTL sur la voie HTML', () {
    testWidgets('inlineHtml : toggle plein-écran opérable + ≥48dp', (t) async {
      final handle = t.ensureSemantics();
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('note', type: EditionFieldType.inlineHtml)],
        registry: _registry(),
      ));
      await t.pump();
      final toggle = find.byKey(const Key('z-markdown-fullscreen-toggle'));
      assertMinTapTarget(t, toggle, 48);
      await assertSemanticActionTap(t, toggle);
      await t.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget);
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();
      handle.dispose();
      await _settle(t);
    });

    testWidgets('html (block) : bouton édition ≥48dp', (t) async {
      final c = _controller(<String, Object?>{'body': _htmlValue});
      await t.pumpWidget(_appRegistry(
        c,
        <ZFieldSpec>[_field('body')],
        registry: _registry(),
      ));
      await t.pump();
      assertMinTapTarget(t, find.byKey(const Key('z-markdown-block-edit')), 48);
      await _settle(t);
    });

    testWidgets('rendu RTL html + inlineHtml sans exception', (t) async {
      for (final type in <EditionFieldType>[
        EditionFieldType.html,
        EditionFieldType.inlineHtml,
      ]) {
        final c = _controller(<String, Object?>{'f': _htmlValue});
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
