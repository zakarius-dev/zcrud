/// [ZAppBarAction] — action d'app-bar DÉCLARÉE EN DONNÉES (SUF-1, AC2/AC3).
///
/// Une action est une **valeur immuable** : icône + libellé a11y explicite
/// (jamais nul) + callback + tooltip optionnel + drapeau de débordement. Le
/// page-shell mappe chaque action vers **un** `IconButton` (cible ≥ 48 dp,
/// `Semantics` via `Icon.semanticLabel`) — ou une entrée de menu de débordement
/// si [isOverflow]. Une action **non déclarée est structurellement absente**
/// (aucun bouton fantôme) : la liste des actions pilote seule l'arbre.
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
  });

  /// Glyphe de l'action.
  final IconData icon;

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
          semanticLabel == other.semanticLabel &&
          onPressed == other.onPressed &&
          tooltip == other.tooltip &&
          isOverflow == other.isOverflow;

  @override
  int get hashCode =>
      Object.hash(icon, semanticLabel, onPressed, tooltip, isOverflow);
}
