// MIN-1 — Options de champ rich-text : hauteur bornée (minLines/maxLines, mode
// compact), limite de caractères (compteur + troncature souple), styles de
// titres dérivés du thème (customStyles Quill, FR-26 zéro couleur en dur).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillController _quill(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor).first).controller;

QuillEditorConfig _config(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor).first).config;

const _field = ZFieldSpec(name: 'notes', type: EditionFieldType.text);

void main() {
  group('MIN-1 — minLines/maxLines (hauteur bornée)', () {
    testWidgets('sans borne : éditeur NON scrollable (E6-1 inchangé)',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_config(tester).scrollable, isFalse);
      await _settle(tester);
    });

    testWidgets('maxLines fourni : éditeur scrollable + hauteur plafonnée',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        minLines: 2,
        maxLines: 4,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_config(tester).scrollable, isTrue);
      // La hauteur de l'éditeur est bornée (< hauteur d'écran).
      final h = tester.getSize(find.byType(QuillEditor).first).height;
      expect(h, lessThan(200));
      await _settle(tester);
    });
  });

  group('MIN-1 — characterLimit (compteur + troncature)', () {
    testWidgets('compteur affiché ; frappe au-delà de la limite tronquée',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        characterLimit: 5,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final q = _quill(tester);
      q.updateSelection(
          const TextSelection.collapsed(offset: 0), ChangeSource.local);
      for (var i = 0; i < 10; i++) {
        final at = q.selection.baseOffset;
        q.replaceText(at, 0, 'x', TextSelection.collapsed(offset: at + 1));
        await tester.pump();
      }

      final plain = q.document.toPlainText().replaceAll('\n', '');
      expect(plain.length, lessThanOrEqualTo(5),
          reason: 'la troncature souple n\'a pas plafonné la saisie');
      // Compteur visible reflétant la limite.
      expect(find.textContaining('/ 5'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets('sans characterLimit : aucun compteur (E6-1 inchangé)',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('/'), findsNothing);
      await _settle(tester);
    });
  });

  group('MIN-1 — styles Quill thémés (customStyles)', () {
    testWidgets('éditeur : customStyles dérivés du thème appliqués',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final styles = _config(tester).customStyles;
      expect(styles, isNotNull);
      expect(styles!.h1, isNotNull);
      expect(styles.h2, isNotNull);
      await _settle(tester);
    });

    testWidgets('lecteur readOnly : customStyles thémés appliqués aussi',
        (tester) async {
      await tester.pumpWidget(_host(const ZMarkdownReader(
        value: <Map<String, dynamic>>[
          <String, dynamic>{'insert': 'Titre\n'},
        ],
        label: 'notes',
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_config(tester).customStyles, isNotNull);
      await _settle(tester);
    });
  });
}
