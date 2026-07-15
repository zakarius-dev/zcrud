/// `ZSyncOrchestrator` (E5-4) — **le *quand*** de l'offline-first, séparé du
/// **comment** (`ZSyncableRepository.sync()`, livré E5-3).
///
/// origine: canonique §7 / AD-9 — *« `ZSyncOrchestrator` (porte `StudySyncManager`,
/// keepAlive) : déclenche `sync()` d'un ensemble de repos enregistrés sur login +
/// reconnexion **débouncée**, best-effort (un échec n'arrête pas les autres) ;
/// sépare quand/comment ; gate par un flag d'activation. »*
///
/// **Frontière E5-3 (comment) vs E5-4 (quand)** — NON négociable :
/// - **E5-3** (immuable, jamais re-implémenté ici) : composition local+distant,
///   merge Last-Write-Wins, propagation soft-delete, lot borné ≤ 450,
///   `Right(unit)` si offline. C'est le **comment**, entièrement dans `sync()`.
/// - **E5-4** (ce fichier) : **registre** de dépôts, déclenchement **débouncé**
///   (login/reconnexion), **coalescence** des rafales, best-effort **tolérant à
///   l'échec partiel**, **gate** d'activation, couture connectivité. C'est le
///   **quand**. L'orchestrateur **n'appelle QUE** `repo.sync()` — jamais un store,
///   un `WriteBatch`, un `Box`, un `Timestamp`, ni la borne `450` (qui reste
///   **exclusivement** dans `zcrud_firestore`).
///
/// **Dette E5-3 (MEDIUM-2) réseau vs serveur — traitée au bon niveau.** La couture
/// [ZSyncOrchestrator.new.isConnected] est le **point d'injection de la vraie
/// source réseau de l'app** (le « login/reconnexion » du canonique) : un cycle ne
/// part que lorsque le réseau est réellement présent. Une **erreur serveur**
/// applicative (permission/quota) remontée par un dépôt en `Left(ServerFailure)`
/// est **comptée `failed` + loggée** dans [ZSyncRunReport] — **jamais** noyée
/// silencieusement en « offline ». La distinction fine par-dépôt réseau/serveur
/// (retourner `Left` sélectif sur permission/quota) nécessiterait un **changement
/// de contrat** de `sync()` et reste une **évolution future** — **hors** du
/// périmètre additif E5-4.
///
/// **AD-5/AD-15 (isolation) — pur-Dart strict** : ce fichier n'importe **aucun**
/// type backend (`hive`/`cloud_firestore`) ni gestionnaire d'état (`get`/
/// `flutter_riverpod`/`provider`) ni plugin connectivité (`connectivity_plus`)
/// **ni même Flutter** (`foundation`/`dart:ui`) — la couche `lib/src/domain` reste
/// PUR-DART (garde `domain_purity_test`). Seuls imports : `dart:async` (Timer),
/// `package:dartz` (Either/Right), et les types core (`ZSyncableRepository`,
/// `ZFailure`/`ZResult`, `ZSyncRunReport`). Les membres test-only ([registeredCount],
/// [flushPending]) sont documentés « test only » plutôt qu'annotés `@visibleForTesting`
/// (l'annotation vient de `package:meta`/`foundation`, exclus du domaine).
/// `pubspec.yaml` **inchangé**.
///
/// **Non-propriété des dépôts** : [ZSyncOrchestrator.dispose] annule le timer et
/// vide le registre, mais **ne dispose PAS** les `ZSyncableRepository` enregistrés
/// — leur cycle de vie appartient à l'app/binding (`StudySyncManager` keepAlive,
/// hors core).
library;

// `prefer_initializing_formals` : FAUX POSITIF (champ privé exposé en paramètre
// nommé — `this._x` interdit par Dart). Désactivé au niveau fichier comme E5-1/2/3.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dartz/dartz.dart' show Right;

import '../failures/z_failure.dart';
import '../ports/z_syncable_repository.dart';
import 'z_sync_run_report.dart';

/// Journal minimal **neutre** de l'orchestrateur (aucune dépendance backend).
/// Miroir **exact** de `ZOfflineFirstLog` (E5-3) : chaque échec de dépôt et
/// chaque cycle sauté est **loggé** (jamais `catch(_){}` muet — AD-11).
typedef ZSyncOrchestratorLog = void Function(
  String message, {
  Object? error,
  StackTrace? stackTrace,
});

void _noopLog(String message, {Object? error, StackTrace? stackTrace}) {}

