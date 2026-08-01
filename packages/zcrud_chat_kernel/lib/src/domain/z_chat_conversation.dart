/// Conversation IA — `ZChatConversation` (AD-4, AD-10, AD-16, AD-19).
///
/// origine: lex_core (module « Assistant ») — `chat_conversation.dart:6-54`.
///
/// ## 🔴 D3 — pourquoi `updated_at` devient `last_message_at`
///
/// `ChatConversation` de lex persiste **`updated_at` dans le corps du document**
/// (`chat_conversation.dart:11-12`) pour trier les conversations par récence.
/// En zcrud, `updated_at` et `is_deleted` sont **réservés hors-entité** (AD-16 /
/// AD-19, `ZSyncMeta.reservedKeys`). Un `updated_at` **métier** logé dans le
/// corps entre en collision avec l'autorité de synchronisation : le store écrit
/// `ZSyncMeta` **APRÈS** le corps ⇒ **le merge Last-Write-Wins est faussé,
/// silencieusement, sans un seul test rouge**.
///
/// Le besoin métier est donc conservé, mais **nommé par son sens** :
/// [ZChatConversation.lastMessageAt], persisté **`last_message_at`**. [toMap]
/// n'émet **ni** `updated_at` **ni** `is_deleted`, **jamais**, sans aucune
/// exception « miroir legacy ». Garde **G12**.
///
/// ## Ce qui n'est PAS porté
///
/// Le scoping d'IFFD (`folderId`/`subFolderId`/`documentId`) et ses
/// `isArchived`/`isChatSession`/`conversationSummary` sont des **spécificités
/// d'hôte** : ils passent par [ZChatConversation.extra] ou par un `ZExtension`
/// versionné (AD-4), pas par le schéma partagé.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_extension_parser.dart';

/// Sentinelle de `copyWith` : distingue « argument omis » de « remis à `null` ».
const Object _unset = Object();

