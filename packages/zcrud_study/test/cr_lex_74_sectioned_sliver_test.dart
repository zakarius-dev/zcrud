/// CR-LEX-74 (🔴 MAJEUR — bloquant d'adoption) — `ZSectionedStudyLayout` est un
/// `ListView.builder` : widget **boîte** à défilement propre, donc inadoptable
/// dans le `CustomScrollView` de slivers de la page-détail de dossier de lex
/// (`SliverAppBar` rétractable + onglets + CTA + chips + bannière, PUIS les
/// sections). L'y insérer imposerait un **défilement imbriqué** et **tuerait
/// l'app-bar rétractable** — précisément le chrome à aligner.
///
/// Réponse : [ZSectionedStudySliver], variante SLIVER du MÊME contenu.
///
/// Ces gardes ne vérifient PAS « une classe existe » (tautologie : le
/// compilateur le dit déjà). Elles observent le RENDU RÉEL, monté :
///
/// | Garde | Ce qui ROUGIT si la correction est défaite |
/// |---|---|
/// | G1 assemblage réel dans un `CustomScrollView` | enveloppe boîte ⇒ « RenderViewport expected a child of type RenderSliver » |
/// | G2 app-bar RESTE rétractable | défilement imbriqué ⇒ l'app-bar ne se replie plus |
/// | G3 anti-divergence boîte ↔ sliver | contenu/ordre/clés divergents entre les deux chemins |
/// | G4 virtualisation | `SliverList(children:)` matérialisant toutes les sections |
/// | G5 non-régression de la variante boîte | `ZSectionedStudyLayout` altéré par le refactor |
///
/// Chacune a été prouvée MORDANTE par ré-injection de la régression exacte
/// (verdicts consignés en tête de chaque test).
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

// --- Fixtures ----------------------------------------------------------------

/// Sections neutres : chaque item porte une clé `item:<id>` et enregistre sa
/// construction dans [built] (⇒ compteur de sections RÉELLEMENT construites).
List<ZStudyToolsSectionSpec> _sections(
  int n, {
  String prefix = 'S',
  List<String>? built,
}) {
  return <ZStudyToolsSectionSpec>[
    for (var i = 0; i < n; i++)
      ZStudyToolsSectionSpec(
        id: '$prefix$i',
        title: 'TITLE_$prefix$i',
        itemCount: 1,
        itemBuilder: (_, _) {
          built?.add('$prefix$i');
          return SizedBox(
            height: 40,
            child: Text('ITEM_$prefix$i',
                key: ValueKey<String>('item:$prefix$i')),
          );
        },
        emptyState: const SizedBox.shrink(),
      ),
  ];
}

/// Rail flashcards (axe HORIZONTAL) — la capacité que la CR exige de retrouver
/// à l'identique dans la variante sliver.
ZStudyToolsSectionSpec _rail() => ZStudyToolsSectionSpec(
      id: 'RAIL',
      title: 'TITLE_RAIL',
      itemCount: 3,
      axis: Axis.horizontal,
      itemBuilder: (_, i) => SizedBox(
        width: 60,
        height: 40,
        child: Text('RAIL_$i', key: ValueKey<String>('item:RAIL$i')),
      ),
      emptyState: const SizedBox.shrink(),
    );

