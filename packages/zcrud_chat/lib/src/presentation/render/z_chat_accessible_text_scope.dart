/// Injection du seam d'**annonce accessible** — correction HIGH-1/HIGH-2 de fin
/// d'epic.
///
/// ## 🔴 Le défaut mesuré : un résumé exhaustif annoncé à PERSONNE
///
/// `ZContentBlock.accessibleText` / `zChatAccessibleTextOf` (kernel) produisent
/// un résumé **exhaustif par construction** — `switch` sur l'union scellée,
/// donc tableaux, sources, suggestions et diagrammes compris. CHAT-3b le
/// branchait sur `AssistMessage.data` de Syncfusion… qui n'est lu **que dans la
/// branche `else`** du constructeur de contenu de `syncfusion_flutter_chat` —
/// branche que `messageContentBuilder` court-circuite **toujours**. Le résumé
/// partait donc dans un champ **inerte** : aucun lecteur d'écran ne l'entendait.
/// Pire, les deux gardes qui prétendaient le couvrir assertaient la **propriété
/// de widget** (`view.messages.first.data`) et seraient restées **vertes** si
/// Syncfusion avait ignoré le champ — ce qu'il fait.
///
/// L'annonce appartient donc désormais à un `Semantics` que **nous** contrôlons,
/// posé dans `ZChatMessageTile` (`zcrud_chat`), sur le chemin **commun** aux
/// deux branches (liste neutre **et** coquille tierce, qui rappellent la même
/// fabrique de tuile). `AssistMessage.data` continue de porter le résumé — c'est
/// la donnée que le modèle de Syncfusion exige — mais il n'est plus la voie
/// d'annonce.
///
/// ## Pourquoi un scope, et pas un paramètre de vue
///
/// Le résolveur doit atteindre **deux** consommateurs vivant dans deux paquets :
/// `ZChatMessageTile` (annonce réelle) et `ZSfAssistShellRenderer` (champ
/// `data`). Un paramètre passé à `ZChatConversationView` n'atteindrait pas le
/// second, et un champ du renderer Syncfusion n'atteindrait pas la première :
/// deux résolveurs, donc deux résumés promis à **diverger** — exactement le
/// motif CR-LEX-78 que ce dépôt a déjà payé. Le scope est **l'unique** point
/// d'injection ; le champ homonyme du renderer Syncfusion ne subsiste que comme
/// surcharge locale explicite.
///
/// AD-1 : ce scope ne peut pas vivre dans `ZcrudScope` — sa signature porte
/// `ZContentBlock`, donc du vocabulaire de `zcrud_chat_kernel`. Même arbitrage
/// que `ZChatRendererScope` et `ZChatShellRendererScope`.
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

  /// Seam d'annonce de l'hôte (AD-4/FR-26) : c'est par lui qu'un bloc **ouvert**
  /// (`'legalReference'`, `'flashcards'`, `'mindmap'`) devient annonçable et
  /// **localisable** — le kernel, pur-Dart, n'émet que de la donnée.
  ///
  /// `null` ⇒ résumé du kernel seul.
  final ZAccessibleTextResolver? resolver;

  /// `false` ⇒ la tuile **ne pose plus** son nœud d'annonce.
  ///
  /// 🔴 Ce n'est pas un confort : l'annonce du résumé impose
  /// `excludeSemantics: true` (sans quoi le résumé **et** le texte des blocs
  /// sont énoncés — le doublon mesuré sur la bande de pièces jointes). Un hôte
  /// dont le `ZChatRenderer` rend des blocs **interactifs** (un bouton dans une
  /// bulle) doit pouvoir garder la sémantique de ses enfants ; il coupe alors
  /// l'annonce ici et l'assume dans son propre renderer. Le défaut reste
  /// `true` : l'annonce est la règle, la muer est le geste explicite.
  final bool announce;

  /// Le scope le plus proche, ou `null` — **jamais de throw** (AD-10).
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