/// Poignée **annulable** d'un déclenchement planifié — abstraction minimale
/// au-dessus d'un `Timer` de `dart:async`.
///
/// La **couture de fabrique** ([ZSyncTimerFactory]) permet aux tests d'injecter
/// une poignée **contrôlable** (capture `(durée, callback)`, `fire()` manuel)
/// afin de piloter le débounce **sans horloge murale** (aucun `Timer` réel ni
/// `Future.delayed` dans la suite de tests — objectif de testabilité E5-4).
abstract class ZCancelableTimer {
  /// Annule le déclenchement planifié : le callback ne sera **jamais** exécuté.
  void cancel();
}

/// Fabrique de [ZCancelableTimer] : reçoit une [duration] et un [callback]
/// **synchrone** (`void`), retourne une poignée annulable. Défaut =
/// [ZSyncOrchestrator] utilise un wrapper sur `Timer` de `dart:async`.
typedef ZSyncTimerFactory = ZCancelableTimer Function(
  Duration duration,
  void Function() callback,
);

/// Poignée par défaut : wrapper mince sur un `Timer` **réel** de `dart:async`.
class _RealCancelableTimer implements ZCancelableTimer {
  _RealCancelableTimer(Duration duration, void Function() callback)
      : _timer = Timer(duration, callback);

  final Timer _timer;

  @override
  void cancel() => _timer.cancel();
}

ZCancelableTimer _realTimerFactory(
  Duration duration,
  void Function() callback,
) =>
    _RealCancelableTimer(duration, callback);

/// Débounce par défaut du cadencement de synchronisation : **400 ms** (canonique
/// §7 « reconnexion débouncée 400 ms »). Surchargeable par le constructeur.
const Duration kZSyncDefaultDebounce = Duration(milliseconds: 400);

/// Orchestrateur de synchronisation offline-first : décide **quand** et **sur
/// quels dépôts** appeler `sync()`, sans jamais toucher au **comment** (E5-3).
///
/// **Cycle de vie** : instancier une fois (côté binding/app), [register] les
/// dépôts synchronisables, câbler [onLogin]/[onReconnected] sur les vraies
/// sources login/réseau de l'app, puis [dispose] à la fin. Voir aussi
/// [syncNow] (cycle immédiat non-débouncé) et [flushPending] (test only).
class ZSyncOrchestrator {
  /// Construit l'orchestrateur.
  ///
  /// - [debounce] : fenêtre de coalescence trailing (défaut [kZSyncDefaultDebounce]
  ///   = 400 ms). Plusieurs déclencheurs dans la fenêtre **réarment** le timer et
  ///   **coalescent** en **un seul** cycle.
  /// - [timerFactory] : couture de fabrique de timer (défaut = `Timer` réel de
  ///   `dart:async`). En test, injecter une fabrique **contrôlable** pour piloter
  ///   le débounce sans horloge murale.
  /// - [isConnected] : couture de connectivité **optionnelle** (défaut `null` →
  ///   jamais court-circuité, comme E5-3). Point d'injection de la **vraie** source
  ///   réseau de l'app. Quand présente et `false`, un cycle est **sauté** proprement.
  /// - [enabled] : gate d'activation (défaut `true`). `false` → aucun déclencheur
  ///   ne planifie, aucun cycle ne s'exécute.
  /// - [logger] : journal neutre (défaut no-op).
  ZSyncOrchestrator({
    Duration debounce = kZSyncDefaultDebounce,
    ZSyncTimerFactory? timerFactory,
    Future<bool> Function()? isConnected,
    bool enabled = true,
    ZSyncOrchestratorLog? logger,
  })  : _debounce = debounce,
        _timerFactory = timerFactory ?? _realTimerFactory,
        _isConnected = isConnected,
        _enabled = enabled,
        _log = logger ?? _noopLog;

  final Duration _debounce;
  final ZSyncTimerFactory _timerFactory;
  final Future<bool> Function()? _isConnected;
  final ZSyncOrchestratorLog _log;

  /// Journalisation **best-effort** : un logger injecté qui `throw` ne doit
  /// JAMAIS casser le cycle (l'orchestrateur est best-effort intégral, MEDIUM-1).
  /// Le catch est volontairement silencieux — le canal de log étant lui-même la
  /// défaillance, il n'existe aucune voie sûre pour le signaler.
  void _safeLog(String message, {Object? error, StackTrace? stackTrace}) {
    try {
      _log(message, error: error, stackTrace: stackTrace);
    } on Object {
      // Logger défaillant : rien d'autre à faire, on protège le cycle.
    }
  }

