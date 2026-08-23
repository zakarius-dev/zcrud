/// Dépôt **mémoire** de routeurs — `ZChatInMemoryRouterRepository`
/// (invariants AD-5, AD-11, AD-14, AD-16).
///
/// Un `ZRepository<ZChatRouter>` complet sans backend : le dépôt d'un test,
/// d'une démonstration, d'un hôte qui administre ses routeurs localement, ou
/// la source d'un `ZChatRepositoryRouteCatalogSource`. Sa sémantique est
/// celle d'un adaptateur documentaire : l'éphémère reçoit une identité à
/// l'écriture, le soft-delete est **hors entité** et rend l'élément invisible
/// en portée `aliveOnly`, `getById` sur un absent ou un supprimé rend
/// `Left(ZNotFoundFailure)`, les lectures à `ZDataRequest` honorent la
/// portée de suppression, les filtres, les tris et la limite.
///
/// Il **délègue la recherche** (`ZDelegatesSearch`) : `ZDataRequest.search`
/// n'est pas servi ici, un écran de liste filtre en mémoire.
library;

import 'dart:async';

import 'package:zcrud_core/domain.dart';

import '../z_chat_router.dart';

/// Fabrique d'identité pour un routeur éphémère.
typedef ZChatRouterIdGenerator = String Function();

class _Slot {
  _Slot(this.router, {required this.isDeleted, required this.updatedAt});
  ZChatRouter router;
  bool isDeleted;
  DateTime updatedAt;
}

