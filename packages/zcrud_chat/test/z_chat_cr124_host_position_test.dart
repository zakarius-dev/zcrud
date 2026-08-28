/// CR-IFFD-124 — la grille unique du legacy : position du créneau hôte et
/// verbe unique exécuté au clic, RÉ-ANCRÉ sur le contrat corrigé : le clic
/// direct est un OPT-IN (`ZChatArtifactActivation.direct`), le défaut est le
/// menu (cf. z_chat_cr124b_activation_test.dart pour le défaut et `confirm`).
///
/// * **P1 (voie ②)** — un artefact à verbe UNIQUE en activation `direct`
///   s'exécute au clic : le rappel part au premier tap, aucun menu ne
///   s'ouvre. Deux verbes ⇒ le menu s'ouvre comme avant (contre-témoin
///   d'inertie de la voie).
/// * **P2 (voie ② / AD-13)** — l'entrée `direct` à verbe unique est annoncée
///   comme un BOUTON, jamais comme un menu dépliable ; l'annonce d'état de
///   l'artefact ne change pas ; la cible reste ≥ 48 dp.
/// * **P3 (voie ②)** — un verbe unique DESTRUCTEUR en `direct` garde sa
///   confirmation : le tap ouvre la question en place, l'effet ne part
///   qu'après « confirmer », « annuler » ne déclenche rien.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

const IconData _iconEdit = IconData(0xE910);
const IconData _iconMap = IconData(0xE911);

String _fb(String key) => kZChatLabelFallbacks[key]!;

/// Monte le créneau assemblé par [ZChatArtifactBar.slot] sur un message
/// d'assistant — le point d'entrée exact d'un hôte resté sur les briques.
Widget _slotHarness({
  required List<ZChatArtifactSpec> artifacts,
  ZChatMessageSlotBuilder? host,
}) {
  final ZChatMessageSlotBuilder slot = ZChatArtifactBar.slot(
    artifacts: artifacts,
    host: host,
  );
  return harness(
    Builder(
      builder: (BuildContext context) =>
          slot(context, assistant(const <ZContentBlock>[])) ??
          const SizedBox.shrink(),
    ),
  );
}

