/// Familles d'échec propres à l'IA — CHAT-1 (AD-5, AD-10, AD-11).
///
/// ## 🔴 Le défaut que ce fichier ferme
///
/// IFFD n'a **aucune** gestion d'erreur typée sur son chemin IA : le texte brut
/// de l'exception est poussé dans le corps du message et **affiché comme s'il
/// s'agissait de la réponse de l'assistant**. Un quota épuisé, une modération,
/// une fenêtre de contexte dépassée et une panne réseau y sont donc **le même
/// événement** — une chaîne. L'hôte ne peut ni réessayer à bon escient, ni
/// informer correctement, ni masquer une capacité absente.
///
/// ## 🔴 Ce qui est CÂBLÉ, pas recréé
///
/// | Besoin | Type **EXISTANT** réutilisé | Chemin |
/// |---|---|---|
/// | Quota IA dépassé (+ `retryAfter`) | `ZQuotaExceededFailure` | `zcrud_core/lib/src/domain/failures/z_failure.dart` |
/// | Capacité non implémentée par l'hôte | `ZUnsupportedOperationFailure` | idem |
/// | Panne backend | `ZServerFailure` | idem |
/// | Règle métier violée | `ZDomainFailure` | idem |
/// | Confirmation refusée | `ZChatActionNotConfirmedFailure` (CHAT-0b) | `action/z_chat_action_failure.dart` |
///
/// `ZQuotaExceededFailure` **existait déjà et n'avait aucun consommateur** :
/// [zChatFailureFromWire] est son premier câblage réel. La garde **G-C4** le
/// prouve dans les deux sens — grep NÉGATIF (aucune failure de quota
/// redéclarée ailleurs que dans le cœur) et grep POSITIF (ce fichier la
/// construit vraiment).
///
/// Ne sont créées ici que les **trois** familles qui manquaient réellement :
/// modération, limite de contexte, flux interrompu.
///
/// ## Hiérarchie PLATE
///
/// Les trois nouveaux types étendent `ZFailure` **directement** — comme
/// `ZDomainFailure`, `ZQuotaExceededFailure` et `ZUnsupportedOperationFailure`,
/// qui sont des **frères**. Aucun n'étend l'autre : le triage se fait par `is`,
/// jamais par un `switch` exhaustif (AD-4 : `ZFailure` n'est pas `sealed`).
library;

import 'package:zcrud_core/domain.dart';

/// Le contenu a été **refusé** (entrée ou sortie) par la modération du
/// fournisseur — ce n'est ni une panne, ni un quota.
///
/// La distinction change ce que l'hôte doit faire : réessayer à l'identique est
/// **garanti inutile**, et le texte du fournisseur ne doit **jamais** être
/// rendu comme une réponse d'assistant (défaut IFFD). [category] est un motif
/// **opaque** (`'violence'`, `'self_harm'`, …), transporté verbatim et jamais
/// interprété par zcrud : aucun catalogue, aucun libellé, aucun `switch`.
/// [onInput] distingue « votre demande a été refusée » de « la réponse produite
/// a été retenue » — deux messages utilisateur opposés.
class ZChatModerationFailure extends ZFailure {
  /// Construit un refus de modération.
  const ZChatModerationFailure(
    super.message, {
    this.category,
    this.onInput = true,
    this.code,
  });

  /// Motif **opaque** du refus, ou `null` si le fournisseur n'en donne pas.
  final String? category;

  /// `true` si c'est la **demande** qui a été refusée ; `false` si c'est la
  /// **réponse** produite qui a été retenue.
  final bool onInput;

  /// Code **VERBATIM** du fournisseur, ou `null` (cf. [ZChatProviderFailure]).
  final String? code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatModerationFailure &&
          other.message == message &&
          other.category == category &&
          other.onInput == onInput &&
          other.code == code;

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, category, onInput, code);

  @override
  String toString() =>
      'ZChatModerationFailure($message, '
      'category: $category, onInput: $onInput)';
}

/// La **fenêtre de contexte** du modèle est dépassée.
///
/// Réaction attendue : **réduire** (élaguer l'historique, retirer des fragments
/// de contexte, découper les notes) — pas réessayer à l'identique, pas afficher
/// une panne. [tokenCount]/[tokenLimit] sont `null` quand le fournisseur ne les
/// expose pas ; leur absence ne doit jamais être lue comme « ça tient ».
class ZChatContextLimitFailure extends ZFailure {
  /// Construit un dépassement de fenêtre de contexte.
  const ZChatContextLimitFailure(
    super.message, {
    this.tokenCount,
    this.tokenLimit,
    this.code,
  });

  /// Taille soumise, si connue.
  final int? tokenCount;

  /// Plafond du modèle, si connu.
  final int? tokenLimit;

  /// Code **VERBATIM** du fournisseur, ou `null` (cf. [ZChatProviderFailure]).
  final String? code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatContextLimitFailure &&
          other.message == message &&
          other.tokenCount == tokenCount &&
          other.tokenLimit == tokenLimit &&
          other.code == code;

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, tokenCount, tokenLimit, code);

  @override
  String toString() =>
      'ZChatContextLimitFailure($message, '
      'tokenCount: $tokenCount, tokenLimit: $tokenLimit)';
}

