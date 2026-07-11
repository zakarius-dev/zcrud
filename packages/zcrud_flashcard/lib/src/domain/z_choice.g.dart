// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'z_choice.dart';

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

ZChoice _$ZChoiceFromMap(Map<String, dynamic> map) => ZChoice(
  content: map['content'] is String ? map['content'] as String : '',
  isCorrect: map['is_correct'] is bool ? map['is_correct'] as bool : false,
);

extension ZChoiceZcrud on ZChoice {
  /// Sérialise vers la map persistée (snake_case, enum camelCase, ISO-8601).
  Map<String, dynamic> toMap() => <String, dynamic>{
    'content': this.content,
    'is_correct': this.isCorrect,
  };

  /// Copie avec sentinelle : un argument omis préserve la valeur, `null` explicite la remet à `null`.
  ZChoice copyWith({
    Object? content = _$undefined,
    Object? isCorrect = _$undefined,
  }) => ZChoice(
    content: identical(content, _$undefined) ? this.content : content as String,
    isCorrect: identical(isCorrect, _$undefined)
        ? this.isCorrect
        : isCorrect as bool,
  );
}

/// Schéma déclaratif projeté depuis @ZcrudField (E2-5).
const List<ZFieldSpec> $ZChoiceFieldSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'content', type: EditionFieldType.text, label: 'Choix'),
  ZFieldSpec(name: 'is_correct', type: EditionFieldType.boolean),
];

/// Enregistre `ZChoice` (kind "flashcard_choice") sur [registry] : (dé)sérialisation + schéma.
void registerZChoice(ZcrudRegistry registry) => registry.register<ZChoice>(
  'flashcard_choice',
  fromMap: _$ZChoiceFromMap,
  toMap: (value) => value.toMap(),
  fieldSpecs: $ZChoiceFieldSpecs,
);
