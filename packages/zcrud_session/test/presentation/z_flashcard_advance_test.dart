/// AC8 — `ZCardAdvanceBehavior { auto, manual }` : **défaut PAR MODE**, table
/// **UNIQUE**, jamais redécidée par un widget (FR-SU5).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

void main() {
  /// Soumet un V/F (auto-soumission : un seul geste) et rend les avances.
  Future<List<int>> submitIn(
    WidgetTester tester, {
    required ZReviewMode mode,
    ZCardAdvanceBehavior? advanceBehavior,
    Duration settle = const Duration(milliseconds: 200),
  }) async {
    final advances = <int>[];
    await tester.pumpWidget(
      host(ZFlashcardAnswerInput(
        card: trueFalseCard(),
        mode: mode,
        advanceBehavior: advanceBehavior,
        onAdvance: () => advances.add(1),
      )),
    );
    await tester.tap(find.byKey(K.answerTrue));
    await tester.pump();
    await tester.pump(settle);
    return advances;
  }

  group('🔒 AC8 — (2) le défaut vient de la TABLE, pas du widget', () {
    testWidgets(
        '🔴 mode `test` sans valeur explicite ⇒ onAdvance invoqué 1× après '
        '200 ms (R3-I8)', (tester) async {
      final advances = await submitIn(tester, mode: ZReviewMode.test);
      expect(advances, hasLength(1));
    });

    testWidgets('mode `whiteExam` ⇒ auto-passage (mode chronométré)',
        (tester) async {
      final advances = await submitIn(tester, mode: ZReviewMode.whiteExam);
      expect(advances, hasLength(1));
    });

    testWidgets(
        '🔴 mode `learn` ⇒ JAMAIS invoqué, même après 5 s (on lit la '
        'correction)', (tester) async {
      final advances = await submitIn(
        tester,
        mode: ZReviewMode.learn,
        settle: const Duration(seconds: 5),
      );
      expect(advances, isEmpty,
          reason: 'un auto-passage en apprentissage ferait disparaître la '
              'correction — l\'essentiel de la valeur pédagogique');
    });

    testWidgets('les 4 modes `manual` ⇒ jamais d\'auto-passage', (tester) async {
      for (final mode in <ZReviewMode>[
        ZReviewMode.spaced,
        ZReviewMode.learn,
        ZReviewMode.list,
        ZReviewMode.cramming,
      ]) {
        final advances = <int>[];
        await tester.pumpWidget(
          host(ZFlashcardAnswerInput(
            key: ValueKey<String>(mode.name),
            card: trueFalseCard(),
            mode: mode,
            onAdvance: () => advances.add(1),
          )),
        );
        await tester.tap(find.byKey(K.answerTrue));
        await tester.pump();
        await tester.pump(const Duration(seconds: 5));
        expect(advances, isEmpty, reason: 'mode $mode ne doit PAS auto-passer');
      }
    });

    testWidgets(
        '🔬 le widget SUIT la table : pour CHAQUE mode, le comportement observé '
        '== `zDefaultAdvanceBehavior(mode)`', (tester) async {
      // 🔴 R3-I8 : si le widget RECODAIT le défaut au lieu de lire la table,
      // les deux divergeraient — ce test croise les DEUX sources.
      for (final mode in ZReviewMode.values) {
        final advances = <int>[];
        await tester.pumpWidget(
          host(ZFlashcardAnswerInput(
            key: ValueKey<String>('x${mode.name}'),
            card: trueFalseCard(),
            mode: mode,
            onAdvance: () => advances.add(1),
          )),
        );
        await tester.tap(find.byKey(K.answerTrue));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final expected = zDefaultAdvanceBehavior(mode) == ZCardAdvanceBehavior.auto;
        expect(
          advances.isNotEmpty,
          expected,
          reason: 'mode $mode : la table dit ${zDefaultAdvanceBehavior(mode)} '
              'mais le widget se comporte autrement ⇒ le défaut a été REDÉCIDÉ '
              'dans le widget (R3-I8)',
        );
      }
    });
  });

  group('🔒 AC8 — (3) une valeur EXPLICITE prime sur le défaut', () {
    testWidgets('🔴 `manual` explicite en mode `test` ⇒ JAMAIS invoqué (R3-I8b)',
        (tester) async {
      final advances = await submitIn(
        tester,
        mode: ZReviewMode.test,
        advanceBehavior: ZCardAdvanceBehavior.manual,
        settle: const Duration(seconds: 5),
      );
      expect(advances, isEmpty,
          reason: 'la valeur explicite de l\'hôte a été IGNORÉE (R3-I8b)');
    });

    testWidgets('`auto` explicite en mode `learn` ⇒ invoqué', (tester) async {
      final advances = await submitIn(
        tester,
        mode: ZReviewMode.learn,
        advanceBehavior: ZCardAdvanceBehavior.auto,
      );
      expect(advances, hasLength(1));
    });
  });

  group('AC8 — le délai est de 200 ms (parité IFFD F13) et paramétrable', () {
    testWidgets('rien AVANT 200 ms, invoqué APRÈS', (tester) async {
      final advances = <int>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: trueFalseCard(),
          mode: ZReviewMode.test,
          onAdvance: () => advances.add(1),
        )),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 199));
      expect(advances, isEmpty, reason: 'l\'avance ne doit pas être immédiate');
      await tester.pump(const Duration(milliseconds: 1));
      expect(advances, hasLength(1));
    });

    testWidgets('autoAdvanceDelay est respecté', (tester) async {
      final advances = <int>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: trueFalseCard(),
          mode: ZReviewMode.test,
          autoAdvanceDelay: const Duration(seconds: 2),
          onAdvance: () => advances.add(1),
        )),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(advances, isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(advances, hasLength(1));
    });
  });

  group('🔒 AC8 — (4) démontage avant échéance ⇒ aucune invocation, aucun crash',
      () {
    testWidgets('🔴 démonter avant les 200 ms ⇒ onAdvance JAMAIS appelé (R3-I8c)',
        (tester) async {
      final advances = <int>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: trueFalseCard(),
          mode: ZReviewMode.test,
          onAdvance: () => advances.add(1),
        )),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pump(const Duration(milliseconds: 50));

      // Démontage AVANT l'échéance.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.pump(const Duration(seconds: 5));

      expect(advances, isEmpty,
          reason: 'un Timer a survécu au dispose : il demande une avance sur un '
              'arbre MORT — classe de bug réelle (R3-I8c)');
      expect(tester.takeException(), isNull);
    });
  });

  group('AC8 — su-3 DEMANDE l\'avance, il ne NAVIGUE pas (frontière su-4)', () {
    testWidgets('sans onAdvance, l\'auto-passage ne casse rien', (tester) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: trueFalseCard(),
          mode: ZReviewMode.test,
          // onAdvance ABSENT : su-3 n'a aucune idée de ce qu'est « la suivante ».
        )),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
