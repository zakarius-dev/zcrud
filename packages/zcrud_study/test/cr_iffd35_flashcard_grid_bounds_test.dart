// CR-IFFD-35 — `ZFlashcardListView` disposait DÉJÀ ses tuiles via `ZAdaptiveGrid`
// mais n'exposait NI plafond de colonnes NI hauteur d'item : les deux étaient des
// constantes privées. Le socle savait pourtant borner une grille ailleurs
// (`ZStudyToolsSectionSpec.crossAxisMaxColumns` / `crossAxisItemHeight`,
// CR-LEX-77) — l'incohérence était interne.
//
// Le portage se fait AU MÊME CONTRAT (mêmes noms, mêmes types, même défaut
// `null`, même repli AD-10 délégué à `computeCrossAxisCount`), et sur la MÊME
// primitive (`ZAdaptiveGrid`) — jamais une seconde mécanique de grille.
//
// ⚠️ Piège mesuré sur CR-LEX-77 : la surface de test fait 800 dp par défaut, donc
// un `SizedBox(width: 1400)` y serait ÉCRASÉ et le plafond ne mordrait JAMAIS. On
// pompe donc une VRAIE fenêtre et on compte les colonnes par ORDONNÉES RÉELLES.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _labels = ZFlashcardListLabels(
  searchHint: 'Rechercher',
  searchFieldLabel: 'Champ de recherche',
  emptyState: 'Aucune carte',
  noResults: 'Aucun résultat',
  actionsMenuTooltip: 'Actions',
  openAction: 'Ouvrir',
  editAction: 'Modifier',
  deleteAction: 'Supprimer',
  duplicateAction: 'Dupliquer',
  moveUpAction: 'Monter',
  moveDownAction: 'Descendre',
  generateWithAiAction: 'Générer avec IA',
  readOnlyBadge: 'Lecture seule',
);

/// Largeur minimale de tuile CÂBLÉE dans la vue (300 dp) + gouttière 8 dp :
/// à 1400 dp la responsive donne 4 colonnes, à 500 dp une seule.
const int kCardCount = 12;

List<ZFlashcard> _cards([int count = kCardCount]) => <ZFlashcard>[
      for (var i = 0; i < count; i++)
        ZFlashcard(id: 'c$i', question: 'Q$i', answer: 'A$i'),
    ];

Finder _tile(int i) => find.byKey(ValueKey<String>('tile-c$i'));

