// CR parité éditeur markdown legacy DODLP (2026-08-11) — GAP-5/6/7.
//
// GAP-5 : jeu de styles NEUTRE par champ (`ZRichTextStyleSet`) — voie
//         « injection par l'hôte » (aucune valeur DODLP dans le paquet).
// GAP-6 : chrome carte OPT-IN (`ZMarkdownFieldChrome`) — en-tête icône+libellé,
//         pilule « Rédiger / Modifier / Valider », écriture différée opt-in.
// GAP-7 : hooks par champ — `textScaleFactor`, `ZRichTextFormulaSpec`.
//
// LIGNE DE BASE DANS LES DEUX SENS : chaque groupe garde AUSSI le défaut
// (`null` ⇒ rendu historique STRICTEMENT inchangé — AD-57).
//
// `flutter_quill`/`flutter_math_fork` en test = voie interne légitime (le
// barrel, lui, reste neutre — gardé par quill_signature_isolation_test).
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: ListView(children: <Widget>[child])),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

QuillEditor _editor(WidgetTester tester) =>
    tester.widget<QuillEditor>(find.byType(QuillEditor).first);

DefaultStyles _styles(WidgetTester tester) =>
    _editor(tester).config.customStyles!;

const ZFieldSpec _field =
    ZFieldSpec(name: 'notes', type: EditionFieldType.text, label: 'Contenu');

