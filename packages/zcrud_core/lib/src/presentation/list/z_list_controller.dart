/// Contrôleur de liste **Flutter-natif** du cœur `zcrud_core` (E4-3).
///
/// origine: E4-3 (recherche/filtre/tri/pagination, FR-6..FR-8 · AD-2/AD-11/
/// AD-15/AD-16). Pendant `DynamicList` de `ZFormController` (E2-7) : réactivité
/// **Flutter-native** exposant une **unique tranche** `ValueListenable<
/// ZListViewState>` — AUCUN gestionnaire d'état (ni `zcrud_list`/Syncfusion). Le
/// code manager-spécifique vit dans les bindings (`zcrud_riverpod`/`zcrud_get`),
/// jamais ici.
///
/// Le contrôleur détient le `ZDataRequest` courant (filtres/tri/recherche),
/// pousse la requête au [ZRepository] (chemin backend curseur) OU pagine
/// **entièrement en mémoire** (repli AD-16), projette `T → ZListRow` via le seam
/// [toRow], et mappe le résultat en `ZListViewState` (dont la décision `empty`
/// vs `noResults`, tranchée ici — déférée d'E4-2).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/contracts/z_entity.dart';
import '../../domain/data/z_cursor.dart';
import '../../domain/data/z_data_request.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/failures/z_failure.dart';
import '../../domain/ports/z_repository.dart';
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
///   [zApplyListRequest].
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
/// value)` (réutilise les vues d'états d'E4-2).
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
  /// **additif et rétro-compatible** — E4-5) : ces filtres sont **toujours ANDés
  /// EN TÊTE** des filtres utilisateur dans CHAQUE requête émise (première page,
  /// `loadMore`, chemin backend ET repli in-memory). Ils expriment une **relation
  /// parent→enfants** (`ZSubListScreen`, `ZFilter(parentField, eq, parentId)`) ou
  /// un **filtre de catégorie d'onglet** (`ZTabbedList`) : `setFilters`/`setSearch`
  /// /`setSort` **ne peuvent JAMAIS** les écraser (là où `setFilters` remplace les
  /// SEULS filtres utilisateur). `baseFilters` vide ⇒ comportement E4-3 strictement
  /// inchangé (mêmes `ZDataRequest`, mêmes tests).
  ZListController({
    required this.repository,
    required this.toRow,
    required this.schema,
    this.pageSize,
    this.mode = ZListPaginationMode.backendCursor,
    this.baseFilters = const <ZFilter>[],
    bool watchMutations = false,
  }) {
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

  /// Socle de filtres **persistant** (relation parent / catégorie d'onglet, E4-5),
  /// **toujours ANDé en tête** des filtres utilisateur dans chaque requête ; jamais
  /// écrasé par `setFilters`. Défaut `const []` ⇒ rétro-compatible E4-3.
  final List<ZFilter> baseFilters;

  final ValueNotifier<ZListViewState> _state =
      ValueNotifier<ZListViewState>(const ZListLoading());

  /// Tranche réactive de l'état de vue (unique surface observée par l'UI).
  ValueListenable<ZListViewState> get state => _state;

  List<ZFilter> _filters = const <ZFilter>[];
  List<ZSort> _sorts = const <ZSort>[];
  String? _search;

  final List<ZListRow> _accumulated = <ZListRow>[];
  ZCursor? _nextCursor;
  bool _hasMore = false;
  bool _isLoading = false;
  bool _disposed = false;
  StreamSubscription<List<T>>? _subscription;

  /// Compteur de génération de requête (garde anti-réponse-obsolète, M-1).
  ///
  /// Incrémenté à CHAQUE (re)lancement d'une requête (`setSearch`/`setFilters`/
  /// `setSort`/`refresh`/`loadMore`/mutation observée). Une requête capture la
  /// génération courante AVANT son `await` ; au retour, tout commit/émission est
  /// **rejeté** si la génération a changé entre-temps — une réponse en retard
  /// (search-as-you-type, réponses hors-ordre) n'écrase JAMAIS un état plus
  /// récent, et un `setX` survenu pendant un `loadMore` en vol ne laisse ni
  /// doublon ni trou dans l'accumulé (AC5, AD-16).
  int _generation = 0;

  /// `true` si une recherche OU un filtre est actif (discriminant `empty` vs
  /// `noResults`, AC8) — signal **local et déterministe** (pas de comptage du
  /// jeu total).
  bool get _hasActiveQuery =>
      (_search != null && _search!.trim().isNotEmpty) || _filters.isNotEmpty;

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
        // Socle PERSISTANT en tête, filtres utilisateur ensuite (E4-5) : la
        // relation parent / catégorie d'onglet ne peut JAMAIS être écrasée par un
        // `setFilters` utilisateur. Point d'émission UNIQUE de toutes les requêtes
        // (première page + `loadMore`, chemin backend ET repli in-memory, qui
        // reçoit ce même `request`) ⇒ la composition est honorée partout.
        filters: baseFilters.isEmpty
            ? _filters
            : <ZFilter>[...baseFilters, ..._filters],
        sorts: _sorts,
        search: _search,
        limit: pageSize,
        startAfter: startAfter,
      );

  Future<void> _runQuery({ZCursor? startAfter, bool append = false}) async {
    // Estampille cette requête : toute réponse en retard sera rejetée si une
    // requête plus récente a été lancée entre-temps (garde M-1).
    final gen = ++_generation;
    _isLoading = true;
    if (!append) _emit(const ZListLoading());
    final request = _buildRequest(startAfter: startAfter);

    if (mode == ZListPaginationMode.inMemory) {
      await _runInMemory(request, gen, append: append);
      return;
    }

    final result = await repository.getAll(request: request);
    // Réponse obsolète (nouvelle requête lancée pendant l'await) OU disposé →
    // ne rien committer/émettre (n'écrase pas un état plus récent, M-1).
    if (_disposed || gen != _generation) return;
    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse(() => const ServerFailure('échec inconnu'));
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

  /// Repli in-memory (AD-16) : récupère le jeu **non paginé** puis pagine via
  /// [zApplyListRequest]. Sert le mode [ZListPaginationMode.inMemory] ET le
  /// repli sur échec curseur du mode [ZListPaginationMode.backendCursor].
  Future<void> _runInMemory(
    ZDataRequest request,
    int gen, {
    required bool append,
  }) async {
    final unpaged = request.copyWith(limit: null, startAfter: null);
    final result = await repository.getAll(request: unpaged);
    // Réponse obsolète OU disposé → aucun commit/émission (garde M-1).
    if (_disposed || gen != _generation) return;
    if (result.isLeft()) {
      final failure =
          result.swap().getOrElse(() => const ServerFailure('échec inconnu'));
      _isLoading = false;
      _emit(ZListError(failure));
      return;
    }
    final items = result.getOrElse(() => const <Never>[]);
    final allRows = <ZListRow>[for (final item in items) toRow(item)];
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
  /// L-1 (bénin, documenté) : quand la taille totale du jeu est un **multiple
  /// exact** de `pageSize`, la dernière page pleine laisse `hasMore == true`, si
  /// bien qu'un `loadMore` supplémentaire ramène une page **vide** qui remet
  /// `hasMore` à `false` sans doublon ni trou (accumulé inchangé). Ce coût — une
  /// seule requête backend « à blanc » — est **inhérent** à la pagination
  /// curseur sans `count()` : trancher `hasMore` avec certitude exigerait un
  /// surcoût backend (sonde `limit + 1` ou `count()`), déféré à l'adaptateur
  /// Firestore (E5). Ici : correction gracieuse, jamais de dé-synchronisation.
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

  /// Mappe l'état accumulé → `ZListViewState` (AC8) : non vide → `ZListReady` ;
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
