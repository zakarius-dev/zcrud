/// Contrôleur de liste **Flutter-natif** du cœur `zcrud_core`.
///
/// Recherche/filtre/tri/pagination (AD-2/AD-11/AD-15/AD-16). Pendant
/// `DynamicList` de `ZFormController` : réactivité **Flutter-native** exposant
/// une **unique tranche** `ValueListenable<ZListViewState>` — AUCUN
/// gestionnaire d'état (ni `zcrud_list`/Syncfusion). Le code manager-spécifique
/// vit dans les bindings (`zcrud_riverpod`/`zcrud_get`), jamais ici.
///
/// Le contrôleur détient le `ZDataRequest` courant (filtres/tri/recherche),
/// pousse la requête au [ZRepository] (chemin backend curseur) OU pagine
/// **entièrement en mémoire** (repli AD-16), projette `T → ZListRow` via le seam
/// [toRow], et mappe le résultat en `ZListViewState` (dont la décision `empty`
/// vs `noResults` est tranchée ici).
///
/// **Recherche que la source ne sait pas servir** : un dépôt qui applique le
/// mixin `ZDelegatesSearch` déclare qu'il ignore `ZDataRequest.search` (ni
/// `LIKE`, ni plein-texte, ni pliage diacritique — le cas de Firestore). Tant
/// qu'aucun terme n'est saisi, rien ne change ; dès qu'une recherche est
/// active, le contrôleur emprunte le chemin mémoire — celui-là même qu'il
/// emprunte déjà quand un curseur n'est pas honoré — et le filtrage devient
/// exact. Le coût, assumé et borné à la durée de la recherche, est une lecture
/// **non paginée** du jeu.
///
/// **Périmètre que la requête ne sait pas dire** : un listing peut déclarer un
/// **post-filtre** (`itemFilter`, prédicat écrit sur l'entité) et des
/// **disjonctions** (`baseFilterGroups`, « cette valeur ou ce champ absent »).
/// Ni l'un ni l'autre n'est traduisible en clause par toutes les sources : les
/// déclarer fait donc emprunter au listing le même chemin mémoire, pour toute
/// sa vie. C'est délibéré — une déclaration de périmètre silencieusement
/// ignorée par la pagination curseur montrerait à l'usager plus que ce que
/// l'écran a autorisé.
///
/// **Ce que la voie mémoire demande à la source** : le jeu, entier, et rien
/// d'autre. Ni page, ni **tri** : le jeu est lu avant d'être ordonné, et c'est
/// le moteur du socle qui rend l'ordre demandé — en **classant** les valeurs
/// absentes, là où l'ordre d'un backend documentaire les **exclut**. Un
/// listing trié sur une date facultative garde donc ses éléments non datés.
///
/// **Ce que le socle ne ré-applique pas** : une clause déclarée
/// `ZFilter.servedBySource`. Elle part dans la requête et n'est jamais rejouée
/// sur les lignes projetées — la voie d'une règle que seule la base sait
/// trancher (valeur calculée, colonne non projetée), et qui, ré-appliquée,
/// viderait le listing faute de cellule correspondante.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/data/z_cursor.dart';
import '../../domain/data/z_data_request.dart';
import '../../domain/data/z_search_text.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/failures/z_failure.dart';
import '../../domain/ports/z_repository.dart';
import '../../domain/ports/z_search_capability.dart';
import 'z_list_query.dart';
import 'z_list_render_request.dart';
import 'z_list_view_state.dart';

/// Stratégie de pagination du [ZListController].
///
/// - [backendCursor] : la pagination curseur native du backend est utilisée
///   (`ZDataRequest.limit`/`startAfter` poussés au repository). Un échec **lié au
///   curseur** bascule automatiquement sur le repli in-memory (AD-16).
/// - [inMemory] : le backend ne supporte PAS le curseur (ou on force le repli) —
///   le jeu non paginé est récupéré puis paginé **en mémoire** via
///   [zApplyListRequest]. C'est aussi le mode à déclarer quand le listing tient
///   en mémoire et doit offrir recherche, tri et filtres complets quelle que
///   soit la source ; son coût est une lecture non paginée du jeu à chaque
///   requête.
enum ZListPaginationMode {
  /// Pagination curseur native (avec repli in-memory sur échec curseur).
  backendCursor,

