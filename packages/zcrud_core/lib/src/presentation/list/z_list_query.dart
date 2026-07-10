/// Moteur de requête de liste **neutre et in-memory** du cœur `zcrud_core`.
///
/// origine: E4-3 (recherche/filtre/tri/pagination, FR-6..FR-8 · AD-8/AD-10/
/// AD-16). **Productionise** le repli in-memory déjà PROUVÉ en E2-2 (fake
/// `_InMemoryZRepository._applyRequest`/`_compareToAnchor`, remédiation M2/M3) en
/// un moteur **public, réutilisable et testé**, opérant sur des `ZListRow.cells`
/// (surface neutre) plutôt que sur des entités `T`.
///
/// **Neutre (SM-5)** : aucun `package:syncfusion`, aucun type backend, aucun
/// gestionnaire d'état. Seuls `package:flutter/foundation.dart` (`@immutable`) et
/// des types `zcrud_core` sont importés — cohérent avec la garde de pureté
/// `presentation/`.
library;

import 'package:flutter/foundation.dart';

import '../../domain/data/z_cursor.dart';
import '../../domain/data/z_data_request.dart';
import '../../domain/data/z_search_text.dart';
import '../../domain/edition/z_field_spec.dart';
import 'z_list_render_request.dart';

/// Résultat **neutre** d'une passe de pagination : les [rows] de la page, le
/// [nextCursor] dérivé (ou `null` s'il n'y a plus de page) et [hasMore].
///
/// [nextCursor] est **non-null ssi** il reste des lignes au-delà de la page
/// courante (invariant : `hasMore == (nextCursor != null)`). Immuable ; égalité
/// de **valeur profonde** (helpers pur-Dart, aucun `package:collection`, AD-1).
@immutable
class ZListPage {
  /// Construit une page. [hasMore] doit rester cohérent avec [nextCursor].
  const ZListPage({
    required this.rows,
    this.nextCursor,
    this.hasMore = false,
  });

  /// Lignes de la page (déjà filtrées/recherchées/triées/tronquées).
  final List<ZListRow> rows;

  /// Curseur d'ancrage de la page suivante, ou `null` s'il n'y en a plus.
  final ZCursor? nextCursor;

  /// `true` s'il reste au moins une page après celle-ci.
  final bool hasMore;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListPage &&
          runtimeType == other.runtimeType &&
          hasMore == other.hasMore &&
          nextCursor == other.nextCursor &&
          _listEquals(rows, other.rows);

  @override
  int get hashCode =>
      Object.hash(runtimeType, Object.hashAll(rows), nextCursor, hasMore);

  @override
  String toString() =>
      'ZListPage(rows: ${rows.length}, hasMore: $hasMore, '
      'nextCursor: $nextCursor)';
}

/// Prédicat de **recherche sans accents** sur les champs `searchable` du schéma.
///
/// (a) [term] vide/blanc → **match tous** (`true`) ; (b) sinon, replie le terme
/// ([zFoldDiacritics]) et teste `contains` sur le texte replié de **chaque**
/// champ `searchable == true` du [schema]. La valeur brute `row.cells[name]` est
/// coercée en `String` de façon neutre (`null → ''`, `Iterable →` éléments
/// joints). Un champ **non** `searchable` n'est **jamais** interrogé.
bool zMatchesSearch(
  ZListRow row,
  String term, {
  required List<ZFieldSpec> schema,
}) {
  final folded = zFoldDiacritics(term.trim());
  if (folded.isEmpty) return true;
  for (final field in schema) {
    if (!field.searchable) continue;
    final text = zFoldDiacritics(_coerceText(row.cells[field.name]));
    if (text.contains(folded)) return true;
  }
  return false;
}

