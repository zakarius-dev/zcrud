/// Entité d'**adhésion** à un dossier d'étude partagé `ZStudyMembership`
/// (Story ES-9.4, AC1/AC3/AC5/AC6).
///
/// origine: surface de partage OPTIONNELLE du domaine `zcrud_study` (AD-26 : le
/// partage est une extension activable, **jamais** un invariant du domaine). Une
/// adhésion lie un acteur (`actorUid`) à un dossier (`folderId`) avec un **rôle**
/// ([ZMembershipRole]) — c'est une entité **owner-contrôlée** : le `role` est un
/// **champ de contrôle** protégé par [ZStudySharingAcl] (dette sécu lex corrigée,
/// AC5). **Aucun** état personnel (SRS / ordre / lecture) n'y vit (AC3).
///
/// Entité **hand-written défensive** (AD-10), PAS `@ZcrudModel` : `zcrud_study`
/// n'a aucun codegen. Immuable, `const`, `==`/`hashCode` par valeur (égalité
/// **profonde** de [extra]). AD-19.1 : slot `_extra` brut + accesseur
/// [extra] = `zSanitizeExtra` (les clés de sync réservées `updated_at`/`is_deleted`
/// sont écartées à la LECTURE ; aucun champ `updatedAt`/`isDeleted` interne — LWW
/// **hors-entité** exclusivement).
library;

import 'package:zcrud_core/domain.dart';

/// Rôle d'un membre dans un dossier partagé — enum **OUVERT** (AD-10) : toute
/// valeur inconnue retombe sur [unknown] (jamais de throw).
///
/// **`role` est un champ de CONTRÔLE** (AC5) : seul l'owner peut le muter — cf.
/// [ZStudySharingAcl.canMutateControl]. Un [contributor]/[viewer] ne peut PAS
/// s'auto-promouvoir owner.
enum ZMembershipRole {
  /// Propriétaire — **seul** habilité à muter les champs de contrôle (AC5).
  owner,

  /// Contributeur — peut éditer le contenu partageable, **jamais** un champ de
  /// contrôle (cœur de la dette sécu lex, AC5).
  contributor,

  /// Lecteur — accès en lecture seule.
  viewer,

  /// Rôle **inconnu** (repli défensif AD-10) — traité comme non habilité.
  unknown;

  /// Reconstruit **défensivement** un rôle depuis une valeur brute (AD-10).
  ///
  /// Une valeur non-`String` ou un nom non reconnu (`"moderator"`, `42`, `null`)
  /// retombe sur [unknown] — **jamais** de throw.
  static ZMembershipRole fromName(Object? raw) {
    if (raw is! String) return unknown;
    for (final r in values) {
      if (r.name == raw) return r;
    }
    return unknown;
  }
}

/// Adhésion **immuable** d'un acteur à un dossier partagé (value-object,
/// `==`/`hashCode` par valeur — égalité **profonde** de [extra]).
class ZStudyMembership {
  /// Construit une adhésion. [id] est opaque et nullable (éphémère AD-14).
  const ZStudyMembership({
    this.id,
    this.folderId = '',
    this.actorUid = '',
    this.role = ZMembershipRole.viewer,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Clés typées de l'entité (exclues de [extra] à la reconstruction).
  static const Set<String> _keys = <String>{
    'id',
    'folder_id',
    'actor_uid',
    'role',
  };

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// Reconstruit **défensivement** depuis une map (AD-10) — **jamais** de throw.
  ///
  /// Map non conforme / champs corrompus ⇒ défauts sûrs ; rôle inconnu ⇒
  /// [ZMembershipRole.unknown] ; les clés inconnues (hors [_keys]) atterrissent
  /// dans [extra] (round-trip additif AD-4).
  static ZStudyMembership fromJson(Object? json) {
    if (json is! Map) return const ZStudyMembership();
    final map = <String, dynamic>{
      for (final e in json.entries) '${e.key}': e.value,
    };
    return ZStudyMembership(
      id: map['id'] is String ? map['id'] as String : null,
      folderId: map['folder_id'] is String ? map['folder_id'] as String : '',
      actorUid: map['actor_uid'] is String ? map['actor_uid'] as String : '',
      role: ZMembershipRole.fromName(map['role']),
      extra: <String, dynamic>{
        for (final e in map.entries)
          if (!_keys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Identité opaque `String` (nullable pour l'éphémère AD-14).
  final String? id;

  /// Dossier d'appartenance (clé neutre `String`).
  final String folderId;

  /// Acteur membre (uid opaque `String`).
  final String actorUid;

  /// 🔴 **Champ de CONTRÔLE** (AC5) — muté par le seul owner ([ZStudySharingAcl]).
  final ZMembershipRole role;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée. **Normalisée à la LECTURE (AD-19.1)** : les clés de
  /// sync réservées (`updated_at`/`is_deleted`) sont écartées — jamais réémises.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Sérialise en clés snake_case ; le rôle en camelCase (AD-3). Étale [extra]
  /// (accesseur — donc clés réservées déjà écartées).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'folder_id': folderId,
        'actor_uid': actorUid,
        'role': role.name,
        ...extra,
      };

  /// Copie modifiée (champ à champ).
  ZStudyMembership copyWith({
    String? id,
    String? folderId,
    String? actorUid,
    ZMembershipRole? role,
    Map<String, dynamic>? extra,
  }) =>
      ZStudyMembership(
        id: id ?? this.id,
        folderId: folderId ?? this.folderId,
        actorUid: actorUid ?? this.actorUid,
        role: role ?? this.role,
        extra: extra ?? _extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyMembership &&
          id == other.id &&
          folderId == other.folderId &&
          actorUid == other.actorUid &&
          role == other.role &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(id, folderId, actorUid, role, zJsonHash(extra));

  @override
  String toString() => 'ZStudyMembership(id: $id, folderId: $folderId, '
      'actorUid: $actorUid, role: $role)';
}
