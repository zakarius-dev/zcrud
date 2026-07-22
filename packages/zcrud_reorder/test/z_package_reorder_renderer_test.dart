// Tests DISCRIMINANTS du renderer adossé à `reorderable_grid_view` (AD-57).
//
// Gardes structurantes (discipline R3 — chacune prouvée MORDANTE en injectant
// la régression qu'elle prétend attraper) :
//   G1 : index LINÉAIRE inter-lignes — un dépôt sur la position k donne l'index
//        k, quelle que soit la ligne, SANS l'ajustement `ReorderableListView`.
//        Régression injectée : `newIndex = rawNewIndex > oldIndex ? rawNewIndex
//        - 1 : rawNewIndex` dans `normalizePackageReorder` ⇒ ROUGE.
//   G2 : voie NON-GESTUELLE accessible — les `CustomSemanticsAction` réordonnent
//        réellement, sans le moindre appui long (AD-13). Le paquet tiers ne les
//        offre PAS : elles sont ajoutées par ce paquet-ci.
//        Régression injectée : bloc `customSemanticsActions` retiré de `_cell`
//        ⇒ ROUGE.
//   G3 : repli AD-10 — un `onReorder` qui LÈVE restaure l'ordre affiché et
//        n'est pas propagé.
//        Régression injectée : `try/catch` retiré de `_move` ⇒ ROUGE.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_reorder/zcrud_reorder.dart';

import 'reorder_test_harness.dart';

