// CR toolbar multi-rangées PAR SURFACE (2026-08-11) — correction de DÉFAUT.
//
// Constat device (pilote DODLP, formulaire Berth, champ `notes`
// `inlineMarkdown`) : `multiRow` était un booléen UNIQUE partagé par le champ
// en flux ET le dialog plein-écran — il ne peut pas être juste pour les deux.
// `true` ⇒ ~10 rangées qui noient le formulaire en flux ; `false` (défaut
// v0.83) ⇒ plein écran privé de multi-rangées alors que la place abonde.
//
// Correctif : `multiRow` devient TRI-ÉTAT (`bool?`). `null` (défaut) = AUTO —
// une rangée pour toute barre rendue DANS LE FLUX d'un formulaire (modes
// `inline` ET voie `controller`), multi-rangées dans `ZRichTextFullscreenDialog`.
// `true`/`false` = forçage hôte, respecté SUR LES DEUX surfaces (AD-4).
//
// Mode `block` (tranché, mesuré ici) : le rendu en flux du mode block ne monte
// AUCUNE toolbar (aperçu lecteur + bouton — vérifié par G6) ; sa seule barre
// vit dans le dialog plein-écran ⇒ elle y est multi-rangées via l'AUTO du
// dialog. Aucun cas « block en flux avec barre » n'existe.
//
// DISCIPLINE R3 (sens baseline) : sur v0.83.0, G2 (AUTO plein-écran) et G5
// (tri-état copyWith) sont ROUGES ; G1/G3/G4/G6 verts (le défaut en flux
// donnait déjà 1 rangée — ces gardes discriminent la SURFACE, pas le défaut).
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show QuillSimpleToolbar;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

ZFieldSpec _field(String name,
        {EditionFieldType type = EditionFieldType.inlineMarkdown}) =>
    ZFieldSpec(name: name, type: type, label: name);

/// Champ rich-text voie `ctx` monté dans un hôte minimal (flux de formulaire).
Widget _inlineHost({
  ZRichTextToolbarConfig? toolbarConfig,
  ZMarkdownFieldMode mode = ZMarkdownFieldMode.inline,
  Size size = const Size(400, 800),
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: ZcrudScope(
          child: Scaffold(
            body: SingleChildScrollView(
              child: ZMarkdownField.fromContext(
                key: const ValueKey<String>('notes'),
                ctx: ZFieldWidgetContext(
                  field: _field('notes',
                      type: mode == ZMarkdownFieldMode.inline
                          ? EditionFieldType.inlineMarkdown
                          : EditionFieldType.markdown),
                  value: null,
                  onChanged: (_) {},
                ),
                mode: mode,
                toolbarConfig: toolbarConfig,
              ),
            ),
          ),
        ),
      ),
    );

/// Dialog plein-écran monté directement (surface plein-écran).
Widget _fullscreenHost({ZRichTextToolbarConfig? toolbarConfig}) => MaterialApp(
      home: ZcrudScope(
        child: Scaffold(
          body: ZRichTextFullscreenDialog(
            initialValue: null,
            toolbarConfig: toolbarConfig,
            fullscreen: true,
          ),
        ),
      ),
    );

/// `multiRowsDisplay` de la barre Quill effectivement MONTÉE (pas de la
/// config zcrud) — c'est le rendu qui fait foi.
bool _mountedMultiRow(WidgetTester t) => t
    .widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
    .config
    .multiRowsDisplay;

/// Démonte l'arbre (annule le Timer de clignotement du curseur Quill).
Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

