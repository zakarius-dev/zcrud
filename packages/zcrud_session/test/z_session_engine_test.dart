/// Tests du runtime de session SRS `ZStudySessionEngine` (ES-4.2).
///
/// Pouvoir discriminant (R12) au CŒUR :
/// - AC3 : golden d'ORDRE de file après réinsertion +2/+4 (INJ-2 le rougit).
/// - AC2 : espion sur le seam ⇒ voie d'écriture SRS UNIQUE, 1×/grade (INJ-1).
/// - AC4 : seuil de lapse = `passThreshold` RÉUTILISÉ, pas un littéral (INJ-3).
/// - AC6 : grade atomique, échec de review NON avalé (INJ-4).
///
/// Runner = `flutter test` (R14 : `ChangeNotifier` ∈ flutter/foundation).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Espion de seam `ZSessionReviewer` : compte les appels, mémorise les arguments
/// et renvoie une réponse **programmable** (`Right` par défaut, `Left` sur
/// demande). Prouve la voie d'écriture UNIQUE (AC2) et l'échec exposé (AC6).
class _SpyReviewer {
  _SpyReviewer({this.failure});

  /// Si non-`null`, chaque appel renvoie `Left(failure)` (AC6).
  final ZFailure? failure;

  int calls = 0;
  final List<String> seenCards = <String>[];
  final List<int> seenQualities = <int>[];
  final List<DateTime?> seenNows = <DateTime?>[];

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    calls += 1;
    seenCards.add(flashcardId);
    seenQualities.add(quality);
    seenNows.add(now);
    if (failure != null) {
      return Left<ZFailure, ZRepetitionInfo>(failure!);
    }
    return Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

ZSessionItem _item(String id) => ZSessionItem(flashcardId: id, folderId: 'F');

List<ZSessionItem> _queueOf(String ids) =>
    ids.split('').map(_item).toList(growable: false);

/// Ordre des `flashcardId` de la file courante (pour les goldens d'ordre).
String _order(ZStudySessionEngine e) =>
    e.state.queue.map((i) => i.flashcardId).join();

void main() {
  group('AC3 — réinsertion +2/+4, ORDRE DE FILE GELÉ (golden, cœur R12)', () {
    test('lapse léger q=1 (+2) puis lapse dur q=2 (+4) — ordre EXACT', () async {
      final spy = _SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABCDEF'),
        reviewer: spy.call,
      );

      expect(_order(engine), 'ABCDEF');
      expect(engine.current!.flashcardId, 'A');

      // grade(A, q=1) : lapse léger, offset +2 ⇒ A réapparaît 2ᵉ carte à venir.
      await engine.grade(1);
      expect(_order(engine), 'BACDEF'); // [B, A, C, D, E, F]
      expect(engine.current!.flashcardId, 'B'); // curseur sur B

      // grade(B, q=2) : lapse dur, offset +4 ⇒ B réapparaît 4ᵉ carte à venir.
      await engine.grade(2);
      expect(_order(engine), 'ACDBEF'); // [A, C, D, B, E, F]
      expect(engine.current!.flashcardId, 'A');
    });

    test('réussite q>=3 ⇒ carte CONSOMMÉE (pas de réinsertion)', () async {
      final spy = _SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABC'),
        reviewer: spy.call,
      );

      await engine.grade(3); // A réussie
      expect(_order(engine), 'BC');
      expect(engine.current!.flashcardId, 'B');

      await engine.grade(5); // B réussie
      expect(_order(engine), 'C');

      await engine.grade(4); // C réussie
      expect(_order(engine), '');
      expect(engine.isComplete, isTrue);
    });

    test('clamp fin de file : lapse dur (+4) avec < 4 cartes à venir', () async {
      final spy = _SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queueOf('XYZ'),
        reviewer: spy.call,
      );

      // grade(X, q=2) : offset +4 mais seules Y,Z restent ⇒ X clampé en fin.
      await engine.grade(2);
      expect(_order(engine), 'YZX'); // X en toute fin
      expect(engine.current!.flashcardId, 'Y');
    });
  });

  group('AC2 — voie d\'écriture SRS UNIQUE via le seam (espion, AD-9/AD-23)',
      () {
    test('N grades ⇒ EXACTEMENT N appels du seam, carte courante attendue',
        () async {
      final spy = _SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABC'),
        reviewer: spy.call,
      );

      await engine.grade(3); // A
      await engine.grade(3); // B
      await engine.grade(3); // C

      expect(spy.calls, 3); // exactement N, jamais 0 ni 2N
      expect(spy.seenCards, <String>['A', 'B', 'C']);
      expect(spy.seenQualities, <int>[3, 3, 3]);
    });

    test('grade sur session COMPLÈTE = no-op : seam NON invoqué', () async {
      final spy = _SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queueOf('A'),
        reviewer: spy.call,
      );

      await engine.grade(3); // consomme A ⇒ complète
      expect(engine.isComplete, isTrue);
      expect(spy.calls, 1);

      final result = await engine.grade(3); // no-op
      expect(spy.calls, 1); // seam PAS rappelé
      expect(result.isLeft(), isTrue); // signalé, jamais silencieux
    });

    test('`now` est RELAYÉ au seam (déterminisme, D6)', () async {
      final spy = _SpyReviewer();
      final engine = ZStudySessionEngine(
        queue: _queueOf('A'),
        reviewer: spy.call,
      );
      final now = DateTime.utc(2026, 7, 14, 8);

      await engine.grade(3, now: now);
      expect(spy.seenNows.single, now);
    });
  });

  group('AC4 — seuil de lapse = passThreshold RÉUTILISÉ (pas un littéral)', () {
    test('défaut passThreshold=3 : q∈{0,1,2}⇒re-queue, q∈{3,4,5}⇒consommé',
        () async {
      for (final q in <int>[0, 1, 2]) {
        final engine = ZStudySessionEngine(
          queue: _queueOf('AB'),
          reviewer: _SpyReviewer().call,
        );
        await engine.grade(q);
        expect(engine.remaining, 2, reason: 'q=$q est un lapse ⇒ re-queue');
        expect(engine.lapses, 1);
      }
      for (final q in <int>[3, 4, 5]) {
        final engine = ZStudySessionEngine(
          queue: _queueOf('AB'),
          reviewer: _SpyReviewer().call,
        );
        await engine.grade(q);
        expect(engine.remaining, 1, reason: 'q=$q est une réussite ⇒ consommé');
        expect(engine.reviewed, 1);
      }
    });

    test('config CUSTOM passThreshold=4 : q=3 devient un LAPSE (re-queue)',
        () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('AB'),
        reviewer: _SpyReviewer().call,
        config: const ZSrsConfig(passThreshold: 4),
      );

      // Avec le SEUIL par défaut (3), q=3 serait consommé ; ici (4) c'est un
      // lapse ⇒ re-queue. Prouve que le seuil est LU, pas codé en dur (INJ-3).
      await engine.grade(3);
      expect(engine.remaining, 2);
      expect(engine.lapses, 1);
      expect(engine.reviewed, 0);
    });
  });

  group('AC5 — table d\'offsets {0,1}→+2, {2}→+4 (constantes nommées)', () {
    test('q=0 et q=1 produisent le MÊME offset (+2)', () async {
      for (final q in <int>[0, 1]) {
        final engine = ZStudySessionEngine(
          queue: _queueOf('ABCDEF'),
          reviewer: _SpyReviewer().call,
        );
        await engine.grade(q);
        // offset +2 ⇒ carte ratée 2ᵉ à venir.
        expect(_order(engine), 'BACDEF', reason: 'q=$q ⇒ offset +2');
      }
    });

    test('q=2 produit +4 (distinct de +2)', () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABCDEF'),
        reviewer: _SpyReviewer().call,
      );
      await engine.grade(2);
      expect(_order(engine), 'BCDAEF'); // A 4ᵉ carte à venir
    });

    test('les constantes exposées valent bien 2 / 4', () {
      expect(kLapseOffsetSoft, 2);
      expect(kLapseOffsetHard, 4);
    });
  });

  group('AC6 — grade atomique ; échec de review NON avalé (AD-5/R6)', () {
    test('seam Left ⇒ file INCHANGÉE + erreur exposée (retour + state)',
        () async {
      final spy = _SpyReviewer(failure: const ServerFailure('offline'));
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABC'),
        reviewer: spy.call,
      );

      final result = await engine.grade(1);

      expect(result.isLeft(), isTrue); // échec REMONTÉ, jamais avalé
      result.fold(
        (f) => expect(f, const ServerFailure('offline')),
        (_) => fail('attendu Left'),
      );
      expect(_order(engine), 'ABC'); // file INCHANGÉE (pas de réinsertion)
      expect(engine.lapses, 0);
      expect(engine.state.error, const ServerFailure('offline')); // exposé
    });

    test('seam Right ⇒ file MUTÉE (contre-preuve)', () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABC'),
        reviewer: _SpyReviewer().call,
      );
      await engine.grade(1);
      expect(_order(engine), 'BAC'); // mutée
      expect(engine.state.error, isNull);
    });
  });

  group('AC7 — complétion & compteurs déterministes', () {
    test('lapse reste `remaining`, réussite incrémente `reviewed`', () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABCDEF'),
        reviewer: _SpyReviewer().call,
      );

      await engine.grade(1); // A lapse
      expect(engine.reviewed, 0); // un lapse ne compte PAS comme reviewed
      expect(engine.lapses, 1);
      expect(engine.remaining, 6);
      expect(engine.isComplete, isFalse);

      await engine.grade(2); // B lapse
      expect(engine.reviewed, 0);
      expect(engine.lapses, 2);
      expect(engine.remaining, 6);
    });

    test('isComplete devient vrai quand la file est vide', () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('A'),
        reviewer: _SpyReviewer().call,
      );
      expect(engine.isComplete, isFalse);
      await engine.grade(4);
      expect(engine.isComplete, isTrue);
      expect(engine.remaining, 0);
      expect(engine.reviewed, 1);
    });
  });

  group('AC8 — notifyListeners granularité (une par transition, 0 sur no-op)',
      () {
    test('chaque grade réussi émet EXACTEMENT une notification', () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('ABC'),
        reviewer: _SpyReviewer().call,
      );
      var notes = 0;
      engine.addListener(() => notes += 1);

      await engine.grade(3); // A
      await engine.grade(1); // B lapse
      await engine.grade(3); // C
      expect(notes, 3);
    });

    test('grade no-op (session complète) ⇒ ZÉRO notification', () async {
      final engine = ZStudySessionEngine(
        queue: _queueOf('A'),
        reviewer: _SpyReviewer().call,
      );
      await engine.grade(3); // complète
      var notes = 0;
      engine.addListener(() => notes += 1);

      await engine.grade(3); // no-op
      expect(notes, 0);
    });
  });

  group('reducer PUR — reduceGrade est une fonction pure (D1/D6)', () {
    test('n\'altère pas l\'état d\'entrée (immuabilité)', () {
      final s0 = ZSessionState.initial(_queueOf('ABC'));
      final s1 = reduceGrade(s0, 1, passThreshold: 3);
      expect(_orderOf(s0), 'ABC'); // entrée INCHANGÉE
      expect(_orderOf(s1), 'BAC'); // sortie mutée
      expect(identical(s0, s1), isFalse);
    });

    test('grade sur file vide = no-op (retourne l\'état tel quel)', () {
      final s0 = ZSessionState.initial(const <ZSessionItem>[]);
      final s1 = reduceGrade(s0, 1, passThreshold: 3);
      expect(identical(s0, s1), isTrue);
    });
  });
}

String _orderOf(ZSessionState s) =>
    s.queue.map((i) => i.flashcardId).join();