/// Applique un [request] **entièrement en mémoire** à [rows] et retourne une
/// [ZListPage] (filtre → recherche → tri → saut curseur → `take(limit)` →
/// dérivation `nextCursor`/`hasMore`).
///
/// C'est la **productionisation** du repli in-memory E2-2 : la sémantique du
/// curseur (comparaison positionnelle par `ZCursor.values` alignées sur
/// `request.sorts`, `id` en départage, `id: null` légitime, ancre introuvable
/// gérée **gracieusement** — page vide au-delà de la fin, sans exception) est
/// STRICTEMENT alignée sur le fake déjà validé (M2/M3). Aucune comparaison ne
/// lève (AD-10) : un type non comparable retombe sur « ne matche pas » (filtre)
/// ou « égal » (tri, stable).
ZListPage zApplyListRequest(
  List<ZListRow> rows,
  ZDataRequest request, {
  required List<ZFieldSpec> schema,
}) {
  // (1) Filtres (conjonction) sur les cellules brutes.
  var result = rows;
  for (final filter in request.filters) {
    result = <ZListRow>[
      for (final row in result)
        if (_matchesFilter(row, filter)) row,
    ];
  }
  // (2) Recherche sans accents sur les champs `searchable`.
  final search = request.search;
  if (search != null && zFoldDiacritics(search.trim()).isNotEmpty) {
    result = <ZListRow>[
      for (final row in result)
        if (zMatchesSearch(row, search, schema: schema)) row,
    ];
  }
  // (3) Tri multi-clés STABLE (direction respectée ; `null` ordonné en dernier
  // dans le sens ascendant).
  result = _sortRows(result, request.sorts);
  // (4) Saut curseur : ignore les lignes situées AVANT l'ancre dans l'ordre
  // courant (repli E2-2). Ancre introuvable → simple position d'ordre, jamais
  // d'exception.
  final cursor = request.startAfter;
  if (cursor != null) {
    result = _skipCursor(result, cursor, request.sorts);
  }
  // (5)+(6) Troncature + dérivation du nextCursor : non-null SSI il reste des
  // lignes après la page prise.
  final limit = request.limit;
  if (limit != null && result.length > limit) {
    final page = result.sublist(0, limit);
    return ZListPage(
      rows: page,
      nextCursor: zDeriveCursor(page.last, request.sorts),
      hasMore: true,
    );
  }
  return ZListPage(rows: result, nextCursor: null, hasMore: false);
}

/// Dérive le **curseur d'ancrage** d'une [row] pour les clés de tri [sorts] :
/// `values` = valeurs des clés de tri de la ligne (alignées positionnellement
/// sur [sorts]), `id` = identité opaque de la ligne. Boucle fermée avec
/// `ZDataRequest.startAfter` (E2-2), sans jamais construire de type backend.
ZCursor zDeriveCursor(ZListRow row, List<ZSort> sorts) => ZCursor(
      values: <Object?>[for (final sort in sorts) row.cells[sort.field]],
      id: row.id,
    );

/// Coercition **neutre** d'une valeur opaque en texte (recherche) : `null → ''`,
/// `Iterable →` éléments coercés puis joints (espace), sinon `toString()`.
String _coerceText(Object? value) {
  if (value == null) return '';
  if (value is Iterable) return value.map(_coerceText).join(' ');
  return value.toString();
}

/// Évalue un [filter] sur `row.cells[filter.field]` pour chaque [ZFilterOp].
/// **Défensif** (AD-10) : une comparaison sur des types non comparables ne lève
/// jamais — elle retombe sur `false` (« ne matche pas »).
bool _matchesFilter(ZListRow row, ZFilter filter) {
  final value = row.cells[filter.field];
  switch (filter.op) {
    case ZFilterOp.eq:
      return value == filter.value;
    case ZFilterOp.neq:
      return value != filter.value;
    case ZFilterOp.lt:
      final c = _tryCompare(value, filter.value);
      return c != null && c < 0;
    case ZFilterOp.lte:
      final c = _tryCompare(value, filter.value);
      return c != null && c <= 0;
    case ZFilterOp.gt:
      final c = _tryCompare(value, filter.value);
      return c != null && c > 0;
    case ZFilterOp.gte:
      final c = _tryCompare(value, filter.value);
      return c != null && c >= 0;
    case ZFilterOp.contains:
      if (value is Iterable) return value.contains(filter.value);
      final needle = zFoldDiacritics(_coerceText(filter.value));
      // L-4 : opérande de sous-chaîne `null`/vide → filtre INDÉFINI, ne matche
      // RIEN (défensif AD-10). Sans cette garde, `_coerceText(null) == ''` et
      // `text.contains('')` serait toujours vrai → un `contains` à opérande nul
      // (erreur d'appel probable) matcherait TOUTES les lignes par accident.
      if (needle.isEmpty) return false;
      return zFoldDiacritics(_coerceText(value)).contains(needle);
    case ZFilterOp.isIn:
      return filter.value is List && (filter.value! as List).contains(value);
    case ZFilterOp.isNull:
      return value == null;
  }
}

