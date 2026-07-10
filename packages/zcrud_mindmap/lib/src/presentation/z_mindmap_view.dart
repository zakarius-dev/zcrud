/// `ZMindmapView` — vue d'une forêt `ZMindmap` (Story E10-2, FR-19, AD-13).
///
/// Deux surfaces **équivalentes** partageant le même `nodeContentBuilder` :
/// - **graphe** auto-agencé `graphite` (`DirectGraph`, orientation descendante),
///   zoom/pan bornés via l'`InteractiveViewer` interne de `graphite`, **AUCUN
///   drag libre** de nœud ; enveloppé d'`ExcludeSemantics` (surface VISUELLE) ;
/// - **liste** sémantique indentée par `level` ([ZMindmapListView]) = **surface
///   a11y de référence** (AD-13).
///
/// **Lecture seule** (AD-2/AD-15) : la vue est pilotée par la donnée immuable
/// passée en entrée ; toute interaction (tap/sélection) est **remontée par
/// callback**, jamais une mutation d'arbre. **AUCUN** gestionnaire d'état tiers,
/// `WidgetRef`/`Get.find`/`Provider.of` : l'état de vue local (sélection, mode)
/// vit dans des `ValueNotifier` pur-Flutter + `ValueListenableBuilder` (rebuild
/// ciblé). **FR-26** : toutes les couleurs viennent de `ZcrudTheme`.
library;

import 'package:flutter/material.dart';
import 'package:graphite/graphite.dart';

import '../domain/z_mindmap.dart';
import '../domain/z_mindmap_node.dart';
import 'z_mindmap_graph_mapper.dart';
import 'z_mindmap_list_view.dart';
import 'z_mindmap_node_card.dart';
import 'z_mindmap_view_config.dart';

/// Vue lecture d'une carte mentale : graphe auto-agencé + liste a11y équivalente.
class ZMindmapView extends StatefulWidget {
  /// Construit la vue à partir d'une [mindmap] immuable, OU directement de [roots]
  /// (racines de la forêt). [mindmap] a priorité si fournie.
  const ZMindmapView({
    this.mindmap,
    this.roots,
    this.mode = ZMindmapViewMode.graph,
    this.nodeContentBuilder,
    this.config = const ZMindmapViewConfig(),
    this.onNodeTap,
    this.onNodeSelected,
    this.emptyLabel,
    super.key,
  }) : assert(mindmap != null || roots != null,
            'Fournir `mindmap` ou `roots`.');

  /// Carte mentale immuable (forêt titrée). Prioritaire sur [roots].
  final ZMindmap? mindmap;

  /// Racines de la forêt (alternative à [mindmap]).
  final List<ZMindmapNode>? roots;

  /// Mode initial (graphe par défaut).
  final ZMindmapViewMode mode;

  /// Constructeur de contenu injecté (défaut sûr : `label` texte brut thématisé).
  final ZMindmapNodeContentBuilder? nodeContentBuilder;

  /// Configuration de layout structurel (bornes de zoom, indentation, cible).
  final ZMindmapViewConfig config;

  /// Remontée du tap sur un nœud (aucune mutation d'arbre).
  final ZMindmapNodeCallback? onNodeTap;

  /// Notifié quand la sélection interne change (id sélectionné → nœud).
  final ZMindmapNodeCallback? onNodeSelected;

  /// Libellé **externalisé** de l'état vide (repli neutre si `null`).
  final String? emptyLabel;

  @override
  State<ZMindmapView> createState() => _ZMindmapViewState();
}

class _ZMindmapViewState extends State<ZMindmapView> {
  /// Id du nœud sélectionné (tranche d'état locale, rebuild ciblé).
  late final ValueNotifier<String?> _selected = ValueNotifier<String?>(null);

  /// Mode d'affichage courant (graphe ⇄ liste), piloté localement.
  late final ValueNotifier<ZMindmapViewMode> _mode =
      ValueNotifier<ZMindmapViewMode>(widget.mode);

