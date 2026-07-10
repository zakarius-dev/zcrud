/// Dérivation de la forêt `ZMindmap` vers la structure `graphite` (Story E10-2).
///
/// **Lecture seule** : la topologie par NESTING (`children`) est projetée à la
/// volée en liste plate de `NodeInput`/`EdgeInput` (adjacency `parent.id →
/// child.id`) — ce n'est PAS le modèle de stockage (canonique §2.2).
///
/// **Multi-racine (choix documenté)** : `graphite` sélectionne comme point
/// d'entrée « le premier nœud sans income ». Une forêt à ≥ 2 racines aurait donc
/// plusieurs points d'entrée → rendu non déterministe. On rattache alors toutes
/// les racines à une **RACINE VIRTUELLE unique non affichée** ([virtualRootId]),
/// reliée par des arêtes **sans flèche** (`EdgeArrowType.none`). Cette racine
/// virtuelle est **exclue du rendu** (son `nodeBuilder` retourne un widget de
/// taille nulle) et **de la sémantique** (le graphe entier est `ExcludeSemantics`
/// et la vue liste itère la forêt RÉELLE, jamais la racine virtuelle). Pour une
/// forêt mono-racine, aucune racine virtuelle n'est ajoutée (cas propre).
library;

import 'package:graphite/graphite.dart';

import '../domain/z_mindmap_node.dart';

/// Résultat de la projection d'une forêt vers `graphite`.
class ZMindmapGraphData {
  /// Construit le résultat immuable.
  const ZMindmapGraphData({
    required this.nodes,
    required this.usesVirtualRoot,
  });

  /// Liste plate de `NodeInput` (nœuds + arêtes), prête pour `DirectGraph.list`.
  final List<NodeInput> nodes;

  /// `true` si une racine virtuelle a été insérée (forêt multi-racine).
  final bool usesVirtualRoot;
}

/// Projette une forêt `ZMindmapNode` vers `graphite` (fonctions pures).
abstract final class ZMindmapGraphMapper {
  const ZMindmapGraphMapper._();

  /// Identifiant sentinelle de la racine virtuelle (multi-racine). Préfixe/suffixe
  /// improbables pour éviter toute collision avec un `id` réel (opaque `String`).
  static const String virtualRootId = '__zcrud_mindmap_virtual_root__';

  /// Construit la liste plate `NodeInput` depuis les [roots] d'une forêt.
  ///
  /// - forêt vide → liste vide, `usesVirtualRoot = false` (l'appelant affiche
  ///   l'état vide sans instancier `DirectGraph`) ;
  /// - forêt mono-racine → nœuds réels seuls ;
  /// - forêt multi-racine → racine virtuelle + nœuds réels.
  static ZMindmapGraphData fromForest(List<ZMindmapNode> roots) {
    final out = <NodeInput>[];
    for (final root in roots) {
      _appendSubtree(root, out);
    }

    final usesVirtualRoot = roots.length > 1;
    if (usesVirtualRoot) {
      out.insert(
        0,
        NodeInput(
          id: virtualRootId,
          // Arêtes sans flèche : la racine virtuelle n'est pas affichée.
          next: <EdgeInput>[
            for (final root in roots)
              EdgeInput(outcome: root.id, type: EdgeArrowType.none),
          ],
        ),
      );
    }
    return ZMindmapGraphData(nodes: out, usesVirtualRoot: usesVirtualRoot);
  }

  /// Aplatit récursivement un sous-arbre en `NodeInput` (arêtes vers enfants).
  static void _appendSubtree(ZMindmapNode node, List<NodeInput> out) {
    out.add(
      NodeInput(
        id: node.id,
        next: <EdgeInput>[
          for (final child in node.children) EdgeInput(outcome: child.id),
        ],
      ),
    );
    for (final child in node.children) {
      _appendSubtree(child, out);
    }
  }
}
