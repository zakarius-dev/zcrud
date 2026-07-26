/// CR-53 (lex, MAJEUR d'adoption) — `ZSectionedStudyLayout` n'avait **aucun
/// slot d'en-tête** : tout contenu rendu au-dessus des sections était
/// inexprimable, ce qui bloquait l'adoption de `ZStudyFolderDetail` (la
/// page-détail lex rend quatre blocs au-dessus des sections : CTA « Réviser »,
/// chips de sous-dossiers, bandeau de génération, filtre par tags).
///
/// Ces gardes ne vérifient PAS « un paramètre existe » (tautologie : le
/// compilateur le dit déjà). Elles observent le RENDU RÉEL :
///
/// | Garde | Ce qui ROUGIT si la correction est défaite |
/// |---|---|
/// | G1 en-tête au-dessus, MÊME scroll | en-tête sorti du `ListView` (bandeau figé) |
/// | G1b mappage d'index | oubli du décalage `- leading` (off-by-one) |
/// | G2 absence STRUCTURELLE | slot réservé + `SizedBox.shrink` fantôme |
/// | G3 virtualisation | `SingleChildScrollView` + `Column` |
/// | G4 granularité AD-2 (en-tête) | en-tête keyé/emballé d'après `sections` |
/// | G5 granularité AD-2 (sections) | `ListView` keyé d'après l'en-tête |
/// | G6 pied | pied non câblé / rendu au-dessus |
/// | G7 voie `ZStudyFolderDetail` | slots non câblés jusqu'au layout |
///
/// Chacune a été prouvée MORDANTE par ré-injection de la régression exacte
/// (verdicts consignés en tête de chaque test).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

// --- Sondes ------------------------------------------------------------------

/// Compteurs mutables partagés avec les sondes (montages / builds).
class _Counter {
  int builds = 0;
  int mounts = 0;
}

/// Sonde d'en-tête : compte ses `build` ET ses montages d'état. Permet de
/// distinguer « pas reconstruit » de « remonté à neuf » (perte d'état).
class _HeaderProbe extends StatefulWidget {
  const _HeaderProbe({required this.counter, required this.label});

  final _Counter counter;
  final String label;

  @override
  State<_HeaderProbe> createState() => _HeaderProbeState();
}

class _HeaderProbeState extends State<_HeaderProbe> {
  @override
  void initState() {
    super.initState();
    widget.counter.mounts++;
  }

  @override
  Widget build(BuildContext context) {
    widget.counter.builds++;
    return SizedBox(
      height: 60,
      child: Text(widget.label, key: ValueKey<String>('probe:${widget.label}')),
    );
  }
}

// --- Fixtures ----------------------------------------------------------------

