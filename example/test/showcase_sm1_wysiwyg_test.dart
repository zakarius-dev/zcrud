import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_example/demos/showcase/axis_harness.dart';
import 'package:zcrud_example/demos/showcase/showcase_registry.dart';
import 'package:zcrud_example/support/rebuild_indicator.dart';
import 'package:zcrud_html/zcrud_html.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';
import 'package:zcrud_media/zcrud_media.dart';

import 'support/pump_helpers.dart';

/// Banc **SM-1 FALSIFIABLE incluant des voisins RICHES** (fp-3-2, AC6 — SM-1 /
/// AD-2 / AD-50).
///
/// ⚠️ **ET-5 (écart consigné)** : la WebView WYSIWYG `ZHtmlEditorField`
/// (`html_editor_enhanced`) n'est **PAS montable** en VM `flutter_test` (aucun
/// moteur WebView). Sa survivance de `State` est prouvée par CONCEPTION dans
/// `zcrud_html` (`late final HtmlEditorController` + `ValueKey('z-html-<name>')`)
/// et par les tests de fp-4-3 (`ZHtmlCommitDebouncer`). Ici on prouve la
/// granularité SM-1 sur un champ intensif STANDARD entouré de **voisins riches
/// montables** :
///  - un champ `html` en **lecture** (`ZHtmlView`) — voisin rich-text réel ;
///  - un champ `markdown` **STATEFUL** (`ZMarkdownField`) dont on prouve que le
///    `State` **SURVIT** aux rebuilds voisins (proxy du pattern d'isolation
///    WYSIWYG : même `ValueKey` de place stable).
void main() {
  testWidgets(
      'AC6/SM-1 — 100 car. ⇒ seul le champ intensif rebuild ; voisins riches '
      '(html/markdown) inchangés, State markdown survivant, focus gardé, aucun Form',
      (tester) async {
    useTallSurface(tester);

    const form = AxisForm(
      id: 'sm1-wysiwyg-bench',
      title: 'Banc SM-1 (voisins riches)',
      intensiveFieldName: 'intense',
      fields: <ZFieldSpec>[
        ZFieldSpec(name: 'intense', type: EditionFieldType.text, label: 'Frappe intensive'),
        ZFieldSpec(name: 'quiet', type: EditionFieldType.text, label: 'Voisin texte'),
        ZFieldSpec(name: 'md', type: EditionFieldType.markdown, label: 'Voisin markdown'),
        // ET-5 : voisin HTML en LECTURE (ZHtmlView) — montable, contrairement à
        // l'éditeur WYSIWYG.
        ZFieldSpec(name: 'htmlRead', type: EditionFieldType.html, label: 'Voisin HTML (lecture)', readOnly: true),
      ],
      initialValues: <String, Object?>{
        'intense': '',
        'quiet': '',
        'md': 'contenu markdown voisin',
        'htmlRead': '<p>HTML voisin</p>',
      },
    );

    final log = RebuildLog();
    final registry = buildShowcaseWidgetRegistry(mediaPicker: ZMediaFilePicker());
    await tester.pumpWidget(
      wrapForTestWithRegistry(
        AxisFormScreen(form: form, rebuildLog: log),
        registry: registry,
      ),
    );
    await tester.pumpAndSettle();

    // Aucun Form/FormBuilder global (AD-2 / objectif produit n°1).
    expect(find.byType(Form), findsNothing);
    // Les voisins riches sont bien montés par leur adaptateur réel.
    expect(find.byType(ZMarkdownField), findsOneWidget);
    expect(find.byType(ZHtmlView), findsOneWidget);

    final intensiveField = find.descendant(
      of: find.byKey(const ValueKey<String>('intense')),
      matching: find.byType(EditableText),
    );
    expect(intensiveField, findsOneWidget);

    // Capture du State markdown AVANT (survivance à prouver).
    final State markdownStateBefore = tester.state(find.byType(ZMarkdownField));

    final baseIntense = log.countOf('intense');
    final baseQuiet = log.countOf('quiet');
    final baseMd = log.countOf('md');
    final baseHtml = log.countOf('htmlRead');

    final buffer = StringBuffer();
    for (var i = 0; i < 100; i++) {
      buffer.write('a');
      await tester.enterText(intensiveField, buffer.toString());
      await tester.pump();
    }

    // (i) Seul le champ intensif se reconstruit.
    expect(log.countOf('intense') - baseIntense, greaterThanOrEqualTo(100));
    // (ii) Les voisins — dont les RICHES — ne bougent JAMAIS (falsifiable R3).
    expect(log.countOf('quiet'), baseQuiet, reason: 'voisin texte reconstruit');
    expect(log.countOf('md'), baseMd, reason: 'voisin markdown reconstruit');
    expect(log.countOf('htmlRead'), baseHtml, reason: 'voisin html reconstruit');

    // (iii) Le State du voisin STATEFUL markdown SURVIT (non recréé) — proxy du
    // pattern d'isolation WYSIWYG (place stable ValueKey, AD-2/AD-50).
    final State markdownStateAfter = tester.state(find.byType(ZMarkdownField));
    expect(identical(markdownStateBefore, markdownStateAfter), isTrue,
        reason: 'Le State du voisin rich-text ne doit PAS être recréé (SM-1)');

    // (iv) Focus/curseur conservés ; contrôleur non recréé.
    final editable = tester.widget<EditableText>(intensiveField);
    expect(editable.focusNode.hasFocus, isTrue, reason: 'Focus perdu');
    expect(editable.controller.text, 'a' * 100);
    expect(editable.controller.selection.baseOffset, 100);
  });
}
