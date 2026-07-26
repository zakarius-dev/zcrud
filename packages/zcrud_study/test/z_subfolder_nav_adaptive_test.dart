/// SUF-3 AC7 — bascule sidebar ↔ sélecteur compact au franchissement du seuil
/// `ZWindowSizeThresholds.mediumMinWidth` (600), testée à DEUX largeurs locales
/// réelles (500 dp / 900 dp), jamais via un flag.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

void main() {
  testWidgets('< 600 dp : sélecteur compact, AUCUNE sidebar', (tester) async {
    await setScreen(tester, 500, 800);
    await pumpDetail(tester);

    expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
    // GARDE MORDANTE : rendre la sidebar dans le builder `compact` ferait
    // apparaître une sidebar à 500 dp.
    expect(find.byType(ZSubfolderSidebar), findsNothing);
  });

  testWidgets('≥ 600 dp : sidebar, AUCUN sélecteur compact', (tester) async {
    await setScreen(tester, 900, 800);
    await pumpDetail(tester);

    expect(find.byType(ZSubfolderSidebar), findsOneWidget);
    // GARDE MORDANTE : rendre le sélecteur compact dans le builder `expanded`
    // ferait apparaître des chips à 900 dp.
    expect(find.byType(ZSubfolderCompactSelector), findsNothing);
  });

  testWidgets('juste sous le seuil (599) reste compact', (tester) async {
    await setScreen(tester, 599, 800);
    await pumpDetail(tester);
    expect(find.byType(ZSubfolderCompactSelector), findsOneWidget);
    expect(find.byType(ZSubfolderSidebar), findsNothing);
  });

  testWidgets('juste au seuil (600) bascule en sidebar', (tester) async {
    await setScreen(tester, 600, 800);
    await pumpDetail(tester);
    expect(find.byType(ZSubfolderSidebar), findsOneWidget);
    expect(find.byType(ZSubfolderCompactSelector), findsNothing);
  });
}
