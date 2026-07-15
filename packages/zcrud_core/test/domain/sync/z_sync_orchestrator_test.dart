// Tests E5-4 : `ZSyncOrchestrator` — **le *quand*** de l'offline-first.
//
// Couverture (mappée aux ACs) : registre idempotent (AC2), débounce/coalescence
// N→1 SANS Timer réel (AC3, AC9), séparation quand/comment — seul `sync()` touché
// (AC4), échec partiel Left+throw sans interruption + trace (AC5), offline→0 sync
// (AC6), gate enabled=false (AC7), `syncNow` rapport agrégé (AC8), dette
// réseau/serveur `ServerFailure` compté `failed` (AC10), dispose inerte + dépôts
// NON disposés (AC11).
//
// **Aucun `Timer` réel ni `Future.delayed`** dans la suite débounce : le temps est
// piloté par une **fabrique de timer contrôlable** (`_FakeTimer`) + `flushPending()`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// ───────────────────────── Fabrique de timer contrôlable ────────────────────

/// Poignée de timer **fausse** : capture `(durée, callback)` sans horloge réelle
/// et permet de déclencher (`fire`) / d'observer l'annulation (`isCancelled`).
class _FakeTimer implements ZCancelableTimer {
  _FakeTimer(this.duration, this.callback);

  final Duration duration;
  final void Function() callback;
  bool isCancelled = false;

  void fire() {
    if (!isCancelled) callback();
  }

  @override
  void cancel() => isCancelled = true;
}

/// Fabrique injectable : mémorise le **dernier** timer créé + un compteur de
/// créations (pour prouver la coalescence : N déclencheurs → réarmements, 1 cycle).
class _FakeTimerFactory {
  final List<_FakeTimer> created = <_FakeTimer>[];

  _FakeTimer? get last => created.isEmpty ? null : created.last;

  ZCancelableTimer call(Duration duration, void Function() callback) {
    final timer = _FakeTimer(duration, callback);
    created.add(timer);
    return timer;
  }
}

// ───────────────────────────── Dépôts espions ──────────────────────────────

enum _SyncBehavior { ok, leftServer, leftCache, throwError }

/// Dépôt espion : compte les appels `sync()` et retourne un résultat paramétrable.
/// **Toute** autre méthode `ZRepository` lève `UnimplementedError` — preuve que
/// l'orchestrateur n'appelle QUE `sync()` (AC4).
class _SpyRepo implements ZSyncableRepository<ZEntity> {
  _SpyRepo(this.behavior);

  final _SyncBehavior behavior;
  int syncCalls = 0;
  bool disposed = false;

  @override
  Future<ZResult<Unit>> sync() async {
    syncCalls++;
    switch (behavior) {
      case _SyncBehavior.ok:
        return Right<ZFailure, Unit>(unit);
      case _SyncBehavior.leftServer:
        return const Left<ZFailure, Unit>(ServerFailure('serveur indisponible'));
      case _SyncBehavior.leftCache:
        return const Left<ZFailure, Unit>(CacheFailure('cache corrompu'));
      case _SyncBehavior.throwError:
        throw StateError('boom');
    }
  }

  @override
  void dispose() => disposed = true;

  // Toute autre surface NE doit JAMAIS être touchée par l'orchestrateur (AC4).
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Méthode ${invocation.memberName} appelée — seul sync() est autorisé',
      );
}

// ─────────────────────────── Collecteur de logs ────────────────────────────

class _LogSink {
  final List<String> messages = <String>[];
  final List<Object?> errors = <Object?>[];

  void call(String message, {Object? error, StackTrace? stackTrace}) {
    messages.add(message);
    errors.add(error);
  }
}