void main() {
  group('AUTO (défaut null) — le nombre de rangées dérive de la SURFACE', () {
    testWidgets(
        'G1 — flux (inline, sans config hôte) : la barre montée est '
        'MONO-rangée', (t) async {
      await t.pumpWidget(_inlineHost());
      await t.pump();
      expect(_mountedMultiRow(t), isFalse,
          reason: 'en flux, un champ ne doit jamais consommer la hauteur '
              'de l\'écran (CR 2026-08-11)');
      await _settle(t);
    });

    testWidgets(
        'G1b — flux (inline, préset markdown AUTO fourni par l\'hôte) : '
        'toujours MONO-rangée', (t) async {
      await t.pumpWidget(
          _inlineHost(toolbarConfig: ZRichTextToolbarConfig.markdown));
      await t.pump();
      expect(_mountedMultiRow(t), isFalse,
          reason: 'fournir un préset (multiRow AUTO) ne force rien : la '
              'surface flux garde sa rangée unique');
      await _settle(t);
    });

    testWidgets(
        'G2 — plein écran (sans config hôte) : la barre montée est '
        'MULTI-rangées (ROUGE sur v0.83.0)', (t) async {
      await t.pumpWidget(_fullscreenHost());
      await t.pump();
      expect(_mountedMultiRow(t), isTrue,
          reason: 'c\'est en plein écran que la place existe — la '
              'découvrabilité des boutons y prime (CR 2026-08-11)');
      await _settle(t);
    });

    testWidgets(
        'G2b — plein écran (préset markdown AUTO transmis par le champ) : '
        'MULTI-rangées aussi', (t) async {
      await t.pumpWidget(
          _fullscreenHost(toolbarConfig: ZRichTextToolbarConfig.markdown));
      await t.pump();
      expect(_mountedMultiRow(t), isTrue);
      await _settle(t);
    });
  });

  group('Forçage hôte (AD-4) — true/false respectés sur les DEUX surfaces',
      () {
    testWidgets('G3 — multiRow: true forcé en FLUX : respecté', (t) async {
      await t.pumpWidget(_inlineHost(
          toolbarConfig:
              ZRichTextToolbarConfig.markdown.copyWith(multiRow: true)));
      await t.pump();
      expect(_mountedMultiRow(t), isTrue,
          reason: 'un hôte qui force garde la main, même contre l\'AUTO');
      await _settle(t);
    });

    testWidgets(
        'G4 — multiRow: false forcé en PLEIN ÉCRAN (contournement DODLP '
        'v0.83) : respecté à l\'identique', (t) async {
      await t.pumpWidget(_fullscreenHost(
          toolbarConfig:
              ZRichTextToolbarConfig.markdown.copyWith(multiRow: false)));
      await t.pump();
      expect(_mountedMultiRow(t), isFalse,
          reason: 'un hôte qui posait `false` explicitement garde EXACTEMENT '
              'son comportement (migration bool→bool? non cassante)');
      await _settle(t);
    });
  });

  group('Tri-état copyWith — « non fourni » ≠ « null explicite »', () {
    test('G5 — omis ⇒ conservé ; null explicite ⇒ retour AUTO ; bool ⇒ forcé '
        '(ROUGE sur v0.83.0)', () {
      // Omis : un copyWith SANS multiRow ne détruit pas l'AUTO du préset…
      expect(
          ZRichTextToolbarConfig.markdown
              .copyWith(showUndoRedo: true)
              .multiRow,
          isNull,
          reason: 'le patron DODLP (copyWith d\'habillage) doit conserver '
              'l\'AUTO, pas le figer');
      // … ni un forçage existant.
      expect(
          ZRichTextToolbarConfig.markdown
              .copyWith(multiRow: true)
              .copyWith(showUndoRedo: true)
              .multiRow,
          isTrue);
      // Forçages.
      expect(ZRichTextToolbarConfig.markdown.copyWith(multiRow: false).multiRow,
          isFalse);
      expect(ZRichTextToolbarConfig.markdown.copyWith(multiRow: true).multiRow,
          isTrue);
      // Null EXPLICITE : retour à l'AUTO (sentinelle — piège classique du
      // copyWith `??` qui confond « null fourni » et « non fourni »).
      expect(
          ZRichTextToolbarConfig.markdown
              .copyWith(multiRow: true)
              .copyWith(multiRow: null)
              .multiRow,
          isNull);
      // Défauts : constructeur nu et présets sont AUTO.
      expect(const ZRichTextToolbarConfig().multiRow, isNull);
      expect(ZRichTextToolbarConfig.full.multiRow, isNull);
      expect(ZRichTextToolbarConfig.minimal.multiRow, isNull);
      expect(ZRichTextToolbarConfig.markdown.multiRow, isNull);
    });

    test('G5b — égalité/hash distinguent AUTO et forçages', () {
      const auto = ZRichTextToolbarConfig();
      final forcedFalse = auto.copyWith(multiRow: false);
      final forcedTrue = auto.copyWith(multiRow: true);
      expect(auto == forcedFalse, isFalse);
      expect(auto == forcedTrue, isFalse);
      expect(forcedFalse == forcedTrue, isFalse);
      expect(auto, equals(auto.copyWith()));
    });
  });

  group('Mode block — mesure fondant la décision (CR « à discuter »)', () {
    testWidgets(
        'G6 — block en flux : AUCUNE toolbar montée (la question du '
        'multi-rangées en flux ne s\'y pose pas) ; hauteur bornée', (t) async {
      await t.pumpWidget(_inlineHost(
        mode: ZMarkdownFieldMode.block,
        toolbarConfig: ZRichTextToolbarConfig.markdown,
      ));
      await t.pump();
      expect(find.byType(QuillSimpleToolbar), findsNothing,
          reason: 'le mode block rend un aperçu lecteur + bouton — sa seule '
              'barre vit dans le dialog plein-écran (où l\'AUTO donne le '
              'multi-rangées)');
      // Mesure : le rendu block (vide) reste très en deçà de l'écran.
      final double h =
          t.getSize(find.byKey(const ValueKey<String>('notes'))).height;
      expect(h, lessThan(400),
          reason: 'critère CR : un champ inséré dans un formulaire ne doit '
              'jamais consommer la hauteur de l\'écran (mesuré : ~${h.round()} '
              'dp sur un écran de 800)');
      await _settle(t);
    });

    testWidgets(
        'G7 — mesure du danger en flux : préset markdown forcé multiRow:true '
        'sur 400 dp de large ⇒ barre plus haute que 5 rangées ; l\'AUTO la '
        'ramène à UNE rangée de 48 dp', (t) async {
      // Géométrie de la BARRE (pas une cible tactile) : mesure légitime.
      // Largeur RÉELLE de layout = surface du testeur (pas le MediaQuery) :
      // on la fixe à 400×800 (gabarit téléphone du constat device).
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(_inlineHost(
          toolbarConfig: ZRichTextToolbarConfig.markdown
              .copyWith(showUndoRedo: true, multiRow: true)));
      await t.pump();
      final double forced =
          t.getSize(find.byType(QuillSimpleToolbar)).height;
      await _settle(t);

      await t.pumpWidget(_inlineHost(
          toolbarConfig: ZRichTextToolbarConfig.markdown
              .copyWith(showUndoRedo: true)));
      await t.pump();
      final double auto = t.getSize(find.byType(QuillSimpleToolbar)).height;
      await _settle(t);

      expect(forced, greaterThan(5 * 48),
          reason: 'mesuré : la barre forcée multi-rangées empile '
              '~${(forced / 48).round()} rangées de 48 dp sur 400 dp de large '
              '(${forced.round()} dp) — elle noie un écran de téléphone');
      expect(auto, lessThanOrEqualTo(2 * 48),
          reason: 'l\'AUTO en flux tient en une rangée défilante '
              '(${auto.round()} dp)');
    });
  });
}
