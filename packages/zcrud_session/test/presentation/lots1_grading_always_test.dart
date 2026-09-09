/// 🔴 Le POINT DE CONTRAT de `ZAnswerGradingVisibility.always` : la rangée de
/// paliers est montée et ACTIVE avant la réponse, et un palier tapé là vaut
/// **notation manuelle** — par la voie de notation habituelle, et une seule
/// fois.
///
/// Ce que la garde compte : le NOMBRE DE NOTATIONS émises. Une garde qui se
/// contenterait de vérifier « la rangée est montée » resterait verte devant
/// une surface qui écrirait DEUX fois — c'est-à-dire devant exactement le
/// défaut que ce régime pourrait introduire (invariants AD-9/AD-33 : une voie
/// d'écriture unique).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

void main() {
  group('🔴 une seule écriture, jamais deux', () {
    testWidgets('un palier tapé AVANT la réponse ⇒ exactement 1 notation ; la '
        'soumission est ensuite VERROUILLÉE et le compte reste à 1', (
      tester,
    ) async {
      final List<int> notations = <int>[];
      final List<ZFlashcardSubmission> soumissions = <ZFlashcardSubmission>[];
      await tester.pumpWidget(
        host(
          ZFlashcardAnswerInput(
            card: qcmSingle(),
            mode: ZReviewMode.learn,
            gradingVisibility: ZAnswerGradingVisibility.always,
            onQualitySelected: notations.add,
            onSubmitted: soumissions.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // La rangée est montée AVANT toute réponse, et aucun palier n'est
      // marqué : rien n'a encore été noté.
      expect(find.byType(ZSrsQualityButtons), findsOneWidget);
      expect(find.byKey(K.submit), findsOneWidget);

      await tester.tap(find.byKey(K.quality(5)));
      await tester.pumpAndSettle();
      expect(notations, <int>[
        5,
      ], reason: '🔴 le palier tapé avant la réponse n\'a pas noté');

      // Le verrou : plus aucune soumission possible.
      expect(
        find.byKey(K.submit),
        findsNothing,
        reason:
            '🔴 la soumission reste offerte après une notation manuelle : '
            'une SECONDE écriture est atteignable',
      );
      expect(find.byKey(K.dontKnow), findsNothing);
      // …et la saisie est inerte : re-cocher un choix ne réarme rien.
      await tester.tap(find.byKey(K.choice(1)));
      await tester.pumpAndSettle();
      expect(find.byKey(K.submit), findsNothing);
      expect(notations, <int>[5], reason: '🔴 une SECONDE notation est partie');
      expect(
        soumissions,
        isEmpty,
        reason:
            '🔴 une soumission a été émise alors que la carte avait été '
            'notée à la main',
      );

      // Un second tap sur un autre palier n\'écrit rien non plus.
      await tester.tap(find.byKey(K.quality(0)));
      await tester.pumpAndSettle();
      expect(notations, <int>[
        5,
      ], reason: '🔴 un second palier tapé a émis une DEUXIÈME notation');
    });

    testWidgets(
      'réponse PUIS palier ⇒ exactement 1 notation (l\'ordre habituel est '
      'intact sous `always`)',
      (tester) async {
        final List<int> notations = <int>[];
        final List<ZFlashcardSubmission> soumissions = <ZFlashcardSubmission>[];
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              gradingVisibility: ZAnswerGradingVisibility.always,
              onQualitySelected: notations.add,
              onSubmitted: soumissions.add,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(K.choice(1)));
        await tester.pump();
        await tester.tap(find.byKey(K.submit));
        await tester.pumpAndSettle();
        expect(soumissions, hasLength(1));
        expect(
          notations,
          isEmpty,
          reason: '🔴 la soumission a noté d\'elle-même',
        );

        await tester.tap(find.byKey(K.quality(4)));
        await tester.pumpAndSettle();
        expect(notations, <int>[4]);
        expect(soumissions, hasLength(1));
      },
    );

    testWidgets(
      'la notation manuelle passe par `onQualitySelected` — AUCUNE autre voie',
      (tester) async {
        final List<ZFlashcardSubmission> soumissions = <ZFlashcardSubmission>[];
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: writtenCard(),
              mode: ZReviewMode.learn,
              gradingVisibility: ZAnswerGradingVisibility.always,
              onQualitySelected: (_) {},
              onSubmitted: soumissions.add,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(K.quality(3)));
        await tester.pumpAndSettle();
        expect(
          soumissions,
          isEmpty,
          reason:
              '🔴 une soumission FABRIQUÉE part au barème : la surface '
              'inventerait une réponse que l\'apprenant n\'a pas donnée',
        );
      },
    );

    testWidgets('une carte suivante RÉARME la surface', (tester) async {
      final List<int> notations = <int>[];
      Widget monte(ZFlashcard card) => host(
        ZFlashcardAnswerInput(
          card: card,
          mode: ZReviewMode.learn,
          gradingVisibility: ZAnswerGradingVisibility.always,
          onQualitySelected: notations.add,
        ),
      );
      await tester.pumpWidget(monte(qcmSingle()));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(K.quality(5)));
      await tester.pumpAndSettle();
      expect(find.byKey(K.submit), findsNothing);

      await tester.pumpWidget(monte(qcmMulti()));
      await tester.pumpAndSettle();
      expect(
        find.byKey(K.submit),
        findsOneWidget,
        reason: '🔴 la carte suivante hérite du verrou de la précédente',
      );
      await tester.tap(find.byKey(K.quality(0)));
      await tester.pumpAndSettle();
      expect(notations, <int>[5, 0]);
    });
  });

  group('quand la rangée n\'est PAS montée avant la réponse', () {
    testWidgets(
      'régime de RÉFÉRENCE : rien avant la soumission (ordre inchangé)',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              onQualitySelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZSrsQualityButtons), findsNothing);
      },
    );

    testWidgets(
      '`always` SANS voie de notation : aucune rangée — une rangée qui '
      'n\'écrit nulle part serait un mensonge',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              gradingVisibility: ZAnswerGradingVisibility.always,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZSrsQualityButtons), findsNothing);
        expect(find.byKey(K.submit), findsOneWidget);
      },
    );

    testWidgets(
      '`always` en correction REPORTÉE : rien n\'est peint — la révélation '
      'appartient à l\'hôte',
      (tester) async {
        await tester.pumpWidget(
          host(
            ZFlashcardAnswerInput(
              card: qcmSingle(),
              mode: ZReviewMode.learn,
              gradingVisibility: ZAnswerGradingVisibility.always,
              correctionVisibility: ZCorrectionVisibility.deferred,
              onQualitySelected: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ZSrsQualityButtons), findsNothing);
      },
    );
  });

  group('le jeton de thème pose le même régime', () {
    testWidgets('`answerInputGradingVisibility` seul suffit', (tester) async {
      final List<int> notations = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              ZcrudTheme(
                answerInputGradingVisibility: ZAnswerGradingVisibility.always,
              ),
            ],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZFlashcardAnswerInput(
                card: qcmSingle(),
                mode: ZReviewMode.learn,
                onQualitySelected: notations.add,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ZSrsQualityButtons), findsOneWidget);
      await tester.tap(find.byKey(K.quality(5)));
      await tester.pumpAndSettle();
      expect(notations, <int>[5]);
    });

    testWidgets('🔴 le PARAMÈTRE prime sur le jeton', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const <ThemeExtension<dynamic>>[
              ZcrudTheme(
                answerInputGradingVisibility: ZAnswerGradingVisibility.always,
              ),
            ],
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ZFlashcardAnswerInput(
                card: qcmSingle(),
                mode: ZReviewMode.learn,
                gradingVisibility: ZAnswerGradingVisibility.afterSubmit,
                onQualitySelected: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZSrsQualityButtons), findsNothing);
    });
  });
}
