/// Helpers de test a11y **réutilisables** (AI-E10-1, retro E10).
///
/// origine: la rétro E10 a acté qu'il fallait **outiller** l'a11y plutôt que de
/// re-vérifier à la main dans chaque test — deux invariants AD-13 :
///   1. **action sémantique opérable** (MEDIUM-2 E11a-2) : le nœud `Semantics`
///      englobant porte `SemanticsAction.tap` ET la déclencher via le lecteur
///      d'écran (`owner.performAction`) produit l'effet attendu ;
///   2. **cible tactile ≥ 48 dp** (AD-13).
///
/// Ces helpers sont **locaux** au package (pas de package de test partagé — hors
/// périmètre) ; le patron est documenté pour réemploi (E9/futurs widgets).
library;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vérifie que le nœud sémantique de [finder] expose `SemanticsAction.tap`
/// **opérable** et, si [expectAfterTap] est fourni, que la déclencher via le
/// lecteur d'écran satisfait cette attente (le test doit avoir armé
/// `tester.ensureSemantics()`).
///
/// Renvoie le [SemanticsNode] pour d'éventuelles assertions supplémentaires.
Future<SemanticsNode> assertSemanticActionTap(
  WidgetTester tester,
  Finder finder, {
  Future<void> Function()? expectAfterTap,
}) async {
  final node = tester.getSemantics(finder);
  expect(node, isSemantics(hasTapAction: true),
      reason: 'le nœud sémantique doit exposer SemanticsAction.tap (AD-13)');
  node.owner!.performAction(node.id, SemanticsAction.tap);
  await tester.pump();
  if (expectAfterTap != null) await expectAfterTap();
  return node;
}

/// Vérifie que la cible tactile de [finder] mesure au moins [min] dp de haut
/// (défaut 48, AD-13). Utilise la taille rendue réelle.
void assertMinTapTarget(
  WidgetTester tester,
  Finder finder, [
  double min = 48,
]) {
  final size = tester.getSize(finder);
  expect(size.height, greaterThanOrEqualTo(min),
      reason: 'cible tactile < $min dp (AD-13) : ${size.height}');
}