/// Une conversation IA — entité canonique **extensible**.
class ZChatConversation extends ZEntity with ZExtensible {
  /// Construit une conversation (primitif `const`).
  ///
  /// ⛔ **Aucun `assert`** (AD-10) et **aucun filtrage** possible : le
  /// constructeur est `const`. C'est l'**accesseur** [extra] qui porte la garde.
  const ZChatConversation({
    this.id,
    this.title = '',
    this.createdAt,
    this.lastMessageAt,
    this.messageCount = 0,
    this.pinned = false,
    this.pinnedAt,
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit **défensivement** depuis une map persistée (AD-10) — aucun cas
  /// ne lève, pas même `ZChatConversation.fromMap(const {})`.
  factory ZChatConversation.fromMap(
    Map<String, dynamic> map, {
    ZChatExtensionParser? extensionParser,
  }) =>
      ZChatConversation(
        id: zJsonStringOrNull(map['id']),
        title: zJsonString(map['title']),
        createdAt: zJsonDate(map['created_at']),
        lastMessageAt: zJsonDate(map[kZChatLastMessageAtKey]),
        messageCount: zJsonInt(map['message_count'], 0),
        pinned: zJsonBool(map['pinned'], false),
        pinnedAt: zJsonDate(map['pinned_at']),
        extension: zDecodeExtension(map['extension'], extensionParser),
        // 🔴 NORMALISATION **EAGER** à l'ENTRÉE (assertion (i.3b) du gate).
        extra: zSanitizeExtra(map, _reservedKeys),
      );

  /// Identité opaque, `null` si la conversation est éphémère.
  @override
  final String? id;

  /// Titre de la conversation (défaut `''`).
  final String title;

  /// Date de création, ou `null` si absente/illisible.
  final DateTime? createdAt;

  /// 🔴 Date du **dernier message** — le champ métier de tri par récence.
  ///
  /// Persisté [kZChatLastMessageAtKey] (`last_message_at`), **jamais**
  /// `updated_at` : cette dernière appartient à `ZSyncMeta` (AD-16/AD-19), et
  /// la loger dans le corps fausserait le merge Last-Write-Wins (**D3**).
  final DateTime? lastMessageAt;

  /// Nombre de messages (défaut `0`).
  final int messageCount;

  /// Conversation épinglée (défaut `false`).
  final bool pinned;

  /// Date d'épinglage, ou `null`.
  final DateTime? pinnedAt;

  /// Slot type additif **versionné** (AD-4 pt.1) — porte notamment le scoping
  /// d'un hôte (dossier, document…) sans polluer le schéma partagé.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4 pt.2) — l'accesseur **NORMALISE**.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Slot `extra` **BRUT** tel que reçu par le constructeur.
  final Map<String, dynamic> _extra;

  /// Clés persistées **RÉSERVÉES** : schéma ∪ `extension` ∪
  /// **`ZSyncMeta.reservedKeys`** (AD-19).
  static const Set<String> _reservedKeys = <String>{
    'id',
    'title',
    'created_at',
    kZChatLastMessageAtKey,
    'message_count',
    'pinned',
    'pinned_at',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  /// Sérialise vers la map persistée (clés snake_case), [extra] étalé d'abord.
  ///
  /// ⛔ **N'émet NI `updated_at` NI `is_deleted`** — sans exception (**G12**).
  Map<String, dynamic> toMap() => <String, dynamic>{
        ...extra,
        if (id != null) 'id': id,
        'title': title,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (lastMessageAt != null)
          kZChatLastMessageAtKey: lastMessageAt!.toIso8601String(),
        'message_count': messageCount,
        'pinned': pinned,
        if (pinnedAt != null) 'pinned_at': pinnedAt!.toIso8601String(),
        if (extension != null) 'extension': extension!.toJson(),
      };

  /// Copie **à sentinelle** — un argument omis conserve la valeur, `null`
  /// explicite la remet à `null`. `extra` est **sanitisé EAGER** (**G13(b)**).
  ZChatConversation copyWith({
    Object? id = _unset,
    Object? title = _unset,
    Object? createdAt = _unset,
    Object? lastMessageAt = _unset,
    Object? messageCount = _unset,
    Object? pinned = _unset,
    Object? pinnedAt = _unset,
    Object? extension = _unset,
    Object? extra = _unset,
  }) =>
      ZChatConversation(
        id: identical(id, _unset) ? this.id : id as String?,
        title: identical(title, _unset) ? this.title : title as String,
        createdAt: identical(createdAt, _unset)
            ? this.createdAt
            : createdAt as DateTime?,
        lastMessageAt: identical(lastMessageAt, _unset)
            ? this.lastMessageAt
            : lastMessageAt as DateTime?,
        messageCount: identical(messageCount, _unset)
            ? this.messageCount
            : messageCount as int,
        pinned: identical(pinned, _unset) ? this.pinned : pinned as bool,
        pinnedAt:
            identical(pinnedAt, _unset) ? this.pinnedAt : pinnedAt as DateTime?,
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
      other is ZChatConversation &&
          id == other.id &&
          title == other.title &&
          createdAt == other.createdAt &&
          lastMessageAt == other.lastMessageAt &&
          messageCount == other.messageCount &&
          pinned == other.pinned &&
          pinnedAt == other.pinnedAt &&
          extension == other.extension &&
          // Égalité PROFONDE du slot `extra` (DW-ES22-4).
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        id,
        title,
        createdAt,
        lastMessageAt,
        messageCount,
        pinned,
        pinnedAt,
        extension,
        zJsonHash(extra),
      );

  @override
  String toString() => 'ZChatConversation(id: $id, title: $title)';
}

/// Clé persistée du champ métier de récence — **jamais** `updated_at` (**D3**).
///
/// Déclarée **une seule fois** et consommée par `fromMap`, `toMap` **et** les
/// clés réservées : zéro littéral dupliqué, donc aucune divergence possible
/// entre les trois voies.
const String kZChatLastMessageAtKey = 'last_message_at';
