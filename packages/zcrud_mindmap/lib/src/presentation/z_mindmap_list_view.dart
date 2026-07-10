/// Vue liste sémantique indentée = **surface a11y de référence** (Story E10-2).
///
/// Parcours **profondeur-d'abord** de la forêt, **une entrée par nœud**,
/// **indentation dérivée de `level`** via `EdgeInsetsDirectional.only(start:)`
/// (RTL-safe, AD-13 — JAMAIS `left:`), rendu par **`ListView.builder`**
/// (jamais `ListView(children:)`). Chaque entrée porte un `Semantics` explicite
/// (label = `ZMindmapNode.label`, profondeur, état sélectionné) et une cible
/// tactile ≥ 48 dp. Le `nodeContentBuilder` injecté est appliqué **à
/// l'identique** que dans le graphe (équivalence graphe ⇄ liste).
///
/// **Lecture seule** (AD-2/AD-15) : aucune mutation d'arbre ; le tap est remonté
/// par callback. État de sélection porté par un `ValueListenable<String?>`
/// (rebuild ciblé, aucun gestionnaire d'état).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/z_mindmap_node.dart';
import 'z_mindmap_node_card.dart';
import 'z_mindmap_view_config.dart';

/// Vue liste sémantique d'une forêt `ZMindmapNode` (surface a11y de référence).
class ZMindmapListView extends StatelessWidget {
  /// Construit la vue liste.
  const ZMindmapListView({
    required this.roots,
    required this.contentBuilder,
    required this.selectedListenable,
    this.config = const ZMindmapViewConfig(),
    this.onNodeTap,
    this.emptyLabel,
    this.padding,
    super.key,
  });

  /// Racines de la forêt (lues telles quelles ; `level` déjà cohérent E10-1).
  final List<ZMindmapNode> roots;

  /// Constructeur de contenu injecté (identique au graphe).
  final ZMindmapNodeContentBuilder contentBuilder;

  /// Tranche d'état « id sélectionné » (rebuild ciblé).
  final ValueListenable<String?> selectedListenable;

  /// Configuration de layout (pas d'indentation, cible tactile…).
  final ZMindmapViewConfig config;

  /// Remontée du tap sur une entrée (aucune mutation d'arbre).
  final ZMindmapNodeCallback? onNodeTap;

  /// Libellé **externalisé** de l'état vide (repli neutre : aucun affichage).
  final String? emptyLabel;

  /// Marge externe optionnelle de la liste (directionnelle recommandée).
  final EdgeInsetsGeometry? padding;

  /// Aplatit la forêt en profondeur-d'abord (une entrée par nœud, ordre stable).
  static List<ZMindmapNode> _flatten(List<ZMindmapNode> roots) {
    final out = <ZMindmapNode>[];
    void visit(ZMindmapNode node) {
      out.add(node);
      for (final child in node.children) {
        visit(child);
      }
    }

    for (final root in roots) {
      visit(root);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _flatten(roots);

    if (entries.isEmpty) {
      // État vide accessible : repli neutre si aucun libellé injecté.
      if (emptyLabel == null) return const SizedBox.expand();
      return Center(
        child: Semantics(
          label: emptyLabel,
          child: Text(emptyLabel!, textAlign: TextAlign.start),
        ),
      );
    }

    return ListView.builder(
      padding: padding,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final node = entries[index];
        final indent = node.level * config.indentStep;
        // Label a11y = même repli que le contenu par défaut (L3) : un nœud
        // « content-only » (label vide) annonce quand même un texte utile.
        final semLabel =
            node.label.isNotEmpty ? node.label : (node.content ?? '');

        // POINT D'ÉCOUTE UNIQUE de la ligne (M1) : la carte reçoit `isSelected`
        // résolu ; elle ne s'abonne plus elle-même.
        return ValueListenableBuilder<String?>(
          valueListenable: selectedListenable,
          builder: (context, selectedId, _) {
            final isSelected = selectedId == node.id;
            return Semantics(
              key: ValueKey<String>('zmindmap-list-sem-${node.id}'),
              container: true,
              selected: isSelected,
              label: semLabel,
              // Profondeur annoncée pour l'équivalence structurelle graphe⇄liste.
              hint: 'niveau ${node.level + 1}',
              button: onNodeTap != null,
              // ACTION SÉMANTIQUE d'activation (H1) : le lecteur d'écran peut
              // activer l'entrée (double-tap) — le GestureDetector de la carte
              // est sous ExcludeSemantics et ne suffit donc pas à lui seul.
              onTap: onNodeTap != null ? () => onNodeTap!(node) : null,
              child: Padding(
                key: ValueKey<String>('zmindmap-list-${node.id}'),
                padding: EdgeInsetsDirectional.only(
                  start: indent,
                  top: config.indentStep / 8,
                  bottom: config.indentStep / 8,
                ),
                child: ExcludeSemantics(
                  // La sémantique est déjà portée par le Semantics parent ;
                  // on évite le doublon label émis par la carte de contenu.
                  child: ZMindmapNodeCard(
                    node: node,
                    contentBuilder: contentBuilder,
                    isSelected: isSelected,
                    config: config,
                    onTap: onNodeTap,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