  /// Repli in-memory total (backend sans support curseur).
  inMemory,
}

/// Contrôleur réactif d'une liste dérivée du schéma, exposant une tranche
/// `ValueListenable<ZListViewState>`.
///
/// Réactivité **Flutter-native** (AD-2/AD-15) : `ChangeNotifier` + `ValueNotifier`
/// interne, aucune dépendance à un gestionnaire d'état. Un widget d'app écoute la
/// SEULE tranche [state] via `ValueListenableBuilder` et rend `DynamicList(state:
/// value)` (réutilise les vues d'états `ZListViewState`).
class ZListController<T extends ZEntity> extends ChangeNotifier {
  /// Construit le contrôleur et **lance immédiatement** la première requête
  /// (état initial `ZListLoading`).
  ///
  /// [repository] source des données (port neutre) ; [toRow] projette une entité
  /// `T` en `ZListRow` neutre ; [schema] porte les champs `searchable` (recherche)
  /// et sert le moteur in-memory ; [pageSize] fixe la taille de page (curseur ;
  /// `null` = non paginé) ; [mode] choisit la stratégie de pagination ; si
  /// [watchMutations] est `true`, s'abonne à `repository.watchAll()` pour
  /// relancer la requête courante à chaque mutation.
  ///
  /// [baseFilters] est un **socle de filtres PERSISTANT** (défaut `const []`,
  /// **additif et rétro-compatible**) : ces filtres sont **toujours ANDés
  /// EN TÊTE** des filtres utilisateur dans CHAQUE requête émise (première page,
  /// `loadMore`, chemin backend ET repli in-memory). Ils expriment une **relation
  /// parent→enfants** (`ZSubListScreen`, `ZFilter(parentField, eq, parentId)`) ou
  /// un **filtre de catégorie d'onglet** (`ZTabbedList`) : `setFilters`/`setSearch`
  /// /`setSort` **ne peuvent JAMAIS** les écraser (là où `setFilters` remplace les
  /// SEULS filtres utilisateur). `baseFilters` vide ⇒ comportement strictement
  /// inchangé (mêmes `ZDataRequest`, mêmes tests).
  ///
  /// [searchScope] et [searchFolding] portent la **sémantique de recherche**
  /// dans chaque requête émise : domaine de colonnes interrogé et profondeur de
  /// normalisation. Leurs défauts
  /// ([ZSearchScope.searchableFields] / [ZSearchFolding.diacritics])
  /// reproduisent le comportement historique **à l'identique**.
  ///
  /// [initialSorts] fait **naître le contrôleur trié** : ces clés de tri sont
  /// portées par la **toute première** requête, celle que la construction émet.
  /// Sans ce paramètre, la seule voie était `setSort` — appelé après coup, il
  /// laissait partir une première requête non triée puis en émettait une
  /// seconde, soit une lecture de la source pour rien, et un premier rendu dans
  /// le mauvais ordre. Un `setSort` ultérieur **remplace** ce tri initial
  /// (même règle que pour les filtres utilisateur : un tri demandé remplace le
  /// tri par défaut). Défaut `const []` ⇒ comportement strictement inchangé.
  ///
  /// [baseFilterGroups] est le pendant **disjonctif** de [baseFilters] : chaque
  /// [ZFilterGroup] est ANDé au reste, mais ses clauses sont en OR (« cette
  /// valeur **ou** ce champ absent »). [itemFilter] est le **post-filtre**
  /// d'écran : un prédicat écrit sur l'entité, appliqué aux entités lues avant
  /// qu'elles ne deviennent des lignes. Tous deux sont `null`/vides par défaut
  /// ⇒ comportement strictement inchangé.
  ///
  /// **Les déclarer impose la voie mémoire** : ni l'un ni l'autre ne se traduit
  /// en requête — le socle ne peut les appliquer que sur un jeu déjà lu. Le
  /// contrôleur lit alors le jeu **non paginé** à chaque requête, exactement
  /// comme le mode [ZListPaginationMode.inMemory], plutôt que de laisser une
  /// déclaration être silencieusement ignorée par la pagination curseur.
  ZListController({
    required this.repository,
    required this.toRow,
    required this.schema,
    this.pageSize,
    this.mode = ZListPaginationMode.backendCursor,
    this.baseFilters = const <ZFilter>[],
    this.baseFilterGroups = const <ZFilterGroup>[],
    this.itemFilter,
    this.searchScope = ZSearchScope.searchableFields,
    this.searchFolding = ZSearchFolding.diacritics,
    List<ZSort> initialSorts = const <ZSort>[],
    bool watchMutations = false,
  }) : _sorts = initialSorts {
    if (watchMutations) {
      _subscription = repository.watchAll().listen((_) {
        // Une mutation externe réinitialise la pagination et relance la requête.
        _resetPagination();
        unawaited(_runQuery());
      });
    }
    unawaited(_runQuery());
  }

