// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'z_repetition_info.dart';

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

ZRepetitionInfo _$ZRepetitionInfoFromMap(Map<String, dynamic> map) =>
    ZRepetitionInfo(
      flashcardId: map['flashcard_id'] is String
          ? map['flashcard_id'] as String
          : '',
      folderId: map['folder_id'] is String ? map['folder_id'] as String : '',
      interval: _$asInt(map['interval']) ?? 0,
      repetitions: _$asInt(map['repetitions']) ?? 0,
      easeFactor: _$asDouble(map['ease_factor']) ?? 2.5,
      nextReviewDate: _$asDateTime(map['next_review_date']),
      learnedAt: _$asDateTime(map['learned_at']),
      lastQuality: _$asInt(map['last_quality']),
    );

extension ZRepetitionInfoZcrud on ZRepetitionInfo {
  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'flashcard_id': this.flashcardId,
    'folder_id': this.folderId,
    'interval': this.interval,
    'repetitions': this.repetitions,
    'ease_factor': this.easeFactor,
    'next_review_date': this.nextReviewDate?.toIso8601String(),
    'learned_at': this.learnedAt?.toIso8601String(),
    'last_quality': this.lastQuality,
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZRepetitionInfo copyWith({
    Object? flashcardId = _$undefined,
    Object? folderId = _$undefined,
    Object? interval = _$undefined,
    Object? repetitions = _$undefined,
    Object? easeFactor = _$undefined,
    Object? nextReviewDate = _$undefined,
    Object? learnedAt = _$undefined,
    Object? lastQuality = _$undefined,
  }) => ZRepetitionInfo(
    flashcardId: identical(flashcardId, _$undefined)
        ? this.flashcardId
        : flashcardId as String,
    folderId: identical(folderId, _$undefined)
        ? this.folderId
        : folderId as String,
    interval: identical(interval, _$undefined)
        ? this.interval
        : interval as int,
    repetitions: identical(repetitions, _$undefined)
        ? this.repetitions
        : repetitions as int,
    easeFactor: identical(easeFactor, _$undefined)
        ? this.easeFactor
        : easeFactor as double,
    nextReviewDate: identical(nextReviewDate, _$undefined)
        ? this.nextReviewDate
        : nextReviewDate as DateTime?,
    learnedAt: identical(learnedAt, _$undefined)
        ? this.learnedAt
        : learnedAt as DateTime?,
    lastQuality: identical(lastQuality, _$undefined)
        ? this.lastQuality
        : lastQuality as int?,
  );
}

/// Schéma déclaratif projeté depuis @ZcrudField (E2-5).
const List<ZFieldSpec> $ZRepetitionInfoFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'flashcard_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'folder_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'interval', type: EditionFieldType.integer),
  ZFieldSpec(name: 'repetitions', type: EditionFieldType.integer),
  ZFieldSpec(
    name: 'ease_factor',
    type: EditionFieldType.float,
    defaultValue: 2.5,
  ),
  ZFieldSpec(name: 'next_review_date', type: EditionFieldType.dateTime),
  ZFieldSpec(name: 'learned_at', type: EditionFieldType.dateTime),
  ZFieldSpec(name: 'last_quality', type: EditionFieldType.integer),
];

/// Enregistre `ZRepetitionInfo` (kind "repetition_info") sur [registry] : (dé)sérialisation + schéma.
void registerZRepetitionInfo(ZcrudRegistry registry) =>
    registry.register<ZRepetitionInfo>(
      'repetition_info',
      fromMap: _$ZRepetitionInfoFromMap,
      toMap: (value) => value.toMap(),
      fieldSpecs: $ZRepetitionInfoFieldSpecs,
    );
