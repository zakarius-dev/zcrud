/// `ZMindmapView` — vue d'une forêt `ZMindmap` (Story E10-2, FR-19, AD-13 ;
/// COMBLEMENTS ES-7.2 : zoom piloté clampé, compact, plein-écran, super-racine).
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
///
/// ## COMBLEMENTS ES-7.2 (ADDITIF STRICT — AC6/D8)
/// Un [controller] **optionnel** (`ZMindmapViewController`) active une barre de
/// contrôles user-facing : **zoom** piloté/clampé, toggle **compact**, toggle
/// **plein-écran**, toggle **super-racine** multi-forêt. `controller == null` ⇒
/// comportement E10 **strictement inchangé** (aucune barre, aucune enveloppe).
///
/// - **Zoom (D4/DW-ES72-1)** : `graphite` 1.2.1 **n'expose pas** de
///   `TransformationController` (le paramètre est documenté mais **absent** du
///   constructeur) ⇒ l'`InteractiveViewer` interne n'est **pas pilotable**. On
///   enveloppe donc la surface graphe dans un `Transform.scale` **externe** piloté
///   par `controller.scale` (clampé au contrôleur), et on **neutralise** le zoom
///   interne (`minScale = maxScale = 1`) pour éviter le double-zoom — **sans
///   forker `graphite`** ; le pan interne reste actif. Le `child` du
///   `Transform.scale` est passé **une fois** (arg `child:`) ⇒ un zoom **ne
///   reconstruit pas** les nœuds (SM-1).
library;

import 'package:flutter/material.dart';
import 'package:graphite/graphite.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_mindmap.dart';
import '../domain/z_mindmap_node.dart';
import 'z_mindmap_graph_mapper.dart';
import 'z_mindmap_list_view.dart';
import 'z_mindmap_node_card.dart';
import 'z_mindmap_view_config.dart';
import 'z_mindmap_view_controls.dart';

