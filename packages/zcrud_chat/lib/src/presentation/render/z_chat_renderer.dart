/// Port de **rendu de conversation** — `ZChatRenderer` (CHAT-3, AD-8/AD-57).
///
/// Patron **strict** des deux ports déjà en production dans ce dépôt :
/// `ZListRenderer` (`zcrud_core/lib/src/presentation/list/z_list_renderer.dart`,
/// Syncfusion isolé dans `zcrud_list`) et `ZReorderRenderer`
/// (`zcrud_core/lib/src/presentation/reorder/z_reorder_renderer.dart`). La
/// forme n'est pas réinventée : le dépôt en a une, éprouvée.
///
/// | Implémentation | Paquet | Dépendance tirée |
/// |---|---|---|
/// | rendu neutre par défaut | `zcrud_chat` (ici) | **aucune** (Flutter seul) |
/// | rendu riche Markdown/LaTeX | satellite adossé à `zcrud_markdown` | Quill |
/// | vue `SfAIAssistView` | lot C6, satellite dédié | Syncfusion |
/// | propre à l'hôte | l'application | ce qu'elle veut |
///
/// 🔴 **Pourquoi une couture, et pas une dépendance directe à
/// `zcrud_markdown`.** `zcrud_markdown` tire Quill. Le brancher en dur ici
/// imposerait Quill — et sa chaîne d'embeds LaTeX/tables — à **tout**
/// consommateur du chat, y compris celui qui n'affiche que du texte. C'est
/// exactement la raison d'être de `ZListRenderer` (SM-5 : un consommateur qui
/// n'importe pas `zcrud_list` ne tire aucun Syncfusion), et AD-57 en fait la
/// règle : tiers admis **derrière une abstraction**, avec un **défaut
/// zéro-dépendance fonctionnel**. Le rendu riche existant n'est donc pas
/// réécrit — il est **atteignable** par cette couture.
///
/// 🔵 **Ce qui rend l'abstraction possible, mesuré.** IFFD ne consomme de
/// `SfAIAssistView` que `messages:`, `composer:`, `placeholderBehavior` et
/// `placeholderBuilder` (`chatbot_conversation_screen.dart:3423-3436`) : le
/// **squelette de liste seulement**, tout le contenu passant par ses propres
/// builders. La surface réellement dépendue est **mince** — un port neutre la
/// couvre, pour IFFD comme pour lex.
///
/// ## Le contrat, en trois points
///
/// 1. **`null` est une réponse VALIDE et FONCTIONNELLE** : « je ne prends pas ce
///    bloc, garde le rendu neutre ». C'est la sémantique exacte de
///    `zResolveGradient` (`null` = « aucun dégradé, garde l'accent uni »), et
///    c'est ce qui rend la prise en charge **partielle** : un renderer d'hôte
///    peut ne connaître que son `kind` custom sans avoir à réimplémenter les
///    neuf variantes fermées du kernel.
/// 2. **`const`** : le renderer est comparé par identité par
///    [ZChatRendererScope.updateShouldNotify] ; le garder `const` ou mémoïsé
///    hors de `build` évite de reconstruire la conversation à chaque frame.
/// 3. **AD-10** : une implémentation ne doit pas lever pour signaler qu'elle ne
///    sait pas rendre — elle rend `null`.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_render_request.dart';

/// Abstraction de rendu d'un bloc de conversation, à partir d'une
/// [ZChatBlockRenderRequest] **neutre**.
///
/// Injectée via `ZChatRendererScope`. Ce package ne connaît QUE ce contrat :
/// aucun type de backend (Quill, Syncfusion, moteur Markdown) n'apparaît dans
/// sa signature.
abstract class ZChatRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZChatRenderer();

  /// Rend [request], ou renvoie `null` pour **déléguer au rendu neutre**.
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request);
}
