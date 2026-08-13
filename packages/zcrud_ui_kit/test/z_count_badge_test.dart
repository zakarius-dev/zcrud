// Gardes de `ZCountBadge` : le nombre est ANNONCÉ, la cible tactile reste
// confortable dès que la pastille est cliquable, et aucune couleur n'est
// écrite en dur (AD-13 / FR-26).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Future<void> pumpBadge(
  WidgetTester tester,
  Widget badge, {
  ThemeData? theme,
  TextDirection direction = TextDirection.ltr,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Directionality(
        textDirection: direction,
        // `Wrap` donne à la pastille ses contraintes INTRINSÈQUES : sans lui,
        // un `Center` la laisserait s'étendre aux dimensions de l'écran et
        // toute mesure de cible tactile serait vraie d'avance.
        child: Scaffold(body: Center(child: Wrap(children: <Widget>[badge]))),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Couleur de fond de la pastille (le `Container` décoré le plus profond).
Color pillColor(WidgetTester tester) {
  final containers = tester.widgetList<Container>(find.byType(Container));
  for (final container in containers) {
    final decoration = container.decoration;
    if (decoration is BoxDecoration && decoration.color != null) {
      return decoration.color!;
    }
  }
  fail('aucune pastille décorée trouvée');
}

void main() {
  testWidgets('le NOMBRE est annoncé, jamais laissé muet', (tester) async {
    await pumpBadge(tester, const ZCountBadge(count: 3));
    expect(find.text('3'), findsOneWidget);
    expect(
      find.bySemanticsLabel('3'),
      findsOneWidget,
      reason: 'la pastille n\'expose aucune annonce du nombre',
    );
  });

  testWidgets('l\'annonce déclarée NOMME ce qui est compté', (tester) async {
    await pumpBadge(
      tester,
      const ZCountBadge(count: 3, semanticsLabel: '3 éléments en corbeille'),
    );
    expect(find.bySemanticsLabel('3 éléments en corbeille'), findsOneWidget);
    // Le texte de la pastille n'est PAS annoncé une seconde fois.
    expect(find.bySemanticsLabel('3'), findsNothing);
  });

  testWidgets('cliquable ⇒ cible tactile ≥ 48 dp', (tester) async {
    var taps = 0;
    await pumpBadge(
      tester,
      ZCountBadge(count: 5, onTap: () => taps++, semanticsLabel: '5 messages'),
    );
    final size = tester.getSize(find.byType(InkWell));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(InkWell));
    expect(taps, 1);
  });

  testWidgets('cliquable ⇒ annoncée comme un BOUTON', (tester) async {
    await pumpBadge(
      tester,
      ZCountBadge(count: 5, onTap: () {}, semanticsLabel: '5 messages'),
    );
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('5 messages')),
      isSemantics(
        label: '5 messages',
        isButton: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('zéro : rien ne s\'affiche, sauf déclaration contraire',
      (tester) async {
    await pumpBadge(tester, const ZCountBadge(count: 0));
    expect(find.text('0'), findsNothing);

    await pumpBadge(tester, const ZCountBadge(count: 0, showZero: true));
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('le contenu porté reste rendu même sans pastille',
      (tester) async {
    await pumpBadge(
      tester,
      const ZCountBadge(count: 0, child: Icon(Icons.delete)),
    );
    expect(find.byIcon(Icons.delete), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('grand nombre : écrêté à l\'affichage, annonce exacte',
      (tester) async {
    await pumpBadge(
      tester,
      const ZCountBadge(count: 1234, semanticsLabel: '1234 éléments'),
    );
    expect(find.text('99+'), findsOneWidget);
    expect(find.bySemanticsLabel('1234 éléments'), findsOneWidget);
  });

  testWidgets('FR-26 : les couleurs suivent le thème, jamais un littéral',
      (tester) async {
    final light = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
    );
    await pumpBadge(tester, const ZCountBadge(count: 2), theme: light);
    expect(pillColor(tester), light.colorScheme.error);

    await pumpBadge(tester, const ZCountBadge(count: 2), theme: dark);
    expect(pillColor(tester), dark.colorScheme.error);
    expect(dark.colorScheme.error, isNot(light.colorScheme.error));
  });

  testWidgets('AD-13 : la pastille posée sur un contenu bascule en RTL',
      (tester) async {
    const badge = ZCountBadge(count: 4, child: SizedBox(width: 40, height: 40));
    await pumpBadge(tester, badge);
    final ltrX = tester.getCenter(find.text('4')).dx;
    final ltrIconX = tester.getCenter(find.byType(SizedBox).first).dx;
    expect(ltrX, greaterThan(ltrIconX));

    await pumpBadge(tester, badge, direction: TextDirection.rtl);
    final rtlX = tester.getCenter(find.text('4')).dx;
    final rtlIconX = tester.getCenter(find.byType(SizedBox).first).dx;
    expect(
      rtlX,
      lessThan(rtlIconX),
      reason: 'la pastille est restée à droite en RTL (placement non '
          'directionnel)',
    );
  });
}
