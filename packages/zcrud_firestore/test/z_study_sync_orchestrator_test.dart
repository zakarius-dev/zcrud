// Tests ES-3.4 : `assembleZStudySyncOrchestrator` — fabrique de câblage de
// l'orchestrateur de synchronisation d'étude (liste de dépôts INJECTÉE).
//
// Couverture (mappée aux ACs), à POUVOIR DISCRIMINANT (R12) — chaque garde est
// prouvée par un COMPTEUR observé (spies), jamais par l'existence de la fabrique :
//   AC2 — liste injectée : un cycle synchronise TOUS les dépôts, exactement 1×.
//   AC3 — aucune liste/import de repos codés en dur (signature `Iterable` neutre).
//   AC4 — best-effort : la panne d'UN dépôt n'arrête pas les autres (pas de Left global).
//   AC5 — débounce ~400 ms (paramétrable) : N déclencheurs → 1 seul cycle coalescé.
//   AC6 — thread UI jamais bloqué : onLogin/onReconnected sync-void, aucun throw échappé.
//   AC7 — dispose NON-propriétaire : les dépôts injectés ne sont PAS disposés.
//   AC8 — signatures nues : sortie = ZSyncOrchestrator (type du cœur), aucun type backend.
//
// **Aucun `Timer` réel ni `Future.delayed`** : le temps est piloté par une
// fabrique de timer contrôlable (`_FakeTimer`) + `flushPending()`. Aucun
// `fake_cloud_firestore`/Hive requis (la fabrique n'orchestre que des `sync()`).
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Fabrique de timer contrôlable ────────────────────

/// Poignée de timer **fausse** : capture `(durée, callback)` sans horloge réelle.
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

/// Fabrique injectable : mémorise chaque timer créé (pour prouver la coalescence).
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

enum _SyncBehavior { ok, leftServer, throwError }

/// Dépôt espion : compte les appels `sync()`/`dispose()` et retourne un résultat
/// paramétrable. **Toute** autre méthode `ZRepository` lève `UnimplementedError` —
/// preuve que l'orchestrateur (et la fabrique) n'appellent QUE `sync()`.
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
        return const Left<ZFailure, Unit>(ZServerFailure('serveur indisponible'));
      case _SyncBehavior.throwError:
        throw StateError('boom');
    }
  }

  @override
  void dispose() => disposed = true;

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Méthode ${invocation.memberName} appelée — seul sync() est autorisé',
      );
}

/// Dépôt espion dont `sync()` reste **pendant** (jamais résolu) : prouve que le
/// déclencheur ne bloque pas l'appelant (AC6).
class _PendingSpyRepo implements ZSyncableRepository<ZEntity> {
  int syncCalls = 0;

  @override
  Future<ZResult<Unit>> sync() {
    syncCalls++;
    return Completer<ZResult<Unit>>().future; // jamais résolu
  }

  @override
  void dispose() {}

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError(
        'Méthode ${invocation.memberName} appelée — seul sync() est autorisé',
      );
}

