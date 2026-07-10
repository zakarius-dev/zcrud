import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

/// Construit une forêt de test :
///   A(0)
///   ├─ B(1)
///   │  └─ D(2)
///   │     └─ F(3)
///   └─ C(1)
///   G(0)
List<ZMindmapNode> _forest() => [
      ZMindmapNode(id: 'A', label: 'A', level: 0, children: [
        ZMindmapNode(id: 'B', label: 'B', level: 1, children: [
          ZMindmapNode(id: 'D', label: 'D', level: 2, children: [
            ZMindmapNode(id: 'F', label: 'F', level: 3),
          ]),
        ]),
        ZMindmapNode(id: 'C', label: 'C', level: 1),
      ]),
      ZMindmapNode(id: 'G', label: 'G', level: 0),
    ];

ZMindmapNode _get(List<ZMindmapNode> roots, String id) =>
    ZMindmapTreeOps.findNode(roots, id)!;

void main() {
  group('findNode + fabriques (AC4)', () {
    test('recherche profonde et introuvable', () {
      final f = _forest();
      expect(ZMindmapTreeOps.findNode(f, 'F')!.id, 'F');
      expect(ZMindmapTreeOps.findNode(f, 'ZZZ'), isNull);
    });

    test('newRootNode / newChildNode : level + id uniques', () {
      final root = ZMindmapTreeOps.newRootNode();
      final child = ZMindmapTreeOps.newChildNode(2);
      expect(root.level, 0);
      expect(child.level, 3);
      expect(root.id, isNotEmpty);
      expect(root.id, isNot(child.id));
      // Forme UUID v4 (36 chars, version 4).
      expect(root.id.length, 36);
      expect(root.id[14], '4');
    });
  });

  group('updateNode (AC4)', () {
    test('label mis à jour, structural sharing du reste', () {
      final f = _forest();
      final out = ZMindmapTreeOps.updateNode(f, 'D', label: 'D2');
      expect(_get(out, 'D').label, 'D2');
      expect(_get(out, 'F').label, 'F');
      // Sous-arbre non touché G reste identical.
      expect(identical(out[1], f[1]), isTrue);
      // C (frère de B) intact → identical.
      expect(identical(_get(out, 'C'), _get(f, 'C')), isTrue);
    });

    test("content '' efface, content null = non touché", () {
      final f = [ZMindmapNode(id: 'n', content: 'hello')];
      final cleared = ZMindmapTreeOps.updateNode(f, 'n', content: '');
      expect(_get(cleared, 'n').content, '');
      final untouched = ZMindmapTreeOps.updateNode(f, 'n', label: 'x');
      expect(_get(untouched, 'n').content, 'hello');
    });

    test('no-op identical si introuvable ou aucun champ', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.updateNode(f, 'ZZZ', label: 'x'), f),
          isTrue);
      expect(identical(ZMindmapTreeOps.updateNode(f, 'A'), f), isTrue);
    });
  });

  group('addChild + level (AC4/AC5)', () {
    test('enfant ajouté à parent.level+1 avec cascade', () {
      final f = _forest();
      final sub = ZMindmapNode(id: 'X', level: 999, children: [
        ZMindmapNode(id: 'Y', level: 999),
      ]);
      final out = ZMindmapTreeOps.addChild(f, 'C', sub); // C au level 1
      expect(_get(out, 'X').level, 2);
      expect(_get(out, 'Y').level, 3);
      // Branche G intacte.
      expect(identical(out[1], f[1]), isTrue);
    });

    test('no-op identical si parent introuvable', () {
      final f = _forest();
      final out =
          ZMindmapTreeOps.addChild(f, 'NOPE', ZMindmapNode(id: 'X'));
      expect(identical(out, f), isTrue);
    });
  });

  group('deleteNode (AC4)', () {
    test('supprime un nœud interne et tout son sous-arbre', () {
      final f = _forest();
      final out = ZMindmapTreeOps.deleteNode(f, 'B');
      expect(ZMindmapTreeOps.findNode(out, 'B'), isNull);
      expect(ZMindmapTreeOps.findNode(out, 'D'), isNull);
      expect(ZMindmapTreeOps.findNode(out, 'F'), isNull);
      expect(ZMindmapTreeOps.findNode(out, 'C'), isNotNull);
      // G intact.
      expect(identical(out[1], f[1]), isTrue);
    });

    test('no-op identical si introuvable', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.deleteNode(f, 'ZZ'), f), isTrue);
    });
  });

  group('moveNode + recalcul level (AC5)', () {
    test('reparente vers un autre sous-arbre, level recalculé en cascade', () {
      final f = _forest();
      // Déplace B (avec D, F) sous G.
      final out = ZMindmapTreeOps.moveNode(f, 'B', 'G');
      expect(_get(out, 'G').children.map((n) => n.id), contains('B'));
      expect(_get(out, 'B').level, 1); // G level 0 → B level 1
      expect(_get(out, 'D').level, 2);
      expect(_get(out, 'F').level, 3);
      // B retiré de A.
      expect(_get(out, 'A').children.map((n) => n.id), isNot(contains('B')));
    });

    test('déplacement vers la racine → level 0, cascade', () {
      final f = _forest();
      final out = ZMindmapTreeOps.moveNode(f, 'D', null);
      expect(_get(out, 'D').level, 0);
      expect(_get(out, 'F').level, 1);
      expect(out.map((n) => n.id), contains('D'));
    });

    test('index insère à la bonne position (clamp si hors bornes)', () {
      final f = _forest();
      final atFront = ZMindmapTreeOps.moveNode(f, 'G', 'A', index: 0);
      expect(_get(atFront, 'A').children.first.id, 'G');
      final clamped = ZMindmapTreeOps.moveNode(f, 'G', 'A', index: 999);
      expect(_get(clamped, 'A').children.last.id, 'G');
    });

    test('ANTI-CYCLE : move vers soi-même → no-op identical', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.moveNode(f, 'B', 'B'), f), isTrue);
    });

    test('ANTI-CYCLE : move vers un descendant → no-op identical', () {
      final f = _forest();
      // D et F sont descendants de B.
      expect(identical(ZMindmapTreeOps.moveNode(f, 'B', 'D'), f), isTrue);
      expect(identical(ZMindmapTreeOps.moveNode(f, 'B', 'F'), f), isTrue);
    });

    test('no-op identical si nœud ou nouveau parent introuvable', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.moveNode(f, 'ZZ', 'A'), f), isTrue);
      expect(identical(ZMindmapTreeOps.moveNode(f, 'A', 'ZZ'), f), isTrue);
    });

    test('no-op identical si même parent et même position', () {
      final f = _forest();
      // C est déjà le 2e (index 1) enfant de A.
      expect(identical(ZMindmapTreeOps.moveNode(f, 'C', 'A', index: 1), f),
          isTrue);
      // append == rester en dernière position pour C.
      expect(identical(ZMindmapTreeOps.moveNode(f, 'C', 'A'), f), isTrue);
      // Racine G déjà en dernière position racine.
      expect(identical(ZMindmapTreeOps.moveNode(f, 'G', null), f), isTrue);
    });
  });

  group('indentNode + level (AC5)', () {
    test('rattache comme dernier enfant du frère précédent, +1 cascade', () {
      final f = _forest();
      // C (index 1 sous A) → dernier enfant de B (son frère précédent).
      final out = ZMindmapTreeOps.indentNode(f, 'C');
      expect(_get(out, 'B').children.map((n) => n.id), contains('C'));
      expect(_get(out, 'C').level, 2); // B level 1 → C level 2
      expect(_get(out, 'A').children.map((n) => n.id), isNot(contains('C')));
    });

    test('no-op identical si premier de la fratrie', () {
      final f = _forest();
      // B est le premier enfant de A ; A est la première racine.
      expect(identical(ZMindmapTreeOps.indentNode(f, 'B'), f), isTrue);
      expect(identical(ZMindmapTreeOps.indentNode(f, 'A'), f), isTrue);
    });

    test('no-op identical si introuvable', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.indentNode(f, 'ZZ'), f), isTrue);
    });
  });

  group('outdentNode + level (AC5)', () {
    test('rattache comme frère suivant du parent, -1 cascade', () {
      final f = _forest();
      // F (level 3, enfant de D) → frère suivant de D sous B.
      final out = ZMindmapTreeOps.outdentNode(f, 'F');
      final b = _get(out, 'B');
      expect(b.children.map((n) => n.id), containsAllInOrder(['D', 'F']));
      expect(_get(out, 'F').level, 2); // B level 1 → F level 2
      expect(_get(out, 'D').children.map((n) => n.id), isNot(contains('F')));
    });

    test('outdent d une profondeur ≥3 recalcule tout le sous-arbre', () {
      final f = [
        ZMindmapNode(id: 'r', level: 0, children: [
          ZMindmapNode(id: 'p', level: 1, children: [
            ZMindmapNode(id: 'n', level: 2, children: [
              ZMindmapNode(id: 'x', level: 3, children: [
                ZMindmapNode(id: 'y', level: 4),
              ]),
            ]),
          ]),
        ]),
      ];
      // n (level 2) outdent → frère suivant de p sous r (level 0) → level 1.
      final out = ZMindmapTreeOps.outdentNode(f, 'n');
      expect(_get(out, 'n').level, 1);
      expect(_get(out, 'x').level, 2);
      expect(_get(out, 'y').level, 3);
      expect(_get(out, 'r').children.map((e) => e.id),
          containsAllInOrder(['p', 'n']));
    });

    test('no-op identical si racine', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.outdentNode(f, 'A'), f), isTrue);
      expect(identical(ZMindmapTreeOps.outdentNode(f, 'G'), f), isTrue);
    });

    test('no-op identical si introuvable', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.outdentNode(f, 'ZZ'), f), isTrue);
    });
  });

  group('reorderChild — level inchangé (AC5)', () {
    test('réordonne une fratrie', () {
      final f = _forest();
      // Enfants de A : [B, C] → [C, B].
      final out = ZMindmapTreeOps.reorderChild(f, 'A', 0, 1);
      expect(_get(out, 'A').children.map((n) => n.id), ['C', 'B']);
      // Levels inchangés.
      expect(_get(out, 'B').level, 1);
      expect(_get(out, 'C').level, 1);
    });

    test('réordonne les racines (parentId null)', () {
      final f = _forest();
      final out = ZMindmapTreeOps.reorderChild(f, null, 0, 1);
      expect(out.map((n) => n.id), ['G', 'A']);
    });

    test('no-op identical si indices égaux, hors bornes, ou parent absent', () {
      final f = _forest();
      expect(identical(ZMindmapTreeOps.reorderChild(f, 'A', 0, 0), f), isTrue);
      expect(identical(ZMindmapTreeOps.reorderChild(f, 'A', 9, 0), f), isTrue);
      expect(
          identical(ZMindmapTreeOps.reorderChild(f, 'ZZ', 0, 1), f), isTrue);
    });
  });

  group('Structural sharing global (AC4/AC5)', () {
    test('une op ciblée préserve identical des branches intactes', () {
      final f = _forest();
      final out = ZMindmapTreeOps.updateNode(f, 'F', label: 'F!');
      // Toute la branche G (racine 2) inchangée.
      expect(identical(out[1], f[1]), isTrue);
      // A rebuild (contient F) mais son frère C intact.
      expect(identical(_get(out, 'C'), _get(f, 'C')), isTrue);
    });

    test('la forêt renvoyée par une op réelle n est PAS identical à l entrée',
        () {
      final f = _forest();
      final out = ZMindmapTreeOps.moveNode(f, 'B', 'G');
      expect(identical(out, f), isFalse);
    });
  });

  group('normalizeLevels', () {
    test('recompute racines→0 cascade, identical si déjà cohérent', () {
      final coherent = _forest();
      expect(identical(ZMindmapTreeOps.normalizeLevels(coherent), coherent),
          isTrue);
      final broken = [
        ZMindmapNode(id: 'r', level: 5, children: [
          ZMindmapNode(id: 'c', level: 9),
        ]),
      ];
      final fixed = ZMindmapTreeOps.normalizeLevels(broken);
      expect(_get(fixed, 'r').level, 0);
      expect(_get(fixed, 'c').level, 1);
    });
  });
}
