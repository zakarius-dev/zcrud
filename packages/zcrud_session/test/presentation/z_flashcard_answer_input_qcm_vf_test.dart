/// AC1 — QCM (simple/multiple DÉDUIT) et V/F évalués **LOCALEMENT** ;
/// 🔒 le port n'est **JAMAIS** appelé (AD-35).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

void main() {
  group('🔒 AC1 — le port n\'est JAMAIS appelé pour un QCM/VF (AD-35)', () {
    testWidgets('QCM soumis ⇒ spy.callCount == 0 (ABSENCE d\'appel)', (
      tester,
    ) async {
      final spy = SpyEvaluationPort();
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            evaluationPort: spy,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(1)));
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(
        spy.callCount,
        0,
        reason:
            'un QCM a été envoyé à l\'IA : AD-35 violé (R3-I1). La bonne '
            'réponse est DANS la carte — l\'appel est superflu ET faillible',
      );
    });

    testWidgets('V/F soumis ⇒ spy.callCount == 0 (ABSENCE d\'appel)', (
      tester,
    ) async {
      final spy = SpyEvaluationPort();
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            evaluationPort: spy,
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pumpAndSettle();

      expect(spy.callCount, 0);
    });
  });

  group('AC1 — mode simple/multiple DÉDUIT du nb de isCorrect', () {
    testWidgets('🔴 1 correct ⇒ EXCLUSIF : cocher B DÉSÉLECTIONNE A (R3-I1b)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(card: qcmSingle(), mode: ZReviewMode.learn)),
      );
      await tester.tap(find.byKey(K.choice(0)));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.byKey(K.choice(0)))
            .hasFlag(SemanticsFlag.isChecked),
        isTrue,
      );

      await tester.tap(find.byKey(K.choice(1)));
      await tester.pump();
      expect(
        tester
            .getSemantics(find.byKey(K.choice(0)))
            .hasFlag(SemanticsFlag.isChecked),
        isFalse,
        reason: 'A est resté coché : le QCM à 1 correct doit être EXCLUSIF',
      );
      expect(
        tester
            .getSemantics(find.byKey(K.choice(1)))
            .hasFlag(SemanticsFlag.isChecked),
        isTrue,
      );
    });

    testWidgets('🔴 2 corrects ⇒ CUMULATIF : cocher B garde A coché (R3-I1b)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(card: qcmMulti(), mode: ZReviewMode.learn)),
      );
      await tester.tap(find.byKey(K.choice(0)));
      await tester.pump();
      await tester.tap(find.byKey(K.choice(2)));
      await tester.pump();

      expect(
        tester
            .getSemantics(find.byKey(K.choice(0)))
            .hasFlag(SemanticsFlag.isChecked),
        isTrue,
        reason: 'A a été décoché : le QCM à 2 corrects doit être CUMULATIF',
      );
      expect(
        tester
            .getSemantics(find.byKey(K.choice(2)))
            .hasFlag(SemanticsFlag.isChecked),
        isTrue,
      );
    });
  });

  group('AC1 — qualité LOCALE : bornes LUES sur ZSrsConfig (AD-46)', () {
    testWidgets('sélection EXACTE ⇒ maxQuality', (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmMulti(),
            mode: ZReviewMode.learn,
            onSubmitted: submissions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(0)));
      await tester.pump();
      await tester.tap(find.byKey(K.choice(2)));
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.quality, const ZSrsConfig().maxQuality);
      expect(submissions.single.isCorrect, isTrue);
    });

    testWidgets('🔴 bonne réponse MANQUANTE ⇒ minQuality (égalité STRICTE)', (
      tester,
    ) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmMulti(),
            mode: ZReviewMode.learn,
            onSubmitted: submissions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(0))); // il en manque un
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(submissions.single.quality, const ZSrsConfig().minQuality);
      expect(submissions.single.isCorrect, isFalse);
    });

    testWidgets('🔴 minQuality: 1 ⇒ une mauvaise réponse vaut 1 (borne LUE)', (
      tester,
    ) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            srsConfig: const ZSrsConfig(minQuality: 1),
            onSubmitted: submissions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(K.choice(0))); // faux
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      expect(
        submissions.single.quality,
        1,
        reason: 'une borne écrite 0 en dur ROUGIT ici (R3-I4/D7)',
      );
    });

    // ⚠️ Deux tests SÉPARÉS, et non une boucle sur un même `tester` : un second
    // `pumpWidget` du même type de widget à la même position RÉUTILISE le
    // `State` — la correction du 1ᵉʳ tour désactiverait les boutons du 2ᵉ et le
    // test échouerait pour une raison qui n'a RIEN à voir avec la règle testée.
    testWidgets('V/F juste ⇒ maxQuality (borne LUE)', (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            onSubmitted: submissions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue)); // isTrue == true ⇒ juste
      await tester.pumpAndSettle();
      expect(submissions.single.quality, const ZSrsConfig().maxQuality);
      expect(submissions.single.isCorrect, isTrue);
    });

    testWidgets('V/F faux ⇒ minQuality (borne LUE)', (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            onSubmitted: submissions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(K.answerFalse)); // isTrue == true ⇒ faux
      await tester.pumpAndSettle();
      expect(submissions.single.quality, const ZSrsConfig().minQuality);
      expect(submissions.single.isCorrect, isFalse);
    });
  });

  testWidgets(
    '🔒 AC1 — V/F : le tap VAUT la soumission (AUTO-SOUMISSION, FR-SU2)',
    (tester) async {
      final submissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(),
            mode: ZReviewMode.learn,
            onSubmitted: submissions.add,
          ),
        ),
      );
      // AUCUN bouton « Valider » n'est offert pour un V/F : un second geste
      // contredirait FR-SU2.
      expect(find.byKey(K.submit), findsNothing);

      await tester.tap(find.byKey(K.answerTrue));
      await tester.pumpAndSettle();
      expect(
        submissions,
        hasLength(1),
        reason: 'le tap V/F doit soumettre SANS second geste',
      );
    },
  );

  group('AC1 — correction visuelle post-soumission (canal NON-coloré)', () {
    testWidgets('la correction n\'apparaît QU\'APRÈS soumission', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(card: qcmSingle(), mode: ZReviewMode.learn)),
      );
      // Avant soumission : aucune icône de correction.
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(find.byIcon(Icons.cancel), findsNothing);

      await tester.tap(find.byKey(K.choice(1)));
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      // Après : chaque choix porte une FORME (jamais la seule couleur, AD-13).
      // Coché ET correct ⇒ ✓ PLEIN ; non cochés et faux ⇒ ✗ CONTOUR (cf. le
      // test « le CHOIX DE L'UTILISATEUR reste distinguable » ci-dessous).
      expect(
        find.byIcon(Icons.check_circle),
        findsOneWidget,
      ); // le correct, coché
      expect(
        find.byIcon(Icons.cancel_outlined),
        findsNWidgets(2),
      ); // les 2 faux
    });

    testWidgets('🔴 le CHOIX DE L\'UTILISATEUR reste distinguable APRÈS correction '
        '(parité des canaux — AD-13)', (tester) async {
      // 🔴 DÉFAUT RÉEL de su-3 : après correction, l'icône ne portait plus QUE la
      // vérité ⇒ un faux COCHÉ et un faux NON COCHÉ étaient **pixel-identiques**
      // (mesuré : même `IconData`, même couleur). Le canal sémantique, lui,
      // gardait `checked: isSelected` ⇒ un utilisateur non-voyant savait ce qu'il
      // avait coché, un VOYANT ne le savait plus. AD-13 exige la PARITÉ des
      // canaux, pas leur inversion.
      //
      // La carte : [Accra, **Lomé** (correct), Cotonou]. On coche **Accra**
      // (faux). Après correction, « Accra » (mon choix) DOIT différer de
      // « Cotonou » (jamais coché) — les deux sont pourtant faux tous les deux.
      await tester.pumpWidget(
        host(ZFlashcardAnswerInput(card: qcmSingle(), mode: ZReviewMode.learn)),
      );
      await tester.tap(find.byKey(K.choice(0))); // Accra — mon choix, FAUX
      await tester.pump();
      await tester.tap(find.byKey(K.submit));
      await tester.pumpAndSettle();

      IconData iconOf(int i) => tester
          .widget<Icon>(
            find.descendant(
              of: find.byKey(K.choice(i)),
              matching: find.byType(Icon),
            ),
          )
          .icon!;

      // Deux axes de FORME, aucune couleur : ✓/✗ = la vérité ; plein/contour =
      // « je l'avais coché » / « je ne l'avais pas coché ».
      expect(iconOf(0), Icons.cancel, reason: 'mon choix, faux ⇒ ✗ PLEIN');
      expect(
        iconOf(2),
        Icons.cancel_outlined,
        reason: 'jamais coché, faux ⇒ ✗ CONTOUR',
      );
      expect(
        iconOf(0),
        isNot(iconOf(2)),
        reason:
            '🔴 le défaut EXACT : coché-faux et non-coché-faux étaient '
            'indistinguables ⇒ le voyant n\'apprenait RIEN de son erreur',
      );
      expect(
        iconOf(1),
        Icons.check_circle_outline,
        reason: 'la bonne réponse, que je n\'avais PAS cochée ⇒ ✓ CONTOUR',
      );

      // Le canal lecteur d'écran reste porté par la MÊME node (leçon D2 su-2).
      final accra = tester.getSemantics(find.byKey(K.choice(0)));
      expect(
        accra.hasFlag(SemanticsFlag.isChecked),
        isTrue,
        reason: 'le SR sait toujours ce que l\'utilisateur avait coché',
      );
    });
  });

  group('AC1 — AD-10 : cartes malformées ⇒ aucune saisie, aucun plantage', () {
    testWidgets('choices == null ⇒ repli l10n, pas de crash', (tester) async {
      await tester.pumpWidget(
        host(
          const ZFlashcardAnswerInput(
            card: ZFlashcard(
              question: 'q',
              type: ZFlashcardType.multipleChoice,
            ),
            mode: ZReviewMode.learn,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(K.choice(0)), findsNothing);
      expect(find.byKey(K.submit), findsNothing);
    });

    testWidgets(
      'QCM sans AUCUN correct ⇒ aucune saisie (jamais « réussi à vide »)',
      (tester) async {
        await tester.pumpWidget(
          host(
            const ZFlashcardAnswerInput(
              card: ZFlashcard(
                question: 'q',
                type: ZFlashcardType.multipleChoice,
                choices: <ZChoice>[
                  ZChoice(content: 'a'),
                  ZChoice(content: 'b'),
                ],
              ),
              mode: ZReviewMode.learn,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byKey(K.choice(0)), findsNothing);
      },
    );

    testWidgets('isTrue == null ⇒ aucun bouton V/F, pas de crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: trueFalseCard(isTrue: null),
            mode: ZReviewMode.learn,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(K.answerTrue), findsNothing);
      expect(find.byKey(K.answerFalse), findsNothing);
    });
  });

  group('AC1 — 🔴 Vrai/Faux : canal de correction NON-COLORÉ (AD-13)', () {
    // 🔴 DÉFAUT RÉEL de su-3 : V/F n'avait **AUCUN** canal de correction — ni
    // icône, ni `Semantics.value`, ni feedback. Les deux boutons se GRISAIENT,
    // point (mesuré : `label=Faux value=<vide> checkIcons=0 cancelIcons=0`).
    // L'apprenant qui répondait faux voyait deux boutons gris et n'apprenait
    // JAMAIS qu'il s'était trompé. AC1 nomme V/F explicitement, et le SEUL test
    // de canal non-coloré ne montait qu'un QCM : la garde n'existait pas pour la
    // moitié des types locaux.

    /// Icône portée par un bouton V/F (`null` si aucune).
    IconData? iconOf(WidgetTester tester, ValueKey<String> key) {
      final icons = find.descendant(
        of: find.byKey(key),
        matching: find.byType(Icon),
      );
      return icons.evaluate().isEmpty
          ? null
          : tester.widget<Icon>(icons.first).icon;
    }

    testWidgets(
      '🔴 réponse FAUSSE ⇒ l\'apprenant apprend qu\'il s\'est trompé',
      (tester) async {
        // `isTrue: true` ⇒ répondre « Faux » est une ERREUR.
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
            ),
          ),
        );
        expect(
          iconOf(tester, K.answerFalse),
          isNull,
          reason: 'aucun marqueur AVANT soumission',
        );

        await tester.tap(find.byKey(K.answerFalse));
        await tester.pumpAndSettle();

        // Deux axes de FORME (mêmes que le QCM) : ✓/✗ = la vérité de CE bouton ;
        // plein = « c'est ce que j'ai répondu », contour = « ce ne l'est pas ».
        expect(
          iconOf(tester, K.answerFalse),
          Icons.cancel,
          reason: 'ma réponse, fausse ⇒ ✗ PLEIN',
        );
        expect(
          iconOf(tester, K.answerTrue),
          Icons.check_circle_outline,
          reason: 'la bonne réponse, que je n\'ai pas donnée ⇒ ✓ CONTOUR',
        );
        expect(
          iconOf(tester, K.answerFalse),
          isNot(iconOf(tester, K.answerTrue)),
        );
      },
    );

    testWidgets('🔴 réponse JUSTE ⇒ ✓ PLEIN sur le bouton tapé', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(card: trueFalseCard(), mode: ZReviewMode.learn),
        ),
      );
      await tester.tap(find.byKey(K.answerTrue));
      await tester.pumpAndSettle();
      expect(iconOf(tester, K.answerTrue), Icons.check_circle);
      expect(iconOf(tester, K.answerFalse), Icons.cancel_outlined);
    });

    testWidgets(
      '🔴 le statut est ASSOCIÉ à SON bouton (Semantics.value sur la MÊME '
      'node que le libellé — leçon D2 de su-2)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: trueFalseCard(),
              mode: ZReviewMode.learn,
            ),
          ),
        );
        await tester.tap(find.byKey(K.answerFalse));
        await tester.pumpAndSettle();

        // On part de la CLÉ structurelle, jamais du libellé qu'on vérifie (D7 su-1).
        final falseNode = tester.getSemantics(find.byKey(K.answerFalse));
        final trueNode = tester.getSemantics(find.byKey(K.answerTrue));
        expect(falseNode.label, contains('Faux'));
        expect(
          falseNode.value,
          'incorrect',
          reason:
              '🔴 `value` était VIDE : le SR annonçait « Faux, bouton, '
              'désactivé » et rien de plus',
        );
        expect(trueNode.label, contains('Vrai'));
        expect(
          trueNode.value,
          'correct',
          reason:
              'le marqueur est porté par la node du bouton CONCERNÉ, '
              'jamais par celle du voisin',
        );
      },
    );
  });

  group('🔒 AD-35 — les DEUX tables de routage sont LIÉES (les 6 types)', () {
    // 🔴 DÉFAUT RÉEL de su-3 : `zIsLocallyEvaluatedType` était documentée (barrel
    // + dartdoc) comme « la voie de ROUTAGE » mais n'avait **AUCUN site d'appel**
    // (grep prod = déclaration + commentaire ; grep tests = RC=1). Le routage réel
    // était fait par le `switch` d'affordance de `_buildInput`. DEUX tables
    // décidaient la même chose, sans rien qui les lie : une 7ᵉ valeur (`cloze`)
    // déclarée LOCALE dans l'une mais tombant dans la chaîne `||` de l'autre
    // aurait envoyé à l'IA un type déclaré local — compilation VERTE, aucun test
    // rouge, port IA appelé en violation d'AD-35.
    //
    // Ce test LIE les deux tables sur les 6 types : il rougit le jour où elles
    // divergent. `ZFlashcardType.values` ⇒ **auto-énumérant** : un 7ᵉ type est
    // couvert SANS édition du test.
    for (final type in ZFlashcardType.values) {
      testWidgets('$type : spy.callCount == 0 ⟺ zIsLocallyEvaluatedType($type)', (
        tester,
      ) async {
        final spy = SpyEvaluationPort();
        // Carte exploitable POUR CHAQUE type : les types locaux doivent pouvoir
        // être réellement soumis (sinon l'absence d'appel serait triviale).
        final card = ZFlashcard(
          question: 'q',
          type: type,
          answer: 'réponse attendue',
          isTrue: true,
          choices: const <ZChoice>[
            ZChoice(content: 'a', isCorrect: true),
            ZChoice(content: 'b'),
          ],
        );
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: card,
              mode: ZReviewMode.learn,
              evaluationPort: spy,
            ),
          ),
        );

        // Soumettre par l'affordance RÉELLE du type (le chemin de l'utilisateur).
        if (find.byKey(K.answerTrue).evaluate().isNotEmpty) {
          await tester.tap(find.byKey(K.answerTrue));
        } else {
          if (find.byKey(K.choice(0)).evaluate().isNotEmpty) {
            await tester.tap(find.byKey(K.choice(0)));
            await tester.pump();
          }
          if (find.byKey(K.answerField).evaluate().isNotEmpty) {
            await tester.enterText(find.byKey(K.answerField), 'ma réponse');
          }
          await tester.tap(find.byKey(K.submit));
        }
        await tester.pumpAndSettle();

        expect(
          spy.callCount == 0,
          zIsLocallyEvaluatedType(type),
          reason:
              '🔴 les deux tables DIVERGENT sur $type : le domaine le '
              'déclare ${zIsLocallyEvaluatedType(type) ? 'LOCAL' : 'non local'} '
              'mais la surface a ${spy.callCount == 0 ? 'PAS ' : ''}appelé le '
              'port (callCount=${spy.callCount}) — AD-35',
        );
      });
    }
  });
}