void main() {
  group('AC2 — liste injectée : un cycle synchronise TOUS les dépôts, 1×', () {
    test('onLogin + flushPending → chaque spy injecté syncCalls == 1', () async {
      final factory = _FakeTimerFactory();
      final spyA = _SpyRepo(_SyncBehavior.ok);
      final spyB = _SpyRepo(_SyncBehavior.ok);
      final spyC = _SpyRepo(_SyncBehavior.ok);

      final o = assembleZStudySyncOrchestrator(
        repositories: [spyA, spyB, spyC],
        timerFactory: factory.call,
      );

      // Registre alimenté par la fabrique (registerAll) : les 3 dépôts.
      expect(o.registeredCount, 3);

      o.onLogin();
      await o.flushPending();

      // R3-a (bout-en-bout) : casser la boucle registerAll (n'assembler que
      // repositories.first) → spyB/spyC.syncCalls == 0 ⇒ ROUGE. La liste
      // injectée est réellement itérée jusqu'au bout (comptée par les spies).
      expect(spyA.syncCalls, 1);
      expect(spyB.syncCalls, 1);
      expect(spyC.syncCalls, 1);

      o.dispose();
    });
  });

  group('AC3 — aucune liste/import de repos codés en dur', () {
    test('la fabrique ne source ses dépôts QUE du paramètre injecté', () async {
      // La MÊME fabrique, appelée avec 1 puis 4 dépôts, orchestre exactement ce
      // qu'on lui passe (aucune liste interne fixe). « Ajouter un dépôt = passer
      // une liste plus longue », jamais éditer la fabrique.
      final one = _SpyRepo(_SyncBehavior.ok);
      final o1 = assembleZStudySyncOrchestrator(
        repositories: [one],
        timerFactory: _FakeTimerFactory().call,
      );
      expect(o1.registeredCount, 1);
      await o1.syncNow();
      expect(one.syncCalls, 1);
      o1.dispose();

      final four = List.generate(4, (_) => _SpyRepo(_SyncBehavior.ok));
      final o4 = assembleZStudySyncOrchestrator(
        repositories: four,
        timerFactory: _FakeTimerFactory().call,
      );
      expect(o4.registeredCount, 4);
      await o4.syncNow();
      expect(four.every((r) => r.syncCalls == 1), isTrue);
      o4.dispose();
    });

    test('garde statique (disque) : le fichier fabrique n\'importe/construit '
        'AUCUN repo concret (anti-doublon study_sync_manager)', () {
      final rawSource = File(
        'lib/src/data/z_study_sync_orchestrator.dart',
      ).readAsStringSync();
      // On inspecte le CODE, pas la prose : le dartdoc nomme légitimement les
      // symboles interdits pour expliquer leur ABSENCE. Retirer les lignes de
      // commentaire évite tout faux-positif (garde load-bearing sur le vrai code).
      final code = rawSource
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');

      // Aucun repo concret importé/instancié : la seule source de dépôts est le
      // paramètre `repositories`. (Miroir de l'éradication de
      // study_sync_manager.dart:9-19,98-112.)
      expect(code.contains('repository_impl'), isFalse,
          reason: 'aucun *_repository_impl importé');
      expect(code.contains('ZOfflineFirstBoxRepository'), isFalse,
          reason: 'aucun dépôt concret référencé/construit');
      expect(code.contains('ZOfflineFirstRepository'), isFalse,
          reason: 'aucun dépôt concret référencé/construit');
      // Aucun couplage app-spécifique (AD-15).
      expect(code.contains('firebase_auth'), isFalse);
      expect(code.contains('connectivity_plus'), isFalse);
      expect(code.toLowerCase().contains('riverpod'), isFalse);
      // Le seul import est le barrel neutre du cœur.
      final imports = rawSource
          .split('\n')
          .where((l) => l.trimLeft().startsWith('import '))
          .toList();
      expect(imports, ["import 'package:zcrud_core/zcrud_core.dart';"],
          reason: 'seule dépendance : le cœur neutre');
      // La signature prend bien une Iterable neutre injectée.
      expect(
          code.contains(
              'required Iterable<ZSyncableRepository<dynamic>> repositories'),
          isTrue);
    });
  });

  group('AC4 — best-effort : la panne d\'UN dépôt n\'arrête pas les autres', () {
    test('[okA, boom, okB] → okA & okB synchronisés, Right(report), failed>=1',
        () async {
      final okA = _SpyRepo(_SyncBehavior.ok);
      final boom = _SpyRepo(_SyncBehavior.throwError);
      final okB = _SpyRepo(_SyncBehavior.ok);

      final o = assembleZStudySyncOrchestrator(
        repositories: [okA, boom, okB],
        timerFactory: _FakeTimerFactory().call,
      );

      final result = await o.syncNow();

      // R3-b : retirer le try/catch par-dépôt / rethrow au 1er échec (court-circuit)
      // → okB.syncCalls == 0 OU syncNow → Left/throw ⇒ ROUGE.
      expect(okA.syncCalls, 1);
      expect(boom.syncCalls, 1);
      expect(okB.syncCalls, 1, reason: 'le dépôt APRÈS la panne est atteint');
      expect(result.isRight(), isTrue, reason: 'best-effort → jamais un Left global');
      final report = result.getOrElse(() => const ZSyncRunReport.empty());
      expect(report.failed, greaterThanOrEqualTo(1));

      o.dispose();
    });

    test('un Left(ZServerFailure) est compté (pas d\'exception échappée)',
        () async {
      final okA = _SpyRepo(_SyncBehavior.ok);
      final bad = _SpyRepo(_SyncBehavior.leftServer);
      final okB = _SpyRepo(_SyncBehavior.ok);
      final o = assembleZStudySyncOrchestrator(
        repositories: [okA, bad, okB],
        timerFactory: _FakeTimerFactory().call,
      );

      final report =
          (await o.syncNow()).getOrElse(() => const ZSyncRunReport.empty());
      expect(okA.syncCalls, 1);
      expect(okB.syncCalls, 1);
      expect(report.succeeded, 2);
      expect(report.failed, 1);
      expect(report.failures.single, isA<ZServerFailure>());

      o.dispose();
    });
  });

  group('AC5 — débounce ~400 ms paramétrable : N déclencheurs → 1 cycle', () {
    test('N onLogin/onReconnected rapprochés coalescent : spy.syncCalls == 1',
        () async {
      final factory = _FakeTimerFactory();
      final spy = _SpyRepo(_SyncBehavior.ok);
      final o = assembleZStudySyncOrchestrator(
        repositories: [spy],
        timerFactory: factory.call,
      );

      o.onLogin();
      o.onReconnected();
      o.onReconnected();

      // R3-c : retirer le _cancelPending() du _schedule (pas de réarmement) → N
      // timers non annulés fire() → spy.syncCalls == N ⇒ ROUGE.
      expect(factory.created.length, 3, reason: '3 réarmements');
      expect(factory.created[0].isCancelled, isTrue);
      expect(factory.created[1].isCancelled, isTrue);
      expect(factory.created[2].isCancelled, isFalse);
      expect(spy.syncCalls, 0, reason: 'aucun sync avant fire');

      await o.flushPending();
      expect(spy.syncCalls, 1, reason: 'un SEUL cycle coalescé (pas N)');

      o.dispose();
    });

    test('fenêtre paramétrable : override capturé ; défaut == 400 ms', () {
      final def = _FakeTimerFactory();
      final oDef = assembleZStudySyncOrchestrator(
        repositories: [_SpyRepo(_SyncBehavior.ok)],
        timerFactory: def.call,
      );
      oDef.onLogin();
      expect(def.last!.duration, kZSyncDefaultDebounce);
      expect(def.last!.duration, const Duration(milliseconds: 400));
      oDef.dispose();

      final custom = _FakeTimerFactory();
      const d = Duration(milliseconds: 120);
      final oCustom = assembleZStudySyncOrchestrator(
        repositories: [_SpyRepo(_SyncBehavior.ok)],
        debounce: d,
        timerFactory: custom.call,
      );
      oCustom.onReconnected();
      expect(custom.last!.duration, d);
      oCustom.dispose();
    });
  });

  group('AC6 — thread UI jamais bloqué', () {
    test('onLogin est sync-void et retourne AVANT tout await sync()', () async {
      final factory = _FakeTimerFactory();
      final pending = _PendingSpyRepo();
      final o = assembleZStudySyncOrchestrator(
        repositories: [pending],
        timerFactory: factory.call,
      );

      // Retourne immédiatement (déclencheur planifie, n'attend rien).
      o.onLogin();
      // Même après avoir « tiré » le timer (fire → unawaited cycle), l'appelant
      // n'est pas bloqué par le sync() pendant.
      factory.last!.fire();
      // Laisse une micro-tâche s'écouler : le cycle a démarré sync() mais ne bloque pas.
      await Future<void>.value();
      expect(pending.syncCalls, 1);

      o.dispose();
    });

    test('un dépôt qui throw n\'émet aucune exception hors de onLogin', () async {
      final factory = _FakeTimerFactory();
      final o = assembleZStudySyncOrchestrator(
        repositories: [_SpyRepo(_SyncBehavior.throwError)],
        timerFactory: factory.call,
      );

      expect(() => o.onLogin(), returnsNormally);
      expect(() => o.onReconnected(), returnsNormally);
      // Voie débouncée = fire-and-forget loggée : le fire ne fait rien fuir.
      expect(() => factory.last!.fire(), returnsNormally);
      await Future<void>.value();

      // Voie awaitable : reste Right(report) même si le dépôt throw.
      final result = await o.syncNow();
      expect(result.isRight(), isTrue);

      o.dispose();
    });
  });

  group('AC7 — dispose NON-propriétaire', () {
    test('dispose vide le registre mais ne dispose PAS les dépôts injectés',
        () async {
      final spy = _SpyRepo(_SyncBehavior.ok);
      final o = assembleZStudySyncOrchestrator(
        repositories: [spy],
        timerFactory: _FakeTimerFactory().call,
      );
      expect(o.registeredCount, 1);

      o.dispose();

      // R3-d : faire dispose() itérer et repo.dispose() → spy.disposed==true ⇒ ROUGE.
      expect(spy.disposed, isFalse, reason: 'l\'app est propriétaire du dépôt injecté');
      expect(o.registeredCount, 0, reason: 'registre vidé');

      // Cycle ultérieur inerte.
      final report =
          (await o.syncNow()).getOrElse(() => const ZSyncRunReport(
                attempted: 99,
                succeeded: 99,
                failed: 0,
              ));
      expect(report, const ZSyncRunReport.empty());
      expect(spy.syncCalls, 0);

      // Idempotent.
      expect(o.dispose, returnsNormally);
    });
  });

  group('AC8 — signatures nues (type du cœur en sortie)', () {
    test('assembleZStudySyncOrchestrator retourne un ZSyncOrchestrator neutre',
        () {
      final ZSyncOrchestrator o = assembleZStudySyncOrchestrator(
        repositories: const <ZSyncableRepository<dynamic>>[],
        timerFactory: _FakeTimerFactory().call,
      );
      expect(o, isA<ZSyncOrchestrator>());
      expect(o.registeredCount, 0);
      o.dispose();
    });
  });
}