  @override
  void didUpdateWidget(covariant ZMindmapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      _mode.value = widget.mode;
    }
  }

  @override
  void dispose() {
    _selected.dispose();
    _mode.dispose();
    super.dispose();
  }

  /// Racines effectives (priorité à `mindmap`).
  List<ZMindmapNode> get _roots =>
      widget.mindmap?.nodes ?? widget.roots ?? const <ZMindmapNode>[];

  /// Contenu par défaut **stable** (tear-off statique — pas de closure réallouée
  /// à chaque build, L2).
  static Widget _defaultContent(BuildContext context, ZMindmapNode node) =>
      ZMindmapDefaultNodeContent(node: node);

  /// Résout le constructeur de contenu (défaut sûr si non injecté).
  ZMindmapNodeContentBuilder get _contentBuilder =>
      widget.nodeContentBuilder ?? _defaultContent;

  void _handleTap(ZMindmapNode node) {
    _selected.value = node.id; // rebuild ciblé du seul surlignage.
    widget.onNodeSelected?.call(node);
    widget.onNodeTap?.call(node);
  }

  @override
  Widget build(BuildContext context) {
    final roots = _roots;
    return ValueListenableBuilder<ZMindmapViewMode>(
      valueListenable: _mode,
      builder: (context, mode, _) {
        switch (mode) {
          case ZMindmapViewMode.list:
            return ZMindmapListView(
              roots: roots,
              contentBuilder: _contentBuilder,
              selectedListenable: _selected,
              config: widget.config,
              onNodeTap: _handleTap,
              emptyLabel: widget.emptyLabel,
            );
          case ZMindmapViewMode.graph:
            return _buildGraph(context, roots);
        }
      },
    );
  }

  Widget _buildGraph(BuildContext context, List<ZMindmapNode> roots) {
    if (roots.isEmpty) return _buildEmpty(context);

    final data = ZMindmapGraphMapper.fromForest(roots);
    final lookup = <String, ZMindmapNode>{};
    void index(ZMindmapNode n) {
      lookup[n.id] = n;
      for (final c in n.children) {
        index(c);
      }
    }

    for (final r in roots) {
      index(r);
    }

    // Surface VISUELLE : le graphe est exclu de la sémantique (la vue liste est
    // la surface a11y de référence, AD-13). Zoom/pan bornés par l'InteractiveViewer
    // interne de `graphite` ; aucun callback de pan de nœud n'est câblé → AUCUN
    // drag libre.
    return ExcludeSemantics(
      child: DirectGraph(
        list: data.nodes,
        defaultCellSize: widget.config.cellSize,
        cellPadding: EdgeInsets.all(widget.config.cellSpacing),
        orientation: MatrixOrientation.Vertical, // descendante parent → enfants
        centered: true,
        minScale: widget.config.minScale,
        maxScale: widget.config.maxScale,
        nodeBuilder: (context, nodeInput) {
          // Racine virtuelle multi-racine : non affichée (taille nulle).
          if (data.usesVirtualRoot &&
              nodeInput.id == ZMindmapGraphMapper.virtualRootId) {
            return const SizedBox.shrink();
          }
          final node = lookup[nodeInput.id];
          if (node == null) return const SizedBox.shrink();
          // Point d'écoute unique du nœud graphe (M1) : la carte reçoit
          // `isSelected` résolu et ne s'abonne plus elle-même.
          return ValueListenableBuilder<String?>(
            key: ValueKey<String>('zmindmap-node-${node.id}'),
            valueListenable: _selected,
            builder: (context, selectedId, _) => ZMindmapNodeCard(
              node: node,
              contentBuilder: _contentBuilder,
              isSelected: selectedId == node.id,
              config: widget.config,
              onTap: _handleTap,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    if (widget.emptyLabel == null) return const SizedBox.expand();
    return Center(
      child: Semantics(
        label: widget.emptyLabel,
        child: Text(widget.emptyLabel!, textAlign: TextAlign.start),
      ),
    );
  }
}
