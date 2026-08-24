// Habillage HORIZONTAL d'une ligne de sous-liste : poignée réglable, bordure
// résoluble par item, marges horizontales tokenisées.
//
// 🔴 CE QUE CES GARDES MESURENT — des RECTANGLES (`tester.getRect`) et des
// COULEURS lues dans la `BoxDecoration` réellement montée, jamais la présence
// d'un widget. Un jeton dont on vérifierait seulement que « le widget existe »
// serait exactement le jeton inerte que la garde d'inertie du thème
// (`test/purity/z_theme_token_inertia_guard_test.dart`) ferme par ailleurs.
//
// RELEVÉ DE RÉFÉRENCE (surface 1200 × 2400, dpr 1, une sous-liste de deux
// items) — c'est la géométrie d'AVANT ce lot, celle qu'aucun hôte passif ne
// doit voir bouger. Les 12 dp de tête sont la marge propre de `DynamicEdition`,
// externe à la sous-liste :
//
//   compact, ordre éditable   cadre de ligne x = 28 → 1172
//                             glyphe de poignée x = 52 → 76 (24 dp, ambiant)
//                             en-tête « F1 »     x = 88
//   compact, sans en-têtes    texte de ligne     x = 40
//   inline,  ordre éditable   cadre de carte     x = 28
//                             glyphe de poignée  x = 40 → 64
//
// Décomposition avant le glyphe, en compact : 12 (`DynamicEdition`) + 16 (marge
// externe de ligne) + 12 (marge interne du cadre) + 12 (centrage du glyphe de
// 24 dp dans la cible de 48 dp) = 52. Les 12 dp de centrage NE SONT PAS
// tokenisés : la cible tactile de 48 dp est le plancher d'AD-13, pas une
// décoration. Les deux autres postes le sont.
//
// 🔴 GARANTIE CENTRALE — l'inertie : aucun jeton posé, aucun seam déclaré ⇒ le
// relevé ci-dessus, À L'OCTET PRÈS, et une bordure strictement égale à
// `ZcrudTheme.fieldBorderColor`. Les valeurs sont ÉCRITES EN DUR
// volontairement : c'est ce qui rend la garde mordante. Un `??` mal replié dans
// un résolveur les fait rougir par assertion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

/// Bordure de référence : une couleur ARBITRAIRE, jamais dérivée du thème
/// ambiant. Si le socle retombait sur autre chose que `fieldBorderColor`, la
/// garde le verrait — ce qu'une couleur « plausible » du `ColorScheme`
/// masquerait.
const Color _neutralBorder = Color(0xFF123456);

/// Teinte que l'hôte associe à sa clé applicative, elle aussi arbitraire.
const Color _hostTint = Color(0xFFABCDEF);

/// Largeur minimale de colonne posée ENTRE les deux places disponibles que
/// laissent respectivement 16 dp et 8 dp de marge externe, sur la surface de
/// 1200 dp de ces gardes. Relevée sur le montage, pas devinée.
const double _stackingThreshold = 992;

ZFieldSpec _field({
  required ZSubListDisplayMode mode,
  bool? reorderable,
  bool showHeaders = true,
}) =>
    ZFieldSpec(
      name: 'a',
      type: EditionFieldType.subItems,
      label: 'Groupe A',
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: mode,
        reorderable: reorderable,
        showSummaryHeaders: showHeaders,
        summaryFields: const <String>['f1'],
      ),
    );

