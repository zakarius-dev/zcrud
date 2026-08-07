/// **CR-IFFD-77 (satellite)** — ce que le rendu Material apporte aux deux
/// canaux ouverts par le socle : le FILET du conteneur (③, un RÔLE de l'hôte)
/// et le DÉCLENCHEUR de dictée (④, glyphe **et** rôle changeant à l'écoute).
///
/// 🔴 Le satellite n'invente aucune teinte (MAT-L2) et n'ajoute aucun verbe :
/// la dictée reste un geste d'hôte, l'état d'écoute reste **injecté**.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

/// La décoration réellement peinte par la surface du composer.
BoxDecoration decorationOf(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(ZChatComposerSurface),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

void main() {
  group('🔴 MCR77-A — ③ le filet du conteneur est un RÔLE de l\'hôte', () {
    testWidgets(
        'MCR77-A1 — par défaut, le filet est peint au `dividerColor` du thème '
        '(le rôle exact de lex), au rayon du conteneur',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(controller: c.controller, settings: settings),
        ),
      );
      final BuildContext context = tester.element(
        find.byType(ZChatMaterialComposer),
      );
      final BoxDecoration deco = decorationOf(tester);
      final Border? border = deco.border as Border?;
      expect(border, isNotNull,
          reason: '🔴 le point de câblage ouvert par le socle n\'est pas '
              'consommé : l\'hôte devrait de nouveau envelopper la surface '
              'd\'un second conteneur (le montage manuel supprimé par CR-76).');
      expect(border!.top.color, Theme.of(context).dividerColor);
      // 🔬 Attendu ≠ ambiant : le rôle n'est ni transparent ni le fond.
      expect(Theme.of(context).dividerColor, isNot(const Color(0x00000000)));
      expect(border.top.color, isNot(deco.color));
      expect(
        deco.borderRadius,
        const BorderRadius.all(ZChatComposerReference.containerRadius),
      );
    });

    testWidgets(
        'MCR77-A2 — l\'hôte garde la main : une couleur explicite l\'emporte '
        'sur le rôle', (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      const Color mien = Color(0xFF10203F);
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(
            controller: c.controller,
            settings: settings,
            borderColor: mien,
          ),
        ),
      );
      final BuildContext context = tester.element(
        find.byType(ZChatMaterialComposer),
      );
      expect(mien, isNot(Theme.of(context).dividerColor),
          reason: '🔬 attendu == ambiant : la garde ne prouverait rien.');
      expect((decorationOf(tester).border! as Border).top.color, mien);
    });
  });

  group('🔴 MCR77-B — ④ le déclencheur de dictée, glyphe ET rôle', () {
    testWidgets('MCR77-B1 — absent sans geste d\'hôte (AD-4)',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        harness(
          ZChatMaterialComposer(controller: c.controller, settings: settings),
        ),
      );
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(ZChatComposerDictationTrigger), findsNothing);
    });

    testWidgets(
        'MCR77-B2 — au repos : le micro ; à l\'écoute : le glyphe d\'arrêt '
        'TEINTÉ du rôle `error` — et le geste reste celui de l\'hôte',
        (WidgetTester tester) async {
      final c = buildController();
      addTearDown(c.controller.dispose);
      final ZChatSettingsController settings = ZChatSettingsController();
      addTearDown(settings.dispose);
      final ValueNotifier<bool> listening = ValueNotifier<bool>(false);
      addTearDown(listening.dispose);
      int gestes = 0;
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.bottomStart,
            child: ZChatMaterialComposer(
              controller: c.controller,
              settings: settings,
              onDictate: () => gestes++,
              dictationListening: listening,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.mic), findsOneWidget);
      await tester.tap(find.byType(ZChatComposerDictationTrigger));
      await tester.pump();
      expect(gestes, 1,
          reason: '🔴 le satellite a intercepté le geste — le moteur de '
              'dictée reste un choix d\'application.');
      // 🔴 L'état est INJECTÉ : rien dans le socle ni dans le satellite ne
      // l'a fait basculer tout seul (le tap n'a PAS changé le glyphe).
      expect(find.byIcon(Icons.mic), findsOneWidget,
          reason: '🔴 le socle a déduit un état d\'écoute qu\'il ne peut pas '
              'connaître.');
      listening.value = true;
      await tester.pump();
      final BuildContext context = tester.element(
        find.byType(ZChatMaterialComposer),
      );
      final Icon stop = tester.widget<Icon>(
        find.descendant(
          of: find.byType(ZChatComposerDictationTrigger),
          matching: find.byType(Icon),
        ),
      );
      expect(stop.icon, Icons.stop,
          reason: '🔴 le glyphe ne change pas pendant l\'écoute.');
      expect(stop.color, Theme.of(context).colorScheme.error,
          reason: '🔴 le rôle ne change pas — et il doit être un RÔLE, jamais '
              'une teinte du satellite (MAT-L2).');
    });
  });
}
