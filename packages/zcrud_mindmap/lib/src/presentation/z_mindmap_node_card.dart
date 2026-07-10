/// Carte de nœud thématisée partagée par le graphe et la vue liste (E10-2).
///
/// - **FR-26** : toutes les couleurs proviennent de `ZcrudTheme.of(context)`
///   (repli `Theme.of(context)`), AUCUN littéral de couleur.
/// - **AD-13** : cible tactile ≥ 48 dp, `TextAlign.start`, padding directionnel,
///   `Semantics` porté par la vue liste (le graphe est `ExcludeSemantics`).
/// - **AD-2/AD-15** : mise en évidence de sélection via `ValueListenableBuilder`
///   sur un `ValueListenable<String?>` (rebuild ciblé, jamais `setState` global,
///   aucun gestionnaire d'état tiers).
///
/// Le **contenu** est délégué au `ZMindmapNodeContentBuilder` injecté (ou au
/// défaut sûr [ZMindmapDefaultNodeContent]) — appliqué **à l'identique** dans les
/// deux surfaces pour garantir l'équivalence graphe ⇄ liste.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_mindmap_node.dart';
import 'z_mindmap_view_config.dart';

/// Rendu **par défaut** du contenu d'un nœud : `label` en texte brut thématisé,
/// repli sur un extrait de `content` si `label` est vide. `TextAlign.start`
/// (RTL-safe), troncature propre. **Ne dépend PAS de `zcrud_markdown`** (le rendu
/// riche est une injection de l'app hôte, AD-4).
class ZMindmapDefaultNodeContent extends StatelessWidget {
  /// Construit le contenu par défaut pour [node].
  const ZMindmapDefaultNodeContent({required this.node, super.key});

  /// Nœud immuable rendu.
  final ZMindmapNode node;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final baseColor = theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    final text = node.label.isNotEmpty ? node.label : (node.content ?? '');
    return Text(
      text,
      textAlign: TextAlign.start,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: baseColor) ??
          TextStyle(color: baseColor),
    );
  }
}

/// Carte interactive thématisée enveloppant le contenu d'un nœud.
///
/// Partagée par le graphe (`ExcludeSemantics` en amont) et la vue liste (qui
/// ajoute le `Semantics` explicite). Cible ≥ 48 dp ; sélection surlignée via
/// [selectedListenable] (rebuild ciblé).
class ZMindmapNodeCard extends StatelessWidget {
  /// Construit une carte pour [node].
  const ZMindmapNodeCard({
    required this.node,
    required this.contentBuilder,
    required this.isSelected,
    required this.config,
    this.onTap,
    super.key,
  });

  /// Nœud immuable rendu.
  final ZMindmapNode node;

  /// Constructeur de contenu injecté (défaut sûr résolu par l'appelant).
  final ZMindmapNodeContentBuilder contentBuilder;

  /// État de sélection **déjà résolu** par l'appelant (surlignage). Le point
  /// d'écoute unique (`ValueListenableBuilder`) vit dans la surface parente
  /// (ligne de liste ou nœud du graphe) — la carte ne s'abonne PAS elle-même
  /// (évite le double-abonnement O(n), M1/AD-2).
  final bool isSelected;

  /// Configuration de layout (cible tactile, tokens géométriques).
  final ZMindmapViewConfig config;

  /// Remontée du tap (aucune mutation d'arbre) ; `null` → carte non interactive.
  final ZMindmapNodeCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final surface = theme.surfaceColor ?? scheme.surface;
    final border = theme.fieldBorderColor ?? scheme.outline;
    final selectedBorder = theme.labelColor ?? scheme.primary;

    final card = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: config.minTapTarget,
        minHeight: config.minTapTarget,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.all(theme.radiusM),
          border: Border.all(
            color: isSelected ? selectedBorder : border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapM,
            vertical: theme.gapS,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: contentBuilder(context, node),
          ),
        ),
      ),
    );
    if (onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap!(node),
      child: card,
    );
  }
}