  /// Source des données (port neutre, backend-agnostique).
  final ZRepository<T> repository;

  /// Projection `T → ZListRow` fournie par l'appelant (via `toMap`/`ZFieldSpec`).
  final ZListRow Function(T) toRow;

  /// Schéma des champs (source de `searchable` + moteur in-memory).
  final List<ZFieldSpec> schema;

  /// Taille de page (curseur), ou `null` (non paginé).
  final int? pageSize;

  /// Stratégie de pagination.
  final ZListPaginationMode mode;

  /// Socle de filtres **persistant** (relation parent / catégorie d'onglet),
  /// **toujours ANDé en tête** des filtres utilisateur dans chaque requête ; jamais
  /// écrasé par `setFilters`. Défaut `const []` ⇒ rétro-compatible.
  ///
  /// Une clause déclarée `ZFilter.servedBySource` y a sa place : elle voyage
  /// dans chaque requête, et le socle ne la rejoue pas sur les lignes — la
  /// voie d'un périmètre que seule la base sait trancher.
  final List<ZFilter> baseFilters;

  /// Socle de **disjonctions** persistantes, ANDées au reste dans chaque
  /// requête émise, chacune résolue en OR de ses clauses. Défaut `const []`
  /// ⇒ rétro-compatible.
  ///
  /// Sert la règle que la conjonction ne sait pas dire — « cette valeur **ou**
  /// ce champ absent », l'état initial d'un workflow. Un groupe **non inerte**
  /// impose la voie mémoire (voir le constructeur).
  final List<ZFilterGroup> baseFilterGroups;

  /// **Post-filtre** d'écran : dernier mot sur ce qui est listé, écrit sur
  /// l'entité `T` (`null` = aucun, défaut).
  ///
  /// Appliqué aux entités **lues**, après la lecture de la source et **avant**
  /// la projection en lignes, donc avant la recherche, le tri et la
  /// pagination : une page pleine reste pleine. Il ne peut que **restreindre**
  /// — une entité que la requête n'a pas ramenée ne peut pas réapparaître.
  ///
  /// Le déclarer impose la voie mémoire (voir le constructeur) : un prédicat
  /// Dart ne se traduit dans aucun langage de requête.
  final bool Function(T item)? itemFilter;

  /// **Domaine de colonnes** de la recherche, porté par chaque requête émise.
  /// Défaut [ZSearchScope.searchableFields] ⇒ rétro-compatible.
  final ZSearchScope searchScope;

  /// **Profondeur de normalisation** de la recherche, portée par chaque requête
  /// émise. Défaut [ZSearchFolding.diacritics] ⇒ rétro-compatible.
  final ZSearchFolding searchFolding;

  final ValueNotifier<ZListViewState> _state =
      ValueNotifier<ZListViewState>(const ZListLoading());

  /// Tranche réactive de l'état de vue (unique surface observée par l'UI).
  ValueListenable<ZListViewState> get state => _state;

  List<ZFilter> _filters = const <ZFilter>[];
  List<ZSort> _sorts;
  String? _search;

