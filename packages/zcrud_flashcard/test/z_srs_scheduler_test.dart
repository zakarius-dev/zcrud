/// Tests du sous-système SRS (Story E9-2) : algorithme SuperMemo-2
/// (`ZSm2Scheduler`), interface remplaçable (`ZSrsScheduler`), config injectable
/// (`ZSrsConfig`), clamp qualité, bornes `easeFactor`, voie d'écriture unique.
///
/// Horloge **injectée fixée** pour un déterminisme total des `nextReviewDate`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Horloge fixe déterministe (UTC).
final DateTime kNow = DateTime.utc(2026, 1, 1);

void main() {
  const scheduler = ZSm2Scheduler();

  group('ZSm2Scheduler.initial (AC3/AC4)', () {
    test('état neuf déterministe : compteurs à zéro, ease=défaut, dates null',
        () {
      final info = scheduler.initial(flashcardId: 'c1', folderId: 'f1');
      expect(info.flashcardId, 'c1');
      expect(info.folderId, 'f1');
      expect(info.interval, 0);
      expect(info.repetitions, 0);
      expect(info.easeFactor, ZSrsConfig.kDefaultEaseFactor);
      expect(info.nextReviewDate, isNull);
      expect(info.learnedAt, isNull);
      expect(info.lastQuality, isNull);
    });

    test('initial respecte le defaultEaseFactor de la config injectée', () {
      const custom = ZSm2Scheduler(config: ZSrsConfig(defaultEaseFactor: 2.1));
      final info = custom.initial(flashcardId: 'c', folderId: 'f');
      expect(info.easeFactor, 2.1);
    });
  });

  group('Courbe SM-2 multi-révisions, q=5 (AC4)', () {
    test('interval suit 1, 6, puis round(prev*ef) croissant ; ease plafonne',
        () {
      var info = scheduler.initial(flashcardId: 'c', folderId: 'f');

      // 1re réussite : interval = 1, repetitions = 1.
      info = scheduler.apply(info, 5, now: kNow);
      expect(info.interval, 1);
      expect(info.repetitions, 1);
      expect(info.easeFactor, 2.5); // déjà au plafond (défaut = max).
      expect(info.nextReviewDate, kNow.add(const Duration(days: 1)));
      expect(info.learnedAt, kNow); // 1re réussite.
      expect(info.lastQuality, 5);

      // 2e réussite : interval = 6, repetitions = 2.
      info = scheduler.apply(info, 5, now: kNow);
      expect(info.interval, 6);
      expect(info.repetitions, 2);
      expect(info.nextReviewDate, kNow.add(const Duration(days: 6)));

      // 3e : interval = round(6 * 2.5 * 1.0) = 15.
      info = scheduler.apply(info, 5, now: kNow);
      expect(info.interval, 15);
      expect(info.repetitions, 3);

      // 4e : interval = round(15 * 2.5) = 38 (croissance monotone).
      info = scheduler.apply(info, 5, now: kNow);
      expect(info.interval, 38);
      expect(info.repetitions, 4);
    });

    test('easeFactor CROÎT puis PLAFONNE à maxEaseFactor (2.5)', () {
      // Part d'un état à ease abaissé pour observer la croissance jusqu'au cap.
      var info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      info = scheduler.apply(info, 3, now: kNow); // q=3 fait décroître l'ease.
      final lowered = info.easeFactor;
      expect(lowered, lessThan(2.5));

      // Suite de q=5 : ease remonte de +0.1 puis PLAFONNE à 2.5.
      var prev = lowered;
      for (var i = 0; i < 10; i++) {
        info = scheduler.apply(info, 5, now: kNow);
        expect(info.easeFactor, greaterThanOrEqualTo(prev));
        expect(info.easeFactor, lessThanOrEqualTo(2.5));
        prev = info.easeFactor;
      }
      expect(info.easeFactor, 2.5); // plafonné.
    });
  });

  group('Bornes easeFactor & lapse (AC4)', () {
    test('suite de q=3 : easeFactor DÉCROÎT et PLANCHER à minEaseFactor (1.3)',
        () {
      var info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      var prev = info.easeFactor;
      for (var i = 0; i < 20; i++) {
        info = scheduler.apply(info, 3, now: kNow);
        expect(info.easeFactor, lessThanOrEqualTo(prev));
        expect(info.easeFactor, greaterThanOrEqualTo(1.3));
        prev = info.easeFactor;
      }
      expect(info.easeFactor, 1.3); // plancher atteint.
    });

    test('lapse (q<3) : repetitions=0, interval=1, learnedAt PRÉSERVÉ', () {
      var info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      info = scheduler.apply(info, 5, now: kNow); // réussite → learnedAt fixé.
      info = scheduler.apply(info, 5, now: kNow);
      final learned = info.learnedAt;
      expect(learned, isNotNull);
      expect(info.repetitions, 2);

      info = scheduler.apply(info, 1, now: kNow); // lapse.
      expect(info.repetitions, 0);
      expect(info.interval, 1);
      expect(info.learnedAt, learned); // JAMAIS remis à null (AC4).
      expect(info.nextReviewDate, kNow.add(const Duration(days: 1)));
    });

    test('learnedAt reste null tant qu\'aucune réussite (lapses répétés)', () {
      var info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      info = scheduler.apply(info, 2, now: kNow);
      info = scheduler.apply(info, 0, now: kNow);
      expect(info.learnedAt, isNull);
    });
  });

  group('Qualité 0..5 défensive, aucun throw (AC6)', () {
    test('apply(info, -3) == apply(info, 0) (lapse)', () {
      final info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      final neg = scheduler.apply(info, -3, now: kNow);
      final zero = scheduler.apply(info, 0, now: kNow);
      expect(neg, zero);
      expect(neg.lastQuality, 0);
    });

    test('apply(info, 99) == apply(info, 5) (réussite maximale)', () {
      final info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      final big = scheduler.apply(info, 99, now: kNow);
      final five = scheduler.apply(info, 5, now: kNow);
      expect(big, five);
      expect(big.lastQuality, 5);
    });

    test('aucune exception sur qualité hors bornes', () {
      final info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      expect(() => scheduler.apply(info, -100, now: kNow), returnsNormally);
      expect(() => scheduler.apply(info, 1000, now: kNow), returnsNormally);
      expect(() => scheduler.simulate(info, -1, now: kNow), returnsNormally);
    });
  });

  group('ZSrsConfig injectée change le planning (AC5)', () {
    test('defaultIntervalModifier: 2.0 double la croissance d\'intervalle', () {
      const fast = ZSm2Scheduler(config: ZSrsConfig(defaultIntervalModifier: 2.0));
      var a = scheduler.initial(flashcardId: 'c', folderId: 'f');
      var b = fast.initial(flashcardId: 'c', folderId: 'f');
      for (var i = 0; i < 3; i++) {
        a = scheduler.apply(a, 5, now: kNow);
        b = fast.apply(b, 5, now: kNow);
      }
      // Au 3e pas : default = round(6*2.5*1.0)=15 ; fast = round(6*2.5*2.0)=30.
      expect(a.interval, 15);
      expect(b.interval, 30);
      expect(b.interval, greaterThan(a.interval));
    });

    test('maxEaseFactor abaissé change le clamp du facteur de facilité', () {
      const capped = ZSm2Scheduler(
        config: ZSrsConfig(defaultEaseFactor: 2.0, maxEaseFactor: 2.0),
      );
      var info = capped.initial(flashcardId: 'c', folderId: 'f');
      for (var i = 0; i < 5; i++) {
        info = capped.apply(info, 5, now: kNow);
      }
      expect(info.easeFactor, 2.0); // plafonné à la borne custom.
    });

    test('passThreshold custom modifie le seuil réussite/lapse', () {
      // Seuil relevé à 4 : q=3 devient un LAPSE.
      const strict = ZSm2Scheduler(config: ZSrsConfig(passThreshold: 4));
      final info = strict.initial(flashcardId: 'c', folderId: 'f');
      final r = strict.apply(info, 3, now: kNow);
      expect(r.repetitions, 0); // traité comme lapse.
      expect(r.learnedAt, isNull);
    });
  });

  group('Interface REMPLAÇABLE — scheduler alternatif (AC3, FR-17)', () {
    test('un scheduler Leitner-like substitué produit un planning DIFFÉRENT',
        () {
      final ZSrsScheduler alt = _FixedStepScheduler();
      var sm2 = scheduler.initial(flashcardId: 'c', folderId: 'f');
      var lei = alt.initial(flashcardId: 'c', folderId: 'f');
      for (var i = 0; i < 4; i++) {
        sm2 = scheduler.apply(sm2, 5, now: kNow);
        lei = alt.apply(lei, 5, now: kNow);
      }
      // SM-2 : 1,6,15,38. Leitner-like fixe : 1,2,3,4.
      expect(sm2.interval, 38);
      expect(lei.interval, 4);
      expect(lei.interval, isNot(sm2.interval)); // remplaçabilité prouvée.
      // Le type stocké (ZRepetitionInfo) est identique — modèles NON touchés.
      expect(lei, isA<ZRepetitionInfo>());
    });
  });

  group('simulate = projection sans persistance (AC3)', () {
    test('simulate retourne l\'état projeté (identique à apply, pur)', () {
      final info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      final sim = scheduler.simulate(info, 4, now: kNow);
      final app = scheduler.apply(info, 4, now: kNow);
      expect(sim, app);
      // L'état source n'est pas muté (immuabilité).
      expect(info.repetitions, 0);
    });
  });

  group('Voie d\'écriture UNIQUE (AC7)', () {
    test('deux apply successifs = courbe SM-2 cohérente (seul chemin public)',
        () {
      var info = scheduler.initial(flashcardId: 'c', folderId: 'f');
      info = scheduler.apply(info, 4, now: kNow);
      final afterFirst = info;
      info = scheduler.apply(info, 4, now: kNow);
      // La seule façon d'avancer est apply : chaque appel produit une NOUVELLE
      // instance (immuabilité), l'ancienne reste inchangée.
      expect(afterFirst.repetitions, 1);
      expect(info.repetitions, 2);
      expect(identical(afterFirst, info), isFalse);
    });
  });
}

