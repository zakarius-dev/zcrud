/// G4 VIS-3 : oracle pixel du rendu zéro-configuration.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

void main() {
  testWidgets('G4 — sans injection VIS, la carte reste pixel-identique', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Material(
          child: Center(
            child: RepaintBoundary(
              key: const ValueKey<String>('vis-3-default-golden'),
              child: SizedBox(
                width: 320,
                child: ZFlashcardReviewCard(
                  card: ZFlashcard(question: 'Question', answer: 'Réponse'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await expectLater(
      find.byKey(const ValueKey<String>('vis-3-default-golden')),
      matchesGoldenFile('goldens/z_flashcard_review_card_default.png'),
    );
  });
}
