/// [ZAppBarAction] — action d'app-bar DÉCLARÉE EN DONNÉES.
///
/// Une action est une **valeur immuable**: icône + libellé a11y explicite
/// (jamais nul) + callback + tooltip optionnel + drapeau de débordement. Le
/// page-shell mappe chaque action vers **un** `IconButton` (cible ≥ 48 dp,
/// `Semantics` via `Icon.semanticLabel`) — ou une entrée de menu de débordement
/// si [isOverflow]. Une action **non déclarée est structurellement absente**
/// (aucun bouton fantôme): la liste des actions pilote seule l'arbre.
library;

import 'package:flutter/widgets.dart';

/// Action déclarative d'app-bar (donnée, pas widget).
@immutable
class ZAppBarAction {
  /// Construit une action. [icon] et [semanticLabel] sont requis ([semanticLabel]
  /// n'est **jamais** nul — a11y AD-13). [onPressed] nul ⇒ action désactivée.
  const ZAppBarAction({
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tooltip,
    this.isOverflow = false,
  }) : child = null;

  /// Variante pour une action portée par un widget (avatar, badge, indicateur
  /// de chargement…). Le chemin [ZAppBarAction.new] à icône reste inchangé.
  const ZAppBarAction.widget({
    required Widget this.child,
    required this.semanticLabel,
    this.onPressed,
    this.tooltip,
    this.isOverflow = false,
  }) : icon = const IconData(0);

  /// Glyphe de l'action.
  final IconData icon;

  /// Widget visible de l'action, présent seulement avec [ZAppBarAction.widget].
  final Widget? child;

  /// Libellé accessible explicite (lecteur d'écran) — toujours présent.
  final String semanticLabel;

  /// Callback invoqué au tap (nul ⇒ bouton désactivé).
  final VoidCallback? onPressed;

  /// Info-bulle optionnelle (survol/appui long).
  final String? tooltip;

  /// Si vrai, l'action est rendue dans le **menu de débordement** plutôt qu'en
  /// bouton d'icône visible.
  final bool isOverflow;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAppBarAction &&
          runtimeType == other.runtimeType &&
          icon == other.icon &&
          child == other.child &&
          semanticLabel == other.semanticLabel &&
          onPressed == other.onPressed &&
          tooltip == other.tooltip &&
          isOverflow == other.isOverflow;

  @override
  int get hashCode =>
      Object.hash(icon, child, semanticLabel, onPressed, tooltip, isOverflow);
}