/// Compare deux valeurs opaques de façon **défensive** : renvoie `null` si elles
/// ne sont pas comparables (types disjoints, non `Comparable`) — jamais
/// d'exception (AD-10). Les `num` sont comparés entre eux (int ↔ double).
int? _tryCompare(Object? a, Object? b) {
  if (a == null || b == null) return null;
  if (a is num && b is num) return a.compareTo(b);
  if (a is Comparable && a.runtimeType == b.runtimeType) {
    return a.compareTo(b);
  }
  return null;
}

/// Tri **stable** multi-clés : applique [sorts] dans l'ordre (départage par la
/// clé suivante), respecte `ZSortDirection`, et préserve l'ordre d'entrée pour
/// les lignes égales (décoration par index d'origine → tie-break final). `null`
/// est traité comme la **plus grande** valeur (dernier en ascendant ; la
/// négation `desc` le place donc en tête — comportement documenté et stable).
List<ZListRow> _sortRows(List<ZListRow> rows, List<ZSort> sorts) {
  if (sorts.isEmpty) return rows;
  final indexed = <MapEntry<int, ZListRow>>[
    for (var i = 0; i < rows.length; i++) MapEntry<int, ZListRow>(i, rows[i]),
  ];
  indexed.sort((a, b) {
    for (final sort in sorts) {
      var c = _compareForSort(
        a.value.cells[sort.field],
        b.value.cells[sort.field],
      );
      if (sort.direction == ZSortDirection.desc) c = -c;
      if (c != 0) return c;
    }
    return a.key.compareTo(b.key); // stabilité : ordre d'entrée préservé
  });
  return <ZListRow>[for (final entry in indexed) entry.value];
}

/// Comparaison d'ordre **totale** (jamais d'exception) : `null` en dernier
/// (ascendant), non-comparables traités comme égaux (stabilité préservée).
int _compareForSort(Object? a, Object? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // null en dernier (ascendant)
  if (b == null) return -1;
  return _tryCompare(a, b) ?? 0;
}

/// Saute au-delà de l'ancre [cursor] dans l'ordre courant. Sans clé de tri, seul
/// [ZCursor.id] peut ancrer (repli dégénéré : page 1 si l'ancre est
/// introuvable). Sinon, conserve les lignes **strictement après** l'ancre
/// (comparaison par `values`).
List<ZListRow> _skipCursor(
  List<ZListRow> rows,
  ZCursor cursor,
  List<ZSort> sorts,
) {
  if (sorts.isEmpty) {
    final anchor = rows.indexWhere((row) => row.id == cursor.id);
    return anchor >= 0 ? rows.sublist(anchor + 1) : rows;
  }
  return <ZListRow>[
    for (final row in rows)
      if (_compareToAnchor(row, cursor, sorts) > 0) row,
  ];
}

/// Compare [row] à l'ancre du [cursor] selon l'ordre [sorts] (départage `id`).
/// `> 0` si [row] est **strictement après** l'ancre (conservé), `< 0` si avant,
/// `0` si [row] EST l'ancre. Aligné sur `_compareToAnchor` du fake E2-2.
///
/// L-3 (consigné) : le départage par `id` sur clés de tri égales n'est cohérent
/// au **raccord** `backendCursor → repli in-memory` que si un backend réel
/// ordonne AUSSI les ex æquo par `id`. Le contrat `ZCursor` l'impose (dernier
/// `orderBy(id)`) : **à garantir côté adaptateur Firestore (E5)**. Ici (moteur
/// neutre + fake E2-2) le tie-break `id` est déjà déterministe.
int _compareToAnchor(ZListRow row, ZCursor cursor, List<ZSort> sorts) {
  final n =
      sorts.length < cursor.values.length ? sorts.length : cursor.values.length;
  for (var i = 0; i < n; i++) {
    final sort = sorts[i];
    var c = _compareForSort(row.cells[sort.field], cursor.values[i]);
    if (sort.direction == ZSortDirection.desc) c = -c;
    if (c != 0) return c;
  }
  // Égalité sur toutes les clés d'ordre → départage par `id` (si l'ancre en a).
  final cid = cursor.id;
  if (cid != null) return row.id.compareTo(cid);
  // `id: null` légitime : ancre traitée comme exacte (row non « après »).
  return 0;
}

/// Égalité **profonde** de deux listes (élément par élément), pur-Dart (évite
/// `package:collection` — AD-1 out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