/// Monte la variante SLIVER dans un VRAI `CustomScrollView`.
///
/// [appBar] `true` ⇒ `SliverAppBar` rétractable au-dessus (cas lex).
Future<void> _pumpSliver(
  WidgetTester tester, {
  required List<ZStudyToolsSectionSpec> sections,
  Widget? header,
  Widget? footer,
  bool appBar = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: <Widget>[
            if (appBar)
              const SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                flexibleSpace: FlexibleSpaceBar(title: Text('APPBAR')),
              ),
            ZSectionedStudySliver(
              sections: sections,
              header: header,
              footer: footer,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Monte la variante BOÎTE (rendu historique, inchangé).
Future<void> _pumpBox(
  WidgetTester tester, {
  required List<ZStudyToolsSectionSpec> sections,
  Widget? header,
  Widget? footer,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ZSectionedStudyLayout(
          sections: sections,
          header: header,
          footer: footer,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Signature de CONTENU + ORDRE : tous les `Text` rendus, dans l'ordre de
/// l'arbre (donc l'ordre de construction / l'ordre visuel vertical).
List<String> _textSignature(WidgetTester t) => t
    .widgetList<Text>(find.byType(Text))
    .map((w) => w.data ?? '<span>')
    .toList(growable: false);

/// Signature de CLÉS : toutes les clés `section:<id>`, dans l'ordre de l'arbre.
List<String> _sectionKeys(WidgetTester t) => t
    .widgetList<Widget>(find.byWidgetPredicate((w) {
      final k = w.key;
      return k is ValueKey<String> && k.value.startsWith('section:');
    }))
    .map((w) => (w.key! as ValueKey<String>).value)
    .toList(growable: false);

/// Étendue peinte du sliver d'app-bar (hauteur RÉELLEMENT occupée à l'écran).
double _appBarExtent(WidgetTester t) {
  final ro = t.renderObject(find.byType(SliverAppBar));
  return (ro as RenderSliver).geometry!.paintExtent;
}

void main() {
  // ---------------------------------------------------------------- G1 ------
  testWidgets(
      'G1 — la variante sliver s\'ASSEMBLE RÉELLEMENT dans un CustomScrollView '
      'aux côtés d\'un SliverAppBar (montage, pas assertion de type)',
      (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 🔴 GARDE MORDANTE — régression ré-injectée : `ZSectionedStudySliver.build`
    // renvoie l'enveloppe BOÎTE (`ListView.builder`, l'état d'avant CR-74).
    // Verdict observé : ROUGE — vrai échec d'assertion (`Expected: null` sur
    // `takeException`), déclenché par l'exception de layout « A RenderViewport
    // expected a child of type RenderSliver but received a child of type
    // RenderClipRect » (puis cascade de RenderErrorBox).
    // Régression retirée ⇒ VERT.
    await _pumpSliver(tester, sections: _sections(4), appBar: true);

    expect(tester.takeException(), isNull);
    expect(find.text('TITLE_S0'), findsOneWidget);
    expect(find.text('APPBAR'), findsWidgets);

    // AUCUN défilement imbriqué : le `CustomScrollView` de l'hôte est le SEUL
    // Scrollable de l'arbre (les sections n'en apportent pas).
    expect(find.byType(Scrollable), findsOneWidget);
  });

  // ---------------------------------------------------------------- G2 ------
  testWidgets(
      'G2 — l\'app-bar rétractable RESTE rétractable : défiler au-dessus des '
      'sections replie le SliverAppBar', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpSliver(tester, sections: _sections(30), appBar: true);

    final expanded = _appBarExtent(tester);
    expect(expanded, moreOrLessEquals(200, epsilon: 1.0));

    // Geste appliqué SUR LES SECTIONS (pas sur l'app-bar) : c'est exactement le
    // cas que le défilement imbriqué casserait — le geste serait absorbé par le
    // `ListView` interne et n'atteindrait jamais le viewport de l'hôte.
    await tester.drag(find.text('TITLE_S1'), const Offset(0, -300));
    await tester.pumpAndSettle();

    final collapsed = _appBarExtent(tester);

    // 🔴 GARDE MORDANTE — régression ré-injectée : sections repassées en
    // enveloppe BOÎTE bornée et emballée (`SliverToBoxAdapter(child: SizedBox(
    // height: 400, child: ZSectionedStudyLayout(…)))`) — le contournement
    // « défilement imbriqué » que lex refuse.
    // Verdict observé : ROUGE — vrai échec d'assertion : « Expected: a value
    // less than <100.0> Actual: <200.0> » (l'app-bar reste PLEINEMENT déployée,
    // le geste ayant été consommé par le ListView imbriqué).
    // Régression retirée ⇒ VERT (paintExtent replié = 56.0 = kToolbarHeight).
    expect(collapsed, lessThan(100.0));
    expect(collapsed, lessThan(expanded));
    // `pinned: true` ⇒ l'app-bar reste visible, repliée à la barre d'outils.
    expect(collapsed, greaterThan(0.0));
  });

  // ---------------------------------------------------------------- G3 ------
  testWidgets(
      'G3 — ANTI-DIVERGENCE : contenu, ordre, clés et rail flashcards '
      'IDENTIQUES entre la variante boîte et la variante sliver',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    List<ZStudyToolsSectionSpec> specs() => <ZStudyToolsSectionSpec>[
          ..._sections(2),
          _rail(),
          ..._sections(2, prefix: 'T'),
        ];
    Widget header() => const SizedBox(
        height: 40, child: Text('HEADER', key: ValueKey<String>('hdr')));
    Widget footer() => const SizedBox(
        height: 40, child: Text('FOOTER', key: ValueKey<String>('ftr')));

    await _pumpBox(
        tester, sections: specs(), header: header(), footer: footer());
    final boxTexts = _textSignature(tester);
    final boxKeys = _sectionKeys(tester);

    await _pumpSliver(
        tester, sections: specs(), header: header(), footer: footer());
    final sliverTexts = _textSignature(tester);
    final sliverKeys = _sectionKeys(tester);

    // 🔴 GARDE MORDANTE — régression ré-injectée : divergence des deux chemins,
    // `ZSectionedStudySliver.build` construisant sa source avec
    // `sections: sections.reversed.toList()` (l'exact défaut IFFD du mapping
    // recopié qui dérive).
    // Verdict observé : ROUGE — vrai échec d'assertion : « Expected: [
    // 'HEADER', 'TITLE_S0', …] Actual: ['HEADER', 'TITLE_T1', …] Which: at
    // location [1] is 'TITLE_T1' instead of 'TITLE_S0' ».
    // Régression retirée ⇒ VERT.
    expect(sliverTexts, equals(boxTexts));
    expect(sliverKeys, equals(boxKeys));

    // Le contenu attendu est bien LÀ (la garde ne compare pas deux vides).
    expect(boxTexts, contains('TITLE_S0'));
    expect(boxTexts, contains('RAIL_2')); // rail flashcards rendu
    expect(boxKeys, equals(const <String>[
      'section:S0',
      'section:S1',
      'section:RAIL',
      'section:T0',
      'section:T1',
    ]));
    // En-tête AVANT tout, pied APRÈS tout — dans les DEUX enveloppes.
    expect(boxTexts.first, 'HEADER');
    expect(boxTexts.last, 'FOOTER');
    expect(sliverTexts.first, 'HEADER');
    expect(sliverTexts.last, 'FOOTER');
  });

  // ---------------------------------------------------------------- G4 ------
  testWidgets(
      'G4 — VIRTUALISATION préservée : la variante sliver ne construit que le '
      'voisinage du viewport, jamais les 60 sections', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final built = <String>[];
    await _pumpSliver(tester, sections: _sections(60, built: built));

    // 🔴 GARDE MORDANTE (a) — régression ré-injectée : `SliverToBoxAdapter(
    // child: Column(children: [for (…) source.buildItem(context, i) ?? …]))` —
    // l'implémentation naïve « j'emballe une Column dans un adaptateur »,
    // qui construit TOUTES les sections d'un coup.
    // Verdict observé : ROUGE — vrai échec d'assertion : « Expected: a value
    // less than <30> Actual: <60> Which: is not a value less than <30> ».
    // Régression retirée ⇒ VERT (6 sections construites sur 60).
    expect(built.toSet().length, lessThan(30));
    expect(built, isNotEmpty);
    expect(find.text('TITLE_S59'), findsNothing);

    // 🔴 GARDE MORDANTE (b) — la mesure (a) ne suffit PAS : un
    // `SliverList(delegate: SliverChildListDelegate([…]))` INSTANCIE les 60
    // sous-arbres de section (coût de construction de widgets + perte du
    // `addAutomaticKeepAlives`/recyclage par builder) alors que l'élément
    // multi-box, lui, reste paresseux — (a) resterait donc VERTE (vérifié :
    // injection jouée, « All tests passed »), ce qui est un DÉFAUT DE GARDE.
    // Cette seconde assertion cible ce défaut précis.
    // Régression ré-injectée : le même `SliverChildListDelegate`.
    // Verdict observé : ROUGE — vrai échec d'assertion : « Expected: <Instance
    // of 'SliverChildBuilderDelegate'> Actual: SliverChildListDelegate:#…(estimated
    // child count: 60) ».
    // Régression retirée ⇒ VERT.
    final sliverList = tester.widget<SliverList>(find.byType(SliverList));
    expect(sliverList.delegate, isA<SliverChildBuilderDelegate>());
    expect(sliverList.delegate.estimatedChildCount, 60);
  });

  // ---------------------------------------------------------------- G5 ------
  testWidgets(
      'G5 — NON-RÉGRESSION : la variante boîte reste un ListView unique, '
      'virtualisé, au contenu inchangé', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final built = <String>[];
    await _pumpBox(
      tester,
      sections: _sections(60, built: built),
      header: const SizedBox(
          height: 40, child: Text('HEADER', key: ValueKey<String>('hdr'))),
    );

    // 🔴 GARDE MORDANTE — régression ré-injectée : `ZSectionedStudyLayout.build`
    // renvoyant l'enveloppe SLIVER (`SliverList.builder`) au lieu du
    // `ListView.builder` historique — la faute exacte qu'un drapeau
    // `sliver: true` rendrait possible SANS erreur de compilation.
    // Verdict observé : ROUGE — vrai échec d'assertion (`Expected: null` sur
    // `takeException`), déclenché par l'exception de layout « A
    // RenderCustomMultiChildLayoutBox expected a child of type RenderBox but
    // received a child of type RenderSliverList ».
    // Régression retirée ⇒ VERT.
    expect(tester.takeException(), isNull);
    expect(find.byType(ListView), findsOneWidget);
    // itemCount = 1 en-tête + 60 sections (décompte structurel inchangé, CR-53).
    expect(tester.widget<ListView>(find.byType(ListView)).semanticChildCount,
        61);
    expect(built.toSet().length, lessThan(30));
    expect(find.text('HEADER'), findsOneWidget);
    expect(find.text('TITLE_S0'), findsOneWidget);
  });
}
