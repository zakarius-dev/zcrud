/// AC5 — indices : **stocké D'ABORD**, port **APRÈS ÉPUISEMENT** (avec les
/// indices déjà montrés), générés **ÉPHÉMÈRES** (AD-36).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

void main() {
  group('🔒 AC5 — l\'indice STOCKÉ est servi D\'ABORD (le port n\'est PAS appelé)',
      () {
    testWidgets(
        '🔴 (1) 1ᵉʳ tap ⇒ le hint STOCKÉ s\'affiche ET hintSpy.callCount == 0 '
        '(ABSENCE d\'appel — R3-I5)', (tester) async {
      final spy = SpyHintPort();
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(hint: 'indice stocké de la carte'),
          mode: ZReviewMode.learn,
          hintPort: spy,
        )),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      expect(find.text('indice stocké de la carte'), findsOneWidget);
      expect(spy.callCount, 0,
          reason: 'AD-36 « Prevents : un appel IA superflu » — la carte PORTAIT '
              'déjà son indice');
    });

    testWidgets(
        '🔴 (2) 2ᵉ tap ⇒ callCount == 1 ET request.shownHints CONTIENT le hint '
        'stocké (anti-répétition — R3-I5b)', (tester) async {
      final spy = SpyHintPort();
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(hint: 'indice stocké de la carte'),
          mode: ZReviewMode.learn,
          hintPort: spy,
        )),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      expect(spy.callCount, 1);
      expect(spy.request!.shownHints, <String>['indice stocké de la carte'],
          reason: 'sans les indices déjà montrés, le barème PARAPHRASERAIT le '
              'même indice et l\'apprenant paierait pour rien');
    });

    testWidgets('🔴 (3) 3ᵉ tap ⇒ shownHints.length == 2 (CUMUL réel — R3-I5b)',
        (tester) async {
      final spy = SpyHintPort();
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(hint: 'stocké'),
          mode: ZReviewMode.learn,
          hintPort: spy,
        )),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
      }
      expect(spy.callCount, 2);
      expect(spy.request!.shownHints, hasLength(2));
      expect(spy.request!.shownHints.first, 'stocké');
      expect(spy.request!.shownHints.last, contains('indice généré'));
    });

    testWidgets(
        'AD-10 — hint absent/vide ⇒ le port est appelé DIRECTEMENT (rien à '
        'épuiser)', (tester) async {
      for (final hint in <String?>[null, '']) {
        final spy = SpyHintPort();
        await tester.pumpWidget(
          host(ZFlashcardAnswerInput(
            key: ValueKey<String>('h$hint'),
            card: writtenCard(hint: hint),
            mode: ZReviewMode.learn,
            hintPort: spy,
          )),
        );
        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
        expect(spy.callCount, 1, reason: 'hint=$hint');
        expect(spy.request!.shownHints, isEmpty);
      }
    });
  });

  group('🔒 AC5 — les indices générés sont ÉPHÉMÈRES (carte JAMAIS mutée)', () {
    testWidgets(
        '🔴 (4) identical(carte avant, carte après) ET aucune écriture',
        (tester) async {
      final card = writtenCard(hint: 'stocké');
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: card,
          mode: ZReviewMode.learn,
          hintPort: SpyHintPort(),
        )),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
      }

      final after =
          tester.widget<ZFlashcardAnswerInput>(find.byType(ZFlashcardAnswerInput));
      expect(identical(after.card, card), isTrue,
          reason: 'la carte a été REMPLACÉE : un indice généré est une aide de '
              'SESSION, jamais une donnée de la carte');
      // La carte n'a pas absorbé les indices générés.
      expect(after.card.hint, 'stocké');
      // 🔒 Aucune écriture n'est même POSSIBLE : la garde de source
      // `z_widgets_purity_test.dart` interdit tout `ZRepetitionStore`/
      // repository dans `presentation/**` (aucun store n'est injectable ici).
    });
  });

  group('🔒 AC5 — port ABSENT ⇒ bouton ABSENT après épuisement (jamais grisé)',
      () {
    testWidgets('hint stocké + port null ⇒ bouton présent, puis ABSENT',
        (tester) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(hint: 'le seul indice'),
          mode: ZReviewMode.learn,
        )),
      );
      // Le stocké est disponible ⇒ bouton offert.
      expect(find.byKey(K.hintButton), findsOneWidget);

      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      expect(find.text('le seul indice'), findsOneWidget);
      // Épuisé et aucun port ⇒ le bouton DISPARAÎT (patron ZItemActionsMenu :
      // absent si non fourni, JAMAIS grisé — un bouton grisé promet une action
      // qui n'existe pas).
      expect(find.byKey(K.hintButton), findsNothing);
    });

    testWidgets('aucun hint stocké + port null ⇒ bouton ABSENT d\'emblée',
        (tester) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
        )),
      );
      expect(find.byKey(K.hintButton), findsNothing);
    });
  });

  group('🔒 AC5 — échec/throw ⇒ aucune exception, compteur NON incrémenté', () {
    testWidgets(
        '🔴 (5) port en ÉCHEC ⇒ compteur d\'indices INCHANGÉ (R3-I5c)',
        (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          hintPort: FailingHintPort(),
          onSubmitted: submissions.add,
        )),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byKey(K.answerField), 'r');
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.hintsUsed, 0,
          reason: 'un indice NON OBTENU ne doit pas pénaliser l\'apprenant');
      // …et donc la qualité n'est PAS plafonnée.
      expect(submissions.single.quality, const ZSrsConfig().passThreshold);
    });

    testWidgets('port qui JETTE ⇒ aucune exception, compteur inchangé',
        (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          hintPort: ThrowingHintPort(),
          onSubmitted: submissions.add,
        )),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(K.dontKnow));
      await tester.pumpAndSettle();
      expect(submissions.single.hintsUsed, 0);
    });

    testWidgets('l\'échec n\'est pas silencieux : un message l10n s\'affiche',
        (tester) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: writtenCard(),
          mode: ZReviewMode.learn,
          hintPort: FailingHintPort(),
        )),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      expect(find.text('Indice indisponible.'), findsOneWidget);
    });
  });

  group('AC5/AC6 — les indices MODULENT la qualité (via le plafond)', () {
    testWidgets('🔴 2 indices ⇒ une réponse EXACTE de QCM plafonne à 3',
        (tester) async {
      // Le plafond est appliqué sur TOUS les chemins, y compris local (AC6).
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(
          card: const ZFlashcard(
            question: 'Capitale du Togo ?',
            type: ZFlashcardType.multipleChoice,
            hint: 'stocké',
            choices: <ZChoice>[
              ZChoice(content: 'Accra'),
              ZChoice(content: 'Lomé', isCorrect: true),
            ],
          ),
          mode: ZReviewMode.learn,
          hintPort: SpyHintPort(),
          onSubmitted: submissions.add,
        )),
      );
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(K.choice(1))); // la BONNE réponse
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.hintsUsed, 2);
      expect(submissions.single.quality, 3,
          reason: '5 (exact) plafonné de 2 crans par 2 indices ⇒ 3');
    });
  });
}
