/// Lien de partage **révocable** `ZShareLink` (Story ES-9.4, AC4/AC5/AC6, AD-20).
///
/// origine: `study_share_links` (collection **GLOBALE** côté lex — résolution de
/// chemin **hors domaine**, AD-20). Un lien lie un dossier (`folderId`) à son
/// owner (`ownerUid`) et porte un état de **révocation MONOTONE** (`revoked` +
/// `revokedAt`). C'est une entité **owner-contrôlée** : `revoked` et `ownerUid`
/// sont des **champs de contrôle** (AC5) — un contributeur ne peut PAS
/// dé-révoquer un lien (la « dé-révocation LWW » de lex est fermée au niveau de
/// l'autorisation domaine via [ZStudySharingAcl]).
///
/// **Aucun** nom de collection en dur ici (`study_share_links` = concern
/// d'adapter, AD-20) ; **aucun** état personnel (AC3). Entité hand-written
/// défensive (AD-10), AD-19.1 sur [extra] (slot `_extra` + `zSanitizeExtra`).
library;

import 'package:zcrud_core/domain.dart';

/// Lien de partage **immuable** et **révocable** (value-object, `==`/`hashCode`
/// par valeur — égalité **profonde** de [extra]).
///
/// La révocation **survit au décodage** (round-trip `toJson`/`fromJson`, AC4) :
/// un lien révoqué reste révoqué (parité leçon M3 kernel).
class ZShareLink {
  /// Construit un lien de partage. [id]/[token] opaques, [revoked] défaut `false`.
  const ZShareLink({
    this.id,
    this.token = '',
    this.folderId = '',
    this.ownerUid = '',
    this.revoked = false,
    this.revokedAt,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Clés typées de l'entité (exclues de [extra] à la reconstruction).
  static const Set<String> _keys = <String>{
    'id',
    'token',
    'folder_id',
    'owner_uid',
    'revoked',
    'revoked_at',
  };

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// Reconstruit **défensivement** depuis une map (AD-10) — **jamais** de throw.
  ///
  /// L'état de révocation **survit** (AC4) ; `revoked` non-`bool` ⇒ `false` sûr ;
  /// `revoked_at` mal formé ⇒ `null`. Les clés inconnues atterrissent dans [extra].
  static ZShareLink fromJson(Object? json) {
    if (json is! Map) return const ZShareLink();
    final map = <String, dynamic>{
      for (final e in json.entries) '${e.key}': e.value,
    };
    return ZShareLink(
      id: map['id'] is String ? map['id'] as String : null,
      token: map['token'] is String ? map['token'] as String : '',
      folderId: map['folder_id'] is String ? map['folder_id'] as String : '',
      ownerUid: map['owner_uid'] is String ? map['owner_uid'] as String : '',
      revoked: map['revoked'] is bool ? map['revoked'] as bool : false,
      revokedAt: _parseIso(map['revoked_at']),
      extra: <String, dynamic>{
        for (final e in map.entries)
          if (!_keys.contains(e.key)) e.key: e.value,
      },
    );
  }

  static DateTime? _parseIso(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;

  /// Identité opaque `String` (nullable pour l'éphémère AD-14).
  final String? id;

  /// Jeton de partage opaque `String` (défaut `''`).
  final String token;

  /// Dossier ciblé par le lien (clé neutre `String`).
  final String folderId;

  /// 🔴 **Champ de CONTRÔLE** (AC5) — propriétaire du lien (uid opaque).
  final String ownerUid;

  /// 🔴 **Champ de CONTRÔLE MONOTONE** (AC5) — `true` une fois révoqué. Un
  /// non-owner ne peut PAS le remettre à `false` ([ZStudySharingAcl]).
  final bool revoked;

  /// Horodatage de révocation (ISO-8601), ou `null` si actif.
  final DateTime? revokedAt;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée. **Normalisée à la LECTURE (AD-19.1)**.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Retourne une **copie révoquée** de ce lien (helper de révocation monotone).
  ///
  /// [at] horodate la révocation (défaut : conserve [revokedAt] courant s'il
  /// existe, sinon `null`). La révocation est **monotone** côté domaine : ce
  /// helper ne dé-révoque **jamais**.
  ZShareLink revoke({DateTime? at}) =>
      copyWith(revoked: true, revokedAt: at ?? revokedAt);

  /// Sérialise en clés snake_case. Étale [extra] (clés réservées déjà écartées).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'token': token,
        'folder_id': folderId,
        'owner_uid': ownerUid,
        'revoked': revoked,
        'revoked_at': revokedAt?.toIso8601String(),
        ...extra,
      };

  /// Copie modifiée (champ à champ). [revokedAt] via sentinelle pour permettre la
  /// remise à `null`.
  ZShareLink copyWith({
    String? id,
    String? token,
    String? folderId,
    String? ownerUid,
    bool? revoked,
    Object? revokedAt = _unset,
    Map<String, dynamic>? extra,
  }) =>
      ZShareLink(
        id: id ?? this.id,
        token: token ?? this.token,
        folderId: folderId ?? this.folderId,
        ownerUid: ownerUid ?? this.ownerUid,
        revoked: revoked ?? this.revoked,
        revokedAt: identical(revokedAt, _unset)
            ? this.revokedAt
            : revokedAt as DateTime?,
        extra: extra ?? _extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZShareLink &&
          id == other.id &&
          token == other.token &&
          folderId == other.folderId &&
          ownerUid == other.ownerUid &&
          revoked == other.revoked &&
          revokedAt == other.revokedAt &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        id,
        token,
        folderId,
        ownerUid,
        revoked,
        revokedAt,
        zJsonHash(extra),
      );

  @override
  String toString() => 'ZShareLink(id: $id, folderId: $folderId, '
      'ownerUid: $ownerUid, revoked: $revoked)';
}

/// Sentinelle interne de [ZShareLink.copyWith] (distingue « omis » de `null`).
const Object _unset = Object();
