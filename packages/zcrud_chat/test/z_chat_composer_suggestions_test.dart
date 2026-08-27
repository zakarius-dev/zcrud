/// L'AGRÉGAT DE PROPOSITIONS — ce que ce fichier mesure.
///
/// Le socle recevait déjà `ZChatSuggestionsEvent` et le rangeait dans la
/// tranche PAR REQUÊTE (`progress(requestId).suggestions`). Un composer n'a
/// pas de `requestId` : la donnée existait sans être lisible par le rendu.
/// L'agrégat par CONVERSATION est ce chaînon — et son danger propre est la
/// fuite d'une conversation vers la suivante.
///
/// * **SGA-I** — INERTIE : sans le moindre événement, l'agrégat est vide, en
///   ABSOLU (une liste de longueur nulle, pas « la même qu'avant »).
/// * **SGA-R** — RÉCEPTION : la livraison reçue atterrit dans l'agrégat, ET
///   dans la tranche par requête — les deux, jamais l'une au prix de l'autre.
/// * 🔴 **SGA-E** — ÉTANCHÉITÉ : une proposition adressée à une conversation
///   quittée n'apparaît PAS dans celle qui l'a remplacée.
/// * **SGA-S** — STABILITÉ : la tranche est la même instance d'un appel à
///   l'autre (un `ValueListenableBuilder` ne se ré-abonne jamais).
@TestOn('vm')
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';

/// Raccourci : l'événement de propositions.
ZResult<ZChatStreamEvent> suggest(List<String> contents) =>
    Right<ZFailure, ZChatStreamEvent>(
      ZChatSuggestionsEvent(
        suggestions: <ZChatSuggestion>[
          for (final String c in contents) ZChatSuggestion(id: c, content: c),
        ],
      ),
    );

/// Les textes de l'agrégat, dans l'ordre.
List<String> aggregate(ZChatController c) => <String>[
  for (final ZChatSuggestion s in c.suggestions.value) s.content,
];

void main() {
  group('🔴 SGA-I — INERTIE', () {
    test('sans aucun événement, l\'agrégat est VIDE (mesure absolue)', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);

      expect(
        rig.controller.suggestions.value,
        isEmpty,
        reason: '🔴 une conversation neuve porte déjà des propositions : '
            'l\'agrégat est alimenté par autre chose que le flux',
      );
    });
  });

  group('SGA-R — RÉCEPTION', () {
    test('la livraison atterrit dans l\'agrégat ET dans la tranche par '
        'requête', () async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'bonjour';
      final Future<ZResult<ZChatRequestToken>> sent = rig.controller.send();
      await pumpEventQueue();
      final String requestId = rig.port.calls.first.token.requestId;

      rig.port.last.add(suggest(<String>['et ensuite ?', 'résume']));
      await pumpEventQueue();

      expect(
        aggregate(rig.controller),
        <String>['et ensuite ?', 'résume'],
        reason: '🔴 la livraison reçue n\'est pas lisible par le rendu : '
            'l\'agrégat n\'est pas alimenté par `_apply`',
      );
      expect(
        rig.controller.progress(requestId).value.suggestions.length,
        2,
        reason: '🔴 la tranche PAR REQUÊTE a été perdue au profit de '
            'l\'agrégat : le lot devait ajouter une vue, pas en remplacer une',
      );

      rig.port.last.add(done());
      await rig.port.closeAll();
      await sent;
    });
  });

  group('🔴 SGA-E — ÉTANCHÉITÉ entre conversations', () {
    test('une proposition ADRESSÉE à la conversation quittée n\'apparaît pas '
        'dans la suivante', () async {
      final rig = buildController(conversationId: 'c-a');
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'question A';
      final Future<ZResult<ZChatRequestToken>> sent = rig.controller.send();
      await pumpEventQueue();

      // LA FENÊTRE réelle : le serveur pousse sa proposition à l'instant où
      // l'utilisateur bascule sur B. L'événement est déjà dans le canal —
      // il sera LIVRÉ après `attach`, avant que l'annulation du jeton ne
      // ferme le drain. C'est le seul ordonnancement où `_apply` s'exécute
      // pour une conversation qui n'est plus la courante ; le mesurer
      // ailleurs ferait une garde hors d'atteinte.
      rig.port.last.add(suggest(<String>['relance de A']));
      rig.controller.attach(conversationId: 'c-b');
      await pumpEventQueue();

      expect(
        aggregate(rig.controller),
        isEmpty,
        reason: '🔴 FUITE : la proposition d\'une conversation quittée '
            's\'affiche sous le champ d\'une autre',
      );

      await rig.port.closeAll();
      await sent;
    });

    test('le changement de conversation VIDE l\'agrégat déjà rempli',
        () async {
      final rig = buildController(conversationId: 'c-a');
      addTearDown(rig.controller.dispose);

      rig.controller.composer.text = 'question A';
      final Future<ZResult<ZChatRequestToken>> sent = rig.controller.send();
      await pumpEventQueue();
      rig.port.last.add(suggest(<String>['relance de A']));
      await pumpEventQueue();
      expect(aggregate(rig.controller), hasLength(1));

      rig.controller.attach(conversationId: 'c-b');
      await pumpEventQueue();

      expect(
        aggregate(rig.controller),
        isEmpty,
        reason: '🔴 l\'agrégat SURVIT au changement de conversation : les '
            'propositions de A restent affichées dans B',
      );

      await rig.port.closeAll();
      await sent;
    });
  });

  group('SGA-S — STABILITÉ de la tranche', () {
    test('la même instance d\'un appel à l\'autre', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);

      expect(
        identical(rig.controller.suggestions, rig.controller.suggestions),
        isTrue,
        reason: '🔴 la tranche est reconstruite à chaque lecture : tout '
            '`ValueListenableBuilder` se ré-abonnerait à chaque build (AD-2)',
      );
      expect(rig.controller.suggestions, isA<ValueListenable<List<ZChatSuggestion>>>());
    });
  });
}
