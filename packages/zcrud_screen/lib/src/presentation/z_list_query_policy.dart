/// `ZListQueryPolicy` — **tri par défaut, filtres permanents, taille de page
/// et sémantique de recherche**, déclarés sur l'écran plutôt que recousus à la
/// main.
///
/// Des réglages qui existaient déjà dans le socle (`ZListController` :
/// `baseFilters`, `setSort`, `pageSize`) mais qu'un écran assemblé n'exposait
/// pas : pour trier une liste par défaut, poser un filtre permanent ou changer
/// la taille de page, une application devait construire son propre contrôleur
/// — c'est-à-dire quitter la déclaration. Cette politique les remet dans la
/// déclaration, avec les deux réglages qui gouvernent **ce que cherche la
/// recherche** ([searchScope]) et **comment elle compare** ([searchFolding]).
///
/// ```dart
/// ZCrudScreen<Dossier>(
///   title: 'Dossiers',
///   source: ZCrudSource.repository(repo),
///   registry: registry,
///   query: const ZListQueryPolicy(
///     sort: <ZSort>[ZSort('updated_at', ZSortDirection.desc)],
///     baseFilters: <ZFilter>[ZFilter('archive', ZFilterOp.eq, false)],
///     pageSize: 50,
///   ),
/// );
/// ```
///
/// **Rien de déclaré, rien de changé** : une politique vide
/// ([ZListQueryPolicy.declaresNothing]) laisse l'écran émettre exactement les
/// mêmes requêtes qu'avant — mêmes filtres (aucun), même tri (aucun), même
/// taille de page (aucune, donc jeu non paginé), même recherche (les seuls
/// champs `searchable`, blancs significatifs).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZDataRequest,
        ZFilter,
        ZSearchFolding,
        ZSearchScope,
        ZSort,
        ZSortDirection;

/// Tri par défaut, filtres permanents, taille de page et sémantique de
/// recherche d'un listing **déclarés** sur l'écran.
///
/// ## Ce que chaque réglage veut dire, et ce qu'il ne fait jamais
///
/// | Réglage | Effet | Ce qui l'emporte |
/// |---|---|---|
/// | [sort] | ordre du **premier** rendu | un tri demandé ensuite le **remplace** |
/// | [baseFilters] | filtres **permanents** de l'écran | rien : un filtre de l'usager s'y **ajoute** |
/// | [pageSize] | taille de page du listing paginé | — |
/// | [searchScope] | colonnes que la recherche interroge | — |
/// | [searchFolding] | ce que la recherche ignore en comparant | — |
///
/// La différence entre les deux premières lignes est la clé : un **tri** est
/// un point de vue, il se remplace ; un **filtre de base** est une règle de
/// l'écran (« ce listing ne montre jamais les archives »), il ne se remplace
/// pas. C'est pourquoi le tri passe par [sortFor] (« celui-ci, ou le mien à
/// défaut ») et les filtres par [filtersWith] (« les miens, puis les vôtres »).
///
/// ## Composition avec le reste de l'écran
///
/// * **Corbeille** — la vue corbeille reste une vue corbeille : la portée de
///   suppression qu'elle impose n'est pas touchée, les filtres permanents et
///   le tri par défaut s'y appliquent **en plus**.
/// * **Onglets** — un onglet catégorise par ses propres filtres. Une page
///   d'onglet qui veut hériter des filtres permanents de l'écran les compose
///   par [filtersWith] : les permanents d'abord, la catégorie ensuite, jamais
///   l'un à la place de l'autre.
/// * **Recherche** — la recherche est un terme, pas un filtre : elle
///   n'efface ni les filtres permanents ni le tri, et élargir son domaine
///   ([searchScope]) ne la fait pas déborder d'un filtre permanent ni de la
///   vue corbeille — elle cherche **dans** ce que la requête a déjà réduit.
///
/// Immuable, comparable par valeur : deux politiques égales ne provoquent
/// aucune reconstruction (AD-2).
@immutable
class ZListQueryPolicy {
  /// Déclare la politique de requête. Tout est optionnel — la politique par
  /// défaut ne déclare rien et laisse le comportement inchangé.
  const ZListQueryPolicy({
    this.sort = const <ZSort>[],
    this.baseFilters = const <ZFilter>[],
    this.pageSize,
    this.searchScope = ZSearchScope.searchableFields,
    this.searchFolding = ZSearchFolding.diacritics,
  });

  /// Raccourci du cas courant : **trier par un champ**, éventuellement avec
  /// des filtres permanents et une taille de page.
  ///
  /// ```dart
  /// query: ZListQueryPolicy.sortedBy('name'),
  /// query: ZListQueryPolicy.sortedBy(
  ///   'updated_at',
  ///   direction: ZSortDirection.desc,
  /// ),
  /// ```
  ///
  /// Ce raccourci n'est **pas** `const` (il compose sa liste de tri) : la
  /// forme `const ZListQueryPolicy(sort: <ZSort>[…])` reste disponible pour
  /// une déclaration constante.
  ZListQueryPolicy.sortedBy(
    String field, {
    ZSortDirection direction = ZSortDirection.asc,
    this.baseFilters = const <ZFilter>[],
    this.pageSize,
    this.searchScope = ZSearchScope.searchableFields,
    this.searchFolding = ZSearchFolding.diacritics,
  }) : sort = <ZSort>[ZSort(field, direction)];