/// Le **flux a été interrompu** avant son événement terminal.
///
/// Porte [requestId] — l'identité du [ZChatRequestToken] de la requête coupée,
/// pour que l'hôte sache **laquelle** de ses requêtes concurrentes s'est
/// arrêtée (le défaut IFFD étant justement de ne pas pouvoir le dire).
/// [cancelledByUser] sépare l'arrêt **voulu** (aucune erreur à afficher) de la
/// coupure **subie** (réseau, timeout) : les aplatir forcerait l'hôte à
/// afficher une erreur sur un geste volontaire. [eventsReceived] dit si un
/// contenu partiel a été rendu et mérite d'être conservé.
class ZChatStreamInterruptedFailure extends ZFailure {
  /// Construit une interruption de flux.
  const ZChatStreamInterruptedFailure(
    super.message, {
    required this.requestId,
    this.eventsReceived = 0,
    this.cancelledByUser = false,
    this.code,
  });

  /// Identité de la requête coupée (`ZChatRequestToken.requestId`).
  final String requestId;

  /// Nombre d'événements déjà émis avant la coupure.
  final int eventsReceived;

  /// `true` si l'utilisateur a annulé (arrêt voulu, pas une erreur).
  final bool cancelledByUser;

  /// Code **VERBATIM** du fournisseur, ou `null` (cf. [ZChatProviderFailure]).
  final String? code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatStreamInterruptedFailure &&
          other.message == message &&
          other.requestId == requestId &&
          other.eventsReceived == eventsReceived &&
          other.cancelledByUser == cancelledByUser &&
          other.code == code;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    message,
    requestId,
    eventsReceived,
    cancelledByUser,
    code,
  );

  @override
  String toString() =>
      'ZChatStreamInterruptedFailure($message, '
      'requestId: $requestId, eventsReceived: $eventsReceived, '
      'cancelledByUser: $cancelledByUser)';
}

/// Échec **du fournisseur**, dont le seul renseignement exploitable est son
/// **code**.
///
/// ## 🔴 L'amélioration réelle sur la référence
///
/// Le serveur de lex émet un code d'erreur **typé** dans le flux SSE
/// (`{"type":"error","code":…}`, 14 codes, dont 4 propres au streaming :
/// `AGENT_TIMEOUT`, `LLM_ERROR`, `STREAM_INTERRUPTED`, `GRAPH_ERROR`) — et
/// **son propre client Dart le JETTE** : `ChatErrorEvent`
/// (`lex_core/lib/domain/entities/chat_stream_event.dart`) ne porte qu'un
/// `message`. L'information la plus actionnable du protocole est détruite au
/// franchissement de la frontière, et l'hôte se retrouve à distinguer un
/// timeout d'agent d'une erreur de graphe **en comparant des phrases**.
///
/// ⇒ zcrud **conserve le code**, toujours : soit dans la famille typée qui lui
/// correspond ([ZChatModerationFailure.code], [ZChatContextLimitFailure.code],
/// [ZChatStreamInterruptedFailure.code]), soit ici quand aucune famille ne
/// s'applique. Le code est **opaque** : aucun catalogue fermé, aucun `switch`
/// exhaustif, aucun libellé — un backend qui en ajoute un demain traverse
/// intact.
///
/// ⚠️ Seul `ZQuotaExceededFailure` ne porte pas de code : c'est un type
/// **EXISTANT du cœur** qu'on réutilise sans le modifier (le type lui-même dit
/// déjà ce que le code disait).
class ZChatProviderFailure extends ZFailure {
  /// Construit un échec fournisseur en conservant son [code].
  const ZChatProviderFailure(super.message, {required this.code});

  /// Code **VERBATIM** du fournisseur (`'AGENT_TIMEOUT'`, `'LLM_ERROR'`,
  /// `'GRAPH_ERROR'`…), transporté sans interprétation.
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatProviderFailure &&
          other.message == message &&
          other.code == code;

  @override
  int get hashCode => Object.hash(runtimeType, message, code);

  @override
  String toString() => 'ZChatProviderFailure($message, code: $code)';
}

/// Codes d'erreur **neutres** du fil IA (camelCase, comme toute valeur d'enum
/// persistée du dépôt).
///
/// Ce ne sont **pas** des libellés : ils ne s'affichent jamais. L'hôte les
/// émet depuis son adaptateur (mapping status-code → code) ; zcrud les traduit
/// en `ZFailure` typée par [zChatFailureFromWire].
///
/// 🔴 Les **alias de lecture** `SCREAMING_SNAKE` du fil SSE de lex sont
/// acceptés à l'entrée (cf. [zChatFailureFromWire]) et **jamais réémis** —
/// principe de Postel, déjà appliqué aux enums de CHAT-0.
abstract final class ZChatFailureCodes {
  /// Quota d'usage épuisé ⇒ `ZQuotaExceededFailure` (type EXISTANT).
  static const String quotaExceeded = 'quotaExceeded';

