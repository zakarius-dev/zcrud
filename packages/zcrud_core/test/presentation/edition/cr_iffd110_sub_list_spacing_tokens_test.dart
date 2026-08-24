// Espacement vertical **INTERNE** d'un bloc de sous-liste, réglable par jetons.
//
// 🔴 CE QUE CES GARDES MESURENT — des RECTANGLES (`tester.getRect`), jamais la
// présence d'un widget. Un jeton d'espacement dont on vérifierait seulement que
// « le widget existe » serait exactement le jeton inerte que la garde d'inertie
// du thème ferme par ailleurs. Ici chaque assertion porte une **quantité en
// dp**, et la quantité est celle du relevé.
//
// RELEVÉ DE RÉFÉRENCE (surface 1200 × 2400, dpr 1, deux sous-listes
// consécutives de deux items) — c'est la géométrie d'AVANT les jetons, celle
// qu'aucun hôte passif ne doit voir bouger :
//
//   compact tabulaire     bloc = y 12 → 156   (h 144)
//   compact lignes libres bloc = y 12 → 180   (h 168)
//   tags                  bloc = y 12 → 128   (h 116)
//   inline                bloc = y 12 → 224   (h 212)
//
// Décomposition interne (bas de la dernière ligne → haut du libellé suivant) :
//   tabulaire     8 (cellule) + 4 (marge de table) + [12 fieldGap] + 8 (caption)
//   lignes libres 14 (jeu de la poignée, AD-13) + 4 (ligne) + [12] + 8 (caption)
//   inline        4 (carte) + 4 + 48 (bouton) + 8 (fin de bloc) + [12] + 8
//
// Les 48 dp des cibles tactiles (poignée de glissement, bouton d'ajout) ne sont
// PAS tokenisés : ce sont des planchers d'accessibilité (AD-13), pas des
// réglages. Les tokeniser reviendrait à offrir de casser l'invariant.
//
// 🔴 GARANTIE CENTRALE — l'inertie : aucun jeton posé ⇒ géométrie identique au
// relevé, À L'OCTET PRÈS. Les valeurs ci-dessous sont ÉCRITES EN DUR
// volontairement : c'est ce qui rend la garde mordante. Un `??` mal replié dans
// un résolveur les fait rougir par assertion.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

const _itemFields = <ZFieldSpec>[
  ZFieldSpec(name: 'f1', type: EditionFieldType.text, label: 'F1'),
];

ZFieldSpec _field(
  String name,
  String label, {
  ZSubListDisplayMode mode = ZSubListDisplayMode.compact,
  bool? reorderable,
}) =>
    ZFieldSpec(
      name: name,
      type: EditionFieldType.subItems,
      label: label,
      config: ZSubListConfig(
        itemFields: _itemFields,
        displayMode: mode,
        reorderable: reorderable,
        summaryFields: const <String>['f1'],
      ),
    );

const Map<String, Object?> _values = <String, Object?>{
  'a': <Map<String, dynamic>>[
    <String, dynamic>{'f1': 'A1'},
    <String, dynamic>{'f1': 'A2'},
  ],
  'b': <Map<String, dynamic>>[
    <String, dynamic>{'f1': 'B1'},
    <String, dynamic>{'f1': 'B2'},
  ],
};