  /// Registre **par identité** : un même instance ré-`register` = no-op ; un dépôt
  /// n'est **jamais** synchronisé deux fois par cycle. Le type est le **sur-port
  /// neutre** `ZSyncableRepository` (générique effacé — l'orchestrateur n'a besoin
  /// que d'appeler `sync()`), jamais un adaptateur concret.
  final Set<ZSyncableRepository<dynamic>> _repos =
      <ZSyncableRepository<dynamic>>{};

  bool _enabled;
  bool _disposed = false;
  ZCancelableTimer? _pending;

  // ───────────────────────────── Registre ────────────────────────────────────

  /// Enregistre [repo] (idempotent par identité). No-op après [dispose].
  void register(ZSyncableRepository<dynamic> repo) {
    if (_disposed) return;
    _repos.add(repo);
  }

  /// Retire [repo] du registre (no-op s'il n'y était pas). No-op après [dispose].
  void unregister(ZSyncableRepository<dynamic> repo) {
    if (_disposed) return;
    _repos.remove(repo);
  }

  /// **ES-3.4 (FR-S15 / AD-20)** — injection en **LOT** de la **liste injectée**
  /// de dépôts synchronisables : enregistre **CHAQUE** dépôt de [repos].
  ///
  /// Miroir *first-class* de [register] pour une **liste** (le AC ES-3.4 exige
  /// que l'orchestrateur *« prend une liste injectée »*) : c'est le foyer nommé
  /// et testable de la **garde d'itération** — « aucun repo oublié ». Strictement
  /// **additif** : il **compose** [register] (n'introduit **aucune** seconde voie
  /// d'injection ni état), hérite donc de l'**idempotence par identité** (un même
  /// instance présent deux fois dans [repos] n'est enregistré qu'une fois) et du
  /// **no-op après [dispose]**. Pur-Dart (aucun import Flutter/backend).
  void registerAll(Iterable<ZSyncableRepository<dynamic>> repos) {
    if (_disposed) return;
    for (final repo in repos) {
      register(repo);
    }
  }

  /// **Test only** — nombre de dépôts actuellement enregistrés (lecture testable ;
  /// équivalent `@visibleForTesting`, l'annotation étant hors domaine pur-Dart).
  int get registeredCount => _repos.length;

  // ─────────────────────────── Gate d'activation ─────────────────────────────

  /// `true` si l'orchestrateur est actif (gate). Défaut `true`.
  bool get enabled => _enabled;

  /// (Dés)active l'orchestrateur. Passer à `false` **annule** un cycle en attente
  /// (le timer planifié est annulé) ; les déclencheurs suivants ne planifient rien
  /// tant que `false`. No-op après [dispose].
  set enabled(bool value) {
    if (_disposed) return;
    _enabled = value;
    if (!value) _cancelPending();
  }

  // ─────────────────────── Déclencheurs débouncés ────────────────────────────

  /// Déclencheur sémantique **login** — planifie un cycle débouncé.
  void onLogin() => _schedule();

  /// Déclencheur sémantique **reconnexion réseau** — planifie un cycle débouncé.
  void onReconnected() => _schedule();

  /// Planifie un cycle débouncé (trailing) : **annule** le timer courant et le
  /// **réarme** — plusieurs déclencheurs dans la fenêtre coalescent en **un seul**
  /// cycle, planifié [_debounce] après le **dernier** déclencheur. No-op si
  /// désactivé ou disposé.
  void _schedule() {
    if (_disposed || !_enabled) return;
    _cancelPending();
    _pending = _timerFactory(_debounce, () {
      _pending = null;
      // Voie débouncée = fire-and-forget : le rapport est **loggé** (résumé),
      // jamais retourné (le callback du timer est synchrone `void`).
      unawaited(_runCycleAndLog());
    });
  }

  void _cancelPending() {
    _pending?.cancel();
    _pending = null;
  }

  // ───────────────────────── Cycle immédiat / flush ──────────────────────────

  /// Exécute **immédiatement** (sans débounce) un cycle best-effort sur tous les
  /// dépôts enregistrés et retourne le [ZSyncRunReport] agrégé.
  ///
  /// Best-effort **intégral** : renvoie **`Right(report)`** même si des dépôts ont
  /// échoué (l'échec partiel est **dans** le rapport — `failed`/`failures` —, pas
  /// un `Left` global). Utile pour un login-forcé, un test, ou la donnée d'étude
  /// (E9). No-op inerte (report vide) après [dispose].
  Future<ZResult<ZSyncRunReport>> syncNow() async {
    final report = await _runCycle();
    return Right<ZFailure, ZSyncRunReport>(report);
  }

