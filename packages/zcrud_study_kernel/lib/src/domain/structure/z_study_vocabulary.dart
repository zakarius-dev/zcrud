/// `ZStudyVocabulary` — liste de valeurs nommées, déclarée **en données**.
///
/// Un vocabulaire remplace ce qu'une énumération fermée aurait figé : le
/// niveau, l'orientation, le format, le cycle sont des vocabulaires, pas des
/// types. L'application les déclare ; le noyau ne connaît ni leurs clés ni
/// leurs valeurs, et n'en teste jamais une.
///
/// [ZStudyVocabularyValue.parentValue] autorise une **hiérarchie de valeurs**
/// à profondeur libre (une valeur large et ses raffinements). Le noyau ne
/// vérifie pas que le parent existe et ne détecte pas les cycles à ce niveau :
/// c'est une donnée de présentation, pas un invariant.
///
/// L'affectation d'une valeur à une cible est portée par
/// `ZStudyClassification`, historisable — le vocabulaire lui-même ne référence
/// jamais de cible.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Valeur d'un vocabulaire.
class ZStudyVocabularyValue {
  /// Construit une valeur de vocabulaire.
  const ZStudyVocabularyValue({
    required this.value,
    this.label,
    this.order,
    this.parentValue,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyVocabularyValue.fromMap(Map<String, dynamic> map) =>
      ZStudyVocabularyValue(
        value: zJsonString(map['value']),
        label: zJsonStringOrNull(map['label']),
        order: zJsonIntOrNull(map['order']),
        parentValue: zJsonStringOrNull(map['parent_value']),
      );

  /// Clé de la valeur — chaîne opaque, défaut `''`.
  final String value;

  /// Libellé affichable, `null` si absent. Destiné à être remplacé par la
  /// localisation de l'application : le noyau ne traduit rien.
  final String? label;

  /// Rang d'affichage, `null` si non ordonnée.
  final int? order;

  /// Valeur parente dans la hiérarchie du vocabulaire, `null` = racine.
  final String? parentValue;

  /// Sérialise vers la map persistée ; aucune valeur absente n'écrit de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'value': value,
    if (label != null) 'label': label,
    if (order != null) 'order': order,
    if (parentValue != null) 'parent_value': parentValue,
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyVocabularyValue copyWith({
    Object? value = _undefined,
    Object? label = _undefined,
    Object? order = _undefined,
    Object? parentValue = _undefined,
  }) => ZStudyVocabularyValue(
    value: identical(value, _undefined) ? this.value : value as String,
    label: identical(label, _undefined) ? this.label : label as String?,
    order: identical(order, _undefined) ? this.order : order as int?,
    parentValue: identical(parentValue, _undefined)
        ? this.parentValue
        : parentValue as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyVocabularyValue &&
          value == other.value &&
          label == other.label &&
          order == other.order &&
          parentValue == other.parentValue;

  @override
  int get hashCode => Object.hash(value, label, order, parentValue);
}

/// Vocabulaire immuable : une clé et ses valeurs.
class ZStudyVocabulary {
  /// Construit un vocabulaire.
  const ZStudyVocabulary({
    required this.key,
    this.label,
    this.values = const <ZStudyVocabularyValue>[],
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyVocabulary.fromMap(Map<String, dynamic> map) =>
      ZStudyVocabulary(
        key: zJsonString(map['key']),
        label: zJsonStringOrNull(map['label']),
        values: zStudyDecodeList<ZStudyVocabularyValue>(
          map['values'],
          ZStudyVocabularyValue.fromMap,
        ),
      );

  /// Clé du vocabulaire — chaîne opaque, défaut `''`.
  final String key;

  /// Libellé affichable, `null` si absent.
  final String? label;

  /// Valeurs déclarées, dans l'ordre de déclaration, défaut `const []`.
  ///
  /// Un vocabulaire sans valeur est valide : il décrit alors un axe ouvert
  /// dont les valeurs sont saisies librement.
  final List<ZStudyVocabularyValue> values;

  /// Valeurs triées par [ZStudyVocabularyValue.order] croissant, les valeurs
  /// non ordonnées à la fin dans leur ordre de déclaration (tri stable).
  List<ZStudyVocabularyValue> get orderedValues {
    final ordered = <ZStudyVocabularyValue>[];
    final unordered = <ZStudyVocabularyValue>[];
    for (final value in values) {
      (value.order == null ? unordered : ordered).add(value);
    }
    ordered.sort(
      (ZStudyVocabularyValue a, ZStudyVocabularyValue b) =>
          a.order!.compareTo(b.order!),
    );
    return List<ZStudyVocabularyValue>.unmodifiable(<ZStudyVocabularyValue>[
      ...ordered,
      ...unordered,
    ]);
  }

  /// Valeur de clé [value], ou `null` si le vocabulaire ne la déclare pas.
  ///
  /// Rendre `null` ne rend pas la valeur invalide : une classification portant
  /// une valeur non déclarée reste valide et round-trippe intacte.
  ZStudyVocabularyValue? valueOf(String value) {
    for (final candidate in values) {
      if (candidate.value == value) return candidate;
    }
    return null;
  }

  /// Sérialise vers la map persistée ; aucune valeur absente n'écrit de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'key': key,
    if (label != null) 'label': label,
    if (values.isNotEmpty)
      'values': zStudyEncodeList(
        values,
        (ZStudyVocabularyValue value) => value.toMap(),
      ),
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyVocabulary copyWith({
    Object? key = _undefined,
    Object? label = _undefined,
    Object? values = _undefined,
  }) => ZStudyVocabulary(
    key: identical(key, _undefined) ? this.key : key as String,
    label: identical(label, _undefined) ? this.label : label as String?,
    values: identical(values, _undefined)
        ? this.values
        : values as List<ZStudyVocabularyValue>,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyVocabulary &&
          key == other.key &&
          label == other.label &&
          zStudyListEquals(values, other.values);

  @override
  int get hashCode => Object.hash(key, label, Object.hashAll(values));
}