/// Monte DEUX sous-listes consécutives par le chemin **nominal**
/// (`DynamicEdition`, aucun `fieldBuilder`) et rend les rectangles des blocs.
///
/// Le chemin nominal n'est pas un détail de confort : construire
/// `ZSubListFieldWidget` à la main court-circuiterait la résolution de thème
/// que ces jetons empruntent — la garde mesurerait alors un montage que
/// personne n'utilise.
Future<List<Rect>> _blocks(
  WidgetTester tester, {
  required ZSubListDisplayMode mode,
  bool? reorderable,
  ZcrudTheme theme = const ZcrudTheme(),
  int generation = 0,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  final fields = <ZFieldSpec>[
    _field('a', 'Groupe A', mode: mode, reorderable: reorderable),
    _field('b', 'Groupe B', mode: mode, reorderable: reorderable),
  ];
  final controller = ZFormController(
    initialValues: Map<String, Object?>.from(_values),
    visibleFields: const <String>['a', 'b'],
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    // `generation` force un remontage complet entre deux mesures d'un même
    // test : sans clé distincte, Flutter réutiliserait les éléments et une
    // mesure « après » pourrait hériter d'un état de « avant ».
    KeyedSubtree(
      key: ValueKey<int>(generation),
      child: MaterialApp(
        home: Scaffold(
          body: ZcrudScope(
            theme: theme,
            child: DynamicEdition(controller: controller, fields: fields),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final finder = find.byType(ZSubListFieldWidget);
  expect(
    tester.widgetList(finder).length,
    2,
    reason: 'les deux sous-listes doivent être montées — sinon la mesure '
        'suivante porterait sur autre chose que ce que la garde croit',
  );
  return <Rect>[tester.getRect(finder.at(0)), tester.getRect(finder.at(1))];
}

/// Hauteur du bloc de sous-liste sous [theme].
Future<double> _height(
  WidgetTester tester, {
  required ZSubListDisplayMode mode,
  bool? reorderable,
  ZcrudTheme theme = const ZcrudTheme(),
  int generation = 0,
}) async {
  final rects = await _blocks(
    tester,
    mode: mode,
    reorderable: reorderable,
    theme: theme,
    generation: generation,
  );
  return rects[0].height;
}

/// Écart, en dp, que [theme] retire (valeur positive) à la hauteur du bloc.
///
/// Mesuré dans le MÊME test que sa référence : une garde d'effet qui
/// comparerait à une constante figée mesurerait la constante, pas l'effet.
Future<double> _saving(
  WidgetTester tester, {
  required ZSubListDisplayMode mode,
  bool? reorderable,
  required ZcrudTheme theme,
}) async {
  final before = await _height(
    tester,
    mode: mode,
    reorderable: reorderable,
    generation: 0,
  );
  final after = await _height(
    tester,
    mode: mode,
    reorderable: reorderable,
    theme: theme,
    generation: 1,
  );
  return before - after;
}

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // A. INERTIE — aucun jeton posé ⇒ la géométrie du relevé, à l'identique.
  // ──────────────────────────────────────────────────────────────────────────
  group('🔴 INERTIE : aucun jeton posé ⇒ géométrie strictement inchangée', () {
    testWidgets('compact TABULAIRE (ordre figé)', (tester) async {
      addTearDown(tester.view.reset);
      final r = await _blocks(
        tester,
        mode: ZSubListDisplayMode.compact,
        reorderable: false,
      );
      expect(r[0].top, 12, reason: 'haut du bloc — déplacé ⇒ jeton actif');
      expect(r[0].bottom, 156, reason: 'bas du bloc — déplacé ⇒ jeton actif');
      expect(r[0].height, 144);
      expect(r[1].top, 168, reason: '12 dp de `fieldGap`, externe au widget');
      // Postes internes, un par un : caption, marge de table, cellules.
      expect(tester.getRect(find.text('Groupe A')).top, 20,
          reason: 'réserve de 8 dp au-dessus du libellé');
      final table = tester.getRect(find.byType(Table).first);
      expect(table.top, 48, reason: 'marge haute de table de 4 dp');
      expect(table.bottom, 152, reason: 'marge basse de table de 4 dp');
      expect(table.height, 104,
          reason: '3 rangées : en-tête 32 + 2 × 36 (texte + 2 × 8 de cellule)');
      expect(tester.getRect(find.text('A2')).bottom, 144,
          reason: 'bas du texte de la dernière ligne');
    });

    testWidgets('compact LIGNES LIBRES (ordre éditable)', (tester) async {
      addTearDown(tester.view.reset);
      final r = await _blocks(
        tester,
        mode: ZSubListDisplayMode.compact,
        reorderable: true,
      );
      expect(r[0].top, 12);
      expect(r[0].bottom, 180);
      expect(r[0].height, 168);
      expect(r[1].top, 192);
      expect(tester.getRect(find.text('Groupe A')).top, 20);
      // `.first` : les DEUX blocs coiffent leur colonne du même libellé `F1`
      // — le premier est celui du bloc mesuré.
      expect(tester.getRect(find.text('F1').first).top, 52,
          reason: 'réserve de 8 dp au-dessus de la ligne d\'en-têtes');
      expect(tester.getRect(find.text('A1')).top, 86);
      expect(tester.getRect(find.text('A2')).top, 142,
          reason: 'écart inter-lignes de 36 dp : 14 + 4 + 4 + 14');
      // La poignée reste une cible ≥ 48 dp (AD-13) : c'est ce plancher, et non
      // un padding, qui domine l'écart inter-lignes de ce rendu.
      expect(tester.getSize(find.byIcon(Icons.drag_handle).first).height, 24);
    });

    testWidgets('inline', (tester) async {
      addTearDown(tester.view.reset);
      final r = await _blocks(tester, mode: ZSubListDisplayMode.inline);
      expect(r[0].top, 12);
      expect(r[0].bottom, 224);
      expect(r[0].height, 212);
      expect(r[1].top, 236);
      expect(tester.getRect(find.text('Groupe A')).top, 20);
    });

    testWidgets('tags', (tester) async {
      addTearDown(tester.view.reset);
      final r = await _blocks(tester, mode: ZSubListDisplayMode.tags);
      expect(r[0].top, 12);
      expect(r[0].bottom, 128);
      expect(r[0].height, 116);
      expect(r[1].top, 140);
      expect(tester.getRect(find.text('Groupe A')).top, 32);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // B. EFFET — chaque jeton déplace la géométrie de la QUANTITÉ attendue.
  // ──────────────────────────────────────────────────────────────────────────
  group('🔴 EFFET : chaque jeton retire exactement ce qu\'il promet', () {
    testWidgets('subListCaptionTopPadding : 8 → 0 retire 8 dp', (tester) async {
      addTearDown(tester.view.reset);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: false,
          theme: const ZcrudTheme(subListCaptionTopPadding: 0),
        ),
        8,
      );
    });

    testWidgets('subListCaptionTopPadding : 8 → 20 AJOUTE 12 dp, et le libellé '
        'descend d\'autant', (tester) async {
      addTearDown(tester.view.reset);
      // Sens montant : un jeton qui ne saurait que retirer serait à moitié
      // câblé. La position du libellé est mesurée en plus de la hauteur —
      // c'est la réserve AU-DESSUS de lui que le jeton nomme.
      final before = await _height(
        tester,
        mode: ZSubListDisplayMode.compact,
        reorderable: false,
      );
      final after = await _height(
        tester,
        mode: ZSubListDisplayMode.compact,
        reorderable: false,
        theme: const ZcrudTheme(subListCaptionTopPadding: 20),
        generation: 1,
      );
      expect(after - before, 12);
      expect(tester.getRect(find.text('Groupe A')).top, 32,
          reason: '12 (haut du bloc) + 20 de réserve');
    });

    testWidgets('subListHeaderTopPadding : 8 → 0 retire 8 dp (compact non '
        'tabulaire)', (tester) async {
      addTearDown(tester.view.reset);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: true,
          theme: const ZcrudTheme(subListHeaderTopPadding: 0),
        ),
        8,
      );
    });

    testWidgets('subListRowVerticalPadding : 4 → 0 retire 2 × 4 par ligne',
        (tester) async {
      addTearDown(tester.view.reset);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: true,
          theme: const ZcrudTheme(subListRowVerticalPadding: 0),
        ),
        16,
        reason: 'deux lignes × (4 haut + 4 bas)',
      );
    });

    testWidgets('subListCellVerticalPadding : 8 → 0 retire 2 × 8 par rangée '
        'de table', (tester) async {
      addTearDown(tester.view.reset);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: false,
          theme: const ZcrudTheme(subListCellVerticalPadding: 0),
        ),
        48,
        reason: 'trois rangées (en-tête + 2 lignes) × (8 haut + 8 bas)',
      );
    });

    testWidgets('subListTableVerticalMargin : 4 → 0 retire 8 dp',
        (tester) async {
      addTearDown(tester.view.reset);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: false,
          theme: const ZcrudTheme(subListTableVerticalMargin: 0),
        ),
        8,
        reason: 'marge haute 4 + marge basse 4 — la basse EST la réserve de '
            'fin de bloc du rendu tabulaire',
      );
    });

    testWidgets('subListBlockEndPadding : 8 → 0 retire 8 dp (inline)',
        (tester) async {
      addTearDown(tester.view.reset);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.inline,
          theme: const ZcrudTheme(subListBlockEndPadding: 0),
        ),
        8,
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // C. COUVERTURE — le jeton porte dans les deux modes ET les deux états.
  //
  // Un jeton câblé sur UN seul site passerait toutes les gardes d'effet
  // ci-dessus si elles ne visaient qu'un rendu. C'est le défaut que ce groupe
  // ferme : la même déclaration, mesurée sur chaque rendu qui la revendique.
  // ──────────────────────────────────────────────────────────────────────────
  group('🔴 COUVERTURE : le jeton porte partout où sa dartdoc le promet', () {
    testWidgets('subListRowVerticalPadding porte en compact lignes libres ET '
        'en inline', (tester) async {
      addTearDown(tester.view.reset);
      const theme = ZcrudTheme(subListRowVerticalPadding: 0);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: true,
          theme: theme,
        ),
        16,
        reason: 'compact, ordre éditable : deux `_CompactRow`',
      );
      expect(
        await _saving(tester, mode: ZSubListDisplayMode.inline, theme: theme),
        16,
        reason: 'inline : deux `_SubItemCard` — même jeton, autre widget',
      );
    });

    testWidgets('subListCaptionTopPadding porte dans les QUATRE rendus',
        (tester) async {
      addTearDown(tester.view.reset);
      const theme = ZcrudTheme(subListCaptionTopPadding: 0);
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: false,
          theme: theme,
        ),
        8,
        reason: 'compact tabulaire',
      );
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: true,
          theme: theme,
        ),
        8,
        reason: 'compact lignes libres',
      );
      expect(
        await _saving(tester, mode: ZSubListDisplayMode.inline, theme: theme),
        8,
        reason: 'inline',
      );
      expect(
        await _saving(tester, mode: ZSubListDisplayMode.tags, theme: theme),
        8,
        reason: 'tags',
      );
    });

    testWidgets('subListBlockEndPadding porte en inline ET en tags',
        (tester) async {
      addTearDown(tester.view.reset);
      const theme = ZcrudTheme(subListBlockEndPadding: 0);
      expect(
        await _saving(tester, mode: ZSubListDisplayMode.inline, theme: theme),
        8,
      );
      expect(
        await _saving(tester, mode: ZSubListDisplayMode.tags, theme: theme),
        8,
      );
    });

    testWidgets('les jetons se CUMULENT — le rendu compact que réclame la '
        'CR se déclare d\'un bloc', (tester) async {
      addTearDown(tester.view.reset);
      // La recette servie à l'hôte dans le handoff. Elle doit valoir la somme
      // de ses postes, pas « un peu moins » : deux jetons câblés sur le même
      // `Padding` se masqueraient l'un l'autre sans qu'aucune garde d'effet
      // isolée ne le voie.
      const compactRecipe = ZcrudTheme(
        subListCaptionTopPadding: 0,
        subListHeaderTopPadding: 0,
        subListRowVerticalPadding: 0,
        subListCellVerticalPadding: 2,
        subListTableVerticalMargin: 0,
        subListBlockEndPadding: 0,
      );
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: false,
          theme: compactRecipe,
        ),
        8 + 8 + 36,
        reason: 'caption 8 + marge de table 8 + cellules 3 × (2 × 6) = 52 ; '
            'le padding de LIGNE et la réserve de fin n\'ont pas de site en '
            'tabulaire — un jeton sans site dans un rendu y est inerte, et '
            'c\'est ce que sa dartdoc annonce',
      );
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.compact,
          reorderable: true,
          theme: compactRecipe,
        ),
        8 + 8 + 16,
        reason: 'caption 8 + en-tête 8 + deux lignes × 8',
      );
      expect(
        await _saving(
          tester,
          mode: ZSubListDisplayMode.inline,
          theme: compactRecipe,
        ),
        8 + 16 + 8,
        reason: 'caption 8 + deux cartes × 8 + fin de bloc 8',
      );
    });
  });
}