  /// **Test only** — exécute immédiatement le cycle **actuellement planifié** (le
  /// cas échéant) en annulant le timer en attente ; awaitable (pour observer le
  /// rapport). No-op si aucun cycle n'est armé, si désactivé ou disposé.
  ///
  /// Permet de piloter le débounce **sans** vrai `Timer` : le test déclenche
  /// [onLogin]/[onReconnected] (qui arment le timer), puis `flushPending()` force
  /// le cycle sans horloge murale.
  ///
  /// Équivalent `@visibleForTesting` (annotation hors domaine pur-Dart) — usage
  /// **strictement réservé aux tests**.
  Future<ZSyncRunReport> flushPending() async {
    if (_disposed || !_enabled) return const ZSyncRunReport.empty();
    if (_pending == null) return const ZSyncRunReport.empty();
    _cancelPending();
    return _runCycle();
  }

  // ──────────────────────── Cœur best-effort du cycle ────────────────────────

  Future<void> _runCycleAndLog() async {
    final report = await _runCycle();
    _safeLog(
      'sync: cycle terminé (attempted=${report.attempted}, '
      'succeeded=${report.succeeded}, failed=${report.failed})',
    );
  }

  /// Exécute un cycle best-effort **tolérant à l'échec partiel** :
  /// - gate `false` / disposé → cycle **sauté**, [ZSyncRunReport.empty].
  /// - `isConnected != null && !await isConnected()` → cycle **sauté** (loggé
  ///   « hors-ligne »), [ZSyncRunReport.empty] (miroir `Right(unit)` d'E5-3).
  /// - sinon itère une **copie** du registre (safe vs `unregister` concurrent) ;
  ///   **chaque** `repo.sync()` est isolé (`try/catch` + garde du `Left`) : un
  ///   `Left` **ou** une exception est **loggé + compté `failed`** et
  ///   **n'interrompt pas** la boucle. **Aucune** exception ne s'échappe.
  Future<ZSyncRunReport> _runCycle() async {
    if (_disposed || !_enabled) return const ZSyncRunReport.empty();

    final isConnected = _isConnected;
    if (isConnected != null) {
      bool connected;
      try {
        connected = await isConnected();
      } on Object catch (error, stackTrace) {
        // MEDIUM-1 : la couture réseau de l'app peut throw. Best-effort
        // intégral → on assimile à « hors-ligne » (cycle sauté), jamais
        // d'erreur async échappée (la voie débouncée est `unawaited`).
        _safeLog('sync: couture isConnected en exception — cycle sauté',
            error: error, stackTrace: stackTrace);
        return const ZSyncRunReport.empty();
      }
      if (!connected) {
        _safeLog('sync: hors-ligne — cycle sauté (aucun sync() déclenché)');
        return const ZSyncRunReport.empty();
      }
    }

    var succeeded = 0;
    var failed = 0;
    final failures = <ZFailure>[];

    // Copie défensive : sûr face à un register/unregister concurrent pendant
    // l'itération asynchrone.
    for (final repo in _repos.toList(growable: false)) {
      try {
        final result = await repo.sync();
        result.fold(
          (failure) {
            failed++;
            failures.add(failure);
            _safeLog('sync: dépôt en échec — ${failure.message}',
                error: failure);
          },
          (_) => succeeded++,
        );
      } on Object catch (error, stackTrace) {
        // AD-11 : jamais de `catch(_){}` muet — loggé + compté, boucle poursuivie.
        failed++;
        _safeLog(
          'sync: dépôt en exception',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    return ZSyncRunReport(
      attempted: succeeded + failed,
      succeeded: succeeded,
      failed: failed,
      failures: failures,
    );
  }

  // ──────────────────────────── Cycle de vie ─────────────────────────────────

  /// Rend l'orchestrateur **inerte** : annule tout timer en attente, vide le
  /// registre, et neutralise tout déclencheur/cycle ultérieur (idempotent).
  ///
  /// **Ne dispose PAS** les dépôts enregistrés — l'orchestrateur n'en est **pas
  /// propriétaire** (leur cycle de vie appartient à l'app/binding).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelPending();
    _repos.clear();
  }
}
