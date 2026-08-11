/// Injection du seam d'annonce accessible d'un message.
///
/// ## Pourquoi l'annonce passe par un `Semantics` dédié
///
/// `ZContentBlock.accessibleText` (kernel) produit un résumé exhaustif par
/// construction — un `switch` sur l'union scellée des blocs, donc tableaux,
/// sources, suggestions et diagrammes compris. Ce résumé est porté par un
/// `Semantics` posé dans `ZChatMessageTile`, sur le chemin commun aux deux
/// branches de rendu (liste neutre et coquille tierce, qui rappellent toutes
/// deux la même fabrique de tuile) — c'est ce qui garantit qu'un lecteur
/// d'écran l'entend quel que soit le rendu choisi par l'hôte.
///
/// ## Pourquoi un scope, et pas un paramètre de vue
///
/// Le résolveur doit atteindre deux consommateurs vivant dans deux paquets :
/// `ZChatMessageTile` (annonce réelle) et un éventuel renderer de coquille
/// tiers. Un paramètre passé à `ZChatConversationView` n'atteindrait pas le
/// second, et un champ propre à ce renderer n'atteindrait pas la première :
/// deux résolveurs indépendants, donc deux résumés qui pourraient diverger.
/// Le scope est l'unique point d'injection.
///
/// Ce scope ne peut pas vivre dans `ZcrudScope` (invariant AD-1) : sa
/// signature porte `ZContentBlock`, donc du vocabulaire de
/// `zcrud_chat_kernel`. Même arbitrage que `ZChatRendererScope` et
/// `ZChatShellRendererScope`.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Porte le résolveur d'annonce de l'hôte jusqu'à la tuile et à la coquille.
class ZChatAccessibleTextScope extends InheritedWidget {
  /// Injecte [resolver] pour le sous-arbre [child].
  const ZChatAccessibleTextScope({
    required this.resolver,
    required super.child,
    this.announce = true,
    super.key,
  });

  /// Seam d'annonce de l'hôte (invariant AD-4) : c'est par lui qu'un bloc de
  /// nature ouverte (une référence légale, des flashcards, une carte
  /// mentale…) devient annonçable et localisable — le kernel, pur-Dart,
  /// n'émet que de la donnée.
  ///
  /// `null` signifie résumé du kernel seul.
  final ZAccessibleTextResolver? resolver;

  /// `false` signifie que la tuile ne pose plus son nœud d'annonce.
  ///
  /// Ce n'est pas un simple confort : l'annonce du résumé impose
  /// `excludeSemantics: true`, sans quoi le résumé et le texte des blocs sont
  /// énoncés en double. Un hôte dont le `ZChatRenderer` rend des blocs
  /// interactifs (un bouton dans une bulle) doit pouvoir garder la sémantique
  /// de ses enfants ; il coupe alors l'annonce ici et l'assume dans son
  /// propre renderer. Le défaut reste `true` : l'annonce est la règle, la
  /// désactiver est le geste explicite.
  final bool announce;

  /// Le scope le plus proche, ou `null` — jamais de `throw` (invariant AD-10).
  static ZChatAccessibleTextScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZChatAccessibleTextScope>();

  /// Le résolveur injecté, ou `null` (aucun scope, ou scope sans résolveur).
  static ZAccessibleTextResolver? resolverOf(BuildContext context) =>
      maybeOf(context)?.resolver;

  /// `true` si la tuile doit poser son nœud d'annonce (défaut hors scope).
  static bool announceOf(BuildContext context) =>
      maybeOf(context)?.announce ?? true;

  @override
  bool updateShouldNotify(ZChatAccessibleTextScope oldWidget) =>
      !identical(resolver, oldWidget.resolver) ||
      announce != oldWidget.announce;
}
