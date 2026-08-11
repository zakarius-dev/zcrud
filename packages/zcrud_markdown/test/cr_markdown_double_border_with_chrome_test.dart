// CR double-bordure sous chrome carte (2026-08-11, pilote DODLP — champ
// `notes` du formulaire « Poste d'accostage »).
//
// Voie (a) de la CR : quand un `ZMarkdownFieldChrome` est actif, la CARTE
// porte le cadre — la zone d'édition ne dessine PLUS sa propre bordure ni son
// propre `fieldPadding` (la carte applique déjà `fieldPadding` autour du
// contenu). Précédent : `ZMarkdownReaderChrome.none` (CR-IFFD-73) retire cadre
// ET padding, « l'appelant habille ».
//
// Pas d'interrupteur (b) : MESURÉ, la carte du chrome dessine TOUJOURS sa
// bordure (`Border.all`, largeurs `ZMarkdownChromeReference.borderWidthFilled/
// Empty`, non configurables) — supprimer la bordure interne sous chrome ne
// peut donc jamais laisser le champ sans aucun cadre.
//
// LIGNE DE BASE DANS LES DEUX SENS : les gardes « chrome ⇒ un seul cadre »
// sont ROUGES sur v0.84.0 ; les gardes « sans chrome ⇒ rendu historique »
// sont vertes avant ET après.
//
// `flutter_quill` en test = voie interne légitime (le barrel reste neutre —
// gardé par quill_signature_isolation_test).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

Widget _host(Widget child, {Size size = const Size(800, 1200)}) => MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: ListView(children: <Widget>[child])),
        ),
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

const ZFieldSpec _field =
    ZFieldSpec(name: 'notes', type: EditionFieldType.text, label: 'Contenu');

/// Les `DecoratedBox` ANCÊTRES de [editor] qui dessinent une bordure — chaque
/// élément est un cadre visuel empilé autour de la zone d'édition.
List<BoxDecoration> _borderedAncestors(WidgetTester tester, Finder editor) =>
    tester
        .widgetList<DecoratedBox>(
            find.ancestor(of: editor, matching: find.byType(DecoratedBox)))
        .map((w) => w.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.border != null)
        .toList();

/// Les `Padding` ancêtres de [editor] portant exactement le `fieldPadding`
/// du thème (défaut `ZcrudTheme`).
int _fieldPaddingAncestors(WidgetTester tester, Finder editor) => tester
    .widgetList<Padding>(
        find.ancestor(of: editor, matching: find.byType(Padding)))
    .where((w) => w.padding == const ZcrudTheme().fieldPadding)
    .length;

/// La `Semantics(textField:)` de la zone d'édition (AD-13) — doit survivre à
/// la suppression du cadre interne.
Finder _textFieldSemantics() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.textField == true);

