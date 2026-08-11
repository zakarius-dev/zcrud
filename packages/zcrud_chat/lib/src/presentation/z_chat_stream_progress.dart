/// Phase et progression grossière d'une requête de conversation.
///
/// Ce type ne porte aucun texte de réponse — c'est la raison d'être de sa
/// séparation d'avec la tranche `ZChatController.streamText` :
///
/// | Tranche | Fréquence | Qui l'écoute |
/// |---|---|---|
/// | `streamText(requestId)` | un signal par jeton (des centaines) | la bulle en cours de rédaction, elle seule |
/// | `progress(requestId)` | quelques signaux par tour | l'indicateur « réflexion », la pastille de sources, le quota |
///
/// Les fusionner ferait reconstruire l'indicateur de réflexion, la liste des
/// sources et la jauge de quota à chaque jeton reçu — exactement le défaut de
/// rebuild global que l'invariant AD-2 interdit.
///
/// `lastSequenceId` et le compteur d'événements ne sont pas exposés ici : ils
/// changent à chaque jeton et vivent dans l'état privé du contrôleur, sans
/// canal réactif — les publier ferait de `progress` une tranche à haute
/// fréquence sous un nom qui promet l'inverse.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Où en est une requête de conversation.
///
/// [cancelled] et [failed] sont distincts : un arrêt voulu n'est pas une
/// erreur. Les aplatir forcerait l'hôte à afficher un message d'échec sur un
/// geste volontaire de l'utilisateur (`ZChatStreamInterruptedFailure`
/// distingue déjà les deux par `cancelledByUser`).
enum ZChatPhase {
  /// Aucune requête en vol pour cette identité.
  idle,

  /// Le flux est ouvert et émet.
  streaming,

  /// Le flux a été coupé et une **reprise** est en cours, sous la **même**
  /// identité de requête (aucun rejeu du tour).
  resuming,

  /// Le tour s'est terminé sur son événement terminal.
  done,

  /// L'utilisateur a arrêté la génération (aucune erreur à afficher).
  cancelled,

  /// Le tour a échoué (`ZChatController.lastFailure` porte la cause typée).
  failed,
}

/// Progression **grossière** d'une requête — jamais son texte.
class ZChatStreamProgress {
  /// Construit une progression.
  const ZChatStreamProgress({
    this.phase = ZChatPhase.idle,
    this.thinking = const <ZChatThinkingStep>[],
    this.sources = const <ZChatSource>[],
    this.suggestions = const <ZChatSuggestion>[],
    this.quota,
    this.retrievalAgent,
    this.sourcesFound = 0,
    this.resumeAttempts = 0,
  });

  /// Phase courante.
  final ZChatPhase phase;

  /// Étapes de « réflexion » annoncées par le flux, dans l'ordre d'arrivée.
  final List<ZChatThinkingStep> thinking;

  /// Aperçu des sources annoncé par le flux (avant l'événement terminal).
  final List<ZChatSource> sources;

  /// Suggestions de suite annoncées par le flux.
  final List<ZChatSuggestion> suggestions;

  /// Dernier instantané de quota reçu, ou `null`.
  final ZChatQuotaSnapshot? quota;

  /// Nom technique du dernier agent de récupération annoncé, ou `null`.
  final String? retrievalAgent;

  /// Nombre de sources trouvées annoncé par la récupération.
  final int sourcesFound;

  /// Nombre de **reprises** déjà tentées pour cette requête (0 = premier essai).
  final int resumeAttempts;

  /// Copie modifiée — les paramètres omis sont **conservés**.
  ZChatStreamProgress copyWith({
    ZChatPhase? phase,
    List<ZChatThinkingStep>? thinking,
    List<ZChatSource>? sources,
    List<ZChatSuggestion>? suggestions,
    ZChatQuotaSnapshot? quota,
    String? retrievalAgent,
    int? sourcesFound,
    int? resumeAttempts,
  }) => ZChatStreamProgress(
    phase: phase ?? this.phase,
    thinking: thinking ?? this.thinking,
    sources: sources ?? this.sources,
    suggestions: suggestions ?? this.suggestions,
    quota: quota ?? this.quota,
    retrievalAgent: retrievalAgent ?? this.retrievalAgent,
    sourcesFound: sourcesFound ?? this.sourcesFound,
    resumeAttempts: resumeAttempts ?? this.resumeAttempts,
  );

  /// Égalité de valeur : un `ValueNotifier` qui reçoit une valeur égale ne
  /// notifie pas. Sans cet opérateur, republier une progression identique
  /// reconstruirait ses écoutants pour rien.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatStreamProgress &&
          phase == other.phase &&
          zListEquals(thinking, other.thinking) &&
          zListEquals(sources, other.sources) &&
          zListEquals(suggestions, other.suggestions) &&
          quota == other.quota &&
          retrievalAgent == other.retrievalAgent &&
          sourcesFound == other.sourcesFound &&
          resumeAttempts == other.resumeAttempts;

  @override
  int get hashCode => Object.hash(
    phase,
    Object.hashAll(thinking),
    Object.hashAll(sources),
    Object.hashAll(suggestions),
    quota,
    retrievalAgent,
    sourcesFound,
    resumeAttempts,
  );

  @override
  String toString() =>
      'ZChatStreamProgress($phase, thinking: ${thinking.length}, '
      'sources: ${sources.length}, suggestions: ${suggestions.length}, '
      'resumeAttempts: $resumeAttempts)';
}
