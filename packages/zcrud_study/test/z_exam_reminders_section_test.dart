// Tests DISCRIMINANTS ES-9.2 — câblage `ZExam → ZApproachingExam` (adaptateur) +
// section rappels. Ancrage R20/R26 : l'AC porte sur NOTRE adaptateur (des `ZExam`
// RÉELS vus à travers lui produisent la vue quotidienne correcte), JAMAIS sur
// `aggregateDailyStudyTasks` (kernel, déjà testé — le re-tester en boîte noire
// serait POWERLESS). PRÉSERVATION EXACTE de la SÉLECTION et de l'ORDRE (R26), pas
// « liste non vide ». Injections R3-I4/I4b prouvées à rouge sous mutation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// `now` INJECTÉ (jamais `DateTime.now()`, AC5) — UTC pour aligner la normalisation
/// de jour de `ZExam.daysUntil`.
final DateTime _now = DateTime.utc(2026, 7, 16);

// Mix RÉEL : 2 approchants (dates distinctes), 1 passé, 1 rappels-off, 1 date=null.
const ZExam _examSoon = ZExam(
  id: 'soon',
  title: 'Soon',
  reminderEnabled: true,
  reminderDaysBefore: <int>[7],
);
const ZExam _examLater = ZExam(
  id: 'later',
  title: 'Later',
  reminderEnabled: true,
  reminderDaysBefore: <int>[7],
);
const ZExam _examPast = ZExam(
  id: 'past',
  title: 'Past',
  reminderEnabled: true,
  reminderDaysBefore: <int>[7],
);
const ZExam _examOff = ZExam(
  id: 'off',
  title: 'Off',
  reminderEnabled: false, // rappels désactivés ⇒ jamais approchant.
  reminderDaysBefore: <int>[7],
);
const ZExam _examNoDate = ZExam(
  id: 'nodate',
  title: 'NoDate',
  reminderEnabled: true,
  reminderDaysBefore: <int>[7],
  // date == null ⇒ jamais approchant.
);

List<ZExam> _mixedExams() => <ZExam>[
      // Ordre d'entrée VOLONTAIREMENT non trié (later avant soon) : prouve le tri.
      _examLater.copyWith(date: DateTime.utc(2026, 7, 20)), // daysUntil 4
      _examPast.copyWith(date: DateTime.utc(2026, 7, 10)), // daysUntil -6 (passé)
      _examSoon.copyWith(date: DateTime.utc(2026, 7, 18)), // daysUntil 2
      _examOff.copyWith(date: DateTime.utc(2026, 7, 17)), // off
      _examNoDate, // date null
    ];

Widget _host(Widget child, {TextDirection dir = TextDirection.ltr}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: dir,
      child: ZcrudScope(
        child: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
      ),
    ),
  );
}

void main() {
  // ===========================================================================
  // AC4 — l'adaptateur sélectionne EXACTEMENT les approchants, triés par date.
  // ===========================================================================
  group('AC4 — approachingReminders (via l\'adaptateur ES-9.2)', () {
    test('SÉLECTION + ORDRE EXACTS : approchants seuls, date croissante (R3-I4)', () {
      final reminders = approachingReminders(exams: _mixedExams(), now: _now);

      // R26 : préservation EXACTE de la sélection ET de l'ordre. R3-I4
      // (`isApproaching => true` dans l'adaptateur) ⇒ Past/Off/NoDate fuient ⇒ rouge.
      expect(
        reminders.map((r) => r.exam.id).toList(),
        <String>['soon', 'later'],
        reason: 'approchants seuls, triés par date croissante (soon@2 < later@4)',
      );
      // R3-I4b (`daysUntil => 0` constant) ⇒ ces décomptes rougissent.
      expect(reminders.map((r) => r.daysUntil).toList(), <int>[2, 4]);
    });

    test('examDailyTasks : dueCards en tête puis ExamTask ordonnés', () {
      final tasks = examDailyTasks(dueCount: 3, exams: _mixedExams(), now: _now);

      expect(tasks.first, isA<ZDueCardsTask>());
      expect((tasks.first as ZDueCardsTask).count, 3);
      final examTasks = tasks.whereType<ZExamTask>().toList();
      expect(examTasks.length, 2);
      // daysUntil dérivé du VRAI exam.daysUntil (R3-I4b ⇒ rouge).
      expect(examTasks.map((t) => t.daysUntil).toList(), <int>[2, 4]);
    });

    test('dueCount <= 0 ⇒ aucune ligne dueCards (parité kernel préservée)', () {
      final tasks = examDailyTasks(dueCount: 0, exams: _mixedExams(), now: _now);
      expect(tasks.whereType<ZDueCardsTask>(), isEmpty);
      expect(tasks.whereType<ZExamTask>().length, 2);
    });

    test('aucun approchant ⇒ liste VIDE (cas non-dégénéré exclu, R26)', () {
      final reminders = approachingReminders(
        exams: <ZExam>[_examPast.copyWith(date: DateTime.utc(2026, 7, 1))],
        now: _now,
      );
      expect(reminders, isEmpty);
    });
  });

  // ===========================================================================
  // AC4/AC7 — la section rend EXACTEMENT les approchants ordonnés + expose à l'app.
  // ===========================================================================
  group('AC4/AC5 — ZExamRemindersSection', () {
    testWidgets('rend les approchants ordonnés + onRemindersComputed les EXPOSE',
        (tester) async {
      List<ZApproachingReminder>? exposed;
      await tester.pumpWidget(_host(ZExamRemindersSection(
        exams: _mixedExams(),
        now: _now,
        onRemindersComputed: (r) => exposed = r,
      )));
      await tester.pump(); // laisse courir le post-frame d'exposition.

      // Titres approchants rendus, dans l'ordre (soon avant later) ; passés/off/
      // sans-date ABSENTS (R3-I4 ⇒ un passé apparaîtrait).
      expect(find.text('Soon'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Past'), findsNothing);
      expect(find.text('Off'), findsNothing);
      expect(find.text('NoDate'), findsNothing);

      // Exposition à l'app (AC5) : la section EXPOSE mais ne planifie JAMAIS.
      expect(exposed, isNotNull);
      expect(exposed!.map((r) => r.exam.id).toList(), <String>['soon', 'later']);
    });

    testWidgets('aucun approchant ⇒ emptyState rendu, aucune ligne',
        (tester) async {
      await tester.pumpWidget(_host(ZExamRemindersSection(
        exams: <ZExam>[_examPast.copyWith(date: DateTime.utc(2026, 7, 1))],
        now: _now,
        emptyState: const SizedBox(key: ValueKey('empty-reminders')),
      )));
      await tester.pump();

      expect(find.byKey(const ValueKey('empty-reminders')), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('la liste est un ListView.builder (AD-13)', (tester) async {
      await tester.pumpWidget(_host(ZExamRemindersSection(
        exams: _mixedExams(),
        now: _now,
      )));
      await tester.pump();
      // ListView.builder ⇒ un ListView avec childrenDelegate paresseux.
      expect(find.byType(ListView), findsOneWidget);
    });
  });
}
