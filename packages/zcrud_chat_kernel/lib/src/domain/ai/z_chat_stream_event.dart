/// Événements de **streaming** de l'assistant — `ZChatStreamEvent` (CHAT-1).
///
/// origine: lex_core (module « Assistant ») —
/// `packages/lex_core/lib/domain/entities/chat_stream_event.dart` (`sealed
/// class ChatStreamEvent`, 10 variants). lex est ici la **référence** : sa forme
/// entre au socle, retypée sur les value objects que ce package porte déjà.
///
/// ## 🔴 Modèle SCELLÉ contre SENTINELLES TEXTUELLES
///
/// IFFD n'a pas de modèle d'événement : il **insère des balises dans le corps
/// du message** et les reconnaît par sous-chaîne —
/// `iffd_ai_repository_impl.dart:140` `eventData.contains("<RAG_THINKING>")`,
/// `:154` `contains("</RAG_THINKING>")` — puis les **retire à l'affichage** par
/// une expression régulière recopiée dans **cinq** fichiers de présentation
/// (`discovry_ai_page.dart:101` et `:117`, `explain_ai_page.dart:270`, `:338`,
/// `:383`, `white_exam_question_card.dart:1005`, `chatbot_conversation_screen
/// .dart:4250`). Conséquences directes : un utilisateur qui écrit littéralement
/// `<RAG_THINKING>` déclenche le mode « réflexion » ; une balise non refermée
/// laisse du raisonnement dans la réponse ; et les cinq nettoyages divergent.
///
/// ⇒ Ici, la réflexion est un **variant à part entière**
/// ([ZChatThinkingEvent]), portant le [ZChatThinkingStep] **déjà existant** dans
/// ce package. Aucune sentinelle n'existe, donc aucun nettoyage n'est requis.
/// Garde **G-C3** : aucune sentinelle textuelle dans `lib/src/domain/`.
///
/// ## 🔴 Aucun variant d'ERREUR — divergence ASSUMÉE d'avec lex
///
/// lex porte **deux** canaux d'échec pour un seul flux : `ChatErrorEvent`
/// (dans le `Right`) **et** le `Left(Failure)` de l'`Either`. Un appelant doit
/// donc traiter l'erreur à deux endroits, et un `Right(ChatErrorEvent)` **passe
/// pour un succès**. AD-5 tranche : l'échec est le `Left`, et lui seul. Garde
/// **G-C2** : aucun variant `*Error*`/`*Failure*` dans cette famille.
///
/// ## Patron `sealed` INTERNE + variant OUVERT (AD-4)
///
/// Décalqué de [ZContentBlock] et de `ZChatAction` : `sealed` donne
/// l'exhaustivité **au socle** (un `switch` sur un événement non traité ne
/// compile pas) ; l'extension inter-package passe par [ZChatCustomStreamEvent]
/// et [ZTypeRegistry], **jamais** par l'héritage externe.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_quota_snapshot.dart';
import '../z_chat_source.dart';
import '../z_chat_suggestion.dart';
import '../z_chat_thinking_step.dart';
import '../z_content_block.dart';
import 'z_chat_response_metadata.dart';

/// Clé persistée du discriminant d'événement.
const String kZChatStreamEventTypeKey = 'type';

/// Union **scellée en interne** des événements de flux.
sealed class ZChatStreamEvent {
  /// Constructeur `const` (variants immuables).
  const ZChatStreamEvent({this.sequenceId});

  /// Position de l'événement dans le flux (`id:` SSE **monotone**), ou `null`
  /// quand le transport n'en expose pas.
  ///
  /// 🔴 C'est la valeur que l'appelant renvoie en `Last-Event-ID` pour
  /// **reprendre** après coupure (`ZChatRequestToken.resumeFrom`). Sans elle, le
  /// port de streaming ne peut pas honorer le protocole reprenable de lex, et
  /// une reconnexion **rejoue ou perd** des événements.
  ///
  /// `null` ne veut **jamais** dire « position 0 » : un backend non reprenable
  /// n'en émet pas, et confondre les deux ferait reprendre un flux au début.
  final String? sequenceId;

  /// Discriminant persisté (camelCase).
  String get kind;

