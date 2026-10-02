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
    this.unsignedReadsAreEmpty = true,
  }) : _open = open {
    scope.addListener(_onScope);
  }

  /// Discriminant de collection.
  final String kind;

  /// Scope courant. `null` ou vide : aucune box.
  final ValueListenable<String?> scope;

  /// `true` : une lecture sans scope rend une liste vide. `false` : le
  /// contenu est inconnu — les lectures uniques échouent, le flux n'émet
  /// rien.
  final bool unsignedReadsAreEmpty;

  final Future<ZLocalStore<T>> Function(String scope) _open;
  ZLocalStore<T>? _inner;
  String? _innerScope;
  Object? _openError;
  Future<void> _tail = Future<void>.value();
  bool _disposed = false;

  static final Map<String, _ZDeferredBoxShare> _shares =
      <String, _ZDeferredBoxShare>{};
  static final Map<String, Future<void>> _gates = <String, Future<void>>{};

  void _onScope() {
    unawaited(_ready());
  }

  Future<ZLocalStore<T>?> _ready() {
    final Completer<ZLocalStore<T>?> done = Completer<ZLocalStore<T>?>();
    _tail = _tail.catchError((Object _) {}).then((_) async {
      try {
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
        while (_gates.containsKey(name)) {
          await _gates[name];
        }
        final _ZDeferredBoxShare? shared = _shares[name];
        if (shared != null) {
          shared.users++;
          _inner = shared.store as ZLocalStore<T>;
          _innerScope = next;
          _openError = null;
          done.complete(_inner);
          return;
        }
        var spins = 0;
        while (Hive.isBoxOpen(name) && spins < 50) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          spins++;
        }
        final Completer<void> gate = Completer<void>();
        _gates[name] = gate.future;
        try {
          final ZLocalStore<T> opened = await _open(next);
          _shares[name] = _ZDeferredBoxShare(opened);
          _inner = opened;
          _innerScope = next;
          _openError = null;
          done.complete(opened);
        } catch (error) {
          _inner = null;
          _innerScope = null;
          _openError = error;
          done.complete(null);
        } finally {
          _gates.remove(name);
          if (!gate.isCompleted) gate.complete();
        }
      } catch (error) {
        _openError = error;
        if (!done.isCompleted) done.complete(null);
      }
    });
    return done.future;
  }

  Future<void> _drop() async {
    final String? name = _innerScope == null
        ? null
        : HiveZLocalStore.boxNameFor(kind, scope: _innerScope);
    _inner = null;
    _innerScope = null;
    if (name == null) return;
    final _ZDeferredBoxShare? share = _shares[name];
    if (share == null) return;
    share.users--;
    if (share.users > 0) return;
    _shares.remove(name);
    share.store.dispose();
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
    if (store == null) {
      if (_openError != null) {
        return Left<ZFailure, R>(
          ZCacheFailure('local box open failed: $_openError'),
        );
      }
      return ifAbsent();
    }
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
              if (unsignedReadsAreEmpty && _openError == null) {
                controller.add(<T>[]);
              }
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
    () => unsignedReadsAreEmpty
        ? Right<ZFailure, List<T>>(<T>[])
        : Left<ZFailure, List<T>>(
            const ZDomainFailure('signed out: the box content is unknown'),
          ),
  );

  @override
  Future<ZResult<T>> getById(String id) => _withStore(
    (ZLocalStore<T> store) => store.getById(id),
    () =>
        Left<ZFailure, T>(ZNotFoundFailure('signed out', id: id, entity: kind)),
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
    () => unsignedReadsAreEmpty
        ? Right<ZFailure, List<ZSyncEntry<T>>>(<ZSyncEntry<T>>[])
        : Left<ZFailure, List<ZSyncEntry<T>>>(
            const ZDomainFailure('signed out: the box content is unknown'),
          ),
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
    final String? name = _innerScope == null
        ? null
        : HiveZLocalStore.boxNameFor(kind, scope: _innerScope);
    _inner = null;
    _innerScope = null;
    if (name == null) return;
    final _ZDeferredBoxShare? share = _shares[name];
    if (share == null) return;
    share.users--;
    if (share.users > 0) return;
    _shares.remove(name);
    share.store.dispose();
  }
}

class _ZDeferredBoxShare {
  _ZDeferredBoxShare(this.store);

  final ZLocalStore<dynamic> store;
  int users = 1;
}
