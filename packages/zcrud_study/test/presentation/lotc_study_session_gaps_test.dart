/// **Lot C « session assemblée »** — les trois écarts mesurés à l'appareil,
/// une garde chacun.
///
/// | # | Écart | Ce qui casse sans le correctif |
/// |---|---|---|
/// | 1 | mode d'apprentissage : la réponse n'est pas atteignable depuis l'assemblage | l'objet même du mode est perdu |
/// | 2 | rappel de question rendu en entier sur écran étroit | la saisie passe sous la ligne de flottaison |
/// | 3 | inset bas non gouvernable / rendu deux fois | cibles sous la barre système, ou gouttière double |
///
/// 🔒 **L'invariant porteur de l'écart 1** : la révélation se REFERME quand la
/// carte de devant change. Sans lui, l'apprenant voit la RÉPONSE de la carte
/// suivante avant sa question — la carte de devant est un `Element` neuf (sa
/// `key` dérive du `flashcardId`), donc le reset interne de la carte au
/// changement de `card` ne s'y produit jamais.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardAnswerInput;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import '../support/z_study_session_harness.dart';

/// Libellé de repli de l'action de révélation, face QUESTION.
const String kRevealFallback = 'Afficher la réponse';

/// Libellé de repli de l'action de révélation, face RÉPONSE.
const String kHideFallback = 'Masquer la réponse';