  /// Sérialise l'événement, discriminant inclus.
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  });

  /// Décode **défensivement** un événement (AD-10) — **ne lève jamais**.
  ///
  /// - [raw] non-`Map`, ou `type` absent/vide ⇒ `null` (aucun événement
  ///   synthétique n'est fabriqué : l'appelant décide de sauter la trame) ;
  /// - `type` inconnu ⇒ [ZChatCustomStreamEvent], **payload verbatim** — jamais
  ///   une erreur (lex, lui, transforme l'inconnu en `ChatErrorEvent`, ce qui
  ///   fait passer une extension backend pour une panne).
  ///
  /// Les alias de lecture **snake_case** du fil de lex (`retrieval_progress`,
  /// `sources_preview`, `content_block`) sont acceptés ; jamais réémis.
  static ZChatStreamEvent? fromJson(
    Object? raw, {
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String rawType = zJsonString(map[kZChatStreamEventTypeKey]);
    if (rawType.isEmpty) return null;
    final String kind = kZChatStreamEventReadAliases[rawType] ?? rawType;
    // Position de reprise : `sequence_id` (forme canonique) ou `id` (champ SSE
    // brut, tel que le transport de lex l'expose). Absente ⇒ `null`, jamais 0.
    final String? seq =
        zJsonStringOrNull(map['sequence_id']) ?? zJsonStringOrNull(map['id']);
    switch (kind) {
      case 'thinking':
        return ZChatThinkingEvent(
          step: ZChatThinkingStep.fromJson(map) ?? const ZChatThinkingStep(),
          sequenceId: seq,
        );
      case 'retrievalProgress':
        return ZChatRetrievalProgressEvent(
          agent: zJsonString(map['agent']),
          sourcesFound: zJsonInt(map['sources_found'], 0),
          sequenceId: seq,
        );
      case 'sourcesPreview':
        return ZChatSourcesPreviewEvent(
          sources:
              zJsonDecodeList<ZChatSource>(
                map['sources'],
                (Object? e) =>
                    ZChatSource.fromJson(e, registry: sourceRegistry),
              ) ??
              const <ZChatSource>[],
          sequenceId: seq,
        );
      case 'token':
        return ZChatTokenEvent(
          content: zJsonString(map['content']),
          sequenceId: seq,
        );
      case 'contentBlock':
        final ZContentBlock? block = ZContentBlock.fromJson(
          <String, dynamic>{
            kZContentBlockTypeKey: map['block_type'],
            kZContentBlockDataKey: map['data'],
          },
          typeRegistry: typeRegistry,
          sourceRegistry: sourceRegistry,
        );
        return block == null
            ? null
            : ZChatContentBlockEvent(block: block, sequenceId: seq);
      case 'suggestions':
        return ZChatSuggestionsEvent(
          suggestions:
              zJsonDecodeList<ZChatSuggestion>(
                map['suggestions'],
                ZChatSuggestion.fromJson,
              ) ??
              const <ZChatSuggestion>[],
          sequenceId: seq,
        );
      case 'quota':
        final ZChatQuotaSnapshot? snapshot = ZChatQuotaSnapshot.fromJson(
          map['snapshot'],
        );
        return snapshot == null
            ? null
            : ZChatQuotaEvent(snapshot: snapshot, sequenceId: seq);
      case 'done':
        return ZChatDoneEvent(
          messageId: zJsonString(map['message_id']),
          conversationId: zJsonString(map['conversation_id']),
          metadata: zJsonMap(map['metadata']) ?? const <String, dynamic>{},
          sequenceId: seq,
        );
      default:
        final Map<String, dynamic> verbatim = <String, dynamic>{
          for (final MapEntry<String, dynamic> e in map.entries)
            if (e.key != kZChatStreamEventTypeKey &&
                e.key != 'sequence_id' &&
                e.key != 'id')
              e.key: e.value,
        };
        final ZValueCodec? codec = typeRegistry?.tryCodecFor(kind);
        return ZChatCustomStreamEvent(
          kind,
          codec == null
              ? verbatim
              : (zJsonMap(zJsonGuard(() => codec.fromJson(verbatim))) ??
                    verbatim),
          sequenceId: seq,
        );
    }
  }
}

/// Alias de **lecture** snake_case (fil de lex) → discriminant canonique.
const Map<String, String> kZChatStreamEventReadAliases = <String, String>{
  'retrieval_progress': 'retrievalProgress',
  'sources_preview': 'sourcesPreview',
  'content_block': 'contentBlock',
};

/// Étape de raisonnement exposée **structurellement** (jamais une balise dans
/// le corps du message — cf. le défaut IFFD documenté en tête de fichier).
class ZChatThinkingEvent extends ZChatStreamEvent {
  /// Construit l'événement de réflexion.
  const ZChatThinkingEvent({required this.step, super.sequenceId});

  /// L'étape, portée par le type **EXISTANT** `ZChatThinkingStep`.
  final ZChatThinkingStep step;

  @override
  String get kind => 'thinking';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    ...step.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatThinkingEvent &&
          sequenceId == other.sequenceId &&
          step == other.step;

  @override
  int get hashCode => Object.hash(kind, sequenceId, step);

  @override
  String toString() => 'ZChatThinkingEvent(agent: ${step.agent})';
}

