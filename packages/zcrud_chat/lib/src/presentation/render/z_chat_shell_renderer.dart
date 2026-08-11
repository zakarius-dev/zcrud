/// Port de rendu de la coquille (le cadre défilant) d'une conversation.
///
/// `ZChatShellRenderer` suit le patron exact de `ZListRenderer` : ce dépôt a
/// déjà résolu une fois le cas « une coquille de liste tierce remplace la
/// liste neutre ». La forme n'est pas réinventée.
///
/// | Implémentation | Paquet | Dépendance tirée |
/// |---|---|---|
/// | `ListView.builder` neutre | `zcrud_chat` (défaut) | aucune |
/// | grille de données dédiée | satellite dédié | Syncfusion |
/// | propre à l'hôte | l'application | ce qu'elle veut |
///
/// ## Ce qu'une coquille tierce ne peut pas faire perdre
///
/// Cette garantie tient à la place du seam dans l'arbre de
/// `ZChatConversationView`, pas à une promesse de documentation :
///
/// ```
/// _ZLiveRegion(liveAnnouncement)        <- AU-DESSUS du seam : hors de portée
///   └── zResolveChatShell(...)          <- LE SEAM : la coquille, et rien d'autre
///         └── request.itemBuilder(i)    <- EN DESSOUS : hors de portée
///               ├── ZChatMessageTile    (dépli inline, cible tactile, RTL)
///               │     └── ZChatBlockView -> seam de bloc de l'hôte
///               └── tuile de streaming  (tranche par requête, invariant AD-2)
/// ```
///
/// Un backend ne reçoit que la place du conteneur défilant. Il ne peut pas
/// retirer la région live (elle l'enveloppe), ni la tuile ni le dépli (ils
/// sont produits par une fabrique du socle qu'il ne peut que rappeler). La
/// seule dégradation possible est de ne pas appeler `itemBuilder`, auquel cas
/// il n'affiche rien du tout — une panne bruyante et non silencieuse.
///
/// ## Le contrat, en trois points (identiques à ceux de `ZChatRenderer`)
///
/// 1. `null` est une réponse valide et fonctionnelle : « je ne prends pas
///    cette conversation, garde la liste neutre ».
/// 2. `const` : le renderer est comparé par identité par
///    [ZChatShellRendererScope.updateShouldNotify].
/// 3. Invariant AD-10 : une implémentation ne lève pas pour dire qu'elle ne
///    sait pas rendre — elle rend `null`.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_shell_render_request.dart';

/// Abstraction de rendu du **cadre** d'une conversation, à partir d'une
/// [ZChatShellRenderRequest] **neutre**.
///
/// Injectée via `ZChatShellRendererScope`. Ce package ne connaît QUE ce
/// contrat : aucun type de backend (Syncfusion, coquille d'hôte) n'apparaît dans
/// sa signature.
abstract class ZChatShellRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZChatShellRenderer();

  /// Rend le cadre de [request], ou renvoie `null` pour **déléguer à la liste
  /// neutre** (`ListView.builder`).
  Widget? buildShell(BuildContext context, ZChatShellRenderRequest request);
}
