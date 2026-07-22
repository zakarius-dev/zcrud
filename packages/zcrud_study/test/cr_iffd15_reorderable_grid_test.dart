// CR-IFFD-15 — la coexistence de `onReorder` et `crossAxisMinItemWidth` PRODUIT
// une grille multi-colonnes RÉORDONNABLE (activation IMPLICITE, aucun changement
// d'API hôte). Jusqu'ici les deux étaient EXCLUSIFS : un `assert` le signalait et
// le rendu retombait sur une liste mono-colonne.
//
// Gardes de ce fichier (câblage ; les gardes de la MÉCANIQUE — index linéaire
// inter-lignes, ordre optimiste local, repli AD-10 — sont prouvées mordantes
// dans `zcrud_responsive/test/z_reorderable_adaptive_grid_test.dart`) :
//   * W1 : onReorder + crossAxisMinItemWidth ⇒ grille MULTI-COLONNES réordonnable
//          (et PLUS aucun `assert` d'exclusivité) ;
//   * W2 : NON-RÉGRESSION — onReorder SEUL reste une liste mono-colonne
//          (`ReorderableListView`), et crossAxisMinItemWidth SEUL reste une
//          `ZAdaptiveGrid` NON réordonnable ;
//   * W3 : les libellés d'actions sémantiques INJECTÉS priment sur le repli ;
//   * W4 : un dépôt réel remonte des indices en convention removeAt/insert —
//          les MÊMES que ceux du mode liste (symétrie `zReorderIds`).

import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZAdaptiveGrid, ZReorderableAdaptiveGrid;
import 'package:zcrud_study/zcrud_study.dart';

const String kMoveBefore = 'AVANT-XYZ';
const String kMoveAfter = 'APRES-XYZ';

ZStudyToolsSectionSpec _spec({
  required List<String> ids,
  double? crossAxisMinItemWidth,
  void Function(int oldIndex, int newIndex)? onReorder,
  String? moveBefore,
  String? moveAfter,
}) =>
    ZStudyToolsSectionSpec(
      id: 'docs',
      title: 'Documents',
      itemCount: ids.length,
      itemBuilder: (context, i) => SizedBox(
        key: ValueKey<String>('item_${ids[i]}'),
        child: Center(child: Text(ids[i])),
      ),
      emptyState: const Text('vide'),
      itemIds: onReorder == null ? null : ids,
      onReorder: onReorder,
      crossAxisMinItemWidth: crossAxisMinItemWidth,
      crossAxisItemHeight: 60,
      reorderMoveBeforeSemanticLabel: moveBefore,
      reorderMoveAfterSemanticLabel: moveAfter,
    );

Future<void> _pump(WidgetTester tester, ZStudyToolsSectionSpec spec,
        {double width = 700}) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: width,
            child: ZSectionedStudyLayout(sections: <ZStudyToolsSectionSpec>[spec]),
          ),
        ),
      ),
    );

Future<void> _dragCell(WidgetTester tester, String from, String to) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.text(from).first));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await gesture.moveTo(tester.getCenter(find.text(to).first));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  group('CR-IFFD-15 — grille multi-colonnes RÉORDONNABLE', () {
    testWidgets(
        'W1 : onReorder + crossAxisMinItemWidth ⇒ grille MULTI-COLONNES '
        'reordonnable (activation implicite, plus aucun assert d\'exclusivite)',
        (tester) async {
      final ids = ['a', 'b', 'c', 'd'];
      await _pump(
        tester,
        _spec(
          ids: ids,
          crossAxisMinItemWidth: 200,
          onReorder: (_, _) {},
        ),
      );

      // Aucun `assert` levé (le rendu a abouti) …
      expect(tester.takeException(), isNull);
      // … c'est bien la primitive réordonnable du socle …
      expect(find.byType(ZReorderableAdaptiveGrid), findsOneWidget);
      // … et PLUS la liste mono-colonne du SDK.
      expect(find.byType(ReorderableListView), findsNothing);
      // Multi-colonnes AVÉRÉ : a et b partagent la même ligne.
      expect(tester.getTopLeft(find.text('a')).dy,
          equals(tester.getTopLeft(find.text('b')).dy));
    });

    testWidgets(
        'W2a : NON-REGRESSION — onReorder SEUL reste une liste MONO-COLONNE',
        (tester) async {
      final ids = ['a', 'b', 'c'];
      await _pump(tester, _spec(ids: ids, onReorder: (_, _) {}));

      expect(find.byType(ReorderableListView), findsOneWidget);
      expect(find.byType(ZReorderableAdaptiveGrid), findsNothing);
      // Mono-colonne : chaque item sur sa propre ligne.
      expect(tester.getTopLeft(find.text('b')).dy,
          greaterThan(tester.getTopLeft(find.text('a')).dy));
    });

    testWidgets(
        'W2b : NON-REGRESSION — crossAxisMinItemWidth SEUL reste une '
        'ZAdaptiveGrid NON reordonnable', (tester) async {
      final ids = ['a', 'b', 'c', 'd'];
      await _pump(tester, _spec(ids: ids, crossAxisMinItemWidth: 200));

      expect(find.byType(ZAdaptiveGrid), findsOneWidget);
      expect(find.byType(ZReorderableAdaptiveGrid), findsNothing);
      expect(find.byType(ReorderableListView), findsNothing);
      expect(tester.getTopLeft(find.text('a')).dy,
          equals(tester.getTopLeft(find.text('b')).dy));
    });

    testWidgets(
        'W3 : les libelles d\'actions semantiques INJECTES priment sur le repli '
        '(a11y AD-13 — alternative obligatoire a l\'appui long)', (tester) async {
      final handle = tester.ensureSemantics();
      final ids = ['a', 'b', 'c', 'd'];
      final calls = <List<int>>[];
      await _pump(
        tester,
        _spec(
          ids: ids,
          crossAxisMinItemWidth: 200,
          onReorder: (o, n) => calls.add([o, n]),
          moveBefore: kMoveBefore,
          moveAfter: kMoveAfter,
        ),
      );

      final before = CustomSemanticsAction(label: kMoveBefore);
      final beforeId = CustomSemanticsAction.getIdentifier(before);
      final node = tester.getSemantics(find.text('b'));
      expect(node.getSemanticsData().customSemanticsActionIds,
          contains(beforeId));

      // Déclencher l'action déplace RÉELLEMENT — sans le moindre appui long.
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        beforeId,
      );
      await tester.pumpAndSettle();
      expect(calls, [
        [1, 0]
      ]);
      handle.dispose();
    });

    testWidgets(
        'W4 : un depot REEL remonte des indices en convention removeAt/insert '
        '— identiques a ceux du mode liste (symetrie zReorderIds)',
        (tester) async {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
      final calls = <List<int>>[];
      await _pump(
        tester,
        _spec(
          ids: ids,
          crossAxisMinItemWidth: 200,
          onReorder: (o, n) => calls.add([o, n]),
        ),
      );

      // 3 colonnes ⇒ `a` (pos 0, ligne 0) et `e` (pos 4, ligne 1).
      expect(tester.getTopLeft(find.text('e')).dy,
          greaterThan(tester.getTopLeft(find.text('a')).dy));

      await _dragCell(tester, 'a', 'e');

      expect(calls, [
        [0, 4]
      ]);
      // L'ordre appliqué localement est EXACTEMENT celui de `zReorderIds`.
      expect(zReorderIds(ids, 0, 4), ['b', 'c', 'd', 'e', 'a', 'f']);
    });
  });
}