void main() {
  // ---------------------------------------------------------------------------
  // G1 [CENTRAL] — index LINÉAIRE inter-lignes.
  // ---------------------------------------------------------------------------
  testWidgets(
      'G1 : glisser la 1re cellule sur une cellule d\'une AUTRE ligne donne '
      'l\'index LINEAIRE de cette cellule (aucun ajustement -1)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    final calls = <List<int>>[];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (o, n) => calls.add([o, n])),
    ));

    // Pré-condition : la grille est bien MULTI-COLONNES (3 colonnes).
    expect(tester.getTopLeft(find.text('a')).dy,
        equals(tester.getTopLeft(find.text('c')).dy));
    expect(tester.getTopLeft(find.text('d')).dy,
        greaterThan(tester.getTopLeft(find.text('a')).dy));

    // `a` (index 0, ligne 0) déposé sur `e` (index 4, ligne 1).
    await dragCell(tester, 'a', 'e');

    expect(calls, [
      [0, 4]
    ], reason: 'index LINEAIRES, jamais des coordonnees de grille');
    expect(visualOrder(tester, ids), ['b', 'c', 'd', 'e', 'a', 'f']);
  });

  testWidgets(
      'G1b : glisser la PREMIERE cellule sur la DERNIERE la place bien en '
      'DERNIERE position (le -1 parasite la placerait une case trop tot)',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    final calls = <List<int>>[];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (o, n) => calls.add([o, n])),
    ));

    await dragCell(tester, 'a', 'f');

    expect(calls, [
      [0, 5]
    ]);
    expect(visualOrder(tester, ids), ['b', 'c', 'd', 'e', 'f', 'a']);
  });

  testWidgets('un depot SUR PLACE ne notifie PAS l\'hote', (tester) async {
    final ids = ['a', 'b', 'c'];
    final calls = <List<int>>[];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (o, n) => calls.add([o, n])),
    ));

    await dragCell(tester, 'b', 'b');

    expect(calls, isEmpty,
        reason: 'le paquet notifie aussi les depots sur place — filtres ici');
    expect(visualOrder(tester, ids), ['a', 'b', 'c']);
  });

  // ---------------------------------------------------------------------------
  // G2 [CENTRAL] — voie NON-GESTUELLE accessible (AD-13).
  // ---------------------------------------------------------------------------
  testWidgets(
      'G2 : les actions semantiques « deplacer avant/apres » REORDONNENT '
      'reellement, sans aucun appui long', (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b', 'c'];
    final calls = <List<int>>[];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (o, n) => calls.add([o, n])),
    ));

    // La 1re cellule n'expose PAS « avant » ; la dernière PAS « après ».
    expect(customActionIds(tester, 'a'), isNot(contains(actionId(kMoveBefore))));
    expect(customActionIds(tester, 'c'), isNot(contains(actionId(kMoveAfter))));

    // La cellule du milieu expose les DEUX.
    expect(customActionIds(tester, 'b'), contains(actionId(kMoveBefore)));
    expect(customActionIds(tester, 'b'), contains(actionId(kMoveAfter)));

    performCustomAction(tester, 'b', kMoveBefore);
    await tester.pumpAndSettle();

    expect(calls, [
      [1, 0]
    ]);
    expect(visualOrder(tester, ids), ['b', 'a', 'c']);
    handle.dispose();
  });

  testWidgets(
      'G2b : les libelles sont ceux INJECTES par l\'hote ; a defaut, un repli '
      'LOCALISE (jamais une action sans nom)', (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      // Aucun libellé fourni ⇒ replis du paquet.
      request(ids: ids, onReorder: (_, _) {}, semanticLabels: false),
    ));

    expect(customActionIds(tester, 'a'),
        contains(actionId(kDefaultMoveAfterLabel)));
    handle.dispose();
  });

  testWidgets(
      'G2c : la voie semantique reste offerte meme quand le GESTE est desactive',
      (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b', 'c'];
    final calls = <List<int>>[];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(dragEnabled: false),
      request(ids: ids, onReorder: (o, n) => calls.add([o, n])),
    ));

    // Le geste ne fait plus rien...
    await dragCell(tester, 'a', 'c');
    expect(calls, isEmpty);

    // ...mais l'action sémantique, si.
    performCustomAction(tester, 'a', kMoveAfter);
    await tester.pumpAndSettle();
    expect(calls, [
      [0, 1]
    ]);
    handle.dispose();
  });

  // ---------------------------------------------------------------------------
  // G3 [CENTRAL] — repli AD-10.
  // ---------------------------------------------------------------------------
  testWidgets(
      'G3 : un onReorder qui LEVE restaure l\'ordre affiche et n\'est PAS '
      'propage (aucun crash de rendu)', (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b', 'c'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(
        ids: ids,
        onReorder: (_, _) => throw StateError('persistance KO'),
      ),
    ));

    performCustomAction(tester, 'a', kMoveAfter);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull,
        reason: 'AD-10 : l\'exception est ABSORBEE, jamais propagee');
    expect(visualOrder(tester, ids), ['a', 'b', 'c'],
        reason: 'l\'ordre affiche est RESTAURE');
    handle.dispose();
  });

  testWidgets('G3b : le repli AD-10 vaut aussi pour la voie GESTUELLE',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (_, _) => throw StateError('KO')),
    ));

    await dragCell(tester, 'a', 'e');

    expect(tester.takeException(), isNull);
    expect(visualOrder(tester, ids), ['a', 'b', 'c', 'd', 'e', 'f']);
  });

  // ---------------------------------------------------------------------------
  // Point 3 du contrat — l'appelant est la source de vérité.
  // ---------------------------------------------------------------------------
  testWidgets(
      'resync : un nouvel itemIds pousse par l\'hote ECRASE l\'ordre optimiste',
      (tester) async {
    final handle = tester.ensureSemantics();
    final ids = ['a', 'b', 'c'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (_, _) {}),
    ));

    performCustomAction(tester, 'a', kMoveAfter);
    await tester.pumpAndSettle();
    expect(visualOrder(tester, ids), ['b', 'a', 'c']);

    // L'hôte impose un ordre TOTALEMENT différent : il gagne.
    final pushed = ['c', 'b', 'a'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: pushed, onReorder: (_, _) {}),
    ));
    await tester.pumpAndSettle();
    expect(visualOrder(tester, pushed), ['c', 'b', 'a']);
    handle.dispose();
  });

  // ---------------------------------------------------------------------------
  // Géométrie de la requête + AD-13 (RTL) + AD-10 (garde vide).
  // ---------------------------------------------------------------------------
  testWidgets('AD-10 : itemIds vide ⇒ SizedBox.shrink(), jamais de throw',
      (tester) async {
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: const <String>[], onReorder: (_, _) {}),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets(
      'minItemWidth/minColumns/maxColumns pilotent REELLEMENT le nombre de '
      'colonnes', (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    // 600 / 300 = 2 colonnes.
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (_, _) {}, minItemWidth: 300),
    ));
    expect(tester.getTopLeft(find.text('c')).dy,
        greaterThan(tester.getTopLeft(find.text('a')).dy),
        reason: '2 colonnes : `c` est sur la 2e ligne');

    // maxColumns: 1 force une seule colonne malgré la largeur.
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (_, _) {}, maxColumns: 1),
    ));
    await tester.pump();
    expect(tester.getTopLeft(find.text('a')).dx,
        equals(tester.getTopLeft(find.text('b')).dx));
  });

  testWidgets('spacing/itemHeight : cellules 200x100 sans gouttiere',
      (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (_, _) {}),
    ));
    final rowGap = tester.getTopLeft(find.text('d')).dy -
        tester.getTopLeft(find.text('a')).dy;
    expect(rowGap, closeTo(100, 0.01));
  });

  testWidgets('AD-13 : en RTL les colonnes sont IDENTIQUES et l\'ordre visuel '
      'se lit de droite a gauche', (tester) async {
    final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(ids: ids, onReorder: (_, _) {}),
      dir: TextDirection.rtl,
    ));
    expect(tester.getTopLeft(find.text('a')).dx,
        greaterThan(tester.getTopLeft(find.text('c')).dx),
        reason: 'RTL : `a` est a DROITE de `c`');
    expect(visualOrder(tester, ids, rtl: true),
        ['a', 'b', 'c', 'd', 'e', 'f']);
  });

  testWidgets('padding DIRECTIONNEL accepte et applique', (tester) async {
    final ids = ['a', 'b', 'c'];
    await tester.pumpWidget(wrapRenderer(
      const ZPackageReorderRenderer(),
      request(
        ids: ids,
        onReorder: (_, _) {},
        padding: const EdgeInsetsDirectional.only(start: 40),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getTopLeft(find.text('a')).dx, greaterThanOrEqualTo(40));
  });

  // ---------------------------------------------------------------------------
  // AD-57 — confinement du tiers.
  // ---------------------------------------------------------------------------
  test('AD-57 : le renderer EST un ZReorderRenderer (type du coeur)', () {
    const ZReorderRenderer renderer = ZPackageReorderRenderer();
    expect(renderer, isA<ZReorderRenderer>());
  });
}
