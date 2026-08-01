/// [ZMenuTrigger] — le DÉCLENCHEUR déclaré en données (CHAT-4).
///
/// Le déclencheur est décrit, jamais construit, par l'appelant : c'est ce qui
/// permet à un [ZMenuRenderer] injecté de le rendre autrement (appui long,
/// clic droit, poignée de feuille modale…) sans que l'appelant change d'un
/// caractère.
///
/// 🔴 [semanticLabel] est **REQUIS** — jamais nul, jamais vide (assert).
/// `ZItemActionsMenu.tooltip` est optionnel et s'en remet au repli localisé de
/// `PopupMenuButton` (`MaterialLocalizations.showMenuTooltip`) ; ce repli
/// n'existe QUE dans Material. Dès qu'un renderer injecté prend la main, un
/// déclencheur sans nom accessible devient **MUET** pour un lecteur d'écran —
/// récidive `su-9`, documentée deux fois dans ce dépôt. Le contrat est donc
/// resserré, jamais relâché.
library;

import 'package:flutter/widgets.dart';

/// Description immuable du déclencheur d'un menu.
@immutable
class ZMenuTrigger {
  /// Déclencheur à GLYPHE.
  ///
  /// [icon] : glyphe INJECTÉ (jamais codé en dur). [semanticLabel] : nom
  /// accessible LOCALISÉ INJECTÉ, obligatoire et non vide. [tooltip] :
  /// info-bulle optionnelle (à défaut, [semanticLabel] est utilisé).
  const ZMenuTrigger({
    required this.icon,
    required this.semanticLabel,
    this.tooltip,
  })  : child = null,
        assert(
          semanticLabel.length > 0,
          'ZMenuTrigger: semanticLabel VIDE — un déclencheur de menu muet pour '
          'un lecteur d\'écran est proscrit (AD-13, récidive su-9).',
        );

  /// Déclencheur porté par un WIDGET (avatar, puce, bulle de message…).
  ///
  /// Le pendant de `ZAppBarAction.widget` (`zcrud_ui_kit`), que
  /// `ZItemActionsMenu` n'offre pas : son déclencheur est toujours un glyphe.
  const ZMenuTrigger.widget({
    required Widget this.child,
    required this.semanticLabel,
    this.tooltip,
  })  : icon = null,
        assert(
          semanticLabel.length > 0,
          'ZMenuTrigger: semanticLabel VIDE — un déclencheur de menu muet pour '
          'un lecteur d\'écran est proscrit (AD-13, récidive su-9).',
        );

  /// Glyphe INJECTÉ du déclencheur (`null` avec [ZMenuTrigger.widget]).
  final IconData? icon;

  /// Widget visible du déclencheur (`null` avec [ZMenuTrigger.new]).
  final Widget? child;

  /// Nom accessible LOCALISÉ INJECTÉ — toujours présent, jamais vide.
  final String semanticLabel;

  /// Info-bulle optionnelle (repli sur [semanticLabel]).
  final String? tooltip;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMenuTrigger &&
          icon == other.icon &&
          child == other.child &&
          semanticLabel == other.semanticLabel &&
          tooltip == other.tooltip;

  @override
  int get hashCode => Object.hash(icon, child, semanticLabel, tooltip);
}