  /// Contenu refusé par la modération ⇒ [ZChatModerationFailure].
  static const String moderationBlocked = 'moderationBlocked';

  /// Fenêtre de contexte dépassée ⇒ [ZChatContextLimitFailure].
  static const String contextLimitExceeded = 'contextLimitExceeded';

  /// Flux coupé avant l'événement terminal ⇒ [ZChatStreamInterruptedFailure].
  static const String streamInterrupted = 'streamInterrupted';

  /// Capacité absente chez l'hôte ⇒ `ZUnsupportedOperationFailure` (EXISTANT).
  static const String unsupported = 'unsupported';
}

/// Normalise un code brut : `SCREAMING_SNAKE` → camelCase canonique.
///
/// Ne **traduit** que les codes dont zcrud a une famille typée. Tout autre code
/// est rendu **inchangé**, pour être conservé verbatim dans
/// [ZChatProviderFailure.code].
String _canonicalCode(String raw) {
  switch (raw) {
    case 'QUOTA_EXCEEDED':
      return ZChatFailureCodes.quotaExceeded;
    case 'MODERATION_BLOCKED':
    case 'CONTENT_FILTERED':
      return ZChatFailureCodes.moderationBlocked;
    case 'CONTEXT_LIMIT_EXCEEDED':
    case 'CONTEXT_LENGTH_EXCEEDED':
      return ZChatFailureCodes.contextLimitExceeded;
    case 'STREAM_INTERRUPTED':
      return ZChatFailureCodes.streamInterrupted;
    case 'UNSUPPORTED':
      return ZChatFailureCodes.unsupported;
    default:
      return raw;
  }
}

/// Traduit une **enveloppe d'erreur neutre** en `ZFailure` typée (AD-10 : ne
/// lève jamais, quelle que soit la forme reçue).
///
/// Forme attendue (clés snake_case, toutes optionnelles sauf `code`) :
/// `{'code': …, 'message': …, 'retry_after_seconds': …, 'category': …,
/// 'on_input': …, 'token_count': …, 'token_limit': …, 'request_id': …,
/// 'events_received': …, 'cancelled_by_user': …, 'operation': …}`.
///
/// 🔴 **Le code est TOUJOURS conservé** — dans la famille typée quand elle
/// existe, dans [ZChatProviderFailure] sinon. Aucun code n'est jeté (contraste
/// avec le client de lex). Le repli `ZServerFailure` n'est atteint que
/// lorsqu'il **n'y a aucun code** : c'est le contraire du défaut IFFD, où
/// l'inconnu devient une réponse d'assistant.
///
/// [fallbackMessage] est un message **technique** de dernier recours, jamais un
/// libellé d'interface — la traduction appartient à l'hôte (AD-13/FR-26).
ZFailure zChatFailureFromWire(
  Object? raw, {
  String fallbackMessage = 'chat request failed',
}) {
  final Map<String, dynamic> map = zJsonMap(raw) ?? const <String, dynamic>{};
  final String message = zJsonString(map['message'], fallbackMessage);
  final String rawCode = zJsonString(map['code']);
  switch (_canonicalCode(rawCode)) {
    case ZChatFailureCodes.quotaExceeded:
      final int? seconds = zJsonIntOrNull(map['retry_after_seconds']);
      // 🔴 CÂBLAGE du type EXISTANT `ZQuotaExceededFailure` (zcrud_core) —
      // premier consommateur réel depuis sa création (CR-LEX-23).
      return ZQuotaExceededFailure(
        message,
        retryAfter: seconds == null ? null : Duration(seconds: seconds),
      );
    case ZChatFailureCodes.moderationBlocked:
      return ZChatModerationFailure(
        message,
        category: zJsonStringOrNull(map['category']),
        onInput: zJsonBool(map['on_input'], true),
        code: rawCode,
      );
    case ZChatFailureCodes.contextLimitExceeded:
      return ZChatContextLimitFailure(
        message,
        tokenCount: zJsonIntOrNull(map['token_count']),
        tokenLimit: zJsonIntOrNull(map['token_limit']),
        code: rawCode,
      );
    case ZChatFailureCodes.streamInterrupted:
      return ZChatStreamInterruptedFailure(
        message,
        requestId: zJsonString(map['request_id']),
        eventsReceived: zJsonInt(map['events_received'], 0),
        cancelledByUser: zJsonBool(map['cancelled_by_user'], false),
        code: rawCode,
      );
    case ZChatFailureCodes.unsupported:
      // Type EXISTANT réutilisé (CHAT-0b/D9), jamais redéclaré.
      return ZUnsupportedOperationFailure(
        message,
        operation: zJsonString(map['operation']),
      );
    default:
      // 🔴 Un code non catalogué N'EST PAS JETÉ : `AGENT_TIMEOUT`,
      // `LLM_ERROR`, `GRAPH_ERROR` traversent intacts.
      return rawCode.isEmpty
          ? ZServerFailure(message)
          : ZChatProviderFailure(message, code: rawCode);
  }
}
