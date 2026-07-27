/// Gardes VIS-3 : identité stable de type et couture de dégradé hôte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const _height = 7.0;
const _specs = <String, ZGradientSpec>{
  'multipleChoice': ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(1), Color(2)]),
    onGradient: Color(3),
  ),
  'trueOrFalse': ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(4), Color(5)]),
    onGradient: Color(6),
  ),
  'openQuestion': ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(7), Color(8)]),
    onGradient: Color(9),
  ),
  'exercise': ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(10), Color(11)]),
    onGradient: Color(12),
  ),
  'fillBlank': ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(13), Color(14)]),
    onGradient: Color(15),
  ),
  'shortAnswer': ZGradientSpec(
    gradient: LinearGradient(colors: <Color>[Color(16), Color(17)]),
    onGradient: Color(18),
  ),
};

ZGradientResolver _resolver(List<String> received) =>
    (ColorScheme _, String key) {
      received.add(key);
      return _specs[key];
    };

Widget _host({
  required List<ZFlashcard> cards,
  required ZGradientResolver resolver,
}) => MaterialApp(
  home: ZcrudScope(
    theme: const ZcrudTheme(
      accentBarHeight: _height,
      gradientBegin: AlignmentDirectional.topStart,
      gradientEnd: AlignmentDirectional.bottomEnd,
    ),
    gradientResolver: resolver,
    child: Scaffold(
      body: Column(
        children: <Widget>[
          for (final card in cards)
            SizedBox(width: 240, child: ZFlashcardReviewCard(card: card)),
        ],
      ),
    ),
  ),
);

List<ZFlashcard> _cards(Iterable<ZFlashcardType> types) => <ZFlashcard>[
  for (final type in types)
    ZFlashcard(question: type.name, answer: 'A', type: type),
];

void main() {
  testWidgets('G1 — le type garde sa clé après tri, filtre et permutation', (
    tester,
  ) async {
    final received = <String>[];
    final types = ZFlashcardType.values;
    await tester.pumpWidget(
      _host(cards: _cards(types), resolver: _resolver(received)),
    );
    expect(received, containsAll(types.map((type) => type.name)));

    received.clear();
    final reordered = <ZFlashcardType>[
      ZFlashcardType.exercise,
      ZFlashcardType.openQuestion,
      ZFlashcardType.shortAnswer,
    ];
    await tester.pumpWidget(
      _host(cards: _cards(reordered), resolver: _resolver(received)),
    );

    expect(
      received,
      orderedEquals(reordered.map((type) => type.name)),
      reason:
          'le resolver doit recevoir card.type.name, jamais un index de '
          'tri, filtre, pagination ou permutation',
    );
  });

  testWidgets('G3 — le seam hôte fournit le gradient et les tokens VIS', (
    tester,
  ) async {
    final received = <String>[];
    await tester.pumpWidget(
      _host(
        cards: _cards(<ZFlashcardType>[ZFlashcardType.openQuestion]),
        resolver: _resolver(received),
      ),
    );

    expect(received, <String>['openQuestion']);
    final accent = tester.widget<Container>(
      find.byKey(ZFlashcardReviewCard.gradientAccentKey),
    );
    final decoration = accent.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(accent.constraints?.maxHeight, _height);
    expect(gradient.colors, _specs['openQuestion']!.gradient.colors);
    expect(gradient.begin, AlignmentDirectional.topStart);
    expect(gradient.end, AlignmentDirectional.bottomEnd);
  });

  testWidgets('G4 — sans seam ni tokens VIS, aucune barre n’est construite', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ZFlashcardReviewCard(
            card: ZFlashcard(question: 'Q', answer: 'A'),
          ),
        ),
      ),
    );

    expect(find.byKey(ZFlashcardReviewCard.gradientAccentKey), findsNothing);
  });
}
