/// [ZPageTab] — onglet DÉCLARATIF du page-shell.
///
/// Un onglet = un libellé + une icône optionnelle + un **constructeur de
/// contenu** (`WidgetBuilder`) rendu paresseusement dans le `TabBarView`. La
/// liste des onglets pilote seule le `TabBar`: `tabs` nul/vide ⇒ aucun
/// `TabBar` dans l'arbre.
library;

import 'package:flutter/widgets.dart';

/// Onglet déclaratif (label + contenu construit à la demande).
@immutable
class ZPageTab {
  /// Construit un onglet. [label] et [contentBuilder] sont requis; [icon]
  /// optionnelle.
  const ZPageTab({
    required this.label,
    required this.contentBuilder,
    this.icon,
  });

  /// Libellé affiché dans le `TabBar`.
  final String label;

  /// Icône optionnelle affichée avec le libellé.
  final IconData? icon;

  /// Constructeur du corps de l'onglet (rendu dans le `TabBarView`).
  final WidgetBuilder contentBuilder;
}
