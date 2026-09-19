import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

void main() {
  testWidgets('carrés, puces et qualité conservés en RTL avec texte agrandi', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: ZcrudScope(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: ZSrsQualityButtons(
                  scale: ZQualityScale.fromConfig(const ZSrsConfig()),
                  passThreshold: 3,
                  square: true,
                  selectedQuality: 4,
                  previewLabelFor: (q) => '$q jours',
                  onQualitySelected: selected.add,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    for (var q = 0; q <= 5; q++) {
      final button = find.byKey(ValueKey('zSrsQuality_$q'));
      final size = tester.getSize(button);
      expect(size.width, size.height);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(
        find.descendant(of: button, matching: find.byType(DecoratedBox)),
        findsOneWidget,
      );
      await tester.tap(button);
    }
    expect(selected, [0, 1, 2, 3, 4, 5]);
    expect(tester.takeException(), isNull);
  });
}
