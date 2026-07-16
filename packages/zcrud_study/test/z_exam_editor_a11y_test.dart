// Tests DISCRIMINANTS ES-9.2 — AC7 (AD-13/FR-26) : cibles ≥ 48 dp, `Semantics.label`
// non vides/distincts INJECTÉS, widgets DIRECTIONNELS, `ListView.builder`, thème
// injecté (aucune Color/label métier codé en dur). Injection R3-I7 (cible < 48 dp /
// label vidé / `EdgeInsets.only(left:` / `ListView(children:`) ⇒ RC=1.

import 'dart:io';

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

void main() {
  // ===========================================================================
  // AC7 — cibles ≥ 48 dp + labels sémantiques INJECTÉS distincts.
  // ===========================================================================
  group('AC7 — cibles ≥ 48 dp + Semantics injectés', () {
    testWidgets('boutons interactifs : taille rendue ≥ 48 dp (R3-I7)',
        (tester) async {
      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (_) {},
        onPickDate: (_) async => null,
        onPickTime: (_) async => null,
        addThresholdSemanticLabel: 'ADD-THRESHOLD',
      )));
      await tester.pump();

      // Cibles rendues ≥ 48 dp (R3-I7 : réduire la ConstrainedBox d'un bouton
      // Material — dont la hauteur défaut est < 48 — fait rougir son getSize).
      void expectTap(Finder f) {
        final size = tester.getSize(f);
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(size.height, greaterThanOrEqualTo(48.0));
      }

      expectTap(find.byType(ElevatedButton)); // submit
      expectTap(find.byType(TextButton).at(0)); // date
      expectTap(find.byType(TextButton).at(1)); // time
      expectTap(find.byType(IconButton)); // add-threshold

      // 🔴 LOAD-BEARING (R3-I7) : le getSize seul est POWERLESS — `MaterialTapTarget`
      // .padded impose déjà 48 dp aux boutons Material indépendamment de notre code.
      // La garde PROPRE à ES-9.2 est notre `ConstrainedBox(min 48/48)` autour de
      // CHAQUE contrôle (date, heure, toggle, +seuil, valider = 5). Réduire
      // `_kMinTapTarget` (R3-I7) fait tomber nos boîtes sous le seuil ⇒ le compte
      // s'effondre ⇒ rouge.
      final ownBoxes = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((b) =>
              b.constraints.minWidth >= 48.0 && b.constraints.minHeight >= 48.0);
      expect(ownBoxes.length, greaterThanOrEqualTo(5),
          reason: 'nos 5 ConstrainedBox interactifs bornent à ≥ 48 dp');
    });

    testWidgets('labels sémantiques INJECTÉS non vides et DISTINCTS', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(ZExamEditor(
        onSubmit: (_) {},
        onPickDate: (_) async => null,
        onPickTime: (_) async => null,
        dateSemanticLabel: 'PICK-DATE-XYZ',
        timeSemanticLabel: 'PICK-TIME-XYZ',
        submitSemanticLabel: 'SUBMIT-XYZ',
        addThresholdSemanticLabel: 'ADD-THRESHOLD-XYZ',
        reminderToggleLabel: 'TOGGLE-XYZ',
      )));
      await tester.pump();

      // Distincts et présents (R3-I7 : un label vidé ⇒ findsNothing ⇒ rouge). Match
      // CONTAINS (RegExp) car un label de bouton fusionne avec le texte visible.
      for (final label in <String>[
        'PICK-DATE-XYZ',
        'PICK-TIME-XYZ',
        'SUBMIT-XYZ',
        'ADD-THRESHOLD-XYZ',
        'TOGGLE-XYZ',
      ]) {
        expect(find.bySemanticsLabel(RegExp(RegExp.escape(label))), findsWidgets,
            reason: label);
      }
      handle.dispose();
    });
  });

  // ===========================================================================
  // AC7 — verrou-source directionnel / thème (grep sur les 3 fichiers ES-9.2).
  // ===========================================================================
  group('AC7 — verrou-source directionnel / thème injecté', () {
    const files = <String>[
      'lib/src/presentation/z_exam_editor.dart',
      'lib/src/presentation/z_exam_reminders.dart',
      'lib/src/presentation/z_exam_reminders_section.dart',
    ];

    test('aucun non-directionnel / Color codé en dur / ListView(children:)', () {
      for (final path in files) {
        // COMMENTAIRES DÉPOUILLÉS : les dartdoc ES-9.2 citent verbatim les formes
        // interdites (« jamais `ListView(children:)` ») — sans dépouillement, le
        // filet mordrait sur sa propre documentation (patron no_datetime_now_test).
        final src = _stripComments(File(path).readAsStringSync());
        expect(src.contains('EdgeInsets.only(left'), isFalse, reason: path);
        expect(src.contains('EdgeInsets.only(right'), isFalse, reason: path);
        expect(src.contains('Alignment.centerLeft'), isFalse, reason: path);
        expect(src.contains('Alignment.centerRight'), isFalse, reason: path);
        expect(src.contains('TextAlign.left'), isFalse, reason: path);
        expect(src.contains('TextAlign.right'), isFalse, reason: path);
        expect(src.contains('Colors.'), isFalse, reason: path);
        expect(RegExp(r'0x[0-9a-fA-F]{6,8}').hasMatch(src), isFalse, reason: path);
        // `ListView(children:` interdit — `ListView.builder` obligatoire (AD-13).
        expect(RegExp(r'ListView\s*\(\s*children').hasMatch(src), isFalse,
            reason: path);
      }
    });
  });

  // ===========================================================================
  // AC7 — RTL : la section rend en direction RTL sans exception (directionnel).
  // ===========================================================================
  testWidgets('AC7 — section en RTL rend sans erreur', (tester) async {
    await tester.pumpWidget(_host(
      ZExamRemindersSection(
        exams: <ZExam>[
          const ZExam(
            id: 's',
            title: 'S',
            reminderEnabled: true,
            reminderDaysBefore: <int>[7],
          ).copyWith(date: DateTime.utc(2026, 7, 18)),
        ],
        now: DateTime.utc(2026, 7, 16),
      ),
      dir: TextDirection.rtl,
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('S'), findsOneWidget);
  });
}

/// Dépouille les commentaires (`//` et `/* */`) avant le scan tokenisé.
String _stripComments(String src) {
  final sansBlocs = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sansBlocs
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');
}
