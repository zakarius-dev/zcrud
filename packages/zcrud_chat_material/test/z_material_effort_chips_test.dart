/// Gardes des **chips d'effort** — lot K3.
///
/// * **EFF-C1** — l'accent vient de la CHAÎNE du chrome, clé par clé : un
///   accent injecté est suivi, les autres restent la référence ;
/// * **EFF-C2** — sans chrome, l'accent est la référence K2 (exception FR-26
///   encadrée — les hex vivent LÀ-BAS, jamais ici) ;
/// * **EFF-W1** — le tap écrit par `setResponseLength` (voie unique) ; re-tap
///   ⇒ retour à « l'hôte décide » (`null`) ;
/// * **EFF-G1** — chaque chip rend ≥ 48 dp en GÉOMÉTRIE RENDUE (un
///   `ChoiceChip` nu rend ~32 dp : le `materialTapTargetSize` n'agrandit que
///   le hit-test, pas la boîte mesurable) ;
/// * **EFF-A1** — règle des trois cas : sans `slot.settings`, le builder rend
///   `null` — AUCUNE chip inerte (AD-4) ;
/// * **EFF-A2** — la coche (canal non chromatique) n'est pas désactivée : la
///   teinte n'est jamais porteuse seule (CR-74).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

const Color _cursor = Color(0xFF123456);
const Color _injected = Color(0xFF00FF00);

/// L'accent rendu pour le palier [length] : la couleur du `DecoratedBox` de
/// l'avatar de sa chip.
Color _accentOf(WidgetTester tester, ZChatResponseLength length) {
  final Finder chips = find.byType(ChoiceChip);
  final int index = ZChatResponseLength.values.indexOf(length);
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find
        .descendant(of: chips.at(index), matching: find.byType(DecoratedBox))
        .first,
  );
  return (box.decoration as ShapeDecoration).color!;
}

void main() {
  testWidgets('EFF-C2 — sans chrome, les TROIS accents sont la référence '
      'K2', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialEffortChips(controller: settings)),
    );
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    for (final ZChatResponseLength length in ZChatResponseLength.values) {
      expect(
        _accentOf(tester, length),
        ZChatComposerReference.responseLengthAccents[length],
        reason: '🔴 l\'accent de $length n\'est plus la référence lex',
      );
    }
  });

  testWidgets('🔴 EFF-C1 — un accent injecté par chrome est SUIVI, clé par '
      'clé', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(
        ZChatMaterialEffortChips(
          controller: settings,
          chrome: const ZChatComposerChrome(
            responseLengthAccents: <ZChatResponseLength, Color>{
              ZChatResponseLength.concise: _injected,
            },
          ),
        ),
      ),
    );
    expect(_accentOf(tester, ZChatResponseLength.concise), _injected,
        reason: '🔴 le builder ignore le chrome — l\'accent est recopié au '
            'lieu de passer par `responseLengthAccent`');
    expect(
      _accentOf(tester, ZChatResponseLength.standard),
      ZChatComposerReference.responseLengthAccents[ZChatResponseLength.standard],
      reason: '🔴 renseigner UNE clé a fait disparaître les autres accents '
          'de référence (résolution en bloc au lieu de clé par clé)',
    );
  });

  testWidgets('🔴 EFF-W1 — tap ⇒ setResponseLength ; re-tap ⇒ null', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialEffortChips(controller: settings)),
    );

    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump();
    expect(settings.settings.value.responseLength,
        ZChatResponseLength.detailed,
        reason: '🔴 le tap n\'écrit pas dans le contrôleur');

    await tester.tap(find.byType(ChoiceChip).at(2));
    await tester.pump();
    expect(settings.settings.value.responseLength, isNull,
        reason: '🔴 re-taper le palier choisi doit rendre la main à l\'hôte '
            '(« l\'hôte décide »), pas verrouiller le réglage');
  });

  testWidgets('🔴 EFF-G1 — chaque chip rend ≥ 48 dp (géométrie RENDUE, sous '
      'un thème d\'hôte HOSTILE)', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    // 🔴 `shrinkWrap` : sans NOTRE plancher, un ChoiceChip y rend ~32 dp.
    // Mesurer sous le thème par défaut (padded ⇒ 48 ambiant) rendrait cette
    // garde VACANTE — démasqué par l'injection I06 de la campagne R3.
    await tester.pumpWidget(
      harness(
        ZChatMaterialEffortChips(controller: settings),
        material: hostileTapTargets(),
      ),
    );
    for (int i = 0; i < ZChatResponseLength.values.length; i++) {
      final Size size = tester.getSize(find.byType(ChoiceChip).at(i));
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '🔴 chip $i : ${size.height} dp — la contrainte plancher a '
              'sauté, le hit-test « padded » ne compte pas');
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('🔴 EFF-A1 — sans slot.settings, le builder rend null : '
      'AUCUNE chip (AD-4)', (WidgetTester tester) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    await tester.pumpWidget(
      harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          tools: zChatMaterialEffortChips(),
          // AUCUN settings : des chips seraient des affordances inertes.
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNothing,
        reason: '🔴 des chips sans contrôleur de réglages sont des '
            'affordances inertes — AD-4 exige l\'ABSENCE');
  });

  testWidgets('EFF-A1b — avec settings, le même builder monte les chips', (
    WidgetTester tester,
  ) async {
    final rig = buildController();
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(rig.controller.dispose);
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          tools: zChatMaterialEffortChips(),
          settings: settings,
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNWidgets(3));
  });

  testWidgets('EFF-A2 — la coche du choix n\'est pas désactivée (canal non '
      'chromatique, CR-74)', (WidgetTester tester) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    settings.setResponseLength(ZChatResponseLength.concise);
    await tester.pumpWidget(
      harness(ZChatMaterialEffortChips(controller: settings)),
    );
    final ChoiceChip chip = tester.widget<ChoiceChip>(
      find.byType(ChoiceChip).first,
    );
    expect(chip.selected, isTrue);
    expect(chip.showCheckmark, isNot(isFalse),
        reason: '🔴 coche supprimée : la teinte porterait SEULE le choix '
            '(le défaut CR-74)');
  });
}
