/// CR-IFFD-71 — **la preuve centrale de la CR** : l'axe « que fait-on du
/// résultat ».
///
/// Un hôte monte les CINQ capacités notebook du legacy IFFD sur
/// `ZChatNotebookView`, avec pour SEULES API : le créneau `actionsBuilder` et
/// `ZChatController.runAction(ZChatCustomAction(...))`.
///
/// | Capacité | Legacy IFFD (`chatbot_conversation_screen.dart`) |
/// |---|---|
/// | carte mentale        | L1677-1761, `!isChatSession` |
/// | flashcards           | L1764-1838, `!isChatSession` (pont métier : `zcrud_chat_study`, `zChatMessageGenerationRequest`) |
/// | variantes            | L1841-1901, `!isChatSession` |
/// | export (par message) | L4178-4222, notebook seul |
/// | enregistrer en note  | L4090-4118, `SmartNoteModel` — la 5ᵉ capacité, non relevée par la CR |
///
/// Ce que le test prouve, mesure à l'appui :
/// * chaque verbe atteint `ZChatActionExecutor.executeCustom` (l'implémentation
///   de l'hôte) avec sa charge utile — dont l'IDENTITÉ DU MESSAGE, la
///   granularité que 4 des 5 capacités exigent ;
/// * AUCUNE autre API n'est sollicitée : pas de nouveau membre de contrôleur
///   (G-CH1), pas de second chemin d'exécution (G-U1/G-CH2 restent vertes sur
///   ce même paquet), aucune écriture kernel ;
/// * un verbe NON destructif ne déclenche aucune confirmation (le contrat du
///   répartiteur s'applique aux verbes d'hôte comme aux verbes scellés) ;
/// * AD-13 : chacune des cinq cibles mesure ≥ 48×48 dp UNE FOIS RENDUE.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Les cinq verbes de l'hôte — le socle ne les connaît pas, et c'est le point.
const List<String> kVerbs = <String>[
  'iffd.generateMindmap',
  'iffd.generateFlashcards',
  'iffd.proposeVariant',
  'iffd.exportMessage',
  'iffd.saveAsNote',
];

/// Exécuteur d'hôte : le SpyExecutor PARTAGÉ, enrichi de l'enregistrement des
/// actions custom REÇUES (verbe + charge utile) — jamais recopié.
class RecordingExecutor extends SpyExecutor {
  /// Les actions custom reçues, dans l'ordre.
  final List<ZChatCustomAction> received = <ZChatCustomAction>[];

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) {
    received.add(action);
    return super.executeCustom(action);
  }
}

