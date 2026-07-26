// SUF-2 (AC10 / R3-G14) — golden NEUTRE de `ZFolderCard`.
//
// Fige le rendu par défaut (thème FIXE déterministe `buildFixedTheme`, police
// Ahem de flutter_test, surface + devicePixelRatio + textScaleFactor figés,
// animations off) : carte plate, fond teinté `alpha 0.12`, pastille pleine,
// titre 2 lignes ancré bas, badge « Archivé », slot compteur + slot menu.
//
// POUVOIR DISCRIMINANT (R3-G14) : le golden est une empreinte pixel — toute
// dérive de layout/teinte (ex. modifier `tintAlpha`, retirer l'ancre bas,
// masquer le badge) change les octets et le fait ROUGIR. Prouvé en verification
// (micro-régression volontaire → diff, retirée avant `done`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import '_fixtures.dart';

void main() {
  testWidgets('AC10 — golden neutre correspond au fichier committé',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(240, 180);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildFixedTheme(),
        home: const Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                height: 160,
                child: ZFolderCard(
                  title: 'Dossier de reference',
                  colorKey: 'secondary',
                  counts: Text('12 cartes'),
                  menu: Icon(Icons.more_vert),
                  isArchived: true,
                  archivedLabel: 'Archive',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ZFolderCard),
      matchesGoldenFile('goldens/z_folder_card_neutral.png'),
    );
  });
}
