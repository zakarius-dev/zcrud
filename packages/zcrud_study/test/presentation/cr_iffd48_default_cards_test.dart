/// **CR-IFFD-48** — cartes par défaut du socle (document, note, carte mentale,
/// examen) + voies typées `.mindmaps`/`.exams` + complément CR-47
/// (`semanticLabelOf` relayé par `.flashcards`).
///
/// Les leçons MESURÉES de CR-47 sont rejouées sur CHAQUE carte nouvelle :
/// - hauteur mesurée en colonne NON BORNÉE (le seul régime où un `Align` sans
///   `heightFactor` se voit — 854 dp mesurés à l'époque) ;
/// - rail étroit (300 dp) ≠ grille large : surface élargie par
///   `tester.view.physicalSize`, sinon la mesure ment ;
/// - cellule à hauteur FIXE : les slots cèdent, la carte ne déborde pas.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String kLongTitle =
    'Support de cours particulièrement détaillé sur la valeur transactionnelle '
    'en douane et ses ajustements obligatoires, édition annotée';

const String kLongExcerpt =
    'La valeur transactionnelle est le prix effectivement payé ou à payer pour '
    'les marchandises lorsqu\'elles sont vendues pour l\'exportation à '
    'destination du territoire douanier, sous réserve des ajustements prévus.';

List<ZFlashcardTag> _longTags([int n = 4]) => <ZFlashcardTag>[
      for (int i = 0; i < n; i++)
        ZFlashcardTag(id: 't$i', title: 'Étiquette de révision numéro $i'),
    ];

ZMindmap _mindmap({
  String id = 'm1',
  String title = 'Plan de révision',
  String? description,
  List<ZMindmapNode> nodes = const <ZMindmapNode>[],
}) =>
    ZMindmap(id: id, folderId: 'f1', title: title, description: description,
        nodes: nodes);

ZExam _exam({
  String? id = 'e1',
  String title = 'Examen de dédouanement',
  bool reminderEnabled = false,
}) =>
    ZExam(id: id, folderId: 'f1', title: title,
        reminderEnabled: reminderEnabled);

Widget _host(Widget child, {double? width, double? height}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: AlignmentDirectional.topStart,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void _wideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Color? _boxColor(WidgetTester tester, Key key) {
  final Finder box = find.byKey(key).evaluate().single.widget is DecoratedBox
      ? find.byKey(key)
      : find.descendant(
          of: find.byKey(key), matching: find.byType(DecoratedBox));
  return (tester.widget<DecoratedBox>(box).decoration as BoxDecoration).color;
}

/// Rejoue sur [build] les DEUX mesures de layout de CR-47 : rail étroit à
/// hauteur non bornée (aucun débordement, hauteur au CONTENU) et cellules à
/// hauteur FIXE (les slots cèdent). Mutualisée : les deux surfaces d'un même
/// repli ne sont PAS mesurées dans des tests séparés par carte.
Future<void> _expectRailAndFixedCells(
  WidgetTester tester,
  Widget Function() build, {
  required String label,
  required List<double> fixedHeights,
  double maxUnboundedHeight = 400,
}) async {
  _wideSurface(tester);
  // Rail contraint 300 dp, hauteur NON bornée.
  await tester.pumpWidget(_host(build(), width: 300));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull,
      reason: '🔴 $label : débordement en rail 300 dp.');
  final double unbounded =
      tester.getSize(find.byType(ZStudyToolsItemCard)).height;
  expect(unbounded, lessThan(maxUnboundedHeight),
      reason: '🔴 $label : la carte doit se dimensionner à son CONTENU en '
          'hauteur non bornée (leçon CR-47 : 854 dp mesurés quand un `Align` '
          'sans `heightFactor` remplissait la place). Mesuré : $unbounded dp.');
  expect(unbounded, greaterThan(48.0),
      reason: '🔴 garde VACUELLE sinon : une carte vide passerait.');

  // Grille libre : plus large ⇒ jamais PLUS HAUT.
  final List<double> heights = <double>[unbounded];
  for (final double w in <double>[800, 1200]) {
    await tester.pumpWidget(_host(build(), width: w));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$label, largeur $w dp');
    heights.add(tester.getSize(find.byType(ZStudyToolsItemCard)).height);
  }
  expect(heights[1], lessThanOrEqualTo(heights[0]),
      reason: '🔴 $label : plus large ne doit JAMAIS être plus haut '
          '(mesuré : $heights).');
  expect(heights[2], lessThanOrEqualTo(heights[1]),
      reason: '🔴 $label : plus large ne doit JAMAIS être plus haut '
          '(mesuré : $heights).');

  // Cellules de rail à hauteur FIXE : les slots cèdent, la carte ne déborde
  // pas (leçon CR-IFFD-37).
  for (final double h in fixedHeights) {
    await tester.pumpWidget(_host(build(), width: 300, height: h));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull,
        reason: '🔴 $label : cellule 300 × $h dp — une hauteur imposée ne '
            'doit pas produire de `RenderFlex overflowed`.');
    expect(tester.getSize(find.byType(ZStudyToolsItemCard)).height, h);
  }
}

