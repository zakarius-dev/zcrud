// DP-10 (B12+B13) — Champ date : bornes min/max (littérales + cross-champ) et
// mode `dateTime` combiné date+heure. Vérifie AC3–AC10 :
//  - résolution du mode (config.mode > dérivé du type)
//  - bornes honorées (fin du hardcode 1900/2100) + priorité littéral > cross-champ
//  - seam AD-2 (résolveurs injectés, StatelessWidget pur, résolution au tap)
//  - picker combiné + préservation de l'heure
//  - `date` seule / `time` inchangés
//  - défensif AD-10 (bornes invalides ⇒ repli, incohérence ⇒ clamp sans crash)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Monte un unique [ZDateFieldWidget] sous un `MaterialApp` (l10n `en` de repli).
Widget _hostDate({
  required ZFieldSpec field,
  Object? value,
  required ValueChanged<String> onChanged,
  ValueGetter<DateTime?>? firstDate,
  ValueGetter<DateTime?>? lastDate,
}) =>
    MaterialApp(
      home: Scaffold(
        body: ZDateFieldWidget(
          field: field,
          value: value,
          onChanged: onChanged,
          firstDate: firstDate,
          lastDate: lastDate,
        ),
      ),
    );

/// Monte un formulaire à deux champs via le dispatcher réel (`DynamicEdition`).
Widget _hostForm(ZFormController controller, List<ZFieldSpec> fields) =>
    MaterialApp(
      home: Scaffold(
        body: DynamicEdition(controller: controller, fields: fields),
      ),
    );

DatePickerDialog _dateDialog(WidgetTester tester) =>
    tester.widget<DatePickerDialog>(find.byType(DatePickerDialog));