/// Progression de la récupération documentaire (nombre de sources trouvées).
class ZChatRetrievalProgressEvent extends ZChatStreamEvent {
  /// Construit l'événement de progression.
  const ZChatRetrievalProgressEvent({
    this.agent = '',
    this.sourcesFound = 0,
    super.sequenceId,
  });

  /// Agent/outil de récupération.
  final String agent;

  /// Nombre de sources trouvées à cet instant.
  final int sourcesFound;

  @override
  String get kind => 'retrievalProgress';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    'agent': agent,
    'sources_found': sourcesFound,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatRetrievalProgressEvent &&
          sequenceId == other.sequenceId &&
          agent == other.agent &&
          sourcesFound == other.sourcesFound;

  @override
  int get hashCode => Object.hash(kind, sequenceId, agent, sourcesFound);

  @override
  String toString() =>
      'ZChatRetrievalProgressEvent(agent: $agent, sourcesFound: $sourcesFound)';
}

/// Aperçu des sources retenues, porté par le type **EXISTANT** `ZChatSource`.
class ZChatSourcesPreviewEvent extends ZChatStreamEvent {
  /// Construit l'aperçu de sources.
  const ZChatSourcesPreviewEvent({
    this.sources = const <ZChatSource>[],
    super.sequenceId,
  });

  /// Sources retenues.
  final List<ZChatSource> sources;

  @override
  String get kind => 'sourcesPreview';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    'sources': <Map<String, dynamic>>[
      for (final ZChatSource s in sources) s.toJson(registry: sourceRegistry),
    ],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSourcesPreviewEvent &&
          sequenceId == other.sequenceId &&
          zListEquals(sources, other.sources);

  @override
  int get hashCode => Object.hash(kind, sequenceId, zListHash(sources));

  @override
  String toString() => 'ZChatSourcesPreviewEvent(${sources.length} sources)';
}

/// Fragment de texte incrémental de la réponse.
class ZChatTokenEvent extends ZChatStreamEvent {
  /// Construit le fragment.
  const ZChatTokenEvent({this.content = '', super.sequenceId});

  /// Fragment textuel — **jamais** une sentinelle (G-C3).
  final String content;

  @override
  String get kind => 'token';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    'content': content,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatTokenEvent &&
          sequenceId == other.sequenceId &&
          content == other.content;

  @override
  int get hashCode => Object.hash(kind, sequenceId, content);

  @override
  String toString() => 'ZChatTokenEvent(${content.length} chars)';
}

/// Bloc de contenu structuré, porté par la famille **EXISTANTE**
/// `ZContentBlock` (ouverte par [ZTypeRegistry] — AD-4).
class ZChatContentBlockEvent extends ZChatStreamEvent {
  /// Construit l'événement de bloc.
  const ZChatContentBlockEvent({required this.block, super.sequenceId});

  /// Le bloc émis.
  final ZContentBlock block;

