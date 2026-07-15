/// Golden EXAMEN BLANC (`ZWhiteExamSessionEngine`) — ES-4.4,
/// AC2/AC3/AC5/AC6/AC7.
///
/// Pouvoir discriminant (R12) : ces goldens FIGENT (a) la machine à états
/// `setup → running → submitted` avec REFUS `throwsStateError` de toute
/// transition illégale (AC2, CŒUR — INJ-2), (b) le scoring déterministe
/// `[5,3,2,0,4] → total:5, correct:3` en littéral (AC3, CŒUR — INJ-4), (c) la
/// frontière `passThreshold` RÉUTILISÉE (AC5), (d) le seam de scoring composable
/// (AC6), (e) la granularité `notifyListeners` (AC7).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

ZSessionItem _item(String id) => ZSessionItem(flashcardId: id, folderId: 'f');

List<ZSessionItem> _queue(List<String> ids) => ids.map(_item).toList();

ZWhiteExamSessionEngine _engine(
  List<String> ids, {
  ZSrsConfig config = const ZSrsConfig(),
  ZExamScoringPort? scorer,
}) =>
    ZWhiteExamSessionEngine(
      queue: _queue(ids),
      config: config,
      scorer: scorer ?? scoreWhiteExam,
    );

void main() {
  group('AC2 — machine à états setup→running→submitted (CŒUR)', () {
    test('chemin nominal : phases exactes après chaque transition', () {
      final e = _engine(<String>['A', 'B', 'C']);

      // État initial : setup.
      expect(e.phase, ZWhiteExamPhase.setup);
      expect(e.current!.flashcardId, 'A');
      expect(e.result, isNull);
      expect(e.isSubmitted, isFalse);

      e.start();
      expect(e.phase, ZWhiteExamPhase.running);
      expect(e.current!.flashcardId, 'A');

      e.answer(4);
      expect(e.phase, ZWhiteExamPhase.running);
      expect(e.answered, 1);
      expect(e.current!.flashcardId, 'B');
      expect(e.remaining, 2);

      e.answer(5);
      e.answer(2);
      expect(e.answered, 3);
      expect(e.current, isNull, reason: 'curseur au-delà de la dernière carte');
      expect(e.remaining, 0);

      // result reste null tant que non soumis.
      expect(e.result, isNull);

      e.submit();
      expect(e.phase, ZWhiteExamPhase.submitted);
      expect(e.isSubmitted, isTrue);
      expect(e.result, isNotNull);
    });

    test('answer() avant start() (phase setup) LÈVE StateError', () {
      final e = _engine(<String>['A']);
      expect(() => e.answer(3), throwsStateError);
      expect(e.phase, ZWhiteExamPhase.setup, reason: 'aucune mutation muette');
    });

    test('submit() avant start() (phase setup) LÈVE StateError', () {
      final e = _engine(<String>['A']);
      expect(() => e.submit(), throwsStateError);
      expect(e.phase, ZWhiteExamPhase.setup);
      expect(e.result, isNull);
    });

    test('start() en phase running LÈVE StateError', () {
      final e = _engine(<String>['A']);
      e.start();
      expect(() => e.start(), throwsStateError);
      expect(e.phase, ZWhiteExamPhase.running);
    });

    test('start() en phase submitted LÈVE StateError (pas de retour arrière)',
        () {
      final e = _engine(<String>['A']);
      e.start();
      e.answer(3);
      e.submit();
      expect(() => e.start(), throwsStateError,
          reason: 'submitted → running interdit');
      expect(e.phase, ZWhiteExamPhase.submitted);
    });

    test('answer() après submit() (phase submitted) LÈVE StateError', () {
      final e = _engine(<String>['A']);
      e.start();
      e.answer(3);
      e.submit();
      expect(() => e.answer(5), throwsStateError);
      expect(e.phase, ZWhiteExamPhase.submitted);
    });

    test('double submit() LÈVE StateError', () {
      final e = _engine(<String>['A']);
      e.start();
      e.answer(3);
      e.submit();
      final first = e.result;
      expect(() => e.submit(), throwsStateError);
      expect(e.result, same(first), reason: 'le score figé ne change pas');
    });
  });

  group('AC3 — scoring déterministe à la soumission, golden figé (CŒUR)', () {
    test('[5,3,2,0,4] passThreshold=3 → total:5, correct:3, byQuality figé', () {
      final e = _engine(<String>['A', 'B', 'C', 'D', 'E']);
      e.start();
      for (final q in <int>[5, 3, 2, 0, 4]) {
        e.answer(q);
      }
      expect(e.result, isNull, reason: 'result null tant que non soumis');
      e.submit();

      const expected = ZStudySessionResult(
        mode: ZReviewMode.whiteExam,
        total: 5,
        correct: 3, // 5,3,4 ≥ 3
        byQuality: <String, int>{'5': 1, '3': 1, '2': 1, '0': 1, '4': 1},
      );
      expect(e.result, expected);
      expect(e.state.result, expected);
      expect(e.result!.mode, ZReviewMode.whiteExam);
    });

    test('scoreWhiteExam (reducer pur) est déterministe et isolé', () {
      final r = scoreWhiteExam(<int>[5, 3, 2, 0, 4], passThreshold: 3);
      expect(r.total, 5);
      expect(r.correct, 3);
      expect(r.byQuality,
          <String, int>{'5': 1, '3': 1, '2': 1, '0': 1, '4': 1});
      expect(r.mode, ZReviewMode.whiteExam);
    });

    test('qualités répétées agrégées dans byQuality', () {
      final r = scoreWhiteExam(<int>[3, 3, 3, 1], passThreshold: 3);
      expect(r.total, 4);
      expect(r.correct, 3);
      expect(r.byQuality, <String, int>{'3': 3, '1': 1});
    });
  });

  group('AC5 — frontière correct/incorrect = passThreshold RÉUTILISÉ', () {
    test('passThreshold=4 sur [5,3,4] → correct:2 (5,4 ≥ 4 ; 3 en-deçà)', () {
      final e = _engine(
        <String>['A', 'B', 'C'],
        config: const ZSrsConfig(passThreshold: 4),
      );
      e.start();
      for (final q in <int>[5, 3, 4]) {
        e.answer(q);
      }
      e.submit();
      expect(e.result!.correct, 2);
      expect(e.result!.total, 3);
    });

    test('défaut passThreshold=3 sur [5,3,4] → correct:3', () {
      final e = _engine(<String>['A', 'B', 'C']);
      e.start();
      for (final q in <int>[5, 3, 4]) {
        e.answer(q);
      }
      e.submit();
      expect(e.result!.correct, 3);
    });
  });

  group('AC6 — scoring composable via ZExamScoringPort PUR, défaut fourni', () {
    test('scorer alternatif injecté est utilisé par submit()', () {
      ZStudySessionResult allCorrect(
        List<int> qualities, {
        required int passThreshold,
      }) =>
          ZStudySessionResult(
            mode: ZReviewMode.whiteExam,
            total: qualities.length,
            correct: qualities.length, // tout correct, ignore le seuil
          );

      final e = _engine(<String>['A', 'B'], scorer: allCorrect);
      e.start();
      e.answer(0);
      e.answer(0);
      e.submit();
      expect(e.result!.correct, 2,
          reason: 'submit() doit honorer le scorer injecté, pas coder en dur');
      expect(e.result!.total, 2);
    });

    test('défaut = scoreWhiteExam quand aucun scorer fourni', () {
      final e = ZWhiteExamSessionEngine(queue: _queue(<String>['A']));
      e.start();
      e.answer(0);
      e.submit();
      expect(e.result!.correct, 0, reason: 'scoreWhiteExam par défaut : 0 < 3');
    });
  });

  group('AC7 — granularité notifyListeners : une par transition effective', () {
    test('start + 3×answer + submit ⇒ exactement 5 notifications', () {
      final e = _engine(<String>['A', 'B', 'C']);
      var count = 0;
      void listener() => count += 1;
      e.addListener(listener);

      e.start();
      e.answer(5);
      e.answer(3);
      e.answer(1);
      e.submit();

      expect(count, 5);
      e.removeListener(listener);
    });
  });

  group('AC4b — examen COMPLET sans aucun seam SRS à injecter (par construction)',
      () {
    test('construction sans reviewer + run complet compile et s\'exécute', () {
      // Preuve de TYPE : le constructeur n'accepte AUCUN reviewer/scheduler.
      final e = ZWhiteExamSessionEngine(queue: _queue(<String>['A', 'B']));
      e.start();
      e.answer(4);
      e.answer(2);
      e.submit();
      expect(e.isSubmitted, isTrue);
      expect(e.result, isNotNull);
    });
  });
}
