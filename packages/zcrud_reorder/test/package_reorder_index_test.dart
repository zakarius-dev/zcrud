// Tests PURS de la normalisation d'index du paquet tiers → convention du port.
//
// Garde structurante R3 :
//   G1 : la convention `reorderable_grid_view` est DÉJÀ ajustée
//        (`removeAt`/`insert`). Ré-appliquer l'ajustement `ReorderableListView`
//        (`if (newIndex > oldIndex) newIndex -= 1`) est le bug silencieux que
//        ce test doit attraper.
//        Régression injectée dans `normalizePackageReorder` :
//        `final newIndex = rawNewIndex > oldIndex ? rawNewIndex - 1 : rawNewIndex;`
//        ⇒ ROUGE (prouvé).

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_reorder/src/presentation/package_reorder_index.dart';

void main() {
  group('normalizePackageReorder — convention LINÉAIRE', () {
    test(
        'G1 : un deplacement VERS L\'AVANT garde l\'index brut (aucun -1 : ce '
        'serait la convention ReorderableListView, pas celle du paquet)', () {
      // [a,b,c] : glisser `a` sur la case de `c` ⇒ removeAt(0) + insert(2)
      // ⇒ [b,c,a]. Avec un `-1` parasite on obtiendrait insert(1) ⇒ [b,a,c].
      final move = normalizePackageReorder(
        rawOldIndex: 0,
        rawNewIndex: 2,
        length: 3,
      );
      expect(move, isNotNull);
      expect(move!.oldIndex, 0);
      expect(move.newIndex, 2);
      expect(applyLinearMove(['a', 'b', 'c'], move.oldIndex, move.newIndex),
          <String>['b', 'c', 'a']);
    });

    test('un deplacement VERS L\'ARRIERE est inchange lui aussi', () {
      final move = normalizePackageReorder(
        rawOldIndex: 2,
        rawNewIndex: 0,
        length: 3,
      );
      expect((move!.oldIndex, move.newIndex), (2, 0));
      expect(applyLinearMove(['a', 'b', 'c'], 2, 0), <String>['c', 'a', 'b']);
    });

    test(
        'dernier index atteignable : glisser le PREMIER sur le DERNIER le place '
        'bien en fin (regression -1 = une case trop tot)', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f'];
      final move = normalizePackageReorder(
        rawOldIndex: 0,
        rawNewIndex: 5,
        length: 6,
      );
      expect(applyLinearMove(ids, move!.oldIndex, move.newIndex).last, 'a');
    });

    test('depot SUR PLACE ⇒ null (le paquet notifie aussi les no-op)', () {
      expect(
        normalizePackageReorder(rawOldIndex: 2, rawNewIndex: 2, length: 5),
        isNull,
      );
    });

    test('AD-10 : liste vide ⇒ null, jamais de throw', () {
      expect(
        normalizePackageReorder(rawOldIndex: 0, rawNewIndex: 1, length: 0),
        isNull,
      );
      expect(
        normalizePackageReorder(rawOldIndex: 3, rawNewIndex: -2, length: -1),
        isNull,
      );
    });

    test('AD-10 : index hors bornes CLAMPES, jamais propages', () {
      final move =
          normalizePackageReorder(rawOldIndex: 99, rawNewIndex: -7, length: 4);
      expect((move!.oldIndex, move.newIndex), (3, 0));
    });
  });

  group('applyLinearMove — transformation de reference', () {
    test('removeAt(from) puis insert(to), sans muter la source', () {
      final source = ['a', 'b', 'c', 'd'];
      expect(applyLinearMove(source, 1, 3), <String>['a', 'c', 'd', 'b']);
      expect(source, <String>['a', 'b', 'c', 'd']);
    });

    test('AD-10 : liste vide / indices absurdes ⇒ jamais de throw', () {
      expect(applyLinearMove(const <String>[], 4, 9), isEmpty);
      expect(applyLinearMove(['a', 'b'], -5, 99), <String>['b', 'a']);
    });
  });

  group('listOrderEquals', () {
    test('sensible a l\'ORDRE, pas seulement au contenu', () {
      expect(listOrderEquals(['a', 'b'], ['a', 'b']), isTrue);
      expect(listOrderEquals(['a', 'b'], ['b', 'a']), isFalse);
      expect(listOrderEquals(['a'], ['a', 'b']), isFalse);
    });
  });
}