  /// Raccourci de la **parité avec les moteurs de liste historiques** : la
  /// recherche interroge **toutes** les colonnes déclarées et ignore les
  /// blancs.
  ///
  /// ```dart
  /// query: const ZListQueryPolicy.legacySearch(),
  /// ```
  ///
  /// C'est exactement `ZListQueryPolicy(searchScope: ZSearchScope.allColumns,
  /// searchFolding: ZSearchFolding.diacriticsAndSpaces)` — les autres réglages
  /// restent déclarables.
  const ZListQueryPolicy.legacySearch({
    this.sort = const <ZSort>[],
    this.baseFilters = const <ZFilter>[],
    this.pageSize,
  })  : searchScope = ZSearchScope.allColumns,
        searchFolding = ZSearchFolding.diacriticsAndSpaces;

  /// **Tri par défaut** du listing, appliqué au premier rendu et à toute
  /// requête qui n'en porte pas d'autre (recherche, changement de page,
  /// rafraîchissement après écriture).
  ///
  /// Plusieurs clés sont honorées dans l'ordre déclaré. Un tri demandé
  /// ensuite — par l'usager, ou par l'application via
  /// `ZCrudScreenActions.sortBy` — **remplace** celui-ci : c'est un défaut, pas
  /// une contrainte. Vide (défaut) = aucun tri imposé, l'ordre est celui de la
  /// source.
  final List<ZSort> sort;

  /// **Filtres permanents** de l'écran, présents dans **chaque** requête —
  /// première page, page suivante, recherche, vue corbeille comprise.
  ///
  /// Ils expriment une règle du listing (« jamais les archives », « seulement
  /// l'exercice courant »), pas un choix de l'usager : un filtre appliqué
  /// ensuite s'y **ajoute** en conjonction, il ne les remplace jamais. Vide
  /// (défaut) = aucun filtre permanent.
  final List<ZFilter> baseFilters;

  /// **Taille de page** du listing paginé (`null` par défaut = non paginé,
  /// comportement historique).
  ///
  /// Elle gouverne la pagination **curseur** de la voie dépôt : chaque requête
  /// demande au plus ce nombre de lignes, et la page suivante s'obtient par le
  /// curseur. Sur la voie `items` (liste déjà en mémoire, rendue d'un bloc),
  /// elle n'a pas d'objet : tronquer une liste sans geste « page suivante »
  /// masquerait des éléments sans recours.
  final int? pageSize;

  /// **Colonnes interrogées** par la recherche plein-texte.
  ///
  /// Par défaut ([ZSearchScope.searchableFields]), seuls les champs déclarés
  /// `searchable: true` sont interrogés : le schéma choisit ce qui est
  /// cherchable, et une colonne technique ne devient pas trouvable par
  /// accident.
  ///
  /// [ZSearchScope.allColumns] interroge **toutes** les colonnes déclarées —
  /// le domaine des moteurs de liste historiques. C'est le réglage à poser
  /// quand une valeur visible à l'écran doit être trouvable sans avoir à
  /// annoter le schéma champ par champ. Le coût est réel mais borné : la
  /// recherche compare le terme à chaque colonne de chaque ligne **déjà
  /// retenue** par les filtres, au lieu des seules colonnes `searchable` — un
  /// facteur au plus égal au nombre de colonnes, sur un jeu déjà réduit, et
  /// aucune lecture supplémentaire de la source.
  final ZSearchScope searchScope;

  /// **Ce que la recherche ignore** en comparant le terme aux valeurs.
  ///
  /// Par défaut ([ZSearchFolding.diacritics]), la casse et les accents sont
  /// ignorés, les blancs **comptent** : « SARL U » ne se laisse pas trouver
  /// par « sarlu ». [ZSearchFolding.diacriticsAndSpaces] ignore en plus tous
  /// les blancs — le comportement des moteurs de liste historiques, à poser
  /// quand les données portent des espacements irréguliers (raisons sociales,
  /// immatriculations, numéros de conteneur).
  final ZSearchFolding searchFolding;

  /// `true` quand la politique ne déclare **rien** — l'écran se comporte alors
  /// exactement comme sans politique du tout.
  bool get declaresNothing =>
      sort.isEmpty &&
      baseFilters.isEmpty &&
      pageSize == null &&
      searchScope == ZSearchScope.searchableFields &&
      searchFolding == ZSearchFolding.diacritics;

