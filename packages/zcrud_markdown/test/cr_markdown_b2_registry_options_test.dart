// CR géo/markdown 2026-08-11 — point B2 : les options par-champ de
// `ZMarkdownField` posées via `registerZMarkdownFields` AGISSENT sur le champ
// rendu par le registre.
//
// 🔴 MOTIF : GAP-9 (`toolbarConfig.themedBarBackground`, livré v0.82.0) était
// INUTILISABLE par un hôte — le widget est construit par le `ZWidgetRegistry`
// (seule voie disponible pour une app), et l'enregistrement n'exposait pas le
// paramètre. Ces gardes prouvent le CHEMIN COMPLET : registre → builder →
// `ZMarkdownField.fromContext` → rendu (pas seulement la signature — celle-ci
// est gardée par `z_markdown_registration_parity_test.dart`).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show QuillSimpleToolbar;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

ZFieldSpec _inlineField(String name, {String? label}) => ZFieldSpec(
      name: name,
      type: EditionFieldType.inlineMarkdown,
      label: label,
    );

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Widget _app(ZFormController controller, List<ZFieldSpec> fields,
        ZWidgetRegistry registry) =>
    MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(1200, 900)),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            widgetRegistry: registry,
            child: Scaffold(
              body: DynamicEdition(controller: controller, fields: fields),
            ),
          ),
        ),
      ),
    );

/// Nettoyage : démonte l'arbre (annule le Timer de clignotement du curseur).
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

/// Le `DecoratedBox` GAP-9 enveloppant la toolbar, s'il existe.
Iterable<DecoratedBox> _toolbarDecorations(WidgetTester t) => t
    .widgetList<DecoratedBox>(find.ancestor(
      of: find.byType(QuillSimpleToolbar),
      matching: find.byType(DecoratedBox),
    ))
    .where((box) {
      final deco = box.decoration;
      return deco is BoxDecoration && deco.border is Border;
    });

void main() {
  group('B2 — `toolbarConfig` posé au REGISTRE agit sur le champ rendu', () {
    testWidgets(
        'themedBarBackground via registre : fond `surfaceContainerLow` + '
        'liseré bas `outlineVariant` autour de la barre', (t) async {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(
        r,
        toolbarConfig: ZRichTextToolbarConfig.minimal
            .copyWith(themedBarBackground: true),
      );
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_app(c, <ZFieldSpec>[_inlineField('note')], r));
      await t.pump();

      final ColorScheme scheme = ThemeData().colorScheme;
      final decorations = _toolbarDecorations(t).where((box) =>
          (box.decoration as BoxDecoration).color ==
          scheme.surfaceContainerLow);
      expect(decorations, isNotEmpty,
          reason: '🔴 B2 : `themedBarBackground` posé par '
              '`registerZMarkdownFields` doit peindre la barre (GAP-9) — '
              "sinon la fonctionnalité livrée en v0.82.0 est inatteignable "
              'par un hôte');
      final BoxDecoration deco =
          decorations.first.decoration as BoxDecoration;
      expect((deco.border! as Border).bottom.color, scheme.outlineVariant);
      await _settle(t);
    });

    // RELEVÉ (contrat DÉLIBÉRÉMENT changé) : ce cas assertait qu'un registre
    // SANS `toolbarConfig` ne peignait aucun fond de barre. C'est précisément
    // le défaut corrigé — un champ compact rend désormais sa barre habillée
    // sans qu'un hôte ne déclare quoi que ce soit, et les deux hôtes qui
    // posaient ce drapeau à la main n'ont plus à le faire. Le cas est
    // RETOURNÉ : il garde la même mécanique (registre → builder → rendu) et
    // asserte le nouveau défaut.
    testWidgets('sans `toolbarConfig` au registre : la barre est habillée PAR '
        'DÉFAUT (fond `surfaceContainerLow` + liseré `outlineVariant`)',
        (t) async {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(r);
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_app(c, <ZFieldSpec>[_inlineField('note')], r));
      await t.pump();

      final ColorScheme scheme = ThemeData().colorScheme;
      final decorations = _toolbarDecorations(t).where((box) =>
          (box.decoration as BoxDecoration).color ==
          scheme.surfaceContainerLow);
      expect(decorations, isNotEmpty,
          reason: '🔴 le champ compact doit rendre sa barre habillée SANS '
              'aucune déclaration hôte — c\'est le bénéfice du défaut');
      expect(
          ((decorations.first.decoration as BoxDecoration).border! as Border)
              .bottom
              .color,
          scheme.outlineVariant);
      await _settle(t);
    });

    testWidgets('un `toolbarConfig` posé au registre PRIME sur le défaut : '
        '`themedBarBackground: false` retire l\'habillage', (t) async {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(
        r,
        toolbarConfig: ZRichTextToolbarConfig.inline
            .copyWith(themedBarBackground: false),
      );
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_app(c, <ZFieldSpec>[_inlineField('note')], r));
      await t.pump();

      final ColorScheme scheme = ThemeData().colorScheme;
      expect(
          _toolbarDecorations(t).where((box) =>
              (box.decoration as BoxDecoration).color ==
              scheme.surfaceContainerLow),
          isEmpty,
          reason: 'le paramètre hôte l\'emporte sur le défaut du socle');
      await _settle(t);
    });

    testWidgets('choix de boutons via registre : `showBold: false` éteint le '
        'bouton gras du champ rendu', (t) async {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(
        r,
        toolbarConfig: ZRichTextToolbarConfig.minimal.copyWith(showBold: false),
      );
      final c = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(_app(c, <ZFieldSpec>[_inlineField('note')], r));
      await t.pump();

      final QuillSimpleToolbar bar =
          t.widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar));
      expect(bar.config.showBoldButton, isFalse,
          reason: '🔴 B2 : la config de boutons posée au registre doit '
              'piloter la barre rendue (défaut `minimal` : gras ALLUMÉ)');
      await _settle(t);
    });
  });

  group('B2 — `showLabel` posé au REGISTRE agit sur le champ rendu', () {
    testWidgets('showLabel: false ⇒ libellé absent ; défaut ⇒ présent',
        (t) async {
      final r = ZWidgetRegistry();
      registerZMarkdownFields(r, showLabel: false);
      final c1 = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(
          _app(c1, <ZFieldSpec>[_inlineField('note', label: 'Remarques')], r));
      await t.pump();
      expect(find.text('Remarques'), findsNothing,
          reason: '🔴 `showLabel: false` au registre doit masquer le libellé '
              "(hôte posant le sien — CR-IFFD-25)");
      await _settle(t);

      final r2 = ZWidgetRegistry();
      registerZMarkdownFields(r2);
      final c2 = _controller(<String, Object?>{'note': null});
      await t.pumpWidget(
          _app(c2, <ZFieldSpec>[_inlineField('note', label: 'Remarques')], r2));
      await t.pump();
      expect(find.text('Remarques'), findsOneWidget,
          reason: 'omis ⇒ libellé rendu — désormais dans l\'EN-TÊTE de la '
              'carte par défaut, et non plus au-dessus du champ');
      await _settle(t);
    });
  });
}