void main() {
  group('CR124-P1 — un verbe UNIQUE en `direct` s\'exécute au clic', () {
    testWidgets('un seul verbe ⇒ le tap invoque le rappel, AUCUN menu', (
      WidgetTester tester,
    ) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'edit',
              label: 'Éditer',
              icon: _iconEdit,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.direct,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.edit(
                  onSelected: (ZChatMessage _) => invoked++,
                ),
              ],
            ),
          ],
        ),
      );
      expect(find.byIcon(_iconEdit), findsOneWidget);
      await tester.tap(find.byIcon(_iconEdit));
      await tester.pump();
      expect(
        invoked,
        1,
        reason: '🔴 le verbe unique n\'est pas parti au premier tap',
      );
      // Aucun menu : le libellé du verbe n'est rendu NULLE PART — ni grille,
      // ni colonne, ni menu à un élément.
      expect(
        find.text(_fb(kZChatLabelArtifactEdit)),
        findsNothing,
        reason: '🔴 un menu à un seul élément s\'est ouvert malgré tout',
      );
      // Et un second tap réinvoque le verbe — le premier n\'a pas laissé un
      // portail armé qui absorberait le geste suivant.
      await tester.tap(find.byIcon(_iconEdit));
      await tester.pump();
      expect(invoked, 2);
    });

    testWidgets('contre-témoin : DEUX verbes ⇒ le menu s\'ouvre, rien ne '
        'part au tap', (WidgetTester tester) async {
      int invoked = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'mindmap',
              label: 'Carte mentale',
              icon: _iconMap,
              presence: (ZChatMessage _) => true,
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
      await tester.tap(find.byIcon(_iconMap));
      await tester.pump();
      expect(
        invoked,
        0,
        reason: '🔴 un verbe est parti sans passer par le menu à deux verbes',
      );
      expect(find.text(_fb(kZChatLabelArtifactOpen)), findsOneWidget);
      expect(find.text(_fb(kZChatLabelArtifactRegenerate)), findsOneWidget);
    });
  });

  group('CR124-P2 — l\'entrée `direct` à verbe unique est un BOUTON, pas un menu '
      '(AD-13)', () {
    testWidgets('annonce : bouton SANS état dépliable, état d\'artefact '
        'inchangé, cible ≥ 48 dp', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'edit',
              label: 'Éditer',
              icon: _iconEdit,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.direct,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.edit(onSelected: (ZChatMessage _) {}),
              ],
            ),
            ZChatArtifactSpec(
              key: 'mindmap',
              label: 'Carte mentale',
              icon: _iconMap,
              presence: (ZChatMessage _) => true,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.open(onSelected: (ZChatMessage _) {}),
                ZChatArtifactAction.delete(onSelected: (ZChatMessage _) {}),
              ],
            ),
          ],
        ),
      );
      final SemanticsNode? sole = findSemantics(
        tester,
        (SemanticsNode n) => n.label == 'Éditer',
      );
      expect(sole, isNotNull);
      expect(sole!.flagsCollection.isButton, isTrue);
      // `Tristate.none` = AUCUN état dépliable annoncé — c'est la différence
      // entre un bouton qui agit et un bouton qui ouvre.
      expect(
        sole.flagsCollection.isExpanded,
        Tristate.none,
        reason:
            '🔴 un verbe unique annoncé « réduit/déplié » se présente comme '
            'un menu — le lecteur d\'écran promet un second geste qui '
            'n\'existe pas',
      );
      // L'annonce d'état de l'artefact ne change pas.
      expect(sole.value, contains(_fb(kZChatLabelGenerated)));
      // Contre-témoin dans le MÊME arbre : l'entrée à deux verbes garde son
      // état dépliable — la garde ci-dessus ne mesure pas un drapeau que
      // plus personne ne porterait.
      final SemanticsNode? menu = findSemantics(
        tester,
        (SemanticsNode n) => n.label == 'Carte mentale',
      );
      expect(menu, isNotNull);
      expect(menu!.flagsCollection.isExpanded, isNot(Tristate.none));
      // Cible tactile inchangée.
      final Size size = tester.getSize(
        find.ancestor(
          of: find.byIcon(_iconEdit),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(size.width, greaterThanOrEqualTo(48.0));
      expect(size.height, greaterThanOrEqualTo(48.0));
      handle.dispose();
    });
  });

  group('CR124-P3 — verbe unique DESTRUCTEUR en `direct` : la confirmation précède '
      'l\'effet', () {
    testWidgets('tap ⇒ question en place ; « confirmer » déclenche ; '
        '« annuler » ne déclenche rien', (WidgetTester tester) async {
      int deleted = 0;
      await tester.pumpWidget(
        _slotHarness(
          artifacts: <ZChatArtifactSpec>[
            ZChatArtifactSpec(
              key: 'summary',
              label: 'Résumé',
              icon: _iconEdit,
              presence: (ZChatMessage _) => true,
              activation: ZChatArtifactActivation.direct,
              actions: <ZChatArtifactAction>[
                ZChatArtifactAction.delete(
                  onSelected: (ZChatMessage _) => deleted++,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.tap(find.byIcon(_iconEdit));
      await tester.pump();
      expect(
        deleted,
        0,
        reason: '🔴 l\'effet destructeur est parti SANS question',
      );
      expect(
        find.text(_fb(kZChatLabelArtifactConfirmPrompt)),
        findsOneWidget,
        reason: '🔴 aucun endroit où confirmer : le verbe est inatteignable',
      );
      // Annuler : rien ne part, la question se ferme.
      await tester.tap(find.text(_fb(kZChatLabelArtifactCancel)));
      await tester.pump();
      expect(deleted, 0);
      expect(find.text(_fb(kZChatLabelArtifactConfirmPrompt)), findsNothing);
      // Rejouer, et confirmer cette fois.
      await tester.tap(find.byIcon(_iconEdit));
      await tester.pump();
      await tester.tap(find.text(_fb(kZChatLabelArtifactConfirm)));
      await tester.pump();
      expect(deleted, 1);
      expect(find.text(_fb(kZChatLabelArtifactConfirmPrompt)), findsNothing);
    });
  });

  group('CR124-P4 — la position du créneau hôte rend ce qu\'elle promet', () {
    const Key hostKey = Key('host-actions');
    Widget hostChip(BuildContext context, ZChatMessage message) =>
        const SizedBox(key: hostKey, width: 48, height: 48);
    const List<IconData> icons = <IconData>[
      IconData(0xE920), IconData(0xE921), IconData(0xE922),
      IconData(0xE923), IconData(0xE924), IconData(0xE925),
      IconData(0xE926), IconData(0xE927), IconData(0xE928),
    ];
    List<ZChatArtifactSpec> nine() => <ZChatArtifactSpec>[
      for (int i = 0; i < 9; i++)
        ZChatArtifactSpec(
          key: 'a$i',
          label: 'artefact $i',
          icon: icons[i],
          presence: (ZChatMessage _) => true,
        ),
    ];

    Widget pump({required ZChatArtifactHostPosition position}) {
      final ZChatMessageSlotBuilder slot = ZChatArtifactBar.slot(
        artifacts: nine(),
        host: hostChip,
        hostPosition: position,
      );
      return harness(
        Builder(
          builder: (BuildContext context) =>
              slot(context, assistant(const <ZContentBlock>[]))!,
        ),
      );
    }

    testWidgets('INERTIE (défaut, en absolu) : `above` ⇒ Column([own, bar]), '
        'l\'hôte HORS du Wrap, au-dessus', (WidgetTester tester) async {
      await tester.pumpWidget(
        pump(position: ZChatArtifactHostPosition.above),
      );
      // La composition historique, mesurée en ABSOLU : une Column dont le
      // premier enfant est le créneau hôte et le second la rangée.
      final Column column = tester.widget<Column>(
        find.ancestor(
          of: find.byType(ZChatArtifactBar),
          matching: find.byType(Column),
        ).first,
      );
      expect(column.children, hasLength(2));
      expect((column.children.first as SizedBox).key, hostKey);
      expect(column.children.last, isA<ZChatArtifactBar>());
      expect(
        find.descendant(of: find.byType(Wrap), matching: find.byKey(hostKey)),
        findsNothing,
        reason: '🔴 l\'hôte est entré dans la grille sans l\'avoir déclaré',
      );
      // Et l'hôte est bien AU-DESSUS.
      expect(
        tester.getBottomLeft(find.byKey(hostKey)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(Wrap)).dy),
      );
    });

    testWidgets('`below` ⇒ l\'hôte SOUS la rangée, toujours hors du Wrap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        pump(position: ZChatArtifactHostPosition.below),
      );
      expect(
        find.descendant(of: find.byType(Wrap), matching: find.byKey(hostKey)),
        findsNothing,
      );
      expect(
        tester.getTopLeft(find.byKey(hostKey)).dy,
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(Wrap)).dy),
        reason: '🔴 `below` n\'a pas déplacé le créneau sous la rangée',
      );
    });

    testWidgets('`inline` ⇒ l\'hôte DANS le Wrap, après le dernier glyphe, '
        'soumis au même repli au viewport étroit', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(240, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        pump(position: ZChatArtifactHostPosition.inline),
      );
      // Une SEULE grille : l'hôte est un enfant du même Wrap, pas d'une
      // seconde rangée ni d'une Column de composition.
      expect(find.byType(Wrap), findsOneWidget);
      expect(
        find.descendant(of: find.byType(Wrap), matching: find.byKey(hostKey)),
        findsOneWidget,
        reason: '🔴 `inline` n\'a pas fait entrer l\'hôte dans la grille',
      );
      expect(
        find.ancestor(
          of: find.byType(ZChatArtifactBar),
          matching: find.byType(Column),
        ),
        findsNothing,
        reason: '🔴 une composition verticale subsiste en mode grille unique',
      );
      // Même repli que les glyphes : à 240 dp, le contenu hôte reste DANS le
      // viewport, ≥ 48 dp, sans recouvrir le dernier glyphe — et il vient
      // APRÈS lui dans l'ordre de lecture de la grille.
      final Rect own = tester.getRect(find.byKey(hostKey));
      expect(own.left, greaterThanOrEqualTo(0.0));
      expect(
        own.right,
        lessThanOrEqualTo(240.0),
        reason: '🔴 le contenu hôte déborde du viewport : le repli du Wrap '
            'ne s\'applique pas à lui',
      );
      expect(own.width, greaterThanOrEqualTo(48.0));
      expect(own.height, greaterThanOrEqualTo(48.0));
      // Le rectangle mesuré est la CIBLE du dernier glyphe (sa boîte 48 dp),
      // pas l'icône centrée dedans — comparer une icône de 24 dp au chip de
      // 48 dp fausserait la comparaison de rangée.
      final Rect last = tester.getRect(
        find.ancestor(
          of: find.byIcon(const IconData(0xE928)),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(own.overlaps(last), isFalse);
      expect(
        own.top >= last.top,
        isTrue,
        reason: '🔴 l\'hôte est passé AVANT le dernier artefact',
      );
    });
  });

  group('CR124-P5 — le relais `ZChatNotebookView.artifactHostPosition`', () {
    testWidgets('`inline` déclaré sur la surface notebook ⇒ le créneau de '
        '`actionsBuilder` entre dans le Wrap', (WidgetTester tester) async {
      const Key hostKey = Key('notebook-host');
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')]),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            actionsBuilder: (BuildContext context, ZChatMessage message) =>
                const SizedBox(key: hostKey, width: 48, height: 48),
            artifactHostPosition: ZChatArtifactHostPosition.inline,
            artifacts: <ZChatArtifactSpec>[
              ZChatArtifactSpec(
                key: 'mindmap',
                label: 'Carte mentale',
                icon: _iconMap,
                presence: (ZChatMessage _) => true,
              ),
            ],
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.descendant(
            of: find.byType(ZChatArtifactBar),
            matching: find.byType(Wrap),
          ),
          matching: find.byKey(hostKey),
        ),
        findsOneWidget,
        reason: '🔴 la surface notebook ne relaie pas la position déclarée',
      );
    });
  });
}
