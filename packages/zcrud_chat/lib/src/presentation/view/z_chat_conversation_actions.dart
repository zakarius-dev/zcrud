/// Actions de conversation déclarées en descripteurs.
///
/// ## Pourquoi aucune action n'est codée en dur dans la tuile
///
/// Les champs qu'une action manipule (épinglage, archivage…) varient d'un
/// hôte à l'autre : en coder un en dur dans la tuile le rendrait mort chez un
/// hôte dont le backend ne le connaît pas — un bouton qui écrit un champ que
/// personne ne lit.
///
/// La tuile ne connaît donc aucune action. Elle reçoit une liste de
/// [ZChatConversationAction], et n'en rend aucune par défaut.
///
/// ## « Absente si son callback est nul » — la fabrique, pas un drapeau
///
/// [zChatConversationActions] n'émet un descripteur que si le callback
/// correspondant est non nul : ne pas passer le callback est le signal
/// d'absence. Un hôte sans épinglage n'a rien à désactiver, rien à
/// configurer, et ne peut pas se tromper de valeur par défaut.
///
/// ## Les huit ports de conversation du kernel, et par où ils entrent
///
/// | Port (`z_chat_conversation_ports.dart`) | Entrée de cette surface |
/// |---|---|
/// | `searchConversations` | `ZChatConversationList.searchTerm` + `matcher` + `onLoadMore`/`hasMore` (le curseur reste chez l'hôte) |
/// | `setPinned` | [zChatConversationActions] `onSetPinned` — **un** callback, `pinned` en paramètre, comme le port |
/// | `share` | `onShare` |
/// | `sharedConversation` | hors liste : l'instantané public se rend avec `ZChatConversationView` |
/// | `retire` | `onRetire` (+ [ZChatConversationAction.confirm]) |
/// | `restore` | `onRestore` |
/// | `trimAfter` | `onTrim` |
/// | `retireAll` | `ZChatConversationList.onRetireSelected` (barre de sélection) |
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_chat_labels.dart';

/// Construit l'icône d'une action — couture d'hôte (le socle n'embarque aucun
/// catalogue d'icônes : `material` lui est interdit).
typedef ZChatActionIconBuilder = Widget? Function(BuildContext context);

/// Un descripteur d'action de conversation. Immuable, sans widget.
///
/// Son identité est sa clé de libellé ([labelKey]). Un champ `id` séparé
/// aurait dupliqué la même information sous deux noms — et aurait exigé un
/// littéral porteur de mot dans un fichier de rendu, ce qu'une discipline
/// stricte de source interdit : c'est la porte par laquelle un libellé
/// finit par entrer codé en dur.
@immutable
class ZChatConversationAction {
  /// Construit un descripteur.
  const ZChatConversationAction({
    required this.labelKey,
    required this.onInvoke,
    this.iconBuilder,
    this.isVisible,
    this.isDestructive = false,
    this.confirm,
  });

  /// Clé de libellé, résolue par `zChatLabel` — **jamais** un libellé. Sert
  /// aussi d'identité (clé de widget, tests, télémétrie d'hôte).
  final String labelKey;

  /// Ce que l'action fait. Le socle ne sait pas ce que c'est, et c'est voulu :
  /// il n'y a aucune navigation ici, seulement un rappel (invariant AD-11).
  final void Function(ZChatConversation conversation) onInvoke;

  /// Icône optionnelle. `null` signifie le libellé seul (défaut fonctionnel
  /// sans configuration requise).
  final ZChatActionIconBuilder? iconBuilder;

  /// Prédicat de visibilité par conversation, ou `null` (toujours visible).
  ///
  /// Un prédicat, pas un champ : la condition de visibilité d'un hôte peut
  /// venir d'un préfixe dans le titre, d'une permission calculée ailleurs —
  /// ce ne sont pas des champs propres, et les modéliser figerait dans le
  /// socle la forme particulière d'un hôte donné.
  final bool Function(ZChatConversation conversation)? isVisible;

  /// `true` pour une action destructive — le socle ne la rend pas
  /// différemment (aucune couleur en dur) ; il l'expose pour que l'hôte le
  /// fasse et pour que [confirm] ait un sens documenté.
  final bool isDestructive;