  /// Les filtres à appliquer quand [extra] s'ajoute aux filtres permanents :
  /// **les permanents d'abord, [extra] ensuite**.
  ///
  /// C'est l'unique règle de composition des filtres de l'écran, et elle ne
  /// sait qu'ajouter : aucun appel ne peut faire disparaître un filtre
  /// permanent, ni le filtre de catégorie qu'on lui confie.
  List<ZFilter> filtersWith(List<ZFilter> extra) {
    if (extra.isEmpty) return baseFilters;
    if (baseFilters.isEmpty) return extra;
    return <ZFilter>[...baseFilters, ...extra];
  }

  /// Le tri effectif quand [requested] est le tri demandé : [requested] s'il
  /// en porte un, sinon le tri par défaut [sort].
  ///
  /// C'est l'unique règle de composition du tri : un tri demandé **remplace**
  /// le défaut (il ne s'y ajoute pas — deux points de vue empilés ne veulent
  /// rien dire), et son absence le laisse s'appliquer.
  List<ZSort> sortFor(List<ZSort> requested) =>
      requested.isEmpty ? sort : requested;

  /// Pose la politique sur une [request] : filtres permanents **en tête** des
  /// filtres déjà présents, tri par défaut si la requête n'en porte aucun,
  /// taille de page si la requête n'en fixe aucune, et sémantique de recherche
  /// déclarée.
  ///
  /// Tout le reste de la requête est transmis tel quel — la portée de
  /// suppression d'une vue corbeille, le terme de recherche et le curseur de
  /// page ne sont jamais touchés.
  ZDataRequest applyTo(ZDataRequest request) => request.copyWith(
        filters: filtersWith(request.filters),
        sorts: sortFor(request.sorts),
        limit: request.limit ?? pageSize,
        searchScope: searchScope,
        searchFolding: searchFolding,
      );

  /// Copie modifiée de la politique.
  ZListQueryPolicy copyWith({
    List<ZSort>? sort,
    List<ZFilter>? baseFilters,
    int? pageSize,
    ZSearchScope? searchScope,
    ZSearchFolding? searchFolding,
  }) =>
      ZListQueryPolicy(
        sort: sort ?? this.sort,
        baseFilters: baseFilters ?? this.baseFilters,
        pageSize: pageSize ?? this.pageSize,
        searchScope: searchScope ?? this.searchScope,
        searchFolding: searchFolding ?? this.searchFolding,
      );

  /// La politique de l'écran englobant, ou `null` hors d'un écran qui en
  /// déclare une.
  ///
  /// Sert aux vues construites **par l'application** sous l'écran — la page
  /// d'un onglet, un en-tête de filtre — pour hériter des filtres permanents
  /// au lieu de les recopier. Hors d'un écran, `null` : le widget reste
  /// montable seul (AD-10).
  static ZListQueryPolicy? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZListQueryScope>()
      ?.policy;

  /// La politique de l'écran englobant, ou une politique **vide** hors écran —
  /// la forme à préférer quand l'appelant veut composer sans se soucier de
  /// l'absence.
  ///
  /// ```dart
  /// // Page d'onglet : les filtres permanents de l'écran, puis la catégorie.
  /// baseFilters: ZListQueryPolicy.of(context).filtersWith(categoryFilters),
  /// ```
  static ZListQueryPolicy of(BuildContext context) =>
      maybeOf(context) ?? const ZListQueryPolicy();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZListQueryPolicy &&
          runtimeType == other.runtimeType &&
          pageSize == other.pageSize &&
          searchScope == other.searchScope &&
          searchFolding == other.searchFolding &&
          _sameSorts(sort, other.sort) &&
          _sameFilters(baseFilters, other.baseFilters);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(sort),
        Object.hashAll(baseFilters),
        pageSize,
        searchScope,
        searchFolding,
      );

  @override
  String toString() => 'ZListQueryPolicy(sort: $sort, '
      'baseFilters: $baseFilters, pageSize: $pageSize, '
      'searchScope: $searchScope, searchFolding: $searchFolding)';
}

/// Contexte portant la [ZListQueryPolicy] d'un écran autour de son corps.
///
/// Posé par `ZCrudScreen` **uniquement** quand une politique est déclarée :
/// sans déclaration, l'arbre est celui d'avant, à l'identique.
class ZListQueryScope extends InheritedWidget {
  /// Pose la [policy] de l'écran autour de [child].
  const ZListQueryScope({
    required this.policy,
    required super.child,
    super.key,
  });

  /// La politique de requête de l'écran englobant.
  final ZListQueryPolicy policy;

  @override
  bool updateShouldNotify(ZListQueryScope oldWidget) =>
      oldWidget.policy != policy;
}

/// Égalité élément par élément de deux listes de tri.
bool _sameSorts(List<ZSort> a, List<ZSort> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Égalité élément par élément de deux listes de filtres.
bool _sameFilters(List<ZFilter> a, List<ZFilter> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
