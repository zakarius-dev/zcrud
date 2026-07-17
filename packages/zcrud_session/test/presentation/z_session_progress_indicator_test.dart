/// AC8 (SU-4) — `ZSessionProgressIndicator` : variante par **ENUM**, couleurs et
/// libellés **INJECTÉS** (FR-SU7/AD-13/FR-26).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';

import 'z_swiper_harness.dart';

Future<void> _pump(
  WidgetTester tester, {
  ZSessionProgressStyle style = ZSessionProgressStyle.dots,
  int total = 4,
  int currentIndex = 1,
  ZSessionQualityAtIndex? qualityOf,
}) async {
  await tester.pumpWidget(
    wrapApp(
      ZSessionProgressIndicator(
        total: total,
        currentIndex: currentIndex,
        passThreshold: 3,
        style: style,
        qualityOf: qualityOf,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('AC8 — la variante est portée par un ENUM (jamais un booléen)', () {
    testWidgets('`dots` ⇒ un point par carte, aucun segment', (tester) async {
      await _pump(tester, style: ZSessionProgressStyle.dots);
      expect(find.byKey(const ValueKey<String>('zProgressDot_0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zProgressDot_3')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('zProgressDot_4')), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('zProgressSegment_0')),
        findsNothing,
      );
    });

    testWidgets('`segmentedBar` ⇒ un segment par carte, aucun point',
        (tester) async {
      await _pump(tester, style: ZSessionProgressStyle.segmentedBar);
      expect(
        find.byKey(const ValueKey<String>('zProgressSegment_0')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('zProgressSegment_3')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey<String>('zProgressDot_0')), findsNothing);
    });
  });

  group('AC8 — la couleur suit la QUALITÉ (seam injecté), jamais un littéral', () {
    testWidgets(
        '🔴 une carte notée en réussite et une en lapse ont des couleurs '
        'DIFFÉRENTES, et une non notée est neutre', (tester) async {
      // 0 → lapse (< passThreshold), 1 → réussite, 2 → non notée.
      await _pump(
        tester,
        total: 3,
        currentIndex: 0,
        style: ZSessionProgressStyle.dots,
        qualityOf: (i) => switch (i) { 0 => 0, 1 => 5, _ => null },
      );

      Color colorOf(int i) {
        final container = tester.widget<Container>(
          find.descendant(
            of: find.byKey(ValueKey<String>('zProgressDot_$i')),
            matching: find.byType(Container),
          ),
        );
        return (container.decoration! as BoxDecoration).color!;
      }

      final lapse = colorOf(0);
      final passed = colorOf(1);
      final pending = colorOf(2);

      expect(passed, isNot(lapse),
          reason: '🔴 réussite et lapse rendent la MÊME couleur ⇒ le seam de '
              'couleur n\'est pas consulté');
      expect(pending, isNot(passed),
          reason: 'une carte NON notée ne doit pas se peindre comme une '
              'réussite (l\'apprenant croirait l\'avoir déjà validée)');
    });
  });

  group('AC9 — la progression est ANNONCÉE (association, pas présence)', () {
    testWidgets('🔴 le `Semantics(value:)` est porté par le NŒUD de progression',
        (tester) async {
      await _pump(tester, style: ZSessionProgressStyle.dots, currentIndex: 1);

      // 🔴 Anti-défaut (su-2/HIGH, su-3/D6b) : on ne cherche PAS un nœud « par le
      // libellé qu'on vérifie ». On vise le nœud de progression par sa CLÉ, puis
      // on lit ce qu'il annonce — c'est l'ASSOCIATION qui est prouvée.
      final node = tester.getSemantics(
        find.byKey(ZSessionProgressIndicator.progressKey),
      );
      expect(
        node.value,
        '2/4',
        reason: '🔴 la progression n\'est pas annoncée SUR son propre nœud : un '
            'lecteur d\'écran ne saurait pas où en est la session',
      );
    });

    testWidgets('une file vide n\'explose pas et n\'annonce pas « 1/0 » (AD-10)',
        (tester) async {
      await _pump(tester, total: 0, currentIndex: 0);
      expect(tester.takeException(), isNull);
      final node = tester.getSemantics(
        find.byKey(ZSessionProgressIndicator.progressKey),
      );
      expect(node.value, '0/0');
    });
  });
}
