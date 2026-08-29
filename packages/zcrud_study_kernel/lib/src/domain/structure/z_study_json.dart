/// Utilitaires de (dé)sérialisation et d'égalité partagés par les types de
/// structure d'étude.
///
/// Tous respectent le décodage défensif (invariant AD-10) : une entrée d'un
/// type inattendu produit une valeur de repli, jamais une levée.
library;

/// Égalité élément par élément de deux listes de chaînes (ordre significatif).
bool zStringListEquals(List<String> a, List<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Égalité élément par élément de deux listes quelconques (ordre
/// significatif), déléguant à l'`==` des éléments.
bool zStudyListEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Égalité de deux ensembles de chaînes (ordre non significatif).
bool zStringSetEquals(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// Hachage stable d'un ensemble de chaînes (indépendant de l'ordre
/// d'itération).
int zStringSetHash(Set<String> values) {
  final sorted = values.toList(growable: false)..sort();
  return Object.hashAll(sorted);
}

/// Décode une liste d'objets depuis une valeur persistée quelconque.
///
/// Repli `const []` si [raw] n'est pas une liste. Les éléments qui ne sont pas
/// une map de chaînes sont **ignorés** ; un élément dont le décodeur lève est
/// ignoré lui aussi — le parent survit toujours (invariant AD-10).
List<T> zStudyDecodeList<T>(
  Object? raw,
  T Function(Map<String, dynamic> map) decode,
) {
  if (raw is! List) return const <Never>[];
  final out = <T>[];
  for (final item in raw) {
    final map = zStudyAsJsonMap(item);
    if (map == null) continue;
    try {
      out.add(decode(map));
    } on Object {
      // Un élément indécodable ne fait jamais échouer la liste ni son parent.
      continue;
    }
  }
  return List<T>.unmodifiable(out);
}

/// Décode une map d'objets `Map` en `Map<String, dynamic>`, ou `null`.
///
/// Accepte toute `Map` dont les clés sont des chaînes (les stores rendent
/// souvent `Map<Object?, Object?>`).
Map<String, dynamic>? zStudyAsJsonMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    final out = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) return null;
      out[key] = entry.value;
    }
    return out;
  }
  return null;
}

/// Encode une liste d'objets en liste de maps persistées.
List<Map<String, dynamic>> zStudyEncodeList<T>(
  List<T> items,
  Map<String, dynamic> Function(T item) encode,
) => <Map<String, dynamic>>[for (final item in items) encode(item)];

/// Décode un ensemble de chaînes (repli `const {}`), en préservant l'ordre
/// d'apparition pour la stabilité du round-trip.
Set<String> zStudyDecodeStringSet(Object? raw) {
  if (raw is! List) return const <String>{};
  final out = <String>{};
  for (final item in raw) {
    if (item is String) out.add(item);
  }
  return Set<String>.unmodifiable(out);
}

/// Retire de [map] toutes les entrées de valeur `null` (règle d'émission :
/// une valeur absente n'écrit aucune clé).
Map<String, dynamic> zStudyPrune(Map<String, dynamic> map) =>
    map..removeWhere((String key, Object? value) => value == null);
