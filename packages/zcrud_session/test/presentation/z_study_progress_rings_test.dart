/// AC3 — `ZStudyProgressRings` : `CustomPaint` PUR sur DTO PRÉ-CALCULÉ.
/// `ZProgressRingsData.fromResult` : ratio clampé, `total == 0` → 0 (pas de
/// division par zéro). Discriminant INJ-3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: ZcrudScope(child: Scaffold(body: Center(child: child))),
    );

void main() {
  group('AC3 — ZProgressRingsData.fromResult (fonction PURE, discriminant INJ-3)',
      () {
    test('ratio = correct / total (8/6 → 0.75)', () {
      final data = ZProgressRingsData.fromResult(
        const ZStudySessionResult(total: 8, correct: 6),
      );
      expect(data.ratio, 0.75);
      expect(data.total, 8);
      expect(data.correct, 6);
    });

    test('total == 0 → ratio 0 (aucune division par zéro)', () {
      final data = ZProgressRingsData.fromResult(
        const ZStudySessionResult(total: 0, correct: 0),
      );
      expect(data.ratio, 0.0);
    });

    test('ratio clampé à [0, 1] même si correct > total (corpus incohérent)',
        () {
      final data = ZProgressRingsData.fromResult(
        const ZStudySessionResult(total: 4, correct: 9),
      );
      expect(data.ratio, 1.0);
    });

    test('égalité de valeur', () {
      expect(
        const ZProgressRingsData(total: 8, correct: 6, ratio: 0.75),
        const ZProgressRingsData(total: 8, correct: 6, ratio: 0.75),
      );
    });
  });

  group('AC3 — widget CustomPaint + Semantics', () {
    testWidgets('rend un CustomPaint et expose « correct/total »',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZStudyProgressRings(
          data: ZProgressRingsData.fromResult(
            const ZStudySessionResult(total: 8, correct: 6),
          ),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      final node =
          tester.getSemantics(find.byType(ZStudyProgressRings));
      expect(node.value, '6/8');
      handle.dispose();
    });

    testWidgets('total == 0 : rend sans crash (anneau vide)', (tester) async {
      await tester.pumpWidget(_wrap(
        ZStudyProgressRings(
          data: ZProgressRingsData.fromResult(
            const ZStudySessionResult(total: 0, correct: 0),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('0/0'), findsOneWidget);
    });
  });
}
