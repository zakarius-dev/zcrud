/// AC3 — port en échec / absent / **jetant** / hors ligne ⇒ **qualité neutre**
/// (`passThreshold`), **sans exception** (AD-10/NFR-SU6/NFR-SU8).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

/// Port **hors ligne** : différé puis `Left` (le cas réseau réel).
class _OfflineEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  int callCount = 0;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    callCount++;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return const Left<ZFailure, ZFlashcardAnswerEvaluation>(
      ZServerFailure('hors ligne'),
    );
  }
}

void main() {
  Future<List<ZFlashcardSubmission>> submitWith(
    WidgetTester tester,
    ZFlashcardAnswerEvaluationPort? port,
  ) async {
    final submissions = <ZFlashcardSubmission>[];
    await tester.pumpWidget(
      host(
        ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: port,
          onQualitySelected: (_) {},
          onSubmitted: submissions.add,
        ),
      ),
    );
    await tester.enterText(find.byKey(K.answerField), 'ma réponse');
    await tester.pump();
    await tester.tap(find.byKey(K.submit));
    await tester.pumpAndSettle();
    return submissions;
  }

  group(
    '🔒 AC3 — les 4 cas ⇒ qualité NEUTRE == passThreshold, sans exception',
    () {
      testWidgets('(1) `Left(ZFailure)` ⇒ passThreshold', (tester) async {
        final port = FailingEvaluationPort();
        final submissions = await submitWith(tester, port);
        expect(port.callCount, 1);
        expect(submissions.single.quality, const ZSrsConfig().passThreshold);
        expect(tester.takeException(), isNull);
      });

      testWidgets('(2) port ABSENT (null) ⇒ passThreshold', (tester) async {
        final submissions = await submitWith(tester, null);
        expect(submissions.single.quality, const ZSrsConfig().passThreshold);
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        '🔴 (3) port qui JETTE ⇒ passThreshold (R3-I3b : n\'attraper que le '
        '`Left` laisse l\'exception traverser)',
        (tester) async {
          final port = ThrowingEvaluationPort();
          final submissions = await submitWith(tester, port);
          expect(port.callCount, 1, reason: 'le port DOIT avoir été appelé');
          expect(submissions.single.quality, const ZSrsConfig().passThreshold);
          expect(
            tester.takeException(),
            isNull,
            reason:
                'une exception a franchi la surface : AD-10 (« jamais '
                'd\'exception ») violé — une session meurt parce qu\'un routeur IA '
                'a paniqué',
          );
        },
      );

      testWidgets('(4) HORS LIGNE (différé puis Left) ⇒ passThreshold', (
        tester,
      ) async {
        final port = _OfflineEvaluationPort();
        final submissions = await submitWith(tester, port);
        expect(port.callCount, 1);
        expect(submissions.single.quality, const ZSrsConfig().passThreshold);
        expect(tester.takeException(), isNull);
      });
    },
  );

  group('🔬 CONTRE-PREUVE : le harnais SAIT faire remonter une exception', () {
    // ⚠️ Leçon su-2 **D3** : sans ces deux contre-preuves, `takeException(),
    // isNull` serait vert même si (a) la doublure ne jetait rien, ou (b) le
    // harnais était structurellement incapable de capter quoi que ce soit — on
    // « prouverait » l'absence d'exception avec un instrument débranché.

    test('(a) la doublure `ThrowingEvaluationPort` JETTE réellement', () {
      // Sans ceci, le cas (3) ci-dessus pourrait passer parce que le port ne
      // jette PAS — et l'on croirait avoir prouvé la garde AD-10.
      final port = ThrowingEvaluationPort();
      expectLater(
        port.evaluateAnswer(
          const ZFlashcardAnswerEvaluationRequest(
            question: 'q',
            userAnswer: 'a',
            cardType: ZFlashcardType.openQuestion,
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(port.callCount, 1);
    });

    testWidgets('(b) ce harnais SAIT capter une exception (instrument branché)', (
      tester,
    ) async {
      // Un widget qui jette pendant `build` : `takeException()` DOIT le rendre.
      // Si cette assertion échouait, tous les `takeException(), isNull` du
      // groupe précédent seraient sans aucune valeur probante.
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(builder: (context) => throw StateError('sonde')),
        ),
      );
      expect(
        tester.takeException(),
        isA<StateError>(),
        reason:
            'le harnais est INCAPABLE de capter une exception ⇒ les '
            '`takeException(), isNull` ci-dessus ne prouveraient RIEN',
      );
    });
  });

  group('AC3 — l\'échec n\'est PAS silencieux et la session CONTINUE', () {
    testWidgets('un feedback de repli l10n est affiché (jamais un blanc)', (
      tester,
    ) async {
      await submitWith(tester, FailingEvaluationPort());
      expect(find.byKey(K.feedback), findsOneWidget);
      final text = tester.widget<Text>(find.byKey(K.feedback)).data;
      expect(text, isNotNull);
      expect(text, isNotEmpty);
    });

    testWidgets(
      'la session CONTINUE : la soumission est enregistrée et la rangée SRS '
      'reste utilisable',
      (tester) async {
        final noted = <int>[];
        final submissions = <ZFlashcardSubmission>[];
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              evaluationPort: ThrowingEvaluationPort(),
              onQualitySelected: noted.add,
              onSubmitted: submissions.add,
            ),
          ),
        );
        await tester.enterText(find.byKey(K.answerField), 'r');
        await tester.pump();
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        expect(submissions, hasLength(1));
        // La rangée SRS est là, pré-sélectionnée sur le cran neutre, et notable.
        await tester.tap(find.byKey(K.quality(4)));
        await tester.pump();
        expect(noted, <int>[4], reason: 'la session doit rester utilisable');
      },
    );
  });

  group('AC3 — le repli est passThreshold, LU (jamais `3` en dur)', () {
    testWidgets('🔴 avec ZSrsConfig(passThreshold: 4) ⇒ le repli vaut 4 (et NON 3)', (
      tester,
    ) async {
      // 🔴 Discriminant D7 : un `3` en dur ROUGIT ici, et seulement ici. Le PRD
      // dit « repli qualité neutre 3 » ; le spine dit « seuil de passage ». Les
      // deux coïncident PARCE QUE `passThreshold == 3` est le défaut — et c'est
      // `passThreshold` qui fait autorité.
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            srsConfig: const ZSrsConfig(passThreshold: 4),
            onSubmitted: submissions.add,
          ),
        ),
      );
      await tester.enterText(find.byKey(K.answerField), 'r');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.quality, 4);
    });
  });

  group('🔴 AC6 — le plafond d\'indices s\'applique AUSSI au chemin de REPLI', () {
    // 🔴 TROU DE COUVERTURE réel de su-3, démasqué par injection : neutraliser le
    // plafond **uniquement** quand `evaluation == null` laissait **198/198
    // VERTS**. Les 4 cas de repli (Left / null / throw / hors ligne) asseraient
    // tous `quality == passThreshold` **avec 0 indice** — le plafond n'y était
    // JAMAIS sollicité.
    //
    // Or AC6 exige explicitement « la fonction est appliquée sur TOUS les chemins
    // de qualité (local AC1, advisory AC2, **repli AC3**, "Je ne sais pas" AC4)
    // — une seule voie, **jamais un chemin qui l'oublie** ».
    //
    // ⚠️ Valeur DISCRIMINANTE choisie : **3 indices** (jamais 2).
    //   - 3 indices : `ceiling = max(5-3, 2) = 2` ⇒ `min(3, 2) = 2` ≠ 3 ⇒ ROUGE
    //     si le plafond est oublié. **Discriminant.**
    //   - 2 indices : `ceiling = max(5-2, 2) = 3` ⇒ `min(3, 3) = 3` — identique
    //     au repli SANS plafond ⇒ **ne discriminerait rien** (leçon D7 : sans
    //     valeur discriminante, le test passe quelle que soit la branche).

    testWidgets(
      '🔴 port HORS LIGNE (`Left`) + 3 indices ⇒ qualité 2 (lapse), jamais 3',
      (tester) async {
        final submissions = <ZFlashcardSubmission>[];
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              evaluationPort: FailingEvaluationPort(),
              hintPort: SpyHintPort(),
              onSubmitted: submissions.add,
            ),
          ),
        );

        // L'apprenant consomme 3 indices…
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.byKey(K.hintButton));
          await tester.pumpAndSettle();
        }
        // …puis rédige, et le routeur IA est hors ligne.
        await tester.enterText(find.byKey(K.answerField), 'ma réponse');
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        expect(submissions.single.hintsUsed, 3);
        expect(
          submissions.single.quality,
          2,
          reason:
              '🔴 le SCÉNARIO EXACT : un apprenant qui a consommé 3 indices '
              'VALIDERAIT sa carte (3 = réussite) grâce à une PANNE RÉSEAU — le '
              'plafond d\'AD-36 contourné par le chemin le plus fréquent en '
              'mobilité (NFR-SU8 : session hors ligne)',
        );
      },
    );

    testWidgets('🔴 port ABSENT + 3 indices ⇒ qualité 2', (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            hintPort: SpyHintPort(),
            onSubmitted: submissions.add,
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(K.answerField), 'ma réponse');
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.quality, 2);
    });

    testWidgets('🔴 port qui JETTE + 3 indices ⇒ qualité 2', (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(),
            mode: ZReviewMode.learn,
            evaluationPort: ThrowingEvaluationPort(),
            hintPort: SpyHintPort(),
            onSubmitted: submissions.add,
          ),
        ),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(K.answerField), 'ma réponse');
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(submissions.single.quality, 2);
    });
  });
}
