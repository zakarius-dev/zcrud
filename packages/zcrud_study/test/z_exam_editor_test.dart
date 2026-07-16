// Tests DISCRIMINANTS ES-9.2 — `ZExamEditor` : adaptateur MINCE composant `ZExam`
// (ES-2.6, `zcrud_exam`, pur-Dart, déjà testé). Ancrage R20/R24 : les assertions
// portent sur l'`exam` ÉMIS par l'éditeur (PRÉSERVATION EXACTE de la saisie), JAMAIS
// sur la (dé)sérialisation de `ZExam` (re-tester `fromMap(toMap())` en boîte noire
// serait POWERLESS). R26 : préservation EXACTE (égalité de valeur), jamais « non
// vide ». Injections R3-I1/I1b/I2/I3 prouvées à rouge sous mutation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_study/zcrud_study.dart';

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

/// Pilote la saisie complète d'un examen non-dégénéré et rend l'`exam` émis.
Future<ZExam> _driveFullEntry(
  WidgetTester tester, {
  required String title,
  required DateTime date,
  required List<int> thresholds,
  required ZReminderTime time,
}) async {
  ZExam? emitted;
  await tester.pumpWidget(_host(ZExamEditor(
    onSubmit: (e) => emitted = e,
    folderId: 'f1',
    onPickDate: (_) async => date,
    onPickTime: (_) async => time,
    addThresholdSemanticLabel: 'ADD-THRESHOLD',
  )));
  await tester.pump();

  // Titre.
  await tester.enterText(find.byType(TextField).at(0), title);
  // Date (picker INJECTÉ — TextButton.at(0)).
  await tester.tap(find.byType(TextButton).at(0));
  await tester.pump();
  await tester.pump();
  // Activer les rappels.
  await tester.tap(find.byType(Switch));
  await tester.pump();
  // Seuils dans l'ORDRE saisi (doublons inclus) : champ seuil = TextField.at(1).
  for (final t in thresholds) {
    await tester.enterText(find.byType(TextField).at(1), '$t');
    await tester.tap(find.byTooltip('ADD-THRESHOLD'));
    await tester.pump();
  }
  // Heure (picker INJECTÉ — TextButton.at(1)).
  await tester.tap(find.byType(TextButton).at(1));
  await tester.pump();
  await tester.pump();
  // Valider.
  await tester.tap(find.byType(ElevatedButton));
  await tester.pump();

  expect(emitted, isNotNull, reason: 'onSubmit doit émettre un ZExam');
  return emitted!;
}