  /// Confirmation optionnelle. `null` signifie aucune confirmation, et c'est
  /// un choix de l'hôte, pas un oubli du socle.
  ///
  /// Le socle ne promet aucune fonctionnalité d'annulation qu'il ne tient
  /// pas : il rend l'annulation triviale à implémenter (le retrait est soft,
  /// et `onRestore` la ramène) sans la forcer.
  final Future<bool> Function(BuildContext context)? confirm;

  /// `true` si l'action doit être rendue pour [conversation].
  bool visibleFor(ZChatConversation conversation) =>
      isVisible?.call(conversation) ?? true;

  @override
  String toString() => 'ZChatConversationAction($labelKey)';
}

/// Fabrique les descripteurs des opérations du kernel — **uniquement** ceux dont
/// le callback est fourni.
///
/// L'ordre est stable et documenté : épinglage, partage, troncature,
/// restauration, retrait. Le retrait est **dernier** parce qu'il est le seul
/// destructif.
List<ZChatConversationAction> zChatConversationActions({
  void Function(ZChatConversation conversation, {required bool pinned})?
  onSetPinned,
  void Function(ZChatConversation conversation)? onShare,
  void Function(ZChatConversation conversation)? onTrim,
  void Function(ZChatConversation conversation)? onRestore,
  void Function(ZChatConversation conversation)? onRetire,
  Future<bool> Function(BuildContext context)? confirmRetire,
  bool Function(ZChatConversation conversation)? isRetired,
  ZChatActionIconBuilder? pinIcon,
  ZChatActionIconBuilder? shareIcon,
  ZChatActionIconBuilder? trimIcon,
  ZChatActionIconBuilder? restoreIcon,
  ZChatActionIconBuilder? retireIcon,
}) {
  final List<ZChatConversationAction> out = <ZChatConversationAction>[];
  if (onSetPinned != null) {
    // Deux descripteurs, un seul verbe : le libellé varie, l'appel non. Cela
    // suit l'invariant du port (`setPinned(id, pinned: …)`) — une seule
    // méthode de service plutôt que deux quasi identiques qui divergeraient
    // tôt ou tard sur un détail de filtrage.
    out.add(
      ZChatConversationAction(
        labelKey: kZChatLabelPin,
        iconBuilder: pinIcon,
        isVisible: (ZChatConversation c) => !c.pinned,
        onInvoke: (ZChatConversation c) => onSetPinned(c, pinned: true),
      ),
    );
    out.add(
      ZChatConversationAction(
        labelKey: kZChatLabelUnpin,
        iconBuilder: pinIcon,
        isVisible: (ZChatConversation c) => c.pinned,
        onInvoke: (ZChatConversation c) => onSetPinned(c, pinned: false),
      ),
    );
  }
  if (onShare != null) {
    out.add(
      ZChatConversationAction(
        labelKey: kZChatLabelShare,
        iconBuilder: shareIcon,
        onInvoke: onShare,
      ),
    );
  }
  if (onTrim != null) {
    out.add(
      ZChatConversationAction(
        labelKey: kZChatLabelTrim,
        iconBuilder: trimIcon,
        onInvoke: onTrim,
      ),
    );
  }
  if (onRestore != null) {
    out.add(
      ZChatConversationAction(
        labelKey: kZChatLabelRestore,
        iconBuilder: restoreIcon,
        // Sans prédicat d'hôte, la restauration reste visible : le socle ne sait
        // pas lire l'état de retrait (il vit hors-entité, dans `ZSyncMeta`), et
        // masquer par défaut une action qu'on ne sait pas évaluer la rendrait
        // inatteignable.
        isVisible: isRetired,
        onInvoke: onRestore,
      ),
    );
  }
  if (onRetire != null) {
    out.add(
      ZChatConversationAction(
        labelKey: kZChatLabelRetire,
        iconBuilder: retireIcon,
        isDestructive: true,
        confirm: confirmRetire,
        isVisible: isRetired == null
            ? null
            : (ZChatConversation c) => !isRetired(c),
        onInvoke: onRetire,
      ),
    );
  }
  return out;
}

/// Clés des descripteurs que [zChatConversationActions] sait produire — exposées
/// pour que les tests d'hôte et les gardes n'aient pas à les recopier.
const List<String> kZChatConversationActionKeys = <String>[
  kZChatLabelPin,
  kZChatLabelUnpin,
  kZChatLabelShare,
  kZChatLabelTrim,
  kZChatLabelRestore,
  kZChatLabelRetire,
];
