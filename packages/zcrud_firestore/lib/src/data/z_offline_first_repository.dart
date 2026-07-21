/// Dépôt **offline-first** `ZOfflineFirstRepository<T>` (E5-3) : compose un store
/// LOCAL **autoritaire** ([ZLocalStore]) et un store DISTANT **best-effort**
/// ([ZRemoteStore]) derrière le sur-port [ZSyncableRepository].
///
/// origine: canonique §7 / AD-9 — patron offline-first standardisé : store local
/// source de vérité, distant fire-and-forget, merge **Last-Write-Wins** sur
/// `updatedAt` (tombstones inclus), soft-delete `is_deleted` **hors-entité**
/// ([ZSyncMeta]), propagation **bornée ≤ 450**. Le *quand* (débounce/multi-dépôts,
/// `ZSyncOrchestrator`) reste **E5-4** — ce dépôt n'expose qu'un [sync] one-shot.
///
/// **Composition, pas héritage** (AD-4) : ni `HiveZLocalStore` ni
/// `FirestoreZRemoteStore` ne sont sous-classés — seuls les **ports neutres** sont
/// injectés. **Isolation AD-5 (héritée E5-1/E5-2, re-vérifiée)** : ce fichier
/// n'importe **aucun** type `hive`/`cloud_firestore` ; toutes les signatures
/// publiques restent `ZResult<…>` / `Stream<List<T>>` **nues**.
///
/// **Frontière de story** : E5-3 = le *comment* (composition + merge LWW +
/// soft-delete propagé + lot ≤ 450 + `Right(unit)` si offline). E5-4 = le *quand*
/// (débounce ~400 ms, registre multi-dépôts, échec partiel toléré) — **hors** de
/// ce fichier.
library;

// `prefer_initializing_formals` : FAUX POSITIF (champ privé exposé en paramètre
// nommé — `this._x` interdit par Dart). Désactivé au niveau fichier comme E5-1/2.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:zcrud_core/zcrud_core.dart';

