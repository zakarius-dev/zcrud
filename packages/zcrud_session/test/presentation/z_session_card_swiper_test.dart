/// AC1 (SU-4) — `ZSessionCardSwiper` : la pile se monte, la carte courante est
/// rendue, la navigation avance l'index.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

List<ZSessionItem> _queue(int n) => <ZSessionItem>[
      for (var i = 0; i < n; i++)
        ZSessionItem(flashcardId: 'f$i', folderId: 'd1'),
    ];

/// Carte d'affichage minimale — le contenu porte l'id, pour prouver **QUELLE**
/// carte est rendue (jamais « une carte est rendue »).
Widget _card(BuildContext context, ZSessionItem item) => Center(
      key: ValueKey<String>('card_${item.flashcardId}'),
      child: Text(item.flashcardId),
    );

void main() {
  group('AC1 — la pile se monte et rend la carte COURANTE', () {
    testWidgets('la carte de devant est celle de l\'index 0', (tester) async {
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: _queue(3),
              cardBuilder: _card,
              passThreshold: 3,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey<String>('card_f0')), findsOneWidget);
      // `numberOfCardsDisplayed: min(2, 3)` ⇒ la carte de fond (index 1) est
      // rendue elle aussi ; la 3ᵉ ne l'est pas.
      expect(find.byKey(const ValueKey<String>('card_f2')), findsNothing);
    });

    testWidgets(
        '🔴 la navigation (bouton accessible) AVANCE l\'index et émet '
        '`onIndexChanged` — voie UNIQUE (A6)', (tester) async {
      final indices = <int>[];
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: _queue(3),
              cardBuilder: _card,
              passThreshold: 3,
              onIndexChanged: indices.add,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();

      expect(
        indices,
        <int>[1],
        reason: '🔴 la navigation programmatique doit passer par `onSwipe` — '
            '`controller.moveTo` COURT-CIRCUITE `onSwipe` (vérifié sur disque, '
            '`card_swiper_state.dart:329`) et n\'émettrait rien',
      );
      expect(find.byKey(const ValueKey<String>('card_f1')), findsOneWidget);
    });

    testWidgets('`onStackEnd` est émis en fin de pile, une SEULE fois',
        (tester) async {
      var ends = 0;
      await tester.pumpWidget(
        wrapApp(
          SizedBox(
            height: 600,
            child: ZSessionCardSwiper(
              queue: _queue(2),
              cardBuilder: _card,
              passThreshold: 3,
              onStackEnd: () => ends++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(ends, 0, reason: 'la pile n\'est pas finie après 1 carte sur 2');

      await tester.tap(find.byKey(ZSessionCardSwiper.nextButtonKey));
      await tester.pumpAndSettle();
      expect(ends, 1, reason: '🔴 `isLoop: false` est indispensable : au défaut '
          '`true`, la pile boucle et `onEnd` n\'est JAMAIS atteint');
    });
  });
}
