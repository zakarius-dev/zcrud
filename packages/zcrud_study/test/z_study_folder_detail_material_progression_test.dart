/// SUF-3 AC5 (onglet Matériel COMPOSE `ZSectionedStudyLayout`) et AC6 (onglet
/// Progression rend `ZStudyProgressRings` + cartes injectées, état vide sûr).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

void main() {
  group('AC5 — onglet Matériel COMPOSE ZSectionedStudyLayout', () {
    testWidgets('un seul ZSectionedStudyLayout, sections = builder',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(tester);
      expect(find.byType(ZSectionedStudyLayout), findsOneWidget);
      // Section fournie par le builder (sélection racine ⇒ id null).
      expect(find.byKey(const ValueKey<String>('empty:null')), findsOneWidget);
    });
  });

  group('AC6 — onglet Progression : anneau + cartes ; état vide sûr si null',
      () {
    testWidgets('rings + 3 cartes de stats visibles ; sémantique 7/10',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        progressData:
            const ZProgressRingsData(total: 10, correct: 7, ratio: .7),
        progressStatCards: const <Widget>[
          Text('stat A', key: ValueKey<String>('stat-a')),
          Text('stat B', key: ValueKey<String>('stat-b')),
          Text('stat C', key: ValueKey<String>('stat-c')),
        ],
      );
      await tester.tap(find.text(kProgTab));
      await tester.pumpAndSettle();

      expect(find.byType(ZStudyProgressRings), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stat-a')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stat-b')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('stat-c')), findsOneWidget);

      // La sémantique « correct/total » est portée par l'anneau réutilisé.
      expect(
        tester.getSemantics(find.byType(ZStudyProgressRings)),
        matchesSemantics(value: '7/10'),
      );
    });

    testWidgets('progressData null ⇒ état vide, PAS d\'anneau, PAS de throw',
        (tester) async {
      await setScreen(tester, 500, 800);
      await pumpDetail(
        tester,
        progressData: null,
        progressEmptyState:
            const Text('EMPTY', key: ValueKey<String>('prog-empty')),
      );
      await tester.tap(find.text(kProgTab));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : rendre les rings sans garde `null` ferait lever l'arbre
      // (progressData!). Ici : anneau absent, état vide présent, aucune exception.
      expect(tester.takeException(), isNull);
      expect(find.byType(ZStudyProgressRings), findsNothing);
      expect(find.byKey(const ValueKey<String>('prog-empty')), findsOneWidget);
    });
  });
}