void main() {
  testWidgets('CR71-C1 — les 5 capacités notebook se composent par le créneau '
      'd\'actions + ZChatCustomAction, SANS AUTRE API', (
    WidgetTester tester,
  ) async {
    final RecordingExecutor executor = RecordingExecutor();
    int confirmations = 0;
    final ZChatController controller = ZChatController(
      streamPort: FakeStreamPort(),
      actionExecutor: executor,
      confirm: (ZChatActionPlan plan) async {
        confirmations++;
        return true;
      },
      newRequestId: SeqIds().next,
      buildRequest: (ZChatDraft draft) => ZChatGenerationRequest(
        style: ZChatGenerationStyle('test'),
        subject: draft.text,
        attachmentIds: draft.attachmentIds,
      ),
      initialMessages: <ZChatMessage>[
        assistant(<ZContentBlock>[
          const ZTextBlock(text: 'reponse notebook'),
        ], id: 'm0'),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      harness(
        ZChatNotebookView(
          controller: controller,
          actionsBuilder: (BuildContext context, ZChatMessage m) => Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final String verb in kVerbs)
                Semantics(
                  button: true,
                  label: verb,
                  child: GestureDetector(
                    key: ValueKey<String>('cap-$verb'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => unawaited(
                      // 🔴 L'UNIQUE chemin d'exécution : `runAction`. Les
                      // membres d'effet ne sont JAMAIS joints d'ici (G-U1).
                      controller.runAction(
                        ZChatCustomAction(
                          verb: verb,
                          isDestructive: false,
                          cascades: false,
                          payload: <String, dynamic>{'message_id': m.id},
                        ),
                      ),
                    ),
                    child: const SizedBox(width: 48, height: 48),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // AD-13 — GÉOMÉTRIE rendue de chaque cible (jamais les contraintes).
    for (final String verb in kVerbs) {
      final Size size = tester.getSize(
        find.byKey(ValueKey<String>('cap-$verb')),
      );
      expect(
        size.width,
        greaterThanOrEqualTo(48.0),
        reason: '🔴 cible `$verb` comprimée sous 48 dp',
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    }

    // Les cinq gestes, l'un après l'autre.
    for (final String verb in kVerbs) {
      await tester.tap(find.byKey(ValueKey<String>('cap-$verb')));
      await tester.pumpAndSettle();
    }

    // Chaque verbe a atteint l'exécuteur de l'HÔTE — via le répartiteur
    // unique, donc `estimateImpact` a été appelé pour chacun.
    expect(
      executor.received.map((ZChatCustomAction a) => a.verb).toList(),
      kVerbs,
      reason:
          '🔴 un verbe n\'a pas atteint `executeCustom` : la capacité '
          'est un bouton MORT (le défaut « Copier » d\'IFFD)',
    );
    for (final ZChatCustomAction a in executor.received) {
      expect(
        a.payload['message_id'],
        'm0',
        reason:
            '🔴 la charge utile ne porte pas l\'identité du message : '
            '4 des 5 capacités du legacy sont PAR MESSAGE — sans elle, '
            'l\'hôte ne sait pas de quel contenu générer',
      );
    }
    expect(executor.calls['executeCustom'], kVerbs.length);
    expect(
      executor.calls['estimateImpact'],
      kVerbs.length,
      reason:
          '🔴 un verbe a court-circuité `prepare` : le chemin ne passe '
          'plus par le répartiteur',
    );
    expect(
      confirmations,
      0,
      reason:
          '🔴 une confirmation a été demandée pour un verbe NON '
          'destructif — le contrat du plan ne s\'applique plus aux verbes '
          'd\'hôte',
    );
    // …et rien d'autre n'a été exécuté : aucun verbe scellé, aucun effet
    // parasite.
    expect(executor.effectCount, kVerbs.length);
  });

  testWidgets(
    'CR71-C2 — contre-preuve : un verbe custom DESTRUCTIF passe, lui, par la '
    'confirmation — et un refus laisse l\'exécuteur à zéro',
    (WidgetTester tester) async {
      final RecordingExecutor executor = RecordingExecutor();
      final List<ZChatActionPlan> asked = <ZChatActionPlan>[];
      final ZChatController controller = ZChatController(
        streamPort: FakeStreamPort(),
        actionExecutor: executor,
        confirm: (ZChatActionPlan plan) async {
          asked.add(plan);
          return false; // refus
        },
        newRequestId: SeqIds().next,
        buildRequest: (ZChatDraft draft) => ZChatGenerationRequest(
          style: ZChatGenerationStyle('test'),
          subject: draft.text,
          attachmentIds: draft.attachmentIds,
        ),
      );
      addTearDown(controller.dispose);

      final ZResult<ZChatActionOutcome> outcome = await controller.runAction(
        const ZChatCustomAction(
          verb: 'iffd.purgeNotes',
          isDestructive: true,
          cascades: true,
          payload: <String, dynamic>{'message_id': 'm0'},
        ),
      );

      expect(
        asked,
        hasLength(1),
        reason:
            '🔴 un verbe destructif d\'hôte n\'a PAS demandé '
            'confirmation',
      );
      expect(
        outcome.isLeft(),
        isTrue,
        reason: '🔴 le refus doit rendre un échec typé, jamais exécuter',
      );
      expect(
        executor.received,
        isEmpty,
        reason:
            '🔴 EXÉCUTION MALGRÉ LE REFUS : la confirmation ne précède '
            'plus l\'effet',
      );
      expect(executor.effectCount, 0);
    },
  );
}
