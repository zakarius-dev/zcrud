/// Gardes du **slider de budget labellisé** — lot K3.
///
/// * **SLD-K1** — bornes/divisions DÉRIVÉES du kernel
///   (`ZChatComputeEffort.min/max`), jamais des littéraux ;
/// * **SLD-W1** — le geste écrit par `setComputeEffort` (voie unique) : glisser
///   au bout ⇒ palier max ;
/// * **SLD-W2** — 🔴 le MONTAGE n'écrit pas : budget absent (`null` =
///   « l'hôte décide ») RESTE absent tant qu'aucun geste n'a eu lieu — monter
///   une feuille ne change pas la requête ;
/// * **SLD-G1** — la tuile rend ≥ 48 dp en géométrie RENDUE ;
/// * **SLD-B1** — branché sur `ZChatSettingsSheet.computeBudgetBuilder`, le
///   slider REMPLACE la tuile à chips du socle (l'écart assumé du satellite —
///   le défaut socle reste les chips, verrouillé par SET-S1/CR-74) ;
/// * **SLD-L1** — l'échelle Rapide/Équilibré/Profond est rendue, hors arbre
///   sémantique (le `Slider` annonce déjà le palier).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

void main() {
  testWidgets('SLD-K1 — bornes et divisions viennent du kernel', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialBudgetSlider(controller: settings)),
    );
    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, ZChatComputeEffort.min.toDouble());
    expect(slider.max, ZChatComputeEffort.max.toDouble());
    expect(
      slider.divisions,
      ZChatComputeEffort.max - ZChatComputeEffort.min,
      reason: '🔴 divisions recopiées au lieu d\'être dérivées des bornes',
    );
  });

  testWidgets('🔴 SLD-W1 — glisser au bout écrit le palier MAX par '
      'setComputeEffort', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialBudgetSlider(controller: settings)),
    );

    final Offset center = tester.getCenter(find.byType(Slider));
    final Offset end = tester.getTopRight(find.byType(Slider));
    await tester.dragFrom(center, Offset(end.dx - center.dx, 0));
    await tester.pumpAndSettle();

    expect(
      settings.settings.value.computeEffort,
      ZChatComputeEffort(ZChatComputeEffort.max),
      reason: '🔴 le geste n\'atteint pas le contrôleur',
    );
  });

  testWidgets('🔴 SLD-W2 — budget ABSENT : le montage n\'écrit RIEN', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    expect(settings.settings.value.computeEffort, isNull);
    await tester.pumpWidget(
      harness(ZChatMaterialBudgetSlider(controller: settings)),
    );
    await tester.pump();
    expect(settings.settings.value.computeEffort, isNull,
        reason: '🔴 monter la tuile a ÉCRIT un budget — la première '
            'écriture doit être un geste utilisateur, jamais un effet de '
            'montage');
  });

  testWidgets('SLD-G1 — la zone du slider rend ≥ 48 dp', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialBudgetSlider(controller: settings)),
    );
    expect(
      tester.getSize(find.byType(Slider)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('🔴 SLD-B1 — via computeBudgetBuilder, le slider REMPLACE la '
      'tuile à chips du socle', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(
        ZChatSettingsSheet(
          controller: settings,
          computeBudgetBuilder: zChatMaterialBudgetSlider(),
        ),
      ),
    );
    expect(find.byType(Slider), findsOneWidget,
        reason: '🔴 le builder n\'est pas monté par la feuille');
    expect(find.byType(ZChatMaterialBudgetSlider), findsOneWidget);
  });

  testWidgets('SLD-L1 — l\'échelle des trois repères est rendue, HORS arbre '
      'sémantique', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialBudgetSlider(controller: settings)),
    );
    final Finder scale = find.descendant(
      of: find.byType(ExcludeSemantics),
      matching: find.byType(Text),
    );
    expect(scale, findsNWidgets(3),
        reason: '🔴 l\'échelle lex (Rapide/Équilibré/Profond) a disparu — '
            'ou est entrée dans l\'arbre sémantique (doublon d\'annonce)');
  });
}
