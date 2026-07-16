/// Signalement de modération `ZStudyFolderReport` (Story ES-9.4, AC1/AC3/AC6).
///
/// origine: modération communautaire d'un dossier publié (FR-S32). Un utilisateur
/// (`reporterUid`) signale un dossier (`folderId`) avec un motif (`reason`) et un
/// **statut** de traitement ([ZReportStatus]). Le port [ZStudyModerationPort]
/// consomme cette entité (`report`/`resolveReport`/`takedown`). **Aucun** état
/// personnel (AC3).
///
/// Entité hand-written défensive (AD-10), AD-19.1 sur [extra].
library;

import 'package:zcrud_core/domain.dart';

/// Statut de traitement d'un signalement — enum **OUVERT** (AD-10) : valeur
/// inconnue ⇒ [unknown] (jamais de throw).
enum ZReportStatus {
  /// Signalement ouvert, non traité.
  open,

  /// En cours d'examen par la modération.
  reviewing,

  /// Traité et résolu (action prise).
  resolved,

  /// Rejeté (pas d'action).
  dismissed,

  /// Statut **inconnu** (repli défensif AD-10).
  unknown;

  /// Reconstruit **défensivement** un statut depuis une valeur brute (AD-10).
  static ZReportStatus fromName(Object? raw) {
    if (raw is! String) return unknown;
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return unknown;
  }
}

/// Signalement **immuable** (value-object, `==`/`hashCode` par valeur — égalité
/// **profonde** de [extra]).
class ZStudyFolderReport {
  /// Construit un signalement. [id] opaque, [status] défaut [ZReportStatus.open].
  const ZStudyFolderReport({
    this.id,
    this.folderId = '',
    this.reporterUid = '',
    this.reason = '',
    this.status = ZReportStatus.open,
    this.createdAt,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Clés typées de l'entité (exclues de [extra] à la reconstruction).
  static const Set<String> _keys = <String>{
    'id',
    'folder_id',
    'reporter_uid',
    'reason',
    'status',
    'created_at',
  };

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  /// Reconstruit **défensivement** depuis une map (AD-10) — **jamais** de throw.
  static ZStudyFolderReport fromJson(Object? json) {
    if (json is! Map) return const ZStudyFolderReport();
    final map = <String, dynamic>{
      for (final e in json.entries) '${e.key}': e.value,
    };
    return ZStudyFolderReport(
      id: map['id'] is String ? map['id'] as String : null,
      folderId: map['folder_id'] is String ? map['folder_id'] as String : '',
      reporterUid:
          map['reporter_uid'] is String ? map['reporter_uid'] as String : '',
      reason: map['reason'] is String ? map['reason'] as String : '',
      status: ZReportStatus.fromName(map['status']),
      createdAt: map['created_at'] is String
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
      extra: <String, dynamic>{
        for (final e in map.entries)
          if (!_keys.contains(e.key)) e.key: e.value,
      },
    );
  }

  /// Identité opaque `String` (nullable pour l'éphémère AD-14).
  final String? id;

  /// Dossier signalé (clé neutre `String`).
  final String folderId;

  /// Auteur du signalement (uid opaque).
  final String reporterUid;

  /// Motif libre du signalement.
  final String reason;

  /// Statut de traitement (modération).
  final ZReportStatus status;

  /// Date du signalement (ISO-8601), ou `null`.
  final DateTime? createdAt;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée. **Normalisée à la LECTURE (AD-19.1)**.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Sérialise en clés snake_case ; le statut en camelCase. Étale [extra].
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'folder_id': folderId,
        'reporter_uid': reporterUid,
        'reason': reason,
        'status': status.name,
        'created_at': createdAt?.toIso8601String(),
        ...extra,
      };

  /// Copie modifiée (champ à champ).
  ZStudyFolderReport copyWith({
    String? id,
    String? folderId,
    String? reporterUid,
    String? reason,
    ZReportStatus? status,
    Object? createdAt = _unset,
    Map<String, dynamic>? extra,
  }) =>
      ZStudyFolderReport(
        id: id ?? this.id,
        folderId: folderId ?? this.folderId,
        reporterUid: reporterUid ?? this.reporterUid,
        reason: reason ?? this.reason,
        status: status ?? this.status,
        createdAt: identical(createdAt, _unset)
            ? this.createdAt
            : createdAt as DateTime?,
        extra: extra ?? _extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyFolderReport &&
          id == other.id &&
          folderId == other.folderId &&
          reporterUid == other.reporterUid &&
          reason == other.reason &&
          status == other.status &&
          createdAt == other.createdAt &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        id,
        folderId,
        reporterUid,
        reason,
        status,
        createdAt,
        zJsonHash(extra),
      );

  @override
  String toString() => 'ZStudyFolderReport(id: $id, folderId: $folderId, '
      'reporterUid: $reporterUid, status: $status)';
}

/// Sentinelle interne de [ZStudyFolderReport.copyWith].
const Object _unset = Object();
