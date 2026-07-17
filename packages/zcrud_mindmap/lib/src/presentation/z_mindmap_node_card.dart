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

/// Rendu **compact** (ES-7.2, AC3) : `label` seul, mono-ligne, thématisé. Ne
/// rend **jamais** `content` (masquage condensé) et ne dépend d'aucun builder
/// injecté. Couleur issue du thème (FR-26), `TextAlign.start` (RTL-safe, AD-13).
class _CompactLabel extends StatelessWidget {
  const _CompactLabel({required this.node});

  final ZMindmapNode node;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final baseColor =
        theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Text(
      node.label,
      textAlign: TextAlign.start,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: baseColor) ??
          TextStyle(color: baseColor),
    );
  }
}

/// Bornage AD-41 d'une cellule du **graphe** (SU-12) : un contenu de nœud
/// **riche** (ex. `ZMindmapMarkdownContent` sans `maxLines`) doit être **borné à
/// la cellule fixe** `cellSize` — troncature propre, **jamais** de `RenderFlex
/// overflow` (leçon su-2/D3) et **jamais** de mesure intrinsèque qui déborderait.
///
/// Mécanique : [SizedBox] fige la taille de cellule ; [OverflowBox] donne à
/// l'enfant des contraintes **lâches** (hauteur jusqu'à l'infini) ⇒ il se pose à
/// sa taille naturelle **sans lever d'overflow** ; [ClipRect] **clippe** le
/// débordement peint. Aligné en `topStart` (RTL-safe, AD-13).
///
/// ⚠️ **N'est PAS appliqué à la vue liste / l'outline** : là, le rendu riche
/// **complet** (non borné) reste garanti (AC4). Seule la cellule du graphe borne.
///
/// Pouvoir discriminant (AD-41) : sans ce bornage, un contenu plus haut que la
/// cellule **déborde** (contre-preuve testable) ; avec, `takeException()` est nul.
class ZMindmapCellClip extends StatelessWidget {
  /// Borne [child] à [size] (troncature clippée, sans overflow ni intrinsèque).
  const ZMindmapCellClip({required this.size, required this.child, super.key});

  /// Taille fixe de la cellule (défaut graphe `180×72`).
  final Size size;

  /// Contenu de nœud borné (rendu riche ou défaut).
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox.fromSize(
        size: size,
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          minWidth: 0,
          maxWidth: size.width,
          minHeight: 0,
          // Contraintes LÂCHES en hauteur : l'enfant se pose à sa taille
          // naturelle (aucune mesure intrinsèque forcée, aucun RenderFlex
          // overflow) ; le ClipRect tronque le surplus (AD-41).
          maxHeight: double.infinity,
          child: child,
        ),
      ),
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
    this.compact = false,
    super.key,
  });

  /// Nœud immuable rendu.
  final ZMindmapNode node;

  /// Constructeur de contenu injecté (défaut sûr résolu par l'appelant).
  final ZMindmapNodeContentBuilder contentBuilder;

  /// Mode **compact** (ES-7.2, AC3) : rendu **condensé label-seul** — le
  /// [contentBuilder] (et donc tout extrait/contenu long ou rich-text) est
  /// **masqué**, seul `label` est rendu en texte brut mono-ligne. Défaut `false`
  /// ⇒ rendu E10 inchangé (ADDITIF STRICT, AC6). La garde de masquage vit ici :
  /// la retirer (toujours appeler [contentBuilder]) laisse le contenu visible
  /// ⇒ assertion AC3 ROUGE (INJ-2).
  final bool compact;

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
            child: compact
                ? _CompactLabel(node: node)
                : contentBuilder(context, node),
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
