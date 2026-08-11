/// Requête de rendu neutre d'un bloc de conversation.
///
/// Suit le patron de `ZListRenderRequest` (`zcrud_core`) : un value object
/// immuable, sans widget, sans dépendance lourde, qui est le seul vocabulaire
/// échangé avec le port de rendu [ZChatRenderer].
///
/// La requête ne porte volontairement aucun widget : c'est ce qui rend
/// interchangeables le rendu neutre zéro-dépendance de ce paquet et un
/// adaptateur tiers (Markdown riche, grille de données, ou rendu propre à
/// l'hôte), qui s'implémentent tous sur le même contrat. Si la requête
/// portait un `Widget` déjà construit, l'implémentation par défaut se
/// trouverait dans la signature du port, et le port ne serait plus qu'une
/// décoration.
///
/// Le texte en cours de streaming passe par cette même requête plutôt que par
/// un canal séparé, propre à chaque adaptateur — cf.
/// [ZChatBlockRenderRequest.streamingText] : c'est la seule façon d'éviter
/// qu'un adaptateur ré-ouvre un chemin parallèle pour la donnée qui change le
/// plus fréquemment dans une conversation.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

/// Ce qu'un renderer reçoit pour décider s'il prend en charge un bloc.
///
/// Immuable, égalité de **valeur** — cohérent avec `ZListRenderRequest`.
class ZChatBlockRenderRequest {
  /// Construit une requête de rendu de bloc.
  const ZChatBlockRenderRequest({
    required this.block,
    required this.message,
    this.blockIndex = 0,
    this.isStreaming = false,
    this.streamingText,
  });

  /// Le bloc à rendre (variante fermée du kernel, ou [ZCustomContentBlock]).
  ///
  /// Un renderer d'hôte reconnaît typiquement SON `kind` custom
  /// (`'legalReference'`, `'flashcards'`, `'mindmap'` — les trois variantes que
  /// `ZContentBlock` documente comme app-side) et rend `null` pour tout le
  /// reste, laissant le défaut neutre s'appliquer bloc par bloc.
  final ZContentBlock block;

  /// Le message porteur — donne au renderer le rôle, la provenance et les
  /// métadonnées sans qu'il ait à les re-chercher.
  final ZChatMessage message;

  /// Position du bloc dans `message.contentBlocks` (clé stable de rendu).
  final int blockIndex;

  /// `true` quand le bloc appartient à une réponse **encore en cours**.
  ///
  /// Un renderer coûteux (rendu Markdown complet, LaTeX, diagramme) peut s'en
  /// servir pour se **désactiver pendant le flux** et ne rendre qu'à la fin —
  /// décision qui lui appartient, que le socle n'impose pas.
  final bool isStreaming;

  /// Le canal à haute fréquence du texte en cours de rédaction, ou `null`
  /// quand le bloc n'est pas celui d'une réponse en vol.
  ///
  /// Une `ValueListenable`, jamais un `String` — exigence structurelle de
  /// l'invariant AD-2 : un `String` changerait la valeur de la requête à
  /// chaque jeton, donc reconstruirait tout ce qui est au-dessus (la liste,
  /// puis la conversation). Une `ValueListenable` est stable par identité (le
  /// contrôleur rend la même instance pour un `requestId` donné) : le
  /// renderer prend l'abonnement dans son propre sous-arbre, si bien qu'un
  /// jeton ne reconstruit que la tuile en cours.
  ///
  /// Un renderer qui l'ignore reste correct : le rendu neutre s'en charge.
  final ValueListenable<String>? streamingText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatBlockRenderRequest &&
          runtimeType == other.runtimeType &&
          block == other.block &&
          message == other.message &&
          blockIndex == other.blockIndex &&
          isStreaming == other.isStreaming &&
          // Identité, jamais valeur : comparer le TEXTE ici ferait de la requête
          // un objet qui change à chaque jeton — exactement ce que le type
          // `ValueListenable` existe pour empêcher.
          identical(streamingText, other.streamingText);

  @override
  int get hashCode => Object.hash(
    runtimeType,
    block,
    message,
    blockIndex,
    isStreaming,
    streamingText,
  );

  @override
  String toString() =>
      'ZChatBlockRenderRequest(kind: ${block.kind}, index: $blockIndex, '
      'streaming: $isStreaming)';
}