/// Sections neutres : chaque item porte une clé `item:<id>` et incrémente
/// [built] à sa construction (⇒ compteur de sections RÉELLEMENT montées).
List<ZStudyToolsSectionSpec> _sections(
  int n, {
  String prefix = 'S',
  List<String>? built,
  bool collapsible = false,
}) {
  return <ZStudyToolsSectionSpec>[
    for (var i = 0; i < n; i++)
      ZStudyToolsSectionSpec(
        id: '$prefix$i',
        title: 'TITLE_$prefix$i',
        itemCount: 1,
        collapsible: collapsible,
        collapseSemanticLabel: 'COLLAPSE',
        expandSemanticLabel: 'EXPAND',
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

Future<void> _pumpLayout(
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

/// `ListView` unique du layout (sonde de décompte d'items).
ListView _listView(WidgetTester t) => t.widget<ListView>(find.byType(ListView));

void main() {
  // ---------------------------------------------------------------- G1 ------
  testWidgets(
      'G1 — en-tête fourni : rendu AU-DESSUS des sections et DANS le même '
      'défilement (il défile avec elles)', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpLayout(
      tester,
      sections: _sections(30),
      header: const SizedBox(
        height: 80,
        child: Text('HEADER_SLOT', key: ValueKey<String>('hdr')),
      ),
    );

    // (a) AU-DESSUS de la première section.
    final headerY = tester.getTopLeft(find.byKey(const ValueKey<String>('hdr')));
    final firstSectionY = tester.getTopLeft(find.text('TITLE_S0'));
    expect(headerY.dy, lessThan(firstSectionY.dy));

    // (b) UN SEUL Scrollable : pas de second défilement imbriqué pour l'en-tête.
    expect(find.byType(Scrollable), findsOneWidget);

    // (c) MÊME défilement : faire défiler la liste DÉPLACE l'en-tête.
    // 🔴 GARDE MORDANTE — régression ré-injectée : en-tête rendu HORS du
    // `ListView` (`Column(children: [header, Expanded(child: ListView…)])`).
    // Verdict observé : ROUGE (« Expected: a value less than <…> Actual: <0.0> »
    // — l'en-tête restait figé à dy=0 pendant que les sections défilaient).
    // Régression retirée ⇒ VERT.
    // Défilement MODÉRÉ (40 px) : l'en-tête reste monté — on observe son
    // DÉPLACEMENT, pas sa disparition.
    await tester.drag(find.byType(Scrollable), const Offset(0, -40));
    await tester.pump();
    final headerAfter =
        tester.getTopLeft(find.byKey(const ValueKey<String>('hdr')));
    final sectionAfter = tester.getTopLeft(find.text('TITLE_S0'));
    expect(headerAfter.dy, lessThan(headerY.dy));
    // …et il défile EXACTEMENT comme les sections (même surface défilante).
    expect(
      headerY.dy - headerAfter.dy,
      moreOrLessEquals(firstSectionY.dy - sectionAfter.dy, epsilon: 0.5),
    );
  });

  // --------------------------------------------------------------- G1b ------
  testWidgets(
      'G1b — mappage d\'index : avec en-tête, CHAQUE section est rendue une '
      'fois, dans l\'ordre, sans décalage', (tester) async {
    await _pumpLayout(
      tester,
      sections: _sections(3),
      header: const SizedBox(
        height: 40,
        child: Text('HEADER_SLOT', key: ValueKey<String>('hdr')),
      ),
    );

    // 🔴 GARDE MORDANTE — régression ré-injectée : `sections[index]` SANS le
    // décalage `- leading`. Verdict observé : ROUGE (« RangeError (length):
    // Invalid value: Not in inclusive range 0..2: 3 » levé pendant la
    // construction du sliver, puis « Expected: exactly one matching candidate /
    // Actual: Found 0 widgets with text "TITLE_S0" »).
    // Régression retirée ⇒ VERT.
    for (var i = 0; i < 3; i++) {
      expect(find.text('TITLE_S$i'), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('TITLE_S0')).dy,
      lessThan(tester.getTopLeft(find.text('TITLE_S1')).dy),
    );
    expect(_listView(tester).semanticChildCount, 4); // 1 en-tête + 3 sections
  });

  // ---------------------------------------------------------------- G2 ------
  testWidgets(
      'G2 — slots NON fournis : absents STRUCTURELLEMENT (aucun item réservé, '
      'aucun SizedBox.shrink fantôme)', (tester) async {
    final built = <String>[];
    await _pumpLayout(tester, sections: _sections(3, built: built));

    // Le décompte d'items du sliver EST le nombre de sections : aucun slot
    // n'est réservé « au cas où ».
    // 🔴 GARDE MORDANTE — régression ré-injectée : `itemCount: 1 +
    // sections.length` avec `index == 0 ? (header ?? const SizedBox.shrink())`.
    // Verdict observé : ROUGE (« Expected: <3> Actual: <4> »).
    // Régression retirée ⇒ VERT.
    expect(_listView(tester).semanticChildCount, 3);

    // Et le PREMIER item rendu est bien une section (rien au-dessus).
    expect(
      tester.getTopLeft(find.text('TITLE_S0')).dy,
      lessThan(tester.getTopLeft(find.text('TITLE_S1')).dy),
    );
    expect(built, <String>['S0', 'S1', 'S2']);
  });

  // ---------------------------------------------------------------- G3 ------
  testWidgets(
      'G3 — virtualisation PRÉSERVÉE avec en-tête : 200 sections, seules '
      'celles du viewport sont construites', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final built = <String>[];
    await _pumpLayout(
      tester,
      sections: _sections(200, built: built),
      header: const SizedBox(height: 80, child: Text('HEADER_SLOT')),
      footer: const SizedBox(height: 80, child: Text('FOOTER_SLOT')),
    );

    // 🔴 GARDE MORDANTE — régression ré-injectée : `SingleChildScrollView(child:
    // Column(children: [if (headerSlot != null) headerSlot, for (final spec in
    // sections) _ZStudySection(…), if (footerSlot != null) footerSlot]))` — le
    // réflexe « je mets l'en-tête et les sections dans une Column ».
    // Verdict observé : ROUGE (« Expected: a value less than <40> Actual: <200> »
    // — les 200 sections construites d'un coup). Régression retirée ⇒ VERT.
    //
    // ⚠️ HONNÊTETÉ SUR LA PORTÉE : une seconde régression a été essayée —
    // `ListView(children: […])` — et elle **N'A PAS** fait rougir cette garde.
    // Ce n'est pas une faiblesse de la sonde mais un fait Flutter :
    // `SliverChildListDelegate` construit la LISTE de widgets d'un coup, mais
    // n'instancie les *Elements* (donc n'appelle `build`) que pour le viewport.
    // Cette garde mesure donc la virtualisation au niveau **build**, pas le coût
    // d'allocation de la liste de widgets — et elle le dit.
    expect(built.length, lessThan(40));
    expect(built.length, greaterThan(0));
    // La dernière section n'a PAS été construite : la liste est bien paresseuse.
    expect(find.text('TITLE_S199'), findsNothing);
  });

  // ---------------------------------------------------------------- G4 ------
  testWidgets(
      'G4 — AD-2 : l\'en-tête n\'est NI reconstruit NI remonté quand les '
      'sections changent (instance d\'en-tête stable)', (tester) async {
    final counter = _Counter();
    // Instance STABLE, repoussée à l'identique par l'appelant.
    final header = _HeaderProbe(counter: counter, label: 'H');

    await _pumpLayout(tester, sections: _sections(3), header: header);
    final buildsAfterFirstPump = counter.builds;
    expect(buildsAfterFirstPump, 1);
    expect(counter.mounts, 1);

    // Trois jeux de sections DIFFÉRENTS (ids, nombre) — l'en-tête, lui, ne
    // change pas.
    await _pumpLayout(tester, sections: _sections(5, prefix: 'B'), header: header);
    await _pumpLayout(tester, sections: _sections(2, prefix: 'C'), header: header);
    await _pumpLayout(tester, sections: _sections(4, prefix: 'D'), header: header);

    // Les sections ont bien changé (la sonde n'est pas figée par construction).
    expect(find.text('TITLE_D0'), findsOneWidget);
    expect(find.text('TITLE_S0'), findsNothing);

    // 🔴 GARDE MORDANTE — régression ré-injectée : en-tête emballé dans une clé
    // dérivée des sections, `KeyedSubtree(key: ValueKey('header:'
    // '${sections.length}'), child: headerSlot)`. Verdict observé : ROUGE
    // (« Expected: <1> Actual: <4> ») — l'en-tête était REMONTÉ à chaque
    // changement de sections, perdant tout état local.
    // Régression retirée ⇒ VERT.
    expect(counter.builds, buildsAfterFirstPump);
    expect(counter.mounts, 1);
  });

  // ---------------------------------------------------------------- G5 ------
  testWidgets(
      'G5 — AD-2 réciproque : changer le CONTENU de l\'en-tête ne remonte pas '
      'les sections (leur état local de repli survit)', (tester) async {
    final sections = _sections(2, collapsible: true);
    final counterA = _Counter();

    await _pumpLayout(
      tester,
      sections: sections,
      header: _HeaderProbe(counter: counterA, label: 'A'),
    );
    expect(find.byKey(const ValueKey<String>('item:S0')), findsOneWidget);

    // État LOCAL de la section 0 : repliée.
    await tester.tap(find.byKey(const ValueKey<String>('section:S0:collapse')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('item:S0')), findsNothing);

    // L'appelant repousse un en-tête au contenu DIFFÉRENT (nouvelle instance),
    // sections inchangées.
    final counterB = _Counter();
    await _pumpLayout(
      tester,
      sections: sections,
      header: _HeaderProbe(counter: counterB, label: 'B'),
    );
    expect(find.byKey(const ValueKey<String>('probe:B')), findsOneWidget);

    // 🔴 GARDE MORDANTE — régression ré-injectée : `ListView.builder(key:
    // ValueKey<Object?>(headerSlot), …)` (le réflexe « je keye la liste pour
    // forcer le rafraîchissement »). Verdict observé : ROUGE (« Expected: no
    // matching candidates Actual: … found 1 widget with key
    // [<'item:S0'>] » — la section, remontée, était redevenue dépliée et son
    // repli perdu).
    // Régression retirée ⇒ VERT.
    expect(find.byKey(const ValueKey<String>('item:S0')), findsNothing);
    // Contre-preuve de falsifiabilité de la sonde : la section 1, jamais
    // repliée, est bien rendue (l'absence ci-dessus n'est pas un artefact).
    expect(find.byKey(const ValueKey<String>('item:S1')), findsOneWidget);
  });

  // ---------------------------------------------------------------- G6 ------
  testWidgets(
      'G6 — pied fourni : rendu SOUS la dernière section, même défilement ; '
      'non fourni ⇒ absent structurellement', (tester) async {
    await _pumpLayout(
      tester,
      sections: _sections(2),
      footer: const SizedBox(
        height: 40,
        child: Text('FOOTER_SLOT', key: ValueKey<String>('ftr')),
      ),
    );

    // 🔴 GARDE MORDANTE — régression ré-injectée : ordre des slots inversé —
    // le pied émis en index 0 et les sections décalées derrière lui.
    // Verdict observé : ROUGE (« Expected: a value greater than <130.0>
    // Actual: <0.0> »). Régression retirée ⇒ VERT.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey<String>('ftr'))).dy,
      greaterThan(tester.getTopLeft(find.text('TITLE_S1')).dy),
    );
    expect(_listView(tester).semanticChildCount, 3);
    expect(find.byType(Scrollable), findsOneWidget);

    // Sans pied : décompte strictement égal au nombre de sections.
    await _pumpLayout(tester, sections: _sections(2));
    expect(_listView(tester).semanticChildCount, 2);
    expect(find.byKey(const ValueKey<String>('ftr')), findsNothing);
  });

  // ---------------------------------------------------------------- G7 ------
  group('G7 — voie complète jusqu\'à ZStudyFolderDetail (onglet Matériel)', () {
    testWidgets(
        'slot d\'en-tête câblé : rendu au-dessus des sections, RE-FOURNI avec '
        'le sous-dossier sélectionné', (tester) async {
      await setScreen(tester, 900, 800);
      final seen = <String?>[];
      await pumpDetail(
        tester,
        materialHeaderBuilder: (context, id) {
          seen.add(id);
          return Text('HDR:${id ?? 'null'}',
              key: ValueKey<String>('hdr:${id ?? 'null'}'));
        },
        materialFooterBuilder: (context, id) =>
            Text('FTR:${id ?? 'null'}', key: const ValueKey<String>('ftr')),
      );

      // 🔴 GARDE MORDANTE — régression ré-injectée : `header:`/`footer:` NON
      // câblés dans `_materialBody()` (retour à `ZSectionedStudyLayout(sections:
      // …)` seul). Verdict observé : ROUGE (« Expected: exactly one matching
      // candidate / Actual: Found 0 widgets with key [<'hdr:null'>] »).
      // Régression retirée ⇒ VERT.
      expect(find.byKey(const ValueKey<String>('hdr:null')), findsOneWidget);
      expect(seen, contains(null));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('hdr:null'))).dy,
        lessThan(tester.getTopLeft(find.text('title:null')).dy),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<String>('ftr'))).dy,
        greaterThan(tester.getTopLeft(find.text('title:null')).dy),
      );

      // La sélection RE-FOURNIT le slot (dépendance au sous-dossier).
      await tester.tap(find.text('Sous-dossier 1'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey<String>('hdr:sf1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('hdr:null')), findsNothing);
      expect(seen, contains('sf1'));
    });

    testWidgets('slots NON fournis ⇒ rendu STRICTEMENT inchangé (non-régression)',
        (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);
      // Aucun item réservé : le décompte du sliver Matériel EST le nombre de
      // sections fournies par le harnais (1).
      final lists = tester
          .widgetList<ListView>(find.byType(ListView))
          .where((l) => l.semanticChildCount == 1);
      expect(lists, isNotEmpty);
      expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
    });

    testWidgets('un builder qui rend `null` ⇒ slot ABSENT (AD-4/AD-10)',
        (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(
        tester,
        // Slot présent pour « tous », ABSENT dès qu'un sous-dossier est choisi.
        materialHeaderBuilder: (context, id) => id == null
            ? const Text('HDR_ALL', key: ValueKey<String>('hdr-all'))
            : null,
      );
      expect(find.byKey(const ValueKey<String>('hdr-all')), findsOneWidget);

      await tester.tap(find.text('Sous-dossier 1'));
      await tester.pumpAndSettle();
      // 🔴 GARDE MORDANTE — régression ré-injectée : `header: widget
      // .materialHeaderBuilder?.call(context, id) ?? const SizedBox.shrink()`.
      // Verdict observé : ROUGE (« Expected: non-empty / Actual:
      // WhereIterable<ListView>:[] » — plus AUCUN sliver à 1 item : un slot
      // fantôme était réservé, portant le décompte à 2). La MÊME régression
      // fait aussi rougir la garde de non-régression ci-dessus (verdict
      // identique) — vérifié. Régression retirée ⇒ VERT.
      expect(find.byKey(const ValueKey<String>('hdr-all')), findsNothing);
      final lists = tester
          .widgetList<ListView>(find.byType(ListView))
          .where((l) => l.semanticChildCount == 1);
      expect(lists, isNotEmpty);
    });
  });
}