void main() {
  group('CR double-bordure — chrome actif ⇒ la carte porte le SEUL cadre', () {
    testWidgets(
        'voie controller + chrome : UN SEUL DecoratedBox bordé autour de '
        'l\'éditeur (la carte, rayon cardRadius) — plus de bordure de zone '
        'd\'édition ; Semantics(textField) conservée', (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
        chrome: const ZMarkdownFieldChrome(),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final editor = find.byType(QuillEditor).first;
      final frames = _borderedAncestors(tester, editor);
      expect(frames.length, 1,
          reason: 'sous chrome, la CARTE est le seul cadre — deux cadres '
              'imbriqués est le défaut de la CR (v0.84.0 en dessinait 2)');
      expect(
        frames.single.borderRadius,
        const BorderRadius.all(ZMarkdownChromeReference.cardRadius),
        reason: 'le cadre restant doit être la carte du chrome (rayon 14), '
            'pas la bordure interne de la zone d\'édition',
      );
      // Le texte ne colle pas au bord : le `fieldPadding` est appliqué UNE
      // fois (par la carte) — plus par la zone d'édition (padding doublé
      // en v0.84.0).
      expect(_fieldPaddingAncestors(tester, editor), 1,
          reason: 'un seul fieldPadding : celui de la carte');
      // AD-13 : la sémantique de champ de texte survit au retrait du cadre.
      expect(_textFieldSemantics(), findsOneWidget);
      await _settle(tester);
    });

    testWidgets(
        'voie ctx mode inline + chrome : même contrat (un seul cadre = la '
        'carte, fieldPadding unique)', (tester) async {
      Object? value;
      await tester.pumpWidget(_host(ZMarkdownField.fromContext(
        key: const ValueKey('z-markdown-notes'),
        ctx: ZFieldWidgetContext(
          field: const ZFieldSpec(
            name: 'notes',
            type: EditionFieldType.inlineMarkdown,
            label: 'Contenu',
          ),
          value: null,
          onChanged: (v) => value = v,
        ),
        mode: ZMarkdownFieldMode.inline,
        chrome: const ZMarkdownFieldChrome(),
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final editor = find.byType(QuillEditor).first;
      final frames = _borderedAncestors(tester, editor);
      expect(frames.length, 1,
          reason: 'inline sous chrome : un seul cadre (la carte)');
      expect(
        frames.single.borderRadius,
        const BorderRadius.all(ZMarkdownChromeReference.cardRadius),
      );
      expect(_fieldPaddingAncestors(tester, editor), 1);
      expect(value, isNull, reason: 'aucune écriture au montage');
      await _settle(tester);
    });

    testWidgets(
        'plein-écran depuis un champ inline CHROMÉ : le dialog garde son '
        'cadre UNIQUE (la carte du chrome n\'enveloppe pas le dialog — '
        'aucun empilement, mesuré)', (tester) async {
      await tester.pumpWidget(_host(ZMarkdownField.fromContext(
        key: const ValueKey('z-markdown-notes'),
        ctx: ZFieldWidgetContext(
          field: const ZFieldSpec(
            name: 'notes',
            type: EditionFieldType.inlineMarkdown,
            label: 'Contenu',
          ),
          value: null,
          onChanged: (_) {},
        ),
        mode: ZMarkdownFieldMode.inline,
        chrome: const ZMarkdownFieldChrome(),
      )));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byKey(const Key('z-markdown-fullscreen-toggle')));
      await tester.pumpAndSettle();

      final dialogEditor = find.descendant(
        of: find.byType(ZRichTextFullscreenDialog),
        matching: find.byType(QuillEditor),
      );
      expect(dialogEditor, findsOneWidget);
      final frames = _borderedAncestors(tester, dialogEditor);
      expect(frames.length, 1,
          reason: 'le dialog plein-écran dessine SA bordure de zone — et '
              'elle seule (la carte du chrome reste dans le formulaire)');
      // Fermer proprement avant le démontage.
      await tester.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await tester.pumpAndSettle();
      await _settle(tester);
    });
  });

  group('LIGNE DE BASE — sans chrome, rendu historique STRICTEMENT inchangé',
      () {
    testWidgets(
        'voie controller sans chrome : la bordure de zone d\'édition '
        '(rayon radiusM) matérialise le champ, fieldPadding présent',
        (tester) async {
      final c = ZFormController();
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(ZMarkdownField(
        key: const ValueKey('notes'),
        controller: c,
        field: _field,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final editor = find.byType(QuillEditor).first;
      final frames = _borderedAncestors(tester, editor);
      expect(frames.length, 1,
          reason: 'sans chrome, LE cadre du champ est la bordure de zone');
      expect(
        frames.single.borderRadius,
        BorderRadius.all(const ZcrudTheme().radiusM),
        reason: 'rayon historique radiusM — pas celui de la carte',
      );
      expect(_fieldPaddingAncestors(tester, editor), 1);
      expect(_textFieldSemantics(), findsOneWidget);
      await _settle(tester);
    });

    testWidgets(
        'voie ctx mode inline sans chrome : bordure de zone conservée '
        '(rayon radiusM)', (tester) async {
      await tester.pumpWidget(_host(ZMarkdownField.fromContext(
        key: const ValueKey('z-markdown-notes'),
        ctx: ZFieldWidgetContext(
          field: const ZFieldSpec(
            name: 'notes',
            type: EditionFieldType.inlineMarkdown,
            label: 'Contenu',
          ),
          value: null,
          onChanged: (_) {},
        ),
        mode: ZMarkdownFieldMode.inline,
      )));
      await tester.pump(const Duration(milliseconds: 50));

      final editor = find.byType(QuillEditor).first;
      final frames = _borderedAncestors(tester, editor);
      expect(frames.length, 1);
      expect(
        frames.single.borderRadius,
        BorderRadius.all(const ZcrudTheme().radiusM),
      );
      await _settle(tester);
    });
  });
}
