/// G5 VIS-3 : durée/courbe du thème, sans recréer l'état de la carte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

Widget _host(ZcrudTheme theme, ZRevealTransition transition) => MaterialApp(
  home: ZcrudScope(
    theme: theme,
    child: Scaffold(
      body: SizedBox(
        width: 320,
        child: ZFlashcardReviewCard(
          card: const ZFlashcard(question: 'Q', answer: 'A'),
          revealTransition: transition,
        ),
      ),
    ),
  ),
);

double _rotation(WidgetTester tester) => tester
    .widgetList<Transform>(find.byType(Transform))
    .map((widget) => widget.transform.entry(0, 2).abs())
    .fold(0.0, (a, b) => a > b ? a : b);

void main() {
  test(
    'AC4 — les constantes de flip sont publiques et conservent leurs valeurs',
    () {
      expect(ZFlashcardReviewCardPerspective, 0.001);
      expect(ZFlashcardReviewCardHalfTurn, 0.5);
      expect(ZFlashcardReviewCardMinTarget, 48);
    },
  );

  testWidgets('G5 — durée et courbe du thème pilotent le flip 3D', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const ZcrudTheme(
          flipDuration: Duration(milliseconds: 800),
          flipCurve: Curves.easeIn,
        ),
        ZRevealTransition.flip3d,
      ),
    );
    final stateBefore = tester.state(find.byType(ZFlashcardReviewCard));
    await tester.tap(find.byType(ZFlashcardReviewCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(
      _rotation(tester),
      lessThan(0.5),
      reason: 'la courbe easeIn du thème doit transformer la progression',
    );

    // 🔴 Le thème doit RÉELLEMENT changer (CR epic VIS, MEDIUM-4). Le premier
    // jet réinjectait ici le MÊME `ZcrudTheme` (800 ms / easeIn) : l'assertion
    // « un changement de thème ne recrée pas le controller » était donc
    // vérifiée SANS qu'aucun thème ne change — tautologique.
    await tester.pumpWidget(
      _host(
        const ZcrudTheme(
          flipDuration: Duration(milliseconds: 200),
          flipCurve: Curves.linear,
        ),
        ZRevealTransition.flip3d,
      ),
    );
    await tester.pump();
    expect(
      identical(stateBefore, tester.state(find.byType(ZFlashcardReviewCard))),
      isTrue,
      reason: 'un changement de thème ne doit pas recréer le controller (AD-2)',
    );

    // …et la nouvelle cinématique doit être PRISE EN COMPTE par le PROCHAIN
    // flip. Nuance mesurée : changer `duration` sur un `AnimationController`
    // n'accélère PAS une animation déjà en vol — la simulation courante garde
    // son rythme. C'est le comportement normal de Flutter ; une assertion qui
    // exigerait la ré-accélération à chaud échouerait à tort.
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ZFlashcardReviewCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // `_rotation` lit l'entrée (0,2) de la matrice, c'est-à-dire `sin(θ)` — pas
    // une progression de 0 à 1. À mi-parcours d'un demi-tour (θ = π/2) elle vaut
    // donc 1,0. Sous 200 ms linéaires, 100 ms placent exactement là ; sous les
    // 800 ms easeIn précédents, on n'aurait parcouru que ~12 % (sin ≈ 0,38).
    // Le seuil sépare franchement les deux régimes.
    expect(
      _rotation(tester),
      greaterThan(0.9),
      reason:
          'la durée du thème doit piloter le flip suivant : 100 ms sous 200 ms '
          'linéaires ⇒ mi-parcours ; sous 800 ms easeIn on serait très en deçà',
    );
  });

  testWidgets('G5 — la courbe du thème pilote aussi le fondu', (tester) async {
    await tester.pumpWidget(
      _host(
        const ZcrudTheme(
          flipDuration: Duration(milliseconds: 800),
          flipCurve: Curves.easeIn,
        ),
        ZRevealTransition.fade,
      ),
    );
    await tester.tap(find.byType(ZFlashcardReviewCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final opacity = tester.widget<Opacity>(find.byType(Opacity)).opacity;
    expect(
      opacity,
      greaterThan(0.7),
      reason: 'le fondu doit employer la même courbe thémable que flip3d',
    );
  });
}
