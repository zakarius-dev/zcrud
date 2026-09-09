/// L'aperçu d'intervalle peut dépendre de la CARTE de devant.
///
/// Mesure sur l'EFFET RENDU (le texte réellement peint sous le cran), jamais
/// sur le passage du paramètre : lire `ZSrsQualityButtons.previewLabelFor`
/// resterait vert si le relais existait sans rien produire, et rendrait la
/// garde aveugle à l'ordre de priorité entre les deux seams.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_answer_input_harness.dart';

ZFlashcard _card(String id) => ZFlashcard(
  id: id,
  question: 'Question $id',
  type: ZFlashcardType.openQuestion,
  answer: 'réponse attendue',
);

Finder _crank(int q) =>
    find.byKey(ValueKey<String>('${ZSrsQualityButtons.buttonKeyPrefix}$q'));

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// Mène la surface jusqu'à la correction : c'est la seule façon d'obtenir la
/// rangée de notation dans l'assemblage de production.
Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(find.byKey(K.answerField), 'ma réponse');
  await tester.pump();
  await tester.tap(find.byKey(K.submit));
  await tester.pumpAndSettle();
  expect(
    find.byType(ZSrsQualityButtons),
    findsOneWidget,
    reason: 'la rangée doit être montée pour que la garde mesure',
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ZFlashcard card,
  String Function(int quality)? qualityPreviewLabelFor,
  String Function(ZFlashcard card, int quality)? qualityPreviewLabelForCard,
}) async {
  await tester.pumpWidget(
    _host(
      ZFlashcardAnswerInput(
        card: card,
        mode: ZReviewMode.learn,
        evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
        onQualitySelected: (_) {},
        qualityPreviewLabelFor: qualityPreviewLabelFor,
        qualityPreviewLabelForCard: qualityPreviewLabelForCard,
      ),
    ),
  );
  await _submit(tester);
}

void main() {
  group('Le seam AVEC carte reçoit la carte de devant', () {
    testWidgets('l\'aperçu rendu VARIE avec la carte, à seam identique', (
      tester,
    ) async {
      // Un seul et même seam pour les deux montages : si l'aperçu rendu
      // diffère, c'est que la carte lui est bien parvenue. C'est le
      // discriminant : avec l'ancien seam, ces deux montages rendaient
      // forcément le même texte.
      String seam(ZFlashcard card, int q) => '${card.id}/J+$q';

      await _pump(
        tester,
        card: _card('alpha'),
        qualityPreviewLabelForCard: seam,
      );
      expect(
        find.descendant(of: _crank(3), matching: find.text('alpha/J+3')),
        findsOneWidget,
        reason: '🔴 la carte n\'est pas parvenue au seam d\'aperçu',
      );
      expect(find.text('beta/J+3'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        card: _card('beta'),
        qualityPreviewLabelForCard: seam,
      );
      expect(
        find.descendant(of: _crank(3), matching: find.text('beta/J+3')),
        findsOneWidget,
        reason: '🔴 l\'aperçu ne suit pas la carte affichée',
      );
      expect(find.text('alpha/J+3'), findsNothing);
    });

    testWidgets('chaque cran reçoit SA qualité', (tester) async {
      await _pump(
        tester,
        card: _card('alpha'),
        qualityPreviewLabelForCard: (card, q) => '${card.id}#$q',
      );
      for (var q = 0; q <= 5; q++) {
        expect(
          find.descendant(of: _crank(q), matching: find.text('alpha#$q')),
          findsOneWidget,
          reason: 'le cran $q doit rendre l\'aperçu de sa propre qualité',
        );
      }
    });

    testWidgets(
      'après un CHANGEMENT de carte sous le même State, l\'aperçu porte sur '
      'la nouvelle',
      (tester) async {
        String seam(ZFlashcard card, int q) => '${card.id}/J+$q';
        final port = SpyEvaluationPort(suggestedQuality: 4);

        Widget surface(ZFlashcard card) => _host(
          ZFlashcardAnswerInput(
            card: card,
            mode: ZReviewMode.learn,
            evaluationPort: port,
            onQualitySelected: (_) {},
            qualityPreviewLabelForCard: seam,
          ),
        );

        await tester.pumpWidget(surface(_card('alpha')));
        await _submit(tester);
        expect(find.text('alpha/J+3'), findsOneWidget);

        // Même position dans l'arbre ⇒ même `Element`, même `State` : c'est
        // exactement le cas où un aperçu figé sur la carte précédente
        // survivrait.
        await tester.pumpWidget(surface(_card('beta')));
        await tester.pumpAndSettle();
        await _submit(tester);

        expect(
          find.text('beta/J+3'),
          findsOneWidget,
          reason:
              '🔴 l\'aperçu est resté sur la carte PRÉCÉDENTE — un intervalle '
              'qui n\'appartient à personne',
        );
        expect(find.text('alpha/J+3'), findsNothing);
      },
    );
  });

  group('Ordre de priorité entre les deux seams', () {
    testWidgets('le seam AVEC carte l\'emporte quand les deux sont fournis', (
      tester,
    ) async {
      await _pump(
        tester,
        card: _card('alpha'),
        qualityPreviewLabelFor: (q) => 'SANS_CARTE_$q',
        qualityPreviewLabelForCard: (card, q) => 'AVEC_${card.id}_$q',
      );

      expect(
        find.descendant(of: _crank(2), matching: find.text('AVEC_alpha_2')),
        findsOneWidget,
        reason: '🔴 le seam avec carte devrait primer',
      );
      expect(
        find.text('SANS_CARTE_2'),
        findsNothing,
        reason:
            '🔴 les deux aperçus sont rendus : la rangée aurait deux '
            'propriétaires pour la même décision',
      );
    });

    testWidgets('le seam SANS carte reste servi quand il est seul', (
      tester,
    ) async {
      await _pump(
        tester,
        card: _card('alpha'),
        qualityPreviewLabelFor: (q) => 'SANS_CARTE_$q',
      );
      expect(
        find.descendant(of: _crank(2), matching: find.text('SANS_CARTE_2')),
        findsOneWidget,
        reason: '🔴 le nouveau seam a évincé l\'ancien : rupture de contrat',
      );
    });

    testWidgets('aucun des deux ⇒ AUCUN aperçu (inertie)', (tester) async {
      await tester.pumpWidget(
        _host(
          ZFlashcardAnswerInput(
            card: _card('alpha'),
            mode: ZReviewMode.learn,
            evaluationPort: SpyEvaluationPort(suggestedQuality: 4),
            onQualitySelected: (_) {},
          ),
        ),
      );
      await _submit(tester);

      // Un cran sans aperçu ne rend QUE son libellé : un second `Text` frère
      // signalerait un aperçu fabriqué par la surface.
      expect(
        find.descendant(of: _crank(0), matching: find.byType(Text)),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ZSrsQualityButtons>(find.byType(ZSrsQualityButtons))
            .previewLabelFor,
        isNull,
        reason: 'aucune closure ne doit être fabriquée sans seam',
      );
    });
  });
}