/// Nombre de tuiles partageant la PREMIÈRE ligne rendue = nombre de colonnes.
///
/// Mesuré sur des ordonnées réelles : un plafond non honoré change le COMPTE,
/// jamais la présence.
int _columnsOnFirstRow(WidgetTester tester, {int count = kCardCount}) {
  final List<double> ys = <double>[];
  for (var i = 0; i < count; i++) {
    final Finder finder = _tile(i);
    if (finder.evaluate().isEmpty) continue; // virtualisé : hors viewport
    ys.add(tester.getTopLeft(finder).dy);
  }
  expect(ys, isNotEmpty, reason: 'aucune tuile rendue : garde inopérante');
  final double first = ys.reduce((double a, double b) => a < b ? a : b);
  return ys.where((double y) => (y - first).abs() < 0.5).length;
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  int? maxColumns,
  double? itemHeight,
  int count = kCardCount,
}) async {
  // ⚠️ VRAIE fenêtre — un SizedBox large serait écrasé à 800 dp.
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ZFlashcardListView(
        cards: _cards(count),
        labels: _labels,
        crossAxisMaxColumns: maxColumns,
        crossAxisItemHeight: itemHeight,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('CR-IFFD-35 — plafond de colonnes', () {
    testWidgets('🔴 plafond 2 MORD à 1400 dp (sans lui : 4 colonnes)',
        (tester) async {
      await _pump(tester, width: 1400, maxColumns: 2);
      expect(_columnsOnFirstRow(tester), 2);
    });

    testWidgets('sans plafond (99), la MÊME largeur donne 4 colonnes',
        (tester) async {
      // Prouve que le 2 ci-dessus vient du PLAFOND, pas de la largeur.
      await _pump(tester, width: 1400, maxColumns: 99);
      expect(_columnsOnFirstRow(tester), 4);
    });

    testWidgets('null (défaut) ⇒ ILLIMITÉ, rendu strictement inchangé',
        (tester) async {
      await _pump(tester, width: 1400);
      final int unlimited = _columnsOnFirstRow(tester);
      expect(unlimited, 4, reason: 'défaut = aucun plafond (rendu historique)');
      await _pump(tester, width: 1400, maxColumns: 99);
      expect(_columnsOnFirstRow(tester), unlimited);
    });

    testWidgets('CONTRÔLE POSITIF — à 500 dp le plafond NE MORD PAS',
        (tester) async {
      // Si cette garde échouait, celles à 1400 dp passeraient par accident.
      await _pump(tester, width: 500);
      final int withoutCap = _columnsOnFirstRow(tester);
      await _pump(tester, width: 500, maxColumns: 2);
      expect(_columnsOnFirstRow(tester), withoutCap);
      expect(withoutCap, lessThan(2));
    });

    testWidgets('AD-10 — plafond absurde (0 / négatif) ⇒ repli PLANCHER (1)',
        (tester) async {
      // Repli ALIGNÉ sur `computeCrossAxisCount`, comme sur le layout sectionné :
      // jamais de grille vide, jamais de throw, jamais une variante locale.
      for (final int absurd in <int>[0, -7]) {
        await _pump(tester, width: 1400, maxColumns: absurd);
        expect(_columnsOnFirstRow(tester), 1, reason: 'maxColumns=$absurd');
        expect(_tile(0), findsOneWidget, reason: 'grille NON vide (AD-10)');
      }
    });
  });

  group('CR-IFFD-35 — hauteur d\'item', () {
    testWidgets('🔴 crossAxisItemHeight injectée ⇒ hauteur de cellule EFFECTIVE',
        (tester) async {
      await _pump(tester, width: 1400, itemHeight: 260);
      expect(tester.getSize(_tile(0)).height, closeTo(260, 0.5));
    });

    testWidgets(
        'null (défaut, mode CARTE — CR-IFFD-58) ⇒ hauteur de RÉFÉRENCE 200 dp',
        (tester) async {
      // CR-IFFD-57/58 (complément owner) : le défaut de la liste est la CARTE
      // à hauteur fixe de référence (200, legacy `SizedBox(height: 200)`) —
      // c'est elle qui rend la grille régulière et confortable.
      await _pump(tester, width: 1400);
      expect(tester.getSize(_tile(0)).height,
          closeTo(ZFlashcardCardReference.cardHeight, 0.5));
    });

    testWidgets('null + mode TUILE ⇒ hauteur historique 180 dp (non-régression)',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ZFlashcardListView(
            cards: _cards(),
            labels: _labels,
            itemStyle: ZFlashcardListItemStyle.tile,
          ),
        ),
      ));
      await tester.pump();
      expect(tester.getSize(_tile(0)).height, closeTo(180, 0.5));
    });
  });

  group('CR-IFFD-35 — invariants préservés', () {
    testWidgets('la grille reste LA MÊME primitive (ZAdaptiveGrid)',
        (tester) async {
      await _pump(tester, width: 1400, maxColumns: 2, itemHeight: 260);
      expect(find.byType(ZAdaptiveGrid), findsOneWidget,
          reason: 'aucune seconde mécanique de grille');
      expect(find.byKey(ZFlashcardListView.gridKey), findsOneWidget);
    });

    testWidgets('AD-2 — virtualisation PRÉSERVÉE sous plafond de colonnes',
        (tester) async {
      // Un plafond bas ALLONGE la grille : c'est exactement la configuration où
      // une matérialisation (`ZAdaptiveGrid(children:)`) coûterait le plus.
      //
      // 🔴 MESURÉ : compter les tuiles MONTÉES ne discrimine PAS. Sous la
      // régression `children:`, le compte reste IDENTIQUE (10 sur 300) — le
      // viewport cull les éléments dans les deux cas ; ce qui change est que
      // l'appelant a d'abord CONSTRUIT les 300 widgets, invisible à l'arbre.
      // La garde porte donc sur le MÉCANISME : en mode virtualisé la grille EST
      // la surface scrollable (`shrinkWrap: false`, physics non figées) ; en
      // mode `children:` elle shrink-wrappe sous des physics NON défilantes.
      const int many = 300;
      await _pump(tester, width: 1400, maxColumns: 2, count: many);

      final GridView grid = tester.widget<GridView>(
        find.descendant(
          of: find.byKey(ZFlashcardListView.gridKey),
          matching: find.byType(GridView),
        ),
      );
      expect(grid.shrinkWrap, isFalse,
          reason: 'shrinkWrap ⇒ la grille layoute tout : virtualisation perdue');
      expect(grid.physics, isNot(isA<NeverScrollableScrollPhysics>()),
          reason: 'la grille virtualisée EST la surface scrollable');

      final int built = <int>[
        for (var i = 0; i < many; i++) if (_tile(i).evaluate().isNotEmpty) i,
      ].length;
      expect(built, greaterThan(0), reason: 'garde inopérante si rien n\'est bâti');
      expect(built, lessThan(many),
          reason: 'seul le viewport est monté (complément, NON discriminant seul)');
    });
  });
}
