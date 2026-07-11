// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'z_study_session_config.dart';

// **************************************************************************
// ZcrudModelGenerator
// **************************************************************************

/// Sentinelle « argument non fourni » du `copyWith` généré (reset-null).
const Object? _$undefined = _ZUndefined();

class _ZUndefined {
  const _ZUndefined();
}

int? _$asInt(Object? v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is num) return v.toInt();
  return null;
}

double? _$asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

num? _$asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

DateTime? _$asDateTime(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

T? _$enumFromName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Coerce défensive vers `Map<String, dynamic>` (AD-10) : `null` si [v] n'est
/// pas une Map ; sinon convertit toute clé en `String` (`Map<dynamic, dynamic>`
/// forgée / Hive) SANS jamais throw — un sous-objet à clés non-`String` ne casse
/// donc JAMAIS le parent (repli `null`).
Map<String, dynamic>? _$asStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return <String, dynamic>{for (final e in v.entries) '${e.key}': e.value};
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Décode défensivement un sous-modèle (AD-10) : coerce [v] en
/// `Map<String, dynamic>` puis délègue à [fromMap]. Toute anomalie (non-map,
/// clés non-`String`, `fromMap` qui throw) retombe sur `null` — le parent
/// survit toujours (sous-objet = `null`, filtrable en liste via `whereType`).
T? _$decodeModel<T>(Object? v, T Function(Map<String, dynamic>) fromMap) {
  final m = _$asStringMap(v);
  if (m == null) return null;
  try {
    return fromMap(m);
  } catch (_) {
    return null;
  }
}

ZStudySessionConfig _$ZStudySessionConfigFromMap(Map<String, dynamic> map) =>
    ZStudySessionConfig(
      mode:
          _$enumFromName(ZReviewMode.values, map['mode']) ?? ZReviewMode.spaced,
      folderId: map['folder_id'] is String ? map['folder_id'] as String : null,
      tagIds: map['tag_ids'] is List
          ? (map['tag_ids'] as List).whereType<String>().toList()
          : null,
      types: map['types'] is List
          ? (map['types'] as List)
                .map((e) => _$enumFromName(ZFlashcardType.values, e))
                .whereType<ZFlashcardType>()
                .toList()
          : null,
      count: _$asInt(map['count']),
    );

extension ZStudySessionConfigZcrud on ZStudySessionConfig {
  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'mode': this.mode.name,
    'folder_id': this.folderId,
    'tag_ids': this.tagIds,
    'types': this.types?.map((e) => e.name).toList(),
    'count': this.count,
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZStudySessionConfig copyWith({
    Object? mode = _$undefined,
    Object? folderId = _$undefined,
    Object? tagIds = _$undefined,
    Object? types = _$undefined,
    Object? count = _$undefined,
  }) => ZStudySessionConfig(
    mode: identical(mode, _$undefined) ? this.mode : mode as ZReviewMode,
    folderId: identical(folderId, _$undefined)
        ? this.folderId
        : folderId as String?,
    tagIds: identical(tagIds, _$undefined)
        ? this.tagIds
        : tagIds as List<String>?,
    types: identical(types, _$undefined)
        ? this.types
        : types as List<ZFlashcardType>?,
    count: identical(count, _$undefined) ? this.count : count as int?,
  );
}

/// Schéma déclaratif projeté depuis @ZcrudField (E2-5).
const List<ZFieldSpec> $ZStudySessionConfigFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(
    name: 'mode',
    type: EditionFieldType.select,
    defaultValue: ZReviewMode.spaced,
  ),
  ZFieldSpec(name: 'folder_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'tag_ids', type: EditionFieldType.text, multiple: true),
  ZFieldSpec(name: 'types', type: EditionFieldType.select, multiple: true),
  ZFieldSpec(name: 'count', type: EditionFieldType.integer),
];

/// Enregistre `ZStudySessionConfig` (kind "study_session_config") sur [registry] : (dé)sérialisation + schéma.
void registerZStudySessionConfig(ZcrudRegistry registry) =>
    registry.register<ZStudySessionConfig>(
      'study_session_config',
      fromMap: _$ZStudySessionConfigFromMap,
      toMap: (value) => value.toMap(),
      fieldSpecs: $ZStudySessionConfigFieldSpecs,
    );

/// Clés persistées à encoder en `Timestamp` Firestore natif (gap B14, AD-5).
///
/// Métadonnée NEUTRE (littéraux `String`) : à passer au param `timestampFields`
/// de `FirebaseZRepositoryImpl` — `Timestamp` reste confiné à `zcrud_firestore`.
const Set<String> $ZStudySessionConfigTimestampFields = <String>{};
