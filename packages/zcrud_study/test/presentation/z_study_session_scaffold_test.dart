/// **Lot 1 « étude »** — `ZStudySessionScaffold` : enveloppe MINCE, slots en
/// pass-through, **un seul** `Scaffold`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_session/zcrud_session.dart' show ZSessionCardSwiper;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZPageScaffold;

import '../support/z_study_session_harness.dart';

void main() {
  Widget page({
    Widget? fab,
    Widget? drawer,
    Widget? bottomNavigationBar,
    List<Widget>? footer,
  }) =>
      MaterialApp(
        home: ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          floatingActionButton: fab,
          drawer: drawer,
          bottomNavigationBar: bottomNavigationBar,
          persistentFooterButtons: footer,
        ),
      );

  testWidgets('l\'enveloppe pose UN `ZPageScaffold` et UN SEUL `Scaffold`',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    expect(find.byType(ZPageScaffold), findsOneWidget);
    // 🔴 UN SEUL porteur de slots : deux `Scaffold` produiraient un FAB
    // fantôme et un double tiroir.
    expect(find.byType(Scaffold), findsOneWidget,
        reason: '🔴 l\'enveloppe ne doit pas empiler son propre `Scaffold` '
            'sur celui de `ZPageScaffold`');
    // …et la session est bien dedans.
    expect(find.byType(ZStudySessionHost), findsOneWidget);
    expect(find.byType(ZSessionCardSwiper), findsOneWidget);
  });

  testWidgets('🔴 slots de page non fournis ⇒ ABSENTS de l\'arbre',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.floatingActionButton, isNull);
    expect(scaffold.drawer, isNull);
    expect(scaffold.bottomNavigationBar, isNull);
    expect(scaffold.persistentFooterButtons, isNull,
        reason: '🔴 un slot non fourni doit rester `null` — jamais une liste '
            'vide ou une boîte fabriquée par l\'enveloppe');
  });

  testWidgets(
      '🔴 chaque slot de page fourni ARRIVE au `Scaffold`, exactement une fois',
      (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      page(
        fab: const FloatingActionButton(
          key: ValueKey<String>('leFab'),
          onPressed: null,
          child: Icon(Icons.add),
        ),
        drawer: const Drawer(key: ValueKey<String>('leTiroir')),
        bottomNavigationBar: const SizedBox(
          key: ValueKey<String>('laBarre'),
          height: 56,
        ),
        footer: const <Widget>[SizedBox(key: ValueKey<String>('lePied'))],
      ),
    );
    await tester.pumpAndSettle();

    final Scaffold scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.floatingActionButton?.key,
        const ValueKey<String>('leFab'));
    expect(scaffold.drawer?.key, const ValueKey<String>('leTiroir'));
    expect(scaffold.bottomNavigationBar?.key,
        const ValueKey<String>('laBarre'));
    expect(scaffold.persistentFooterButtons?.single.key,
        const ValueKey<String>('lePied'));

    // 🔴 EXACTEMENT une occurrence rendue : un pass-through qui poserait le
    // slot ET le rendrait lui-même produirait un doublon silencieux.
    expect(find.byKey(const ValueKey<String>('leFab')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('laBarre')), findsOneWidget);
  });

  testWidgets(
      '🔴 les slots de SESSION traversent aussi l\'enveloppe (elle n\'en '
      'consomme aucun)', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ZStudySessionScaffold(
          title: 'Session',
          mode: ZReviewMode.list,
          queue: writtenCards(2),
          counterBuilder: (BuildContext c, ZStudySessionProgress p) =>
              Text('COMPTEUR ${p.total}'),
          headerBuilder: (BuildContext c, ZStudySessionProgress p) =>
              const Text('EN-TÊTE'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EN-TÊTE'), findsOneWidget);
    expect(find.text('COMPTEUR 2'), findsOneWidget,
        reason: '🔴 le slot reçoit la progression RÉELLE — un pass-through qui '
            'perdrait la donnée rendrait « COMPTEUR 0 »');
  });

  testWidgets('le titre de page est rendu', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Session'), findsOneWidget);
  });
}
