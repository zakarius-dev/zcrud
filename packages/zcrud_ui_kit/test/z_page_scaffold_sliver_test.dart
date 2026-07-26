import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

Widget _sliverHost(ZPageAppBarMode mode) => MaterialApp(
      home: ZPageScaffold(
        title: 'TITRE',
        mode: mode,
        body: const SizedBox(height: 2000, child: Text('LONG_BODY')),
      ),
    );

/// Position verticale du titre (haut de l'app-bar), ou `null` si le titre n'est
/// plus dans l'arbre (app-bar entièrement repliée/scrollée hors champ).
double? _titleTop(WidgetTester tester) {
  final finder = find.text('TITRE');
  if (finder.evaluate().isEmpty) return null;
  return tester.getTopLeft(finder).dy;
}

Future<void> _scrollUp(WidgetTester tester, Finder scrollable) async {
  await tester.drag(scrollable, const Offset(0, -400));
  await tester.pumpAndSettle();
}

void main() {
  // AC11 — floating se replie : l'app-bar quitte le champ au défilement.
  testWidgets('AC11: floating ⇒ l\'app-bar se replie au scroll', (tester) async {
    await tester.pumpWidget(_sliverHost(ZPageAppBarMode.floating));
    expect(find.byType(SliverAppBar), findsOneWidget);
    final before = _titleTop(tester);
    expect(before, isNotNull);
    await _scrollUp(tester, find.byType(CustomScrollView));
    final after = _titleTop(tester);
    // Repli : soit l'app-bar est sortie du champ (null), soit remontée (< before).
    expect(after == null || after < before!, isTrue,
        reason: 'une SliverAppBar floating doit se replier au défilement');
  });

  // AC11 — pinned garde l'app-bar visible (position constante).
  testWidgets('AC11: pinned ⇒ app-bar reste visible', (tester) async {
    await tester.pumpWidget(_sliverHost(ZPageAppBarMode.pinned));
    expect(find.byType(SliverAppBar), findsOneWidget);
    final before = _titleTop(tester);
    await _scrollUp(tester, find.byType(CustomScrollView));
    final after = _titleTop(tester);
    expect(after, isNotNull,
        reason: 'une SliverAppBar pinned reste visible en tête');
    expect(after, closeTo(before!, 0.5));
  });

  // AC11 — floatingPinned garde l'app-bar visible.
  testWidgets('AC11: floatingPinned ⇒ app-bar reste visible', (tester) async {
    await tester.pumpWidget(_sliverHost(ZPageAppBarMode.floatingPinned));
    expect(find.byType(SliverAppBar), findsOneWidget);
    final before = _titleTop(tester);
    await _scrollUp(tester, find.byType(CustomScrollView));
    final after = _titleTop(tester);
    expect(after, isNotNull);
    expect(after, closeTo(before!, 0.5));
  });

  // AC11 — fixed : aucune SliverAppBar + hauteur d'app-bar constante.
  testWidgets('AC11: fixed ⇒ aucune SliverAppBar, hauteur constante',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ZPageScaffold(
        title: 'TITRE',
        body: ListView(
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('L$i')),
          ],
        ),
      ),
    ));
    expect(find.byType(SliverAppBar), findsNothing);
    final before = tester.getSize(find.byType(AppBar)).height;
    await _scrollUp(tester, find.byType(ListView));
    final after = tester.getSize(find.byType(AppBar)).height;
    expect(after, before, reason: 'une app-bar fixe ne se replie pas');
  });
}
