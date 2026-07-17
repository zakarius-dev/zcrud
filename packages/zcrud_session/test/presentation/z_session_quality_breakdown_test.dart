/// AC2 (CŒUR) — `ZSessionQualityBreakdown` : rend `byQuality` INJECTÉ, un et un
/// seul segment par clé, aucune catégorie omise/inversée, ordonné par qualité
/// croissante ; clé HORS échelle signalée À PART (R6). AC7 (consommation directe
/// de `result.byQuality`). Discriminant INJ-2.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: ZcrudScope(child: Scaffold(body: Center(child: child))),
    );

int _countOf(WidgetTester tester, String segmentKey) {
  final node = tester.getSemantics(find.byKey(ValueKey<String>(segmentKey)));
  return int.parse(node.value);
}

void main() {
  group('AC2 — comptage fidèle (discriminant INJ-2)', () {
    testWidgets('un segment par clé présente, valeur exacte, ordre croissant',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZSessionQualityBreakdown(
          byQuality: <String, int>{'0': 1, '2': 3, '5': 2},
          scale: ZQualityScale.fromConfig(const ZSrsConfig()),
          passThreshold: 3,
        ),
      ));

      // Exactement les 3 segments présents, chacun avec sa valeur EXACTE.
      const prefix = ZSessionQualityBreakdown.segmentKeyPrefix;
      expect(find.byKey(const ValueKey<String>('${prefix}0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('${prefix}2')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('${prefix}5')), findsOneWidget);
      // Aucune catégorie absente (1/3/4) n'est matérialisée.
      expect(find.byKey(const ValueKey<String>('${prefix}1')), findsNothing);
      expect(find.byKey(const ValueKey<String>('${prefix}3')), findsNothing);
      expect(find.byKey(const ValueKey<String>('${prefix}4')), findsNothing);

      expect(_countOf(tester, '${prefix}0'), 1);
      expect(_countOf(tester, '${prefix}2'), 3);
      expect(_countOf(tester, '${prefix}5'), 2);

      // Ordre croissant de qualité (position visuelle 0 < 2 < 5).
      final dx0 = tester
          .getTopLeft(find.byKey(const ValueKey<String>('${prefix}0')))
          .dx;
      final dx2 = tester
          .getTopLeft(find.byKey(const ValueKey<String>('${prefix}2')))
          .dx;
      final dx5 = tester
          .getTopLeft(find.byKey(const ValueKey<String>('${prefix}5')))
          .dx;
      expect(dx0, lessThan(dx2));
      expect(dx2, lessThan(dx5));
      handle.dispose();
    });

    testWidgets('une clé HORS échelle est rendue À PART, jamais fusionnée (R6)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZSessionQualityBreakdown(
          byQuality: <String, int>{'2': 3, '9': 7},
          scale: ZQualityScale.fromConfig(const ZSrsConfig()),
          passThreshold: 3,
        ),
      ));
      // Le compte de la clé connue "2" n'est PAS pollué par "9".
      expect(
        _countOf(tester, '${ZSessionQualityBreakdown.segmentKeyPrefix}2'),
        3,
      );
      // La clé hors échelle a son propre segment signalé.
      final unknownKey =
          '${ZSessionQualityBreakdown.unknownKeyPrefix}9';
      expect(find.byKey(ValueKey<String>(unknownKey)), findsOneWidget);
      expect(_countOf(tester, unknownKey), 7);
      final node = tester.getSemantics(find.byKey(ValueKey<String>(unknownKey)));
      expect(node.label, contains('hors échelle'));
      handle.dispose();
    });

    testWidgets(
        'une clé NON-CANONIQUE en-range ("03") est rendue, jamais droppée (R6/D3)',
        (tester) async {
      // "03" parse en 3 (in-range) MAIS n'est PAS la clé canonique "3" : avec
      // l'ancien `int.tryParse`, elle était jugée « in-scale » (donc exclue de
      // la section hors-échelle) SANS produire de segment in-scale
      // (`containsKey('3')` == false) ⇒ son compte DISPARAISSAIT. Le fix
      // canonique la traite en hors-échelle : elle DOIT apparaître quelque part.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZSessionQualityBreakdown(
          byQuality: <String, int>{'2': 4, '03': 2},
          scale: ZQualityScale.fromConfig(const ZSrsConfig()),
          passThreshold: 3,
        ),
      ));
      // La clé canonique "2" reste rendue à sa valeur exacte.
      expect(
        _countOf(tester, '${ZSessionQualityBreakdown.segmentKeyPrefix}2'),
        4,
      );
      // La clé non-canonique "03" n'a AUCUN segment in-scale (pas de "3").
      expect(
        find.byKey(const ValueKey<String>(
            '${ZSessionQualityBreakdown.segmentKeyPrefix}3')),
        findsNothing,
      );
      // Elle DOIT être rendue dans la section hors-échelle, compte préservé.
      final unknownKey = '${ZSessionQualityBreakdown.unknownKeyPrefix}03';
      expect(find.byKey(const ValueKey<String>(
          '${ZSessionQualityBreakdown.unknownKeyPrefix}03')), findsOneWidget);
      expect(_countOf(tester, unknownKey), 2);
      final node = tester.getSemantics(find.byKey(ValueKey<String>(unknownKey)));
      expect(node.label, contains('hors échelle'));
      handle.dispose();
    });
  });

  group('AC7 — consomme result.byQuality directement', () {
    testWidgets('le breakdown de result.byQuality == breakdown de la map brute',
        (tester) async {
      const result = ZStudySessionResult(
        mode: ZReviewMode.spaced,
        total: 6,
        correct: 5,
        byQuality: <String, int>{'0': 1, '4': 2, '5': 3},
      );
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        ZSessionQualityBreakdown(
          byQuality: result.byQuality,
          scale: ZQualityScale.fromConfig(const ZSrsConfig()),
          passThreshold: 3,
        ),
      ));
      const prefix = ZSessionQualityBreakdown.segmentKeyPrefix;
      expect(_countOf(tester, '${prefix}0'), 1);
      expect(_countOf(tester, '${prefix}4'), 2);
      expect(_countOf(tester, '${prefix}5'), 3);
      handle.dispose();
    });
  });
}
