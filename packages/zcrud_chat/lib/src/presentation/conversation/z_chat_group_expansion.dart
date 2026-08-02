/// Repliement de groupes — `ZChatGroupExpansion` (CR-IFFD-39 ; AD-2).
///
/// ## 🔴 Le bug qu'on refuse de reproduire
///
/// La hiérarchie de conversations d'IFFD est repliable, et son contrôleur
/// d'expansion est **créé dans `build`**. Conséquence : chaque rebuild — donc
/// chaque arrivée de message, chaque fin de génération, chaque frappe dans la
/// recherche — **réinitialise le repliement**. Un groupe replié se rouvre tout
/// seul, et l'utilisateur n'a aucun moyen de le savoir.
///
/// Le correctif structurel n'est pas « mémoriser l'état ailleurs » : c'est que
/// l'état de repliement **n'appartienne pas au widget**. Il est donc porté par
/// ce `ChangeNotifier`, **créé et disposé par l'hôte**, exactement comme
/// `ZChatConversationSelection`. `ZChatConversationList` ne fait que l'écouter ;
/// elle n'en fabrique **jamais** un par défaut — sans contrôleur, les groupes
/// sont simplement toujours dépliés (défaut fonctionnel, AD-57).
///
/// ## La clé de groupe est OPAQUE
///
/// La hiérarchie d'IFFD tient dans trois champs (`folderId`, `subFolderId`,
/// `documentId`) qui sont des **spécificités d'hôte** : les modéliser ici
/// interdirait toute autre hiérarchie. La clé est donc un `Object?` quelconque,
/// produit par l'hôte (`Object? Function(ZChatConversation)`) — un `String`, un
/// enregistrement, une date tronquée, ce qu'il veut. Le socle n'en fait que deux
/// choses : l'égalité et le hachage.
library;

import 'package:flutter/foundation.dart';

/// État de repliement, indexé par **clé de groupe opaque**.
///
/// Le défaut est **déplié** : un socle qui replierait tout au premier montage
/// cacherait des conversations que personne n'a demandé à cacher.
class ZChatGroupExpansion extends ChangeNotifier {
  /// Construit un état de repliement.
  ///
  /// [collapsedByDefault] `true` inverse le défaut — utile pour une liste
  /// d'archives, jamais pour la liste principale.
  ZChatGroupExpansion({this.collapsedByDefault = false});

  /// `true` si un groupe jamais visité est considéré **replié**.
  final bool collapsedByDefault;

  /// Clés dont l'état **diffère** du défaut. Stocker les exceptions plutôt que
  /// tous les groupes évite d'avoir à énumérer des groupes qui n'existent pas
  /// encore (la liste est paginée : ils arrivent au fil de l'eau).
  final Set<Object?> _flipped = <Object?>{};

  /// `true` si le groupe [key] est déplié.
  bool isExpanded(Object? key) =>
      _flipped.contains(key) ? collapsedByDefault : !collapsedByDefault;

  /// Bascule le groupe [key].
  void toggle(Object? key) {
    if (!_flipped.remove(key)) _flipped.add(key);
    notifyListeners();
  }

  /// Force l'état du groupe [key].
  void setExpanded(Object? key, {required bool expanded}) {
    if (isExpanded(key) == expanded) return;
    toggle(key);
  }

  /// Réinitialise tous les groupes au défaut.
  void reset() {
    if (_flipped.isEmpty) return;
    _flipped.clear();
    notifyListeners();
  }
}
