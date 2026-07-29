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
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

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

/// Champ éditable ciblé par un [ZMindmapEditFieldBuilder] (SU-12, AD-40).
///
/// **enum, jamais `bool`** (Key Don'ts) : le kind discrimine le champ `label` du
/// champ `content` sans encoder une sémantique dans un booléen opaque.
enum ZMindmapEditFieldKind {
  /// Titre court mono-ligne du nœud (`ZMindmapNode.label`, texte brut OQ-S5).
  label,

  /// Contenu long multiligne du nœud (`ZMindmapNode.content`, texte brut OQ-S5).
  content,
}

/// Contexte **stable** passé à un [ZMindmapEditFieldBuilder] (SU-12, AD-40).
///
/// Porte tout ce qu'un slot d'édition (défaut `TextField` OU adaptateur riche)
/// consomme SANS que le builder n'accède au [ZMindmapOutlineController] :
/// - [controller] : le `TextEditingController` **STABLE** keyé par `node.id` (voie
///   texte brut — jamais recréé au rebuild, zéro perte de focus SM-1/AD-2) ;
/// - [value] : la valeur texte brut courante (`label` ou `content ?? ''`) ;
/// - [onChanged] : voie d'écriture **texte brut** (branchée sur `editLabel`/
///   `editContent` — `label`/`content` restent plain, OQ-S5/AD-28) ;
/// - [writeRichSlot] : voie d'écriture d'un **slot AD-4** (`extra[slotKey]`) —
///   c'est CE que l'adaptateur riche emprunte (ops Delta neutres), SANS toucher
///   `label`/`content`. Générique (n'importe quel slot), pas markdown-spécifique.
@immutable
class ZMindmapEditFieldContext {
  /// Construit le contexte d'un champ d'édition d'un nœud.
  const ZMindmapEditFieldContext({
    required this.node,
    required this.kind,
    required this.controller,
    required this.value,
    required this.onChanged,
    required this.writeRichSlot,
    required this.hint,
    required this.config,
    required this.theme,
  });

  /// Nœud immuable édité.
  final ZMindmapNode node;

  /// Champ ciblé (`label` ou `content`).
  final ZMindmapEditFieldKind kind;

  /// `TextEditingController` **stable** de la voie texte brut (keyé par `node.id`).
  final TextEditingController controller;

  /// Valeur texte brut courante du champ (`label` ou `content ?? ''`).
  final String value;

  /// Voie d'écriture **texte brut** (branchée sur `editLabel`/`editContent`).
  final ValueChanged<String> onChanged;

  /// Voie d'écriture d'un **slot AD-4** de `extra` (ops Delta neutres) : écrit
  /// `node.extra[slotKey]` SANS toucher `label`/`content` (OQ-S5/AD-28). C'est la
  /// voie qu'emprunte l'adaptateur d'édition riche (symétrie avec le rendu qui
  /// LIT le même slot). Générique — l'appelant choisit `slotKey`.
  final void Function(String slotKey, List<Map<String, dynamic>> ops)
      writeRichSlot;

  /// Libellé/placeholder a11y du champ (repli neutre).
  final String hint;

  /// Configuration de layout (cible tactile ≥ 48 dp, tokens géométriques).
  final ZMindmapViewConfig config;

  /// Thème injecté (couleurs/espacements — FR-26, repli `Theme.of`).
  final ZcrudTheme theme;
}

/// Constructeur injectable d'un **champ d'édition** d'un nœud (SU-12, AD-40).
///
/// Reçoit un [ZMindmapEditFieldContext] stable et retourne le widget d'édition
/// (défaut `TextField` texte brut fourni par l'outline editor quand `null` ;
/// l'adaptateur riche `ZMindmapMarkdownEditField.builder` est une **injection**
/// de l'app hôte, au-dessus de l'arête `zcrud_mindmap → zcrud_markdown`, AD-40).
typedef ZMindmapEditFieldBuilder = Widget Function(
  BuildContext context,
  ZMindmapEditFieldContext ctx,
);

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
    this.borderWidth,
    this.selectedBorderWidth,
  })  : assert(minScale > 0 && minScale <= maxScale,
            'minScale doit être > 0 et ≤ maxScale'),
        assert(minTapTarget >= 48, 'cible tactile ≥ 48 dp (AD-13)'),
        assert(borderWidth == null || borderWidth >= 0,
            'borderWidth doit être ≥ 0'),
        assert(selectedBorderWidth == null || selectedBorderWidth >= 0,
            'selectedBorderWidth doit être ≥ 0');

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

  /// Épaisseur du trait de la carte de nœud **non sélectionnée** (CR-LEX-80).
  ///
  /// `null` ⇒ repli sur [kZMindmapDefaultBorderWidth] (`1`) : rendu **strictement
  /// inchangé** tant que l'hôte n'injecte rien (ADDITIF STRICT). La config porte
  /// déjà les autres dimensions du nœud ([cellSize], [cellSpacing]) — le trait
  /// était la seule dimension fermée.
  final double? borderWidth;

  /// Épaisseur du trait de la carte de nœud **sélectionnée** (CR-LEX-80).
  ///
  /// `null` ⇒ repli sur [kZMindmapDefaultSelectedBorderWidth] (`2`). Le défaut
  /// `1`/`2` est **volontairement conservé** : il fait de l'épaisseur un canal de
  /// distinction de la sélection. C'est l'hôte qui arbitre (ex. trait constant),
  /// pas le socle.
  final double? selectedBorderWidth;
}

/// Épaisseur de trait par défaut d'un nœud **non sélectionné** (CR-LEX-80).
///
/// Valeur historique — la changer modifierait le rendu de tous les hôtes qui
/// n'injectent rien (`ZMindmapViewConfig.borderWidth == null`).
const double kZMindmapDefaultBorderWidth = 1;

/// Épaisseur de trait par défaut d'un nœud **sélectionné** (CR-LEX-80).
///
/// Valeur historique — canal de distinction de la sélection (cf.
/// [ZMindmapViewConfig.selectedBorderWidth]).
const double kZMindmapDefaultSelectedBorderWidth = 2;
