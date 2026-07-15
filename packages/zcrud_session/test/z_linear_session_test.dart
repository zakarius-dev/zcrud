/// Golden LINÉAIRE (`ZLinearSessionState`) — ES-4.3, AC3/AC4/AC5/AC6/AC7.
///
/// Pouvoir discriminant (R12) : ces goldens FIGENT la progression list (ordre &
/// curseur gelés, AC3) et cramming (re-boucle +2/+4 gelée, AC4) en littéraux ⇒
/// tout écart d'offset/curseur/ré-insertion ROUGIT (INJ-2/INJ-4).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

ZSessionItem _item(String id) => ZSessionItem(flashcardId: id, folderId: 'f');

List<ZSessionItem> _queue(List<String> ids) => ids.map(_item).toList();

List<String> _ids(ZSessionState state) =>
    state.queue.map((e) => e.flashcardId).toList();

void main() {
  group('AC3 — mode list : progression linéaire stricte, ordre & curseur gelés',
      () {
    test('séquence current [A..F], curseur 0→6, reviewed 1..6, isComplete@6',
        () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B', 'C', 'D', 'E', 'F']),
        mode: ZReviewMode.list,
      );

      final currentSeq = <String>[];
      final cursorSeq = <int>[];
      final reviewedSeq = <int>[];

      while (!s.isComplete) {
        currentSeq.add(s.current!.flashcardId);
        s.advance();
        cursorSeq.add(s.state.cursor);
        reviewedSeq.add(s.reviewed);
      }

      expect(currentSeq, <String>['A', 'B', 'C', 'D', 'E', 'F']);
      expect(cursorSeq, <int>[1, 2, 3, 4, 5, 6]);
      expect(reviewedSeq, <int>[1, 2, 3, 4, 5, 6]);
      expect(s.isComplete, isTrue);
      expect(s.current, isNull);
      expect(s.lapses, 0, reason: 'le mode list ne re-boucle jamais');
      // La file n'est JAMAIS ré-ordonnée ni tronquée en mode list.
      expect(_ids(s.state), <String>['A', 'B', 'C', 'D', 'E', 'F']);
    });

    test('advance() ignore la quality (answer délègue à advanceLinear)', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B']),
        mode: ZReviewMode.list,
      );
      s.answer(0); // quality ignorée en mode list
      expect(s.current!.flashcardId, 'B');
      expect(s.reviewed, 1);
      expect(s.lapses, 0);
      expect(_ids(s.state), <String>['A', 'B']);
    });
  });

  group('AC4 — mode cramming : re-boucle des ratés +2/+4, ordre gelé', () {
    test('lapse léger (+2) puis lapse dur (+4), positions figées', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B', 'C', 'D', 'E', 'F']),
        mode: ZReviewMode.cramming,
      );

      // answer(A, q=1) → lapse léger, A réapparaît 2ᵉ carte à venir (+2).
      s.answer(1);
      expect(_ids(s.state), <String>['B', 'A', 'C', 'D', 'E', 'F']);
      expect(s.lapses, 1);
      expect(s.reviewed, 0, reason: 'un lapse ne consomme pas la carte');
      expect(s.current!.flashcardId, 'B');

      // answer(B, q=2) → lapse dur, B réapparaît 4ᵉ carte à venir (+4).
      s.answer(2);
      expect(_ids(s.state), <String>['A', 'C', 'D', 'B', 'E', 'F']);
      expect(s.lapses, 2);
      expect(s.reviewed, 0);
      expect(s.current!.flashcardId, 'A');
    });

    test('réussite (q≥passThreshold) consomme la carte, pas de ré-insertion',
        () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B', 'C']),
        mode: ZReviewMode.cramming,
      );
      s.answer(3); // réussite → A consommée
      expect(_ids(s.state), <String>['B', 'C']);
      expect(s.reviewed, 1);
      expect(s.lapses, 0);
      expect(s.current!.flashcardId, 'B');
    });

    test('clamp fin de file : +4 avec < 4 cartes à venir ⇒ ré-insertion en fin',
        () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['X', 'Y', 'Z']),
        mode: ZReviewMode.cramming,
      );
      s.answer(2); // lapse dur (+4) mais seulement 2 cartes à venir ⇒ clamp fin
      expect(_ids(s.state), <String>['Y', 'Z', 'X']);
      expect(s.lapses, 1);
    });

    test('session cramming COMPLÈTE se vide (isComplete par consommation)', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B']),
        mode: ZReviewMode.cramming,
      );
      s.answer(5); // A consommée
      s.answer(5); // B consommée
      expect(s.isComplete, isTrue);
      expect(s.current, isNull);
      expect(s.reviewed, 2);
    });
  });

  group('AC5 — seuil cramming = passThreshold réutilisé, pas un littéral', () {
    test('passThreshold custom (=4) : q=3 est un lapse (re-bouclé)', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B', 'C']),
        mode: ZReviewMode.cramming,
        config: const ZSrsConfig(passThreshold: 4),
      );
      s.answer(3); // 3 < 4 ⇒ lapse ⇒ re-boucle (A NON consommée)
      expect(s.lapses, 1);
      expect(s.reviewed, 0);
      expect(_ids(s.state), <String>['B', 'C', 'A'],
          reason: 'q=3 > kLapseSoftMaxQuality(1) → offset +4 ; 2 cartes à venir '
              '⇒ insertIndex min(0+4-1,2)=2 ⇒ ré-insertion en fin [B,C,A]');
    });

    test('passThreshold défaut (=3) : q=3 est une réussite (consommée)', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B', 'C']),
        mode: ZReviewMode.cramming,
      );
      s.answer(3); // 3 >= 3 ⇒ réussite ⇒ consommée
      expect(s.lapses, 0);
      expect(s.reviewed, 1);
      expect(_ids(s.state), <String>['B', 'C']);
    });
  });

  group('AC6 — modes SRS/examen refusés par le constructeur (assert)', () {
    for (final mode in <ZReviewMode>[
      ZReviewMode.spaced,
      ZReviewMode.learn,
      ZReviewMode.whiteExam,
      ZReviewMode.test,
    ]) {
      test('mode $mode déclenche un AssertionError', () {
        expect(
          () => ZLinearSessionState(
            queue: _queue(<String>['A']),
            mode: mode,
          ),
          throwsA(isA<AssertionError>()),
        );
      });
    }

    test('modes list/cramming acceptés', () {
      expect(
        () => ZLinearSessionState(
          queue: _queue(<String>['A']),
          mode: ZReviewMode.list,
        ),
        returnsNormally,
      );
      expect(
        () => ZLinearSessionState(
          queue: _queue(<String>['A']),
          mode: ZReviewMode.cramming,
        ),
        returnsNormally,
      );
    });
  });

  group('AC7 — notification granulaire : 1 par transition, 0 sur no-op', () {
    test('mode list : une notif par advance, zéro sur session complète', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A', 'B']),
        mode: ZReviewMode.list,
      );
      var count = 0;
      s.addListener(() => count++);

      s.advance(); // A → 1
      s.advance(); // B → 2
      expect(count, 2);
      expect(s.isComplete, isTrue);

      s.advance(); // no-op (complète) ⇒ aucune notif
      expect(count, 2, reason: 'aucune notification sur no-op');
    });

    test('mode cramming : une notif par answer effectif, zéro sur no-op', () {
      final s = ZLinearSessionState(
        queue: _queue(<String>['A']),
        mode: ZReviewMode.cramming,
      );
      var count = 0;
      s.addListener(() => count++);

      s.answer(5); // A consommée → 1
      expect(count, 1);
      expect(s.isComplete, isTrue);

      s.answer(5); // no-op (complète) ⇒ aucune notif
      expect(count, 1);
    });
  });

  group('AC1 — pureté du type', () {
    test('ZLinearSessionState est un ChangeNotifier (Flutter-native)', () {
      final s = ZLinearSessionState(queue: _queue(<String>['A']));
      expect(s, isA<ChangeNotifier>());
      expect(s.state.mode, ZReviewMode.list, reason: 'mode par défaut = list');
    });
  });
}
