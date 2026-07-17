/// SU-7 / AC1 — `ZListSessionView` affiche l'examen en liste, chaque question
/// offrant **la saisie de su-3** (jamais une saisie réécrite).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_exam_harness.dart';

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('AC1 — 3 cartes ⇒ 3 `ZFlashcardAnswerInput` (la saisie de su-3, '
      'jamais une réécriture)', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(
        cards: <ZFlashcard>[examCard('Q1'), examCard('Q2'), examCard('Q3')],
      ),
    );
    expect(find.byType(ZFlashcardAnswerInput), findsNWidgets(3));
  });

  testWidgets('AC1 — la progression vient de `ZSessionProgressIndicator` '
      '(aucun compteur parallèle)', (tester) async {
    useLargeSurface(tester);
    await tester.pumpWidget(
      ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
    );
    expect(find.byType(ZSessionProgressIndicator), findsOneWidget);

    // 🔴 Présence ≠ association : on prouve que l'indicateur reçoit la VRAIE
    // progression, pas qu'il est là. Un indicateur câblé sur une constante
    // passerait le `findsOneWidget` ci-dessus sans broncher.
    final before = tester.widget<ZSessionProgressIndicator>(
      find.byType(ZSessionProgressIndicator),
    );
    expect(before.total, 2);
    expect(before.currentIndex, 0);

    await tester.tap(
      find.descendant(
        of: find.ancestor(
          of: find.text('Q1'),
          matching: find.byType(ZFlashcardAnswerInput),
        ),
        matching: find.byKey(EK.answerTrue),
      ),
    );
    await tester.pumpAndSettle();

    final after = tester.widget<ZSessionProgressIndicator>(
      find.byType(ZSessionProgressIndicator),
    );
    expect(after.currentIndex, 1, reason: 'la progression doit AVANCER');
  });

  test('AC1 — la liste est VIRTUALISÉE : aucun `ListView(children:)` dans la '
      'vue (scan de SOURCE — un `find.byType` ne verrait pas la différence)', () {
    const path = 'lib/src/presentation/z_list_session_view.dart';
    final file = File(path);
    // Contre-preuve R12 : sans ceci, un fichier renommé rendrait le scan vide
    // et VERT — une preuve d'absence fausse.
    expect(
      file.existsSync(),
      isTrue,
      reason: 'source introuvable: $path (cwd=${Directory.current.path})',
    );
    final lines = file.readAsLinesSync();
    expect(lines, isNotEmpty, reason: 'source vide — rien scanné');

    final violations = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      // La doc doit pouvoir NOMMER le motif interdit (ce dartdoc-ci le fait).
      if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
      // `ListView(` = constructeur par défaut (children:) ; `ListView.builder(`
      // ne matche pas (le `.` s'interpose).
      if (lines[i].contains('ListView(')) {
        violations.add('$path:${i + 1} :: ${lines[i].trim()}');
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '🔴 `ListView(children: […])` construit TOUTES les questions d\'un '
          'coup : un examen de 300 questions les monterait toutes. '
          '`ListView.builder` est obligatoire (AD-13/CLAUDE.md) :\n'
          '${violations.join('\n')}',
    );

    // Contre-preuve : le scan voit bien le VRAI `ListView.builder` de la vue —
    // sans quoi il serait vert sur un fichier qui n'aurait aucune liste.
    expect(
      lines.any((l) => l.contains('ListView.builder(')),
      isTrue,
      reason: 'la vue ne contient aucun `ListView.builder` : ce scan serait '
          'vert pour de mauvaises raisons',
    );
  });
}
