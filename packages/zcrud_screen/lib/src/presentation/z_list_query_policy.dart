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
/// champs `searchable`, blancs significatifs), même voie de pagination.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZDataRequest,
        ZFilter,
        ZFilterGroup,
        ZItemFilter,
        ZListPaginationMode,
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
/// | [baseFilterGroups] | disjonctions permanentes (« valeur **ou** champ absent ») | rien : ANDées au reste |
/// | [itemFilter] | **post-filtre** de l'écran, écrit sur l'entité | rien : il ne peut que retirer |
/// | [pageSize] | taille de page du listing paginé | — |
/// | [searchScope] | colonnes que la recherche interroge | — |
/// | [searchFolding] | ce que la recherche ignore en comparant | — |
/// | [paginationMode] | où la liste est paginée, filtrée et cherchée | — |
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
/// ## Quand le périmètre n'est pas une requête
///
/// [baseFilters] suppose que la règle de l'écran s'écrit en clauses. Trois
/// déclarations prennent le relais quand ce n'est pas le cas :
///
/// * `ZFilter.servedBySource`, dans [baseFilters], pour la clause que **seule
///   la base sait trancher** — un champ calculé, jamais persisté, qu'aucune
///   colonne ne porte : elle part dans la requête et n'est jamais rejouée sur
///   les lignes ;
/// * [baseFilterGroups] pour la **disjonction** — « cet état **ou** ce champ
///   jamais renseigné », le cas de l'onglet d'entrée d'un workflow ;
/// * [itemFilter] pour le **post-filtre** — un prédicat Dart écrit sur
///   l'entité, quand le dernier mot appartient au métier (croisement de
///   droits, fenêtre calculée, catégorie qui n'existe pas en base).
///
/// Les deux dernières se paient de la même façon, et il faut le savoir avant
/// de les déclarer : **le listing bascule en mémoire** et lit le jeu entier à
/// chaque requête, parce qu'aucune source n'est réputée savoir les servir.
/// Voir [itemFilter] pour le détail du coût et des cas où il ne faut pas en
/// déclarer. La première, elle, ne coûte rien — mais elle ne vaut que ce que
/// la source en fait (voir [baseFilters]).
///
/// Une fois en mémoire, le listing **n'envoie plus son tri à la source** : il
/// lit le jeu entier puis l'ordonne lui-même, en classant les valeurs absentes
/// au lieu de les retrancher (voir [paginationMode]).
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
    this.baseFilterGroups = const <ZFilterGroup>[],
    this.itemFilter,
    this.pageSize,
    this.searchScope = ZSearchScope.searchableFields,
    this.searchFolding = ZSearchFolding.diacritics,
    this.paginationMode = ZListPaginationMode.backendCursor,
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
    this.baseFilterGroups = const <ZFilterGroup>[],
    this.itemFilter,
    this.pageSize,
    this.searchScope = ZSearchScope.searchableFields,
    this.searchFolding = ZSearchFolding.diacritics,
    this.paginationMode = ZListPaginationMode.backendCursor,
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
    this.baseFilterGroups = const <ZFilterGroup>[],
    this.itemFilter,
    this.pageSize,
    this.paginationMode = ZListPaginationMode.backendCursor,
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
  ///
  /// **Une clause que seule la base sait trancher** se déclare ici aussi, avec
  /// `ZFilter.servedBySource` :
  ///
  /// ```dart
  /// // `etat_depotage` est calculé côté source : aucune colonne ne le porte.
  /// baseFilters: <ZFilter>[
  ///   ZFilter.servedBySource('etat_depotage', ZFilterOp.isIn, <String>['termine']),
  /// ],
  /// ```
  ///
  /// Dès qu'un listing est servi en mémoire (voir [paginationMode],
  /// [itemFilter], [baseFilterGroups], ou une recherche en cours), les filtres
  /// de la requête sont **ré-appliqués** aux lignes projetées — c'est ce qui
  /// les rend exacts devant une source qui ne les traduit pas. Une clause
  /// visant un champ **absent de la ligne** n'y trouve alors rien et **vide le
  /// listing** dès le premier rendu ; la déclarer servie par la source la
  /// laisse partir dans la requête sans jamais être rejouée, ce qui supprime
  /// l'obligation d'ajouter une colonne « pont » au seul bénéfice du filtre.
  ///
  /// ⚠️ C'est une **promesse faite à la source**, pas une garantie du socle :
  /// devant un dépôt qui ne sert pas la clause — ou sur la voie
  /// `ZCrudSource.items`, où il n'y a pas de source à qui adresser la promesse
  /// — elle ne filtre **rien**, et l'écran montre plus que ce qui a été
  /// déclaré, sans erreur ni avertissement. À réserver aux clauses dont le
  /// dépôt est connu capable ; sinon, une clause ordinaire ou un [itemFilter].
  final List<ZFilter> baseFilters;

  /// **Disjonctions permanentes** de l'écran : chaque groupe est ANDé au reste
  /// de la requête, mais ses clauses sont en **OR**. Vide (défaut) = aucune.
  ///
  /// C'est la règle que [baseFilters] ne sait pas dire, et c'est la plus
  /// courante d'un workflow : **l'état initial est l'absence d'état**. Un
  /// onglet « En attente » exprimé par la seule égalité se vide des dossiers
  /// fraîchement déposés, dont le champ n'a jamais été écrit.
  ///
  /// ```dart
  /// query: const ZListQueryPolicy(
  ///   baseFilterGroups: <ZFilterGroup>[
  ///     ZFilterGroup.any(<ZFilter>[
  ///       ZFilter('etat', ZFilterOp.eq, 'enAttente'),
  ///       ZFilter('etat', ZFilterOp.isNull),
  ///     ]),
  ///   ],
  /// ),
  /// ```
  ///
  /// Un groupe **élargit à l'intérieur de lui-même**, jamais au-delà : il ne
  /// peut pas faire ressortir une ligne qu'un filtre permanent, une catégorie
  /// d'onglet ou la portée de corbeille ont exclue. Un groupe **sans clause**
  /// est inerte : il n'impose rien et ne coûte rien.
  ///
  /// **Ce que cela coûte** : aucune source n'est réputée savoir traduire une
  /// disjonction — en déclarer une non inerte fait passer le listing en
  /// mémoire (voir [itemFilter] pour le détail). Le socle préfère cette
  /// lecture complète à une disjonction que la pagination curseur aurait
  /// ignorée en silence, c'est-à-dire à un écran qui montre plus, ou moins,
  /// que ce qui a été déclaré.
  final List<ZFilterGroup> baseFilterGroups;

  /// **Post-filtre de l'écran** : le dernier mot sur ce qui est listé, écrit
  /// sur l'entité typée (`null` par défaut = aucun, rien ne change).
  ///
  /// Filtres et disjonctions supposent une règle exprimable en clauses. Quand
  /// le périmètre appartient au métier — un croisement de droits, une fenêtre
  /// de dates calculée, une catégorie qui n'existe pas en base — il s'écrit en
  /// Dart, et c'est ici qu'il se déclare :
  ///
  /// ```dart
  /// // Déclaré une fois, hors du `build` (voir plus bas).
  /// static bool _visiblePour(Dossier d) => d.habilitations.contains(agent);
  ///
  /// query: ZListQueryPolicy(itemFilter: ZItemFilter.of(_visiblePour)),
  /// ```
  ///
  /// Le prédicat reçoit **l'entité**, jamais la ligne rendue : la règle se lit
  /// dans le vocabulaire du domaine, et renommer un champ devient une erreur
  /// de compilation au lieu d'un listing qui se met silencieusement à tout
  /// montrer.
  ///
  /// **Il ne peut que restreindre** : le listing montre au plus ce qu'il
  /// montrait sans lui. Il s'applique aux entités **lues**, avant leur
  /// projection en lignes — donc avant la recherche, le tri et la pagination :
  /// une page pleine reste pleine, jamais trouée par un filtrage venu après
  /// coup. Le post-filtre d'un onglet (`ZListTab.itemFilter`) s'y ajoute en
  /// conjonction : l'onglet retire, il ne rouvre pas.
  ///
  /// **Ce que cela coûte** : un prédicat Dart ne se traduit dans aucun langage
  /// de requête. Le socle ne peut l'appliquer que sur un jeu déjà lu — le
  /// listing bascule donc sur le **chemin mémoire** et lit le jeu **entier** à
  /// chaque requête, pour toute sa vie (là où la bascule d'une recherche ne
  /// dure que le temps du terme saisi). Raisonnable sur un listing borné,
  /// à proscrire sur une collection sans borne.
  ///
  /// **Quand ne PAS en déclarer** : dès que la règle est exprimable en
  /// clauses. Un [baseFilters] — ou un [baseFilterGroups] pour « cette valeur
  /// ou ce champ absent » — reste servi par la source, garde la pagination
  /// curseur et ne lit que la page affichée. Le post-filtre est la voie de ce
  /// qui n'est **pas** requêtable, jamais un raccourci d'écriture.
  ///
  /// **À déclarer hors du `build`** : deux politiques sont comparées par
  /// valeur, et changer de politique reconstruit les contrôleurs du listing.
  /// Une fonction nommée reste égale à elle-même d'une image à l'autre ; une
  /// lambda écrite dans `build` est une fonction neuve à chaque fois, et le
  /// listing se rechargerait sans fin.
  final ZItemFilter? itemFilter;

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

  /// **Où la liste est paginée, filtrée, triée et cherchée** : sur la source,
  /// ou en mémoire.
  ///
  /// Par défaut ([ZListPaginationMode.backendCursor]), le listing demande une
  /// page à la fois et laisse la source faire le travail — le comportement
  /// historique, et le seul tenable sur un gros parc.
  ///
  /// [ZListPaginationMode.inMemory] lit le jeu **entier** puis applique
  /// recherche, filtres, tri et pagination avec le moteur du socle. C'est le
  /// réglage à déclarer quand la source ne sait pas tout servir — typiquement
  /// une recherche plein-texte, que Firestore n'a pas — et que le listing
  /// tient en mémoire :
  ///
  /// ```dart
  /// query: const ZListQueryPolicy(
  ///   paginationMode: ZListPaginationMode.inMemory,
  /// ),
  /// ```
  ///
  /// **Ce que cela coûte** : une lecture non paginée de la source à chaque
  /// requête. Raisonnable pour un référentiel de quelques milliers de lignes,
  /// à proscrire sur une collection sans borne.
  ///
  /// **Ce que devient le tri** : il n'est **pas** transmis à la source. Le jeu
  /// est lu avant d'être ordonné, et c'est le moteur du socle qui rend l'ordre
  /// demandé — en **classant** les valeurs absentes (dernières en croissant,
  /// premières en décroissant) là où l'ordre d'un backend documentaire
  /// **exclut** les documents dépourvus du champ trié. Un listing trié sur une
  /// date facultative garde donc ses éléments non datés, et aucun index
  /// composite n'est exigé pour un tri qui ne s'applique qu'en mémoire. Cela
  /// vaut pour toutes les bascules en mémoire — celle-ci, celle d'un
  /// [itemFilter] ou d'un [baseFilterGroups], celle d'une recherche en cours.
  /// Sur la voie dépôt à périmètre requêtable, tri et pagination restent
  /// **serveur**, inchangés.
  ///
  /// **À n'employer que si le mode automatique ne suffit pas** : un dépôt qui
  /// déclare `ZDelegatesSearch` (l'adaptateur Firestore le fait) fait déjà
  /// basculer le listing en mémoire **le temps d'une recherche**, sans rien
  /// déclarer ici et sans rien coûter le reste du temps. Ce réglage sert les
  /// cas où le filtrage ou le tri, eux aussi, doivent être exacts sur une
  /// source qui ne les sert pas.
  final ZListPaginationMode paginationMode;

  /// `true` quand la politique ne déclare **rien** — l'écran se comporte alors
  /// exactement comme sans politique du tout.
  bool get declaresNothing =>
      sort.isEmpty &&
      baseFilters.isEmpty &&
      baseFilterGroups.isEmpty &&
      itemFilter == null &&
      pageSize == null &&
      searchScope == ZSearchScope.searchableFields &&
      searchFolding == ZSearchFolding.diacritics &&
      paginationMode == ZListPaginationMode.backendCursor;

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

  /// Les disjonctions à appliquer quand [extra] s'ajoute à celles de l'écran :
  /// **celles de l'écran d'abord, [extra] ensuite**.
  ///
  /// Même règle que [filtersWith], et pour la même raison : les groupes sont
  /// ANDés entre eux, aucun appel ne peut donc en faire disparaître un.
  List<ZFilterGroup> filterGroupsWith(List<ZFilterGroup> extra) {
    if (extra.isEmpty) return baseFilterGroups;
    if (baseFilterGroups.isEmpty) return extra;
    return <ZFilterGroup>[...baseFilterGroups, ...extra];
  }

  /// Le post-filtre effectif quand [extra] s'ajoute à celui de l'écran : les
  /// deux doivent retenir l'entité (**conjonction**), ou celui qui existe si
  /// l'autre est absent, ou `null` si aucun n'est déclaré.
  ///
  /// C'est la règle de cascade des niveaux — écran puis onglet : un niveau ne
  /// peut que **retirer**, jamais rendre ce qu'un autre a écarté.
  ZItemFilter? itemFilterWith(ZItemFilter? extra) =>
      ZItemFilter.every(<ZItemFilter?>[itemFilter, extra]);

  /// Le tri effectif quand [requested] est le tri demandé : [requested] s'il
  /// en porte un, sinon le tri par défaut [sort].
  ///
  /// C'est l'unique règle de composition du tri : un tri demandé **remplace**
  /// le défaut (il ne s'y ajoute pas — deux points de vue empilés ne veulent
  /// rien dire), et son absence le laisse s'appliquer.
  List<ZSort> sortFor(List<ZSort> requested) =>
      requested.isEmpty ? sort : requested;

  /// Pose la politique sur une [request] : filtres permanents **en tête** des
  /// filtres déjà présents, disjonctions permanentes en tête de celles déjà
  /// présentes, tri par défaut si la requête n'en porte aucun, taille de page
  /// si la requête n'en fixe aucune, et sémantique de recherche déclarée.
  ///
  /// Le **post-filtre** ([itemFilter]) n'entre pas dans la requête : il ne
  /// s'exprime pas en clauses, et c'est le listing qui l'applique aux entités
  /// lues.
  ///
  /// Tout le reste de la requête est transmis tel quel — la portée de
  /// suppression d'une vue corbeille, le terme de recherche et le curseur de
  /// page ne sont jamais touchés.
  ZDataRequest applyTo(ZDataRequest request) => request.copyWith(
        filters: filtersWith(request.filters),
        filterGroups: filterGroupsWith(request.filterGroups),
        sorts: sortFor(request.sorts),
        limit: request.limit ?? pageSize,
        searchScope: searchScope,
        searchFolding: searchFolding,
      );

  /// Copie modifiée de la politique.
  ZListQueryPolicy copyWith({
    List<ZSort>? sort,
    List<ZFilter>? baseFilters,
    List<ZFilterGroup>? baseFilterGroups,
    ZItemFilter? itemFilter,
    int? pageSize,
    ZSearchScope? searchScope,
    ZSearchFolding? searchFolding,
    ZListPaginationMode? paginationMode,
  }) =>
      ZListQueryPolicy(
        sort: sort ?? this.sort,
        baseFilters: baseFilters ?? this.baseFilters,
        baseFilterGroups: baseFilterGroups ?? this.baseFilterGroups,
        itemFilter: itemFilter ?? this.itemFilter,
        pageSize: pageSize ?? this.pageSize,
        searchScope: searchScope ?? this.searchScope,
        searchFolding: searchFolding ?? this.searchFolding,
        paginationMode: paginationMode ?? this.paginationMode,
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
          paginationMode == other.paginationMode &&
          itemFilter == other.itemFilter &&
          _sameSorts(sort, other.sort) &&
          _sameFilters(baseFilters, other.baseFilters) &&
          _sameGroups(baseFilterGroups, other.baseFilterGroups);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        Object.hashAll(sort),
        Object.hashAll(baseFilters),
        Object.hashAll(baseFilterGroups),
        itemFilter,
        pageSize,
        searchScope,
        searchFolding,
        paginationMode,
      );

  @override
  String toString() => 'ZListQueryPolicy(sort: $sort, '
      'baseFilters: $baseFilters, baseFilterGroups: $baseFilterGroups, '
      'itemFilter: $itemFilter, pageSize: $pageSize, '
      'searchScope: $searchScope, searchFolding: $searchFolding, '
      'paginationMode: $paginationMode)';
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

/// Égalité élément par élément de deux listes de disjonctions.
bool _sameGroups(List<ZFilterGroup> a, List<ZFilterGroup> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
