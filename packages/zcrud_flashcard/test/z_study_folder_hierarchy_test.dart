/// Tests E9-3 : primitive PURE `validatePlacement` (AC9, AD-5/AD-11/AD-14).
///
/// Couvre la sémantique EXACTE de l'invariant « 2 niveaux max » (racine OK ;
/// enfant de racine niveau 2 OK ; petit-enfant niveau 3 rejeté ; auto-parent
/// rejeté ; parent manquant rejeté). Vérifie aussi que l'entité `ZStudyFolder`
/// ne porte AUCUN contrôle de profondeur (AD-14).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  group('validatePlacement — 2 niveaux max (AC9)', () {
    test('racine (parentId null) ⇒ Right(unit)', () {
      final r = validatePlacement(parentId: null, selfId: 'a');
      expect(r.isRight(), isTrue);
      expect(r.getOrElse(() => throw StateError('left')), unit);
    });

    test('enfant d\'une racine (niveau 2) ⇒ Right(unit)', () {
      const parent = ZStudyFolder(id: 'p', title: 'racine'); // parentId null
      final r = validatePlacement(parentId: 'p', parent: parent, selfId: 'c');
      expect(r.isRight(), isTrue);
    });

    test('petit-enfant (niveau 3) ⇒ Left(DomainFailure), sans écrire', () {
      const parent =
          ZStudyFolder(id: 'p', title: 'sous-dossier', parentId: 'grand');
      final r = validatePlacement(parentId: 'p', parent: parent, selfId: 'c');
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f, isA<DomainFailure>()),
        (_) => fail('attendu Left'),
      );
    });

    test('auto-parent (parentId == selfId) ⇒ Left(DomainFailure)', () {
      const parent = ZStudyFolder(id: 'x', title: 'r');
      final r = validatePlacement(parentId: 'x', parent: parent, selfId: 'x');
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f, isA<DomainFailure>()),
        (_) => fail('attendu Left'),
      );
    });

    test('parent manquant (parentId non null, parent null) ⇒ Left', () {
      final r = validatePlacement(parentId: 'p', parent: null, selfId: 'c');
      expect(r.isLeft(), isTrue);
      r.fold(
        (f) => expect(f, isA<DomainFailure>()),
        (_) => fail('attendu Left'),
      );
    });

    test('auto-parent prime même si le parent est une racine', () {
      // parentId == selfId doit échouer avant toute autre considération.
      const parent = ZStudyFolder(id: 'x', title: 'r');
      expect(
        validatePlacement(parentId: 'x', parent: parent, selfId: 'x').isLeft(),
        isTrue,
      );
    });

    test('selfId null n\'active pas la garde auto-parent', () {
      const parent = ZStudyFolder(id: 'p', title: 'r');
      final r = validatePlacement(parentId: 'p', parent: parent);
      expect(r.isRight(), isTrue);
    });
  });

  group('AD-14 — l\'entité ne s\'auto-valide jamais', () {
    test('construire un dossier niveau 3 ne throw pas (invariant au repo)', () {
      // L'entité accepte n'importe quel parentId : c'est le repo (via
      // validatePlacement) qui refuse — jamais le constructeur.
      expect(
        () => const ZStudyFolder(id: 'gc', title: 't', parentId: 'child'),
        returnsNormally,
      );
    });
  });
}