void main() {
  Widget host(
    List<ZFlashcard> cards,
    FakeSessionReviewer reviewer, {
    ZReviewMode mode = ZReviewMode.learn,
    ZStudySessionRevealPolicy revealPolicy = ZStudySessionRevealPolicy.auto,
    ZStudySessionQuestionRecall recall = ZStudySessionQuestionRecall.auto,
    double? bottomInset,
    Widget Function(BuildContext, ZFlashcard)? cardBuilder,
    EdgeInsets? systemPadding,
  }) {
    final Widget session = ZStudySessionHost(
      mode: mode,
      queue: cards,
      reviewer: reviewer.call,
      revealPolicy: revealPolicy,
      questionRecall: recall,
      bottomInset: bottomInset,
      cardBuilder: cardBuilder,
    );
    if (systemPadding == null) return wrapForTest(session);
    // L'inset système est posé SOUS le `Scaffold` : c'est la seule façon
    // d'observer ce que la surface de session en fait réellement (le
    // `Scaffold` retire l'inset de son `body` quand il porte lui-même une
    // barre basse).
    return wrapForTest(
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(padding: systemPadding),
          child: session,
        ),
      ),
    );
  }

  /// Rétrécit la fenêtre : largeur < `ZStudySessionReference.narrowWidth`.
  void useNarrowSurface(WidgetTester tester, {double width = 360}) {
    tester.view.physicalSize = Size(
      width * tester.view.devicePixelRatio,
      6000 * tester.view.devicePixelRatio,
    );
    addTearDown(tester.view.resetPhysicalSize);
  }

  // ── ÉCART 1 ───────────────────────────────────────────────────────────────
  group('🔴 écart 1 — la réponse est ATTEIGNABLE en mode apprentissage', () {
    testWidgets('l\'action de révélation est présente et DÉVOILE la réponse',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(host(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      expect(find.byKey(ZStudySessionHost.revealActionKey), findsOneWidget,
          reason: '🔴 sans elle, l\'assemblage n\'offre AUCUNE voie vers la '
              'réponse — l\'objet même du mode d\'apprentissage');
      expect(find.text('r0'), findsNothing,
          reason: 'départ face question');

      await tester.tap(find.byKey(ZStudySessionHost.revealActionKey));
      await tester.pumpAndSettle();

      expect(find.text('r0'), findsOneWidget,
          reason: '🔴 la réponse de la carte de DEVANT est dévoilée');
      expect(find.text(kHideFallback), findsOneWidget,
          reason: 'le libellé décrit ce que le geste fait MAINTENANT');
    });

    testWidgets(
        '🔴 la révélation n\'écrit RIEN : ni SRS, ni avance de pile (AD-9/AD-33)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(host(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZStudySessionHost.revealActionKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZStudySessionHost.revealActionKey));
      await tester.pumpAndSettle();

      expect(reviewer.writes, 0,
          reason: '🔴 la voie d\'écriture SRS est UNIQUE : dévoiler n\'est pas '
              'noter');
      expect(
        find.byKey(const ValueKey<String>('zStudySessionAnswer_c0')),
        findsOneWidget,
        reason: 'la pile n\'a pas avancé',
      );
    });

    testWidgets(
        '🔒 INVARIANT PORTEUR — la révélation se REFERME quand la carte de '
        'devant change', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(host(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZStudySessionHost.revealActionKey));
      await tester.pumpAndSettle();
      expect(find.text('r0'), findsOneWidget, reason: 'sonde : c0 est dévoilée');

      // Un lapse fait avancer le front du moteur à c1 — après continuation
      // (la carte notée est retenue le temps que sa réponse soit lue).
      await dontKnowThenContinue(tester);
      expect(
        find.byKey(const ValueKey<String>('zStudySessionAnswer_c1')),
        findsOneWidget,
        reason: 'sonde : le front est bien passé à c1',
      );

      expect(find.text('r1'), findsNothing,
          reason: '🔴 sans le reset, l\'apprenant verrait la RÉPONSE de c1 '
              'AVANT sa question — la carte de devant est un `Element` neuf, '
              'son reset interne ne s\'y produit pas');
      expect(find.text(kRevealFallback), findsOneWidget,
          reason: 'l\'action est revenue à « afficher »');
    });

    testWidgets(
        '🔴 la carte EMPILÉE DERRIÈRE n\'est pas dévoilée (créneau `isFront`)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(host(writtenCards(3), reviewer));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZStudySessionHost.revealActionKey));
      await tester.pumpAndSettle();

      expect(find.text('r0'), findsOneWidget, reason: 'sonde : c0 dévoilée');
      expect(find.text('r1'), findsNothing,
          reason: '🔴 un contrôleur partagé par TOUTE la pile dévoilerait la '
              'carte suivante en même temps que celle de devant');
    });

    testWidgets('🔴 INERTIE — aucune action de révélation en mode `spaced`',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(writtenCards(3), reviewer, mode: ZReviewMode.spaced),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ZStudySessionHost.revealActionKey), findsNothing,
          reason: '🔴 le défaut des modes notés est STRICTEMENT inchangé');
      expect(find.text(kRevealFallback), findsNothing);
    });

    testWidgets(
        '🔴 aucune action de révélation quand l\'hôte fournit son `cardBuilder` '
        '(jamais une commande morte)', (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          cardBuilder: (BuildContext context, ZFlashcard card) =>
              const SizedBox.shrink(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ZStudySessionHost.revealActionKey), findsNothing,
          reason: '🔴 la carte de l\'hôte ne se branche pas sur la révélation '
              'de l\'assemblage : le bouton ne dévoilerait rien');
    });

    testWidgets('`never` retire l\'action même en mode apprentissage',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          revealPolicy: ZStudySessionRevealPolicy.never,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZStudySessionHost.revealActionKey), findsNothing);
    });

    testWidgets('`always` offre l\'action jusque dans un mode noté',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          mode: ZReviewMode.spaced,
          revealPolicy: ZStudySessionRevealPolicy.always,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZStudySessionHost.revealActionKey), findsOneWidget);
    });

    testWidgets('AD-13 — la cible de révélation mesure ≥ 48 dp RENDUS',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(host(writtenCards(3), reviewer));
      await tester.pumpAndSettle();
      final Size size =
          tester.getSize(find.byKey(ZStudySessionHost.revealActionKey));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });

    test('table unique de révélation — `learn` seul, en régime `auto`', () {
      for (final ZReviewMode mode in ZReviewMode.values) {
        expect(
          zStudySessionRevealsAnswer(mode, ZStudySessionRevealPolicy.auto),
          mode == ZReviewMode.learn,
          reason: 'mode $mode',
        );
        expect(
          zStudySessionRevealsAnswer(mode, ZStudySessionRevealPolicy.never),
          isFalse,
        );
        expect(
          zStudySessionRevealsAnswer(mode, ZStudySessionRevealPolicy.always),
          isTrue,
        );
      }
    });
  });

  // ── ÉCART 2 ───────────────────────────────────────────────────────────────
  group('🔴 écart 2 — le rappel de question s\'abrège sur écran ÉTROIT', () {
    testWidgets('🔴 sous le seuil, le rappel est BORNÉ (régime `auto`)',
        (tester) async {
      useNarrowSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(writtenCards(3), reviewer, mode: ZReviewMode.spaced),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZFadedOverflow), findsOneWidget,
          reason: '🔴 sur un téléphone en portrait, la carte ET son rappel '
              'occupent l\'écran entier : la saisie passe sous la ligne de '
              'flottaison');
      final Size size = tester.getSize(find.byType(ZFadedOverflow));
      expect(
        size.height,
        lessThanOrEqualTo(ZStudySessionReference.compactRecallMaxHeight),
      );
    });

    testWidgets('au-dessus du seuil, le rappel reste ENTIER (régime `auto`)',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(writtenCards(3), reviewer, mode: ZReviewMode.spaced),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZFadedOverflow), findsNothing,
          reason: 'sur large écran le rappel est utile — rien ne change');
    });

    testWidgets(
        '🔴 ÉCHAPPATOIRE — `full` restaure le rendu d\'avant, même étroit',
        (tester) async {
      useNarrowSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          mode: ZReviewMode.spaced,
          recall: ZStudySessionQuestionRecall.full,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZFadedOverflow), findsNothing,
          reason: '🔴 un hôte doit pouvoir retrouver EXACTEMENT le rendu qu\'il '
              'avait avant ce régime');
    });

    testWidgets('`hidden` retire le rappel — la question ne vit que sur la carte',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          mode: ZReviewMode.spaced,
          recall: ZStudySessionQuestionRecall.hidden,
        ),
      );
      await tester.pumpAndSettle();
      // La question n'est plus rendue QUE par la carte (un seul exemplaire).
      expect(find.text('Question c0.'), findsOneWidget,
          reason: '🔴 sans le régime, la question est rendue DEUX fois');
    });

    testWidgets('sonde de non-vacuité : le rappel EXISTE bien par défaut',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(writtenCards(3), reviewer, mode: ZReviewMode.spaced),
      );
      await tester.pumpAndSettle();
      expect(find.text('Question c0.'), findsNWidgets(2),
          reason: 'carte + rappel — c\'est le doublon que l\'écart décrit');
    });

    test('table unique du rappel — le seuil est le SEUL arbitre en `auto`', () {
      const double narrow = ZStudySessionReference.narrowWidth;
      expect(
        zResolveQuestionRecall(ZStudySessionQuestionRecall.auto, narrow - 1),
        ZStudySessionQuestionRecall.compact,
      );
      expect(
        zResolveQuestionRecall(ZStudySessionQuestionRecall.auto, narrow),
        ZStudySessionQuestionRecall.full,
      );
      for (final ZStudySessionQuestionRecall explicit
          in <ZStudySessionQuestionRecall>[
        ZStudySessionQuestionRecall.full,
        ZStudySessionQuestionRecall.compact,
        ZStudySessionQuestionRecall.hidden,
      ]) {
        expect(zResolveQuestionRecall(explicit, 1), explicit,
            reason: 'une valeur explicite n\'est JAMAIS redécidée');
        expect(zResolveQuestionRecall(explicit, 9999), explicit);
      }
    });
  });

  // ── ÉCART 3 ───────────────────────────────────────────────────────────────
  group('🔴 écart 3 — l\'inset bas est réservé UNE FOIS, et gouvernable', () {
    testWidgets('🔴 une SEULE réserve d\'inset — jamais de gouttière double',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          mode: ZReviewMode.spaced,
          systemPadding: const EdgeInsets.only(bottom: 34),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ZFlashcardAnswerInput.bottomInsetKey), findsOneWidget,
          reason: '🔴 la surface de saisie réserve l\'inset système');
      final Padding pad = tester.widget<Padding>(
        find.byKey(ZFlashcardAnswerInput.bottomInsetKey),
      );
      expect(pad.padding.resolve(TextDirection.ltr).bottom, 34);
      // 🔬 NON-VACUITÉ. L'assertion « la rangée de notation ne pose pas de
      // seconde réserve » serait VERTE POUR LA MAUVAISE RAISON : mesuré,
      // `ZSrsQualityButtons` n'est pas monté tant qu'aucune réponse n'est
      // soumise (`find.byType(ZSrsQualityButtons)` ⇒ 0). Ce qu'il faut mesurer
      // est la PROPRIÉTÉ qui empêche la gouttière double, et elle est
      // observable ici : l'inset est CONSOMMÉ pour le sous-arbre, donc tout
      // descendant qui relirait `MediaQuery` en lirait zéro.
      final BuildContext inner = tester.element(
        find
            .descendant(
              of: find.byKey(ZFlashcardAnswerInput.bottomInsetKey),
              matching: find.byType(TextField),
            )
            .first,
      );
      expect(
        MediaQuery.paddingOf(tester.element(find.byType(ZStudySessionHost)))
            .bottom,
        34,
        reason: '🔬 CONTRE-PREUVE : l\'inset EXISTE bien au-dessus de la '
            'surface — un zéro mesuré plus bas est donc une CONSOMMATION, pas '
            'une absence',
      );
      expect(MediaQuery.paddingOf(inner).bottom, 0,
          reason: '🔴 la surface CONSOMME l\'inset pour son sous-arbre : sans '
              'cela, une rangée imbriquée qui relit le même `MediaQuery` '
              'réserverait une SECONDE fois — gouttière double');
    });

    testWidgets('🔴 `bottomInset: 0` — l\'hôte gouverne, aucune réserve rendue',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          mode: ZReviewMode.spaced,
          bottomInset: 0,
          systemPadding: const EdgeInsets.only(bottom: 34),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZFlashcardAnswerInput.bottomInsetKey), findsNothing,
          reason: '🔴 l\'hôte qui pose 0 a décidé : rien n\'est réservé');
    });

    testWidgets('🔴 une valeur explicite prime sur l\'inset système',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(
          writtenCards(3),
          reviewer,
          mode: ZReviewMode.spaced,
          bottomInset: 72,
          systemPadding: const EdgeInsets.only(bottom: 34),
        ),
      );
      await tester.pumpAndSettle();
      final Padding pad = tester.widget<Padding>(
        find.byKey(ZFlashcardAnswerInput.bottomInsetKey),
      );
      expect(pad.padding.resolve(TextDirection.ltr).bottom, 72);
    });

    testWidgets('🔴 INERTIE — sans inset système, AUCUN nœud de réserve',
        (tester) async {
      useTallSurface(tester);
      final reviewer = FakeSessionReviewer();
      await tester.pumpWidget(
        host(writtenCards(3), reviewer, mode: ZReviewMode.spaced),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(ZFlashcardAnswerInput.bottomInsetKey), findsNothing,
          reason: '🔴 l\'arbre d\'un hôte qui ne demande rien est INCHANGÉ');
    });
  });
}
