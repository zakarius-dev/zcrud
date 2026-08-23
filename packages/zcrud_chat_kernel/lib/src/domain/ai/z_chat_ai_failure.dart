/// Familles d'échec propres à l'IA (invariants AD-5, AD-10, AD-11).
///
/// ## Le défaut que ce fichier ferme
///
/// Sans gestion d'erreur typée sur le chemin IA, le texte brut d'une exception
/// finit poussé dans le corps du message et **affiché comme s'il s'agissait
/// de la réponse de l'assistant**. Un quota épuisé, une modération, une
/// fenêtre de contexte dépassée et une panne réseau deviennent alors **le même
/// événement** — une chaîne. L'hôte ne peut ni réessayer à bon escient, ni
/// informer correctement, ni masquer une capacité absente.
///
/// ## Ce qui est câblé, pas recréé
///
/// | Besoin | Type **existant** réutilisé | Chemin |
/// |---|---|---|
/// | Quota IA dépassé (+ `retryAfter`) | `ZQuotaExceededFailure` | `zcrud_core/lib/src/domain/failures/z_failure.dart` |
/// | Capacité non implémentée par l'hôte | `ZUnsupportedOperationFailure` | idem |
/// | Panne backend | `ZServerFailure` | idem |
/// | Règle métier violée | `ZDomainFailure` | idem |
/// | Confirmation refusée | `ZChatActionNotConfirmedFailure` | `action/z_chat_action_failure.dart` |
///
/// [zChatFailureFromWire] est le point de câblage réel de
/// `ZQuotaExceededFailure` sur le chemin IA.
///
/// Ne sont créées ici que les **trois** familles qui manquaient réellement :
/// modération, limite de contexte, flux interrompu.
///
/// ## Hiérarchie plate
///
/// Les trois nouveaux types étendent `ZFailure` **directement** — comme
/// `ZDomainFailure`, `ZQuotaExceededFailure` et `ZUnsupportedOperationFailure`,
/// qui sont des **frères**. Aucun n'étend l'autre : le triage se fait par `is`,
/// jamais par un `switch` exhaustif (`ZFailure` n'est pas `sealed`, invariant
/// AD-4).
library;

import 'package:zcrud_core/domain.dart';

/// Le contenu a été **refusé** (entrée ou sortie) par la modération du
/// fournisseur — ce n'est ni une panne, ni un quota.
///
/// La distinction change ce que l'hôte doit faire : réessayer à l'identique est
/// **garanti inutile**, et le texte du fournisseur ne doit **jamais** être
/// rendu comme une réponse d'assistant. [category] est un motif
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
/// arrêtée, plutôt que de devoir supposer qu'il s'agit de « la dernière
/// lancée ». [cancelledByUser] sépare l'arrêt **voulu** (aucune erreur à
/// afficher) de la coupure **subie** (réseau, timeout) : les aplatir
/// forcerait l'hôte à afficher une erreur sur un geste volontaire.
/// [eventsReceived] dit si un contenu partiel a été rendu et mérite d'être
/// conservé.
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
/// ## Pourquoi le code est toujours conservé
///
/// Un flux d'erreurs serveur typé (par exemple un événement SSE
/// `{"type":"error","code":…}`) perd toute sa valeur diagnostique si le
/// client jette le code en ne conservant que le message : l'hôte se retrouve
/// alors à distinguer un timeout d'agent d'une erreur de graphe **en
/// comparant des phrases**.
///
/// ⇒ zcrud **conserve le code**, toujours : soit dans la famille typée qui lui
/// correspond ([ZChatModerationFailure.code], [ZChatContextLimitFailure.code],
/// [ZChatStreamInterruptedFailure.code]), soit ici quand aucune famille ne
/// s'applique. Le code est **opaque** : aucun catalogue fermé, aucun `switch`
/// exhaustif, aucun libellé — un backend qui en ajoute un demain traverse
/// intact.
///
/// Seul `ZQuotaExceededFailure` ne porte pas de code : c'est un type
/// **existant du cœur** qu'on réutilise sans le modifier (le type lui-même dit
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
/// Les **alias de lecture** `SCREAMING_SNAKE` d'un flux d'événements distant
/// sont acceptés à l'entrée (cf. [zChatFailureFromWire]) et **jamais
/// réémis** — principe de Postel, appliqué de façon cohérente aux enums de ce
/// paquet.
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

  /// Route refusée par la gouvernance (palier insuffisant, jeton d'accès
  /// manquant) ⇒ [ZChatProviderFailure] portant ce code — émis par un
  /// `ZChatRouteGate` comme par un backend.
  static const String upgradeRequired = 'upgradeRequired';
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
    case 'UPGRADE_REQUIRED':
      return ZChatFailureCodes.upgradeRequired;
    default:
      return raw;
  }
}

/// Traduit une **enveloppe d'erreur neutre** en `ZFailure` typée (invariant
/// AD-10 : ne lève jamais, quelle que soit la forme reçue).
///
/// Forme attendue (clés snake_case, toutes optionnelles sauf `code`) :
/// `{'code': …, 'message': …, 'retry_after_seconds': …, 'category': …,
/// 'on_input': …, 'token_count': …, 'token_limit': …, 'request_id': …,
/// 'events_received': …, 'cancelled_by_user': …, 'operation': …}`.
///
/// **Le code est toujours conservé** — dans la famille typée quand elle
/// existe, dans [ZChatProviderFailure] sinon. Aucun code n'est jeté. Le repli
/// `ZServerFailure` n'est atteint que lorsqu'il **n'y a aucun code** —
/// jamais parce que le code reçu était inconnu.
///
/// [fallbackMessage] est un message **technique** de dernier recours, jamais un
/// libellé d'interface — la traduction appartient à l'hôte (invariant AD-13).
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
      // Câblage du type existant `ZQuotaExceededFailure` (zcrud_core).
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
      // Type existant réutilisé, jamais redéclaré.
      return ZUnsupportedOperationFailure(
        message,
        operation: zJsonString(map['operation']),
      );
    case ZChatFailureCodes.upgradeRequired:
      // Le code CANONIQUE est réémis : c'est lui qu'un hôte compare.
      return ZChatProviderFailure(
        message,
        code: ZChatFailureCodes.upgradeRequired,
      );
    default:
      // Un code non catalogué n'est pas jeté : il traverse intact.
      return rawCode.isEmpty
          ? ZServerFailure(message)
          : ZChatProviderFailure(message, code: rawCode);
  }
}
