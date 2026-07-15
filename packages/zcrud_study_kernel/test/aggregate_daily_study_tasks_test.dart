/// Tests `aggregateDailyStudyTasks` (ES-2.7, AC7–AC11) — PURE, TOTALE,
/// DÉTERMINISTE, horloge injectée, tri STABLE.
///
/// 🔴 Pouvoir discriminant OBSERVÉ (anti-golden-fortuit) : on fait VARIER `now`
/// et l'ordre d'entrée pour PROUVER que la sortie en dépend (leçon ES-2.3), et le
/// tri stable est éprouvé sur **40 examens de même date** (au-dessus du seuil
/// insertion-sort ⇒ quicksort INSTABLE sans tie-breaker — le test MORD).
///
/// Littéraux `DateTime.utc(...)` JS-safe, **aucun `dart:io`** (gate:web AC15).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('AC7 — contrat ordre/filtre (dues en tête, exams triés après)', () {
    test('dues en tête PUIS examens approchants par date croissante', () {
      final examLoin = _Fake(id: 'loin', date: DateTime.utc(2026, 7, 25));
      final examProche = _Fake(id: 'proche', date: DateTime.utc(2026, 7, 20));
      final now = DateTime.utc(2026, 7, 19);
      final tasks = aggregateDailyStudyTasks(
        dueCount: 4,
        exams: <ZApproachingExam>[examLoin, examProche], // ordre d'entrée = loin, proche
        now: now,
      );
      expect(tasks.length, 3);
      expect(tasks[0], const ZDueCardsTask(4));
      expect(tasks[1], isA<ZExamTask>());
      expect((tasks[1] as ZExamTask).exam, examProche); // le plus proche d'abord
      expect((tasks[2] as ZExamTask).exam, examLoin);
    });

    test('les non-approchants sont EXCLUS (rappels désactivés / passés)', () {
      final actif = _Fake(id: 'actif', date: DateTime.utc(2026, 7, 20));
      final desactive = _Fake(
        id: 'off',
        date: DateTime.utc(2026, 7, 20),
        reminderEnabled: false,
      );
      final passe = _Fake(id: 'passe', date: DateTime.utc(2026, 7, 1));
      final now = DateTime.utc(2026, 7, 19);
      final tasks = aggregateDailyStudyTasks(
        dueCount: 0,
        exams: <ZApproachingExam>[actif, desactive, passe],
        now: now,
      );
      expect(tasks.length, 1);
      expect((tasks.single as ZExamTask).exam, actif);
    });
  });

  group('AC8 — DÉTERMINISME + DÉPENDANCE à `now` (anti-DateTime.now()-caché)',
      () {
    test('même now + même entrée ⇒ sorties égales (élément par élément)', () {
      final e = _Fake(id: 'e', date: DateTime.utc(2026, 7, 20));
      final now = DateTime.utc(2026, 7, 19, 9, 0);
      final a = aggregateDailyStudyTasks(dueCount: 2, exams: [e], now: now);
      final b = aggregateDailyStudyTasks(dueCount: 2, exams: [e], now: now);
      expect(a, b);
    });

    test('BALAYAGE D\'HORLOGE — sorties DISTINCTES selon `now` (J-7…J+1)', () {
      // date=07-20, reminderDaysBefore=[7,1] ⇒ présent J-7..J0, absent J+1.
      final e = _Fake(id: 'e', date: DateTime.utc(2026, 7, 20));
      ZExamTask? examTask(DateTime now) {
        final tasks = aggregateDailyStudyTasks(dueCount: 0, exams: [e], now: now);
        return tasks.isEmpty ? null : tasks.single as ZExamTask;
      }

      expect(examTask(DateTime.utc(2026, 7, 13))?.daysUntil, 7); // J-7
      expect(examTask(DateTime.utc(2026, 7, 19))?.daysUntil, 1); // J-1
      expect(examTask(DateTime.utc(2026, 7, 20))?.daysUntil, 0); // J0
      expect(examTask(DateTime.utc(2026, 7, 21)), isNull); // J+1 : passé, ABSENT
    });

    test('FRONTIÈRE DE JOUR — minuit UTC de part et d\'autre (D4)', () {
      final e = _Fake(id: 'e', date: DateTime.utc(2026, 7, 20));
      ZExamTask? examTask(DateTime now) {
        final tasks = aggregateDailyStudyTasks(dueCount: 0, exams: [e], now: now);
        return tasks.isEmpty ? null : tasks.single as ZExamTask;
      }

      // Avant minuit UTC du 20 : encore 1 jour (à venir, présent).
      expect(examTask(DateTime.utc(2026, 7, 19, 23, 59))?.daysUntil, 1);
      // Après minuit UTC du 20 : jour J (présent).
      expect(examTask(DateTime.utc(2026, 7, 20, 0, 1))?.daysUntil, 0);
      // Le lendemain : passé, ABSENT.
      expect(examTask(DateTime.utc(2026, 7, 21, 0, 1)), isNull);
    });
  });

  group('AC9 — dueCount source unique, jamais recalculé, borné à > 0', () {
    final now = DateTime.utc(2026, 7, 19);

    test('dueCount 0 + aucun exam ⇒ const []', () {
      expect(
        aggregateDailyStudyTasks(dueCount: 0, exams: const [], now: now),
        <ZDailyStudyTask>[],
      );
    });

    test('dueCount 3 ⇒ [ZDueCardsTask(3)] (count verbatim, en tête)', () {
      final tasks =
          aggregateDailyStudyTasks(dueCount: 3, exams: const [], now: now);
      expect(tasks, <ZDailyStudyTask>[const ZDueCardsTask(3)]);
    });

    test('dueCount négatif ⇒ aucun ZDueCardsTask', () {
      final tasks =
          aggregateDailyStudyTasks(dueCount: -1, exams: const [], now: now);
      expect(tasks.whereType<ZDueCardsTask>(), isEmpty);
    });
  });

  group('AC10 — tri STABLE et DÉTERMINISTE sur date ÉGALE (D5)', () {
    final now = DateTime.utc(2026, 7, 19);

    test('dates DIFFÉRENTES ⇒ TOUJOURS [plus-proche, plus-loin]', () {
      final d1 = _Fake(id: 'd1', date: DateTime.utc(2026, 7, 20));
      final d2 = _Fake(id: 'd2', date: DateTime.utc(2026, 7, 25));
      for (final entree in <List<ZApproachingExam>>[
        [d1, d2],
        [d2, d1], // ordre d'entrée inversé : sortie identique (par date)
      ]) {
        final tasks =
            aggregateDailyStudyTasks(dueCount: 0, exams: entree, now: now);
        expect((tasks[0] as ZExamTask).exam, d1);
        expect((tasks[1] as ZExamTask).exam, d2);
      }
    });

    test('date ÉGALE ⇒ ordre d\'ENTRÉE préservé (règle documentée)', () {
      final a = _Fake(id: 'a', date: DateTime.utc(2026, 7, 20));
      final b = _Fake(id: 'b', date: DateTime.utc(2026, 7, 20));
      final ab =
          aggregateDailyStudyTasks(dueCount: 0, exams: [a, b], now: now);
      expect((ab[0] as ZExamTask).exam, a);
      expect((ab[1] as ZExamTask).exam, b);
      // Entrée inversée : sortie cohérente avec la stabilité (ordre d'entrée).
      final ba =
          aggregateDailyStudyTasks(dueCount: 0, exams: [b, a], now: now);
      expect((ba[0] as ZExamTask).exam, b);
      expect((ba[1] as ZExamTask).exam, a);
    });

    test(
        'POUVOIR DISCRIMINANT — 40 examens de MÊME date : ordre d\'entrée '
        'préservé (sans tie-breaker, le quicksort les PERMUTERAIT)', () {
      // n=40 > seuil insertion-sort (33) ⇒ `List.sort` nu est INSTABLE ici.
      // Le tie-breaker d'index (D5) garantit malgré tout l'ordre d'entrée.
      final exams = <ZApproachingExam>[
        for (var i = 0; i < 40; i++)
          _Fake(
            id: i.toString().padLeft(2, '0'),
            date: DateTime.utc(2026, 7, 20),
          ),
      ];
      final tasks =
          aggregateDailyStudyTasks(dueCount: 0, exams: exams, now: now);
      final outIds = <String>[
        for (final t in tasks) ((t as ZExamTask).exam as _Fake).id,
      ];
      final inIds = <String>[for (final e in exams) (e as _Fake).id];
      expect(outIds, inIds); // ordre d'entrée EXACTEMENT préservé
    });
  });

  group('AC11 — totalité / défensif (AD-10, D6)', () {
    final now = DateTime.utc(2026, 7, 19);

    test('aggregate(dueCount:0, exams:[]) ⇒ const [] (jamais de throw)', () {
      expect(
        aggregateDailyStudyTasks(dueCount: 0, exams: const [], now: now),
        isEmpty,
      );
    });

    test('aucun exam approchant + dueCount>0 ⇒ [ZDueCardsTask] seul', () {
      final passe = _Fake(id: 'p', date: DateTime.utc(2026, 1, 1));
      final tasks =
          aggregateDailyStudyTasks(dueCount: 2, exams: [passe], now: now);
      expect(tasks, <ZDailyStudyTask>[const ZDueCardsTask(2)]);
    });

    test('un now quelconque ne throw jamais (exam date null toléré)', () {
      final sansDate = _Fake(id: 'x', date: null, approaching: false);
      expect(
        () => aggregateDailyStudyTasks(
          dueCount: 0,
          exams: [sansDate],
          now: DateTime.utc(2030, 12, 31),
        ),
        returnsNormally,
      );
    });
  });
}

/// Double local — forme identique à `ZExam` (D3/D10), aucun import satellite.
class _Fake implements ZApproachingExam {
  _Fake({
    required this.date,
    this.id = '',
    bool? approaching,
    this.reminderEnabled = true,
  }) : _forced = approaching;

  final String id;
  @override
  final DateTime? date;
  final bool? _forced;
  final bool reminderEnabled;
  static const List<int> reminderDaysBefore = <int>[7, 1];

  @override
  int? daysUntil(DateTime now) {
    final d = date;
    if (d == null) return null;
    final target = DateTime.utc(d.year, d.month, d.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  @override
  bool isApproaching(DateTime now) {
    if (_forced != null) return _forced;
    if (!reminderEnabled) return false;
    final delta = daysUntil(now);
    if (delta == null || delta < 0) return false;
    return reminderDaysBefore.any((threshold) => delta <= threshold);
  }
}
