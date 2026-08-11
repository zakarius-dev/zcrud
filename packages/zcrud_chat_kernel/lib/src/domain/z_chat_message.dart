/// Message de conversation IA — `ZChatMessage` (invariants AD-4, AD-9,
/// AD-10).
///
/// ## Trois choix de robustesse assumés
///
/// 1. **[ZChatMessage.createdAt] est `DateTime?`**. Parser une date sans
///    tolérance (`DateTime.parse` direct sur le champ brut) fait qu'un
///    document sans `created_at`, ou avec une date corrompue, **lève** et
///    **détruit tout le message**. L'invariant AD-10 l'interdit.
/// 2. **[ZChatMessage.id] est `String?`** — l'entité éphémère (message en cours
///    de streaming, non encore matérialisé) est un état de premier ordre du
///    domaine (`ZEntity.isEphemeral`), pas un `''` déguisé.
/// 3. **Aucun `freshnessForSource` dédié** : une résolution qui passerait par
///    un `switch` sur des sous-types métier de source n'a pas sa place dans
///    un socle générique dépourvu de ces types. Un hôte croise
///    `sourceFreshness` et `sources` lui-même, sur la clé de son choix.
///
/// ## `updated_at` / `is_deleted` n'existent pas ici (invariant AD-9)
///
/// Ces deux clés appartiennent à `ZSyncMeta` — **hors-entité**. [toMap] ne les
/// émet **jamais**, et [extra] ne peut **jamais** les porter, sur **aucune**
/// voie d'écriture (ctor `const`, `copyWith`, `fromMap`).
///
/// ```dart
/// import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
///
/// final message = ZChatMessage(
///   conversationId: 'conv-1',
///   role: ZChatRole.assistant,
///   contentBlocks: const [ZTextBlock(text: 'Bonjour !')],
///   createdAt: DateTime.now(),
/// );
/// final Map<String, dynamic> persisted = message.toMap();
/// final ZChatMessage relu = ZChatMessage.fromMap(persisted);
/// ```
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_attachment.dart';
import 'z_chat_enums.dart';
import 'z_chat_extension_parser.dart';
import 'z_chat_response_confidence.dart';
import 'z_chat_source.dart';
import 'z_chat_source_freshness.dart';
import 'z_chat_suggestion.dart';
import 'z_chat_thinking_step.dart';
import 'z_content_block.dart';

/// Sentinelle de `copyWith` : distingue « argument omis » de « remis à `null` ».
const Object _unset = Object();

