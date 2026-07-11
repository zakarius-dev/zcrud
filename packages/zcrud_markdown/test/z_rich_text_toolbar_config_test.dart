// DP-22 (M20) — `ZRichTextToolbarConfig` : granularité PAR BOUTON de la toolbar
// rich-text (présets full/minimal/markdown), et son intégration à `ZMarkdownField`
// (voie `controller`).
//
// RÉTRO-COMPAT (NON-NÉGOCIABLE) :
//   - un `ZMarkdownField` SANS `toolbarConfig` conserve EXACTEMENT le comportement
//     E6-1/DP-3 (préset FULL : tous les boutons, dont latex/table/image/vidéo) ;
//   - le drapeau `showToolbar` reste honoré (masque toute la barre) ;
//   - `toolbarConfig` FOURNIE pilote chaque bouton.
//
// AD-1/AD-7 : la config est une DONNÉE pure (booléens) — aucun type Quill.
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: child));

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

Set<String?> _customTooltips(WidgetTester tester) => tester
    .widgetList<QuillToolbarCustomButton>(find.byType(QuillToolbarCustomButton))
    .map((b) => b.options.tooltip)
    .toSet();

const _field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

void main() {
  group('présets — valeurs de drapeaux', () {
    test('full = tous les groupes activés', () {
      const c = ZRichTextToolbarConfig.full;
      expect(c.showBold, isTrue);
      expect(c.showColor, isTrue);
      expect(c.showAlignment, isTrue);
      expect(c.showLatexButton, isTrue);
      expect(c.showTableButton, isTrue);
      expect(c.showImageButton, isTrue);
      expect(c.showVideoButton, isTrue);
    });

    test('minimal = style de base + listes, SANS police/couleur/embeds', () {
      const c = ZRichTextToolbarConfig.minimal;
      expect(c.showBold, isTrue);
      expect(c.showItalic, isTrue);
      expect(c.showUnderline, isTrue);
      expect(c.showList, isTrue);
      // masqués
      expect(c.showFontFamily, isFalse);
      expect(c.showFontSize, isFalse);
      expect(c.showColor, isFalse);
      expect(c.showBackgroundColor, isFalse);
      expect(c.showAlignment, isFalse);
      expect(c.showLatexButton, isFalse);
      expect(c.showTableButton, isFalse);
      expect(c.showImageButton, isFalse);
      expect(c.showVideoButton, isFalse);
    });

    test('markdown = style + listes + insertions (embeds), sans couleur/aligne', () {
      const c = ZRichTextToolbarConfig.markdown;
      expect(c.showHeaderStyle, isTrue);
      expect(c.showBlockQuote, isTrue);
      expect(c.showCodeBlock, isTrue);
      expect(c.showLink, isTrue);
      expect(c.showLatexButton, isTrue);
      expect(c.showTableButton, isTrue);
      expect(c.showImageButton, isTrue);
      expect(c.showVideoButton, isTrue);
      // divergences markdown
      expect(c.showColor, isFalse);
      expect(c.showBackgroundColor, isFalse);
      expect(c.showAlignment, isFalse);
      expect(c.showFontFamily, isFalse);
    });
  });

  group('copyWith / égalité', () {
    test('copyWith remplace uniquement le drapeau fourni', () {
      const base = ZRichTextToolbarConfig.markdown;
      final c = base.copyWith(showImageButton: false, showColor: true);
      expect(c.showImageButton, isFalse);
      expect(c.showColor, isTrue);
      // inchangés
      expect(c.showTableButton, base.showTableButton);
      expect(c.showVideoButton, base.showVideoButton);
    });

    test('== et hashCode cohérents sur les drapeaux', () {
      const a = ZRichTextToolbarConfig.full;
      final b = const ZRichTextToolbarConfig().copyWith();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(ZRichTextToolbarConfig.minimal)));
    });
  });

  group('intégration ZMarkdownField (voie controller)', () {
    testWidgets('RÉTRO-COMPAT : sans toolbarConfig → préset FULL (tous boutons)',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final tips = _customTooltips(tester);
      expect(
        tips.containsAll(<String>{
          'Insérer une formule',
          'Insérer un tableau',
          'Insérer une image',
          'Insérer une vidéo',
        }),
        isTrue,
        reason: 'défaut (rétro-compat) = tous les boutons custom présents',
      );
      // Boutons natifs (échantillon).
      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('RÉTRO-COMPAT : showToolbar:false masque toute la barre',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
        showToolbar: false,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(QuillSimpleToolbar), findsNothing,
          reason: 'showToolbar:false doit masquer la barre (parité E6-1)');
      await _settle(tester);
    });

    testWidgets('toolbarConfig granulaire → masque les boutons ciblés',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
        toolbarConfig: const ZRichTextToolbarConfig(
          showImageButton: false,
          showVideoButton: false,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final tips = _customTooltips(tester);
      expect(tips.contains('Insérer une formule'), isTrue);
      expect(tips.contains('Insérer un tableau'), isTrue);
      expect(tips.contains('Insérer une image'), isFalse,
          reason: 'showImageButton:false doit retirer le bouton image');
      expect(tips.contains('Insérer une vidéo'), isFalse);
      await _settle(tester);
    });

    testWidgets('préset minimal → aucun bouton custom (latex/table/image/vidéo)',
        (tester) async {
      final controller = ZFormController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: controller,
        field: _field,
        toolbarConfig: ZRichTextToolbarConfig.minimal,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      expect(_customTooltips(tester), isEmpty,
          reason: 'minimal masque tous les boutons d\'insertion custom');
      // La barre reste montée (boutons natifs de base présents).
      expect(find.byType(QuillSimpleToolbar), findsOneWidget);
      await _settle(tester);
    });
  });
}
