/// 🔴 CONCURRENCE — gardes issues du code-review su-3.
///
/// La logique **pure** de su-3 était solide et les cas dégradés de la carte tous
/// traités ; la faille était **ailleurs** : le widget n'avait **ni
/// `didUpdateWidget`, ni verrou de ré-entrance** (deux absences prouvées par grep
/// négatif, RC=1). La story n'arbitrait la concurrence **nulle part** — ce
/// n'étaient donc pas des écarts assumés, mais des **trous**.
///
/// Ces tests exercent la **fenêtre `await`** : le seul endroit où une carte peut
/// changer et où un second tap peut passer. Un port qui répond immédiatement la
/// referme et rend les défauts **invisibles** — d'où [SlowEvaluationPort] /
/// [SlowHintPort], dont le test contrôle l'instant de réponse.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

/// Carte rédigée **distincte** de `writtenCard()` (question, réponse ET indice
/// stocké différents) — sert de « carte B » aux tests de fuite inter-cartes.
ZFlashcard writtenCardB({String? hint}) => ZFlashcard(
  question: 'Qu\'est-ce que le régime suspensif ?',
  type: ZFlashcardType.openQuestion,
  answer: 'réponse B',
  hint: hint,
);

void main() {
  group('🔴 MAJEUR — carte changée pendant un appel de port EN VOL', () {
    // 🔴 LE SCÉNARIO LE PLUS DANGEREUX DE LA STORY : le `then` d'un appel en vol
    // écrivait sur la **NOUVELLE** carte. `mounted` NE SUFFIT PAS — quand la
    // carte change, seul le **widget** est remplacé : l'`Element` et le `State`
    // **survivent**, `mounted` reste `true`.
    //
    // En su-4, `onSubmitted` sera branché sur `ZSessionReviewer.reviewCard` :
    // c'est une **note SRS FAUSSE écrite sur la mauvaise carte**, par la voie
    // légitime — AD-33 n'attrape rien, la garde de pureté non plus.

    /// Monte la surface **à la même position, avec la MÊME `key`** ⇒ `State`
    /// conservé : c'est exactement le cas par défaut d'un hôte qui ne donne pas
    /// de `key: ValueKey(card.id)` (et rien ne l'y oblige).
    Future<void> pumpCard(
      WidgetTester tester,
      ZFlashcard card, {
      ZFlashcardAnswerEvaluationPort? port,
      ZFlashcardHintPort? hintPort,
      void Function(ZFlashcardSubmission)? onSubmitted,
    }) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            key: const ValueKey<String>('surface-recyclee'),
            card: card,
            mode: ZReviewMode.learn,
            evaluationPort: port,
            hintPort: hintPort,
            onSubmitted: onSubmitted,
          ),
        ),
      );
    }

    testWidgets('🔴 le résultat de la carte A ne touche JAMAIS la carte B '
        '(feedback + note)', (tester) async {
      final port = SlowEvaluationPort();
      final subs = <ZFlashcardSubmission>[];
      await pumpCard(tester, writtenCard(), port: port, onSubmitted: subs.add);

      await tester.enterText(find.byKey(K.answerField), 'réponse carte A');
      await tester.tap(find.byKey(K.submit));
      await tester.pump();
      expect(port.callCount, 1, reason: 'l\'appel de A est EN VOL');

      // La session avance sur la carte B pendant que le port réfléchit.
      await pumpCard(tester, writtenCardB(), port: port, onSubmitted: subs.add);

      // …et le port de A répond MAINTENANT.
      port.release(0, feedback: 'feedback de la carte A');
      await tester.pumpAndSettle();

      expect(
        subs,
        isEmpty,
        reason:
            '🔴 le DÉFAUT EXACT : la soumission de A partait au callback '
            'de B ⇒ en su-4, une note SRS FAUSSE sur la mauvaise carte',
      );
      expect(
        find.text('feedback de la carte A'),
        findsNothing,
        reason: '🔴 le feedback de A s\'affichait sur la carte B',
      );
      expect(find.byType(ZSrsQualityButtons), findsNothing);
    });

    testWidgets('🔴 l\'état de réponse de A ne FUIT pas sur B', (tester) async {
      await pumpCard(tester, writtenCard());
      await tester.enterText(find.byKey(K.answerField), 'réponse carte A');
      await tester.pump();

      await pumpCard(tester, writtenCardB());
      await tester.pump();

      expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .controller
            .text,
        isEmpty,
        reason: '🔴 « réponse carte A » restait PRÉ-REMPLIE sur la carte B',
      );
    });

    testWidgets(
      '🔴 AD-36 : l\'indice STOCKÉ de B est servi, et le port N\'EST PAS '
      'appelé (l\'indice de A rendait `_hasUnservedStoredHint` faux À JAMAIS)',
      (tester) async {
        final hintPort = SpyHintPort();
        await pumpCard(
          tester,
          writtenCard(hint: 'indice A'),
          hintPort: hintPort,
        );

        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
        expect(find.text('indice A'), findsOneWidget);
        expect(hintPort.callCount, 0, reason: 'le STOCKÉ d\'abord (AD-36)');

        // Carte B, qui porte AUSSI un indice stocké.
        await pumpCard(
          tester,
          writtenCardB(hint: 'indice B'),
          hintPort: hintPort,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('indice A'),
          findsNothing,
          reason:
              '🔴 l\'indice de A restait affiché sur B ET comptait comme '
              'hintsUsed=1 ⇒ B était PLAFONNÉE à tort',
        );

        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();

        expect(
          find.text('indice B'),
          findsOneWidget,
          reason: '🔴 l\'indice stocké de B n\'était JAMAIS servi',
        );
        expect(
          hintPort.callCount,
          0,
          reason:
              '🔴 le port ÉTAIT appelé — précisément l\'« appel IA '
              'superflu » qu\'AD-36 existe pour empêcher ; et `shownHints` '
              'transportait le contenu de la carte A dans le prompt de B',
        );
      },
    );

    testWidgets('🔴 un indice EN VOL sur A n\'atterrit pas sur B', (
      tester,
    ) async {
      final hintPort = SlowHintPort();
      await pumpCard(tester, writtenCard(), hintPort: hintPort);
      await tester.tap(find.byKey(K.hintButton));
      await tester.pump();
      expect(hintPort.callCount, 1);

      await pumpCard(tester, writtenCardB(), hintPort: hintPort);
      hintPort.release(0, 'indice DE LA CARTE A');
      await tester.pumpAndSettle();

      expect(
        find.text('indice DE LA CARTE A'),
        findsNothing,
        reason: 'fuite de contenu inter-carte + hintsUsed faussé sur B',
      );
    });
  });

  group('🔴 MAJEUR — soumission RÉ-ENTRANTE (les TROIS chemins)', () {
    // 🔴 L'intention one-shot était explicite et implémentée sur le chemin QCM
    // (`if (corrected == null) _SubmitButton(...)`) et V/F (`onPressed: corrected
    // != null ? null : …`) — mais **2 chemins sur 3** l'oubliaient. Ce n'était
    // donc pas un arbitrage : un oubli, contredit par ses propres frères.

    testWidgets(
      '🔴 (1/3) rédigée : double-tap « Valider » ⇒ UN SEUL appel de port, '
      'UNE SEULE émission',
      (tester) async {
        final port = SlowEvaluationPort();
        final subs = <ZFlashcardSubmission>[];
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              evaluationPort: port,
              onSubmitted: subs.add,
            ),
          ),
        );
        await tester.enterText(find.byKey(K.answerField), 'ma réponse');

        // Le port est lent et le bouton n'a AUCUN indicateur de charge :
        // l'utilisateur, sans le moindre retour visuel, retape.
        await tester.tap(find.byKey(K.submit));
        await tester.pump();
        await tester.tap(find.byKey(K.submit));
        await tester.pump();

        expect(
          port.callCount,
          1,
          reason:
              '🔴 le DÉFAUT EXACT : callCount=2 ⇒ DEUX appels IA FACTURÉS '
              'pour une seule réponse',
        );

        port.release(0);
        await tester.pumpAndSettle();
        expect(
          subs,
          hasLength(1),
          reason:
              '🔴 deux `onSubmitted` étaient émis : l\'hôte de su-4 recevait '
              'deux soumissions contradictoires sans savoir laquelle fait foi',
        );
      },
    );

    testWidgets('🔴 (2/3) V/F auto-soumis : double-tap ⇒ UNE SEULE émission', (
      tester,
    ) async {
      final subs = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            onSubmitted: subs.add,
          ),
        ),
      );
      // Le tap VAUT la soumission (FR-SU2) : rien n'empêchait deux taps.
      await tester.tap(find.byKey(K.answerTrue), warnIfMissed: false);
      await tester.tap(find.byKey(K.answerTrue), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(subs, hasLength(1));
    });

    testWidgets(
      '🔴 (3/3) « Je ne sais pas » APRÈS une bonne réponse ne peut plus '
      'écraser la note (mesuré : `[5, 0]`)',
      (tester) async {
        final subs = <ZFlashcardSubmission>[];
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              onSubmitted: subs.add,
              onQualitySelected: (_) {},
            ),
          ),
        );
        await tester.tap(find.byKey(K.choice(1))); // Lomé — JUSTE
        await tester.pump();
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        expect(subs.map((s) => s.quality), <int>[5]);
        expect(
          find.byKey(K.dontKnow),
          findsNothing,
          reason:
              '🔴 le bouton restait LÀ et ACTIF : un tap (curiosité, tap '
              'parasite — cible ≥ 48 dp, juste sous la correction) ré-émettait '
              'la BORNE BASSE sur une réponse EXACTE, fabriquant un lapse. '
              'Aucun AC ne prévoit qu\'il reste offert après la révélation',
        );
        expect(subs, hasLength(1));
      },
    );

    testWidgets(
      '🔒 le bouton « Valider » et « Je ne sais pas » DISPARAISSENT après '
      'correction (patron des 3 frères)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(card: writtenCard(), mode: ZReviewMode.learn),
          ),
        );
        expect(find.byKey(K.submit), findsOneWidget);
        expect(find.byKey(K.dontKnow), findsOneWidget);

        await tester.enterText(find.byKey(K.answerField), 'ma réponse');
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        expect(find.byKey(K.submit), findsNothing);
        expect(find.byKey(K.dontKnow), findsNothing);
      },
    );

    testWidgets(
      '🔵 le bouton « Indice » disparaît lui aussi après correction (un '
      'indice n\'a plus d\'effet sur une note déjà émise)',
      (tester) async {
        final hintPort = SpyHintPort();
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              hintPort: hintPort,
            ),
          ),
        );
        expect(find.byKey(K.hintButton), findsOneWidget);

        await tester.enterText(find.byKey(K.answerField), 'ma réponse');
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();

        expect(
          find.byKey(K.hintButton),
          findsNothing,
          reason: 'sinon : appel IA FACTURÉ pour une carte déjà corrigée',
        );
      },
    );
  });

  group('🔴 MEDIUM — demande d\'indice RÉ-ENTRANTE', () {
    testWidgets(
      '🔴 double-tap « Indice » ⇒ UN SEUL appel : aucun indice PAYÉ PUIS JETÉ',
      (tester) async {
        final hintPort = SlowHintPort();
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              hintPort: hintPort,
            ),
          ),
        );

        await tester.tap(find.byKey(K.hintButton));
        await tester.pump();
        await tester.tap(find.byKey(K.hintButton));
        await tester.pump();

        expect(
          hintPort.callCount,
          1,
          reason:
              '🔴 le DÉFAUT EXACT : deux requêtes concurrentes capturaient '
              'le MÊME `shownHints` ⇒ la seconde réponse ÉCRASAIT la première '
              '⇒ 2 appels IA facturés, 1 seul indice affiché, `hintsUsed == 1` '
              '⇒ le plafond d\'AD-36 FAUSSÉ, et l\'anti-répétition AVEUGLE',
        );

        hintPort.release(0, 'le seul indice');
        await tester.pumpAndSettle();
        expect(find.text('le seul indice'), findsOneWidget);
      },
    );

    testWidgets(
      '🔒 un indice NON OBTENU peut être REDEMANDÉ (le verrou est libéré sur '
      'échec — le compteur, lui, reste inchangé)',
      (tester) async {
        final hintPort = FailingHintPort();
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              hintPort: hintPort,
            ),
          ),
        );

        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
        expect(hintPort.callCount, 1);

        await tester.tap(find.byKey(K.hintButton));
        await tester.pumpAndSettle();
        expect(
          hintPort.callCount,
          2,
          reason:
              'un verrou jamais libéré condamnerait l\'apprenant à ne plus '
              'jamais pouvoir demander d\'indice après une panne réseau',
        );
      },
    );

    testWidgets('🔒 le cumul est lu au DERNIER moment (jamais depuis la copie '
        'pré-`await`)', (tester) async {
      // Carte à indice STOCKÉ + port : le stocké est servi d'abord, puis le port.
      final hintPort = SpyHintPort();
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: writtenCard(hint: 'indice stocké'),
            mode: ZReviewMode.learn,
            hintPort: hintPort,
          ),
        ),
      );

      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.hintButton));
      await tester.pumpAndSettle();

      // Les DEUX indices sont affichés : le cumul n'a rien écrasé.
      expect(find.text('indice stocké'), findsOneWidget);
      expect(find.text('indice généré 1'), findsOneWidget);
      // Anti-répétition : le port a bien reçu l'indice déjà montré (AD-36).
      expect(hintPort.request!.shownHints, <String>['indice stocké']);
    });
  });
}