  @override
  String get kind => 'contentBlock';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) {
    final Map<String, dynamic> envelope = block.toJson(
      typeRegistry: typeRegistry,
      sourceRegistry: sourceRegistry,
    );
    return <String, dynamic>{
      kZChatStreamEventTypeKey: kind,
      if (sequenceId != null) 'sequence_id': sequenceId,
      'block_type': envelope[kZContentBlockTypeKey],
      'data': envelope[kZContentBlockDataKey],
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatContentBlockEvent &&
          sequenceId == other.sequenceId &&
          block == other.block;

  @override
  int get hashCode => Object.hash(kind, sequenceId, block);

  @override
  String toString() => 'ZChatContentBlockEvent(block: ${block.kind})';
}

/// Suggestions de relance, portées par le type **EXISTANT** `ZChatSuggestion`.
class ZChatSuggestionsEvent extends ZChatStreamEvent {
  /// Construit l'événement de suggestions.
  const ZChatSuggestionsEvent({
    this.suggestions = const <ZChatSuggestion>[],
    super.sequenceId,
  });

  /// Suggestions proposées.
  final List<ZChatSuggestion> suggestions;

  @override
  String get kind => 'suggestions';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    'suggestions': <Map<String, dynamic>>[
      for (final ZChatSuggestion s in suggestions) s.toJson(),
    ],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSuggestionsEvent &&
          sequenceId == other.sequenceId &&
          zListEquals(suggestions, other.suggestions);

  @override
  int get hashCode => Object.hash(kind, sequenceId, zListHash(suggestions));

  @override
  String toString() => 'ZChatSuggestionsEvent(${suggestions.length})';
}

/// Instantané de quota **observationnel**, porté par le type **EXISTANT**
/// `ZChatQuotaSnapshot`.
///
/// ⚠️ Ce n'est **pas** un échec : un quota épuisé qui **refuse** l'appel est un
/// `Left(ZQuotaExceededFailure)` (`z_chat_ai_failure.dart`). Cet événement
/// n'informe que de l'état courant.
class ZChatQuotaEvent extends ZChatStreamEvent {
  /// Construit l'événement de quota.
  const ZChatQuotaEvent({required this.snapshot, super.sequenceId});

  /// L'instantané.
  final ZChatQuotaSnapshot snapshot;

  @override
  String get kind => 'quota';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    'snapshot': snapshot.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatQuotaEvent &&
          sequenceId == other.sequenceId &&
          snapshot == other.snapshot;

  @override
  int get hashCode => Object.hash(kind, sequenceId, snapshot);

  @override
  String toString() => 'ZChatQuotaEvent($snapshot)';
}

/// Événement **terminal** du flux : la réponse est complète.
class ZChatDoneEvent extends ZChatStreamEvent {
  /// Construit l'événement terminal.
  const ZChatDoneEvent({
    this.messageId = '',
    this.conversationId = '',
    this.metadata = const <String, dynamic>{},
    super.sequenceId,
  });

  /// Identité du message assistant produit.
  final String messageId;

  /// Identité de la conversation.
  final String conversationId;

  /// Métadonnées libres du fournisseur, **verbatim**.
  ///
  /// 🔴 Reste la **source de vérité brute** : rien n'est retiré ni normalisé à
  /// la réception. La lecture typée passe par [responseMetadata], qui **dérive**
  /// de cette carte au lieu de la doubler — deux représentations stockées
  /// pourraient diverger, et l'une afficherait alors un verdict que l'autre
  /// contredit.
  final Map<String, dynamic> metadata;

  /// Lecture **typée et ouverte** de [metadata] (CHAT-7).
  ///
  /// Ne lève jamais (AD-10) : une carte absente, vide ou mal typée rend
  /// `ZChatResponseMetadata.empty`. Aucun champ n'est fabriqué — un backend
  /// sans contrat de fin de réponse (IFFD) rend simplement une carte vide.
  ///
  /// [verifiedSourceCount]/[totalSourceCount] sont les comptes de sources du
  /// message, connus de l'appelant seul : le serveur ne les émet pas dans
  /// `done.metadata`, ils se dérivent des drapeaux de vérification des sources.
  ZChatResponseMetadata responseMetadata({
    int? verifiedSourceCount,
    int? totalSourceCount,
  }) => ZChatResponseMetadata.fromJson(
    metadata,
    verifiedSourceCount: verifiedSourceCount,
    totalSourceCount: totalSourceCount,
  );

  @override
  String get kind => 'done';

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) => <String, dynamic>{
    kZChatStreamEventTypeKey: kind,
    if (sequenceId != null) 'sequence_id': sequenceId,
    'message_id': messageId,
    'conversation_id': conversationId,
    if (metadata.isNotEmpty) 'metadata': metadata,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatDoneEvent &&
          sequenceId == other.sequenceId &&
          messageId == other.messageId &&
          conversationId == other.conversationId &&
          zJsonEquals(metadata, other.metadata);

  @override
  int get hashCode => Object.hash(
    kind,
    sequenceId,
    messageId,
    conversationId,
    zJsonHash(metadata),
  );

  @override
  String toString() => 'ZChatDoneEvent(messageId: $messageId)';
}

/// Variant **OUVERT** (AD-4) : tout événement propre à un hôte, traversant
/// intact ou reconstruit par le codec [ZTypeRegistry] qu'il a enregistré.
///
/// C'est ce qui rend atteignables les variants non portés de lex
/// (`clarification`…) et tout événement futur d'un backend, **sans forker le
/// socle** et **sans sentinelle textuelle**.
class ZChatCustomStreamEvent extends ZChatStreamEvent {
  /// Construit un événement ouvert de discriminant [kind].
  ZChatCustomStreamEvent(
    this.kind,
    Map<String, dynamic> payload, {
    super.sequenceId,
  }) : payload = Map<String, dynamic>.unmodifiable(payload);

  @override
  final String kind;

  /// Charge utile **verbatim**.
  final Map<String, dynamic> payload;

  @override
  Map<String, dynamic> toJson({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) {
    final ZValueCodec? codec = typeRegistry?.tryCodecFor(kind);
    final Map<String, dynamic> body = codec == null
        ? payload
        : (zJsonGuard(() => codec.toJson(payload)) ?? payload);
    return <String, dynamic>{
      ...body,
      kZChatStreamEventTypeKey: kind,
      if (sequenceId != null) 'sequence_id': sequenceId,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCustomStreamEvent &&
          sequenceId == other.sequenceId &&
          kind == other.kind &&
          zJsonEquals(payload, other.payload);

  @override
  int get hashCode => Object.hash(kind, sequenceId, zJsonHash(payload));

  @override
  String toString() => 'ZChatCustomStreamEvent(kind: $kind)';
}