void main() {
  // -------------------------------------------------------------------------
  group('Complément CR-IFFD-47 — `.flashcards` relaie `semanticLabelOf`', () {
    testWidgets('le libellé sémantique PAR CARTE atteint la carte rendue',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wideSurface(tester);
      final spec = ZStudyToolsSectionSpec.flashcards(
        id: 'flashcards',
        title: 'Cartes',
        cards: <ZFlashcard>[
          const ZFlashcard(id: 'a', question: 'Énoncé A'),
        ],
        emptyState: const SizedBox.shrink(),
        semanticLabelOf: (ZFlashcard c) => 'Carte de révision ${c.id}',
      );
      await tester.pumpWidget(_host(
        Builder(builder: (BuildContext c) => spec.itemBuilder(c, 0)),
        width: 500,
      ));
      await tester.pumpAndSettle();

      // 🔴 NON-VACUITÉ : la valeur attendue est DÉRIVÉE de la carte, pas la
      // valeur ambiante (le repli serait l'énoncé « Énoncé A »).
      expect(find.bySemanticsLabel('Carte de révision a'), findsOneWidget,
          reason: '🔴 CR-47 incomplète : `semanticLabelOf` doit être relayé '
              'à `ZDefaultFlashcardCard.semanticLabel`, par carte.');
      expect(find.bySemanticsLabel('Énoncé A'), findsNothing,
          reason: 'le libellé injecté doit PRIMER sur le repli (énoncé).');
      handle.dispose();
    });

    testWidgets('sans `semanticLabelOf` : repli STRICTEMENT antérieur (énoncé)',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wideSurface(tester);
      final spec = ZStudyToolsSectionSpec.flashcards(
        id: 'flashcards',
        title: 'Cartes',
        cards: <ZFlashcard>[const ZFlashcard(id: 'a', question: 'Énoncé A')],
        emptyState: const SizedBox.shrink(),
      );
      await tester.pumpWidget(_host(
        Builder(builder: (BuildContext c) => spec.itemBuilder(c, 0)),
        width: 500,
      ));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Énoncé A'), findsOneWidget);
      handle.dispose();
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-48 §doc — icône TYPÉE par format (mapping OUVERT)', () {
    test('résolution : extension, point, casse, MIME — puis repli TOTAL', () {
      expect(zResolveDocumentFormatIcon('pdf'),
          Icons.picture_as_pdf_outlined);
      expect(zResolveDocumentFormatIcon('.PDF'),
          Icons.picture_as_pdf_outlined,
          reason: 'normalisation : point d\'extension et casse.');
      expect(zResolveDocumentFormatIcon('application/pdf'),
          Icons.picture_as_pdf_outlined,
          reason: 'MIME : le sous-type doit être essayé.');
      expect(zResolveDocumentFormatIcon('image/x-exotic'),
          Icons.image_outlined,
          reason: 'MIME : la FAMILLE doit être essayée en dernier recours.');
      expect(zResolveDocumentFormatIcon('format-inconnu'),
          zDefaultDocumentFallbackIcon);
      expect(zResolveDocumentFormatIcon(null), zDefaultDocumentFallbackIcon);
      expect(zResolveDocumentFormatIcon(''), zDefaultDocumentFallbackIcon);
    });

    test('le mapping INJECTÉ prime sur la table par défaut (AD-4 : ouvert)',
        () {
      const Map<String, IconData> icons = <String, IconData>{
        'pdf': Icons.star_outline,
        'genially': Icons.animation,
      };
      expect(zResolveDocumentFormatIcon('pdf', icons: icons),
          Icons.star_outline,
          reason: '🔴 un hôte doit pouvoir REMPLACER un glyphe par défaut.');
      expect(zResolveDocumentFormatIcon('genially', icons: icons),
          Icons.animation,
          reason: '🔴 un format NOUVEAU = une entrée de map, jamais une CR '
              '(enum fermé interdit).');
      // 🔴 NON-VACUITÉ : le glyphe injecté DIFFÈRE du défaut, sinon la
      // priorité ne prouverait rien.
      expect(Icons.star_outline, isNot(Icons.picture_as_pdf_outlined));
    });

    testWidgets('l\'icône typée est rendue, le format est REDIT en texte '
        '(AD-13) et annoncé', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(
          title: 'Cours de chimie',
          subtitle: 'Modifié hier',
          formatKey: 'application/pdf',
          formatLabel: 'PDF',
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(ZDefaultDocumentCard.iconTileKey),
          matching: find.byIcon(Icons.picture_as_pdf_outlined),
        ),
        findsOneWidget,
      );
      // AD-13 : l'info portée par l'icône/couleur est AUSSI en texte…
      expect(find.text('PDF'), findsOneWidget);
      // …et dans le libellé sémantique par défaut de la carte.
      expect(find.bySemanticsLabel('Cours de chimie, Modifié hier, PDF'),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('AD-4 : sans `formatLabel`, la puce est ABSENTE (jamais un '
        'libellé inventé)', (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(title: 'Cours', formatKey: 'pdf'),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultDocumentCard.formatChipKey), findsNothing);
      // Le socle ne traduit JAMAIS : ni « PDF » ni la clé opaque rendue.
      expect(find.text('PDF'), findsNothing);
      expect(find.text('pdf'), findsNothing);
    });

    testWidgets('accent STABLE par format : même format ⇒ même tuile, la puce '
        'porte la MÊME paire', (WidgetTester tester) async {
      _wideSurface(tester);
      final List<Color?> seen = <Color?>[];
      for (final String title in <String>['Premier', 'Second']) {
        await tester.pumpWidget(_host(
          ZDefaultDocumentCard(
              title: title, formatKey: 'pdf', formatLabel: 'PDF'),
          width: 400,
        ));
        await tester.pumpAndSettle();
        seen.add(_boxColor(tester, ZDefaultDocumentCard.iconTileKey));
      }
      expect(seen.first, isNotNull);
      expect(seen[1], seen.first,
          reason: '🔴 l\'accent doit dériver du FORMAT (clé stable), pas du '
              'titre ni de l\'ordre de rendu.');
      expect(_boxColor(tester, ZDefaultDocumentCard.formatChipKey), seen.first,
          reason: 'tuile et puce portent la même paire dérivée.');
    });

    testWidgets('activation : onTap déclenche ; sans geste, AUCUN InkWell '
        '(AD-45)', (WidgetTester tester) async {
      _wideSurface(tester);
      int taps = 0;
      await tester.pumpWidget(_host(
        ZDefaultDocumentCard(title: 'Cours', onTap: () => taps++),
        width: 400,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ZDefaultDocumentCard));
      expect(taps, 1);

      await tester.pumpWidget(_host(
        const ZDefaultDocumentCard(title: 'Cours'),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('mesures rail/grille/cellules (leçons CR-47 rejouées)',
        (WidgetTester tester) async {
      await _expectRailAndFixedCells(
        tester,
        () => const ZDefaultDocumentCard(
          title: kLongTitle,
          subtitle: 'Modifié hier à 18 h 42, 2,4 Mo',
          formatKey: 'pdf',
          formatLabel: 'PDF',
        ),
        label: 'ZDefaultDocumentCard',
        // Plancher : tuile d'icône 40 dp + padding de carte (2 × gapM).
        fixedHeights: <double>[80, 120, 160],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-48 §note — ZDefaultNoteCard', () {
    testWidgets('extrait TRONQUÉ + balises via ZTagChips (rien de réécrit)',
        (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultNoteCard(
          title: 'Note de synthèse',
          subtitle: 'Modifiée hier',
          excerpt: kLongExcerpt,
          tags: _longTags(2),
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      final Text excerpt = tester
          .widget<Text>(find.byKey(ZDefaultNoteCard.excerptKey));
      expect(excerpt.maxLines, 2);
      expect(excerpt.overflow, TextOverflow.ellipsis);
      expect(find.byType(ZTagChips), findsOneWidget);
      expect(find.byKey(ZDefaultNoteCard.accentKey), findsOneWidget);
    });

    testWidgets('AD-4 : sans extrait NI balises, le corps est ABSENT',
        (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        const ZDefaultNoteCard(title: 'Note'),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultNoteCard.excerptKey), findsNothing);
      expect(find.byKey(ZDefaultNoteCard.tagsKey), findsNothing);
      expect(find.byType(ZTagChips), findsNothing);
    });

    testWidgets('accent STABLE : même titre ⇒ même accent',
        (WidgetTester tester) async {
      _wideSurface(tester);
      final List<Color?> seen = <Color?>[];
      for (int i = 0; i < 2; i++) {
        await tester.pumpWidget(_host(
          const ZDefaultNoteCard(title: 'Note de synthèse'),
          width: 400,
        ));
        await tester.pumpAndSettle();
        final ColoredBox box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(ZDefaultNoteCard.accentKey),
            matching: find.byType(ColoredBox),
          ),
        );
        seen.add(box.color);
      }
      expect(seen.first, isNotNull);
      expect(seen[1], seen.first);
    });

    testWidgets('mesures rail/grille/cellules (leçons CR-47 rejouées)',
        (WidgetTester tester) async {
      await _expectRailAndFixedCells(
        tester,
        () => ZDefaultNoteCard(
          title: kLongTitle,
          subtitle: 'Modifiée hier à 18 h 42',
          excerpt: kLongExcerpt,
          tags: _longTags(),
        ),
        label: 'ZDefaultNoteCard',
        fixedHeights: <double>[80, 120, 180],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-48 §mindmap — ZDefaultMindmapCard (vignette)', () {
    ZMindmapNode node(String id, [List<ZMindmapNode> children = const []]) =>
        ZMindmapNode(id: id, label: id, children: children);

    test('zMindmapNodeCount compte TOUTE la forêt (racines + descendance)',
        () {
      expect(zMindmapNodeCount(const <ZMindmapNode>[]), 0);
      expect(
        zMindmapNodeCount(<ZMindmapNode>[
          node('r1', <ZMindmapNode>[
            node('a', <ZMindmapNode>[node('a1'), node('a2')]),
            node('b'),
          ]),
          node('r2'),
        ]),
        6,
        reason: '🔴 un compte limité aux racines mentirait sur la vignette '
            'ET sur la puce.',
      );
    });

    testWidgets('vignette DÉCORATIVE + compte redit EN TEXTE (AD-13)',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultMindmapCard(
          map: _mindmap(
            description: 'Chapitres 1 à 4',
            nodes: <ZMindmapNode>[
              node('r', <ZMindmapNode>[node('a'), node('b')]),
            ],
          ),
          nodeCountLabel: (int n) => '$n nœuds',
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(ZDefaultMindmapCard.vignetteKey), findsOneWidget);
      expect(find.text('3 nœuds'), findsOneWidget,
          reason: '🔴 le compte affiché doit être le compte RÉEL de la forêt.');
      expect(
        find.bySemanticsLabel('Plan de révision, Chapitres 1 à 4, 3 nœuds'),
        findsOneWidget,
        reason: 'l\'information de la vignette est ANNONCÉE (AD-13).',
      );
      handle.dispose();
    });

    testWidgets('AD-4/FR-26 : sans `nodeCountLabel`, la puce est ABSENTE '
        '(jamais un nombre nu)', (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultMindmapCard(map: _mindmap(nodes: <ZMindmapNode>[node('r')])),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultMindmapCard.countChipKey), findsNothing);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('titre vide ⇒ `untitledLabel` INJECTÉ ; sans lui, RIEN '
        'd\'inventé', (WidgetTester tester) async {
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultMindmapCard(
          map: _mindmap(title: ''),
          untitledLabel: 'Carte sans titre',
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Carte sans titre'), findsOneWidget);

      await tester.pumpWidget(_host(
        ZDefaultMindmapCard(map: _mindmap(title: '')),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Carte sans titre'), findsNothing,
          reason: '🔴 le socle ne traduit JAMAIS en dur (FR-26).');
    });

    testWidgets('mesures rail/grille/cellules (leçons CR-47 rejouées)',
        (WidgetTester tester) async {
      await _expectRailAndFixedCells(
        tester,
        () => ZDefaultMindmapCard(
          map: _mindmap(
            title: kLongTitle,
            description: 'Description assez longue pour replier sur deux '
                'lignes en rail étroit, avec des chapitres nombreux',
            nodes: <ZMindmapNode>[
              node('r', <ZMindmapNode>[node('a'), node('b'), node('c')]),
            ],
          ),
          nodeCountLabel: (int n) => '$n nœuds dans cette carte mentale',
        ),
        label: 'ZDefaultMindmapCard',
        fixedHeights: <double>[80, 120, 160],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-48 §exam — ZDefaultExamCard', () {
    testWidgets('date DÉJÀ formatée par l\'hôte + puce de rappel EN TEXTE '
        '(AD-13)', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wideSurface(tester);
      await tester.pumpWidget(_host(
        ZDefaultExamCard(
          exam: _exam(reminderEnabled: true),
          dateLabel: 'jeudi 12 mars, 9 h',
          reminderLabel: 'Rappels activés',
        ),
        width: 400,
      ));
      await tester.pumpAndSettle();

      expect(find.text('jeudi 12 mars, 9 h'), findsOneWidget);
      expect(find.text('Rappels activés'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
            'Examen de dédouanement, jeudi 12 mars, 9 h, Rappels activés'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('la puce de rappel exige l\'ÉTAT **et** le LIBELLÉ (AD-4)',
        (WidgetTester tester) async {
      _wideSurface(tester);
      // Rappels DÉSACTIVÉS + libellé fourni ⇒ puce absente (elle mentirait).
      await tester.pumpWidget(_host(
        ZDefaultExamCard(exam: _exam(), reminderLabel: 'Rappels activés'),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultExamCard.reminderChipKey), findsNothing);
      expect(find.text('Rappels activés'), findsNothing);

      // Rappels ACTIVÉS sans libellé injecté ⇒ puce absente (FR-26 : le socle
      // ne traduit jamais).
      await tester.pumpWidget(_host(
        ZDefaultExamCard(exam: _exam(reminderEnabled: true)),
        width: 400,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(ZDefaultExamCard.reminderChipKey), findsNothing);
    });

    testWidgets('accent STABLE de genre : deux examens ⇒ même accent',
        (WidgetTester tester) async {
      _wideSurface(tester);
      final List<Color?> seen = <Color?>[];
      for (final String title in <String>['Premier', 'Second']) {
        await tester.pumpWidget(_host(
          ZDefaultExamCard(exam: _exam(title: title)),
          width: 400,
        ));
        await tester.pumpAndSettle();
        final ColoredBox box = tester.widget<ColoredBox>(
          find.descendant(
            of: find.byKey(ZDefaultExamCard.accentKey),
            matching: find.byType(ColoredBox),
          ),
        );
        seen.add(box.color);
      }
      expect(seen.first, isNotNull);
      expect(seen[1], seen.first);
    });

    testWidgets('mesures rail/grille/cellules (leçons CR-47 rejouées)',
        (WidgetTester tester) async {
      await _expectRailAndFixedCells(
        tester,
        () => ZDefaultExamCard(
          exam: _exam(title: kLongTitle, reminderEnabled: true),
          dateLabel: 'jeudi 12 mars 2026 à 9 heures précises, salle B-204',
          reminderLabel: 'Rappels activés 7, 3 et 1 jours avant',
        ),
        label: 'ZDefaultExamCard',
        fixedHeights: <double>[72, 120, 160],
      );
    });
  });

  // -------------------------------------------------------------------------
  group('CR-IFFD-48 — voies typées `.mindmaps` / `.exams`', () {
    test('`.mindmaps` dérive itemCount et NE propose PAS le réordonnancement',
        () {
      final spec = ZStudyToolsSectionSpec.mindmaps(
        id: 'mindmaps',
        title: 'Cartes mentales',
        maps: <ZMindmap>[_mindmap(id: 'a'), _mindmap(id: 'b')],
        emptyState: const SizedBox.shrink(),
      );
      expect(spec.itemCount, 2);
      expect(spec.onReorder, isNull);
      expect(spec.itemIds, isNull);
    });

    testWidgets('`.mindmaps` rend la carte par défaut, clé STABLE par id, '
        'créneaux PAR CARTE', (WidgetTester tester) async {
      _wideSurface(tester);
      final List<String> opened = <String>[];
      final spec = ZStudyToolsSectionSpec.mindmaps(
        id: 'mindmaps',
        title: 'Cartes mentales',
        maps: <ZMindmap>[
          _mindmap(id: 'a', title: 'Alpha'),
          _mindmap(id: 'b', title: 'Beta'),
        ],
        emptyState: const SizedBox.shrink(),
        onCardTap: (ZMindmap m) => opened.add(m.id),
        semanticLabelOf: (ZMindmap m) => 'Carte mentale ${m.id}',
      );
      await tester.pumpWidget(_host(
        Builder(builder: (BuildContext c) => spec.itemBuilder(c, 1)),
        width: 600,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ZDefaultMindmapCard), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zDefaultMindmapCard-b')),
          findsOneWidget,
          reason: 'clé STABLE par carte (AD-2) — jamais l\'index seul.');
      await tester.tap(find.byType(ZDefaultMindmapCard));
      expect(opened, <String>['b'],
          reason: '🔴 le créneau doit recevoir LA carte de l\'index rendu.');
    });

    test('`.exams` dérive itemCount et NE propose PAS le réordonnancement',
        () {
      final spec = ZStudyToolsSectionSpec.exams(
        id: 'exams',
        title: 'Examens',
        exams: <ZExam>[_exam(id: 'a'), _exam(id: 'b'), _exam(id: null)],
        emptyState: const SizedBox.shrink(),
      );
      expect(spec.itemCount, 3);
      expect(spec.onReorder, isNull);
      expect(spec.itemIds, isNull);
    });

    testWidgets('`.exams` : dateLabelOf/semanticLabelOf PAR EXAMEN, clé '
        'stable, éphémère toléré', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      _wideSurface(tester);
      final spec = ZStudyToolsSectionSpec.exams(
        id: 'exams',
        title: 'Examens',
        exams: <ZExam>[
          _exam(id: 'a', title: 'Session A'),
          _exam(id: null, title: 'Brouillon'),
        ],
        emptyState: const SizedBox.shrink(),
        dateLabelOf: (ZExam e) => 'échéance de ${e.title}',
        semanticLabelOf: (ZExam e) => 'Examen ${e.title}',
      );
      await tester.pumpWidget(_host(
        Column(
          children: <Widget>[
            for (int i = 0; i < spec.itemCount; i++)
              Builder(builder: (BuildContext c) => spec.itemBuilder(c, i)),
          ],
        ),
        width: 600,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ZDefaultExamCard), findsNWidgets(2));
      expect(find.text('échéance de Session A'), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zDefaultExamCard-a')),
          findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('zDefaultExamCard-ephemeral-1')),
        findsOneWidget,
        reason: 'un examen éphémère (id null) garde une clé DISTINCTE.',
      );
      expect(find.bySemanticsLabel('Examen Session A'), findsOneWidget);
      handle.dispose();
    });
  });
}