  final List<ZListRow> _accumulated = <ZListRow>[];
  ZCursor? _nextCursor;
  bool _hasMore = false;
  bool _isLoading = false;
  bool _disposed = false;
  StreamSubscription<List<T>>? _subscription;

  /// Compteur de génération de requête (garde anti-réponse-obsolète).
  ///
  /// Incrémenté à CHAQUE (re)lancement d'une requête (`setSearch`/`setFilters`/
  /// `setSort`/`refresh`/`loadMore`/mutation observée). Une requête capture la
  /// génération courante AVANT son `await` ; au retour, tout commit/émission est
  /// **rejeté** si la génération a changé entre-temps — une réponse en retard
  /// (search-as-you-type, réponses hors-ordre) n'écrase JAMAIS un état plus
  /// récent, et un `setX` survenu pendant un `loadMore` en vol ne laisse ni
  /// doublon ni trou dans l'accumulé (AD-16).
  int _generation = 0;

  /// `true` si une recherche est **réellement** active (terme non vide une
  /// fois les blancs retirés).
  bool get _hasActiveSearch => _search != null && _search!.trim().isNotEmpty;

  /// `true` si une recherche OU un filtre est actif (discriminant `empty` vs
  /// `noResults`) — signal **local et déterministe** (pas de comptage du
  /// jeu total).
  bool get _hasActiveQuery => _hasActiveSearch || _filters.isNotEmpty;

  /// Le dépôt **délègue-t-il** la recherche au moteur du socle ?
  ///
  /// Capacité **déclarée** par le dépôt lui-même ([ZDelegatesSearch]), jamais
  /// devinée d'après son type : le cœur ne connaît aucun de ses adaptateurs
  /// (AD-1). Lue une seule fois — la capacité d'un dépôt ne change pas en
  /// cours de vie.
  late final bool _delegatesSearch = !zRepositoryServesSearch(repository);

  /// La requête courante doit-elle être servie **en mémoire** faute d'un dépôt
  /// sachant chercher ?
  ///
  /// Vrai **seulement** quand une recherche est réellement active : sans
  /// terme, un dépôt qui ne sait pas chercher n'a rien à déléguer, et la
  /// pagination curseur reste le chemin nominal. C'est ce qui borne le coût de
  /// la bascule à la durée d'une recherche.
  bool get _searchNeedsMemory => _delegatesSearch && _hasActiveSearch;

  /// Le périmètre déclaré est-il **hors de portée d'une requête** ?
  ///
  /// Vrai dès qu'un post-filtre est déclaré ou qu'une disjonction non inerte
  /// est posée : ni l'un ni l'autre n'est garanti servi par la source. Le
  /// listing part alors en mémoire — pour toutes ses requêtes, celles-là mêmes
  /// que la pagination curseur aurait tronquées avant que la règle ne
  /// s'applique. C'est la seule façon qu'une déclaration ne soit jamais
  /// silencieusement ignorée.
  late final bool _postFilterNeedsMemory = itemFilter != null ||
      baseFilterGroups.any((group) => group.isNotEmpty);

  /// Remplace le terme de recherche, réinitialise la pagination et re-interroge.
  void setSearch(String? term) {
    _search = term;
    _resetPagination();
    unawaited(_runQuery());
  }

  /// Remplace les filtres, réinitialise la pagination et re-interroge.
  void setFilters(List<ZFilter> filters) {
    _filters = filters;
    _resetPagination();
    unawaited(_runQuery());
  }

  /// Remplace les clés de tri, réinitialise la pagination et re-interroge.
  void setSort(List<ZSort> sorts) {
    _sorts = sorts;
    _resetPagination();
    unawaited(_runQuery());
  }

  /// Charge la page suivante (si [state] indique `hasMore`), en **accumulant**
  /// les lignes. No-op s'il n'y a pas de page suivante ou si une requête est en
  /// cours.
  Future<void> loadMore() async {
    if (!_hasMore || _nextCursor == null || _isLoading) return;
    await _runQuery(startAfter: _nextCursor, append: true);
  }

