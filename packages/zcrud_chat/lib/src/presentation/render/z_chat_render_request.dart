/// Requête de rendu **neutre** d'un bloc de conversation — CHAT-3.
///
/// origine: patron strict de `ZListRenderRequest`
/// (`zcrud_core/lib/src/presentation/list/z_list_render_request.dart`) : un
/// value object **immuable, sans widget, sans dépendance lourde**, qui est le
/// SEUL vocabulaire échangé avec le port de rendu [ZChatRenderer].
///
/// 🔴 **Pourquoi la requête ne porte AUCUN widget.** C'est ce qui rend deux
/// backends interchangeables : le rendu neutre zéro-dépendance de ce package,
/// et un adaptateur tiers (Syncfusion — lot C6 —, `zcrud_markdown`/Quill, ou
/// l'hôte lui-même) s'implémentent sur le **même** contrat. Si la requête
/// portait un `Widget` déjà construit, l'implémentation par défaut se trouverait
/// dans la signature du port et le port ne serait plus qu'une décoration.
///
/// 🔴 **CHAT-3b — le texte en cours de streaming passe désormais PAR la
/// couture.** Constat du lot C6 : la requête portait `isStreaming` mais **aucun
/// canal pour le texte en train d'arriver**. L'adaptateur a donc dû sortir ce
/// texte de la couture et le passer en paramètre de sa propre vue — c'est-à-dire
/// rouvrir un chemin parallèle pour la seule donnée qui bouge 300 fois par tour.
/// [ZChatBlockRenderRequest.streamingText] ferme ce chemin.
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

  /// 🔴 Le **canal à haute fréquence** du texte en cours de rédaction, ou `null`
  /// quand le bloc n'est pas celui d'une réponse en vol.
  ///
  /// **Une `ValueListenable`, JAMAIS un `String`** — et c'est structurel, pas
  /// cosmétique (SM-1, objectif produit n°1) :
  /// * un `String` changerait la **valeur de la requête** à chaque jeton, donc
  ///   reconstruirait tout ce qui est au-dessus (la liste, puis la
  ///   conversation) : le bug historique, réintroduit par la couture elle-même ;
  /// * une `ValueListenable` est **stable par identité** (le contrôleur rend la
  ///   même instance pour un `requestId` donné, patron
  ///   `ZFormController.fieldListenable`). Le renderer prend l'abonnement
  ///   **DANS son propre sous-arbre** : un jeton ne reconstruit que la tuile en
  ///   cours.
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
