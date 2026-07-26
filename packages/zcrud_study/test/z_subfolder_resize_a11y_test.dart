/// SUF-3 AC15 / AD-13 — la poignée de redimensionnement de la sidebar est
/// atteignable AUTREMENT qu'au drag de pointeur : nœud sémantique LABELLISÉ
/// (libellé INJECTÉ) portant `increase`/`decrease` (WCAG 2.5.7) et pilotage
/// CLAVIER par les flèches, inversées en RTL (WCAG 2.1.1).
///
/// Ces gardes complètent — sans le dupliquer — `z_subfolder_sidebar_test.dart`
/// (AC10), qui ne couvre QUE le drag de pointeur et ses bornes.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'support/suf3_harness.dart';

/// Nœud sémantique de la poignée.
SemanticsNode _handleNode(WidgetTester t) =>
    t.getSemantics(find.byKey(ZSubfolderSidebar.resizeHandleKey));

/// `FocusNode` de la poignée (la poignée est focusable — WCAG 2.1.1).
FocusNode _handleFocus(WidgetTester t) => t
    .widget<Focus>(
      find.descendant(
        of: find.byKey(ZSubfolderSidebar.resizeHandleKey),
        matching: find.byType(Focus),
      ),
    )
    .focusNode!;

double _sidebarWidth(WidgetTester t) =>
    t.getSize(find.byType(ZSubfolderSidebar)).width;

void main() {
  group('AC15 — poignée de resize : sémantique explicite (alternative au drag)',
      () {
    testWidgets('label INJECTÉ + actions increase/decrease + valeur = largeur',
        (tester) async {
      final handle = tester.ensureSemantics();
      await setScreen(tester, 900, 800);
      await pumpDetail(tester); // largeur initiale 320, bornes [300, 450]

      final data = _handleNode(tester).getSemanticsData();
      // GARDE MORDANTE : retirer le `Semantics` de `_ResizeHandle` (revenir au
      // `MouseRegion > GestureDetector` nu) ⇒ `getSemantics` ne trouve plus de
      // nœud (exception) et ces trois assertions rougissent.
      expect(data.label, kResizeLabel);
      expect(data.value, '320');
      expect(data.hasAction(SemanticsAction.increase), isTrue);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      handle.dispose();
    });

    testWidgets('action increase ÉLARGIT la sidebar et notifie (clampé)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await setScreen(tester, 900, 800);
      double? emitted;
      await pumpDetail(
        tester,
        nav: navSpec(onSidebarWidthChanged: (w) => emitted = w),
      );

      final node = _handleNode(tester);
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.increase);
      await tester.pumpAndSettle();

      // GARDE MORDANTE : câbler `onIncrease` sur un no-op (ou sur `_narrow`)
      // ferait échouer ces deux assertions.
      expect(_sidebarWidth(tester), closeTo(352, 0.5));
      // Changement NON-POINTEUR = immédiatement STABILISÉ ⇒ l'hôte persiste.
      expect(emitted, closeTo(352, 0.5));
      handle.dispose();
    });

    testWidgets('action decrease RÉTRÉCIT la sidebar', (tester) async {
      final handle = tester.ensureSemantics();
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);

      final node = _handleNode(tester);
      tester.binding.pipelineOwner.semanticsOwner!
          .performAction(node.id, SemanticsAction.decrease);
      await tester.pumpAndSettle();

      expect(_sidebarWidth(tester), closeTo(300, 0.5)); // 320-32 = 288 → clampé
      handle.dispose();
    });

    testWidgets('aux bornes, l\'action devient ABSENTE (jamais un no-op annoncé)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);

      // Poussée à la borne HAUTE (450 = 50 % de 900) par le drag existant.
      await tester.drag(
        find.byKey(ZSubfolderSidebar.resizeHandleKey),
        const Offset(10000, 0),
      );
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), closeTo(450, 0.5));

      final data = _handleNode(tester).getSemanticsData();
      // GARDE MORDANTE : exposer `onIncrease` inconditionnellement laisserait
      // cette action présente alors qu'elle ne peut plus rien faire (AD-45).
      expect(data.hasAction(SemanticsAction.increase), isFalse);
      expect(data.hasAction(SemanticsAction.decrease), isTrue);
      handle.dispose();
    });
  });

  group('AC15 — poignée de resize : pilotage CLAVIER (WCAG 2.1.1)', () {
    testWidgets('LTR : → élargit, ← rétrécit', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);

      _handleFocus(tester).requestFocus();
      await tester.pump();
      expect(_handleFocus(tester).hasPrimaryFocus, isTrue,
          reason: 'la poignée doit être FOCUSABLE (sinon aucune voie clavier)');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      // GARDE MORDANTE : supprimer `onKeyEvent` de `_ResizeHandle` laisse la
      // largeur à 320 ⇒ rouge.
      expect(_sidebarWidth(tester), closeTo(352, 0.5));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(_sidebarWidth(tester), closeTo(320, 0.5));
    });

    testWidgets('RTL : ← élargit (même inversion que le drag)', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester, textDirection: TextDirection.rtl);

      _handleFocus(tester).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      // GARDE MORDANTE : oublier l'inversion RTL rétrécirait (300) au lieu
      // d'élargir (352).
      expect(_sidebarWidth(tester), closeTo(352, 0.5));
    });

    testWidgets('cible de la poignée ≥ 48 dp', (tester) async {
      await setScreen(tester, 900, 800);
      await pumpDetail(tester);
      final size = tester.getSize(find.byKey(ZSubfolderSidebar.resizeHandleKey));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