void main() {
  group('Registre (AC2)', () {
    test('register/unregister/ré-register idempotent par identité', () {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final r1 = _SpyRepo(_SyncBehavior.ok);
      final r2 = _SpyRepo(_SyncBehavior.ok);

      expect(o.registeredCount, 0);
      o.register(r1);
      o.register(r2);
      expect(o.registeredCount, 2);

      // Ré-register du même instance = no-op (pas de doublon).
      o.register(r1);
      expect(o.registeredCount, 2);

      o.unregister(r1);
      expect(o.registeredCount, 1);
      // unregister d'un absent = no-op.
      o.unregister(r1);
      expect(o.registeredCount, 1);

      o.dispose();
    });
  });

  group('registerAll (ES-3.4)', () {
    test('enregistre CHAQUE dépôt de la liste injectée (garde d\'itération)',
        () {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final r1 = _SpyRepo(_SyncBehavior.ok);
      final r2 = _SpyRepo(_SyncBehavior.ok);
      final r3 = _SpyRepo(_SyncBehavior.ok);

      o.registerAll([r1, r2, r3]);
      // R3-a : remplacer la boucle par `register(repos.first)` → count==1 ⇒ ROUGE
      // (la garde « aucun repo oublié » est LOAD-BEARING).
      expect(o.registeredCount, 3);

      o.dispose();
    });

    test('idempotence héritée : re-appel avec la même liste ⇒ toujours 3', () {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final r1 = _SpyRepo(_SyncBehavior.ok);
      final r2 = _SpyRepo(_SyncBehavior.ok);
      final r3 = _SpyRepo(_SyncBehavior.ok);

      o.registerAll([r1, r2, r3]);
      o.registerAll([r1, r2, r3]);
      expect(o.registeredCount, 3, reason: 'compose register (idempotent par identité)');

      // Un doublon dans la liste elle-même n'est enregistré qu'une fois.
      o.registerAll([r1, r1]);
      expect(o.registeredCount, 3);

      o.dispose();
    });

    test('no-op après dispose ⇒ registeredCount reste 0', () {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      o.dispose();
      o.registerAll([_SpyRepo(_SyncBehavior.ok), _SpyRepo(_SyncBehavior.ok)]);
      expect(o.registeredCount, 0, reason: 'no-op après dispose (héritée de register)');
    });

    test('un cycle synchronise TOUS les dépôts injectés, exactement une fois',
        () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final r1 = _SpyRepo(_SyncBehavior.ok);
      final r2 = _SpyRepo(_SyncBehavior.ok);
      final r3 = _SpyRepo(_SyncBehavior.ok);
      o.registerAll([r1, r2, r3]);

      await o.syncNow();
      // Preuve par compteurs (pas par registeredCount seul — R12) : chaque dépôt
      // injecté est réellement itéré jusqu'au bout.
      expect(r1.syncCalls, 1);
      expect(r2.syncCalls, 1);
      expect(r3.syncCalls, 1);

      o.dispose();
    });
  });

  group('Débounce & coalescence SANS Timer réel (AC3, AC9)', () {
    test('N déclencheurs rapprochés → 1 seul cycle, chaque sync() 1 fois',
        () async {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(timerFactory: factory.call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      // 3 déclencheurs rapprochés : chaque _schedule réarme (crée un nouveau
      // fake timer et annule le précédent).
      o.onLogin();
      o.onReconnected();
      o.onReconnected();

      expect(factory.created.length, 3, reason: '3 réarmements');
      // Les 2 premiers timers sont annulés ; seul le dernier reste armé.
      expect(factory.created[0].isCancelled, isTrue);
      expect(factory.created[1].isCancelled, isTrue);
      expect(factory.created[2].isCancelled, isFalse);
      // Débounce = 400 ms par défaut.
      expect(factory.created[2].duration, const Duration(milliseconds: 400));

      // Aucun sync() tant que le timer n'a pas tiré.
      expect(repo.syncCalls, 0);

      await o.flushPending();
      // Un SEUL cycle → sync() appelé exactement une fois (coalescence).
      expect(repo.syncCalls, 1);

      o.dispose();
    });

    test('flushPending sans timer armé = no-op (report vide)', () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      final report = await o.flushPending();
      expect(report, const ZSyncRunReport.empty());
      expect(repo.syncCalls, 0);

      o.dispose();
    });

    test('débounce surchargeable par le constructeur', () {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(
        debounce: const Duration(milliseconds: 50),
        timerFactory: factory.call,
      );
      o.onLogin();
      expect(factory.last!.duration, const Duration(milliseconds: 50));
      o.dispose();
    });
  });

  group('Séparation quand/comment (AC4)', () {
    test('seul sync() est invoqué sur le dépôt (autres méthodes throw)',
        () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      final report = await o.syncNow();
      // Si l'orchestrateur avait touché getAll/watch/save/..., noSuchMethod
      // aurait levé UnimplementedError et fait échouer ce test.
      expect(report.isRight(), isTrue);
      expect(repo.syncCalls, 1);
      expect(repo.disposed, isFalse);

      o.dispose();
    });
  });

  group('Best-effort & échec partiel (AC5)', () {
    test('un Left ET un throw n\'interrompent pas les autres dépôts', () async {
      final log = _LogSink();
      final o = ZSyncOrchestrator(
        timerFactory: _FakeTimerFactory().call,
        logger: log.call,
      );
      final ok1 = _SpyRepo(_SyncBehavior.ok);
      final bad = _SpyRepo(_SyncBehavior.leftServer);
      final boom = _SpyRepo(_SyncBehavior.throwError);
      final ok2 = _SpyRepo(_SyncBehavior.ok);
      o
        ..register(ok1)
        ..register(bad)
        ..register(boom)
        ..register(ok2);

      final result = await o.syncNow();

      // Aucune exception échappée : on a bien un Right.
      final report = result.getOrElse(() => const ZSyncRunReport.empty());
      // TOUS les dépôts ont vu sync() (même après l'échec central).
      expect(ok1.syncCalls, 1);
      expect(bad.syncCalls, 1);
      expect(boom.syncCalls, 1);
      expect(ok2.syncCalls, 1);
      // 2 succès, 2 échecs (1 Left + 1 throw).
      expect(report.attempted, 4);
      expect(report.succeeded, 2);
      expect(report.failed, 2);
      // Le Left (ZFailure) est collecté ; l'exception brute non (juste comptée).
      expect(report.failures.length, 1);
      expect(report.failures.single, isA<ServerFailure>());
      // Les deux échecs sont tracés (log non muet — AD-11).
      expect(log.messages.where((m) => m.contains('échec')).length, 1);
      expect(log.messages.where((m) => m.contains('exception')).length, 1);

      o.dispose();
    });
  });

  group('Offline → cycle sauté (AC6)', () {
    test('isConnected=false → 0 sync(), report vide', () async {
      final log = _LogSink();
      final o = ZSyncOrchestrator(
        timerFactory: _FakeTimerFactory().call,
        isConnected: () async => false,
        logger: log.call,
      );
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      final result = await o.syncNow();
      final report = result.getOrElse(() => const ZSyncRunReport(
            attempted: 99,
            succeeded: 99,
            failed: 0,
          ));
      expect(repo.syncCalls, 0);
      expect(report, const ZSyncRunReport.empty());
      expect(log.messages.any((m) => m.contains('hors-ligne')), isTrue);

      o.dispose();
    });

    test('isConnected=true → cycle exécuté normalement', () async {
      final o = ZSyncOrchestrator(
        timerFactory: _FakeTimerFactory().call,
        isConnected: () async => true,
      );
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      await o.syncNow();
      expect(repo.syncCalls, 1);
      o.dispose();
    });

    test('isConnected=null (défaut) → jamais court-circuité', () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);
      await o.syncNow();
      expect(repo.syncCalls, 1);
      o.dispose();
    });

    test(
        'MEDIUM-1 : isConnected qui THROW → cycle sauté, Right(report vide), '
        'aucune exception échappée', () async {
      final log = _LogSink();
      final o = ZSyncOrchestrator(
        timerFactory: _FakeTimerFactory().call,
        isConnected: () async => throw StateError('réseau indéterminé'),
        logger: log.call,
      );
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      // Voie immédiate : best-effort intégral → Right, jamais un throw.
      final result = await o.syncNow();
      expect(result.isRight(), isTrue);
      expect(
          result.getOrElse(() =>
              const ZSyncRunReport(attempted: 99, succeeded: 99, failed: 0)),
          const ZSyncRunReport.empty());
      expect(repo.syncCalls, 0, reason: 'cycle sauté quand isConnected throw');
      expect(log.messages.any((m) => m.contains('isConnected en exception')),
          isTrue);

      // Voie débouncée (unawaited) : un déclencheur + flush ne fait rien fuir.
      o.onLogin();
      await o.flushPending();
      expect(repo.syncCalls, 0);
      o.dispose();
    });

    test(
        'MEDIUM-1 : logger qui THROW n\'interrompt pas le cycle best-effort',
        () async {
      final o = ZSyncOrchestrator(
        timerFactory: _FakeTimerFactory().call,
        logger: (message, {error, stackTrace}) =>
            throw StateError('log cassé'),
      );
      o.register(_SpyRepo(_SyncBehavior.leftServer)); // déclenche un _safeLog
      final okRepo = _SpyRepo(_SyncBehavior.ok);
      o.register(okRepo);

      final result = await o.syncNow();
      expect(result.isRight(), isTrue);
      final report = result.getOrElse(() => const ZSyncRunReport.empty());
      expect(report.attempted, 2);
      expect(report.failed, 1);
      expect(okRepo.syncCalls, 1,
          reason: 'le 2e dépôt passe malgré un logger défaillant sur le 1er');
      o.dispose();
    });
  });

  group('Gate d\'activation (AC7)', () {
    test('enabled=false → aucun timer armé, flushPending no-op, 0 sync()',
        () async {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(timerFactory: factory.call, enabled: false);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      o.onLogin();
      o.onReconnected();
      expect(factory.created, isEmpty, reason: 'aucun timer armé');

      final flushed = await o.flushPending();
      expect(flushed, const ZSyncRunReport.empty());

      final report = (await o.syncNow())
          .getOrElse(() => const ZSyncRunReport(attempted: 1, succeeded: 1, failed: 0));
      expect(report, const ZSyncRunReport.empty());
      expect(repo.syncCalls, 0);

      o.dispose();
    });

    test('passer enabled=false ANNULE un cycle en attente', () async {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(timerFactory: factory.call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);

      o.onReconnected();
      expect(factory.last!.isCancelled, isFalse);

      o.enabled = false;
      expect(factory.last!.isCancelled, isTrue, reason: 'timer annulé');

      final flushed = await o.flushPending();
      expect(flushed, const ZSyncRunReport.empty());
      expect(repo.syncCalls, 0);

      o.dispose();
    });

    test('réactiver enabled=true permet de re-planifier', () {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(timerFactory: factory.call, enabled: false);
      o.onLogin();
      expect(factory.created, isEmpty);
      o.enabled = true;
      o.onLogin();
      expect(factory.created.length, 1);
      o.dispose();
    });
  });

  group('syncNow — rapport agrégé (AC8)', () {
    test('mix succès/échec → Right(report attempted:3, succeeded:2, failed:1)',
        () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      o
        ..register(_SpyRepo(_SyncBehavior.ok))
        ..register(_SpyRepo(_SyncBehavior.leftServer))
        ..register(_SpyRepo(_SyncBehavior.ok));

      final result = await o.syncNow();
      expect(result.isRight(), isTrue, reason: 'best-effort intégral → jamais Left');
      final report = result.getOrElse(() => const ZSyncRunReport.empty());
      expect(report.attempted, 3);
      expect(report.succeeded, 2);
      expect(report.failed, 1);

      o.dispose();
    });

    test('registre vide → report vide (Right)', () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final result = await o.syncNow();
      expect(result.getOrElse(() => const ZSyncRunReport(attempted: 1, succeeded: 1, failed: 0)),
          const ZSyncRunReport.empty());
      o.dispose();
    });
  });

  group('Dette réseau/serveur (AC10)', () {
    test('Left(ServerFailure) compté failed + collecté (pas masqué offline)',
        () async {
      final log = _LogSink();
      final o = ZSyncOrchestrator(
        timerFactory: _FakeTimerFactory().call,
        logger: log.call,
      );
      o.register(_SpyRepo(_SyncBehavior.leftServer));

      final report = (await o.syncNow()).getOrElse(() => const ZSyncRunReport.empty());
      expect(report.failed, 1);
      expect(report.failures.single, isA<ServerFailure>());
      // Visible dans le log (jamais noyé silencieusement).
      expect(log.messages.any((m) => m.contains('échec')), isTrue);

      o.dispose();
    });
  });

  group('Cycle de vie — dispose (AC11)', () {
    test('post-dispose : onReconnected n\'arme rien, flushPending no-op', () async {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(timerFactory: factory.call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);
      o.dispose();

      o.onReconnected();
      o.onLogin();
      expect(factory.created, isEmpty, reason: 'aucun timer après dispose');

      final flushed = await o.flushPending();
      expect(flushed, const ZSyncRunReport.empty());
      expect(repo.syncCalls, 0);
    });

    test('dispose annule un timer en attente et vide le registre', () async {
      final factory = _FakeTimerFactory();
      final o = ZSyncOrchestrator(timerFactory: factory.call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);
      o.onReconnected();
      expect(o.registeredCount, 1);

      o.dispose();
      expect(factory.last!.isCancelled, isTrue);
      expect(o.registeredCount, 0);
    });

    test('dispose ne dispose PAS les dépôts enregistrés (non-propriété)', () {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final repo = _SpyRepo(_SyncBehavior.ok);
      o.register(repo);
      o.dispose();
      expect(repo.disposed, isFalse, reason: 'orchestrateur non propriétaire');
    });

    test('dispose idempotent', () {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      o.dispose();
      expect(o.dispose, returnsNormally);
    });
  });

  group('Isolation des signatures publiques (AC12)', () {
    test('syncNow expose un ZResult<ZSyncRunReport> neutre', () async {
      final o = ZSyncOrchestrator(timerFactory: _FakeTimerFactory().call);
      final ZResult<ZSyncRunReport> result = await o.syncNow();
      expect(result, isA<Either<ZFailure, ZSyncRunReport>>());
      o.dispose();
    });
  });
}
