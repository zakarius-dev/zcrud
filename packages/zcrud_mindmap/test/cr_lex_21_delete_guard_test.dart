// CR-LEX-21 — `deleteNode` supprime un SOUS-ARBRE ENTIER, racine comprise, sans
// confirmation possible : une forêt à une seule racine devenait VIDE en un
// geste, et rien ne permettait d'intercepter.
//
// Deux leviers, tous deux NON CASSANTS (défauts = comportement historique) :
// un plancher structurel (`minRoots`) et une confirmation asynchrone
// (`onConfirmDelete`) — plus `subtreeSize` pour annoncer l'ampleur AVANT.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

Widget _app(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(body: child),
      ),
    );

/// Forêt : une racine avec deux enfants, dont l'un a lui-même un enfant.
List<ZMindmapNode> _foret() => <ZMindmapNode>[
      ZMindmapNode(
        id: 'r1',
        label: 'Racine',
        children: <ZMindmapNode>[
          ZMindmapNode(
            id: 'a',
            label: 'A',
            children: <ZMindmapNode>[ZMindmapNode(id: 'a1', label: 'A1')],
          ),
          ZMindmapNode(id: 'b', label: 'B'),
        ],
      ),
    ];

void main() {
  group('🔴 CR-LEX-21 — `minRoots` rend la forêt vide inatteignable', () {
    test('sans minRoots (défaut 0), le comportement est INCHANGÉ', () {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);
      c.deleteNode('r1');
      expect(c.forest, isEmpty,
          reason: 'défaut non cassant : la forêt peut encore se vider');
    });

    test('🔴 `minRoots: 1` REFUSE la suppression de la dernière racine', () {
      final c = ZMindmapOutlineController(initialForest: _foret(), minRoots: 1);
      addTearDown(c.dispose);
      c.deleteNode('r1');
      expect(c.forest, hasLength(1),
          reason: 'la forêt ne doit pas pouvoir devenir vide par accident');
    });

    test('`minRoots` ne bloque PAS la suppression d\'un nœud interne', () {
      final c = ZMindmapOutlineController(initialForest: _foret(), minRoots: 1);
      addTearDown(c.dispose);
      c.deleteNode('a');
      expect(c.forest.first.children, hasLength(1),
          reason: 'le plancher porte sur les RACINES, pas sur les branches');
    });

    test('avec DEUX racines et `minRoots: 1`, on peut en retirer une', () {
      final c = ZMindmapOutlineController(
        initialForest: <ZMindmapNode>[
          ..._foret(),
          ZMindmapNode(id: 'r2', label: 'Seconde'),
        ],
        minRoots: 1,
      );
      addTearDown(c.dispose);
      c.deleteNode('r2');
      expect(c.forest, hasLength(1));
    });
  });

  group('🔴 `subtreeSize` annonce l\'ampleur AVANT de supprimer', () {
    test('compte la racine du sous-arbre ET tous ses descendants', () {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);
      expect(c.subtreeSize('a'), 2, reason: 'a + a1');
      expect(c.subtreeSize('r1'), 4, reason: 'r1 + a + a1 + b');
      expect(c.subtreeSize('b'), 1);
    });

    test('un `id` introuvable rend 0, jamais une exception', () {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);
      expect(c.subtreeSize('inexistant'), 0);
    });
  });

  group('🔴 `onConfirmDelete` intercepte la suppression', () {
    testWidgets('un refus ANNULE la suppression', (tester) async {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);
      var demande = 0;

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(
        controller: c,
        onConfirmDelete: (node) async {
          demande++;
          return false; // l'utilisateur annule
        },
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();

      expect(demande, 1, reason: 'le hook doit être consulté');
      expect(c.forest, hasLength(1),
          reason: 'un refus ne doit RIEN supprimer');
      expect(c.subtreeSize('r1'), 4, reason: 'le sous-arbre est intact');
    });

    testWidgets('une acceptation supprime bien', (tester) async {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(
        controller: c,
        onConfirmDelete: (node) async => true,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(c.forest, isEmpty);
    });

    testWidgets('SANS hook, la suppression reste immédiate (non cassant)',
        (tester) async {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(controller: c)));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(c.forest, isEmpty,
          reason: 'défaut inchangé : aucun hôte existant n\'est affecté');
    });

    testWidgets('le hook reçoit le nœud VISÉ', (tester) async {
      final c = ZMindmapOutlineController(initialForest: _foret());
      addTearDown(c.dispose);
      String? vu;

      await tester.pumpWidget(_app(ZMindmapOutlineEditor(
        controller: c,
        onConfirmDelete: (node) async {
          vu = node.id;
          return false;
        },
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(vu, 'r1');
    });
  });
}
