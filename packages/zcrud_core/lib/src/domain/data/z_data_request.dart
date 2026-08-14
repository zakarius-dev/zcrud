/// Value objects neutres de **requête** du domaine `zcrud_core`.
///
/// Porte le domaine backend-agnostique de l'invariant AD-5 et la pagination
/// par curseur dans le contrat neutre de l'invariant AD-16. Un seul type
/// préfixé `Z` — `ZDataRequest` — couvre filtres, tri, recherche et
/// pagination : aucun type distinct n'est créé pour ces responsabilités.
library;

import 'z_cursor.dart';
import 'z_search_text.dart';

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

/// Sélection de **suppression logique** d'une requête de lecture (listing
/// corbeille). Valeurs en **camelCase** (canonique §5).
///
/// Étend `ZDataRequest` de façon **additive** : le défaut [aliveOnly] reproduit
/// le comportement historique (exclusion des soft-deleted, invariant AD-9) —
/// aucun appelant existant n'est affecté. La sémantique exacte de « supprimé »
/// (drapeau `is_deleted` hors-entité `ZSyncMeta`, éventuelle clé préexistante
/// côté hôte) est tranchée par l'**adaptateur** backend : ce membre reste
/// backend-agnostique (invariant AD-5).
enum ZDeletedScope {
  /// Seuls les documents **vivants** (non soft-deleted) — défaut, comportement
  /// historique inchangé.
  aliveOnly,

  /// Vivants **et** soft-deleted (vue « tout », badge corbeille).
  includeDeleted,

  /// Seuls les **soft-deleted** (listing corbeille : clear/restore).
  deletedOnly,
}

/// **Domaine de colonnes** interrogé par la recherche plein-texte d'une
/// requête. Valeurs en **camelCase** (canonique §5).
///
/// Étend `ZDataRequest` de façon **additive** : le défaut [searchableFields]
/// reproduit le comportement historique — aucune requête existante n'est
/// affectée.
enum ZSearchScope {
  /// Seuls les champs déclarés `searchable: true` — défaut, comportement
  /// historique inchangé.
  ///
  /// Domaine **choisi** : la recherche ne coûte que ce que le schéma a
  /// désigné, et ne peut pas exposer un champ technique.
  searchableFields,

  /// **Toutes** les colonnes du schéma, `searchable` ou non.
  ///
  /// Domaine **large** : tout ce qui est déclaré est trouvable. C'est le
  /// domaine des moteurs de liste historiques, et le réglage à poser quand une
  /// application constate qu'une valeur affichée n'est pas cherchable.
  allColumns,
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

/// **Disjonction** de prédicats : une ligne est retenue dès qu'**au moins une**
/// des [clauses] la retient.
///
/// Les [ZFilter] d'une requête se composent en **conjonction** — chacun
/// restreint ce que le précédent a laissé passer. C'est la bonne règle pour un
/// listing (« jamais les archives », « seulement l'exercice courant »), mais
/// elle ne sait pas dire le cas le plus courant d'un workflow : **une valeur ou
/// l'absence de valeur**. L'état initial d'un dossier, c'est très souvent
/// l'absence d'état — le champ n'a jamais été écrit. Un onglet « En attente »
/// exprimé par la seule égalité `etat == enAttente` se vide donc des dossiers
/// fraîchement déposés, silencieusement.
///
/// ```dart
/// // « En attente », c'est la valeur… OU le champ jamais renseigné.
/// ZFilterGroup.any(<ZFilter>[
///   ZFilter('etat', ZFilterOp.eq, 'enAttente'),
///   ZFilter('etat', ZFilterOp.isNull),
/// ])
/// ```
///
/// **Composition** : les groupes d'une requête sont ANDés entre eux **et** avec
/// [ZDataRequest.filters]. Un groupe élargit donc *à l'intérieur de lui-même*,
/// jamais au-delà : ajouter un groupe ne peut pas faire ressortir une ligne
/// qu'un filtre permanent a exclue.
///
/// **Groupe sans clause** : inerte — il n'exprime aucune intention, il
/// n'impose donc aucune contrainte (et ne fait basculer aucun listing en
/// mémoire). C'est délibéré : une disjonction est une construction qui
/// **élargit** ; une disjonction vide n'élargit rien, et la lire comme « ne
/// retenir personne » viderait un listing sur une liste de clauses calculée
/// qui se trouve vide — exactement l'écran vide sans recours que ce type
/// cherche à éviter.
///
/// **Qui le sert** : le moteur de liste du socle (`zApplyListRequest`), donc la
/// voie mémoire. Un adaptateur libre de traduire la disjonction dans son
/// langage de requête peut le faire ; celui qui ne le sait pas l'ignore, et le
/// socle ne s'y fie jamais — un listing dont la déclaration porte un groupe est
/// servi en mémoire, où la disjonction est appliquée pour de bon.
class ZFilterGroup {
  /// Construit une disjonction des [clauses] : une ligne est retenue dès
  /// qu'**une** clause la retient. Sans clause, le groupe est inerte.
  const ZFilterGroup.any(this.clauses);

  /// Clauses de la disjonction (au moins une doit matcher).
  final List<ZFilter> clauses;

  /// `true` quand le groupe ne porte **aucune** clause — il n'impose alors
  /// aucune contrainte.
  bool get isEmpty => clauses.isEmpty;

