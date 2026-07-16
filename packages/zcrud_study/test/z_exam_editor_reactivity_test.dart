// Tests DISCRIMINANTS ES-9.2 — AC6 (AD-2/AD-15, SM-1) : controller du titre
// owned/injected, identité STABLE entre rebuilds, granularité (une frappe ne
// reconstruit pas un champ voisin). Patron `z_study_tools_rebuild_test.dart` /
// `z_tag_editor_test.dart`. Injections R3-I6 (controller recréé dans build) /
// R3-I6b (état lifté en setState de page) prouvées à rouge.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_study/zcrud_study.dart';

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: ZcrudScope(
        child: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
      ),
    ),
  );
}

void main() {
  group('AC6 — controller du titre owned/injected', () {
    testWidgets('POSSÉDÉ : identique sous tempête de rebuilds, disposé au démontage '
        '(R3-I6)', (tester) async {
      late StateSetter storm;
      await tester.pumpWidget(_host(StatefulBuilder(
        builder: (context, setState) {
          storm = setState;
          return ZExamEditor(onSubmit: (_) {});
        },
      )));
      await tester.pump();

      TextEditingController titleController() =>
          tester.widget<TextField>(find.byType(TextField).at(0)).controller!;
      final before = titleController();

      for (var i = 0; i < 6; i++) {
        storm(() {});
        await tester.pump();
      }
      // R3-I6 : controller créé dans build() ⇒ non-identique ⇒ rouge.
      expect(identical(before, titleController()), isTrue);

      await tester.pumpWidget(_host(const SizedBox.shrink()));
      // Un controller disposé throw en debug sur addListener (ChangeNotifier).
      expect(() => before.addListener(() {}), throwsFlutterError);
    });

    testWidgets('INJECTÉ : utilisé tel quel, JAMAIS disposé par l\'éditeur',
        (tester) async {
      final injected = TextEditingController();
      addTearDown(injected.dispose);

      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (_) {},
        titleController: injected,
      )));
      await tester.pump();

      expect(
        identical(
          tester.widget<TextField>(find.byType(TextField).at(0)).controller,
          injected,
        ),
        isTrue,
      );

      await tester.pumpWidget(_host(const SizedBox.shrink()));
      // Non disposé ⇒ addListener ne throw pas (R3 : un dispose ici rougirait).
      expect(() => injected.addListener(() {}), returnsNormally);
    });
  });

  group('AC6 — granularité SM-1', () {
    testWidgets('taper dans le titre ne reconstruit PAS le champ date (R3-I6b)',
        (tester) async {
      // Sonde : `dateLabeler` n'est appelé que lorsque le ValueListenableBuilder de
      // la date se (re)construit — c.-à-d. si `editor.build()` est réinvoqué. Une
      // frappe qui lifte l'état en `setState` de page (R3-I6b) rebuild tout l'éditeur
      // ⇒ la sonde s'incrémente. Une frappe via le controller local (attendu) ⇒ sonde
      // stable.
      var dateLabelCalls = 0;
      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (_) {},
        initialExam: ZExam(date: DateTime.utc(2026, 8, 1)),
        dateLabeler: (d) {
          dateLabelCalls++;
          return 'D';
        },
      )));
      await tester.pump();
      final baseline = dateLabelCalls;
      expect(baseline, greaterThanOrEqualTo(1));

      // 20 frappes dans le titre (controller local) — champ date NON reconstruit.
      final buffer = StringBuffer();
      for (var i = 0; i < 20; i++) {
        buffer.write('x');
        await tester.enterText(find.byType(TextField).at(0), buffer.toString());
        await tester.pump();
      }

      expect(dateLabelCalls, baseline,
          reason: 'SM-1 : le champ date ne se reconstruit pas à la frappe du titre');
    });

    testWidgets('changer un seul champ ne reconstruit QUE ce champ (notifiers isolés)',
        (tester) async {
      var dateLabelCalls = 0;
      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (_) {},
        initialExam: ZExam(date: DateTime.utc(2026, 8, 1)),
        dateLabeler: (d) {
          dateLabelCalls++;
          return 'D';
        },
        addThresholdSemanticLabel: 'ADD-THRESHOLD',
      )));
      await tester.pump();
      final baseline = dateLabelCalls;

      // Toggler les rappels (autre notifier) ne reconstruit pas le champ date.
      await tester.tap(find.byType(Switch));
      await tester.pump();
      expect(dateLabelCalls, baseline);
    });
  });
}
