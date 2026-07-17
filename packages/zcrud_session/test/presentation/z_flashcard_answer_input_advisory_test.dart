/// AC2 — port **ADVISORY** : bouton SRS **PRÉ-SÉLECTIONNÉ**, l'utilisateur
/// valide ; le port n'écrit **JAMAIS** le SRS (AD-33/AD-35/AD-46).
/// AC4 — « Je ne sais pas » = **borne basse**, sans appel au port.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

void main() {
  Future<void> pumpAndSubmit(
    WidgetTester tester, {
    required Widget widget,
    String answer = 'ma réponse',
  }) async {
    await tester.pumpWidget(widget);
    await tester.enterText(find.byKey(K.answerField), answer);
    await tester.pump();
    await tester.tap(find.byKey(K.submit));
    await tester.pumpAndSettle();
  }

  group('AC2 — la suggestion du port est PRÉ-SÉLECTIONNÉE et CLAMPÉE', () {
    testWidgets('suggestedQuality: 4 ⇒ le cran 4 est pré-sélectionné',
        (tester) async {
      await pumpAndSubmit(
        tester,
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
          onQualitySelected: (_) {},
        )),
      );
      expect(
        tester.getSemantics(find.byKey(K.quality(4))).hasFlag(SemanticsFlag.isSelected),
        isTrue,
        reason: 'le cran suggéré n\'est pas pré-sélectionné (AC2)',
      );
      // …et lui SEUL.
      for (final q in <int>[0, 1, 2, 3, 5]) {
        expect(
          tester.getSemantics(find.byKey(K.quality(q))).hasFlag(SemanticsFlag.isSelected),
          isFalse,
          reason: 'le cran $q ne devrait pas être sélectionné',
        );
      }
    });

    testWidgets('suggestedQuality: 9 (HORS BORNES) ⇒ cran 5, jamais hors échelle',
        (tester) async {
      await pumpAndSubmit(
        tester,
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(suggestedQuality: 9),
          onQualitySelected: (_) {},
        )),
      );
      expect(
        tester.getSemantics(find.byKey(K.quality(5))).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
      // Aucun cran hors échelle n'existe : la rangée est DÉRIVÉE de ZSrsConfig.
      expect(find.byKey(K.quality(9)), findsNothing);
    });

    testWidgets(
        '🔴 suggestedQuality: -3 ⇒ cran 0 — le PORTEUR du clamp '
        '(le cas haut « 9 ⇒ 5 » est masqué par le plafond, leçon D12)',
        (tester) async {
      // Cf. `z_hint_penalty_test.dart` : avec 0 indice, le plafond rend déjà 5
      // même SANS clamp ⇒ le cas HAUT ne discrimine pas. Seule la borne BASSE
      // prouve que `clampQuality` est réellement appelé (R3-I2).
      final submissions = <ZFlashcardSubmission>[];
      await pumpAndSubmit(
        tester,
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(suggestedQuality: -3),
          onQualitySelected: (_) {},
          onSubmitted: submissions.add,
        )),
      );
      expect(submissions.single.quality, 0,
          reason: 'sans `clampQuality`, la note serait -3 : HORS échelle');
      expect(
        tester.getSemantics(find.byKey(K.quality(0))).hasFlag(SemanticsFlag.isSelected),
        isTrue,
      );
    });
  });

  group('🔒 AC2 — ADVISORY ≠ NOTATION (le port SUGGÈRE, il ne note pas)', () {
    testWidgets(
        '🔴 la SEULE soumission n\'invoque PAS onQualitySelected (R3-I2b)',
        (tester) async {
      final noted = <int>[];
      await pumpAndSubmit(
        tester,
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
          onQualitySelected: noted.add,
        )),
      );
      expect(noted, isEmpty,
          reason: 'la soumission a NOTÉ : le port ne doit que SUGGÉRER — '
              'c\'est le TAP de l\'utilisateur qui vaut notation (AD-35)');
    });

    testWidgets('c\'est le TAP sur un cran qui note (voie UNIQUE)',
        (tester) async {
      final noted = <int>[];
      await pumpAndSubmit(
        tester,
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
          onQualitySelected: noted.add,
        )),
      );
      await tester.tap(find.byKey(K.quality(2)));
      await tester.pump();
      expect(noted, <int>[2],
          reason: 'l\'utilisateur reste maître : il peut noter AUTREMENT que la '
              'suggestion');
    });

    testWidgets(
        '🔒 rangée SRS ABSENTE si onQualitySelected == null (patron '
        'ZItemActionsMenu — jamais grisée, jamais un booléen)', (tester) async {
      await pumpAndSubmit(
        tester,
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(),
        )),
      );
      expect(find.byType(ZSrsQualityButtons), findsNothing);
    });
  });

  group('AC2 — la requête AD-35 est transmise fidèlement', () {
    testWidgets('la requête porte question/userAnswer/cardType/expected/explication',
        (tester) async {
      final spy = SpyEvaluationPort();
      await pumpAndSubmit(
        tester,
        answer: 'le transit suspend les droits',
        widget: host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: spy,
        )),
      );
      final request = spy.request!;
      expect(request.question, 'Expliquez le transit douanier.');
      expect(request.userAnswer, 'le transit suspend les droits');
      expect(request.cardType, ZFlashcardType.openQuestion);
      expect(request.expectedAnswer, 'réponse attendue');
      expect(request.explanation, 'explication');
    });

    testWidgets('🔴 hintsUsed == 2 après 2 indices (transmis INFORMATIVEMENT)',
        (tester) async {
      final spy = SpyEvaluationPort();
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(hint: 'indice stocké'),
          mode: ZReviewMode.learn,
          evaluationPort: spy,
          hintPort: SpyHintPort(),
        )),
      );
      // 1ᵉʳ indice : le STOCKÉ. 2ᵉ : le port.
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(K.answerField), 'ma réponse');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(spy.request!.hintsUsed, 2);
    });

    testWidgets('timeTaken est transmis (mesuré même hors affichage)',
        (tester) async {
      final spy = SpyEvaluationPort();
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: spy,
        )),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.enterText(find.byKey(K.answerField), 'r');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(spy.request!.timeTaken, isNotNull);
      expect(spy.request!.timeTaken!.inMilliseconds, greaterThan(0));
    });
  });

  group('AC6 — le plafond s\'applique AUSSI sur le chemin ADVISORY', () {
    testWidgets(
        '🔴 port ⇒ 5 avec 3 indices ⇒ qualité 2 (ANTI-CONTOURNEMENT, R3-I6d)',
        (tester) async {
      // AD-36 : « un port qui rend 10 indices ne contourne pas le plafond ».
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(hint: 'indice stocké'),
          mode: ZReviewMode.learn,
          evaluationPort: SpyEvaluationPort(suggestedQuality: 5),
          hintPort: SpyHintPort(),
          onSubmitted: submissions.add,
        )),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byKey(K.answerField), 'r');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.hintsUsed, 3);
      expect(submissions.single.quality, 2,
          reason: 'le chemin advisory a OUBLIÉ le plafond (R3-I6d) : le port '
              'suggère 5, 3 indices plafonnent à 2');
    });
  });

  group('🔒 AC4 — « Je ne sais pas » = borne basse, SANS appel au port', () {
    testWidgets('🔴 spy.callCount == 0 ET quality == minQuality', (tester) async {
      final spy = SpyEvaluationPort();
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          evaluationPort: spy,
          onSubmitted: submissions.add,
        )),
      );
      await tester.tap(find.byKey(K.dontKnow));
      await tester.pumpAndSettle();

      expect(spy.callCount, 0, reason: 'AD-35 : « borne basse, SANS appel »');
      expect(submissions.single.quality, const ZSrsConfig().minQuality);
      expect(submissions.single.isCorrect, isFalse);
    });

    testWidgets(
        '🔴 avec ZSrsConfig(minQuality: 1) ⇒ la soumission vaut 1 '
        '(la borne est LUE, jamais codée en dur — R3-I4)', (tester) async {
      // ⚠️ ÉCART PRD ASSUMÉ (arbitrage n°1) : le PRD dit « qualité 1 », le spine
      // dit « borne basse ». Le spine prime — et avec `minQuality: 1` les deux
      // lectures COÏNCIDENT. Ce test prouve que la valeur est LUE : un `0` (ou
      // un `1`) en dur ROUGIT sur l'un des deux cas.
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          srsConfig: const ZSrsConfig(minQuality: 1),
          onSubmitted: submissions.add,
        )),
      );
      await tester.tap(find.byKey(K.dontKnow));
      await tester.pumpAndSettle();
      expect(submissions.single.quality, 1);
    });

    testWidgets('« Je ne sais pas » est IMMÉDIAT (aucune saisie requise)',
        (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          onSubmitted: submissions.add,
        )),
      );
      // Champ VIDE : aucun texte saisi.
      await tester.tap(find.byKey(K.dontKnow));
      await tester.pumpAndSettle();
      expect(submissions, hasLength(1));
    });
  });
}
