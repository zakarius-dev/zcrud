/// Sélection multiple de conversations — `ZChatConversationSelection`
/// (CR-IFFD-39 ; AD-2, AD-15).
///
/// ## 🔴 Pourquoi un contrôleur EXTERNE, et pas un état interne à la liste
///
/// Mesuré sur les deux hôtes : le **backend** de lex expose une suppression par
/// **lot** (`batch_delete_conversations`, portée ici par
/// `ZChatConversationLifecyclePort.retireAll`) et **aucun client ne l'appelle** ;
/// IFFD n'a pas de sélection du tout. La sélection multiple est donc une
/// capacité **neuve** — et la première erreur à ne pas commettre est celle que
/// leur repliement de groupe commet déjà : créer le contrôleur **dans `build`**.
/// Un contrôleur recréé au rebuild perd la sélection à chaque frame utile
/// (arrivée d'une conversation, fin d'un flux, changement de recherche).
///
/// Le cycle de vie appartient donc à l'**hôte** : il le crée, il le `dispose`.
/// `ZChatConversationList` ne fait que l'écouter. C'est la même règle que
/// `ZChatController` et `ZChatAttachmentController` dans ce package.
///
/// ## Entrée et sortie sont EXPLICITES
///
/// [begin] entre en mode sélection (appui **long** côté vue), [clear] en sort.
/// Il n'existe **aucune** sortie implicite « quand la dernière case se
/// décoche » : un mode qui disparaît sous le doigt fait toucher la ligne
/// suivante à vide. [toggle] peut donc ramener le compte à zéro **sans** quitter
/// le mode — et [active] reste `true`.
library;

import 'package:flutter/foundation.dart';

/// Sélection multiple **observable** de conversations, par identité.
///
/// `ChangeNotifier` pur-Flutter (AD-2) : aucun gestionnaire d'état.
class ZChatConversationSelection extends ChangeNotifier {
  /// Construit une sélection **vide et inactive**.
  ZChatConversationSelection();

  final Set<String> _ids = <String>{};
  bool _active = false;

  /// `true` quand le mode sélection est engagé.
  ///
  /// 🔴 Indépendant de [count] : le mode reste actif même à zéro élément
  /// sélectionné (cf. la note de bibliothèque).
  bool get active => _active;

  /// Les identités sélectionnées — vue **non modifiable** (une copie mutable
  /// rendue à l'appelant permettrait d'écrire sans notifier).
  Set<String> get selectedIds => Set<String>.unmodifiable(_ids);

  /// Nombre d'éléments sélectionnés.
  int get count => _ids.length;

  /// `true` si [id] est sélectionnée (`null` ⇒ `false` — une conversation
  /// éphémère n'a pas d'identité, elle ne peut pas être sélectionnée).
  bool isSelected(String? id) => id != null && _ids.contains(id);

  /// Entre en mode sélection, en sélectionnant éventuellement [id].
  ///
  /// Idempotent : rappeler [begin] sur une sélection déjà active ajoute
  /// simplement [id].
  void begin([String? id]) {
    final bool wasActive = _active;
    final bool added = id != null && _ids.add(id);
    if (wasActive && !added) return;
    _active = true;
    notifyListeners();
  }

  /// Bascule [id]. Sans effet si la sélection n'est pas [active] — un appui
  /// simple hors mode sélection **ouvre** la conversation, il ne la coche pas.
  void toggle(String? id) {
    if (!_active || id == null) return;
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  /// Sort du mode sélection et vide la sélection — le geste **explicite**.
  void clear() {
    if (!_active && _ids.isEmpty) return;
    _active = false;
    _ids.clear();
    notifyListeners();
  }

  /// Retire des identités de la sélection **sans** quitter le mode.
  ///
  /// Pendant exact d'un `retireAll` réussi : les lignes disparaissent, le mode
  /// reste engagé pour l'action suivante.
  void unselectAll(Iterable<String> ids) {
    final int before = _ids.length;
    _ids.removeAll(ids);
    if (_ids.length != before) notifyListeners();
  }
}
