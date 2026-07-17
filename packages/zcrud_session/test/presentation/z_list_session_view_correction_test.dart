/// SU-7 / AC2 — 🔴 La correction n'apparaît **QU'À la soumission finale**.
///
/// # Le sous-piège que ce fichier existe pour attraper
///
/// Dans su-3, `corrected != null` gate **DEUX choses au même endroit** :
/// l'**affichage** de la correction **ET** le **verrou d'interaction**
/// (`onTap: corrected != null ? null : …`). « Différer » naïvement — en laissant
/// `_correction.value` à `null` — **rouvrirait la double soumission** : les choix
/// redeviendraient tapables, le QCM auto-soumis pourrait ré-émettre. C'est le
/// **défaut majeur D2** que su-3 avait fermé.
///
/// Le gate de su-7 porte donc sur le **RENDU SEUL** : `_correction` **reste
/// posé**. **Le test (2) est celui qui le prouve** — sans lui, une régression
/// silencieuse et grave passerait toute la suite au vert.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';
import 'z_exam_harness.dart';

void main() {
  void useLargeSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('🔴 AC2 — dans l\'examen (deferred), répondre ne révèle RIEN', () {
    testWidgets('(1) après réponse : aucun verdict, aucune icône de vérité',
        (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(cards: <ZFlashcard>[examCard('Q1'), examCard('Q2')]),
      );
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

      // ⚠️ Ces `find.text` sont un filet, PAS la garde : sur une carte V/F, su-3
      // ne peint aucun `Text('correct')` (le verdict est icône + Semantics) ⇒
      // ils seraient verts PAR VACUITÉ. Les assertions qui MORDENT sont
      // l'icône et la sémantique, ci-dessous.
      expect(find.text('correct'), findsNothing);
      expect(find.text('incorrect'), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);
      // 🔴 Canal SÉMANTIQUE — su-6 : un nombre annoncé au lecteur d'écran mais
      // affiché nulle part laissait le test VERT. Ici, le miroir : une
      // correction annoncée mais non peinte doit rougir.
      expect(
        tester
            .getSemantics(
              find.descendant(
                of: find.ancestor(
                  of: find.text('Q1'),
                  matching: find.byType(ZFlashcardAnswerInput),
                ),
                matching: find.byKey(EK.answerTrue),
              ),
            )
            .value,
        isEmpty,
        reason: '🔴 la correction est annoncée au lecteur d\'écran pendant '
            'l\'examen : le report ne gate que le canal VISUEL.',
      );

      // Contre-preuve : la réponse a bien été ENREGISTRÉE — sinon « aucune
      // correction » serait vrai par vacuité (rien ne s'est passé).
      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(host.engine.answered, 1, reason: 'la réponse doit être comptée');
    });

    testWidgets(
      '🔴 (2) LE VERROU SURVIT AU REPORT : re-taper l\'autre choix n\'émet PAS '
      'une 2ᵉ soumission (le report ne rouvre PAS la double soumission)',
      (tester) async {
        useLargeSurface(tester);
        var submissions = 0;
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.whiteExam,
              correctionVisibility: ZCorrectionVisibility.deferred,
              onSubmitted: (_) => submissions++,
            ),
          ),
        );

        await tester.tap(find.byKey(K.answerTrue));
        await tester.pumpAndSettle();
        expect(submissions, 1);

        // 🔴 On **TAPE RÉELLEMENT** l'autre bouton (présence ≠ association) :
        // constater qu'il « a l'air » désactivé ne prouverait rien.
        await tester.tap(find.byKey(K.answerFalse), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(
          submissions,
          1,
          reason: '🔴 le report de correction a ROUVERT la double soumission : '
              '`_correction` a dû être laissé à `null` au lieu d\'être posé puis '
              'simplement non peint. C\'est le défaut MAJEUR D2 de su-3, '
              'rejoué.',
        );
      },
    );

    testWidgets('🔴 (2bis) même garde sur le QCM (un défaut est un MOTIF : on '
        'balaye les DEUX chemins auto-soumis)', (tester) async {
      useLargeSurface(tester);
      var submissions = 0;
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.whiteExam,
            correctionVisibility: ZCorrectionVisibility.deferred,
            onSubmitted: (_) => submissions++,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();
      expect(submissions, 1);

      // Re-taper un choix APRÈS soumission : le verrou `onTap` doit tenir.
      await tester.tap(find.byKey(K.choice(0)), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byKey(K.submit), findsNothing,
          reason: 'le bouton de soumission doit rester ABSENT après soumission');
      expect(submissions, 1);
    });

    testWidgets('(3) à la soumission finale, la correction de CHAQUE question '
        'devient visible', (tester) async {
      useLargeSurface(tester);
      final cards = <ZFlashcard>[examCard('Q1'), examCard('Q2')];
      await tester.pumpWidget(ExamHost(cards: cards));
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
      expect(find.text('correct'), findsNothing, reason: 'rien avant submit');

      await tester.tap(find.byKey(ZListSessionView.submitKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ZListSessionView.confirmKey));
      await tester.pumpAndSettle();

      expect(find.text('correct'), findsNWidgets(2),
          reason: '🔴 les DEUX questions doivent être corrigées, pas seulement '
              'la première (un défaut est un MOTIF)');
    });
  });

  group('🔒 AC2 (4) — NON-RÉGRESSION su-3 : `immediate` est le DÉFAUT', () {
    // 🔴 **LES DEUX CANAUX, jamais un seul** (leçon su-6 : le streak n'existait
    // que dans `Semantics(value:)`, invisible à l'œil, et son test était VERT).
    //
    // ⚠️ **Canal RÉEL du Vrai/Faux, vérifié sur la source** : le verdict d'un
    // bouton V/F n'est **PAS** un `Text('correct')` — c'est une **ICÔNE**
    // (`statusIcon`) + un **`Semantics(value:)`** (`statusValue`), via
    // `_ControlButton`. Un premier jet de ce test assertait `find.text('correct')`
    // et rougissait sur du code SAIN : il observait un canal **qui n'existe pas
    // ici**. Pire, l'assertion d'ABSENCE correspondante (test (1)) aurait été
    // vraie **PAR VACUITÉ** — verte quoi qu'il arrive. On mesure donc les canaux
    // que su-3 peint **réellement**.
    testWidgets('sans paramètre : icône ET Semantics de correction présents',
        (tester) async {
      var submissions = 0;
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.spaced,
            onSubmitted: (_) => submissions++,
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pumpAndSettle();

      expect(submissions, 1);
      expect(find.byIcon(Icons.check_circle), findsOneWidget,
          reason: '🔴 su-3 a régressé : le défaut n\'est plus `immediate` '
              '(canal VISUEL).');
      expect(tester.getSemantics(find.byKey(K.answerTrue)).value, 'correct',
          reason: '🔴 su-3 a régressé (canal SÉMANTIQUE).');
    });

    testWidgets('`immediate` explicite se comporte comme le défaut',
        (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.spaced,
            correctionVisibility: ZCorrectionVisibility.immediate,
            onSubmitted: (_) {},
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(tester.getSemantics(find.byKey(K.answerTrue)).value, 'correct');
    });

    testWidgets('🔴 …et en `deferred`, les DEUX canaux se taisent (le miroir '
        'EXACT du test ci-dessus)', (tester) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.whiteExam,
            correctionVisibility: ZCorrectionVisibility.deferred,
            onSubmitted: (_) {},
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle), findsNothing);
      // 🔴 Le canal sémantique doit se taire AUSSI : un lecteur d'écran ne doit
      // pas être MIEUX informé qu'un voyant (AD-13 exige la PARITÉ des canaux —
      // su-3 a déjà corrigé exactement cette inversion).
      expect(tester.getSemantics(find.byKey(K.answerTrue)).value, isEmpty,
          reason: '🔴 la correction est annoncée au lecteur d\'écran alors '
              'qu\'elle est invisible à l\'œil : le report ne gate qu\'UN canal.');
    });
  });

  // ══════════════════════════════════════════════════════════════════════════
  // 🔴 LES DEUX AUTRES CANAUX DE RENDU — angle mort de FIXTURE, pas de rigueur
  //
  // D2 gate **TROIS** canaux ; `examCard()` ne fabriquait que du **Vrai/Faux**,
  // si bien que tous les tests d'examen n'en tapaient qu'**UN**. Mesuré :
  //   · gate QCM (`_ChoiceRow.showCorrection`) CONTOURNÉ  ⇒ **507/507 VERTS**
  //   · gate feedback (`_CorrectionSection`) SUPPRIMÉ     ⇒ **506/506 VERTS**
  // Deux des trois canaux de la **raison d'être de la story** n'étaient gardés
  // par personne. « Un défaut est un MOTIF » — le motif a trois branches.
  // ══════════════════════════════════════════════════════════════════════════
  group('🔴 AC2 — le MOTIF entier : les TROIS canaux de rendu se taisent en '
      '`deferred` (pas seulement le Vrai/Faux)', () {
    testWidgets('(3) QCM — aucune icône de vérité n\'est peinte sur un choix '
        'après soumission', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(cards: <ZFlashcard>[examQcmCard('Q1')]),
      );
      await tester.pumpAndSettle();

      // 🔒 Contre-preuve AVANT : les choix sont bien là et tapables (sans quoi
      // « aucune icône » serait vrai PAR VACUITÉ — l'écran serait vide).
      expect(find.byKey(EK.choice(1)), findsOneWidget);

      await tester.tap(find.byKey(EK.choice(1)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(EK.submitAnswer));
      await tester.pumpAndSettle();

      // 🔒 Contre-preuve de NON-VACUITÉ : la réponse est RÉELLEMENT partie ⇒ le
      // gate est bien exercé sur une carte CORRIGÉE, pas sur une carte vierge.
      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(
        host.submissions.containsKey(0),
        isTrue,
        reason: '🔴 sans soumission, `corrected == null` et « aucune icône » '
            'serait vrai pour de MAUVAISES raisons.',
      );

      expect(
        find.byIcon(Icons.check_circle),
        findsNothing,
        reason: '🔴 l\'apprenant voit la VÉRITÉ de son QCM en plein examen — il '
            'connaît sa note question par question avant même de soumettre.',
      );
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(find.byIcon(Icons.check_circle_outline), findsNothing);
      expect(find.byIcon(Icons.cancel_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('(4) carte RÉDIGÉE — le feedback du barème n\'est PAS peint '
        'sous la question', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[examWrittenCard('Q1')],
          // 🔒 Le port rend un feedback NON-null : c'est le cas NORMAL — le
          // chemin `_submitAdvisory` affecte TOUJOURS un feedback (celui du
          // port, ou le repli l10n). Sans le gate, il serait peint.
          evaluationPort: SpyEvaluationPort(
            suggestedQuality: 4,
            feedback: 'CORRIGÉ DU BARÈME',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EK.answerField), 'ma réponse');
      await tester.tap(find.byKey(EK.submitAnswer));
      await tester.pumpAndSettle();

      // 🔒 Contre-preuve de NON-VACUITÉ : la soumission a eu lieu ET le port a
      // bien produit le feedback ⇒ il y avait RÉELLEMENT quelque chose à cacher.
      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(host.submissions[0]?.feedback, 'CORRIGÉ DU BARÈME');

      expect(
        find.byKey(EK.feedback),
        findsNothing,
        reason: '🔴 le CORRIGÉ DU BARÈME s\'affiche sous la question, en plein '
            'examen blanc — violation frontale d\'AC2, qui nomme '
            '`_CorrectionSection` explicitement.',
      );
      expect(
        find.text('CORRIGÉ DU BARÈME'),
        findsNothing,
        reason: '🔴 le canal VISIBLE fuit (leçon su-6 : ne jamais observer un '
            'seul canal).',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('(5) « Je ne sais pas » — 3ᵉ chemin auto-soumis : rien n\'est '
        'peint (le motif a TROIS branches, la garde en tenait deux)',
        (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(cards: <ZFlashcard>[examQcmCard('Q1')]),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(K.dontKnow), findsOneWidget);

      await tester.tap(find.byKey(K.dontKnow));
      await tester.pumpAndSettle();

      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      expect(
        host.submissions.containsKey(0),
        isTrue,
        reason: 'contre-preuve : « Je ne sais pas » soumet RÉELLEMENT',
      );
      expect(find.byKey(EK.feedback), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('🔴 D10 — une réponse donnée ne peut PLUS changer : le champ RÉDIGÉ se '
      'verrouille comme les 3 autres contrôles', () {
    testWidgets('après soumission, le texte NOTÉ reste affiché — l\'apprenant '
        'ne peut pas réécrire sa copie', (tester) async {
      useLargeSurface(tester);
      await tester.pumpWidget(
        ExamHost(
          cards: <ZFlashcard>[examWrittenCard('Q1')],
          evaluationPort: SpyEvaluationPort(suggestedQuality: 3),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(EK.answerField), 'ma reponse SOUMISE');
      await tester.tap(find.byKey(EK.submitAnswer));
      await tester.pumpAndSettle();

      final host = tester.state<ExamHostState>(find.byType(ExamHost));
      // 🔒 Contre-preuve : la qualité est notée SUR le texte soumis.
      expect(host.submissions[0]!.quality, 3);

      // 🔴 L'ATTAQUE : l'apprenant réécrit après coup. En `deferred`, RIEN n'est
      // peint — le seul signal de soumission est la disparition SILENCIEUSE du
      // bouton. Il peaufinait donc sa copie en croyant l'améliorer, alors que sa
      // note était déjà tombée. Et `ZFlashcardSubmission` ne porte PAS le texte :
      // le verdict de la révélation portait sur une réponse qui n'existait PLUS
      // NULLE PART — impossible à réconcilier pour l'apprenant.
      await tester.enterText(find.byKey(EK.answerField), 'JE REECRIS APRES COUP');
      await tester.pumpAndSettle();

      // 🔒 Le canal VISIBLE (ce que l'apprenant LIT), pas un état interne.
      expect(
        find.text('JE REECRIS APRES COUP'),
        findsNothing,
        reason: '🔴 le champ a accepté une réécriture APRÈS que la note soit '
            'tombée : l\'apprenant croit améliorer une copie déjà notée.',
      );
      expect(
        find.text('ma reponse SOUMISE'),
        findsOneWidget,
        reason: '🔴 le champ rédigé était le SEUL contrôle de su-3 sans verrou '
            'ONE-SHOT (`_ChoiceRow` → `onTap: null`, `_tfButton` → '
            '`onPressed: null`, `_DontKnowButton` → disparaît). D10 affirme '
            '« jamais changer une réponse donnée » : c\'était FAUX pour les 4 '
            '`ZFlashcardType` rédigés.',
      );
      // 🔒 Et la note ne bouge pas non plus (aucune 2ᵉ soumission).
      expect(host.submissions[0]!.quality, 3);
      expect(host.engine.state.answers, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });
}
