/// Métadonnées de **galerie publique** `ZPublicStudyFolder` (Story ES-9.4,
/// AC1/AC3/AC5).
///
/// origine: listing public d'un dossier partagé (AD-26). Ne porte QUE des
/// métadonnées **partageables** (titre, owner, date de mise en ligne) — **JAMAIS**
/// d'état personnel (SRS / ordre / lecture, AC3). L'`ownerUid` et le fait d'être
/// listé (`listedAt`) sont des **champs de contrôle** (AC5) : seul l'owner publie
/// / retire ([ZStudySharingAcl]).
///
/// Entité hand-written défensive (AD-10), AD-19.1 sur [extra].
library;

import 'package:zcrud_core/domain.dart';

/// Fiche **immuable** de galerie publique (value-object, `==`/`hashCode` par
/// valeur — égalité **profonde** de [extra]).
class ZPublicStudyFolder {
  /// Construit une fiche publique. [id] opaque, [listedAt] `null` si non listé.
  const ZPublicStudyFolder({
    this.id,
    this.folderId = '',
    this.ownerUid = '',
    this.title = '',
    this.listedAt,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Clés typées de l'entité (exclues de [extra] à la reconstruction).
  static const Set<String> _keys = <String>{
    'id',
    'folder_id',
    'owner_uid',
    'title',
    'listed_at',
  };

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// Reconstruit **défensivement** depuis une map (AD-10) — **jamais** de throw.
  static ZPublicStudyFolder fromJson(Object? json) {
    if (json is! Map) return const ZPublicStudyFolder();
    final map = <String, dynamic>{
      for (final e in json.entries) '${e.key}': e.value,
    };
    return ZPublicStudyFolder(
      id: map['id'] is String ? map['id'] as String : null,
      folderId: map['folder_id'] is String ? map['folder_id'] as String : '',
      ownerUid: map['owner_uid'] is String ? map['owner_uid'] as String : '',
      title: map['title'] is String ? map['title'] as String : '',
      listedAt: map['listed_at'] is String
          ? DateTime.tryParse(map['listed_at'] as String)
          : null,
      extra: <String, dynamic>{
        for (final e in map.entries)
          if (!_keys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Identité opaque `String` (nullable pour l'éphémère AD-14).
  final String? id;

  /// Dossier listé (clé neutre `String`).
  final String folderId;

  /// 🔴 **Champ de CONTRÔLE** (AC5) — propriétaire (uid opaque).
  final String ownerUid;

  /// Titre affiché en galerie (métadonnée partageable).
  final String title;

  /// 🔴 **Champ de CONTRÔLE** (AC5) — date de mise en galerie, `null` si retiré.
  final DateTime? listedAt;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée. **Normalisée à la LECTURE (AD-19.1)**.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Sérialise en clés snake_case. Étale [extra] (clés réservées déjà écartées).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'folder_id': folderId,
        'owner_uid': ownerUid,
        'title': title,
        'listed_at': listedAt?.toIso8601String(),
        ...extra,
      };

  /// Copie modifiée (champ à champ).
  ZPublicStudyFolder copyWith({
    String? id,
    String? folderId,
    String? ownerUid,
    String? title,
    Object? listedAt = _unset,
    Map<String, dynamic>? extra,
  }) =>
      ZPublicStudyFolder(
        id: id ?? this.id,
        folderId: folderId ?? this.folderId,
        ownerUid: ownerUid ?? this.ownerUid,
        title: title ?? this.title,
        listedAt:
            identical(listedAt, _unset) ? this.listedAt : listedAt as DateTime?,
        extra: extra ?? _extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPublicStudyFolder &&
          id == other.id &&
          folderId == other.folderId &&
          ownerUid == other.ownerUid &&
          title == other.title &&
          listedAt == other.listedAt &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        id,
        folderId,
        ownerUid,
        title,
        listedAt,
        zJsonHash(extra),
      );

  @override
  String toString() => 'ZPublicStudyFolder(id: $id, folderId: $folderId, '
      'ownerUid: $ownerUid, title: $title, listedAt: $listedAt)';
}

/// Sentinelle interne de [ZPublicStudyFolder.copyWith].
const Object _unset = Object();
