/// Tests de garde du noyau (ES-1.1, AC1) : `validatePlacement` remonté verbatim.
///
/// Reprend les invariants clés de la hiérarchie 2 niveaux (racine + 1 niveau)
/// pour prouver le portage : racine OK, enfant de racine OK, niveau 3 refusé,
/// parent introuvable refusé, auto-parent refusé.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('validatePlacement — hiérarchie 2 niveaux (AC1)', () {
    test('racine (parentId null) ⇒ Right', () {
      final r = validatePlacement(parentId: null);
      expect(r.isRight(), isTrue);
    });

    test('enfant d\'une racine ⇒ Right (niveau 2)', () {
      const root = ZStudyFolder(id: 'root', title: 'R');
      final r = validatePlacement(parentId: 'root', parent: root);
      expect(r.isRight(), isTrue);
    });

    test('sous un enfant (parent a un parent) ⇒ Left (niveau 3 refusé)', () {
      const child = ZStudyFolder(id: 'c', title: 'C', parentId: 'root');
      final r = validatePlacement(parentId: 'c', parent: child);
      expect(r.isLeft(), isTrue);
    });

    test('parent non résolu (null) ⇒ Left', () {
      final r = validatePlacement(parentId: 'ghost');
      expect(r.isLeft(), isTrue);
    });

    test('auto-parent (selfId == parentId) ⇒ Left', () {
      const parent = ZStudyFolder(id: 'x', title: 'X');
      final r =
          validatePlacement(parentId: 'x', parent: parent, selfId: 'x');
      expect(r.isLeft(), isTrue);
    });
  });
}
