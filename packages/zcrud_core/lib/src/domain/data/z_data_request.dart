/// Value objects neutres de **requête** du domaine `zcrud_core`.
///
/// origine: lex_core (module « Étude ») — `DataRequest` (filtres/tri/recherche +
/// pagination) des repositories. Canonique §7 ; AD-5 (backend-agnostique) ;
/// AD-16 (pagination curseur dans le contrat neutre).
///
/// **Décision de nommage (finding readiness #15)** : `DataRequest` et `ZQuery`
/// sont **fusionnés** en un seul type préfixé `Z` — `ZDataRequest`. `ZQuery`
/// n'est **pas** créé (aucune prolifération `DataRequest`+`ZQuery`).
library;

import 'z_cursor.dart';

/// Opérateur de comparaison d'un [ZFilter]. Valeurs en **camelCase** (canonique §5).
enum ZFilterOp {
  /// Égal (`==`).
  eq,

  /// Différent (`!=`).
  neq,

  /// Strictement inférieur (`<`).
  lt,

  /// Inférieur ou égal (`<=`).
  lte,

  /// Strictement supérieur (`>`).
  gt,

  /// Supérieur ou égal (`>=`).
  gte,

  /// Contient (sous-chaîne / appartenance d'élément à un champ collection).
  contains,

  /// Appartient à l'ensemble de valeurs fourni (`value` est une `List`).
  isIn,

  /// Le champ est `null`.
  isNull,
}

/// Sens de tri d'un [ZSort]. Valeurs en **camelCase** (canonique §5).
enum ZSortDirection {
  /// Ordre croissant.
  asc,

  /// Ordre décroissant.
  desc,
}

/// Prédicat de filtrage neutre : `field` [op] `value`.
///
/// [value] est **opaque** (`Object?`) — aucune contrainte de type backend. Pour
/// [ZFilterOp.isIn], [value] est une `List` ; pour [ZFilterOp.isNull], [value]
/// est ignorée.
class ZFilter {
  /// Construit un filtre `field op value`.
  const ZFilter(this.field, this.op, [this.value]);

  /// Nom logique du champ ciblé (opaque, snake/camel décidé par l'adaptateur).
  final String field;

  /// Opérateur de comparaison.
  final ZFilterOp op;

  /// Opérande de comparaison (opaque), ou `null`.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFilter &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          op == other.op &&
          _deepEquals(value, other.value);

  @override
  int get hashCode => Object.hash(runtimeType, field, op, _deepHash(value));

  @override
  String toString() => 'ZFilter($field, $op, $value)';
}

/// Clé de tri neutre : `field` dans la [direction] donnée (croissant par défaut).
class ZSort {
  /// Construit une clé de tri sur [field] dans la [direction] donnée.
  const ZSort(this.field, [this.direction = ZSortDirection.asc]);

  /// Nom logique du champ de tri (opaque).
  final String field;

  /// Sens du tri.
  final ZSortDirection direction;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSort &&
          runtimeType == other.runtimeType &&
          field == other.field &&
          direction == other.direction;

  @override
  int get hashCode => Object.hash(runtimeType, field, direction);

  @override
  String toString() => 'ZSort($field, $direction)';
}

/// Value object **neutre et immuable** décrivant une requête de lecture.
///
/// Porte les [filters], le tri [sorts], la [search] plein-texte et la
/// **pagination curseur** ([limit] + [startAfter]). Un `ZDataRequest()` par
/// défaut (aucun filtre/tri/curseur, tout `null`) représente « tout, non
/// paginé » et est valide.
///
/// Immuable (`const` + champs `final`) ; égalité de **valeur profonde** (listes
/// comparées élément par élément). [copyWith] utilise une sentinelle permettant
/// de **remettre à `null`** [search]/[limit]/[startAfter].
class ZDataRequest {
  /// Construit une requête. Tous les paramètres sont optionnels ; les valeurs
  /// par défaut décrivent « tout, non paginé ».
  const ZDataRequest({
    this.filters = const <ZFilter>[],
    this.sorts = const <ZSort>[],
    this.search,
    this.limit,
    this.startAfter,
  });

  /// Prédicats de filtrage (conjonction). Par défaut : aucun.
  final List<ZFilter> filters;

  /// Clés de tri, appliquées dans l'ordre. Par défaut : aucun tri.
  final List<ZSort> sorts;

  /// Terme de recherche plein-texte, ou `null`.
  final String? search;

  /// Taille de page maximale, ou `null` (non paginé).
  final int? limit;

  /// Curseur d'ancrage de la page suivante, ou `null` (première page).
  final ZCursor? startAfter;

  /// Sentinelle interne : distingue « argument omis » de « mis explicitement à
  /// `null` » dans [copyWith].
  static const Object _unset = Object();

  /// Copie modifiée. Passer explicitement `null` à [search]/[limit]/[startAfter]
  /// les **réinitialise** ; les omettre conserve la valeur courante.
  ZDataRequest copyWith({
    List<ZFilter>? filters,
    List<ZSort>? sorts,
    Object? search = _unset,
    Object? limit = _unset,
    Object? startAfter = _unset,
  }) {
    return ZDataRequest(
      filters: filters ?? this.filters,
      sorts: sorts ?? this.sorts,
      search: identical(search, _unset) ? this.search : search as String?,
      limit: identical(limit, _unset) ? this.limit : limit as int?,
      startAfter:
          identical(startAfter, _unset) ? this.startAfter : startAfter as ZCursor?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDataRequest &&
          runtimeType == other.runtimeType &&
          search == other.search &&
          limit == other.limit &&
          startAfter == other.startAfter &&
          _listEquals(filters, other.filters) &&
          _listEquals(sorts, other.sorts);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(filters),
        Object.hashAll(sorts),
        search,
        limit,
        startAfter,
      );

  @override
  String toString() =>
      'ZDataRequest(filters: $filters, sorts: $sorts, search: $search, '
      'limit: $limit, startAfter: $startAfter)';
}

/// Égalité **profonde** de deux listes (élément par élément), en pur-Dart.
///
/// Interne : évite `package:collection` dans le cœur (AD-1, out-degree 0).
bool _listEquals(List<Object?> a, List<Object?> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_deepEquals(a[i], b[i])) return false;
  }
  return true;
}

/// Égalité profonde d'une valeur opaque, gérant les `List` imbriquées
/// (utile pour [ZFilterOp.isIn] dont l'opérande est une liste).
bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List<Object?> && b is List<Object?>) return _listEquals(a, b);
  return a == b;
}

/// Hash cohérent avec [_deepEquals] (les listes hachent leur contenu).
int _deepHash(Object? value) =>
    value is List<Object?> ? Object.hashAll(value) : value.hashCode;
