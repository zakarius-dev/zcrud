/// SUF-3 AC10 (resize borné, largeur persistée sans I/O), AC11 (repli ~56 dp),
/// AC12 (réordonnable ssi callback), AC13 (bouton « Ajouter » slot).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

void main() {
  group('AC10 — sidebar redimensionnable, bornée, largeur persistée sans I/O',
      () {
    testWidgets('drag +10000 ⇒ borne max (≤ 50 % écran) ; callback = clampé',
        (tester) async {
      await setScreen(tester, 900, 800);
      double? emitted;
      await pumpDetail(
        tester,
        nav: navSpec(onSidebarWidthChanged: (w) => emitted = w),
      );

      await tester.drag(
        find.byKey(ZSubfolderSidebar.resizeHandleKey),
        const Offset(10000, 0),
      );
      await tester.pumpAndSettle();

      final w = tester.getSize(find.byType(ZSubfolderSidebar)).width;
      // max = min(300, 900×0.5) = 450.
      expect(w, closeTo(450, 0.5));
      // GARDE MORDANTE : retirer le `clamp` laisserait la largeur dépasser 450.
      expect(w, lessThanOrEqualTo(900 * 0.5 + 0.5));
      expect(emitted, closeTo(450, 0.5));
    });

    testWidgets('drag -10000 ⇒ borne min (300)', (tester) async {
      await setScreen(tester, 900, 800);
      double? emitted;
      await pumpDetail(
        tester,
        nav: navSpec(onSidebarWidthChanged: (w) => emitted = w),
      );

      await tester.drag(
        find.byKey(ZSubfolderSidebar.resizeHandleKey),
        const Offset(-10000, 0),
      );
      await tester.pumpAndSettle();

      final w = tester.getSize(find.byType(ZSubfolderSidebar)).width;
      expect(w, closeTo(300, 0.5));
      expect(emitted, closeTo(300, 0.5));
    });
  });

  group('AC11 — repli / déploiement (~56 dp repliée)', () {
    testWidgets('tap repli masque la liste et réduit à ~56 dp ; re-tap restaure',
        (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);

      // Déployée : liste visible, largeur = largeur initiale clampée (320).
      expect(find.text('Sous-dossier 0'), findsOneWidget);
      expect(tester.getSize(find.byType(ZSubfolderSidebar)).width,
          closeTo(320, 0.5));

      await tester.tap(find.byKey(ZSubfolderSidebar.collapseToggleKey));
      await tester.pumpAndSettle();

      // GARDE MORDANTE : figer `_collapsed=false` empêcherait ce masquage.
      expect(find.text('Sous-dossier 0'), findsNothing);
      expect(tester.getSize(find.byType(ZSubfolderSidebar)).width,
          closeTo(56, 0.5));

      await tester.tap(find.byKey(ZSubfolderSidebar.collapseToggleKey));
      await tester.pumpAndSettle();
      expect(find.text('Sous-dossier 0'), findsOneWidget);
      expect(tester.getSize(find.byType(ZSubfolderSidebar)).width,
          closeTo(320, 0.5));
    });
  });

  group('AC12 — réordonnable ssi onSubfolderReorder fourni', () {
    testWidgets('onReorder null ⇒ AUCUNE poignée', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester); // navSpec par défaut : onReorder == null
      expect(find.byIcon(Icons.drag_handle), findsNothing);
    });

    testWidgets('onReorder fourni ⇒ poignées présentes + émission (old,new)',
        (tester) async {
      await setScreen(tester, 900, 800);
      final calls = <List<int>>[];
      await pumpDetail(
        tester,
        nav: navSpec(onReorder: (o, n) => calls.add(<int>[o, n])),
      );

      // Une poignée par sous-dossier (3).
      expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));

      final rlv =
          tester.widget<ReorderableListView>(find.byType(ReorderableListView));
      rlv.onReorderItem!(0, 2);
      // GARDE MORDANTE : inverser old/new dans l'émission donnerait [2,0].
      expect(calls, <List<int>>[
        <int>[0, 2],
      ]);
    });

    testWidgets('a11y : action sémantique « déplacer avant » émet (index, -1)',
        (tester) async {
      await setScreen(tester, 900, 800);
      final calls = <List<int>>[];
      await pumpDetail(
        tester,
        nav: navSpec(onReorder: (o, n) => calls.add(<int>[o, n])),
      );

      final before = CustomSemanticsAction(label: kMoveBefore);
      final node = tester.getSemantics(find.text('Sous-dossier 1'));
      expect(
        node.getSemanticsData().customSemanticsActionIds,
        contains(CustomSemanticsAction.getIdentifier(before)),
      );
      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(before),
      );
      expect(calls, <List<int>>[
        <int>[1, 0],
      ]);
    });
  });

  group('AC13 — bouton « Ajouter » via slot, absent si non fourni', () {
    testWidgets('sidebar : addAction fourni ⇒ bouton présent + tap invoque',
        (tester) async {
      await setScreen(tester, 900, 800);
      var hits = 0;
      await pumpDetail(tester, nav: navSpec(addAction: () => hits++));
      final btn = find.byKey(const ValueKey<String>('suf3:sidebar:add'));
      expect(btn, findsOneWidget);
      await tester.tap(btn);
      await tester.pump();
      expect(hits, 1);
    });

    testWidgets('sidebar : addAction null ⇒ bouton ABSENT', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester); // addAction null
      expect(find.byKey(const ValueKey<String>('suf3:sidebar:add')),
          findsNothing);
    });

    testWidgets('compact : addAction fourni ⇒ bouton présent + tap invoque',
        (tester) async {
      await setScreen(tester, 500, 800);
      var hits = 0;
      await pumpDetail(tester, nav: navSpec(addAction: () => hits++));
      final btn = find.byKey(const ValueKey<String>('suf3:compact:add'));
      expect(btn, findsOneWidget);
      await tester.ensureVisible(btn);
      await tester.pumpAndSettle();
      await tester.tap(btn);
      await tester.pump();
      expect(hits, 1);
    });
  });
}
