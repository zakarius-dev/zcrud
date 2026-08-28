/// CR-IFFD-124 (correctif d'activation) — le mode d'activation d'un artefact
/// à verbe unique est déclaré PAR SPEC, et le défaut est le MENU.
///
/// * **B1** — sans mode déclaré, un verbe unique ouvre le **menu à un
///   élément** : rien ne part au tap, l'arbre du menu est mesuré, le verbe
///   part au second geste. L'entrée est annoncée dépliable.
/// * **B2** — `confirm` : la question précède toute exécution ; annuler
///   n'exécute rien ; confirmer exécute ; le message et les libellés de
///   l'hôte sont rendus ; sans message, le libellé localisé du socle l'est.
/// * **B3** — `confirm` + couture d'hôte : la couture décide, une seule fois.
/// * **B4** — un verbe DESTRUCTEUR en `confirm` ne reçoit qu'UNE question —
///   la destructrice — jamais deux empilées.
/// * **B5** — granularité et inertie : un spec à PLUSIEURS verbes visibles
///   ignore `direct` (le menu s'ouvre, rien ne part) ; le voisin de rangée
///   garde son propre mode.
/// * **B6** — relais déclaratif : `ZChatArtifactDeclaration.activation` et
///   `activationPromptToken` traversent `zChatArtifactSpecOf`.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const IconData _iconA = IconData(0xE930);
const IconData _iconB = IconData(0xE931);

String _fb(String key) => kZChatLabelFallbacks[key]!;

Widget _slotHarness({
  required List<ZChatArtifactSpec> artifacts,
  ZChatArtifactConfirm? confirm,
}) {
  final ZChatMessageSlotBuilder slot = ZChatArtifactBar.slot(
    artifacts: artifacts,
    confirm: confirm,
  );
  return harness(
    Builder(
      builder: (BuildContext context) =>
          slot(context, assistant(const <ZContentBlock>[])) ??
          const SizedBox.shrink(),
    ),
  );
}

ZChatArtifactSpec _soleVerb({
  required void Function() onSelected,
  ZChatArtifactActivation activation = ZChatArtifactActivation.menu,
  String? activationPrompt,
  String? activationConfirmLabel,
  String? activationCancelLabel,
}) => ZChatArtifactSpec(
  key: 'k',
  label: 'Carte mentale',
  icon: _iconA,
  presence: (ZChatMessage _) => true,
  activation: activation,
  activationPrompt: activationPrompt,
  activationConfirmLabel: activationConfirmLabel,
  activationCancelLabel: activationCancelLabel,
  actions: <ZChatArtifactAction>[
    ZChatArtifactAction.open(onSelected: (ZChatMessage _) => onSelected()),
  ],
);

