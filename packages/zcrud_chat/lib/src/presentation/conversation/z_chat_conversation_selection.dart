/// Sélection multiple de conversations.
///
/// ## Pourquoi un contrôleur externe, et pas un état interne à la liste
///
/// Un contrôleur créé dans `build` perd la sélection à chaque frame utile
/// (arrivée d'une conversation, fin d'un flux, changement de recherche) —
/// c'est la même erreur structurelle que pour le repliement de groupe.
///
/// Le cycle de vie appartient donc à l'hôte : il le crée, il le `dispose`.
/// `ZChatConversationList` ne fait que l'écouter. C'est la même règle que
/// `ZChatController` et `ZChatAttachmentController` dans ce paquet.
///
/// ## Entrée et sortie sont explicites
///
/// [begin] entre en mode sélection (typiquement un appui long côté vue),
/// [clear] en sort. Il n'existe aucune sortie implicite « quand la dernière
/// case se décoche » : un mode qui disparaît sous le doigt ferait toucher la
/// ligne suivante à vide. [toggle] peut donc ramener le compte à zéro sans
/// quitter le mode — [active] reste `true`.
///
/// ## Le mode est commandable de l'extérieur
///
/// [ZChatConversationSelection.activeController] permet à l'hôte de piloter
/// l'entrée et la sortie du mode sélection depuis sa propre interface (une
/// barre d'application, une navigation), en plus du geste natif dans la
/// liste. Le contrôleur externe commande le mode, jamais le contenu de la
/// sélection : les identités restent la propriété de cet objet ([toggle],
/// [unselectAll]). Les deux ne se touchent qu'en un point : sortir du mode
/// vide toujours la sélection, quel que soit le chemin de sortie emprunté.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Sélection multiple observable de conversations, par identité.
///
/// `ChangeNotifier` pur-Flutter (invariant AD-2) : aucun gestionnaire d'état.
class ZChatConversationSelection extends ChangeNotifier {
  /// Construit une sélection vide et inactive.
  ///
  /// [activeController] : pilotage externe du mode — `null` signifie que la
  /// sélection se gouverne seule (comportement par défaut). Fourni, il
  /// devient la source de vérité de [active] : aucun miroir n'est conservé
  /// ici (cf. [ZDisplayStateBinding]), donc les deux états ne peuvent pas
  /// diverger. [begin] et [clear] écrivent à travers lui, et
  /// [ChangeNotifier.notifyListeners] est émis dans les deux sens.
  ///
  /// Le contrôleur doit être possédé hors de `build`
  /// ([ZDisplayStateOwnerMixin]) — la même règle que pour cette sélection
  /// elle-même et pour `ZChatGroupExpansion` : un contrôleur créé dans
  /// `build` est inerte dès le premier rebuild.
  ZChatConversationSelection({ZToggleController? activeController}) {
    _activeBinding = ZDisplayStateBinding<bool>(
      consumer: this,
      initialValue: false,
    )..bind(activeController);
    _activeBinding.listenable.addListener(_onActiveChanged);
  }

  final Set<String> _ids = <String>{};

  /// État interne par défaut, contrôleur de l'hôte quand il y en a un.
  late final ZDisplayStateBinding<bool> _activeBinding;

  /// `true` quand le mode sélection est engagé.
  ///
  /// Indépendant de [count] : le mode reste actif même à zéro élément
  /// sélectionné (cf. la note de bibliothèque).
  ///
  /// Lu à la source : quand un `activeController` est fourni, c'est sa
  /// valeur, jamais une copie tenue à jour.
  bool get active => _activeBinding.value;

  /// Voie unique de réaction à un changement de mode, d'où qu'il vienne :
  /// [begin], [clear], ou une commande de l'hôte sur son contrôleur.
  ///
  /// C'est ici — et seulement ici — que l'invariant « sortir du mode vide la
  /// sélection » est appliqué. Le placer dans [clear] l'aurait laissé
  /// **inappliqué** sur le chemin de l'hôte : la barre aurait disparu en
  /// laissant des identités cochées derrière elle, qu'un `begin` ultérieur
  /// aurait ressuscitées.
  void _onActiveChanged() {
    if (!_activeBinding.value) _ids.clear();
    notifyListeners();
  }

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
    final bool wasActive = active;
    final bool added = id != null && _ids.add(id);
    if (wasActive && !added) return;
    if (!wasActive) {
      // Écrit **à la source** ⇒ la notification est émise par [_onActiveChanged],
      // et le contrôleur de l'hôte voit l'appui long.
      _activeBinding.value = true;
      return;
    }
    notifyListeners();
  }

  /// Bascule [id]. Sans effet si la sélection n'est pas [active] — un appui
  /// simple hors mode sélection **ouvre** la conversation, il ne la coche pas.
  void toggle(String? id) {
    if (!active || id == null) return;
    if (!_ids.remove(id)) _ids.add(id);
    notifyListeners();
  }

  /// Sort du mode sélection et vide la sélection — le geste **explicite**.
  void clear() {
    if (!active) {
      if (_ids.isEmpty) return;
      _ids.clear();
      notifyListeners();
      return;
    }
    // Le vidage et la notification sont la charge de [_onActiveChanged] : une
    // seconde voie ferait diverger la sortie interne de la sortie commandée.
    _activeBinding.value = false;
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

  @override
  void dispose() {
    // La liaison ne dispose jamais le contrôleur de l'hôte : il ne nous
    // appartient pas (son propriétaire est un `State` de l'hôte).
    _activeBinding.listenable.removeListener(_onActiveChanged);
    _activeBinding.dispose();
    super.dispose();
  }
}