void main() {
  // ===========================================================================
  // AC1 — PRÉSERVATION EXACTE de la saisie + id == null (AD-14, R26).
  // ===========================================================================
  group('AC1 — émission à saisie préservée', () {
    testWidgets('chaque champ saisi survit à l\'identique, id == null (R3-I1/I1b)',
        (tester) async {
      final date = DateTime.utc(2026, 8, 1);
      const time = ZReminderTime(hour: 8, minute: 5);
      final exam = await _driveFullEntry(
        tester,
        title: 'Examen Final',
        date: date,
        thresholds: <int>[7, 1],
        time: time,
      );

      // R26 : égalité de valeur EXACTE sur l'`exam` composé attendu. R3-I1 (émettre
      // un ZExam() défaut ou dropper un champ) ⇒ cette égalité rouge. R3-I1b (id
      // non-null) ⇒ `id == null` rouge.
      expect(
        exam,
        const ZExam(
          folderId: 'f1',
          title: 'Examen Final',
          reminderEnabled: true,
          reminderDaysBefore: <int>[7, 1],
          reminderTime: time,
        ).copyWith(date: date),
      );
      expect(exam.id, isNull, reason: 'AD-14 : id matérialisé au repository (ES-3)');
      // Non-dégénéré : au moins un seuil, une heure non-null, un titre non-vide.
      expect(exam.title.isNotEmpty, isTrue);
      expect(exam.reminderDaysBefore, isNotEmpty);
      expect(exam.reminderTime, isNotNull);
    });

    testWidgets('édition : id de initialExam PRÉSERVÉ (jamais réattribué)',
        (tester) async {
      ZExam? emitted;
      const initial = ZExam(id: 'x9', folderId: 'f1', title: 'Ancien');
      await tester.pumpWidget(_host(ZExamEditor(
        initialExam: initial,
        onSubmit: (e) => emitted = e,
      )));
      await tester.pump();
      await tester.enterText(find.byType(TextField).at(0), 'Nouveau');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(emitted!.id, 'x9'); // édition : id existant préservé.
      expect(emitted!.title, 'Nouveau'); // saisie appliquée.
    });
  });

  // ===========================================================================
  // AC2 — reminderTime TYPÉ ZReminderTime + round-trip '08:05' (AD-28, R26).
  // ===========================================================================
  group('AC2 — heure TYPÉE + round-trip persistance', () {
    testWidgets('08 h 05 ⇒ ZReminderTime(8,5), toMap ⇒ 08:05, round-trip exact (R3-I2)',
        (tester) async {
      final exam = await _driveFullEntry(
        tester,
        title: 'T',
        date: DateTime.utc(2026, 8, 1),
        thresholds: <int>[3],
        time: const ZReminderTime(hour: 8, minute: 5),
      );

      // TYPE statique : jamais une String (AD-28). R3-I2 (émettre une String nue) ⇒
      // ne compilerait pas comme ZReminderTime? / la valeur rougirait.
      final ZReminderTime? t = exam.reminderTime;
      expect(t, const ZReminderTime(hour: 8, minute: 5));
      // Zéro-paddé : R3-I2 (perte du padding '8:5') ⇒ rouge.
      expect(exam.toMap()[kReminderTimeKey], '08:05');
      // Round-trip EXACT (persistance ZExam — non réimplémentée).
      expect(ZExam.fromMap(exam.toMap()).reminderTime, exam.reminderTime);
    });

    testWidgets('heure vidée (picker rend null) ⇒ reminderTime == null (AD-10)',
        (tester) async {
      ZExam? emitted;
      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (e) => emitted = e,
        onPickTime: (_) async => null, // vidé.
      )));
      await tester.pump();
      await tester.tap(find.byType(TextButton).at(1)); // ligne heure.
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(emitted!.reminderTime, isNull);
      expect(emitted!.toMap().containsKey(kReminderTimeKey), isFalse);
    });
  });

  // ===========================================================================
  // AC3 — reminderDaysBefore : ordre + doublons PRÉSERVÉS (R26 sur-purge).
  // ===========================================================================
  group('AC3 — seuils ordre + doublons préservés', () {
    testWidgets('[7, 1] non-trié PRÉSERVÉ EXACTEMENT (R3-I3 ordre)', (tester) async {
      final exam = await _driveFullEntry(
        tester,
        title: 'T',
        date: DateTime.utc(2026, 8, 1),
        thresholds: <int>[7, 1],
        time: const ZReminderTime(hour: 9, minute: 0),
      );
      // R3-I3 : un `..sort()` rendrait [1, 7] ⇒ rouge.
      expect(exam.reminderDaysBefore, <int>[7, 1]);
    });

    testWidgets('[3, 3, 10] doublon PRÉSERVÉ (R3-I3 dédup)', (tester) async {
      final exam = await _driveFullEntry(
        tester,
        title: 'T',
        date: DateTime.utc(2026, 8, 1),
        thresholds: <int>[3, 3, 10],
        time: const ZReminderTime(hour: 9, minute: 0),
      );
      // R3-I3 : un `.toSet().toList()` rendrait [3, 10] ⇒ rouge.
      expect(exam.reminderDaysBefore, <int>[3, 3, 10]);
    });

    testWidgets('retrait d\'un seuil : les autres conservent leur ordre',
        (tester) async {
      ZExam? emitted;
      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (e) => emitted = e,
        addThresholdSemanticLabel: 'ADD-THRESHOLD',
        removeThresholdSemanticLabel: (t) => 'RM-$t',
      )));
      await tester.pump();
      for (final t in <int>[7, 3, 1]) {
        await tester.enterText(find.byType(TextField).at(1), '$t');
        await tester.tap(find.byTooltip('ADD-THRESHOLD'));
        await tester.pump();
      }
      // Retirer le seuil du milieu (3).
      await tester.tap(find.byTooltip('RM-3'));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(emitted!.reminderDaysBefore, <int>[7, 1]);
    });
  });
}