/// Dépôt de routeurs en mémoire, à sémantique documentaire.
class ZChatInMemoryRouterRepository extends ZRepository<ZChatRouter>
    with ZDelegatesSearch<ZChatRouter> {
  /// Construit le dépôt, pré-rempli par [seed] (les éphémères y reçoivent
  /// une identité). [idGenerator] nomme les éphémères ; [clock] date les
  /// écritures.
  ZChatInMemoryRouterRepository({
    Iterable<ZChatRouter> seed = const <ZChatRouter>[],
    ZChatRouterIdGenerator? idGenerator,
    ZClock clock = ZSystemClock.utc,
  }) : _nextId = idGenerator ?? _sequential(),
       // ignore: prefer_initializing_formals
       _clock = clock {
    for (final ZChatRouter r in seed) {
      _put(r);
    }
  }

  final ZChatRouterIdGenerator _nextId;
  final ZClock _clock;
  final Map<String, _Slot> _slots = <String, _Slot>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static ZChatRouterIdGenerator _sequential() {
    int n = 0;
    return () => 'router-${++n}';
  }

  ZChatRouter _put(ZChatRouter router) {
    final String id = router.id ?? _nextId();
    final ZChatRouter stored = router.id == id
        ? router
        : router.copyWith(id: id);
    _slots[id] = _Slot(stored, isDeleted: false, updatedAt: _clock());
    return stored;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  /// Soft-delete du routeur [id] tel qu'il est **porté** (`null` si absent).
  bool? isDeleted(String id) => _slots[id]?.isDeleted;

  /// Date de la dernière écriture de [id], ou `null`.
  DateTime? updatedAt(String id) => _slots[id]?.updatedAt;

  List<ZChatRouter> _query(ZDataRequest request) {
    final List<ZChatRouter> out = <ZChatRouter>[];
    for (final _Slot s in _slots.values) {
      if (!_inScope(s, request.deletedScope)) continue;
      final Map<String, dynamic> doc = s.router.toMap();
      if (!request.filters.every((ZFilter f) => _matches(doc, f))) continue;
      if (!request.filterGroups.every(
        (ZFilterGroup g) =>
            g.isEmpty || g.clauses.any((ZFilter f) => _matches(doc, f)),
      )) {
        continue;
      }
      out.add(s.router);
    }
    if (request.sorts.isNotEmpty) {
      out.sort((ZChatRouter a, ZChatRouter b) {
        final Map<String, dynamic> da = a.toMap();
        final Map<String, dynamic> db = b.toMap();
        for (final ZSort sort in request.sorts) {
          final int c = _compare(da[sort.field], db[sort.field]);
          if (c != 0) return sort.direction == ZSortDirection.desc ? -c : c;
        }
        return 0;
      });
    }
    final int? limit = request.limit;
    if (limit != null && limit >= 0 && out.length > limit) {
      return out.sublist(0, limit);
    }
    return out;
  }

  static bool _inScope(_Slot s, ZDeletedScope scope) => switch (scope) {
    ZDeletedScope.aliveOnly => !s.isDeleted,
    ZDeletedScope.deletedOnly => s.isDeleted,
    ZDeletedScope.includeDeleted => true,
  };

  static bool _matches(Map<String, dynamic> doc, ZFilter f) {
    final Object? v = doc[f.field];
    return switch (f.op) {
      ZFilterOp.eq => v == f.value,
      ZFilterOp.neq => v != f.value,
      ZFilterOp.isIn => f.value is List && (f.value! as List).contains(v),
      ZFilterOp.isNull => v == null,
      ZFilterOp.contains =>
        v is List ? v.contains(f.value) : '$v'.contains('${f.value}'),
      ZFilterOp.lt => _compare(v, f.value) < 0,
      ZFilterOp.lte => _compare(v, f.value) <= 0,
      ZFilterOp.gt => _compare(v, f.value) > 0,
      ZFilterOp.gte => _compare(v, f.value) >= 0,
    };
  }

  static int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is Comparable && a.runtimeType == b.runtimeType) {
      return a.compareTo(b);
    }
    return '$a'.compareTo('$b');
  }

  @override
  Stream<List<ZChatRouter>> watchAll() => watch(const ZDataRequest());

  /// Flux à **seed immédiat** à l'abonnement, puis une émission par
  /// mutation du dépôt.
  @override
  Stream<List<ZChatRouter>> watch(ZDataRequest request) {
    late final StreamController<List<ZChatRouter>> out;
    StreamSubscription<void>? sub;
    out = StreamController<List<ZChatRouter>>(
      onListen: () {
        out.add(_query(request));
        sub = _changes.stream.listen((void _) => out.add(_query(request)));
      },
      onCancel: () async {
        await sub?.cancel();
        sub = null;
      },
    );
    return out.stream;
  }

  @override
  Future<ZResult<List<ZChatRouter>>> getAll({ZDataRequest? request}) async =>
      Right<ZFailure, List<ZChatRouter>>(
        List<ZChatRouter>.unmodifiable(_query(request ?? const ZDataRequest())),
      );

  @override
  Future<ZResult<ZChatRouter>> getById(String id) async {
    final _Slot? s = _slots[id];
    if (s == null || s.isDeleted) {
      return Left<ZFailure, ZChatRouter>(
        ZNotFoundFailure('router not found', id: id, entity: kZChatRouterKind),
      );
    }
    return Right<ZFailure, ZChatRouter>(s.router);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right<ZFailure, int>(_query(request ?? const ZDataRequest()).length);

  /// Écrit [item] : un éphémère reçoit une identité ; une identité en
  /// corbeille est **ravivée**. [collectionId] est ignoré (une seule
  /// collection).
  @override
  Future<ZResult<ZChatRouter>> save(
    ZChatRouter item, {
    String? collectionId,
  }) async {
    final ZChatRouter stored = _put(item);
    _notify();
    return Right<ZFailure, ZChatRouter>(stored);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async => _flag(id, deleted: true);

  @override
  Future<ZResult<Unit>> restore(String id) async => _flag(id, deleted: false);

  Future<ZResult<Unit>> _flag(String id, {required bool deleted}) async {
    final _Slot? s = _slots[id];
    if (s == null) {
      return Left<ZFailure, Unit>(
        ZNotFoundFailure('router not found', id: id, entity: kZChatRouterKind),
      );
    }
    s
      ..isDeleted = deleted
      ..updatedAt = _clock();
    _notify();
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() {
    _changes.close();
  }
}
