/// Gardes du **FAB d'envoi** — lot K3.
///
/// * **FAB-C1** — le disque rend la valeur du CHROME : un chrome différent ⇒
///   le rendu suit (la garde n'est pas vacante : le défaut « valeur recopiée »
///   la ferait rougir) ;
/// * **FAB-C2** — sans chrome ni scope, le disque rend la RÉFÉRENCE lex ;
/// * **FAB-G1** — cible ≥ 48 dp en GÉOMÉTRIE RENDUE (le précédent
///   `widthFactor` de ce dépôt : on mesure la boîte, jamais les contraintes) ;
/// * **FAB-S1** — le tap emprunte [ZChatComposerSlot.submit] : la requête part
///   par le port — AUCUN second site d'envoi ;
/// * **FAB-R1** — RTL : le glyphe `Icons.send` est MIROITÉ (le
///   `_DirectionalSendIcon` de lex, `chat_input.dart:1219-1231`).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

const Color _cursor = Color(0xFF123456);

Finder _disc() => find.descendant(
  of: find.byType(ZChatMaterialSendFab),
  matching: find.byWidgetPredicate(
    (Widget w) => w is Material && w.shape is CircleBorder,
  ),
);

Widget _composer(
  ZChatController controller, {
  ZChatComposerChrome? chrome,
  TextDirection direction = TextDirection.ltr,
}) => harness(
  ZChatComposer(
    controller: controller,
    cursorColor: _cursor,
    trailing: zChatMaterialSendFab(chrome: chrome),
  ),
  direction: direction,
);

void main() {
  testWidgets('FAB-C2 — sans chrome ni scope, le disque rend la RÉFÉRENCE '
      'lex (sendTargetSize)', (WidgetTester tester) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    await tester.pumpWidget(_composer(rig.controller));

    final Size disc = tester.getSize(_disc());
    expect(disc.width, ZChatComposerReference.sendTargetSize);
    expect(disc.height, ZChatComposerReference.sendTargetSize);
  });

  testWidgets('🔴 FAB-C1 — un chrome différent ⇒ le disque SUIT (jamais une '
      'valeur recopiée)', (WidgetTester tester) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    await tester.pumpWidget(
      _composer(
        rig.controller,
        chrome: const ZChatComposerChrome(sendTargetSize: 64),
      ),
    );

    final Size disc = tester.getSize(_disc());
    expect(disc.width, 64,
        reason: '🔴 le builder ignore le chrome — la dimension est recopiée '
            'quelque part au lieu de passer par `zChatComposerChromeOf`');
    expect(disc.height, 64);
  });

  testWidgets('FAB-G1 — cible ≥ 48 dp en géométrie RENDUE', (
    WidgetTester tester,
  ) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    await tester.pumpWidget(_composer(rig.controller));

    final Size target = tester.getSize(find.byType(ZChatComposerSendTarget));
    expect(target.width, greaterThanOrEqualTo(48));
    expect(target.height, greaterThanOrEqualTo(48),
        reason: '🔴 le défaut legacy (40 dp) est de retour');
  });

  testWidgets('🔴 FAB-S1 — le tap envoie par le port, via slot.submit', (
    WidgetTester tester,
  ) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    await tester.pumpWidget(_composer(rig.controller));

    await tester.enterText(find.byType(EditableText), 'bonjour');
    await tester.pump();
    expect(rig.port.calls, isEmpty);

    await tester.tap(find.byType(ZChatMaterialSendFab));
    await tester.pump();
    expect(rig.port.calls, hasLength(1),
        reason: '🔴 le tap du FAB n\'atteint pas `send()` — le glyphe a '
            'avalé le geste (un bouton Material avec son propre handler ?)');
    expect(rig.port.calls.single.subject, 'bonjour');
  });

  testWidgets('FAB-S1b — saisie vide : le tap est SANS effet (le refus reste '
      'celui de send)', (WidgetTester tester) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    await tester.pumpWidget(_composer(rig.controller));

    await tester.tap(find.byType(ZChatMaterialSendFab));
    await tester.pump();
    expect(rig.port.calls, isEmpty);
  });

  testWidgets('🔴 FAB-R1 — RTL : le glyphe est miroité ; LTR : il ne l\'est '
      'pas', (WidgetTester tester) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);

    // ⚠️ `AnimatedScale` (primitive K2) rend son propre `Transform` interne :
    // le miroir cherché est celui qui enveloppe DIRECTEMENT le glyphe.
    Finder flip() => find.descendant(
      of: find.byType(ZChatMaterialSendFab),
      matching: find.byWidgetPredicate(
        (Widget w) => w is Transform && w.child is Icon,
      ),
    );

    await tester.pumpWidget(_composer(rig.controller));
    expect(flip(), findsNothing);

    await tester.pumpWidget(
      _composer(rig.controller, direction: TextDirection.rtl),
    );
    expect(flip(), findsOneWidget,
        reason: '🔴 `Icons.send` n\'est pas auto-miroité : sous RTL la '
            'flèche pointe HORS du champ — le miroir lex a été perdu');
  });

  testWidgets('FAB-I1 — glyphe d\'hôte : le paramètre `icon` remplace '
      'Icons.send (AD-4)', (WidgetTester tester) async {
    final rig = buildController();
    addTearDown(rig.controller.dispose);
    const Key custom = Key('mon-glyphe');
    await tester.pumpWidget(
      harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          trailing: (BuildContext context, ZChatComposerSlot slot) =>
              ZChatMaterialSendFab(
                slot: slot,
                icon: const SizedBox(key: custom, width: 10, height: 10),
              ),
        ),
      ),
    );
    expect(find.byKey(custom), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ZChatMaterialSendFab),
        matching: find.byIcon(Icons.send),
      ),
      findsNothing,
    );
  });
}
