/// Types & configuration publics de la vue de carte mentale (Story E10-2).
///
/// - [ZMindmapNodeContentBuilder] : point d'injection du **rendu de contenu**
///   d'un nœud (branchable sur `zcrud_markdown`, badges de source/audio via
///   les slots d'extension AD-4…), appliqué **à l'identique** au graphe et à la
///   vue liste (équivalence graphe ⇄ liste, AD-13).
/// - [ZMindmapNodeCallback] : remontée d'interaction (tap/sélection) SANS
///   mutation d'arbre — E10-2 est **lecture seule** (AD-2/AD-15).
/// - [ZMindmapViewMode] : bascule graphe ⇄ liste (surface a11y de référence).
/// - [ZMindmapViewConfig] : constantes de **layout structurel** immuables
///   (bornes de zoom, taille de cellule, pas d'indentation, cible tactile) —
///   pas de couleur (les couleurs viennent de `ZcrudTheme`, FR-26).
library;

import 'package:flutter/widgets.dart';

import '../domain/z_mindmap_node.dart';

/// Constructeur injectable du **contenu** d'un nœud de carte mentale.
///
/// Reçoit le [ZMindmapNode] immuable et retourne le widget de contenu (titre,
/// extrait, rendu riche domaine…). Défaut sûr fourni par la vue quand `null`
/// (texte brut `label`, thématisé) — le défaut **ne dépend pas** de
/// `zcrud_markdown` (le rendu riche est une injection de l'app hôte, AD-4).
typedef ZMindmapNodeContentBuilder = Widget Function(
  BuildContext context,
  ZMindmapNode node,
);

/// Callback de remontée d'interaction sur un nœud (tap/sélection).
///
/// E10-2 **ne mute jamais** l'arbre : elle notifie l'app hôte, qui décide (ouvrir
/// un éditeur E10-3, naviguer…). AD-2/AD-15.
typedef ZMindmapNodeCallback = void Function(ZMindmapNode node);

/// Mode d'affichage de [ZMindmapView].
enum ZMindmapViewMode {
  /// Graphe auto-agencé `graphite` (surface visuelle ; `ExcludeSemantics`).
  graph,

  /// Vue liste sémantique indentée (surface a11y de référence, AD-13).
  list,
}

/// Configuration **immuable** de layout structurel de la vue (AD-13/FR-26).
///
/// Ne porte **aucune couleur** (les couleurs proviennent de `ZcrudTheme`) :
/// uniquement des constantes géométriques admissibles (bornes de zoom, taille
/// de cellule graphite, pas d'indentation, cible tactile minimale ≥ 48 dp).
@immutable
class ZMindmapViewConfig {
  /// Construit une configuration. Valeurs par défaut sûres (cible ≥ 48 dp).
  const ZMindmapViewConfig({
    this.minScale = 0.25,
    this.maxScale = 2.5,
    this.cellSize = const Size(180, 72),
    this.cellSpacing = 24,
    this.indentStep = 24,
    this.minTapTarget = 48,
  })  : assert(minScale > 0 && minScale <= maxScale,
            'minScale doit être > 0 et ≤ maxScale'),
        assert(minTapTarget >= 48, 'cible tactile ≥ 48 dp (AD-13)');

  /// Échelle minimale de l'`InteractiveViewer` interne de `graphite` (zoom).
  final double minScale;

  /// Échelle maximale de l'`InteractiveViewer` interne de `graphite` (zoom).
  final double maxScale;

  /// Taille par défaut d'une cellule/nœud du graphe (auto-layout `graphite`).
  final Size cellSize;

  /// Espacement entre cellules du graphe (allonge aussi les arêtes).
  final double cellSpacing;

  /// Pas d'indentation **directionnel** de la vue liste (par `level`).
  final double indentStep;

  /// Côté minimal d'une cible tactile interactive (AD-13 : ≥ 48 dp).
  final double minTapTarget;
}
