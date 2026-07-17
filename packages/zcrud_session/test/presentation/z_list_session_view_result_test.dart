/// SU-7 / AC4 — L'agrégat provient du **MOTEUR**, sans recalcul parallèle (D4).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'z_exam_harness.dart';

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets(
    '🔴 AC4 — l\'UI affiche l\'agrégat du SCORER (999), jamais un recomptage '
    '(sentinelle : les vrais chiffres seraient 2)',
    (tester) async {
      useLargeSurface(tester);
      final cards = <ZFlashcard>[examCard('Q1'), examCard('Q2')];

      await tester.pumpWidget(
        ExamHost(
          cards: cards,
          // 🔒 Scorer **SENTINELLE** : il rend un agrégat IMPOSSIBLE à
          // recalculer (999 total pour 2 cartes). Si l'UI recomptait, elle
          // afficherait `2` et ce test rougirait — c'est tout son intérêt.
          scorer: (qualities, {required int passThreshold}) =>
              const ZStudySessionResult(
                mode: ZReviewMode.whiteExam,
                total: 999,
                correct: 42,
                byQuality: <String, int>{'5': 999},
              ),
        ),
      );

      for (final c in cards) {
        await tester.tap(
          find.descendant(
            of: find.ancestor(
              of: find.text(c.question),
              matching: find.byType(ZFlashcardAnswerInput),
            ),
            matching: find.byKey(EK.answerTrue),
          ),
        );
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZListSessionView.confirmKey));
      await tester.pumpAndSettle();

      // 🔒 L'écran de fin est `ZSessionSummaryView` (su-5), jamais un écran
      // réécrit.
      expect(find.byType(ZSessionSummaryView), findsOneWidget);
      final summary = tester.widget<ZSessionSummaryView>(
        find.byType(ZSessionSummaryView),
      );
      expect(
        summary.result.total,
        999,
        reason: '🔴 AC4 : l\'agrégat affiché n\'est pas celui du moteur. La '
            'présentation a recompté — `scoreWhiteExam` doit rester le '
            'PRODUCTEUR UNIQUE.',
      );
      expect(summary.result.correct, 42);
      // 🔴 Canal VISIBLE — pas seulement le paramètre passé au widget (un
      // paramètre correct rendu nulle part resterait vert : leçon su-6).
      //
      // ⚠️ On vise la tuile « total » PAR SA CLÉ : `find.text('999')` seul
      // trouve **3** nœuds ici (la répartition `byQuality` de la sentinelle
      // porte le même nombre). Un `findsWidgets` laxiste passerait même si le
      // total, lui, était faux — on cherche donc le nombre **là où il doit être**.
      expect(
        tester.widget<Text>(find.byKey(ZSessionSummaryView.totalValueKey)).data,
        '999',
        reason: '🔴 la tuile « total » n\'affiche pas l\'agrégat du moteur.',
      );
    },
  );

  test('🔴 AC4 — la vue ne RECOMPTE ni ne JUGE (scan de source)', () {
    const path = 'lib/src/presentation/z_list_session_view.dart';
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason: 'source introuvable: $path (cwd=${Directory.current.path})',
    );
    final lines = file.readAsLinesSync();
    expect(lines, isNotEmpty, reason: 'source vide — rien scanné');

    // ⚠️ **Portée déclarée honnêtement — pourquoi PAS un grep de
    // `passThreshold` tout court** (ce que l'AC suggérait à la lettre) :
    // `ZSessionProgressIndicator` (su-4) **EXIGE** `passThreshold` à son ctor, et
    // `ZSessionSummaryView` (su-5) exige `config`. Les leur **passer** est un
    // **RELAIS** de la valeur dont `ZSrsConfig` est propriétaire (AD-46) — pas un
    // jugement. Un grep littéral rougirait donc sur du code **conforme**, et
    // finirait désactivé (une garde qui crie au loup ne survit pas).
    //
    // Ce qui doit être interdit, c'est **JUGER** et **RECOMPTER** :
    //  - comparer une qualité au seuil (`>= passThreshold`) = re-décider
    //    correct/incorrect, alors que `scoreWhiteExam` en est le seul juge ;
    //  - incrémenter un compteur = tenir un agrégat parallèle.
    final banned = <({String pattern, String why})>[
      (pattern: '>= passThreshold', why: 'juge correct/incorrect'),
      (pattern: '> passThreshold', why: 'juge correct/incorrect'),
      (pattern: '+= 1', why: 'recompte un agrégat'),
      (pattern: 'correct++', why: 'recompte un agrégat'),
      (pattern: 'correct +=', why: 'recompte un agrégat'),
    ];

    final violations = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trimLeft();
      if (trimmed.startsWith('///') || trimmed.startsWith('//')) continue;
      for (final rule in banned) {
        if (lines[i].contains(rule.pattern)) {
          violations.add(
            '$path:${i + 1} → `${rule.pattern}` (${rule.why}) :: '
            '${lines[i].trim()}',
          );
        }
      }
    }
    expect(
      violations,
      isEmpty,
      reason: '🔴 AC4/D4 : la présentation recompte ou juge. L\'agrégat a UN '
          'producteur (`scoreWhiteExam`) ; le détail par question vient des '
          '`ZFlashcardSubmission`. Deux canaux, jamais deux calculs :\n'
          '${violations.join('\n')}',
    );

    // Contre-preuve : le scan voit bien le VRAI relais de l'agrégat — sinon il
    // serait vert sur un fichier qui n'afficherait aucun résultat.
    expect(
      lines.any((l) => l.contains('result: aggregate')),
      isTrue,
      reason: 'la vue ne relaie plus `result` au sommaire : ce scan serait vert '
          'pour de mauvaises raisons',
    );
  });
}
