/// Port de rendu de conversation.
///
/// `ZChatRenderer` suit le patron des ports de rendu déjà éprouvés du dépôt —
/// `ZListRenderer` (Syncfusion isolé dans `zcrud_list`) et
/// `ZReorderRenderer` — plutôt que d'en réinventer un.
///
/// | Implémentation | Où | Dépendance tirée |
/// |---|---|---|
/// | rendu neutre par défaut | ce paquet | aucune (Flutter seul) |
/// | rendu riche Markdown/LaTeX | satellite adossé à `zcrud_markdown` | Quill |
/// | grille de données dédiée | satellite dédié | Syncfusion |
/// | propre à l'hôte | l'application | ce qu'elle veut |
///
/// Cette couture évite qu'un consommateur qui n'affiche que du texte se voie
/// imposer Quill ou Syncfusion : un tiers n'entre jamais que derrière une
/// abstraction, avec un défaut zéro-dépendance qui reste pleinement
/// fonctionnel (invariant AD-1).
///
/// ## Le contrat, en trois points
///
/// 1. `null` est une réponse valide et fonctionnelle : « je ne prends pas ce
///    bloc, garde le rendu neutre » — la même sémantique que `null` pour un
///    dégradé optionnel (« garde l'accent uni »). C'est ce qui rend la prise
///    en charge partielle : un renderer d'hôte peut ne connaître que son
///    `kind` personnalisé sans avoir à réimplémenter les variantes fermées du
///    kernel.
/// 2. `const` : le renderer est comparé par identité par
///    [ZChatRendererScope.updateShouldNotify] ; le garder `const` ou mémoïsé
///    hors de `build` évite de reconstruire la conversation à chaque frame.
/// 3. Invariant AD-10 : une implémentation ne doit pas lever pour signaler
///    qu'elle ne sait pas rendre — elle rend `null`.
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