void main() {
  group('DP-10 — bornes littérales (AC4/B12)', () {
    testWidgets('minDateIso/maxDateIso fixent les bornes du showDatePicker',
        (tester) async {
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        label: 'Date',
        config: ZDateConfig(mode: ZDateMode.date),
      );
      await tester.pumpWidget(_hostDate(
        field: field,
        value: null,
        onChanged: (_) {},
        firstDate: () => DateTime(2020, 1, 1),
        lastDate: () => DateTime(2030, 12, 31),
      ));
      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();

      final dlg = _dateDialog(tester);
      expect(dlg.firstDate, DateTime(2020, 1, 1));
      expect(dlg.lastDate, DateTime(2030, 12, 31));
    });

    testWidgets('aucune borne (résolveurs null) ⇒ repli 1900/2100',
        (tester) async {
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        label: 'Date',
        config: ZDateConfig(mode: ZDateMode.date),
      );
      await tester.pumpWidget(_hostDate(
        field: field,
        value: null,
        onChanged: (_) {},
      ));
      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();

      final dlg = _dateDialog(tester);
      expect(dlg.firstDate, DateTime(1900));
      expect(dlg.lastDate, DateTime(2100));
    });
  });

  group('DP-10 — bornes cross-champ + priorité (AC4/AC5)', () {
    testWidgets('firstDateKey dérive la borne depuis un autre champ peuplé',
        (tester) async {
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'src', type: EditionFieldType.dateTime, label: 'Source'),
        ZFieldSpec(
          name: 'target',
          type: EditionFieldType.dateTime,
          label: 'Cible',
          config: ZDateConfig(mode: ZDateMode.date, firstDateKey: 'src'),
        ),
      ];
      final controller = ZFormController(
        initialValues: const <String, Object?>{'src': null, 'target': null},
        visibleFields: const <String>['src', 'target'],
      );
      addTearDown(controller.dispose);
      controller.setValue('src', '2022-05-10T00:00:00.000');

      await tester.pumpWidget(_hostForm(controller, fields));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Cible'));
      await tester.pumpAndSettle();

      expect(_dateDialog(tester).firstDate, DateTime(2022, 5, 10));
    });

    testWidgets('le littéral minDateIso l\'emporte sur le cross-champ',
        (tester) async {
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'src', type: EditionFieldType.dateTime, label: 'Source'),
        ZFieldSpec(
          name: 'target',
          type: EditionFieldType.dateTime,
          label: 'Cible',
          config: ZDateConfig(
            mode: ZDateMode.date,
            firstDateKey: 'src',
            minDateIso: '2019-03-03T00:00:00.000',
          ),
        ),
      ];
      final controller = ZFormController(
        initialValues: const <String, Object?>{'src': null, 'target': null},
        visibleFields: const <String>['src', 'target'],
      );
      addTearDown(controller.dispose);
      controller.setValue('src', '2022-05-10T00:00:00.000');

      await tester.pumpWidget(_hostForm(controller, fields));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Cible'));
      await tester.pumpAndSettle();

      // Littéral 2019-03-03 gagne sur le cross-champ 2022-05-10.
      expect(_dateDialog(tester).firstDate, DateTime(2019, 3, 3));
    });
  });

  group('DP-10 — combiné date+heure (AC6/B13)', () {
    testWidgets('nouvelle date + heure conservée ⇒ ISO combiné', (tester) async {
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        label: 'Date',
      );
      String? captured;
      await tester.pumpWidget(_hostDate(
        field: field,
        value: '2026-07-11T14:30:00.000',
        onChanged: (iso) => captured = iso,
      ));

      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();
      // Choisir le 15 du mois courant (2026-07).
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      // Étape heure : accepter l'heure préexistante (14:30).
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(captured, DateTime(2026, 7, 15, 14, 30).toIso8601String());
    });

    testWidgets('annulation de l\'étape heure conserve l\'heure préexistante',
        (tester) async {
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        label: 'Date',
      );
      String? captured;
      await tester.pumpWidget(_hostDate(
        field: field,
        value: '2026-07-11T14:30:00.000',
        onChanged: (iso) => captured = iso,
      ));

      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK')); // garde le 11
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel')); // annule l'heure
      await tester.pumpAndSettle();

      // Heure NON écrasée à minuit : 14:30 préservé.
      expect(captured, DateTime(2026, 7, 11, 14, 30).toIso8601String());
    });
  });

  group('DP-10 — date seule / time inchangés (AC7)', () {
    testWidgets('mode date ⇒ un seul dialog, pas de time picker, midnight',
        (tester) async {
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        label: 'Date',
        config: ZDateConfig(mode: ZDateMode.date),
      );
      var calls = 0;
      String? captured;
      await tester.pumpWidget(_hostDate(
        field: field,
        value: '2026-07-11T00:00:00.000',
        onChanged: (iso) {
          calls++;
          captured = iso;
        },
      ));

      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(TimePickerDialog), findsNothing);
      expect(calls, 1);
      expect(captured, DateTime(2026, 7, 11).toIso8601String());
    });

    testWidgets('type time ⇒ showTimePicker seul, sortie HH:mm', (tester) async {
      const field =
          ZFieldSpec(name: 't', type: EditionFieldType.time, label: 'Heure');
      String? captured;
      await tester.pumpWidget(_hostDate(
        field: field,
        value: '09:15',
        onChanged: (v) => captured = v,
      ));

      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      expect(find.byType(DatePickerDialog), findsNothing);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(captured, '09:15');
    });
  });

  group('DP-10 — défensif AD-10 (AC8)', () {
    testWidgets('minDateIso invalide + cross-champ non parsable ⇒ repli 1900/2100',
        (tester) async {
      const fields = <ZFieldSpec>[
        ZFieldSpec(name: 'src', type: EditionFieldType.dateTime, label: 'Source'),
        ZFieldSpec(
          name: 'target',
          type: EditionFieldType.dateTime,
          label: 'Cible',
          config: ZDateConfig(
            mode: ZDateMode.date,
            firstDateKey: 'src',
            minDateIso: 'pas-une-date',
          ),
        ),
      ];
      final controller = ZFormController(
        initialValues: const <String, Object?>{'src': null, 'target': null},
        visibleFields: const <String>['src', 'target'],
      );
      addTearDown(controller.dispose);
      controller.setValue('src', 'garbage');

      await tester.pumpWidget(_hostForm(controller, fields));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Cible'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dlg = _dateDialog(tester);
      expect(dlg.firstDate, DateTime(1900));
      expect(dlg.lastDate, DateTime(2100));
    });

    testWidgets('firstDate > lastDate et > date initiale ⇒ clamp, pas d\'assertion',
        (tester) async {
      const field = ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
        label: 'Date',
        config: ZDateConfig(mode: ZDateMode.date),
      );
      await tester.pumpWidget(_hostDate(
        field: field,
        value: null,
        onChanged: (_) {},
        firstDate: () => DateTime(2040, 1, 1),
        lastDate: () => DateTime(2030, 1, 1),
      ));
      await tester.tap(find.byType(ZDateFieldWidget));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final dlg = _dateDialog(tester);
      // Borne basse repliée sur la borne haute (2030) ; initialDate clampée.
      expect(dlg.firstDate, DateTime(2030, 1, 1));
      expect(dlg.lastDate, DateTime(2030, 1, 1));
      expect(dlg.firstDate.isAfter(dlg.lastDate), isFalse);
    });
  });

  group('DP-10 — AD-2 / SM-1 (AC5)', () {
    testWidgets('ZDateFieldWidget reste StatelessWidget (aucun controller local)',
        (tester) async {
      const field =
          ZFieldSpec(name: 'd', type: EditionFieldType.dateTime, label: 'Date');
      await tester.pumpWidget(_hostDate(
        field: field,
        value: null,
        onChanged: (_) {},
      ));
      expect(find.byType(ZDateFieldWidget), findsOneWidget);
      final w = tester.widget(find.byType(ZDateFieldWidget));
      expect(w, isA<StatelessWidget>());
      expect(find.byType(EditableText), findsNothing);
    });
  });
}