/// Monte UNE sous-liste de deux items par le chemin **nominal**
/// (`DynamicEdition`, aucun `fieldBuilder`).
///
/// Le chemin nominal n'est pas un détail de confort : construire
/// `ZSubListFieldWidget` à la main court-circuiterait la résolution de thème et
/// de seams que ce lot emprunte — la garde mesurerait alors un montage que
/// personne n'utilise.
Future<void> _pump(
  WidgetTester tester, {
  required ZSubListDisplayMode mode,
  bool? reorderable,
  bool showHeaders = true,
  ZcrudTheme theme = const ZcrudTheme(fieldBorderColor: _neutralBorder),
  ZSubListSeams? seams,
  ZColorKeyResolver? colorKeyResolver,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  final controller = ZFormController(
    initialValues: <String, Object?>{
      'a': <Map<String, dynamic>>[
        <String, dynamic>{'f1': 'A1'},
        <String, dynamic>{'f1': 'A2'},
      ],
    },
    visibleFields: const <String>['a'],
  );
  addTearDown(controller.dispose);
  final registry = ZSubListSeamRegistry();
  if (seams != null) registry.register('a', seams);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZcrudScope(
          theme: theme,
          acl: const ZAllowAllAcl(),
          colorKeyResolver: colorKeyResolver,
          subListSeamRegistry: seams == null ? null : registry,
          child: DynamicEdition(
            controller: controller,
            fields: <ZFieldSpec>[
              _field(
                mode: mode,
                reorderable: reorderable,
                showHeaders: showHeaders,
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Cadres de ligne réellement montés, dans l'ordre du rendu.
///
/// Le `DecoratedBox` est **le** porteur du cadre : c'est lui qui reçoit la
/// couleur de bordure, et son rectangle est la ligne moins ses marges externes.
Finder get _frames => find.byType(DecoratedBox);

Rect _frameRect(WidgetTester tester, int i) =>
    tester.getRect(_frames.at(i));

/// Couleur de la bordure du cadre d'indice [i], ou `null` s'il n'en a pas.
Color? _frameBorder(WidgetTester tester, int i) {
  final decoration =
      tester.widget<DecoratedBox>(_frames.at(i)).decoration as BoxDecoration;
  final border = decoration.border;
  if (border == null) return null;
  return border.top.color;
}

/// Glyphe de la poignée effectivement rendu (le premier des deux lignes).
Icon _handleIcon(WidgetTester tester) => tester.widget<Icon>(
      find.descendant(
        of: find.byType(ZSubListFieldWidget),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Icon &&
              (w.icon == Icons.drag_indicator_rounded ||
                  w.icon == Icons.reorder),
        ),
      ).first,
    );

Rect _handleGlyphRect(WidgetTester tester, {IconData? icon}) => tester.getRect(
      find.byIcon(icon ?? Icons.drag_indicator_rounded).first,
    );

/// Rectangle de la CIBLE TACTILE de la poignée (le `SizedBox` de 48 dp qui
/// enveloppe le glyphe) — mesuré séparément du glyphe, précisément parce que
/// les jetons ne doivent jamais y toucher (invariant AD-13).
Rect _handleTargetRect(WidgetTester tester) => tester.getRect(
      find
          .ancestor(
            of: find.byIcon(Icons.drag_indicator_rounded).first,
            matching: find.byType(SizedBox),
          )
          .first,
    );

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // A. INERTIE — aucun jeton, aucun seam ⇒ le relevé, à l'identique.
  // ──────────────────────────────────────────────────────────────────────────
  group('🔴 INERTIE : ni jeton ni seam ⇒ habillage strictement inchangé', () {
    testWidgets('compact, ordre éditable : cadre, glyphe, en-tête', (t) async {
      addTearDown(t.view.reset);
      await _pump(t, mode: ZSubListDisplayMode.compact, reorderable: true);

      final frame = _frameRect(t, 0);
      expect(frame.left, 28,
          reason: '12 (DynamicEdition) + 16 (marge externe de ligne)');
      expect(frame.right, 1172, reason: 'marge externe symétrique');

      final glyph = _handleGlyphRect(t);
      expect(glyph.left, 52, reason: '28 + 12 (marge interne) + 12 (centrage)');
      expect(glyph.width, 24, reason: 'taille d\'icône AMBIANTE, jeton absent');

      final icon = _handleIcon(t);
      expect(icon.icon, Icons.drag_indicator_rounded);
      expect(icon.size, isNull,
          reason: 'jeton absent ⇒ `size: null` passé à `Icon`, pas un '
              'littéral : c\'est ce qui rend la taille ambiante');
      expect(icon.color, isNull,
          reason: 'jeton absent ⇒ `color: null` ⇒ couleur d\'`IconTheme`');

      expect(t.getRect(find.text('F1').first).left, 88,
          reason: 'l\'en-tête reproduit la géométrie de la ligne : '
              '28 + 12 + 48 (réserve de poignée)');
    });

    testWidgets('compact, sans en-têtes ni poignée : marge interne', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: false,
        showHeaders: false,
      );
      expect(_frameRect(t, 0).left, 28);
      expect(t.getRect(find.text('A1')).left, 40,
          reason: '28 + 12 de marge interne — sans poignée, le texte ouvre '
              'la ligne');
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing,
          reason: 'ordre figé ⇒ aucune poignée : la garde suivante mesure '
              'donc bien l\'autre état de `canReorder`');
    });

    testWidgets('inline, ordre éditable : cadre et glyphe', (t) async {
      addTearDown(t.view.reset);
      await _pump(t, mode: ZSubListDisplayMode.inline, reorderable: true);
      expect(_frameRect(t, 0).left, 28);
      expect(_frameRect(t, 0).right, 1172);
      expect(_handleGlyphRect(t).left, 40,
          reason: '28 + 12 (centrage) — une carte n\'a pas de marge interne '
              'de cadre');
    });

    testWidgets('inline, ordre figé : cadre inchangé', (t) async {
      addTearDown(t.view.reset);
      await _pump(t, mode: ZSubListDisplayMode.inline, reorderable: false);
      expect(_frameRect(t, 0).left, 28);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    });

    testWidgets('bordure : `fieldBorderColor`, la MÊME sur chaque ligne',
        (t) async {
      addTearDown(t.view.reset);
      for (final mode in <ZSubListDisplayMode>[
        ZSubListDisplayMode.compact,
        ZSubListDisplayMode.inline,
      ]) {
        await _pump(t, mode: mode, reorderable: true);
        expect(_frameBorder(t, 0), _neutralBorder, reason: 'mode $mode');
        expect(_frameBorder(t, 1), _neutralBorder, reason: 'mode $mode');
      }
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // B. EFFET — chaque jeton change ce qu'il promet, de la quantité annoncée.
  // ──────────────────────────────────────────────────────────────────────────
  group('🔴 EFFET : chaque jeton de poignée fait ce que sa dartdoc promet', () {
    testWidgets('subListDragHandleIcon remplace le glyphe', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListDragHandleIcon: Icons.reorder,
        ),
      );
      expect(_handleIcon(t).icon, Icons.reorder);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing,
          reason: 'le glyffe par défaut ne coexiste pas avec le jeton');
      expect(_handleGlyphRect(t, icon: Icons.reorder).left, 52,
          reason: 'changer le glyphe ne déplace rien');
    });

    testWidgets('subListDragHandleSize : 24 → 20 rétrécit le GLYPHE, '
        'jamais la cible tactile', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListDragHandleSize: 20,
        ),
      );
      // La cible tactile D'ABORD : c'est la promesse la plus forte du jeton
      // (« je rétrécis le glyphe, pas la cible »), elle doit donc être la
      // première à rougir si le jeton déborde de son périmètre.
      final target = _handleTargetRect(t);
      expect(target.width, 48,
          reason: '🔴 AD-13 : la cible tactile est un plancher, aucun jeton '
              'ne la descend');
      expect(target.height, 48);
      final glyph = _handleGlyphRect(t);
      expect(glyph.width, 20, reason: '24 → 20');
      expect(glyph.height, 20);
      expect(glyph.left, 54,
          reason: 'le centrage grandit de 2 dp de chaque côté : 40 + 14');
    });

    testWidgets('subListDragHandleColor peint le glyphe', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListDragHandleColor: _hostTint,
        ),
      );
      expect(_handleIcon(t).color, _hostTint);
    });

    testWidgets('les trois jetons de poignée CUMULENT — la poignée legacy se '
        'déclare d\'un bloc', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListDragHandleIcon: Icons.drag_indicator_rounded,
          subListDragHandleSize: 20,
          subListDragHandleColor: _hostTint,
        ),
      );
      final icon = _handleIcon(t);
      expect(icon.icon, Icons.drag_indicator_rounded);
      expect(icon.size, 20);
      expect(icon.color, _hostTint);
      expect(_handleGlyphRect(t).width, 20);
    });
  });

  group('🔴 EFFET : les marges horizontales font ce qu\'elles promettent', () {
    testWidgets('subListRowHorizontalPadding : 16 → 8 rapproche cadre, '
        'glyphe ET en-tête de 8 dp', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListRowHorizontalPadding: 8,
        ),
      );
      final frame = _frameRect(t, 0);
      expect(frame.left, 20, reason: '28 − 8');
      expect(frame.right, 1180, reason: '1172 + 8 — la marge est symétrique');
      expect(_handleGlyphRect(t).left, 44, reason: '52 − 8');
      expect(t.getRect(find.text('F1').first).left, 80,
          reason: '88 − 8 : l\'en-tête SUIT la ligne, sinon les colonnes ne '
              'tombent plus en face');
    });

    testWidgets('subListRowHorizontalPadding porte aussi en inline', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.inline,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListRowHorizontalPadding: 8,
        ),
      );
      expect(_frameRect(t, 0).left, 20, reason: '28 − 8');
      expect(_handleGlyphRect(t).left, 32, reason: '40 − 8');
    });

    testWidgets('subListRowInnerPadding : 12 → 4 rapproche le glyphe de 8 dp '
        'SANS déplacer le cadre', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListRowInnerPadding: 4,
        ),
      );
      expect(_frameRect(t, 0).left, 28,
          reason: 'la marge INTERNE ne bouge pas le cadre — c\'est ce qui la '
              'distingue de la marge externe');
      expect(_handleGlyphRect(t).left, 44, reason: '52 − 8');
      expect(t.getRect(find.text('F1').first).left, 80, reason: '88 − 8');
    });

    testWidgets('subListRowInnerPadding est SANS OBJET en inline', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.inline,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListRowInnerPadding: 0,
        ),
      );
      expect(_frameRect(t, 0).left, 28);
      expect(_handleGlyphRect(t).left, 40,
          reason: 'une carte d\'item n\'a pas de marge interne de cadre : le '
              'jeton n\'y ment pas, il n\'y fait rien');
    });

    testWidgets('les deux marges CUMULENT — 40 dp avant le glyphe deviennent '
        '16', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListRowHorizontalPadding: 0,
          subListRowInnerPadding: 4,
        ),
      );
      // 12 (DynamicEdition) + 0 + 4 + 12 (centrage, plancher AD-13) = 28.
      expect(_handleGlyphRect(t).left, 28,
          reason: 'les 12 dp de centrage restent : ils sont le plancher '
              'tactile, pas une marge');
      expect(_frameRect(t, 0).left, 12);
    });

    testWidgets('la marge externe entre dans le SEUIL D\'EMPILEMENT — ce que '
        'la marge rend, les colonnes le reprennent', (t) async {
      addTearDown(t.view.reset);
      // Le seuil se calcule : `disponible = largeur − habillage − actions`,
      // empilé ssi `disponible < colonnes × largeurMin`. Sur cette surface,
      // l'habillage vaut 48 dp aux marges par défaut et 32 dp à 8 dp de marge :
      // une largeur minimale posée ENTRE les deux disponibles correspondantes
      // fait basculer le rendu par la seule marge. Si le seuil avait gardé la
      // constante 48, les deux rendus seraient identiques — et cette garde
      // rougirait.
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: false,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListColumnMinWidth: _stackingThreshold,
        ),
      );
      expect(find.byType(Table), findsNothing,
          reason: 'marges par défaut : la place manque, le résumé s\'empile');
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: false,
        theme: const ZcrudTheme(
          fieldBorderColor: _neutralBorder,
          subListColumnMinWidth: _stackingThreshold,
          subListRowHorizontalPadding: 8,
        ),
      );
      expect(find.byType(Table), findsOneWidget,
          reason: '🔴 les 16 dp rendus par la marge repassent aux colonnes : '
              'le rendu redevient tabulaire');
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // C. BORDURE PAR ITEM — le seam, sa chaîne et ses replis.
  // ──────────────────────────────────────────────────────────────────────────
  group('🔴 BORDURE PAR ITEM : la chaîne seam → scope → thème', () {
    testWidgets('une clé sur la PREMIÈRE ligne seulement : la seconde garde '
        'la bordure du thème', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        seams: ZSubListSeams(
          itemBorderColorKey: (item) => item.index == 0 ? 'primary' : null,
        ),
      );
      final scheme =
          Theme.of(t.element(find.byType(ZSubListFieldWidget))).colorScheme;
      expect(_frameBorder(t, 0), scheme.primaryContainer,
          reason: 'clé du vocabulaire Material 3 ⇒ rôle dérivé du schéma');
      expect(_frameBorder(t, 1), _neutralBorder,
          reason: '🔴 une clé nulle N\'EST PAS une couleur nulle : la ligne '
              'retombe sur `fieldBorderColor`');
    });

    testWidgets('le resolver de l\'hôte PRIME sur le vocabulaire du cœur',
        (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        colorKeyResolver: (scheme, key) => key == 'modelePrincipal'
            ? const ZColorPair(color: _hostTint, onColor: Colors.black)
            : null,
        seams: ZSubListSeams(
          itemBorderColorKey: (item) =>
              item.index == 0 ? 'modelePrincipal' : null,
        ),
      );
      expect(_frameBorder(t, 0), _hostTint,
          reason: 'clé applicative inconnue de Material 3 : seul le resolver '
              'hôte sait la teindre');
      expect(_frameBorder(t, 1), _neutralBorder);
    });

    testWidgets('clé inconnue de TOUTE la chaîne ⇒ bordure du thème',
        (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        seams: ZSubListSeams(
          itemBorderColorKey: (item) => 'cleQueRienNeConnait',
        ),
      );
      expect(_frameBorder(t, 0), _neutralBorder);
      expect(_frameBorder(t, 1), _neutralBorder);
    });

    testWidgets('un seam qui LÈVE est un seam absent (AD-10)', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        seams: ZSubListSeams(
          itemBorderColorKey: (item) => throw StateError('boum'),
        ),
      );
      expect(_frameBorder(t, 0), _neutralBorder,
          reason: 'le rendu reste celui d\'avant, aucune exception ne remonte');
      expect(_frameBorder(t, 1), _neutralBorder);
    });

    testWidgets('la vue reçue porte les DONNÉES de l\'item, pas seulement son '
        'indice', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        colorKeyResolver: (scheme, key) => key == 'vu'
            ? const ZColorPair(color: _hostTint, onColor: Colors.black)
            : null,
        seams: ZSubListSeams(
          itemBorderColorKey: (item) => item.data['f1'] == 'A2' ? 'vu' : null,
        ),
      );
      expect(_frameBorder(t, 0), _neutralBorder);
      expect(_frameBorder(t, 1), _hostTint,
          reason: 'c\'est la DONNÉE qui décide — le canal serait sans intérêt '
              's\'il ne voyait que la position');
    });

    testWidgets('le seam porte aussi en INLINE', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.inline,
        reorderable: true,
        colorKeyResolver: (scheme, key) => key == 'vu'
            ? const ZColorPair(color: _hostTint, onColor: Colors.black)
            : null,
        seams: ZSubListSeams(
          itemBorderColorKey: (item) => item.index == 0 ? 'vu' : null,
        ),
      );
      expect(_frameBorder(t, 0), _hostTint);
      expect(_frameBorder(t, 1), _neutralBorder);
    });

    testWidgets('le seam n\'ajoute AUCUNE bordure là où le thème n\'en pose '
        'pas', (t) async {
      addTearDown(t.view.reset);
      await _pump(
        t,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
        theme: const ZcrudTheme(),
        seams: ZSubListSeams(
          itemBorderColorKey: (item) => item.index == 0 ? 'primary' : null,
        ),
      );
      expect(_frameBorder(t, 1), isNull,
          reason: '🔴 `fieldBorderColor` nul ⇒ pas de cadre du tout : le repli '
              'reproduit l\'ABSENCE, il n\'invente pas une couleur');
    });
  });
}