void main() {
  group('GAP-5 — jeu de styles NEUTRE par champ (injection hôte)', () {
    testWidgets(
        'LIGNE DE BASE : sans styleSet, gras/citation/code = défauts '
        '(aucune couleur signature, décoration de citation Quill intacte)',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final s = _styles(tester);
      // Défaut Quill : le gras n'a PAS de couleur propre (pas de rose DODLP).
      expect(s.bold?.color, isNull,
          reason: 'sans styleSet le gras doit rester sans couleur propre');
      expect(s.inlineCode?.backgroundColor, isNot(const Color(0xFF00FF00)));
      await _settle(tester);
    });

    testWidgets(
        'styleSet : chaque slot fourni est appliqué (couleurs, décorations, '
        'hauteurs de ligne, espacements) et FUSIONNÉ (le gras reste gras)',
        (tester) async {
      const boldColor = Color(0xFFAA0055);
      const italicColor = Color(0xFF0055AA);
      const codeBg = Color(0xFFEEEEEE);
      const quoteDeco = BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFF009999), width: 4),
        ),
      );
      const codeDeco = BoxDecoration(color: Color(0xFF112233));
      const set = ZRichTextStyleSet(
        bold: TextStyle(color: boldColor),
        italic: TextStyle(color: italicColor),
        underline: TextStyle(decorationColor: Color(0xFF00AA99)),
        strikeThrough: TextStyle(color: Color(0xFF777777)),
        inlineCode: TextStyle(color: Color(0xFFCC6600)),
        inlineCodeBackgroundColor: codeBg,
        inlineCodeRadius: Radius.circular(4),
        codeBlock: TextStyle(color: Color(0xFF117711)),
        codeBlockDecoration: codeDeco,
        quote: TextStyle(fontStyle: FontStyle.italic),
        quoteDecoration: quoteDeco,
        link: TextStyle(color: Color(0xFF3366FF)),
        sizeLarge: TextStyle(fontSize: 20),
        lineHeight: 2.0,
        headingLineHeight: 1.8,
        paragraphSpacing: ZRichTextSpacing(0, 0),
        headingSpacing: ZRichTextSpacing(16, 8),
      );
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        styleSet: set,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final s = _styles(tester);
      expect(s.bold?.color, boldColor);
      // FUSION, pas remplacement : la graisse Quill du gras survit au slot
      // qui ne porte qu'une couleur.
      expect(s.bold?.fontWeight, FontWeight.bold,
          reason: 'le slot gras doit FUSIONNER (merge), pas remplacer');
      expect(s.italic?.color, italicColor);
      expect(s.underline?.decorationColor, const Color(0xFF00AA99));
      expect(s.strikeThrough?.color, const Color(0xFF777777));
      expect(s.inlineCode?.style.color, const Color(0xFFCC6600));
      expect(s.inlineCode?.backgroundColor, codeBg);
      expect(s.inlineCode?.radius, const Radius.circular(4));
      expect(s.code?.style.color, const Color(0xFF117711));
      expect(s.code?.decoration, codeDeco);
      expect(s.quote?.decoration, quoteDeco);
      expect(s.link?.color, const Color(0xFF3366FF));
      expect(s.sizeLarge?.fontSize, 20);
      // Hauteurs de ligne : corps 2.0, titres 1.8 (parité qdsh).
      expect(s.paragraph?.style.height, 2.0);
      expect(s.lists?.style.height, 2.0);
      expect(s.quote?.style.height, 2.0);
      expect(s.h2?.style.height, 1.8);
      // Espacements : titres 16/8, paragraphe 0/0.
      expect(s.h1?.verticalSpacing.top, 16);
      expect(s.h1?.verticalSpacing.bottom, 8);
      expect(s.paragraph?.verticalSpacing.top, 0);
      await _settle(tester);
    });

    testWidgets('le LECTEUR (readOnly) honore le même styleSet',
        (tester) async {
      const bold = TextStyle(color: Color(0xFFAA0055));
      const spec = ZFieldSpec(
        name: 'notes',
        type: EditionFieldType.text,
        label: 'Contenu',
        readOnly: true,
      );
      final c = ZFormController(
        initialValues: <String, Object?>{
          'notes': <Map<String, dynamic>>[
            <String, dynamic>{'insert': 'lu\n'},
          ],
        },
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: spec,
        styleSet: const ZRichTextStyleSet(bold: bold),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(_styles(tester).bold?.color, const Color(0xFFAA0055));
      await _settle(tester);
    });
  });

  group('GAP-6 — chrome carte OPT-IN', () {
    testWidgets(
        'LIGNE DE BASE : chrome null ⇒ AUCUN en-tête carte, AUCUNE pilule '
        '(rendu historique inchangé)', (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.article_rounded), findsNothing);
      expect(find.byKey(const Key('z-markdown-chrome-action')), findsNothing);
      // Le libellé texte historique, lui, est rendu.
      expect(find.text('Contenu'), findsOneWidget);
      await _settle(tester);
    });

    testWidgets(
        'chrome fourni : en-tête (icône + libellé UNIQUE) + pilule « Valider » '
        'à cible ≥ 48 dp ; dégradé du PARAMÈTRE prioritaire', (tester) async {
      const g = <Color>[Color(0xFF667EEA), Color(0xFF764BA2)];
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        chrome: const ZMarkdownFieldChrome(
          gradient: g,
          onGradient: Color(0xFFFFFFFF),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.article_rounded), findsOneWidget);
      // Le libellé n'apparaît qu'UNE fois (l'en-tête remplace le libellé texte
      // — pas de doublon, précédent CR-IFFD-25).
      expect(find.text('Contenu'), findsOneWidget);
      final pill = find.byKey(const Key('z-markdown-chrome-action'));
      expect(pill, findsOneWidget);
      // RELEVÉ : le libellé de la pilule est résolu par
      // `label(context, 'z.markdown.commit')` — plus aucun littéral français
      // dans le paquet. Cet hôte ne monte pas de delegate ⇒ repli `en`.
      expect(find.text('Confirm'), findsOneWidget);
      // Cible tactile ≥ 48 dp par CONTRAINTE (AD-13) — jamais tester.getSize.
      final box = tester.widget<ConstrainedBox>(find
          .ancestor(of: pill, matching: find.byType(ConstrainedBox))
          .first);
      expect(box.constraints.minWidth, greaterThanOrEqualTo(48));
      expect(box.constraints.minHeight, greaterThanOrEqualTo(48));
      // Dégradé du paramètre : l'en-tête est teinté par la 1ʳᵉ couleur hôte.
      final header = tester.widgetList<Container>(find.byType(Container)).where(
        (w) {
          final d = w.decoration;
          return d is BoxDecoration && d.gradient is LinearGradient;
        },
      );
      expect(
        header.any((w) {
          final gr = (w.decoration! as BoxDecoration).gradient!;
          return (gr as LinearGradient).colors.first ==
              g.first.withValues(
                  alpha: ZMarkdownChromeReference.headerGradientOpacity);
        }),
        isTrue,
        reason: 'le dégradé hôte (paramètre) doit teinter l\'en-tête',
      );
      await _settle(tester);
    });

    testWidgets(
        'deferWrites FALSE (défaut) : l\'auto-save des hôtes existants est '
        'CONSERVÉ — la frappe écrit la tranche', (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        chrome: const ZMarkdownFieldChrome(),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      _editor(tester).controller.replaceText(
          0, 0, 'auto', const TextSelection.collapsed(offset: 4));
      await tester.pump();
      expect(
        (c.valueOf('notes')! as List).first,
        containsPair('insert', 'auto\n'),
        reason: 'sans deferWrites la frappe doit écrire la tranche (auto-save)',
      );
      await _settle(tester);
    });

    testWidgets(
        'deferWrites TRUE (opt-in, articulation legacy mef:93-101) : la frappe '
        'N\'écrit PAS ; « Valider » écrit ; la perte de focus écrit',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        chrome: const ZMarkdownFieldChrome(deferWrites: true),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final quill = _editor(tester).controller;
      quill.replaceText(
          0, 0, 'diff', const TextSelection.collapsed(offset: 4));
      await tester.pump();
      expect(c.valueOf('notes'), isNull,
          reason: 'écriture DIFFÉRÉE : la frappe ne doit pas écrire');
      // « Valider » commit.
      await tester.tap(find.byKey(const Key('z-markdown-chrome-action')));
      await tester.pump();
      expect(
        (c.valueOf('notes')! as List).first,
        containsPair('insert', 'diff\n'),
      );
      // Perte de focus : nouvelle frappe puis blur ⇒ commit (sans quoi la
      // sync guardée ré-injecterait la valeur externe périmée).
      final focus = _editor(tester).focusNode;
      focus.requestFocus();
      await tester.pump();
      quill.replaceText(
          4, 0, '2', const TextSelection.collapsed(offset: 5));
      await tester.pump();
      expect(
        (c.valueOf('notes')! as List).first,
        containsPair('insert', 'diff\n'),
        reason: 'toujours différé pendant la frappe focalisée',
      );
      focus.unfocus();
      await tester.pump();
      expect(
        (c.valueOf('notes')! as List).first,
        containsPair('insert', 'diff2\n'),
        reason: 'le blur doit committer (parité legacy)',
      );
      await _settle(tester);
    });

    testWidgets(
        'compteur de caractères VIVANT sous deferWrites (notifier granulaire)',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        characterLimit: 10,
        chrome: const ZMarkdownFieldChrome(deferWrites: true),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('0 / 10'), findsOneWidget);
      _editor(tester).controller.replaceText(
          0, 0, 'abc', const TextSelection.collapsed(offset: 3));
      await tester.pump();
      expect(find.text('3 / 10'), findsOneWidget,
          reason: 'le compteur doit vivre SANS écriture de tranche');
      await _settle(tester);
    });

    testWidgets(
        'mode block + chrome : pilule « Rédiger » (vide) dans l\'en-tête, '
        'bouton bas historique ABSENT ; le tap ouvre le plein-écran',
        (tester) async {
      final c = ZFormController(
          initialValues: const <String, Object?>{'notes': null});
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ValueListenableBuilder<Object?>(
        valueListenable: c.fieldListenable('notes'),
        builder: (context, value, _) => ZMarkdownField.fromContext(
          key: const ValueKey<String>('z-markdown-notes'),
          ctx: ZFieldWidgetContext(
            field: _field,
            value: value,
            onChanged: (v) => c.setValue('notes', v),
          ),
          mode: ZMarkdownFieldMode.block,
          chrome: const ZMarkdownFieldChrome(),
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      // RELEVÉ : `label(context, 'z.markdown.write')`, repli `en`.
      expect(find.text('Write'), findsOneWidget);
      expect(find.byKey(const Key('z-markdown-block-edit')), findsNothing,
          reason: 'sous chrome, une SEULE affordance (la pilule d\'en-tête)');
      await tester.tap(find.byKey(const Key('z-markdown-chrome-action')));
      await tester.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget);
      await tester.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await tester.pumpAndSettle();
      await _settle(tester);
    });
  });

  group('GAP-7 — hooks par champ (échelle, formules)', () {
    testWidgets(
        'LIGNE DE BASE : sans textScaleFactor, l\'échelle ambiante est intacte',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final ctxEditor = tester.element(find.byType(QuillEditor).first);
      // Identité (×1) : 10 dp restent 10 dp — aucune échelle imposée.
      expect(MediaQuery.textScalerOf(ctxEditor).scale(10), 10);
      await _settle(tester);
    });

    testWidgets(
        'textScaleFactor: 1.5 ⇒ MediaQuery LOCAL TextScaler.linear(1.5) '
        '(Quill lit textScalerOf — text_line.dart:182)', (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        textScaleFactor: 1.5,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final ctxEditor = tester.element(find.byType(QuillEditor).first);
      expect(
        MediaQuery.textScalerOf(ctxEditor),
        const TextScaler.linear(1.5),
      );
      await _settle(tester);
    });

    testWidgets(
        'formulaSpec : style + facteur inline appliqués au rendu Math '
        '(fontSize 20 × 2 = 40) ; sans spec, rendu historique', (tester) async {
      final seeded = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': r'E=mc^2'},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      final c = ZFormController(
          initialValues: <String, Object?>{'notes': seeded});
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        formulaSpec: const ZRichTextFormulaSpec(
          textStyle: TextStyle(color: Color(0xFF7700AA), fontSize: 20),
          inlineScaleFactor: 2,
        ),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final math = tester.widget<Math>(find.byType(Math).first);
      expect(math.textStyle?.color, const Color(0xFF7700AA));
      expect(math.textStyle?.fontSize, 40,
          reason: 'inlineScaleFactor doit multiplier la taille du style');
      await _settle(tester);
    });

    testWidgets('LIGNE DE BASE formules : sans spec, style du point d\'insertion',
        (tester) async {
      final seeded = <Map<String, dynamic>>[
        <String, dynamic>{
          'insert': <String, dynamic>{'latex': r'E=mc^2'},
        },
        <String, dynamic>{'insert': '\n'},
      ];
      final c = ZFormController(
          initialValues: <String, Object?>{'notes': seeded});
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));
      final math = tester.widget<Math>(find.byType(Math).first);
      expect(math.textStyle?.color, isNot(const Color(0xFF7700AA)));
      expect(math.textStyle?.fontSize, isNot(40));
      await _settle(tester);
    });
  });
}
