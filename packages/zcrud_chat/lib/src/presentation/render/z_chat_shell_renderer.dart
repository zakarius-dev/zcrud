/// Port de **rendu de COQUILLE de conversation** — `ZChatShellRenderer`
/// (CHAT-3b, AD-8/AD-57).
///
/// Patron **EXACT** de `ZListRenderer`
/// (`zcrud_core/lib/src/presentation/list/z_list_renderer.dart`) : ce dépôt a
/// déjà résolu **une fois** le cas « une coquille de liste tierce remplace la
/// liste neutre », pour `SfDataGrid`. La forme n'est pas réinventée.
///
/// | Implémentation | Paquet | Dépendance tirée |
/// |---|---|---|
/// | `ListView.builder` neutre | `zcrud_chat` (défaut) | **aucune** |
/// | `SfAIAssistView` | `zcrud_chat_syncfusion` | Syncfusion |
/// | propre à l'hôte | l'application | ce qu'elle veut |
///
/// ## 🔴 CE QU'UNE COQUILLE TIERCE NE PEUT PAS FAIRE PERDRE
///
/// C'est l'exigence qui donne son sens au lot, et elle n'est pas tenue par une
/// promesse de documentation : elle est tenue par la **PLACE du seam** dans
/// l'arbre de `ZChatConversationView`.
///
/// ```
/// _ZLiveRegion(liveAnnouncement)        ← AU-DESSUS du seam : hors de portée
///   └── zResolveChatShell(...)          ← LE SEAM : la coquille, et rien d'autre
///         └── request.itemBuilder(i)    ← EN DESSOUS : hors de portée
///               ├── ZChatMessageTile    (dépli inline, ≥ 48 dp, RTL)
///               │     └── ZChatBlockView → seam de BLOC de l'hôte
///               └── tuile de streaming  (tranche PAR REQUÊTE, SM-1)
/// ```
///
/// Un backend ne reçoit **que** la place du conteneur défilant. Il ne peut pas
/// retirer la région live (elle l'enveloppe), ni la tuile ni le dépli (ils sont
/// produits par une fabrique du socle qu'il ne peut que **rappeler**). La seule
/// dégradation qui lui reste est de **ne pas appeler** `itemBuilder` — auquel
/// cas il n'affiche rien du tout, panne bruyante et non silencieuse.
///
/// C'est la différence exacte avec le widget parallèle de C6, où la coquille
/// **était** la vue : tout ce qu'elle ne réimplémentait pas était perdu.
///
/// ## Le contrat, en trois points (identiques à ceux de `ZChatRenderer`)
///
/// 1. **`null` est une réponse VALIDE et FONCTIONNELLE** : « je ne prends pas
///    cette conversation, garde la liste neutre » — sémantique de
///    `zResolveGradient`.
/// 2. **`const`** : le renderer est comparé par identité par
///    [ZChatShellRendererScope.updateShouldNotify].
/// 3. **AD-10** : une implémentation ne lève pas pour dire qu'elle ne sait pas
///    rendre — elle rend `null`.
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
