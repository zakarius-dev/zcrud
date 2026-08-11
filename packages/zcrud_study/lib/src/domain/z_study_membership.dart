/// Entité d'adhésion d'un acteur à un dossier d'étude partagé.
///
/// Surface de partage optionnelle du domaine : une adhésion lie un acteur
/// (`actorUid`) à un dossier (`folderId`) avec un rôle ([ZMembershipRole]).
/// C'est une entité contrôlée par le propriétaire : le `role` est un champ
/// de contrôle protégé par `ZStudySharingAcl`. Aucun état personnel
/// (répétition espacée, ordre, lecture) n'y vit.
///
/// Entité écrite à la main et désérialisée défensivement (invariant AD-10),
/// et non générée par codegen. Immuable, `const`, `==`/`hashCode` par
/// valeur (égalité profonde de [extra]).
library;

import 'package:zcrud_core/domain.dart';

/// Rôle d'un membre dans un dossier partagé — enum ouvert (invariant AD-10) :
/// toute valeur inconnue retombe sur [unknown], jamais de throw.
///
/// `role` est un champ de contrôle : seul le propriétaire peut le muter —
/// voir `ZStudySharingAcl.canMutateControl`. Un [contributor] ou un [viewer]
/// ne peut pas s'auto-promouvoir propriétaire.
enum ZMembershipRole {
  /// Propriétaire — seul habilité à muter les champs de contrôle.
  owner,

  /// Contributeur — peut éditer le contenu partageable, jamais un champ de
  /// contrôle.
  contributor,

  /// Lecteur — accès en lecture seule.
  viewer,

  /// Rôle inconnu (repli défensif) — traité comme non habilité.
  unknown;

  /// Reconstruit défensivement un rôle depuis une valeur brute.
  ///
  /// Une valeur non-`String` ou un nom non reconnu (`"moderator"`, `42`,
  /// `null`) retombe sur [unknown] — jamais de throw.
  static ZMembershipRole fromName(Object? raw) {
    if (raw is! String) return unknown;
    for (final r in values) {
      if (r.name == raw) return r;
    }
    return unknown;
  }
}

/// Adhésion immuable d'un acteur à un dossier partagé (value-object,
/// `==`/`hashCode` par valeur — égalité profonde de [extra]).
class ZStudyMembership {
  /// Construit une adhésion. [id] est opaque et nullable pour une adhésion
  /// pas encore persistée.
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

  /// Clés réservées écartées de [extra] à la lecture.
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// Reconstruit défensivement depuis une map (invariant AD-10) — ne lève
  /// jamais.
  ///
  /// Une map non conforme ou des champs corrompus retombent sur des
  /// défauts sûrs ; un rôle inconnu retombe sur [ZMembershipRole.unknown] ;
  /// les clés inconnues (hors [_keys]) atterrissent dans [extra].
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

  /// Identité opaque `String`, nullable pour l'adhésion pas encore
  /// persistée.
  final String? id;

  /// Dossier d'appartenance (clé neutre `String`).
  final String folderId;

  /// Acteur membre (identifiant opaque `String`).
  final String actorUid;

  /// Champ de contrôle : muté par le seul propriétaire (voir
  /// `ZStudySharingAcl`).
  final ZMembershipRole role;

  /// Slot brut de l'échappatoire (normalisé à la lecture via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée, normalisée à la lecture : les clés de
  /// synchronisation réservées (`updated_at`, `is_deleted`) sont toujours
  /// écartées.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Sérialise en clés snake_case ; le rôle en camelCase. Étale [extra]
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
