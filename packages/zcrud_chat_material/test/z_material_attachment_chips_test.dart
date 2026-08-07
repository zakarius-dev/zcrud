/// Gardes des **chips de pièces jointes** — lot K3.
///
/// * **ATT-R1** — la rangée SUIT la tranche `pending` : vide ⇒ rien, deux
///   pièces ⇒ deux chips, et l'apparition est RÉACTIVE (même montée via le
///   builder de créneau, avant toute pièce) ;
/// * **ATT-W1** — presser une chip retire LA BONNE pièce (`remove(index)`,
///   voie unique) — presser la seconde ne retire pas la première ;
/// * **ATT-G1** — chaque chip rend ≥ 48 dp en GÉOMÉTRIE RENDUE : le
///   « retirer » de 20 dp de lex (`chat_input.dart:1032`) est INEXPRIMABLE
///   ici, la chip entière est la cible ;
/// * **ATT-P1** — le pixel lex : radius de chip = référence `chipRadius` (12).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

const Color _cursor = Color(0xFF123456);

void main() {
  testWidgets('ATT-R1 — vide ⇒ rien ; deux pièces ⇒ deux chips ; retrait '
      'suivi', (WidgetTester tester) async {
    final ZChatAttachmentController attachments = ZChatAttachmentController();
    addTearDown(attachments.dispose);
    await tester.pumpWidget(
      harness(ZChatMaterialAttachmentChips(attachments: attachments)),
    );
    expect(find.byType(InputChip), findsNothing);

    attachments.add(pendingPng('a.png'));
    attachments.add(pendingPng('b.png', withThumb: true));
    await tester.pump();
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('a.png'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);
  });

  testWidgets('ATT-R1b — monté par le BUILDER de créneau AVANT toute pièce, '
      'la rangée apparaît quand une pièce arrive', (WidgetTester tester) async {
    final rig = buildController();
    final ZChatAttachmentController attachments = ZChatAttachmentController();
    addTearDown(rig.controller.dispose);
    addTearDown(attachments.dispose);
    await tester.pumpWidget(
      harness(
        ZChatComposer(
          controller: rig.controller,
          cursorColor: _cursor,
          leading: zChatMaterialAttachmentChips(attachments),
        ),
      ),
    );
    expect(find.byType(InputChip), findsNothing);

    attachments.add(pendingPng('tard.png'));
    await tester.pump();
    expect(find.byType(InputChip), findsOneWidget,
        reason: '🔴 l\'absence a été FIGÉE au montage (builder rendant null '
            'sur `pending.value`) — le composer ne re-résout pas ses '
            'créneaux : la rangée doit être réactive de l\'intérieur');
  });

  testWidgets('🔴 ATT-W1 — presser la SECONDE chip retire la seconde pièce', (
    WidgetTester tester,
  ) async {
    final ZChatAttachmentController attachments = ZChatAttachmentController();
    addTearDown(attachments.dispose);
    attachments.add(pendingPng('garde.png'));
    attachments.add(pendingPng('retire.png'));
    await tester.pumpWidget(
      harness(ZChatMaterialAttachmentChips(attachments: attachments)),
    );

    await tester.tap(find.byType(InputChip).at(1));
    await tester.pump();
    expect(attachments.pending.value, hasLength(1),
        reason: '🔴 la pression ne retire pas');
    expect(attachments.pending.value.single.fileName, 'garde.png',
        reason: '🔴 mauvais index retiré — la fermeture capture le mauvais '
            '`i`');
    expect(find.text('garde.png'), findsOneWidget);
    expect(find.text('retire.png'), findsNothing);
  });

  testWidgets('🔴 ATT-G1 — chaque chip rend ≥ 48 dp (la cible de retrait '
      'est la chip ENTIÈRE — jamais les 20 dp de lex)', (
    WidgetTester tester,
  ) async {
    final ZChatAttachmentController attachments = ZChatAttachmentController();
    addTearDown(attachments.dispose);
    attachments.add(pendingPng('a.png'));
    attachments.add(pendingPng('b.png', withThumb: true));
    // 🔴 `shrinkWrap` : mesurer sous le thème par défaut mesurerait le
    // plancher AMBIANT du SDK, pas le NÔTRE (leçon I06, « attendu ≠
    // ambiant »).
    await tester.pumpWidget(
      harness(
        ZChatMaterialAttachmentChips(attachments: attachments),
        material: hostileTapTargets(),
      ),
    );
    for (int i = 0; i < 2; i++) {
      final Size size = tester.getSize(find.byType(InputChip).at(i));
      expect(size.height, greaterThanOrEqualTo(48),
          reason: '🔴 chip $i : ${size.height} dp — le défaut lex '
              '(cible < 48 dp) est de retour');
      expect(size.width, greaterThanOrEqualTo(48));
    }
  });

  testWidgets('ATT-P1 — radius de chip = référence lex (12)', (
    WidgetTester tester,
  ) async {
    final ZChatAttachmentController attachments = ZChatAttachmentController();
    addTearDown(attachments.dispose);
    attachments.add(pendingPng('a.png'));
    await tester.pumpWidget(
      harness(ZChatMaterialAttachmentChips(attachments: attachments)),
    );
    final InputChip chip = tester.widget<InputChip>(find.byType(InputChip));
    expect(
      (chip.shape as RoundedRectangleBorder?)?.borderRadius,
      const BorderRadius.all(ZChatComposerReference.chipRadius),
    );
  });
}