/// Journal minimal **neutre** du dépôt offline-first (aucune dépendance backend).
/// Un échec distant **best-effort** (assimilé à « offline ») est **loggé** ici
/// avant d'être avalé en `Right(unit)` — jamais silencieux (AD-11). Miroir de
/// `ZLocalStoreLog`/`ZFirestoreLog` (E5-2/E5-1).
typedef ZOfflineFirstLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Dépôt **offline-first** synchronisable pour l'agrégat [T].
///
/// **Injection** (aucun singleton — testabilité) : un [ZLocalStore] **autoritaire**,
/// un [ZRemoteStore] **best-effort**, un [ZLwwResolver] (défaut = résolveur
/// canonique `const ZLwwResolver()`), une couture de connectivité `isConnected`
/// **optionnelle** (défaut `null` — jamais court-circuitée), et un
/// [ZOfflineFirstLog] optionnel (défaut no-op).
class ZOfflineFirstRepository<T extends ZEntity>
    extends ZSyncableRepository<T> {
  /// Construit le dépôt par **composition** des deux stores + du résolveur LWW.
  ZOfflineFirstRepository({
    required ZLocalStore<T> local,
    required ZRemoteStore<T> remote,
    ZLwwResolver resolver = const ZLwwResolver(),
    Future<bool> Function()? isConnected,
    ZOfflineFirstLog? logger,
  })  : _local = local,
        _remote = remote,
        _resolver = resolver,
        _isConnected = isConnected,
        _log = logger ?? _noopLog;

  final ZLocalStore<T> _local;
  final ZRemoteStore<T> _remote;
  final ZLwwResolver _resolver;
  final Future<bool> Function()? _isConnected;
  final ZOfflineFirstLog _log;

  // ───────────────────────── Lectures = LOCAL source de vérité ────────────────
  //
  // AD-9 : le local **fait autorité** offline-first — les lectures ne touchent
  // JAMAIS le distant. Le port [ZLocalStore] n'expose pas de requête filtrée ;
  // le `request` est donc appliqué au **snapshot local visible** (le local
  // renvoie toutes les entités visibles — la traduction requête→backend local est
  // hors périmètre E5-3, qui porte la composition offline-first + le merge LWW).
  // Les tombstones (soft-deletés) sont exclus par le store local de façon
  // COHÉRENTE (get/getAll/watch), hérité E5-2.

  /// Message de dette EXPLICITE (MEDIUM-1) : le dépôt offline-first rend le
  /// **snapshot local complet** ; filtre/tri/pagination du [ZDataRequest] ne sont
  /// PAS traduits (le port [ZLocalStore] n'expose pas de requête). Le drop est
  /// tracé — jamais silencieux — pour être repris en E9 (traduction requête→cache).
  static const String _requestDroppedNote =
      'ZOfflineFirstRepository: request (filtre/tri/pagination) NON appliqué — '
      'snapshot local complet renvoyé (dette E9, voir code-review-e5-3).';

  @override
  Stream<List<T>> watchAll() => _local.watchAll();

  @override
  Stream<List<T>> watch(ZDataRequest request) {
    _log('$_requestDroppedNote [watch]');
    return _local.watchAll();
  }

  @override
  Future<ZResult<List<T>>> getAll({ZDataRequest? request}) {
    if (request != null) _log('$_requestDroppedNote [getAll]');
    return _local.getAll();
  }

  @override
  Future<ZResult<T>> getById(String id) => _local.getById(id);

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async {
    if (request != null) _log('$_requestDroppedNote [count]');
    final res = await _local.getAll();
    return res.map((list) => list.length);
  }

  // ───────────────────────── Écritures = LOCAL-first autoritaire ──────────────
  //
  // AD-9 : écrit d'ABORD au local (autoritaire), renvoie le résultat local DÈS
  // son succès ; propage ENSUITE au distant en **fire-and-forget** — un échec
  // distant est **loggé** et n'invalide JAMAIS le succès local.

  @override
  Future<ZResult<T>> save(T item, {String? collectionId}) async {
    final localRes = await _local.put(item);
    // AD-9 fire-and-forget STRICT : on renvoie le résultat local DÈS son succès,
    // SANS attendre la propagation distante (`unawaited`). Attendre le distant
    // bloquerait la méthode le temps d'un timeout réseau hors-ligne (MAJEUR-1).
    localRes.fold(
      (_) {}, // échec local : rien à propager (l'échec est renvoyé tel quel)
      (saved) => unawaited(_bestEffortRemote(
        () => _remote.push(saved),
        'save→push (id=${saved.id})',
      )),
    );
    return localRes;
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    final localRes = await _local.softDelete(id);
    localRes.fold(
      (_) {},
      (_) => unawaited(_bestEffortRemote(
        () => _remote.remoteDelete(id),
        'softDelete→remoteDelete (id=$id)',
      )),
    );
    return localRes;
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    final localRes = await _local.restore(id);
    // Propagation du restore : re-pousse l'entité restaurée (is_deleted=false)
    // au distant (best-effort, fire-and-forget). `push` réécrit is_deleted=false.
    localRes.fold(
      (_) {},
      (_) => unawaited(_propagateRestore(id)),
    );
    return localRes;
  }

  /// Propagation distante **fire-and-forget** d'un restore (best-effort) : relit
  /// l'entité restaurée localement puis la re-pousse. Toute erreur est avalée par
  /// [_bestEffortRemote] (le local reste autoritaire, AD-9).
  Future<void> _propagateRestore(String id) async {
    final entity = await _local.getById(id);
    await entity.fold(
      (_) async {}, // introuvable localement après restore : rien à pousser
      (e) => _bestEffortRemote(
        () => _remote.push(e),
        'restore→push (id=$id)',
      ),
    );
  }

  /// Exécute une opération distante **best-effort** : son `Left`/exception est
  /// **loggé** puis **avalé** (jamais propagé au résultat local). Le local reste
  /// la source de vérité (AD-9).
  Future<void> _bestEffortRemote(
    Future<ZResult<Object?>> Function() op,
    String label,
  ) async {
    try {
      final res = await op();
      res.leftMap((f) => _log('propagation distante best-effort échouée '
          '($label) : ${f.message}'));
    } on Object catch (e, s) {
      _log('propagation distante best-effort en exception ($label)',
          error: e, stackTrace: s);
    }
  }

  // ───────────────────────── sync() = pull one-shot + merge LWW ───────────────

  /// Synchronise **une fois** : pull des méta (tombstones inclus) des deux côtés,
  /// merge **Last-Write-Wins** via [ZLwwResolver], puis application des gagnants
  /// (distants adoptés localement via `applyMerged` ; locaux propagés par lot
  /// borné via `applyMergedAll`).
  ///
  /// **`Right(unit)` si déconnecté** (AD-9/AD-11) : `isConnected == false` OU un
  /// `Left(ZServerFailure)` distant est assimilé à « offline » → `Right(unit)`
  /// (loggé). Une **panne locale** (`Left(ZCacheFailure)` sur `syncEntries`/
  /// `applyMerged`) est une vraie erreur → `Left` (jamais avalée).
  @override
  Future<ZResult<Unit>> sync() async {
    // (0) Court-circuit connectivité (couture optionnelle) → Right(unit).
    final isConnected = _isConnected;
    if (isConnected != null && !await isConnected()) {
      _log('sync: hors-ligne (isConnected=false) — Right(unit) best-effort');
      return Right<ZFailure, Unit>(unit);
    }

    // (a) Lecture LOCALE : une erreur locale est une VRAIE panne → Left.
    final localRes = await _local.syncEntries();
    final localEntries = localRes.fold<List<ZSyncEntry<T>>?>(
      (_) => null,
      (r) => r,
    );
    if (localEntries == null) {
      return localRes.fold(
        (f) => Left<ZFailure, Unit>(f),
        (_) => Right<ZFailure, Unit>(unit), // inatteignable
      );
    }

    // (a') Lecture DISTANTE : une erreur distante = offline → Right(unit).
    final remoteRes = await _remote.syncEntries();
    final remoteEntries = remoteRes.fold<List<ZSyncEntry<T>>?>(
      (_) => null,
      (r) => r,
    );
    if (remoteEntries == null) {
      // MEDIUM-2 (dette E5-4 assumée) : un `Left` distant est assimilé à
      // « offline » → Right(unit). ⚠️ Ceci englobe AUSSI les erreurs NON
      // réseau (permission/quota/misconfig) : une telle sync « réussit » sans
      // jamais converger. Le drop est loggé en clair (jamais muet, AD-11) ;
      // la distinction réseau vs serveur (pour ne re-Right que le réseau) est
      // portée par E5-4 (`ZSyncOrchestrator` + typage connectivité).
      remoteRes.leftMap((f) => _log(
          'sync: pull distant en échec, assimilé offline → Right(unit) '
          'best-effort — ⚠️ inclut permission/quota (dette E5-4) : ${f.message}'));
      return Right<ZFailure, Unit>(unit);
    }

    // (b) Index par `id` + union déterministe (tri stable).
    final localById = <String, ZSyncEntry<T>>{
      for (final e in localEntries)
        if (e.id != null) e.id!: e,
    };
    final remoteById = <String, ZSyncEntry<T>>{
      for (final e in remoteEntries)
        if (e.id != null) e.id!: e,
    };
    final ids = <String>{...localById.keys, ...remoteById.keys}.toList()
      ..sort();

    // (c) Résolution + application : adopt local immédiat ; push accumulé.
    final toPush = <ZSyncEntry<T>>[];
    for (final id in ids) {
      final decision = _resolver.resolve<T>(localById[id], remoteById[id]);
      switch (decision.action) {
        case ZLwwAction.noop:
          break;
        case ZLwwAction.adoptRemoteIntoLocal:
          final applied = await _local.applyMerged(decision.entry!);
          // Panne locale à l'application → VRAIE erreur (Left, jamais avalée).
          final failed = applied.fold<ZFailure?>((f) => f, (_) => null);
          if (failed != null) return Left<ZFailure, Unit>(failed);
        case ZLwwAction.pushLocalToRemote:
          toPush.add(decision.entry!);
      }
    }

    // (d) Propagation distante bornée (best-effort : échec = offline → Right).
    if (toPush.isNotEmpty) {
      final pushed = await _remote.applyMergedAll(toPush);
      pushed.leftMap((f) => _log('sync: propagation distante échouée '
          '(${f.message}) — Right(unit) best-effort'));
    }

    return Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() {
    _local.dispose();
    _remote.dispose();
  }
}