/// Scheduler alternatif de TEST (Leitner-like à pas fixe) : prouve la
/// remplaçabilité de [ZSrsScheduler] sans toucher `ZRepetitionInfo` (FR-17).
/// Intervalle = repetitions (1,2,3,…), aucune notion d'easeFactor.
class _FixedStepScheduler implements ZSrsScheduler {
  @override
  ZRepetitionInfo apply(ZRepetitionInfo current, int quality, {DateTime? now}) {
    final effectiveNow = now ?? DateTime.now();
    final q = quality.clamp(0, 5);
    final passed = q >= 3;
    final repetitions = passed ? current.repetitions + 1 : 0;
    final interval = passed ? repetitions : 1;
    return ZRepetitionInfo(
      flashcardId: current.flashcardId,
      folderId: current.folderId,
      interval: interval,
      repetitions: repetitions,
      easeFactor: current.easeFactor,
      nextReviewDate: effectiveNow.add(Duration(days: interval)),
      learnedAt: current.learnedAt ?? (passed ? effectiveNow : null),
      lastQuality: q,
    );
  }

  @override
  ZRepetitionInfo simulate(ZRepetitionInfo current, int quality,
          {DateTime? now}) =>
      apply(current, quality, now: now);

  @override
  ZRepetitionInfo initial({
    required String flashcardId,
    required String folderId,
  }) =>
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId);
}
