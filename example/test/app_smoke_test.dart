import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_example/app.dart';
import 'package:zcrud_example/demos/edition_demo_screen.dart';
import 'package:zcrud_example/home_screen.dart';

void main() {
  testWidgets('AC1/AC3 — l\'app démarre, l\'accueil s\'affiche, navigation Édition',
      (tester) async {
    tester.view.physicalSize =
        Size(1200 * tester.view.devicePixelRatio, 3000 * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    // Accueil monté avec la liste des domaines.
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Édition'), findsOneWidget);
    expect(find.text('Liste'), findsOneWidget);
    // EX-3 (AC9) : TOUTES les features MVP sont actives ; plus AUCUNE entrée
    // « à venir » ne subsiste (l'epic EX est clôturé). Les 5 nouvelles démos
    // sont présentes.
    expect(find.widgetWithText(Chip, 'à venir'), findsNothing);
    for (final title in <String>['Markdown', 'Geo', 'Intl', 'Export']) {
      expect(find.text(title), findsOneWidget, reason: '$title attendu');
    }

    // Navigation vers la démo Édition.
    await tester.tap(find.text('Édition'));
    await tester.pumpAndSettle();
    expect(find.byType(EditionDemoScreen), findsOneWidget);
  });

  testWidgets('AC3 — bascule RTL sans exception', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(HomeScreen))),
        TextDirection.ltr);

    await tester.tap(find.byTooltip('Sens : LTR'));
    await tester.pumpAndSettle();

    expect(Directionality.of(tester.element(find.byType(HomeScreen))),
        TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AC3 — bascule langue fr↔en', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    // Bascule de langue (tooltip contient le code de langue courant).
    await tester.tap(find.byTooltip('Langue (fr)'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Langue (en)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
