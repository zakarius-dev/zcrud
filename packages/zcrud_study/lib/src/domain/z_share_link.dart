/// Lien de partage révocable d'un dossier d'étude.
///
/// Un lien lie un dossier (`folderId`) à son propriétaire (`ownerUid`) et
/// porte un état de révocation monotone (`revoked` + `revokedAt`). C'est une
/// entité contrôlée par le propriétaire : `revoked` et `ownerUid` sont des
/// champs de contrôle — un contributeur ne peut pas dé-révoquer un lien,
/// cette possibilité étant fermée au niveau de l'autorisation domaine (voir
/// `ZStudySharingAcl`).
///
/// Aucun nom de collection n'est codé en dur ici : la résolution du chemin
/// de stockage est un concern d'adaptateur, hors du domaine. Aucun état
/// personnel n'y vit non plus. Entité écrite à la main et désérialisée
/// défensivement (invariant AD-10).
library;

import 'package:zcrud_core/domain.dart';

/// Lien de partage immuable et révocable (value-object, `==`/`hashCode` par
/// valeur — égalité profonde de [extra]).
///
/// La révocation survit au décodage (round-trip `toJson`/`fromJson`) : un
/// lien révoqué reste révoqué.
class ZShareLink {
  /// Construit un lien de partage. [id]/[token] opaques, [revoked] défaut
  /// `false`.
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

  /// Clés réservées écartées de [extra] à la lecture.
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// Reconstruit défensivement depuis une map (invariant AD-10) — ne lève
  /// jamais.
  ///
  /// L'état de révocation survit à la reconstruction ; un `revoked`
  /// non-`bool` retombe sur `false` ; un `revoked_at` mal formé retombe sur
  /// `null`. Les clés inconnues atterrissent dans [extra].
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

  /// Identité opaque `String`, nullable pour le lien pas encore persisté.
  final String? id;

  /// Jeton de partage opaque `String` (défaut `''`).
  final String token;

  /// Dossier ciblé par le lien (clé neutre `String`).
  final String folderId;

  /// Champ de contrôle : propriétaire du lien (identifiant opaque).
  final String ownerUid;

  /// Champ de contrôle monotone : `true` une fois révoqué. Un
  /// non-propriétaire ne peut pas le remettre à `false` (voir
  /// `ZStudySharingAcl`).
  final bool revoked;

  /// Horodatage de révocation (ISO-8601), ou `null` si actif.
  final DateTime? revokedAt;

  /// Slot brut de l'échappatoire (normalisé à la lecture via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée, normalisée à la lecture.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Retourne une copie révoquée de ce lien (aide à la révocation
  /// monotone).
  ///
  /// [at] horodate la révocation (défaut : conserve [revokedAt] courant
  /// s'il existe, sinon `null`). La révocation est monotone côté domaine :
  /// cette méthode ne dé-révoque jamais.
  ZShareLink revoke({DateTime? at}) =>
      copyWith(revoked: true, revokedAt: at ?? revokedAt);

  /// Sérialise en clés snake_case. Étale [extra] (clés réservées déjà
  /// écartées).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'token': token,
        'folder_id': folderId,
        'owner_uid': ownerUid,
        'revoked': revoked,
        'revoked_at': revokedAt?.toIso8601String(),
        ...extra,
      };

  /// Copie modifiée (champ à champ). [revokedAt] passe par une sentinelle
  /// pour permettre la remise à `null`.
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

/// Sentinelle interne de [ZShareLink.copyWith] (distingue « omis » de
/// `null`).
const Object _unset = Object();
