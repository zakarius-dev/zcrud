import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _host(
  Widget appBar, {
  ZcrudLabels? labels,
  TextDirection direction = TextDirection.ltr,
}) {
  Widget home = Scaffold(appBar: appBar as PreferredSizeWidget);
  home = Directionality(textDirection: direction, child: home);
  if (labels != null) {
    home = ZcrudScope(labels: labels, child: home);
  }
  return MaterialApp(home: home);
}

void main() {
  // AC1 — titre + leading conditionnel.
  testWidgets('AC1: titre rendu ; leading présent ssi fourni', (tester) async {
    await tester.pumpWidget(_host(
      const ZSearchableAppBar(
        title: 'Mon titre',
        leading: Icon(Icons.menu, key: Key('lead')),
      ),
    ));
    expect(find.text('Mon titre'), findsOneWidget);
    expect(find.byKey(const Key('lead')), findsOneWidget);
    expect(tester.widget<AppBar>(find.byType(AppBar)).leading, isNotNull);

    // leading == null ⇒ AUCUN leading (aucun placeholder — mordant AC1).
    await tester.pumpWidget(_host(const ZSearchableAppBar(title: 'T')));
    expect(tester.widget<AppBar>(find.byType(AppBar)).leading, isNull);
  });

  // AC2 — actions en données, absentes si non fournies.
  testWidgets('AC2: N actions ⇒ N icônes ; retrait ⇒ disparition', (tester) async {
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'T',
        actions: [
          ZAppBarAction(
            icon: Icons.edit,
            semanticLabel: 'Éditer',
            onPressed: () {},
          ),
          ZAppBarAction(
            icon: Icons.delete,
            semanticLabel: 'Supprimer',
            onPressed: () {},
          ),
        ],
      ),
    ));
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(2));

    // Retrait d'une action ⇒ son icône disparaît.
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'T',
        actions: [
          ZAppBarAction(
            icon: Icons.edit,
            semanticLabel: 'Éditer',
            onPressed: () {},
          ),
        ],
      ),
    ));
    expect(find.byIcon(Icons.edit), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsNothing);
    expect(find.byType(IconButton), findsOneWidget);
  });

  // AC3 — a11y + cible ≥ 48 dp + bon callback.
  testWidgets('AC3: tap action index 1 invoque le bon callback', (tester) async {
    var tapped = -1;
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'T',
        actions: [
          ZAppBarAction(
            icon: Icons.edit,
            semanticLabel: 'Éditer',
            onPressed: () => tapped = 0,
          ),
          ZAppBarAction(
            icon: Icons.delete,
            semanticLabel: 'Supprimer',
            onPressed: () => tapped = 1,
          ),
        ],
      ),
    ));
    // Cible tactile ≥ 48 dp.
    final size = tester.getSize(find.widgetWithIcon(IconButton, Icons.delete));
    expect(size.height, greaterThanOrEqualTo(48.0));
    expect(size.width, greaterThanOrEqualTo(48.0));
    // Semantics explicite (label de l'action).
    expect(find.bySemanticsLabel('Supprimer'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete));
    expect(tapped, 1);
  });

  // AC4 — bascule recherche : morphe en champ, re-bascule restaure.
  testWidgets('AC4: loupe morphe en champ ; re-tap restaure', (tester) async {
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'Titre',
        search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
      ),
    ));
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Titre'), findsOneWidget);
  });

  // AC5 — émission de la query + query détenue par le widget.
  testWidgets('AC5: saisie ⇒ émission exacte + queryListenable', (tester) async {
    final emitted = <String>[];
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'T',
        search: ZAppBarSearchConfig(onQueryChanged: emitted.add),
      ),
    ));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pump();

    expect(emitted.last, 'abc');
    final state = tester.state<ZSearchableAppBarState>(
      find.byType(ZSearchableAppBar),
    );
    expect(state.queryListenable.value, 'abc');
  });

  // AC7 — fermeture vide ET émet ''.
  testWidgets('AC7: close vide la query + émet "" + restaure le titre',
      (tester) async {
    final emitted = <String>[];
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'Titre',
        search: ZAppBarSearchConfig(onQueryChanged: emitted.add),
      ),
    ));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    expect(emitted.last, 'hello');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    final state = tester.state<ZSearchableAppBarState>(
      find.byType(ZSearchableAppBar),
    );
    expect(state.queryListenable.value, '');
    expect(emitted.last, '');
    expect(find.text('Titre'), findsOneWidget);
  });

  // AC8 — recherche absente si non configurée.
  testWidgets('AC8: search null ⇒ aucune loupe', (tester) async {
    await tester.pumpWidget(_host(const ZSearchableAppBar(title: 'T')));
    expect(find.byIcon(Icons.search), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  // AC13 — hint résolu par label injecté (ZcrudScope).
  testWidgets('AC13: hint résolu depuis ZcrudLabels injectés', (tester) async {
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'T',
        search: ZAppBarSearchConfig(onQueryChanged: (_) {}),
      ),
      labels: ZcrudLabels({'search': 'ZZZ'}),
    ));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, 'ZZZ');
  });

  // AC13 — hintLabel explicite prime sur la résolution l10n.
  testWidgets('AC13: hintLabel explicite prime', (tester) async {
    await tester.pumpWidget(_host(
      ZSearchableAppBar(
        title: 'T',
        search: ZAppBarSearchConfig(
          onQueryChanged: (_) {},
          hintLabel: 'Explicite',
        ),
      ),
      labels: ZcrudLabels({'search': 'ZZZ'}),
    ));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration?.hintText, 'Explicite');
  });
}
