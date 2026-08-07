/// **CR-IFFD-76 (satellite)** — `ZChatMaterialComposer`, l'assemblé Material.
///
/// Les gardes vérifient que le satellite ne fait qu'INJECTER (glyphes, rôles,
/// FAB) dans l'assemblé PUR du socle — et que les acquis de l'assemblé
/// (défauts ② et ③ d'IFFD fermés) survivent au skin.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

void main() {
  group('🔴 MCP — l\'assemblé Material', () {
    testWidgets(
        'MCP-1 — il monte l\'assemblé PUR du socle, le FAB lex au créneau '
        'd\'envoi, et le fond `surfaceContainerHighest` de l\'hôte',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(
            controller: c.controller,
            settings: settings,
          ),
        ),
      );
      expect(find.byType(ZDefaultChatComposer), findsOneWidget,
          reason: '🔴 vue parallèle : le satellite doit poser son skin sur '
              'l\'assemblé du socle, jamais le réécrire.');
      expect(find.byType(ZChatMaterialSendFab), findsOneWidget,
          reason: '🔴 l\'envoi n\'est pas le FAB lex.');
      final BuildContext context = tester.element(
        find.byType(ZChatMaterialComposer),
      );
      final DecoratedBox box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(ZChatComposerSurface),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        Theme.of(context).colorScheme.surfaceContainerHighest,
        reason: '🔴 le fond doit être un RÔLE de l\'hôte, jamais une teinte.',
      );
    });

    testWidgets(
        'MCP-2 — défaut ② au travers du skin : la requête PART avec les '
        'réglages du contrôleur câblé', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      settings.setResponseLength(ZChatResponseLength.detailed);
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(
            controller: c.controller,
            settings: settings,
          ),
        ),
      );
      c.controller.seedDraft('question');
      await tester.pump();
      await tester.tap(find.byType(ZChatMaterialSendFab));
      await tester.pump();
      expect(c.port.calls, hasLength(1));
      expect(
        c.port.calls.single.settings.responseLength,
        ZChatResponseLength.detailed,
        reason: '🔴 défaut ② réinjecté à travers le satellite : les réglages '
            'sont réglés puis jetés.',
      );
    });

    testWidgets(
        'MCP-3 — défaut ③ au travers du skin : le badge VIVANT est dans la '
        'cible « outils », et son rect TAPPÉ ouvre la feuille',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      // Un réglage actif ⇒ le badge vivant affiche 1.
      settings.setResponseLength(ZChatResponseLength.concise);
      int opened = 0;
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(
            controller: c.controller,
            settings: settings,
            onOpenTools: () => opened++,
          ),
        ),
      );
      final Finder badge = find.byType(ZChatMaterialToolsBadge);
      expect(badge, findsOneWidget,
          reason: '🔴 le compteur vivant (tranche `activeCount`) doit être '
              'monté avec le bouton « outils ».');
      expect(find.text('1'), findsOneWidget,
          reason: '🔴 badge décoratif : il ne suit pas `activeCount`.');
      await tester.tapAt(tester.getCenter(badge));
      await tester.pump();
      expect(opened, 1,
          reason: '🔴 défaut ③ réinjecté : le badge vole le tap du bouton.');
    });

    testWidgets('MCP-4 — sans `onOpenTools` : ni bouton « outils » ni badge '
        '(AD-4)', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(
            controller: c.controller,
            settings: settings,
          ),
        ),
      );
      expect(find.byType(ZChatMaterialToolsBadge), findsNothing);
      expect(find.byType(ZChatComposerToolsTrigger), findsNothing);
    });
  });
}
