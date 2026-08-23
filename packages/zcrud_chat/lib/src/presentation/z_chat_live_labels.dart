/// Libellés des annonces de région live du contrôleur de conversation.
///
/// Le socle n'écrit **aucune** phrase : chaque jalon d'un tour (début,
/// fin, annulation, échec, entrée en édition) est annoncé avec le texte que
/// l'hôte a fourni ici, et **seulement** s'il l'a fourni. Un libellé absent
/// rend le jalon **silencieux** — jamais un texte inventé dans une langue
/// par défaut.
///
/// Les deux jalons qui portent du contenu ([generationCompleted],
/// [generationCancelled]) reçoivent le texte accessible du message produit :
/// sans libellé, c'est **ce contenu** qui est annoncé (le plancher : une
/// réponse qui arrive ne reste jamais muette pour un lecteur d'écran).
library;

import 'package:flutter/foundation.dart';

/// Compose un libellé à partir du contenu accessible d'un message.
typedef ZChatContentLabel = String Function(String content);

/// Compose un libellé à partir de la clé **opaque** d'un artefact — l'hôte
/// y résout son propre nom d'artefact.
typedef ZChatArtifactLabel = String Function(String artifactKey);

/// Libellés **optionnels** des jalons d'un tour — tous nullables.
///
/// Objet de valeur immuable, injecté dans `ZChatController` à la
/// construction. Il n'a ni `BuildContext` ni locale : l'hôte le construit à
/// partir de sa propre localisation et le reconstruit si la langue change.
@immutable
class ZChatLiveLabels {
  /// Construit l'objet de libellés ; tout champ omis rend son jalon muet.
  const ZChatLiveLabels({
    this.generationStarted,
    this.generationCompleted,
    this.generationCancelled,
    this.generationFailed,
    this.editingStarted,
    this.artifactGenerationStarted,
    this.artifactGenerationCompleted,
    this.artifactGenerationFailed,
    this.artifactDeleted,
  });

  /// Aucun libellé : chaque jalon sans contenu est silencieux, les jalons
  /// avec contenu annoncent le contenu nu.
  static const ZChatLiveLabels none = ZChatLiveLabels();

  /// Annoncé dès qu'une génération est lancée (envoi, édition rejouée,
  /// régénération).
  final String? generationStarted;

  /// Annoncé à la fin d'un tour réussi, avec le texte accessible de la
  /// réponse. Omis : la réponse elle-même est annoncée.
  final ZChatContentLabel? generationCompleted;

  /// Annoncé quand l'utilisateur arrête une génération, avec le texte
  /// partiel conservé (éventuellement vide). Omis : le partiel est annoncé
  /// s'il existe, rien sinon.
  final ZChatContentLabel? generationCancelled;

  /// Annoncé quand un tour échoue sans l'avoir voulu. Omis : le partiel
  /// conservé est annoncé s'il existe, rien sinon.
  final String? generationFailed;

  /// Annoncé à l'entrée en mode édition d'un message envoyé.
  final String? editingStarted;

  /// Annoncé quand la génération d'un artefact est lancée, avec sa clé.
  final ZChatArtifactLabel? artifactGenerationStarted;

  /// Annoncé quand la génération d'un artefact a abouti, avec sa clé.
  final ZChatArtifactLabel? artifactGenerationCompleted;

  /// Annoncé quand la génération d'un artefact a échoué, avec sa clé.
  final ZChatArtifactLabel? artifactGenerationFailed;

  /// Annoncé quand un artefact a été supprimé, avec sa clé.
  final ZChatArtifactLabel? artifactDeleted;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatLiveLabels &&
          generationStarted == other.generationStarted &&
          generationCompleted == other.generationCompleted &&
          generationCancelled == other.generationCancelled &&
          generationFailed == other.generationFailed &&
          editingStarted == other.editingStarted &&
          artifactGenerationStarted == other.artifactGenerationStarted &&
          artifactGenerationCompleted == other.artifactGenerationCompleted &&
          artifactGenerationFailed == other.artifactGenerationFailed &&
          artifactDeleted == other.artifactDeleted;

  @override
  int get hashCode => Object.hash(
        generationStarted,
        generationCompleted,
        generationCancelled,
        generationFailed,
        editingStarted,
        artifactGenerationStarted,
        artifactGenerationCompleted,
        artifactGenerationFailed,
        artifactDeleted,
      );
}