  /// Relance la requête courante depuis la première page.
  Future<void> refresh() async {
    _resetPagination();
    await _runQuery();
  }

  void _resetPagination() {
    _accumulated.clear();
    _nextCursor = null;
    _hasMore = false;
  }

  ZDataRequest _buildRequest({ZCursor? startAfter}) => ZDataRequest(
        // Socle PERSISTANT en tête, filtres utilisateur ensuite : la
        // relation parent / catégorie d'onglet ne peut JAMAIS être écrasée par un
        // `setFilters` utilisateur. Point d'émission UNIQUE de toutes les requêtes
        // (première page + `loadMore`, chemin backend ET repli in-memory, qui
        // reçoit ce même `request`) ⇒ la composition est honorée partout.
        filters: baseFilters.isEmpty
            ? _filters
            : <ZFilter>[...baseFilters, ..._filters],
        // Les disjonctions déclarées voyagent dans la requête : un dépôt qui
        // sait les traduire y gagne, un dépôt qui les ignore ne perd rien —
        // le moteur du socle les applique de toute façon en mémoire.
        filterGroups: baseFilterGroups,
        sorts: _sorts,
        search: _search,
        limit: pageSize,
        startAfter: startAfter,
        searchScope: searchScope,
        searchFolding: searchFolding,
      );

