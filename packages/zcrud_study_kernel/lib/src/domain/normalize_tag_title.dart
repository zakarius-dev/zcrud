/// `normalizeTagTitle` + `dedupeByNormalizedTitle<T>` — normalisation de titre
/// de tag et dédoublonnage associé (ES-1.2, FR-S2/FR-S6, AC5).
///
/// Fonctions **pures**, **totales** et **locale-indépendantes** — usage prévu :
/// `ZFlashcardTag`/`ZSuggestedTag` (ES-2.3/ES-8.1), pour comparer des titres de
/// tag saisis avec des variations d'espacement/casse (`"Droit Douanier"` vs
/// `"  droit   douanier "`).
library;

/// Normalise [raw] pour comparaison : `trim()` + collapse de toute séquence
/// d'espaces (`\s+`, y compris NBSP/espaces Unicode couverts par `\s` en Dart)
/// vers un espace unique + `toLowerCase()`.
///
/// **Pure, totale, locale-indépendante** : `null`/`''`/`'   '` → `''`, jamais
/// de throw (AD-10).
String normalizeTagTitle(String? raw) =>
    (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Dédoublonne [items] par **titre normalisé** ([normalizeTagTitle]) :
/// conserve la **1re** occurrence de chaque titre normalisé, dans l'ordre
/// d'entrée (tri **stable** implicite — un seul passage, jamais de
/// réordonnancement).
///
/// Ne mute pas [items] ; retourne une **nouvelle** `List<T>`.
List<T> dedupeByNormalizedTitle<T>(
  Iterable<T> items, {
  required String? Function(T item) titleOf,
}) {
  final seenTitles = <String>{};
  final result = <T>[];
  for (final item in items) {
    final normalized = normalizeTagTitle(titleOf(item));
    if (seenTitles.add(normalized)) {
      result.add(item);
    }
  }
  return result;
}
