// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'z_flashcard.dart';

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

ZFlashcard _$ZFlashcardFromMap(Map<String, dynamic> map) => ZFlashcard(
  id: map['id'] is String ? map['id'] as String : null,
  folderId: map['folder_id'] is String ? map['folder_id'] as String : null,
  subFolderId: map['sub_folder_id'] is String
      ? map['sub_folder_id'] as String
      : null,
  type:
      _$enumFromName(ZFlashcardType.values, map['type']) ??
      ZFlashcardType.openQuestion,
  question: map['question'] is String ? map['question'] as String : '',
  answer: map['answer'] is String ? map['answer'] as String : null,
  isTrue: map['is_true'] is bool ? map['is_true'] as bool : null,
  choices: map['choices'] is List
      ? (map['choices'] as List)
            .map((e) => _$decodeModel(e, ZChoice.fromMap))
            .whereType<ZChoice>()
            .toList()
      : null,
  explanation: map['explanation'] is String
      ? map['explanation'] as String
      : null,
  hint: map['hint'] is String ? map['hint'] as String : null,
  tagIds: map['tag_ids'] is List
      ? (map['tag_ids'] as List).whereType<String>().toList()
      : const <String>[],
  isReadOnly: map['is_read_only'] is bool ? map['is_read_only'] as bool : false,
  createdAt: _$asDateTime(map['created_at']),
  updatedAt: _$asDateTime(map['updated_at']),
);

extension ZFlashcardZcrud on ZFlashcard {
  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': this.id,
    'folder_id': this.folderId,
    'sub_folder_id': this.subFolderId,
    'type': this.type.name,
    'question': this.question,
    'answer': this.answer,
    'is_true': this.isTrue,
    'choices': this.choices?.map((e) => e.toMap()).toList(),
    'explanation': this.explanation,
    'hint': this.hint,
    'tag_ids': this.tagIds,
    'is_read_only': this.isReadOnly,
    'created_at': this.createdAt?.toIso8601String(),
    'updated_at': this.updatedAt?.toIso8601String(),
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZFlashcard copyWith({
    Object? id = _$undefined,
    Object? folderId = _$undefined,
    Object? subFolderId = _$undefined,
    Object? type = _$undefined,
    Object? question = _$undefined,
    Object? answer = _$undefined,
    Object? isTrue = _$undefined,
    Object? choices = _$undefined,
    Object? explanation = _$undefined,
    Object? hint = _$undefined,
    Object? tagIds = _$undefined,
    Object? isReadOnly = _$undefined,
    Object? createdAt = _$undefined,
    Object? updatedAt = _$undefined,
  }) => ZFlashcard(
    id: identical(id, _$undefined) ? this.id : id as String?,
    folderId: identical(folderId, _$undefined)
        ? this.folderId
        : folderId as String?,
    subFolderId: identical(subFolderId, _$undefined)
        ? this.subFolderId
        : subFolderId as String?,
    type: identical(type, _$undefined) ? this.type : type as ZFlashcardType,
    question: identical(question, _$undefined)
        ? this.question
        : question as String,
    answer: identical(answer, _$undefined) ? this.answer : answer as String?,
    isTrue: identical(isTrue, _$undefined) ? this.isTrue : isTrue as bool?,
    choices: identical(choices, _$undefined)
        ? this.choices
        : choices as List<ZChoice>?,
    explanation: identical(explanation, _$undefined)
        ? this.explanation
        : explanation as String?,
    hint: identical(hint, _$undefined) ? this.hint : hint as String?,
    tagIds: identical(tagIds, _$undefined)
        ? this.tagIds
        : tagIds as List<String>,
    isReadOnly: identical(isReadOnly, _$undefined)
        ? this.isReadOnly
        : isReadOnly as bool,
    createdAt: identical(createdAt, _$undefined)
        ? this.createdAt
        : createdAt as DateTime?,
    updatedAt: identical(updatedAt, _$undefined)
        ? this.updatedAt
        : updatedAt as DateTime?,
  );
}

/// Schéma déclaratif projeté depuis @ZcrudField (E2-5).
const List<ZFieldSpec> $ZFlashcardFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'folder_id', type: EditionFieldType.text),
  ZFieldSpec(name: 'sub_folder_id', type: EditionFieldType.text),
  ZFieldSpec(
    name: 'type',
    type: EditionFieldType.select,
    defaultValue: ZFlashcardType.openQuestion,
  ),
  ZFieldSpec(
    name: 'question',
    type: EditionFieldType.text,
    label: 'Question',
    validators: [ZValidatorSpec.required()],
  ),
  ZFieldSpec(name: 'answer', type: EditionFieldType.text),
  ZFieldSpec(name: 'is_true', type: EditionFieldType.boolean),
  ZFieldSpec(name: 'choices', type: EditionFieldType.subItems, multiple: true),
  ZFieldSpec(name: 'explanation', type: EditionFieldType.text),
  ZFieldSpec(name: 'hint', type: EditionFieldType.text),
  ZFieldSpec(name: 'tag_ids', type: EditionFieldType.text, multiple: true),
  ZFieldSpec(name: 'is_read_only', type: EditionFieldType.boolean),
  ZFieldSpec(name: 'created_at', type: EditionFieldType.dateTime),
  ZFieldSpec(name: 'updated_at', type: EditionFieldType.dateTime),
];

/// Enregistre `ZFlashcard` (kind "flashcard") sur [registry] : (dé)sérialisation + schéma.
void registerZFlashcard(ZcrudRegistry registry) =>
    registry.register<ZFlashcard>(
      'flashcard',
      fromMap: _$ZFlashcardFromMap,
      toMap: (value) => value.toMap(),
      fieldSpecs: $ZFlashcardFieldSpecs,
    );
