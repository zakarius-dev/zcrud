/// Tests de proximité `ZExam` — PURES, TOTALES, DÉTERMINISTES, horloge INJECTÉE
/// (AC8, AC9).
///
/// 🔴 PUR `dart test` **ET** `dart test -p node` (JS-safe) : aucun `dart:io`.
/// L'horloge est un **littéral injecté** — tous les `DateTime` sont construits via
/// `DateTime.utc(...)` (arguments EXPLICITES), jamais `DateTime.now()` argless (non
/// déterministe, banni). C'est `DateTime.now()` qui est proscrit, PAS
/// `DateTime.utc(args)`.
library;

import 'package:test/test.dart';
import 'package:zcrud_exam/zcrud_exam.dart';

void main() {
  // Un examen daté au 2026-07-20, rappels [7, 1] jours avant, activés.
  const examWithReminders = ZExam(
    title: 'Examen',
    date: null, // remplacé ci-dessous par copyWith avec une date UTC littérale.
    reminderEnabled: true,
    reminderDaysBefore: <int>[7, 1],
  );
  final exam = examWithReminders.copyWith(date: DateTime.utc(2026, 7, 20));

  group('AC8 — méthodes TOTALES sur date == null', () {
    const noDate = ZExam(reminderEnabled: true, reminderDaysBefore: <int>[7]);
    final now = DateTime.utc(2026, 7, 15);
    test('daysUntil ⇒ null si date == null', () {
      expect(noDate.daysUntil(now), isNull);
    });
    test('isPast ⇒ false si date == null', () {
      expect(noDate.isPast(now), isFalse);
    });
    test('isApproaching ⇒ false si date == null', () {
      expect(noDate.isApproaching(now), isFalse);
    });
    test('isApproaching ⇒ false si reminderEnabled == false', () {
      final e = exam.copyWith(reminderEnabled: false);
      expect(e.isApproaching(DateTime.utc(2026, 7, 19)), isFalse);
    });
    test('isApproaching ⇒ false si reminderDaysBefore vide', () {
      final e = exam.copyWith(reminderDaysBefore: const <int>[]);
      expect(e.isApproaching(DateTime.utc(2026, 7, 19)), isFalse);
    });
  });

  group('AC9 — DÉTERMINISME (même now ⇒ même sortie)', () {
    test('deux appels daysUntil avec le MÊME now ⇒ MÊME valeur', () {
      final now = DateTime.utc(2026, 7, 20, 9, 0);
      expect(exam.daysUntil(now), equals(exam.daysUntil(now)));
    });
    test('la sortie ne dépend QUE de now + date (deux instances, même état)',
        () {
      final other = ZExam(
        title: 'Autre',
        date: DateTime.utc(2026, 7, 20),
        reminderEnabled: true,
        reminderDaysBefore: const <int>[7, 1],
      );
      final now = DateTime.utc(2026, 7, 19);
      expect(exam.daysUntil(now), equals(other.daysUntil(now)));
      expect(exam.isApproaching(now), equals(other.isApproaching(now)));
    });
  });

  group('AC9 — POUVOIR DISCRIMINANT OBSERVÉ (faire VARIER now)', () {
    // 🔴 Balayage {J-7, J-1, J0, J+1} avec le MÊME examen (date fixe au J0) :
    // sorties DISTINCTES. Une méthode qui IGNORERAIT `now` (ou appellerait
    // `DateTime.now()`) ne pourrait PAS produire ces 4 sorties. Le test le PROUVE.
    final jMinus7 = DateTime.utc(2026, 7, 13);
    final jMinus1 = DateTime.utc(2026, 7, 19);
    final j0 = DateTime.utc(2026, 7, 20);
    final jPlus1 = DateTime.utc(2026, 7, 21);

    test('daysUntil = {7, 1, 0, -1}', () {
      expect(exam.daysUntil(jMinus7), 7);
      expect(exam.daysUntil(jMinus1), 1);
      expect(exam.daysUntil(j0), 0);
      expect(exam.daysUntil(jPlus1), -1);
      // Sorties DISTINCTES (dépendance à now prouvée).
      final outputs = <int?>{
        exam.daysUntil(jMinus7),
        exam.daysUntil(jMinus1),
        exam.daysUntil(j0),
        exam.daysUntil(jPlus1),
      };
      expect(outputs, hasLength(4), reason: '4 valeurs de now ⇒ 4 sorties');
    });

    test('isPast = {false, false, false, true}', () {
      expect(exam.isPast(jMinus7), isFalse);
      expect(exam.isPast(jMinus1), isFalse);
      expect(exam.isPast(j0), isFalse, reason: 'le jour J n\'est pas passé');
      expect(exam.isPast(jPlus1), isTrue);
    });

    test('isApproaching = {true, true, true, false} (seuils [7, 1])', () {
      expect(exam.isApproaching(jMinus7), isTrue,
          reason: 'à J-7 le seuil 7 déclenche');
      expect(exam.isApproaching(jMinus1), isTrue);
      expect(exam.isApproaching(j0), isTrue);
      expect(exam.isApproaching(jPlus1), isFalse, reason: 'passé ⇒ plus de rappel');
    });

    test('un seuil sous J-7 ne déclenche pas encore à J-8', () {
      final jMinus8 = DateTime.utc(2026, 7, 12);
      expect(exam.daysUntil(jMinus8), 8);
      expect(exam.isApproaching(jMinus8), isFalse,
          reason: '8 > max(seuils)=7 ⇒ pas encore de rappel');
    });
  });

  group('AC8 — jours CALENDAIRES (heure de now ignorée)', () {
    test('daysUntil ignore l\'heure du jour de now', () {
      // Deux `now` le même jour calendaire à des heures différentes ⇒ même sortie.
      expect(exam.daysUntil(DateTime.utc(2026, 7, 19, 0, 1)),
          exam.daysUntil(DateTime.utc(2026, 7, 19, 23, 59)));
    });
  });
}
