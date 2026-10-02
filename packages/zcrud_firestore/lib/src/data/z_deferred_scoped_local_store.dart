/// Store local dont la box n'est ouverte qu'au premier usage, pour un scope
/// connu plus tard (après l'authentification).
///
/// Un scope absent ne retombe pas sur la box non cloisonnée : les lectures
/// sont vides et les écritures sont refusées. Un changement de scope ferme
/// la box précédente avant d'en ouvrir une autre. Les ouvertures d'un même
/// nom sont sérialisées, parce que la fermeture Hive rend la main avant le
/// retrait du registre.
///
/// [dispose] ferme les box que ce store a ouvertes. Il ne faut pas lui
/// passer un store partagé : le dépôt qui reçoit ce store appelle [dispose].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'hive_z_local_store.dart';

/// Ouvre une box cloisonnée à la demande.
class ZDeferredScopedLocalStore<T extends ZEntity> implements ZLocalStore<T> {
  /// [scope] est lu à chaque opération. [open] doit rendre un store que
  /// cette instance possède (elle le fermera).
  // Le paramètre public s'appelle `open` ; le champ reste privé.
  // ignore: prefer_initializing_formals
  ZDeferredScopedLocalStore({
    required this.kind,
    required this.scope,
    required Future<ZLocalStore<T>> Function(String scope) open,
  }) : _open = open {
    scope.addListener(_onScope);
  }

  /// Discriminant de collection.
  final String kind;

  /// Scope courant. `null` ou vide : aucune box.
  final ValueListenable<String?> scope;

  final Future<ZLocalStore<T>> Function(String scope) _open;
  ZLocalStore<T>? _inner;
  String? _innerScope;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  void _onScope() {
    unawaited(_ready());
  }

  Future<ZLocalStore<T>?> _ready() {
    final Completer<ZLocalStore<T>?> done = Completer<ZLocalStore<T>?>();
    _tail = _tail.then((_) async {
      if (_disposed) {
        done.complete(null);
        return;
      }
      final String? next = scope.value;
      if (next == null || next.isEmpty) {
        await _drop();
        done.complete(null);
        return;
      }
      if (_inner != null && _innerScope == next) {
        done.complete(_inner);
        return;
      }
      await _drop();
      final String name = HiveZLocalStore.boxNameFor(kind, scope: next);
      var spins = 0;
      while (Hive.isBoxOpen(name) && spins < 50) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        spins++;
      }
      _inner = await _open(next);
      _innerScope = next;
      done.complete(_inner);
    });
    return done.future;
  }

  Future<void> _drop() async {
    final ZLocalStore<T>? previous = _inner;
    final String? name = _innerScope == null
        ? null
        : HiveZLocalStore.boxNameFor(kind, scope: _innerScope);
    _inner = null;
    _innerScope = null;
    previous?.dispose();
    if (name == null) return;
    var spins = 0;
    while (Hive.isBoxOpen(name) && spins < 50) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      spins++;
    }
  }

  Future<ZResult<R>> _withStore<R>(
    Future<ZResult<R>> Function(ZLocalStore<T> store) action,
    ZResult<R> Function() ifAbsent,
  ) async {
    final ZLocalStore<T>? store = await _ready();
    if (store == null) return ifAbsent();
    return action(store);
  }

  @override
  Stream<List<T>> watchAll() {
    // Le flux suit la box courante. Un scope absent émet une liste vide.
    return Stream<List<T>>.multi((MultiStreamController<List<T>> controller) {
      StreamSubscription<List<T>>? innerSub;
      void listen() {
        unawaited(innerSub?.cancel());
        innerSub = null;
        unawaited(
          _ready().then((ZLocalStore<T>? store) {
            if (controller.isClosed) return;
            if (store == null) {
              controller.add(<T>[]);
              return;
            }
            innerSub = store.watchAll().listen(
              controller.add,
              onError: controller.addError,
            );
          }),
        );
      }

      listen();
      scope.addListener(listen);
      controller.onCancel = () async {
        scope.removeListener(listen);
        await innerSub?.cancel();
      };
    });
  }

  @override
  Future<ZResult<List<T>>> getAll() => _withStore(
    (ZLocalStore<T> store) => store.getAll(),
    () => Right<ZFailure, List<T>>(<T>[]),
  );

  @override
  Future<ZResult<T>> getById(String id) => _withStore(
    (ZLocalStore<T> store) => store.getById(id),
    () => Left<ZFailure, T>(
      ZNotFoundFailure('signed out', id: id, entity: kind),
    ),
  );

  @override
  Future<ZResult<T>> put(T item) => _withStore(
    (ZLocalStore<T> store) => store.put(item),
    () => Left<ZFailure, T>(
      ZDomainFailure('signed out: refusing to open the unscoped box'),
    ),
  );

  @override
  Future<ZResult<T>> putMerged(T item) => _withStore(
    (ZLocalStore<T> store) => store.putMerged(item),
    () => Left<ZFailure, T>(
      ZDomainFailure('signed out: refusing to open the unscoped box'),
    ),
  );

  @override
  Future<ZResult<Unit>> softDelete(String id) => _withStore(
    (ZLocalStore<T> store) => store.softDelete(id),
    () => const Left<ZFailure, Unit>(
      ZDomainFailure('signed out: refusing to open the unscoped box'),
    ),
  );

  @override
  Future<ZResult<Unit>> restore(String id) => _withStore(
    (ZLocalStore<T> store) => store.restore(id),
    () => const Left<ZFailure, Unit>(
      ZDomainFailure('signed out: refusing to open the unscoped box'),
    ),
  );

  @override
  Future<ZResult<List<ZSyncEntry<T>>>> syncEntries() => _withStore(
    (ZLocalStore<T> store) => store.syncEntries(),
    () => Right<ZFailure, List<ZSyncEntry<T>>>(<ZSyncEntry<T>>[]),
  );

  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<T> entry) => _withStore(
    (ZLocalStore<T> store) => store.applyMerged(entry),
    () => const Left<ZFailure, Unit>(
      ZDomainFailure('signed out: refusing to open the unscoped box'),
    ),
  );

  @override
  Future<ZResult<Unit>> purge(String id) => _withStore(
    (ZLocalStore<T> store) => store.purge(id),
    () => const Right<ZFailure, Unit>(unit),
  );

  @override
  Future<ZResult<Unit>> clear() => _withStore(
    (ZLocalStore<T> store) => store.clear(),
    () => const Right<ZFailure, Unit>(unit),
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    scope.removeListener(_onScope);
    final ZLocalStore<T>? previous = _inner;
    _inner = null;
    previous?.dispose();
  }
}