  /// `true` quand le groupe porte au moins une clause.
  bool get isNotEmpty => clauses.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFilterGroup &&
          runtimeType == other.runtimeType &&
          _listEquals(clauses, other.clauses);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(clauses));

  @override
  String toString() => 'ZFilterGroup.any($clauses)';
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
    this.filterGroups = const <ZFilterGroup>[],
    this.sorts = const <ZSort>[],
    this.search,
    this.limit,
    this.startAfter,
    this.deletedScope = ZDeletedScope.aliveOnly,
    this.searchScope = ZSearchScope.searchableFields,
    this.searchFolding = ZSearchFolding.diacritics,
  });

  /// Prédicats de filtrage (conjonction). Par défaut : aucun.
  final List<ZFilter> filters;

  /// **Disjonctions** ([ZFilterGroup]) de la requête, ANDées entre elles et
  /// avec [filters]. Par défaut : aucune — champ **additif**, aucune requête
  /// existante n'est affectée.
  ///
  /// Servi par le moteur de liste du socle (`zApplyListRequest`). Un
  /// adaptateur qui exécute la requête côté serveur reste libre de ne pas le
  /// traduire, comme il l'est déjà pour [search] : c'est pourquoi la
  /// déclaration d'un groupe **impose** au listing la voie mémoire, où la
  /// disjonction est appliquée pour de bon. Une lecture directe du dépôt avec
  /// des groupes, hors du listing, ne bénéficie donc d'aucune garantie
  /// d'exactitude tant que l'adaptateur ne les documente pas comme servis.
  final List<ZFilterGroup> filterGroups;

  /// Clés de tri, appliquées dans l'ordre. Par défaut : aucun tri.
  final List<ZSort> sorts;

  /// Terme de recherche plein-texte, ou `null`.
  final String? search;

  /// Taille de page maximale, ou `null` (non paginé).
  final int? limit;

  /// Curseur d'ancrage de la page suivante, ou `null` (première page).
  final ZCursor? startAfter;

  /// Sélection de suppression logique (corbeille). Par défaut :
  /// [ZDeletedScope.aliveOnly] — comportement historique **inchangé**
  /// (exclusion des soft-deleted). Champ additif.
  final ZDeletedScope deletedScope;

  /// **Domaine de colonnes** de la recherche [search]. Par défaut :
  /// [ZSearchScope.searchableFields] — comportement historique **inchangé**
  /// (seuls les champs déclarés `searchable`). Champ additif.
  ///
  /// Servi par le moteur in-memory (`zApplyListRequest`). Un adaptateur qui
  /// exécute la recherche côté serveur reste libre de ne pas l'honorer : il
  /// doit alors le dire dans sa documentation, comme il le fait déjà pour
  /// [search].
  final ZSearchScope searchScope;

  /// **Profondeur de normalisation** de la recherche [search], appliquée au
  /// terme comme aux valeurs. Par défaut : [ZSearchFolding.diacritics] —
  /// comportement historique **inchangé**. Champ additif.
  final ZSearchFolding searchFolding;

  /// Sentinelle interne : distingue « argument omis » de « mis explicitement à
  /// `null` » dans [copyWith].
  static const Object _unset = Object();

  /// `true` quand la requête porte au moins une disjonction **non inerte** —
  /// c'est-à-dire une contrainte que les seuls [filters] ne savent pas dire.
  bool get hasFilterGroups {
    for (final group in filterGroups) {
      if (group.isNotEmpty) return true;
    }
    return false;
  }

  /// Copie modifiée. Passer explicitement `null` à [search]/[limit]/[startAfter]
  /// les **réinitialise** ; les omettre conserve la valeur courante.
  ZDataRequest copyWith({
    List<ZFilter>? filters,
    List<ZFilterGroup>? filterGroups,
    List<ZSort>? sorts,
    Object? search = _unset,
    Object? limit = _unset,
    Object? startAfter = _unset,
    ZDeletedScope? deletedScope,
    ZSearchScope? searchScope,
    ZSearchFolding? searchFolding,
  }) {
    return ZDataRequest(
      filters: filters ?? this.filters,
      filterGroups: filterGroups ?? this.filterGroups,
      sorts: sorts ?? this.sorts,
      search: identical(search, _unset) ? this.search : search as String?,
      limit: identical(limit, _unset) ? this.limit : limit as int?,
      startAfter:
          identical(startAfter, _unset) ? this.startAfter : startAfter as ZCursor?,
      deletedScope: deletedScope ?? this.deletedScope,
      searchScope: searchScope ?? this.searchScope,
      searchFolding: searchFolding ?? this.searchFolding,
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
          deletedScope == other.deletedScope &&
          searchScope == other.searchScope &&
          searchFolding == other.searchFolding &&
          _listEquals(filters, other.filters) &&
          _listEquals(filterGroups, other.filterGroups) &&
          _listEquals(sorts, other.sorts);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(filters),
        Object.hashAll(filterGroups),
        Object.hashAll(sorts),
        search,
        limit,
        startAfter,
        deletedScope,
        searchScope,
        searchFolding,
      );

  @override
  String toString() =>
      'ZDataRequest(filters: $filters, filterGroups: $filterGroups, '
      'sorts: $sorts, search: $search, '
      'limit: $limit, startAfter: $startAfter, deletedScope: $deletedScope, '
      'searchScope: $searchScope, searchFolding: $searchFolding)';
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
