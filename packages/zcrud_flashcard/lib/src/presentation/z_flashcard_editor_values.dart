/// Coercitions **défensives** (AD-10) des valeurs de tranche flashcard —
/// partagées par les widgets d'édition et le validateur (Story E9-5).
///
/// La tranche d'un champ flashcard peut porter la valeur **typée** (produite par
/// nos widgets : `ZFlashcardType`, `List<ZChoice>`, `bool`) **ou** une forme
/// **persistée/corrompue** (String, `List<Map>`, `null`) au premier montage
/// (reseed depuis une map). Ces helpers **ne jettent jamais** : une valeur
/// illisible retombe sur un défaut sûr (type → `openQuestion`, choix → `[]`,
/// vrai/faux → `null`).
library;

import '../domain/z_choice.dart';
import '../domain/z_flashcard_type.dart';

/// Coerce défensivement une valeur de tranche en [ZFlashcardType].
///
/// - déjà un [ZFlashcardType] → tel quel ;
/// - `String` (nom camelCase persisté) → valeur correspondante, sinon
///   [ZFlashcardType.openQuestion] (repli défensif AC1) ;
/// - tout le reste (`null`, type inattendu) → [ZFlashcardType.openQuestion].
ZFlashcardType coerceFlashcardType(Object? value) {
  if (value is ZFlashcardType) return value;
  if (value is String) {
    for (final t in ZFlashcardType.values) {
      if (t.name == value) return t;
    }
  }
  return ZFlashcardType.openQuestion;
}

/// Coerce défensivement une valeur de tranche en `List<ZChoice>` (jamais `null`).
///
/// - `List<ZChoice>` → copie mutable ;
/// - `List` hétérogène → chaque élément décodé (ZChoice tel quel, `Map` via
///   `ZChoice.fromMap`, sinon ignoré) ;
/// - tout le reste → `[]`.
List<ZChoice> coerceChoices(Object? value) {
  if (value is List<ZChoice>) return List<ZChoice>.of(value);
  if (value is List) {
    return <ZChoice>[
      for (final e in value)
        if (e is ZChoice)
          e
        else if (e is Map)
          ZChoice.fromMap(<String, dynamic>{
            for (final entry in e.entries) '${entry.key}': entry.value,
          }),
    ];
  }
  return <ZChoice>[];
}

/// Coerce défensivement une valeur de tranche en `bool?` (vrai/faux).
///
/// - déjà `bool` → tel quel ;
/// - `String` `'true'`/`'false'` (insensible) → booléen correspondant ;
/// - tout le reste → `null` (aucune sélection).
bool? coerceTrueFalse(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final v = value.trim().toLowerCase();
    if (v == 'true') return true;
    if (v == 'false') return false;
  }
  return null;
}
