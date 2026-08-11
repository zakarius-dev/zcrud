/// `normalizeTagTitle` + `dedupeByNormalizedTitle` — normalisation de titre
/// de tag et dédoublonnage associé.
///
/// Fonctions **pures**, **totales** et **locale-indépendantes**, réutilisables
/// par tout satellite d'étude pour comparer des titres de tag saisis avec des
/// variations d'espacement/casse (`"Droit Douanier"` vs `"  droit   douanier "`).
library;

/// Normalise [raw] pour comparaison : `trim()` + collapse de toute séquence
/// d'espaces (`\s+`, y compris NBSP/espaces Unicode couverts par `\s` en Dart)
/// vers un espace unique + `toLowerCase()`.
///
/// Pure, totale, locale-indépendante : `null`/`''`/`'   '` → `''`, jamais de
/// `throw` (invariant AD-10).
String normalizeTagTitle(String? raw) =>
    (raw ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// Dédoublonne [items] par titre normalisé ([normalizeTagTitle]) : conserve
/// la première occurrence de chaque titre normalisé, dans l'ordre d'entrée
/// (tri stable implicite — un seul passage, jamais de réordonnancement).
///
/// Ne mute pas [items] ; retourne une nouvelle `List<T>`.
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
