/// SUF-3 AC15 (runtime) — RTL : la sidebar s'ancre côté START (droite visuelle
/// en RTL, gauche en LTR) ; cibles ≥ 48 dp ; libellés INJECTÉS rendus.
/// La part STATIQUE (0 couleur/label/API non-directionnelle en dur) est couverte
/// par le scanner récursif `z_widgets_hardcode_scan_test.dart` (toute la
/// présentation, mes fichiers inclus).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

void main() {
  testWidgets('RTL : la sidebar s\'ancre à droite (côté start visuel)',
      (tester) async {
    await setScreen(tester, 900, 800);
    await pumpDetail(tester, textDirection: TextDirection.rtl);
    final rect = tester.getRect(find.byType(ZSubfolderSidebar));
    // Ancrée côté start ⇒ bord DROIT au bord droit de l'écran.
    expect(rect.right, closeTo(900, 1));
  });

  testWidgets('LTR : la sidebar s\'ancre à gauche (côté start visuel)',
      (tester) async {
    await setScreen(tester, 900, 800);
    await pumpDetail(tester);
    final rect = tester.getRect(find.byType(ZSubfolderSidebar));
    expect(rect.left, closeTo(0, 1));
  });

  testWidgets('cible du contrôle de repli ≥ 48 dp', (tester) async {
    await setScreen(tester, 900, 800);
    await pumpDetail(tester);
    final size =
        tester.getSize(find.byKey(ZSubfolderSidebar.collapseToggleKey));
    expect(size.height, greaterThanOrEqualTo(48));
    expect(size.width, greaterThanOrEqualTo(48));
  });

  testWidgets('libellés INJECTÉS rendus (item racine)', (tester) async {
    await setScreen(tester, 900, 800);
    await pumpDetail(tester);
    expect(find.text(kAllLabel), findsOneWidget);
  });
}
