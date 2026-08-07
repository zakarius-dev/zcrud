/// Gardes du **badge compteur** — lot K3.
///
/// * **BDG-C1** — le radius vient de la CHAÎNE du chrome (paramètre suivi) ;
/// * **BDG-C2** — sans chrome ni scope, le radius est la référence lex (et le
///   jeton `badgeRadius` du scope s'insère entre les deux) ;
/// * **BDG-R1** — rôles : actif ⇒ `primary`/`onPrimary`, zéro ⇒ surfaces —
///   jamais un hex local ;
/// * **BDG-L1** — `ZChatMaterialToolsBadge` SUIT la tranche `activeCount` du
///   contrôleur (F12) sans recompte d'hôte.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'support/z_chat_material_fakes.dart';

BoxDecoration _decoration(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(ZChatMaterialBadge),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  testWidgets('BDG-C2 — sans chrome ni scope, radius = référence lex (8)', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const ZChatMaterialBadge(count: 3)));
    expect(
      _decoration(tester).borderRadius,
      const BorderRadius.all(ZChatComposerReference.badgeRadius),
    );
  });

  testWidgets('🔴 BDG-C1 — un chrome différent ⇒ le radius SUIT', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      harness(
        const ZChatMaterialBadge(
          count: 3,
          chrome: ZChatComposerChrome(badgeRadius: Radius.circular(3)),
        ),
      ),
    );
    expect(
      _decoration(tester).borderRadius,
      const BorderRadius.all(Radius.circular(3)),
      reason: '🔴 le badge ignore le chrome — radius recopié',
    );
  });

  testWidgets('BDG-C2b — le JETON badgeRadius du scope s\'insère entre '
      'paramètre et référence', (WidgetTester tester) async {
    await tester.pumpWidget(
      harness(
        const ZChatMaterialBadge(count: 1),
        theme: const ZcrudTheme(badgeRadius: Radius.circular(5)),
      ),
    );
    expect(
      _decoration(tester).borderRadius,
      const BorderRadius.all(Radius.circular(5)),
      reason: '🔴 le jeton du scope est ignoré : la chaîne n\'a que deux '
          'maillons',
    );
  });

  testWidgets('BDG-R1 — rôles du ColorScheme de l\'hôte, selon l\'activité', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(harness(const ZChatMaterialBadge(count: 2)));
    final BuildContext context = tester.element(
      find.byType(ZChatMaterialBadge),
    );
    final ColorScheme scheme = Theme.of(context).colorScheme;
    expect(_decoration(tester).color, scheme.primary);

    await tester.pumpWidget(harness(const ZChatMaterialBadge(count: 0)));
    expect(_decoration(tester).color, scheme.surfaceContainerHighest,
        reason: '🔴 zéro réglage actif doit rester DISCRET (lex '
            '`:856-874`), pas accentué');
  });

  testWidgets('🔴 BDG-L1 — ZChatMaterialToolsBadge suit activeCount', (
    WidgetTester tester,
  ) async {
    final ZChatSettingsController settings = ZChatSettingsController();
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialToolsBadge(controller: settings)),
    );
    expect(find.text('0'), findsOneWidget);

    settings.setResponseLength(ZChatResponseLength.concise);
    await tester.pump();
    expect(find.text('1'), findsOneWidget,
        reason: '🔴 le badge ne suit pas la tranche `activeCount` — le '
            'compteur F12 est débranché');
  });
}