  Future<void> _runQuery({ZCursor? startAfter, bool append = false}) async {
    // Estampille cette requête : toute réponse en retard sera rejetée si une
    // requête plus récente a été lancée entre-temps (garde anti-réponse-obsolète).
    final gen = ++_generation;
    _isLoading = true;
    if (!append) _emit(const ZListLoading());
    final request = _buildRequest(startAfter: startAfter);

    // Trois raisons d'aller en mémoire, et une seule mécanique : le mode
    // déclaré, une recherche active que le dépôt ne sait pas servir, ou un
    // périmètre déclaré hors de portée d'une requête (post-filtre,
    // disjonction). Dans le deuxième cas la bascule dure ce que dure la
    // recherche — le terme effacé ramène la voie curseur ; dans le troisième
    // elle dure ce que dure le listing, puisque la déclaration, elle, ne
    // s'efface pas.
    if (mode == ZListPaginationMode.inMemory ||
        _searchNeedsMemory ||
        _postFilterNeedsMemory) {
      await _runInMemory(request, gen, append: append);
      return;
    }

    final result = await repository.getAll(request: request);
    // Réponse obsolète (nouvelle requête lancée pendant l'await) OU disposé →
    // ne rien committer/émettre (n'écrase pas un état plus récent).
    if (_disposed || gen != _generation) return;
    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse(() => const ZServerFailure('échec inconnu'));
      // Un échec sur une requête PORTANT un curseur est interprété comme un
      // curseur non honoré → repli in-memory (AD-16), pas d'erreur fatale. Un
      // échec sur la première page (sans curseur) est une vraie erreur.
      if (request.startAfter != null) {
        await _runInMemory(request, gen, append: append);
        return;
      }
      _isLoading = false;
      _emit(ZListError(failure));
      return;
    }
    final items = result.getOrElse(() => const <Never>[]);
    final rows = <ZListRow>[for (final item in items) toRow(item)];
    _commitBackendPage(rows, request, append: append);
  }

  /// Repli in-memory (AD-16) : récupère le jeu **non paginé et non trié** puis
  /// ordonne et pagine via [zApplyListRequest]. Sert le mode
  /// [ZListPaginationMode.inMemory] ET le repli sur échec curseur du mode
  /// [ZListPaginationMode.backendCursor].
  ///
  /// **Ce que la lecture ne demande pas** : ni page (`limit`/`startAfter`), ni
  /// **tri**. Le jeu est lu entier avant d'être ordonné — un tri servi par la
  /// source n'apporterait donc aucun ordre au rendu, puisque le moteur du
  /// socle ré-ordonne de toute façon. Il ne resterait de lui que ses effets de
  /// bord : sur un backend documentaire, un ordre serveur **exclut** les
  /// documents dépourvus du champ trié, et un listing trié sur une date
  /// facultative perdait ainsi, en silence, tous ses éléments non datés. La
  /// requête part donc sans tri, et l'ordre demandé est rendu par
  /// [zApplyListRequest], qui **classe** les valeurs absentes au lieu de les
  /// retrancher.
  Future<void> _runInMemory(
    ZDataRequest request,
    int gen, {
    required bool append,
  }) async {
    final unpaged = request.copyWith(
      limit: null,
      startAfter: null,
      sorts: const <ZSort>[],
    );
    final result = await repository.getAll(request: unpaged);
    // Réponse obsolète OU disposé → aucun commit/émission.
    if (_disposed || gen != _generation) return;
    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse(() => const ZServerFailure('échec inconnu'));
      _isLoading = false;
      _emit(ZListError(failure));
      return;
    }
    final items = result.getOrElse(() => const <Never>[]);
    // Post-filtre AVANT la projection : la règle est écrite sur l'entité, et
    // ce qu'elle écarte ne devient jamais une ligne (donc n'entre ni dans la
    // recherche, ni dans le tri, ni dans le comptage d'une page).
    final filter = itemFilter;
    final kept = filter == null
        ? items
        : <T>[
            for (final item in items)
              if (filter(item)) item,
          ];
    final allRows = <ZListRow>[for (final item in kept) toRow(item)];
    // Le moteur applique filtres/recherche/tri/curseur/limit de façon
    // idempotente (une re-application sur un jeu déjà filtré donne le même
    // résultat) ; startAfter reprend le curseur accumulé sur un loadMore.
    final page = zApplyListRequest(
      allRows,
      request.copyWith(startAfter: append ? _nextCursor : null),
      schema: schema,
    );
    _commitPage(page.rows, page.nextCursor, page.hasMore, append: append);
  }

  /// Commit d'une page **backend** : dérive `nextCursor`/`hasMore` de la page
  /// reçue (heuristique : `rows.length >= pageSize` ⇒ page pleine ⇒ suivante
  /// probable).
  ///
  /// Limite bénigne, documentée : quand la taille totale du jeu est un **multiple
  /// exact** de `pageSize`, la dernière page pleine laisse `hasMore == true`, si
  /// bien qu'un `loadMore` supplémentaire ramène une page **vide** qui remet
  /// `hasMore` à `false` sans doublon ni trou (accumulé inchangé). Ce coût — une
  /// seule requête backend « à blanc » — est **inhérent** à la pagination
  /// curseur sans `count()` : trancher `hasMore` avec certitude exigerait un
  /// surcoût backend (sonde `limit + 1` ou `count()`), laissé à l'adaptateur
  /// backend. Ici : correction gracieuse, jamais de dé-synchronisation.
  void _commitBackendPage(
    List<ZListRow> rows,
    ZDataRequest request, {
    required bool append,
  }) {
    final limit = request.limit;
    final hasMore = limit != null && rows.isNotEmpty && rows.length >= limit;
    final next = hasMore ? zDeriveCursor(rows.last, request.sorts) : null;
    _commitPage(rows, next, hasMore, append: append);
  }

  void _commitPage(
    List<ZListRow> rows,
    ZCursor? nextCursor,
    bool hasMore, {
    required bool append,
  }) {
    if (append) {
      _accumulated.addAll(rows);
    } else {
      _accumulated
        ..clear()
        ..addAll(rows);
    }
    _nextCursor = nextCursor;
    _hasMore = hasMore;
    _isLoading = false;
    _emit(_mapState());
  }

  /// Mappe l'état accumulé → `ZListViewState` : non vide → `ZListReady` ;
  /// vide + requête active → `ZListNoResults` ; vide sans requête → `ZListEmpty`.
  ZListViewState _mapState() {
    if (_accumulated.isNotEmpty) {
      return ZListReady(List<ZListRow>.unmodifiable(_accumulated));
    }
    return _hasActiveQuery ? const ZListNoResults() : const ZListEmpty();
  }

  void _emit(ZListViewState next) {
    if (_disposed) return;
    _state.value = next;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _state.dispose();
    super.dispose();
  }
}
