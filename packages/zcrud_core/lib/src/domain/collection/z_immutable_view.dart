/// Vues **non modifiables** des canaux `Map`/`List` (DW-ES24-1, ES-3.0, AD-10).
///
/// origine: ES-3.0 (Phase B) — **patron `extra` d'ES-2.2b** (`zNormalizeExtra`)
/// appliqué à l'IMMUABILITÉ : *« le champ STOCKÉ reste BRUT (le ctor `const`
/// l'exige) ; c'est la LECTURE — l'ACCESSEUR — qui est normalisée »*. C'est le
/// **seul point que TOUTES les voies traversent** (fromMap/copyWith **ET** le
/// constructeur `const` invoqué non-`const` avec une réf mutable retenue), **sans
/// perdre `const`** et **sans `assert`** (AD-10 : le décodeur généré appelle le
/// ctor avec des valeurs BRUTES).
///
/// ## Le trou fermé (MESURÉ, DW-ES24-1)
///
/// ```dart
/// final mut = <int, int>{1: 2};
/// final i = ZDocumentLearningInfo(qualityByPage: mut); // ctor const, non-const
/// i.qualityByPage[0] = 99; // ⛔ NE THROW PAS — la réf mutable était retenue
/// ```
///
/// Posées sur l'ACCESSEUR, ces vues rendent la mutation en place **impossible
/// INCONDITIONNELLEMENT** (`UnsupportedError`), y compris sur la voie `const`.
///
/// ## Zéro-copie sur le chemin chaud (AC14)
///
/// Chaque fonction est **IDEMPOTENTE** : si la collection est **déjà** une vue
/// profondément non modifiable (cas des voies `fromMap`/`copyWith`, qui
/// normalisent EAGER en stockant le résultat de ces mêmes fonctions), elle est
/// rendue **TELLE QUELLE** (`identical`) — aucune re-copie. Seule la voie `const`
/// polluée paie une enveloppe (lazy, O(n) une fois par lecture).
///
/// AD-1 : pur `dart:collection`, aucun type hors `zcrud_core` — CORE OUT=0.
library;

import 'dart:collection';

/// Vue non modifiable **PEU PROFONDE** d'une [map] à valeurs **scalaires** (aucune
/// collection imbriquée : `Map<int,int>`, `Map<String,int>`…). Idempotente +
/// zéro-copie (rend [map] si c'est déjà une [UnmodifiableMapView]).
Map<K, V> zUnmodifiableScalarMap<K, V>(Map<K, V> map) =>
    map is UnmodifiableMapView<K, V> ? map : UnmodifiableMapView<K, V>(map);

/// Vue non modifiable **PEU PROFONDE** d'une [list] à éléments **scalaires**.
List<E> zUnmodifiableScalarList<E>(List<E> list) =>
    list is UnmodifiableListView<E> ? list : UnmodifiableListView<E>(list);

/// Vue non modifiable **PROFONDE** d'une map dont les valeurs sont des LISTES
/// (`Map<K, List<E>>`, ex. `ZFolderContentsOrder.sectionOrders`) : la map **ET**
/// chaque liste interne. Idempotente + zéro-copie.
Map<K, List<E>> zUnmodifiableMapOfLists<K, E>(Map<K, List<E>> map) {
  if (map is UnmodifiableMapView<K, List<E>> &&
      map.values.every((v) => v is UnmodifiableListView<E>)) {
    return map;
  }
  return UnmodifiableMapView<K, List<E>>(<K, List<E>>{
    for (final e in map.entries)
      e.key: e.value is UnmodifiableListView<E>
          ? e.value
          : UnmodifiableListView<E>(e.value),
  });
}

/// Vue non modifiable **PROFONDE** d'ops Delta neutres
/// (`List<Map<String, dynamic>>`, ex. `ZSmartNote.content`) : la liste, **chaque
/// op**, **et** les valeurs imbriquées (attributs / embeds opaques). Idempotente +
/// zéro-copie (rend [list] si chaque op est déjà une [UnmodifiableMapView]).
List<Map<String, dynamic>> zUnmodifiableJsonMapList(
  List<Map<String, dynamic>> list,
) {
  if (list is UnmodifiableListView<Map<String, dynamic>> &&
      list.every((m) => m is UnmodifiableMapView)) {
    return list;
  }
  return UnmodifiableListView<Map<String, dynamic>>(<Map<String, dynamic>>[
    for (final m in list) _deepJsonMap(m),
  ]);
}

/// Enveloppe **profonde** d'une `Map<String, dynamic>` (op Delta) : la map ET ses
/// valeurs `Map`/`List` imbriquées.
Map<String, dynamic> _deepJsonMap(Map<String, dynamic> m) =>
    UnmodifiableMapView<String, dynamic>(<String, dynamic>{
      for (final e in m.entries) e.key: _deepJson(e.value),
    });

/// Enveloppe **profonde** d'une valeur JSON quelconque (récursive sur `Map`/`List`).
Object? _deepJson(Object? v) {
  if (v is Map) {
    return UnmodifiableMapView<Object?, Object?>(<Object?, Object?>{
      for (final e in v.entries) e.key: _deepJson(e.value),
    });
  }
  if (v is List) {
    return UnmodifiableListView<Object?>(<Object?>[
      for (final e in v) _deepJson(e),
    ]);
  }
  return v;
}
