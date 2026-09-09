/// **Notation MANUELLE, présentation de carte, et drapeaux de saisie** —
/// l'assemblage de session.
///
/// ## Le défaut visé
///
/// La rangée de paliers montée d'emblée (`ZAnswerGradingVisibility.always`)
/// verrouille la surface dès qu'un cran est tapé : la saisie devient inerte,
/// le contrôle de soumission quitte l'arbre. L'assemblage, lui, ne relayait
/// que le **rappel** — aucune écriture n'atteignait le moteur, la carte
/// restait figée, et la session était sans issue.
///
/// Second défaut, de la même famille : une carte réinsérée au lapse revient
/// sous la même identité. Sa surface de saisie portait la même `key`, donc le
/// même `State` — la réponse déjà tapée et sa correction survivaient à leur
/// propre notation.
///
/// ## Ce que ces gardes mesurent
///
/// 🔴 Elles comptent les **écritures du seam de révision**
/// (`FakeSessionReviewer.writes`), jamais les notifications de la surface.
/// C'est exactement la différence qui a laissé passer le défaut : une garde
/// qui compte les rappels reste verte sur une session qui n'écrit rien.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudScope;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcard,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardFaceContent,
        ZFlashcardReviewCard,
        ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZFlashcardAnswerInput,
        ZFlashcardSubmission,
        ZSessionItem,
        ZSessionReviewer,
        ZSrsQualityButtons;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import '../support/lotw1_seams.dart' show W1EvaluationPort;
import '../support/z_study_session_harness.dart';

const ValueKey<String> kField = ValueKey<String>('zAnswerField');
const ValueKey<String> kSubmit = ValueKey<String>('zSubmit');
const ValueKey<String> kHint = ValueKey<String>('zHintButton');

