// INTERCHANGEABILITÉ (AD-57, condition 3) — la promesse « dégradée, jamais
// absente » n'a de sens que si les deux implémentations du port se comportent
// PAREIL sur le contrat.
//
// Ce fichier rejoue EXACTEMENT la même séquence sur :
//   * `ZDefaultReorderRenderer` — repli zéro-dépendance (`zcrud_responsive`) ;
//   * `ZPackageReorderRenderer` — adossé à `reorderable_grid_view`.
// et exige le MÊME ordre final ET la MÊME séquence d'appels `onReorder`.
//
// L'arête `zcrud_reorder -> zcrud_responsive` est ACYCLIQUE
// (`zcrud_responsive` ne dépend que de `zcrud_core`) — vérifié par
// `scripts/dev/graph_proof.py` (ACYCLIQUE OK, CORE OUT=0 OK). C'est pourquoi la
// comparaison est faite sur le VRAI repli, et non sur une convention réécrite
// en dur qui pourrait diverger sans que rien ne rougisse.

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_reorder/zcrud_reorder.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart'
    show ZDefaultReorderRenderer;

import 'reorder_test_harness.dart';

/// Résultat observable d'une séquence : appels reçus + ordre visuel final.
typedef _Outcome = ({List<List<int>> calls, List<String> order});

/// Rejoue la séquence de référence sur [renderer] et retourne l'observable.
Future<_Outcome> _replay(
  WidgetTester tester,
  ZReorderRenderer renderer,
) async {
  final handle = tester.ensureSemantics();
  final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
  final calls = <List<int>>[];
  await tester.pumpWidget(wrapRenderer(
    renderer,
    request(ids: ids, onReorder: (o, n) => calls.add([o, n])),
  ));

  // 1) Geste : `a` (ligne 0) déposé sur `e` (ligne 1) — inter-lignes.
  await dragCell(tester, 'a', 'e');
  // 2) Voie accessible : « déplacer avant » sur la cellule qui affiche `f`.
  performCustomAction(tester, 'f', kMoveBefore);
  await tester.pumpAndSettle();
  // 3) Geste retour : `d` déposé sur `b`.
  await dragCell(tester, 'd', 'b');

  final outcome = (calls: calls, order: visualOrder(tester, ids));
  handle.dispose();
  return outcome;
}

void main() {
  late _Outcome fallback;
  late _Outcome package;

  testWidgets('sequence de reference — repli zero-dependance', (tester) async {
    fallback = await _replay(tester, const ZDefaultReorderRenderer());
    // Ancrage explicite : la séquence produit un ordre NON trivial (sinon la
    // comparaison ci-dessous serait vraie pour de mauvaises raisons).
    expect(fallback.order, isNot(['a', 'b', 'c', 'd', 'e', 'f']));
    expect(fallback.calls.length, 3);
  });

  testWidgets('sequence de reference — implementation paquet tiers',
      (tester) async {
    package = await _replay(tester, const ZPackageReorderRenderer());
    expect(package.calls.length, 3);
  });

  test('INTERCHANGEABLES : meme sequence ⇒ meme ordre final ET memes appels',
      () {
    expect(package.order, fallback.order,
        reason: 'l\'ordre final DOIT etre identique — sinon le port ne rend '
            'pas les implementations substituables (AD-57)');
    expect(package.calls, fallback.calls,
        reason: 'meme convention d\'index LINEAIRES notifiee a l\'hote');
  });
}