void main() {
  group('CR124B-B1 — le DÉFAUT est le menu, même à un seul verbe', () {
    testWidgets('sans mode : tap ⇒ AUCUNE exécution, le menu à UN élément '
        'est dans l\'arbre ; le second geste exécute', (
      WidgetTester tester,
    ) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            _soleVerb(onSelected: () => invoked++),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(
        invoked,
        0,
        reason:
            '🔴 le verbe unique est parti au tap SANS opt-in : le défaut '
            'est redevenu l\'exécution directe',
      );
      // L'arbre du MENU est mesuré — pas la seule absence d'exécution : le
      // libellé du verbe est rendu, dans le portail, comme entrée de menu.
      expect(
        find.text(_fb(kZChatLabelArtifactOpen)),
        findsOneWidget,
        reason:
            '🔴 aucun menu à un élément : le comportement historique du '
            'défaut n\'est pas restitué',
      );
      await tester.tap(find.text(_fb(kZChatLabelArtifactOpen)));
      await tester.pump();
      expect(invoked, 1, reason: '🔴 le second geste n\'exécute pas le verbe');
      expect(find.text(_fb(kZChatLabelArtifactOpen)), findsNothing);
    });

    testWidgets('sans mode : l\'entrée est annoncée DÉPLIABLE — un menu, pas '
        'un bouton qui agit', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[_soleVerb(onSelected: () {})],
        ),
      );
      final SemanticsNode? node = findSemantics(
        tester,
        (SemanticsNode n) => n.label == 'Carte mentale',
      );
      expect(node, isNotNull);
      expect(
        node!.flagsCollection.isExpanded,
        isNot(Tristate.none),
        reason:
            '🔴 sans opt-in, l\'entrée doit se présenter comme un menu '
            'dépliable — l\'annonce « bouton simple » promet une '
            'exécution au tap que le défaut ne fait plus',
      );
      handle.dispose();
    });
  });

  group('CR124B-B2 — `confirm` : la question PRÉCÈDE l\'exécution', () {
    testWidgets('tap ⇒ question, rien ne part ; annuler ⇒ RIEN ; '
        'confirmer ⇒ exécution', (WidgetTester tester) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            _soleVerb(
              onSelected: () => invoked++,
              activation: ZChatArtifactActivation.confirm,
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(
        invoked,
        0,
        reason: '🔴 le verbe est parti AVANT la question du mode `confirm`',
      );
      // Sans message d'hôte : la question LOCALISÉE du socle.
      expect(
        find.text(_fb(kZChatLabelArtifactActivatePrompt)),
        findsOneWidget,
        reason: '🔴 aucune question rendue : le cycle de confirmation manque',
      );
      // Annuler : ASSERTION D'ABSENCE d'appel.
      await tester.tap(find.text(_fb(kZChatLabelArtifactCancel)));
      await tester.pump();
      expect(
        invoked,
        0,
        reason: '🔴 annuler a exécuté le verbe — la question ne décide rien',
      );
      expect(find.text(_fb(kZChatLabelArtifactActivatePrompt)), findsNothing);
      // Rejouer, confirmer : l'exécution part, une fois.
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      await tester.tap(find.text(_fb(kZChatLabelArtifactConfirm)));
      await tester.pump();
      expect(invoked, 1);
      expect(find.text(_fb(kZChatLabelArtifactActivatePrompt)), findsNothing);
    });

    testWidgets('message et libellés de l\'HÔTE rendus tels quels', (
      WidgetTester tester,
    ) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            _soleVerb(
              onSelected: () => invoked++,
              activation: ZChatArtifactActivation.confirm,
              activationPrompt: 'Générer la carte mentale ? (coûteux)',
              activationConfirmLabel: 'Lancer',
              activationCancelLabel: 'Pas maintenant',
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(find.text('Générer la carte mentale ? (coûteux)'), findsOneWidget);
      // Les libellés de l'hôte REMPLACENT ceux du socle — pas de doublon.
      expect(find.text(_fb(kZChatLabelArtifactConfirm)), findsNothing);
      expect(find.text(_fb(kZChatLabelArtifactCancel)), findsNothing);
      await tester.tap(find.text('Pas maintenant'));
      await tester.pump();
      expect(invoked, 0);
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      await tester.tap(find.text('Lancer'));
      await tester.pump();
      expect(invoked, 1);
    });
  });

  group('CR124B-B3 — `confirm` : la couture d\'hôte DÉCIDE', () {
    testWidgets('la couture reçoit la demande ; `false` ⇒ rien ; `true` ⇒ '
        'exécution', (WidgetTester tester) async {
      int invoked = 0;
      bool answer = false;
      final List<ZChatArtifactConfirmRequest> asked =
          <ZChatArtifactConfirmRequest>[];
      await tester.pumpWidget(
        _slotHarness(
          confirm: (BuildContext context, ZChatArtifactConfirmRequest r) async {
            asked.add(r);
            return answer;
          },
          artifacts: <ZChatArtifactSpec>[
            _soleVerb(
              onSelected: () => invoked++,
              activation: ZChatArtifactActivation.confirm,
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pumpAndSettle();
      expect(asked, hasLength(1));
      expect(asked.single.artifact.key, 'k');
      expect(invoked, 0, reason: '🔴 le refus de la couture n\'a rien refusé');
      answer = true;
      await tester.tap(find.byIcon(_iconA));
      await tester.pumpAndSettle();
      expect(invoked, 1);
      expect(asked, hasLength(2));
    });
  });

  group('CR124B-B4 — destructeur en `confirm` : UNE seule question', () {
    testWidgets('la question DESTRUCTRICE est posée, la question '
        'd\'activation ne s\'empile pas ; une confirmation suffit', (
      WidgetTester tester,
    ) async {
      int deleted = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'k',
              label: 'Résumé',
              icon: _iconA,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.confirm,
              activationPrompt:
                  'Question d\'activation — ne doit PAS '
                  's\'afficher pour un destructeur',
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.delete(
                  onSelected: (ZChatMessage _) => deleted++,
                  confirmMessage: 'Supprimer le résumé ?',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(deleted, 0);
      expect(find.text('Supprimer le résumé ?'), findsOneWidget);
      expect(
        find.textContaining('Question d\'activation'),
        findsNothing,
        reason:
            '🔴 la question d\'activation s\'est empilée sur la question '
            'destructrice',
      );
      // UNE confirmation exécute — aucune seconde question n'apparaît.
      await tester.tap(find.text(_fb(kZChatLabelArtifactConfirm)));
      await tester.pump();
      expect(
        deleted,
        1,
        reason:
            '🔴 une confirmation n\'a pas suffi : une seconde question '
            's\'est interposée',
      );
      expect(find.textContaining('Question d\'activation'), findsNothing);
    });

    testWidgets('un rappel qui confirme EN AVAL (`confirmsDownstream`) part '
        'comme en `direct` — aucune question du socle', (
      WidgetTester tester,
    ) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'k',
              label: 'Résumé',
              icon: _iconA,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.confirm,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction(
                  labelKey: kZChatLabelArtifactDelete,
                  confirmsDownstream: true,
                  onSelected: (ZChatMessage _) => invoked++,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(
        invoked,
        1,
        reason:
            '🔴 la question du socle s\'est superposée à celle que le '
            'rappel pose déjà en aval',
      );
      expect(find.text(_fb(kZChatLabelArtifactActivatePrompt)), findsNothing);
    });
  });

  group('CR124B-B5 — granularité et inertie', () {
    testWidgets('PLUSIEURS verbes visibles ⇒ `direct` est sans effet : le '
        'menu s\'ouvre, rien ne part', (WidgetTester tester) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'k',
              label: 'Carte mentale',
              icon: _iconA,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.direct,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.open(
                  onSelected: (ZChatMessage _) => invoked++,
                ),
                ZChatArtifactAction.regenerate(
                  onSelected: (ZChatMessage _) => invoked++,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(
        invoked,
        0,
        reason:
            '🔴 `direct` a exécuté au tap alors que DEUX verbes étaient '
            'visibles : le mode a débordé de sa granularité',
      );
      expect(find.text(_fb(kZChatLabelArtifactOpen)), findsOneWidget);
      expect(find.text(_fb(kZChatLabelArtifactRegenerate)), findsOneWidget);
    });

    testWidgets('le mode est PAR ITEM : `direct` sur l\'un ne change rien au '
        'voisin resté au défaut', (WidgetTester tester) async {
      int direct = 0;
      int voisin = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'a',
              label: 'Commande',
              icon: _iconA,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.direct,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.open(
                  onSelected: (ZChatMessage _) => direct++,
                ),
              ],
            ),
            ZChatArtifactSpec(
              key: 'b',
              label: 'Flashcards',
              icon: _iconB,
              presence: (ZChatMessage _) => true,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.regenerate(
                  onSelected: (ZChatMessage _) => voisin++,
                ),
              ],
            ),
          ],
        ),
      );
      // L'item `direct` exécute au tap.
      await tester.tap(find.byIcon(_iconA));
      await tester.pump();
      expect(direct, 1);
      expect(voisin, 0);
      // Le voisin au DÉFAUT ouvre son menu — le mode du premier n'a pas
      // déteint sur la rangée.
      await tester.tap(find.byIcon(_iconB));
      await tester.pump();
      expect(
        voisin,
        0,
        reason: '🔴 le mode `direct` du voisin a déteint sur l\'item au défaut',
      );
      expect(find.text(_fb(kZChatLabelArtifactRegenerate)), findsOneWidget);
    });
  });

  group('CR124B-B6 — relais DÉCLARATIF (kernel → spec)', () {
    test(
      '`activation` et `activationPromptToken` traversent la dérivation',
      () async {
        final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
        addTearDown(transcript.dispose);
        ZChatNotebookController nbOf(ZChatArtifactDeclaration d) {
          final ZChatNotebookController nb = ZChatNotebookController(
            streamPort: FakeStreamPort(),
            transcript: transcript,
            conversationId: 'c1',
            registry: ZChatArtifactRegistry(<ZChatArtifactDeclaration>[d]),
          );
          addTearDown(nb.dispose);
          return nb;
        }

        final ZChatNotebookController nb = nbOf(
          ZChatArtifactDeclaration(
            key: 'mindmap',
            labelToken: 'lbl.mindmap',
            activation: ZChatArtifactActivation.confirm,
            activationPromptToken: 'prompt.mindmap',
            verbs: <ZChatArtifactVerb>[ZChatArtifactVerb.create()],
          ),
        );
        final ZChatArtifactSpec spec = zChatArtifactSpecOf(
          nb.registry.declarations.single,
          controller: nb,
          resolvers: ZChatArtifactResolvers(
            label: (String token) => switch (token) {
              'lbl.mindmap' => 'Carte mentale',
              'prompt.mindmap' => 'Générer la carte ?',
              _ => null,
            },
          ),
        );
        expect(spec.activation, ZChatArtifactActivation.confirm);
        expect(spec.activationPrompt, 'Générer la carte ?');
        // Témoin d'inertie : sans déclaration, le défaut relayé est le menu et
        // aucun message n'est inventé.
        final ZChatNotebookController plainNb = nbOf(
          ZChatArtifactDeclaration(key: 'plain'),
        );
        final ZChatArtifactSpec plain = zChatArtifactSpecOf(
          plainNb.registry.declarations.single,
          controller: plainNb,
        );
        expect(plain.activation, ZChatArtifactActivation.menu);
        expect(plain.activationPrompt, isNull);
      },
    );
  });
}