/// Un message d'une conversation IA — entité canonique **extensible**.
class ZChatMessage extends ZEntity with ZExtensible {
  /// Construit un message (primitif `const`).
  ///
  /// **Aucun `assert` ici, volontairement** (invariant AD-10) : ce
  /// constructeur est la cible de [fromMap], appelé avec des valeurs
  /// **brutes** issues du store. Un `assert` y ferait **échouer la
  /// désérialisation d'une donnée corrompue**.
  ///
  /// Étant `const`, il ne peut appeler **aucune** fonction dans son
  /// initializer : il ne filtre donc **rien**. C'est l'**accesseur** [extra] qui
  /// porte la garde (`zNormalizeExtra`) — le seul point que **toutes** les
  /// voies traversent.
  const ZChatMessage({
    this.id,
    this.conversationId = '',
    this.role = ZChatRole.unknown,
    this.contentBlocks = const <ZContentBlock>[],
    this.sources,
    this.attachments,
    this.createdAt,
    this.thinking,
    this.suggestions,
    this.feedbackRating,
    this.feedbackCategory,
    this.feedbackComment,
    this.agentsCalled,
    this.confidence,
    this.sourceFreshness,
    this.versionKey,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** un message depuis une map persistée
  /// (invariant AD-10).
  ///
  /// **Aucun cas ne lève** — pas même `ZChatMessage.fromMap(const {})` : `role`
  /// inconnu ⇒ [ZChatRole.unknown] ; bloc de type inconnu ⇒
  /// [ZCustomContentBlock] ; élément de liste illisible ⇒ **ignoré** (la liste
  /// survit) ; `created_at` absent/corrompu ⇒ `null` ;
  /// `extension` illisible ⇒ payload préservé opaque.
  ///
  /// [typeRegistry] / [sourceRegistry] ouvrent les blocs et provenances que le
  /// cœur ne type pas (invariant AD-4, mécanisme 3) ; [extensionParser] type
  /// le slot `extension`.
  factory ZChatMessage.fromMap(
    Map<String, dynamic> map, {
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
    ZChatExtensionParser? extensionParser,
  }) {
    return ZChatMessage(
      id: zJsonStringOrNull(map['id']),
      conversationId: zJsonString(map['conversation_id']),
      role: ZChatRole.fromJson(map['role']),
      contentBlocks: zJsonDecodeList<ZContentBlock>(
            map['content_blocks'],
            (Object? e) => ZContentBlock.fromJson(
              e,
              typeRegistry: typeRegistry,
              sourceRegistry: sourceRegistry,
            ),
          ) ??
          const <ZContentBlock>[],
      sources: zJsonDecodeList<ZChatSource>(
        map['sources'],
        (Object? e) => ZChatSource.fromJson(e, registry: sourceRegistry),
      ),
      attachments: zJsonDecodeList<ZChatAttachment>(
        map['attachments'],
        ZChatAttachment.fromJson,
      ),
      createdAt: zJsonDate(map['created_at']),
      thinking: zJsonDecodeList<ZChatThinkingStep>(
        map['thinking'],
        ZChatThinkingStep.fromJson,
      ),
      suggestions: zJsonDecodeList<ZChatSuggestion>(
        map['suggestions'],
        ZChatSuggestion.fromJson,
      ),
      feedbackRating: ZChatFeedbackRating.fromJson(map['feedback_rating']),
      feedbackCategory:
          ZChatFeedbackCategory.fromJson(map['feedback_category']),
      feedbackComment: zJsonStringOrNull(map['feedback_comment']),
      agentsCalled: zJsonStringList(map['agents_called']),
      confidence: ZChatResponseConfidence.fromJson(map['confidence']),
      sourceFreshness: zJsonDecodeList<ZChatSourceFreshness>(
        map['source_freshness'],
        ZChatSourceFreshness.fromJson,
      ),
      versionKey: zJsonStringOrNull(map['version_key']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      // Normalisation EAGER à la frontière d'entrée : le slot stocké est
      // déjà propre ⇒ la lecture d'`extra` est sans copie.
      extra: zSanitizeExtra(map, _reservedKeys),
    );
  }

  /// Identité opaque, `null` tant que le message est **éphémère** (en cours de
  /// streaming, non matérialisé par un repository) — `ZEntity.isEphemeral`.
  @override
  final String? id;

  /// Conversation d'appartenance (clé neutre, défaut `''`).
  final String conversationId;

  /// Rôle de l'auteur (défaut [ZChatRole.unknown] — jamais `user` par défaut).
  final ZChatRole role;

  /// Contenu structuré du message (jamais `null` : liste vide si absent).
  final List<ZContentBlock> contentBlocks;

  /// Sources citées, ou `null` si la clé est absente.
  final List<ZChatSource>? sources;

  /// Pièces jointes, ou `null` si la clé est absente.
  final List<ZChatAttachment>? attachments;

  /// Date de création (ISO-8601), `null` si absente ou illisible.
  ///
  /// Il n'y a **volontairement aucun** `updatedAt` : la clé Last-Write-Wins
  /// est **hors-entité** (`ZSyncMeta.updatedAt`, invariant AD-9).
  final DateTime? createdAt;

  /// Étapes de raisonnement exposées, ou `null`.
  final List<ZChatThinkingStep>? thinking;

  /// Suggestions de relance, ou `null`.
  final List<ZChatSuggestion>? suggestions;

  /// Appréciation binaire de la réponse, ou `null`.
  final ZChatFeedbackRating? feedbackRating;

  /// Motif catégorisé d'un feedback négatif, ou `null`.
  final ZChatFeedbackCategory? feedbackCategory;

  /// Commentaire libre joint au feedback, ou `null`.
  final String? feedbackComment;

  /// Agents/outils appelés pour produire la réponse, ou `null`.
  final List<String>? agentsCalled;

  /// Confiance agrégée de la réponse, ou `null` (message utilisateur, ou
  /// réponse sans signal).
  final ZChatResponseConfidence? confidence;

  /// Fiches de fraîcheur des datasets cités, ou `null`.
  final List<ZChatSourceFreshness>? sourceFreshness;

  /// Tag de version composable de la réponse, ou `null`.
  final String? versionKey;

  /// Slot type additif **versionné** (invariant AD-4, mécanisme 1).
  ///
  /// Vaut un `ZOpaqueExtension` quand aucun [ZChatExtensionParser] n'a su typer
  /// le payload : la donnée **survit** même si le type ne revient pas.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (invariant AD-4, mécanisme 2) — clés inconnues
  /// du cœur, préservées.
  ///
  /// L'accesseur **NORMALISE** : il ne rend **jamais** une clé réservée, quelle
  /// que soit la voie d'écriture empruntée (le ctor `const` ne peut rien
  /// filtrer). Zéro copie quand le slot stocké est déjà propre.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` **BRUT** tel que reçu par le constructeur — lu **nulle part**
  /// ailleurs que dans l'accesseur [extra] (ni `toMap`, ni `==`, ni `hashCode`).
  final Map<String, dynamic> _extra;

  /// Texte concaténé des seuls [ZTextBlock].
  String get content => contentBlocks
      .whereType<ZTextBlock>()
      .map((ZTextBlock b) => b.text)
      .join();

  /// Clés persistées **réservées** : schéma du message ∪ `extension` ∪
  /// **`ZSyncMeta.reservedKeys`**.
  ///
  /// Sans le spread `ZSyncMeta.reservedKeys`, un store qui écrit
  /// `updated_at`/`is_deleted` **dans le corps** du document avant de passer
  /// la map complète à [fromMap] verrait ses clés atterrir dans [extra] puis
  /// être **réémises** par [toMap] : le merge Last-Write-Wins serait faussé
  /// **silencieusement** (invariant AD-9).
  static const Set<String> _reservedKeys = <String>{
    'id',
    'conversation_id',
    'role',
    'content_blocks',
    'sources',
    'attachments',
    'created_at',
    'thinking',
    'suggestions',
    'feedback_rating',
    'feedback_category',
    'feedback_comment',
    'agents_called',
    'confidence',
    'source_freshness',
    'version_key',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Sérialise vers la map persistée **complète** (clés snake_case), zéro-perte.
  ///
  /// [extra] est étalé **en premier** (via l'**accesseur**, donc via la garde),
  /// puis les champs du schéma : une clé inconnue survit au round-trip
  /// (invariant AD-4) et ne peut jamais écraser un champ connu.
  ///
  /// **N'émet NI `updated_at` NI `is_deleted`, dans aucun cas de figure** —
  /// y compris quand ces clés étaient présentes dans la map source.
  Map<String, dynamic> toMap({
    ZTypeRegistry? typeRegistry,
    ZSourceRegistry? sourceRegistry,
  }) =>
      <String, dynamic>{
        ...extra,
        if (id != null) 'id': id,
        'conversation_id': conversationId,
        'role': role.jsonValue,
        'content_blocks': <Map<String, dynamic>>[
          for (final ZContentBlock b in contentBlocks)
            b.toJson(
              typeRegistry: typeRegistry,
              sourceRegistry: sourceRegistry,
            ),
        ],
        if (sources != null)
          'sources': <Map<String, dynamic>>[
            for (final ZChatSource s in sources!)
              s.toJson(registry: sourceRegistry),
          ],
        if (attachments != null)
          'attachments': <Map<String, dynamic>>[
            for (final ZChatAttachment a in attachments!) a.toJson(),
          ],
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (thinking != null)
          'thinking': <Map<String, dynamic>>[
            for (final ZChatThinkingStep t in thinking!) t.toJson(),
          ],
        if (suggestions != null)
          'suggestions': <Map<String, dynamic>>[
            for (final ZChatSuggestion s in suggestions!) s.toJson(),
          ],
        if (feedbackRating != null) 'feedback_rating': feedbackRating!.jsonValue,
        if (feedbackCategory != null)
          'feedback_category': feedbackCategory!.jsonValue,
        if (feedbackComment != null) 'feedback_comment': feedbackComment,
        if (agentsCalled != null) 'agents_called': agentsCalled,
        if (confidence != null) 'confidence': confidence!.toJson(),
        if (sourceFreshness != null)
          'source_freshness': <Map<String, dynamic>>[
            for (final ZChatSourceFreshness f in sourceFreshness!) f.toJson(),
          ],
        if (versionKey != null) 'version_key': versionKey,
        if (extension != null) 'extension': extension!.toJson(),
      };

  /// Copie **à sentinelle** : un argument omis conserve la valeur courante, un
  /// `null` **explicite** la remet à `null`, étendu à **tous** les champs
  /// nullables — une sentinelle partielle ne couvrant qu'une partie des champs
  /// laisserait les autres impossibles à remettre à `null`.
  ///
  /// `extra` est **sanitisé eager** ici : une voie d'écriture qui ne
  /// filtrerait pas laisserait la garde d'invariant rouvrable.
  ZChatMessage copyWith({
    Object? id = _unset,
    Object? conversationId = _unset,
    Object? role = _unset,
    Object? contentBlocks = _unset,
    Object? sources = _unset,
    Object? attachments = _unset,
    Object? createdAt = _unset,
    Object? thinking = _unset,
    Object? suggestions = _unset,
    Object? feedbackRating = _unset,
    Object? feedbackCategory = _unset,
    Object? feedbackComment = _unset,
    Object? agentsCalled = _unset,
    Object? confidence = _unset,
    Object? sourceFreshness = _unset,
    Object? versionKey = _unset,
    Object? extension = _unset,
    Object? extra = _unset,
  }) =>
      ZChatMessage(
        id: identical(id, _unset) ? this.id : id as String?,
        conversationId: identical(conversationId, _unset)
            ? this.conversationId
            : conversationId as String,
        role: identical(role, _unset) ? this.role : role as ZChatRole,
        contentBlocks: identical(contentBlocks, _unset)
            ? this.contentBlocks
            : contentBlocks as List<ZContentBlock>,
        sources: identical(sources, _unset)
            ? this.sources
            : sources as List<ZChatSource>?,
        attachments: identical(attachments, _unset)
            ? this.attachments
            : attachments as List<ZChatAttachment>?,
        createdAt: identical(createdAt, _unset)
            ? this.createdAt
            : createdAt as DateTime?,
        thinking: identical(thinking, _unset)
            ? this.thinking
            : thinking as List<ZChatThinkingStep>?,
        suggestions: identical(suggestions, _unset)
            ? this.suggestions
            : suggestions as List<ZChatSuggestion>?,
        feedbackRating: identical(feedbackRating, _unset)
            ? this.feedbackRating
            : feedbackRating as ZChatFeedbackRating?,
        feedbackCategory: identical(feedbackCategory, _unset)
            ? this.feedbackCategory
            : feedbackCategory as ZChatFeedbackCategory?,
        feedbackComment: identical(feedbackComment, _unset)
            ? this.feedbackComment
            : feedbackComment as String?,
        agentsCalled: identical(agentsCalled, _unset)
            ? this.agentsCalled
            : agentsCalled as List<String>?,
        confidence: identical(confidence, _unset)
            ? this.confidence
            : confidence as ZChatResponseConfidence?,
        sourceFreshness: identical(sourceFreshness, _unset)
            ? this.sourceFreshness
            : sourceFreshness as List<ZChatSourceFreshness>?,
        versionKey: identical(versionKey, _unset)
            ? this.versionKey
            : versionKey as String?,
        extension: identical(extension, _unset)
            ? this.extension
            : extension as ZExtension?,
        extra: identical(extra, _unset)
            ? this.extra
            : zSanitizeExtra(extra as Map<String, dynamic>, _reservedKeys),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatMessage &&
          id == other.id &&
          conversationId == other.conversationId &&
          role == other.role &&
          zListEquals(contentBlocks, other.contentBlocks) &&
          zListEquals(sources, other.sources) &&
          zListEquals(attachments, other.attachments) &&
          createdAt == other.createdAt &&
          zListEquals(thinking, other.thinking) &&
          zListEquals(suggestions, other.suggestions) &&
          feedbackRating == other.feedbackRating &&
          feedbackCategory == other.feedbackCategory &&
          feedbackComment == other.feedbackComment &&
          zListEquals(agentsCalled, other.agentsCalled) &&
          confidence == other.confidence &&
          zListEquals(sourceFreshness, other.sourceFreshness) &&
          versionKey == other.versionKey &&
          extension == other.extension &&
          // Égalité profonde du slot `extra` : `extra` porte du JSON imbriqué
          // par construction, et l'`==` d'une `Map` est une égalité d'identité
          // en Dart. `zJsonEquals` est l'implémentation unique du dépôt.
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        role,
        zListHash(contentBlocks),
        zListHash(sources),
        zListHash(attachments),
        createdAt,
        zListHash(thinking),
        zListHash(suggestions),
        feedbackRating,
        feedbackCategory,
        feedbackComment,
        zListHash(agentsCalled),
        confidence,
        zListHash(sourceFreshness),
        versionKey,
        extension,
        zJsonHash(extra),
      );

  @override
  String toString() =>
      'ZChatMessage(id: $id, conversationId: $conversationId, role: $role)';
}
