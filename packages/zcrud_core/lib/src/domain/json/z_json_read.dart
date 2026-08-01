/// 🔴 **LECTURE JSON DÉFENSIVE PARTAGÉE** du domaine `zcrud_core` (AD-10).
///
/// ## Pourquoi cette surface existe (décision owner, CHAT-0)
///
/// Chaque entité **écrite à la main** (hors codegen) du dépôt reconstruit les
/// **mêmes** micro-helpers de lecture tolérante — `_coerceStringMap`,
/// `_asString`, `_asIntOrNull`, `_guard` — copiés d'un fichier à l'autre
/// (`ZFlashcardSource`, `AppFile`, `ZMindmap`, le modèle de chat…). C'est
/// exactement la classe de duplication qui a produit **DW-ES22-4** : six
/// `_mapEquals` jumeaux dans trois packages, dont **aucun** n'était profond, et
/// que rien n'obligeait à rester cohérents.
///
/// ⇒ Ces primitives sont ici **UNE SEULE FOIS**, publiques, et destinées à
/// **tous** les modules — présents et futurs. Le pendant existe déjà pour
/// l'égalité (`zJsonEquals`/`zJsonHash`, `z_json_equality.dart`) : c'est la même
/// discipline appliquée à la **lecture**.
///
/// ## Le contrat, en une phrase
///
/// **Aucune fonction de ce fichier ne lève, quelle que soit la valeur reçue.**
/// Un champ absent, mal typé, tronqué ou venu d'un schéma futur retombe sur un
/// défaut nommé — jamais sur une exception qui emporterait le parent (AD-10 :
/// « un champ absent/corrompu ne fait JAMAIS échouer le parent »).
///
/// Pur-Dart, zéro dépendance (AD-1/AD-14).
library;

/// Coerce défensive vers `Map<String, dynamic>` — repli `null`, jamais de throw.
///
/// Tolère les `Map<dynamic, dynamic>` (forme rendue par les stores clé-valeur
/// et par certains décodeurs) en re-clefant sur `'${e.key}'`.
Map<String, dynamic>? zJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    try {
      return <String, dynamic>{
        for (final MapEntry<Object?, Object?> e in value.entries)
          '${e.key}': e.value,
      };
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Lecture défensive d'une `String` (repli [fallback], défaut `''`).
String zJsonString(Object? value, [String fallback = '']) =>
    value is String ? value : fallback;

/// Lecture défensive d'une `String?` : rend `null` si absente **ou vide**.
///
/// La vacuité est traitée comme une **absence** : une chaîne vide persistée ne
/// doit pas ressusciter en « champ présent mais vide », sans quoi le round-trip
/// n'est plus idempotent (`'' → null → clé omise → ''`).
String? zJsonStringOrNull(Object? value) {
  if (value is String && value.isNotEmpty) return value;
  return null;
}

/// Lecture défensive d'un `int?` (tolère `num` et `String`), repli `null`.
int? zJsonIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Lecture défensive d'un `int` avec repli [fallback].
int zJsonInt(Object? value, int fallback) => zJsonIntOrNull(value) ?? fallback;

/// Lecture défensive d'un `double?` (tolère `num` et `String`), repli `null`.
///
/// ⚠️ Un score **absent** ne doit **jamais** être coercé en `0.0` par l'appelant :
/// « non évalué » et « évalué à zéro » sont deux faits distincts, et les
/// confondre fait mentir toute règle métier qui s'appuie dessus.
double? zJsonDoubleOrNull(Object? value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Lecture défensive d'un `double` avec repli [fallback].
double zJsonDouble(Object? value, double fallback) =>
    zJsonDoubleOrNull(value) ?? fallback;

/// Lecture défensive d'un `bool?` (tolère `num` et `'true'`/`'false'`).
///
/// Les backends sérialisent le même drapeau tantôt en `bool`, tantôt en `1`/`0`,
/// tantôt en chaîne : les trois formes sont acceptées, tout le reste ⇒ `null`.
bool? zJsonBoolOrNull(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final String lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  return null;
}

/// Lecture défensive d'un `bool` avec repli [fallback].
bool zJsonBool(Object? value, bool fallback) =>
    zJsonBoolOrNull(value) ?? fallback;

/// Lecture défensive d'une date **ISO-8601** — repli `null`.
///
/// 🔴 `DateTime.**tryParse**`, jamais `DateTime.parse` : une entité qui fait
/// `DateTime.parse(json['created_at'] as String)` **lève** sur une date absente
/// ou corrompue et **détruit tout le parent** — violation frontale d'AD-10.
DateTime? zJsonDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value);
}

/// Lecture défensive d'une `List<String>` — repli `null` si [value] n'est pas
/// une liste ; les éléments non-`String` sont **ignorés** (la liste survit).
List<String>? zJsonStringList(Object? value) {
  if (value is! List) return null;
  return <String>[
    for (final Object? e in value)
      if (e is String) e,
  ];
}

/// Exécute [parse] et rend son résultat, ou `null` sur **toute** exception.
///
/// Jumeau de `ZExtension.guard` pour le code décodé qui n'est **pas** une
/// extension (codec d'app injecté par `ZTypeRegistry`/`ZSourceRegistry`,
/// désérialisation d'un sous-objet…).
T? zJsonGuard<T>(T Function() parse) {
  try {
    return parse();
  } catch (_) {
    return null;
  }
}

/// 🔴 Décode une **liste** en ignorant les éléments illisibles — **la liste
/// n'est jamais perdue** (AD-10).
///
/// - [raw] n'est pas une `List` ⇒ `null` (« champ absent », distinct de « liste
///   vide », qui reste `[]`) ;
/// - un élément dont [decode] rend `null` est **sauté** : il n'annule pas les
///   autres ;
/// - un [decode] qui **lève** est absorbé (l'élément est sauté).
///
/// ⚠️ C'est exactement ce que `raw.map((e) => T.fromJson(e as Map…)).toList()`
/// **ne fait pas** : un seul élément au mauvais type y lève un `TypeError` qui
/// emporte le parent entier.
List<T>? zJsonDecodeList<T extends Object>(
  Object? raw,
  T? Function(Object? element) decode,
) {
  if (raw is! List) return null;
  final List<T> out = <T>[];
  for (final Object? element in raw) {
    final T? decoded = zJsonGuard<T?>(() => decode(element));
    if (decoded != null) out.add(decoded);
  }
  return out;
}

/// Égalité **élément par élément** de deux listes.
///
/// L'`==` d'une `List` est une égalité d'**IDENTITÉ** en Dart : une entité qui
/// compare ses listes avec `==` est dite différente d'elle-même relue du store.
/// C'est le pendant, pour les listes de **valeurs typées**, de ce que
/// `zJsonEquals` fait pour le JSON **arbitraire** (slot `extra`, payloads).
bool zListEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Hachage cohérent avec [zListEquals] (`null` ⇒ `0`).
int zListHash<T>(List<T>? list) => list == null ? 0 : Object.hashAll(list);