/// Clé de la surface « maximisée » (AC4) : le wrapper `SizedBox.expand` n'est
/// présent QUE lorsque `controller.fullscreen == true`. Exposée pour rendre la
/// présence du wrapper OBSERVABLE en test (pouvoir discriminant R12 : neutraliser
/// le wrapper fait rougir l'assertion AC4, jamais un simple libellé de bouton).
const String kMindmapMaximizedSurfaceKey = 'zMindmapMaximizedSurface';

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
    this.controller,
    this.viewLabels = const ZMindmapViewLabels(),
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

  /// Contrôleur de vue **optionnel** (ES-7.2) : zoom/compact/plein-écran/super-
  /// racine. `null` ⇒ comportement E10 inchangé (aucune barre de contrôles).
  /// Cycle de vie (création/`dispose`) porté par l'app hôte (AD-2).
  final ZMindmapViewController? controller;

  /// Libellés a11y **externalisés** des contrôles ES-7.2 (repli neutre non-nul).
  final ZMindmapViewLabels viewLabels;

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
    final controller = widget.controller;
    // Chemin E10 STRICT : aucun contrôleur ⇒ surface nue, comportement inchangé.
    if (controller == null) return _buildSurface(context, null);
    // Chemin ES-7.2 : barre de contrôles + plein-écran, tranches isolées.
    return ValueListenableBuilder<bool>(
      valueListenable: controller.fullscreen,
      builder: (context, fullscreen, _) {
        final body = _buildControlledBody(context, controller);
        if (!fullscreen) return body;
        // « Maximisé » (AC4) : la surface s'ÉTEND pour REMPLIR L'ESPACE DISPONIBLE
        // que l'hôte lui accorde (`SizedBox.expand`) sur un fond opaque, l'affordance
        // de SORTIE étant le bouton étiqueté `exitFullscreen` de la barre. Sur un hôte
        // à surface large/non bornée (page mindmap dédiée) la carte occupe toute la
        // page ; sur un hôte à hauteur BORNÉE (section study contrainte, ES-7.1) elle
        // remplit ce cadre — un vrai plein-écran par Overlay/route qui ÉCHAPPE à
        // l'arbre est une amélioration DÉFÉRÉE (DW-ES72-5), hors périmètre M ES-7.2.
        // Défaut off ⇒ ce chemin n'est jamais pris par E10 (additif strict AC6). La
        // `ValueKey` rend la présence du wrapper OBSERVABLE par le test (pouvoir
        // discriminant : sans le wrapper, l'assertion AC4 rougit).
        final theme = ZcrudTheme.of(context);
        final bg = theme.surfaceColor ?? Theme.of(context).colorScheme.surface;
        return SizedBox.expand(
          key: const ValueKey<String>(kMindmapMaximizedSurfaceKey),
          child: ColoredBox(color: bg, child: body),
        );
      },
    );
  }

  /// Corps « contrôlé » : barre de contrôles au-dessus, surface au-dessous.
  Widget _buildControlledBody(
    BuildContext context,
    ZMindmapViewController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ZMindmapControlBar(
          controller: controller,
          labels: widget.viewLabels,
        ),
        Expanded(child: _buildSurface(context, controller)),
      ],
    );
  }

  /// Surface graphe ⇄ liste. [controller] non-null active zoom/compact/super-
  /// racine ; `null` ⇒ E10 strict.
  Widget _buildSurface(BuildContext context, ZMindmapViewController? controller) {
    final roots = _roots;
    return ValueListenableBuilder<ZMindmapViewMode>(
      valueListenable: _mode,
      builder: (context, mode, _) {
        switch (mode) {
          case ZMindmapViewMode.list:
            return _buildList(context, roots, controller);
          case ZMindmapViewMode.graph:
            return _buildGraphSurface(context, roots, controller);
        }
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    List<ZMindmapNode> roots,
    ZMindmapViewController? controller,
  ) {
    // Super-racine liste : réutilise l'invariant `usesVirtualRoot` (multi-forêt).
    // Le libellé n'est passé QUE si le toggle est actif ; l'écoute du toggle se
    // fait ici via un ValueListenableBuilder pour un rebuild ciblé.
    if (controller == null) {
      return ZMindmapListView(
        roots: roots,
        contentBuilder: _contentBuilder,
        selectedListenable: _selected,
        config: widget.config,
        onNodeTap: _handleTap,
        emptyLabel: widget.emptyLabel,
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: controller.showSuperRoot,
      builder: (context, showSuperRoot, _) => ZMindmapListView(
        roots: roots,
        contentBuilder: _contentBuilder,
        selectedListenable: _selected,
        config: widget.config,
        onNodeTap: _handleTap,
        emptyLabel: widget.emptyLabel,
        compactListenable: controller.compact,
        superRootLabel:
            showSuperRoot ? widget.viewLabels.superRootLabel : null,
      ),
    );
  }

  /// Enveloppe la surface graphe : en mode contrôlé, `Transform.scale` externe
  /// piloté par `controller.scale` (le `child` graphe est passé UNE FOIS ⇒ le
  /// zoom ne reconstruit pas les nœuds, SM-1). Sinon, graphe nu (E10).
  Widget _buildGraphSurface(
    BuildContext context,
    List<ZMindmapNode> roots,
    ZMindmapViewController? controller,
  ) {
    final graph = _buildGraph(context, roots, controller);
    if (controller == null) return graph;
    return ValueListenableBuilder<double>(
      valueListenable: controller.scale,
      // 🔴 `child` passé UNE FOIS : un changement d'échelle rebuild le SEUL
      // Transform.scale, JAMAIS le sous-arbre graphe (nœuds non reconstruits).
      child: graph,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
    );
  }

  Widget _buildGraph(
    BuildContext context,
    List<ZMindmapNode> roots,
    ZMindmapViewController? controller,
  ) {
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

    // Neutralisation du zoom INTERNE de `graphite` en mode contrôlé (DW-ES72-1) :
    // notre `Transform.scale` externe pilote le zoom ⇒ on verrouille le zoom
    // interne (min = max = 1) pour éviter le double-zoom (pan interne conservé).
    final controlled = controller != null;
    final minScale = controlled ? 1.0 : widget.config.minScale;
    final maxScale = controlled ? 1.0 : widget.config.maxScale;

    // Surface VISUELLE : le graphe est exclu de la sémantique (la vue liste est
    // la surface a11y de référence, AD-13). Aucun callback de pan de nœud n'est
    // câblé → AUCUN drag libre.
    return ExcludeSemantics(
      child: DirectGraph(
        list: data.nodes,
        defaultCellSize: widget.config.cellSize,
        cellPadding: EdgeInsets.all(widget.config.cellSpacing),
        orientation: MatrixOrientation.Vertical, // descendante parent → enfants
        centered: true,
        minScale: minScale,
        maxScale: maxScale,
        nodeBuilder: (context, nodeInput) {
          // Racine virtuelle multi-racine.
          if (data.usesVirtualRoot &&
              nodeInput.id == ZMindmapGraphMapper.virtualRootId) {
            // E10 : non affichée. ES-7.2 : affichable en super-racine étiquetée
            // (opt-in `showSuperRoot`) — réutilise le MÊME virtual root (aucun
            // 2e mécanisme). 1 racine ⇒ `usesVirtualRoot == false` ⇒ jamais ici.
            if (controller == null) return const SizedBox.shrink();
            return ValueListenableBuilder<bool>(
              valueListenable: controller.showSuperRoot,
              builder: (context, show, _) => show
                  ? _SuperRootNode(
                      label: widget.viewLabels.superRootLabel,
                      config: widget.config,
                    )
                  : const SizedBox.shrink(),
            );
          }
          final node = lookup[nodeInput.id];
          if (node == null) return const SizedBox.shrink();
          // Point d'écoute unique du nœud graphe (M1) : la carte reçoit
          // `isSelected` résolu et ne s'abonne plus elle-même. Le compact est une
          // tranche SÉPARÉE (résolue par un builder imbriqué en mode contrôlé).
          return ValueListenableBuilder<String?>(
            key: ValueKey<String>('zmindmap-node-${node.id}'),
            valueListenable: _selected,
            builder: (context, selectedId, _) {
              final isSelected = selectedId == node.id;
              // Bornage AD-41 (SU-12) : la cellule GRAPHE borne le contenu
              // (riche compris) à `cellSize` — troncature clippée, jamais de
              // RenderFlex overflow. La vue liste, elle, reste NON bornée.
              if (controller == null) {
                return ZMindmapCellClip(
                  size: widget.config.cellSize,
                  child: ZMindmapNodeCard(
                    node: node,
                    contentBuilder: _contentBuilder,
                    isSelected: isSelected,
                    config: widget.config,
                    onTap: _handleTap,
                  ),
                );
              }
              return ValueListenableBuilder<bool>(
                valueListenable: controller.compact,
                builder: (context, compact, _) => ZMindmapCellClip(
                  size: widget.config.cellSize,
                  child: ZMindmapNodeCard(
                    node: node,
                    contentBuilder: _contentBuilder,
                    isSelected: isSelected,
                    config: widget.config,
                    onTap: _handleTap,
                    compact: compact,
                  ),
                ),
              );
            },
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

/// Nœud « super-racine » affiché (ES-7.2, AC5) : étiquette externalisée groupant
/// la forêt multi-racine. Thématisé (FR-26), cible ≥ 48 dp, `TextAlign.start`.
class _SuperRootNode extends StatelessWidget {
  const _SuperRootNode({required this.label, required this.config});

  final String label;
  final ZMindmapViewConfig config;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final surface = theme.surfaceColor ?? scheme.surface;
    final border = theme.labelColor ?? scheme.primary;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: config.minTapTarget,
        minHeight: config.minTapTarget,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.all(theme.radiusM),
          border: Border.all(color: border, width: 2),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapM,
            vertical: theme.gapS,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barre de contrôles user-facing (ES-7.2) : zoom in/out/reset, compact, plein-
/// écran, super-racine. Chaque bouton est **≥ 48 dp**, `Semantics(button:true)`
/// avec libellé **externalisé**, directionnel, **sans couleur codée en dur**
/// (icônes thématisées par défaut). Les toggles écoutent leur tranche via un
/// `ValueListenableBuilder` (rebuild ciblé du seul bouton, SM-1).
class _ZMindmapControlBar extends StatelessWidget {
  const _ZMindmapControlBar({required this.controller, required this.labels});

  final ZMindmapViewController controller;
  final ZMindmapViewLabels labels;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: theme.gapS,
        vertical: theme.gapS,
      ),
      // Défilement horizontal (LOW-2) : 6 cibles ≥ 48 dp (~288 dp) débordent un
      // hôte étroit/RTL — un `SingleChildScrollView` évite le `RenderFlex overflow`
      // sans jamais rogner une cible tactile (AD-13). Directionnel (RTL-safe).
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _ControlButton(
              icon: Icons.zoom_out,
            label: labels.zoomOut,
            onPressed: controller.zoomOut,
            keyValue: 'zmindmap-ctl-zoom-out',
          ),
          _ControlButton(
            icon: Icons.center_focus_strong,
            label: labels.resetZoom,
            onPressed: controller.resetZoom,
            keyValue: 'zmindmap-ctl-zoom-reset',
          ),
          _ControlButton(
            icon: Icons.zoom_in,
            label: labels.zoomIn,
            onPressed: controller.zoomIn,
            keyValue: 'zmindmap-ctl-zoom-in',
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.compact,
            builder: (context, compact, _) => _ControlButton(
              icon: compact ? Icons.view_agenda : Icons.view_compact,
              label: compact ? labels.expand : labels.compact,
              onPressed: controller.toggleCompact,
              keyValue: 'zmindmap-ctl-compact',
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.fullscreen,
            builder: (context, fullscreen, _) => _ControlButton(
              icon: fullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
              label:
                  fullscreen ? labels.exitFullscreen : labels.enterFullscreen,
              onPressed: controller.toggleFullscreen,
              keyValue: 'zmindmap-ctl-fullscreen',
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: controller.showSuperRoot,
            builder: (context, show, _) => _ControlButton(
              icon: Icons.account_tree,
              label: show ? labels.hideSuperRoot : labels.showSuperRoot,
              onPressed: controller.toggleSuperRoot,
              keyValue: 'zmindmap-ctl-super-root',
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// Bouton de contrôle **≥ 48 dp**, `Semantics(button:true, label:…)` externalisé,
/// couleur d'icône issue du thème (aucun littéral). AD-13/FR-26.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.keyValue,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final String keyValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        key: ValueKey<String>(keyValue),
        icon: Icon(icon),
        tooltip: label,
        // Cible tactile ≥ 48 dp (AD-13) — contrainte explicite.
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        onPressed: onPressed,
      ),
    );
  }
}
