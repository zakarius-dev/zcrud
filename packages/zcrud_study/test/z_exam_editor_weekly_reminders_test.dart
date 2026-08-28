// `Tristate` : sous Flutter 3.44 `SemanticsData.flagsCollection.isSelected`
// n'est pas un `bool` mais un tri-état (absent / faux / vrai) — la distinction
// compte ici, « pas de drapeau » n'est PAS « non sélectionné ». Même import
// que `zcrud_chat/test/z_chat_cr74_visible_selection_test.dart`.
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_study/zcrud_study.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: ZcrudScope(
      child: Scaffold(
        body: SizedBox(width: 800, height: 700, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'garde (a) — sans récurrence hebdomadaire, la soumission est inerte',
    (tester) async {
      final initial = ZExam(
        id: 'exam-a',
        folderId: 'folder-a',
        title: 'Examen inchangé',
        date: DateTime.utc(2026, 9, 4),
        reminderEnabled: true,
        reminderDaysBefore: const <int>[7, 1, 1],
        reminderTime: const ZReminderTime(hour: 8, minute: 5),
        extra: const <String, dynamic>{
          'legacy': <String, dynamic>{'kept': true},
        },
      );
      ZExam? emitted;

      await tester.pumpWidget(
        _host(
          ZExamEditor(
            initialExam: initial,
            onSubmit: (exam) => emitted = exam,
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(emitted, initial);
      expect(emitted!.toMap(), initial.toMap());
    },
  );

  testWidgets(
    'garde (b) — le mode par défaut préserve la récurrence hebdomadaire',
    (tester) async {
      const recurrence = ZReminderRecurrence(
        daysBefore: <int>[14, 2],
        weekdays: <int>{DateTime.tuesday, DateTime.thursday},
      );
      const initial = ZExam(
        id: 'exam-b',
        folderId: 'folder-b',
        title: 'Récurrence à préserver',
        reminderEnabled: true,
        reminderDaysBefore: <int>[30],
        reminderTime: ZReminderTime(hour: 9, minute: 45),
        reminderRecurrence: recurrence,
      );
      ZExam? emitted;

      await tester.pumpWidget(
        _host(
          ZExamEditor(
            initialExam: initial,
            onSubmit: (exam) => emitted = exam,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey<String>('z-exam-weekly-reminders')),
        findsNothing,
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(emitted!.reminderRecurrence, recurrence);
      expect(emitted, initial);
    },
  );

  // ===========================================================================
  // Garde (c) — EFFET : la section coche des jours et l'heure, et la valeur
  // émise porte EXACTEMENT ce qui a été saisi.
  //
  // Injection R3 attendue : faire ignorer `_weekdays` à `_composeRecurrence`
  // (rendre `null`, ou reporter `base.reminderRecurrence`) ⇒ rouge PAR
  // ASSERTION sur `weekdays`.
  // ===========================================================================
  testWidgets(
    'garde (c) — mardi + jeudi + 18:30 donnent exactement {2, 4} et 18:30',
    (tester) async {
      const initial = ZExam(
        id: 'exam-c',
        folderId: 'folder-c',
        title: 'Édition hebdomadaire',
        reminderEnabled: true,
      );
      ZExam? emitted;

      await tester.pumpWidget(
        _host(
          ZExamEditor(
            initialExam: initial,
            showWeeklyReminders: true,
            onPickTime: (_) async => const ZReminderTime(hour: 18, minute: 30),
            onSubmit: (exam) => emitted = exam,
          ),
        ),
      );

      // La section n'existe QUE dans ce mode (pendant exact de la garde (b)).
      expect(
        find.byKey(const ValueKey<String>('z-exam-weekly-reminders')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('z-exam-weekday:${DateTime.tuesday}')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('z-exam-weekday:${DateTime.thursday}')),
      );
      await tester.pump();

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey<String>('z-exam-time')),
          matching: find.byType(TextButton),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Égalité STRICTE de l'ensemble : ni `contains`, ni `length` — deux jours
      // EXACTEMENT, et ceux-là.
      expect(
        emitted!.reminderRecurrence,
        const ZReminderRecurrence(
          weekdays: <int>{DateTime.tuesday, DateTime.thursday},
        ),
      );
      expect(emitted!.reminderRecurrence!.weekdays,
          <int>{DateTime.tuesday, DateTime.thursday});
      expect(emitted!.reminderTime, const ZReminderTime(hour: 18, minute: 30));
      // La famille RELATIVE de l'examen n'est pas touchée par cette section.
      expect(emitted!.reminderDaysBefore, initial.reminderDaysBefore);
    },
  );

  // ===========================================================================
  // Garde (d) — AD-13 : CHAQUE puce de jour porte une cible ≥ 48 dp et une
  // sémantique utilisable (label non vide, DISTINCT des six autres, et l'état
  // `selected` qui reflète réellement la sélection).
  //
  // 🔴 LOAD-BEARING : la mesure de taille SEULE serait POWERLESS —
  // `MaterialTapTargetSize.padded` impose déjà 48 dp de hauteur à un bouton
  // Material. Ce qui appartient à ce lot, c'est (1) notre `ConstrainedBox`
  // min 48/48 sur les DEUX axes — un `TextButton` à libellé d'une seule lettre
  // fait moins de 48 dp de LARGE sans elle — et (2) le nœud `Semantics`.
  //
  // 🔴 CE QUE CETTE GARDE N'AFFIRME PAS, ET POURQUOI : sept libellés DISTINCTS.
  // Mesuré : `MaterialLocalizations.narrowWeekdays` rend en `en_US`
  // `S M T W T F S` — CINQ libellés pour sept jours (mardi/jeudi et
  // samedi/dimanche sont homographes). C'est une propriété de la LOCALE, pas un
  // défaut de ce widget : Flutter lui-même n'expose aucun nom de jour complet
  // hors `formatFullDate`, qui exige une DATE réelle qu'une puce de jour de
  // semaine n'a pas. Le repli reste donc ambigu au lecteur d'écran, et c'est
  // précisément pourquoi `weekdayLabeler` existe — le second scénario ci-dessous
  // prouve que l'injection atteint bien le nœud sémantique.
  //
  // Ce que la garde affirme À LA PLACE, et qui MORD : le libellé de CHAQUE
  // puce est celui que la locale attribue à CE jour ISO — c'est l'APPARIEMENT
  // « index Material → jour ISO » qui est mesuré. Le décaler (`_isoWeekdayOf`
  // faussé, ou libellé lu à un autre index) déplace les lettres et rougit ici.
  //
  // ⚠️ Ce qu'elle ne mesure PAS : l'ORDRE d'affichage. La rotation
  // `(first + i) % 7` dérive le jour ISO et son libellé du MÊME index, donc la
  // changer réordonne les puces sans jamais dépareiller un libellé. L'ordre
  // dépend de `firstDayOfWeekIndex`, propriété de la locale, pas de ce lot.
  //
  // Injections R3 attendues : `_kMinTapTarget` abaissé, `label:` vidé,
  // `selected:` figé, ou mapping ISO faussé ⇒ rouge PAR ASSERTION.
  // ===========================================================================

  /// Abréviations `en_US` attendues, par jour ISO (1 = lundi … 7 = dimanche).
  /// Volontairement écrites ici (le verrou de source FR-26 ne scanne que
  /// `lib/`) : c'est la table de vérité contre laquelle le mapping est mesuré.
  const narrowEnUs = <int, String>{
    DateTime.monday: 'M',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'W',
    DateTime.thursday: 'T',
    DateTime.friday: 'F',
    DateTime.saturday: 'S',
    DateTime.sunday: 'S',
  };

  testWidgets(
    'garde (d) — AD-13 : chaque puce ≥ 48 dp, jour ISO bien étiqueté, selected fidèle',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ZExamEditor(
            showWeeklyReminders: true,
            initialExam: const ZExam(
              id: 'exam-d',
              folderId: 'folder-d',
              reminderRecurrence: ZReminderRecurrence(
                weekdays: <int>{DateTime.wednesday},
              ),
            ),
            onSubmit: (_) {},
          ),
        ),
      );

      for (var iso = DateTime.monday; iso <= DateTime.sunday; iso++) {
        final finder = find.byKey(ValueKey<String>('z-exam-weekday:$iso'));
        expect(finder, findsOneWidget, reason: 'jour ISO $iso absent');

        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48.0), reason: 'largeur ISO $iso');
        expect(size.height, greaterThanOrEqualTo(48.0), reason: 'hauteur ISO $iso');

        final data = tester.getSemantics(finder).getSemanticsData();
        expect(data.label, isNotEmpty, reason: 'label vide pour ISO $iso');
        // Le libellé est celui que la LOCALE donne à CE jour ISO : c'est le
        // mapping Material(0 = dimanche) → ISO(1 = lundi) qui est mesuré.
        expect(
          data.label,
          narrowEnUs[iso],
          reason: 'mapping ISO→locale faux pour le jour $iso',
        );
        // `selected` FIDÈLE : seul mercredi est coché dans cet examen.
        expect(
          data.flagsCollection.isSelected,
          iso == DateTime.wednesday ? Tristate.isTrue : Tristate.isFalse,
          reason: 'état selected faux pour ISO $iso',
        );
      }

      handle.dispose();
    },
  );

  testWidgets(
    'garde (d bis) — le labeler injecté atteint le nœud sémantique de chaque jour',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ZExamEditor(
            showWeeklyReminders: true,
            // Labeler INJECTÉ : sept libellés sans homographe, ce que le repli
            // `narrowWeekdays` ne peut pas garantir.
            weekdayLabeler: (weekday) => 'JOUR-$weekday',
            onSubmit: (_) {},
          ),
        ),
      );

      final labels = <String>{};
      for (var iso = DateTime.monday; iso <= DateTime.sunday; iso++) {
        final data = tester
            .getSemantics(find.byKey(ValueKey<String>('z-exam-weekday:$iso')))
            .getSemanticsData();
        expect(data.label, 'JOUR-$iso');
        labels.add(data.label);
      }
      // L'injection PORTE : sept nœuds, sept libellés distincts, le bon sur
      // chacun. Un repli qui ignorerait `weekdayLabeler` rougirait ci-dessus.
      expect(labels, hasLength(DateTime.daysPerWeek));

      handle.dispose();
    },
  );
}