Finder _quality(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

/// Clé de la surface de saisie d'une carte à sa `n`-ième présentation.
Finder _answerOf(String id, int presentation) =>
    find.byKey(ValueKey<String>('zStudySessionAnswer_$id#$presentation'));

ZFlashcard _hintedCard(String id) => ZFlashcard(
      id: id,
      folderId: kHarnessFolderId,
      type: ZFlashcardType.openQuestion,
      question: 'Question $id.',
      answer: 'r$id',
      hint: 'lotl2:indice-stocke',
    );

Widget _wrap(Widget child) =>
    MaterialApp(home: ZcrudScope(child: Scaffold(body: child)));

Future<void> _pump(
  WidgetTester tester, {
  required List<ZFlashcard> queue,
  required ZReviewMode mode,
  ZSessionReviewer? reviewer,
  ValueChanged<int>? onQualitySelected,
  ZAnswerGradingVisibility? answerGradingVisibility,
  ZStudySessionPostSubmitPolicy postSubmitPolicy =
      ZStudySessionPostSubmitPolicy.auto,
  ZFlashcardAnswerEvaluationPort? evaluationPort,
  bool? answerAllowSkipEvaluation,
  bool? answerRevealStoredHint,
  void Function(ZFlashcard card)? onSource,
  String Function(ZFlashcard card, int quality)? qualityPreviewLabelForCard,
}) async {
  useTallSurface(tester);
  await tester.pumpWidget(_wrap(ZStudySessionHost(
    mode: mode,
    queue: queue,
    reviewer: reviewer,
    onQualitySelected: onQualitySelected,
    answerGradingVisibility: answerGradingVisibility,
    postSubmitPolicy: postSubmitPolicy,
    evaluationPort: evaluationPort,
    answerAllowSkipEvaluation: answerAllowSkipEvaluation,
    answerRevealStoredHint: answerRevealStoredHint,
    onSource: onSource,
    qualityPreviewLabelForCard: qualityPreviewLabelForCard,
  )));
  await tester.pumpAndSettle();
}

/// Rédige une réponse puis la soumet.
Future<void> _submit(WidgetTester tester, {String answer = 'ma réponse'}) async {
  await tester.enterText(find.byKey(kField), answer);
  await tester.pump();
  await tester.tap(find.byKey(kSubmit));
  await tester.pumpAndSettle();
}

void main() {
  // ═════════════════════════════════════════════════════════════════════════
  // Le contrat de notation — AVANT la réponse, le palier NOTE
  // ═════════════════════════════════════════════════════════════════════════
  group('🔴 `always` — un palier tapé AVANT la réponse NOTE la carte', () {
    testWidgets('exactement UNE écriture, avec la qualité tapée',
        (WidgetTester tester) async {
      final List<int> taps = <int>[];
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(2),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
        onQualitySelected: taps.add,
        answerGradingVisibility: ZAnswerGradingVisibility.always,
      );

      await tester.tap(_quality(5));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 1,
          reason: '🔴 le palier tapé avant la réponse doit NOTER la carte — '
              'compter les rappels laisserait cette mesure verte à zéro');
      expect(reviewer.qualities, <int>[5]);
      expect(reviewer.gradedIds, <String>['c0']);
      expect(taps, <int>[5],
          reason: 'le rappel de l\'hôte part toujours, en plus de l\'écriture');
    });

    testWidgets('sans retenue, la FILE avance : la carte notée part',
        (WidgetTester tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(2),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
        onQualitySelected: (int q) {},
        answerGradingVisibility: ZAnswerGradingVisibility.always,
        // Sans retenue : le passage est immédiat, exactement comme après une
        // soumission dans le même régime.
        postSubmitPolicy: ZStudySessionPostSubmitPolicy.advance,
      );
      expect(_answerOf('c0', 0), findsOneWidget);

      await tester.tap(_quality(5));
      await tester.pumpAndSettle();

      expect(_answerOf('c1', 0), findsOneWidget,
          reason: '🔴 la carte notée à la main ne part pas : la session reste '
              'figée sur une saisie verrouillée');
      expect(_answerOf('c0', 0), findsNothing);
      expect(reviewer.writes, 1);
    });

    testWidgets('la surface se verrouille, et un SECOND geste n\'écrit rien',
        (WidgetTester tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(2),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
        onQualitySelected: (int q) {},
        answerGradingVisibility: ZAnswerGradingVisibility.always,
      );

      await tester.tap(_quality(5));
      await tester.pumpAndSettle();
      expect(find.byKey(kSubmit), findsNothing,
          reason: 'la surface notée à la main retire sa soumission');

      await tester.tap(_quality(0), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(reviewer.writes, 1,
          reason: '🔒 AD-33 — une seule écriture par présentation de carte');
      expect(reviewer.qualities, <int>[5],
          reason: 'la note retenue est celle du PREMIER cran tapé');
    });

    testWidgets('mode d\'apprentissage : la carte notée est RETENUE, et son '
        'écriture est déjà partie', (WidgetTester tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(2),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
        onQualitySelected: (int q) {},
        answerGradingVisibility: ZAnswerGradingVisibility.always,
      );

      await tester.tap(_quality(5));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 1, reason: 'la note part au geste, pas au départ');
      expect(_answerOf('c0', 0), findsOneWidget,
          reason: '🔴 la retenue ne s\'applique pas à la notation manuelle : '
              'la réponse disparaît avant d\'avoir pu être lue');
      final Finder cont = find.byKey(ZStudySessionHost.continueActionKey);
      expect(cont, findsOneWidget);

      await tester.tap(cont);
      await tester.pumpAndSettle();
      expect(_answerOf('c1', 0), findsOneWidget);
      expect(reviewer.writes, 1,
          reason: '🔒 la continuation n\'écrit rien : elle laisse partir');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Le résultat agrégé compte les cartes NOTÉES, pas les réponses rédigées
  // ═════════════════════════════════════════════════════════════════════════
  group('🧮 résultat de session', () {
    testWidgets('une carte notée à la main COMPTE dans le résultat',
        (WidgetTester tester) async {
      final List<ZStudySessionResult> ends = <ZStudySessionResult>[];
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(ZStudySessionHost(
        mode: ZReviewMode.learn,
        queue: writtenCards(1),
        reviewer: FakeSessionReviewer().call,
        onQualitySelected: (int q) {},
        answerGradingVisibility: ZAnswerGradingVisibility.always,
        onSessionEnd: (ZStudySessionResult r, Duration d) => ends.add(r),
      )));
      await tester.pumpAndSettle();

      await tester.tap(_quality(5));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();

      expect(ends, hasLength(1));
      expect(ends.single.total, 1,
          reason: '🔴 une carte notée sans réponse rédigée sort du décompte : '
              'la session se termine sur un résultat vide');
      expect(ends.single.correct, 1);
      expect(ends.single.byQuality, <String, int>{'5': 1});
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // Une écriture par PRÉSENTATION — y compris depuis une surface d'hôte
  // ═════════════════════════════════════════════════════════════════════════
  group('🔒 AD-33 — deux soumissions pour la même présentation n\'écrivent '
      'qu\'une fois', () {
    testWidgets('une surface d\'hôte qui soumet DEUX fois ne note qu\'une '
        'fois', (WidgetTester tester) async {
      // 🔴 La surface du socle porte son propre verrou one-shot : elle ne peut
      // pas produire ce geste. Une surface fournie par l'hôte, si — et c'est
      // l'assemblage qui doit alors tenir l'invariant.
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(ZStudySessionHost(
        // `spaced` : aucune retenue après notation — le seul régime où la
        // seconde soumission n'est pas déjà arrêtée par le gel d'affichage.
        mode: ZReviewMode.spaced,
        queue: writtenCards(2),
        reviewer: reviewer.call,
        gradingBuilder: (
          BuildContext context,
          ZSessionItem item,
          ValueChanged<ZFlashcardSubmission> submit,
        ) =>
            TextButton(
          key: const ValueKey<String>('lotl2:double-submit'),
          onPressed: () {
            const ZFlashcardSubmission sub = ZFlashcardSubmission(
              quality: 5,
              timeTaken: Duration.zero,
              hintsUsed: 0,
            );
            submit(sub);
            submit(sub);
          },
          child: const Text('lotl2:soumettre-deux-fois'),
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>(
        'lotl2:double-submit',
      )));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 1,
          reason: '🔴 deux écritures pour UNE présentation de carte (AD-33)');
      expect(reviewer.gradedIds, <String>['c0']);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // …et APRÈS la réponse, c'est la soumission qui a noté
  // ═════════════════════════════════════════════════════════════════════════
  group('🟢 `afterSubmit` — le palier tapé après la réponse ne fait que '
      'notifier', () {
    testWidgets('la soumission note, le cran suivant n\'écrit pas une '
        'seconde fois', (WidgetTester tester) async {
      final List<int> taps = <int>[];
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(2),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
        onQualitySelected: taps.add,
      );
      // Régime de référence : aucune rangée avant la réponse.
      expect(find.byType(ZSrsQualityButtons), findsNothing);
      expect(reviewer.writes, 0);

      await _submit(tester);
      expect(reviewer.writes, 1, reason: 'la soumission NOTE, comme toujours');
      expect(find.byType(ZSrsQualityButtons), findsOneWidget);

      await tester.tap(_quality(0));
      await tester.pumpAndSettle();
      expect(taps, <int>[0],
          reason: 'le cran tapé après la réponse reste un rappel');
      expect(reviewer.writes, 1,
          reason: '🔴 le cran advisory a doublé la note de la soumission');
      expect(reviewer.qualities, hasLength(1),
          reason: 'la note écrite reste celle de la soumission');
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // La clé de PRÉSENTATION — une carte réinsérée repart vierge
  // ═════════════════════════════════════════════════════════════════════════
  group('🔑 une carte réinsérée au lapse repart sur une saisie VIERGE', () {
    testWidgets('la saisie précédente ne fuit pas sur la nouvelle '
        'présentation', (WidgetTester tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      // UNE carte : le lapse la réinsère SEULE, donc la file de devant ne
      // change pas d'identité — le seul état où la fuite est atteignable.
      await _pump(
        tester,
        queue: writtenCards(1),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
      );
      expect(_answerOf('c0', 0), findsOneWidget);

      // Une réponse est TAPÉE, puis la carte est passée : la note tombe à la
      // borne basse, donc un LAPSE — le seul geste qui réinsère la carte.
      await tester.enterText(find.byKey(kField), 'lotl2:reponse-precedente');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(reviewer.writes, 1);
      expect(reviewer.qualities, <int>[0], reason: 'sonde : c\'est un lapse');
      expect(find.text('lotl2:reponse-precedente'), findsWidgets,
          reason: 'sonde : la réponse tapée est bien à l\'écran avant le '
              'départ de la carte');

      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();

      expect(_answerOf('c0', 1), findsOneWidget,
          reason: '🔴 la clé de la saisie ne porte pas le numéro de '
              'présentation : le `State` de la présentation précédente '
              'survit à la carte réinsérée');
      expect(_answerOf('c0', 0), findsNothing);
      expect(find.text('lotl2:reponse-precedente'), findsNothing,
          reason: '🔴 la réponse de la présentation précédente a FUI sur la '
              'nouvelle');
      expect(find.byKey(kSubmit), findsOneWidget,
          reason: 'la nouvelle présentation est saisissable, pas verrouillée');
      expect(find.byType(ZSrsQualityButtons), findsNothing,
          reason: 'aucune correction héritée de la présentation précédente');
      expect(reviewer.writes, 1,
          reason: 'la présentation neuve n\'a encore rien écrit');
    });

    testWidgets('…et elle repart FACE QUESTION, jamais sur sa correction',
        (WidgetTester tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(1),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
      );
      await tester.tap(find.byKey(const ValueKey<String>('zDontKnow')));
      await tester.pumpAndSettle();
      expect(find.text('r0'), findsWidgets,
          reason: 'sonde : la retenue montre bien la réponse de la carte');

      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();
      expect(find.text('r0'), findsNothing,
          reason: '🔴 la carte réinsertée revient FACE RÉPONSE : la question '
              'qu\'on redemande est déjà corrigée à l\'écran');
    });

    testWidgets('🔬 contre-preuve : sans notation, le numéro ne bouge pas',
        (WidgetTester tester) async {
      await _pump(
        tester,
        queue: writtenCards(1),
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
      );
      // Un rebuild pur, aucune notation : la présentation reste la même —
      // sinon le compteur remonterait la saisie à chaque frame et l'apprenant
      // perdrait sa frappe.
      await tester.pump();
      expect(_answerOf('c0', 0), findsOneWidget);
      expect(_answerOf('c0', 1), findsNothing);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // CR-97 — les deux drapeaux de la surface de saisie, relayés
  // ═════════════════════════════════════════════════════════════════════════
  group('🚩 drapeaux de la surface de saisie', () {
    testWidgets('`answerAllowSkipEvaluation` monte la voie « sans IA »',
        (WidgetTester tester) async {
      await _pump(
        tester,
        queue: writtenCards(1),
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
        evaluationPort: W1EvaluationPort(),
        answerAllowSkipEvaluation: true,
      );
      expect(find.byKey(ZFlashcardAnswerInput.skipEvaluationKey), findsOneWidget,
          reason: '🔴 le drapeau n\'atteint pas la surface montée par '
              'l\'assemblage');
    });

    testWidgets('🔬 non-vacuité : sans le drapeau, la voie « sans IA » est '
        'ABSENTE', (WidgetTester tester) async {
      await _pump(
        tester,
        queue: writtenCards(1),
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
        evaluationPort: W1EvaluationPort(),
      );
      expect(find.byKey(ZFlashcardAnswerInput.skipEvaluationKey), findsNothing);
    });

    testWidgets('`answerRevealStoredHint` sert l\'indice stocké d\'emblée',
        (WidgetTester tester) async {
      await _pump(
        tester,
        queue: <ZFlashcard>[_hintedCard('c0')],
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
        answerRevealStoredHint: true,
      );
      expect(find.text('lotl2:indice-stocke'), findsOneWidget,
          reason: '🔴 le drapeau n\'atteint pas la surface');
      expect(find.byKey(kHint), findsNothing,
          reason: 'le stocké servi, il ne reste rien derrière le bouton');
    });

    testWidgets('🔬 non-vacuité : sans le drapeau, l\'indice reste derrière '
        'son bouton', (WidgetTester tester) async {
      await _pump(
        tester,
        queue: <ZFlashcard>[_hintedCard('c0')],
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
      );
      expect(find.text('lotl2:indice-stocke'), findsNothing);
      expect(find.byKey(kHint), findsOneWidget);
    });

    testWidgets('les deux à `null` : la surface garde ses défauts',
        (WidgetTester tester) async {
      await _pump(
        tester,
        queue: <ZFlashcard>[_hintedCard('c0')],
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
        evaluationPort: W1EvaluationPort(),
      );
      final ZFlashcardAnswerInput input =
          tester.widget<ZFlashcardAnswerInput>(find.byType(
        ZFlashcardAnswerInput,
      ));
      expect(input.allowSkipEvaluation, isFalse);
      expect(input.revealStoredHint, isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  // CR-96 / CR-95 — les deux seams neufs, au bon destinataire
  // ═════════════════════════════════════════════════════════════════════════
  group('🔗 seams de carte — devant seulement', () {
    testWidgets('`onSource` ne monte son action que sur la carte CONSULTÉE',
        (WidgetTester tester) async {
      final List<String> opened = <String>[];
      await _pump(
        tester,
        queue: writtenCards(3),
        mode: ZReviewMode.learn,
        reviewer: FakeSessionReviewer().call,
        onSource: (ZFlashcard card) => opened.add(card.id ?? ''),
      );
      expect(find.byKey(ZFlashcardReviewCard.sourceActionKey), findsOneWidget,
          reason: '🔴 la pile porte trois cartes : une action par carte '
              'offrirait de remonter à la source d\'une question non lue');

      await tester.tap(find.byKey(ZFlashcardReviewCard.sourceActionKey));
      await tester.pumpAndSettle();
      expect(opened, <String>['c0']);
    });

    testWidgets('…y compris quand les cartes empilées rendent leur CONTENU',
        (WidgetTester tester) async {
      // 🔴 Sans ce régime, les cartes de rang > 0 sont muettes et ne portent
      // aucune rangée d'actions : la mesure resterait verte même si l'action
      // était posée sur toutes les cartes. C'est le seul état qui discrimine.
      useTallSurface(tester);
      await tester.pumpWidget(_wrap(ZStudySessionHost(
        mode: ZReviewMode.learn,
        queue: writtenCards(3),
        reviewer: FakeSessionReviewer().call,
        backCardsContent: ZFlashcardFaceContent.full,
        onSource: (ZFlashcard card) {},
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(ZFlashcardReviewCard.sourceActionKey), findsOneWidget,
          reason: '🔴 l\'action de source est posée sur les cartes empilées : '
              'elle offre de remonter à la source d\'une question non lue');
    });

    testWidgets('l\'aperçu par carte reçoit la carte de DEVANT, y compris '
        'après avancement', (WidgetTester tester) async {
      final FakeSessionReviewer reviewer = FakeSessionReviewer();
      await _pump(
        tester,
        queue: writtenCards(2),
        mode: ZReviewMode.learn,
        reviewer: reviewer.call,
        onQualitySelected: (int q) {},
        qualityPreviewLabelForCard: (ZFlashcard card, int q) =>
            'lotl2:${card.id}:J+$q',
      );

      await _submit(tester);
      expect(find.text('lotl2:c0:J+5'), findsOneWidget);

      await tester.tap(find.byKey(ZStudySessionHost.continueActionKey));
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(find.text('lotl2:c1:J+5'), findsOneWidget,
          reason: '🔴 l\'aperçu porte encore la carte précédente : il '
              'afficherait un intervalle qui n\'est celui de personne');
      expect(find.text('lotl2:c0:J+5'), findsNothing);
    });
  });
}
