/// CR-IFFD-84 · volet B — la **coquille de tuile déclarée** : carte, filet,
/// coiffe, style du bouton de dépli, format d'horodatage.
///
/// ## Ce que ce fichier mesure, et pourquoi dans cet ordre
///
/// Le premier groupe est le **contre-témoin**, et il est écrit en COMPTES
/// ABSOLUS de widgets : sans déclaration, la tuile rend zéro `DecoratedBox`,
/// zéro `Padding`, une seule `Column`. Une comparaison entre deux rendus
/// passifs aurait été verte même si les deux avaient changé ensemble — c'est
/// exactement le piège que la revue multi-lentilles a relevé ailleurs.
///
/// Les groupes suivants mesurent ce que la déclaration apporte, et un seul
/// axe à la fois : déclarer une coiffe ne déplace pas le bouton de dépli,
/// déclarer une coquille ne fait pas apparaître d'identité d'interlocuteur.
///
/// ## Le contresens que le groupe C existe pour interdire
///
/// La CR insiste : le sujet du tour n'est **pas** l'identité de
/// l'interlocuteur. Le notebook masque structurellement la seconde
/// (`identityBuilder` n'existe pas sur cette surface) et doit pourtant
/// pouvoir coiffer ses réponses. Deux gardes le prouvent dans les deux
/// sens : une coiffe sur une surface sans identité, et un compte ABSOLU de
/// zéro coiffe quand seule l'identité est réglée.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Un message d'utilisateur porteur de [text].
ZChatMessage user(String text, {String id = 'q1'}) => ZChatMessage(
  id: id,
  conversationId: 'c1',
  role: ZChatRole.user,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
);

/// Nombre de widgets de type [T] **sous la tuile** — jamais sous le harnais,
/// dont le `Scaffold` porte ses propres conteneurs.
int under<T extends Widget>(WidgetTester tester) => find
    .descendant(of: find.byType(ZChatMessageTile), matching: find.byType(T))
    .evaluate()
    .length;

/// La décoration de la carte (le premier `DecoratedBox` sous la tuile).
BoxDecoration card(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(ZChatMessageTile),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

/// La décoration de la pilule de dépli (le dernier `DecoratedBox`).
BoxDecoration pill(WidgetTester tester) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byType(ZChatMessageTile),
                    matching: find.byType(DecoratedBox),
                  )
                  .last,
            )
            .decoration
        as BoxDecoration;

/// Le rectangle rendu de la cible du bouton de dépli.
Rect toggleRect(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(ZChatMessageTile),
    matching: find.byType(GestureDetector),
  ),
);

/// Capture les erreurs relayées à `FlutterError` pendant [body].
Future<List<FlutterErrorDetails>> captureErrors(
  Future<void> Function() body,
) async {
  final List<FlutterErrorDetails> caught = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = caught.add;
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
  }
  return caught;
}

/// Une tuile repliable, dans un défilement d'hôte (le dépli doit pouvoir
/// grandir sans déborder le `Scaffold` du test — infra, pas sujet).
Widget collapsible({ZChatTileShell? shell, String? topic}) =>
    SingleChildScrollView(
      child: ZChatMessageTile(
        message: assistant(<ZContentBlock>[longText(40)]),
        collapsedMaxHeight: 96,
        shell: shell,
        topic: topic,
      ),
    );

void main() {
  group('🔴 B-A — CONTRE-TÉMOIN : rien de déclaré, rien de rendu (comptes '
      'ABSOLUS)', () {
    testWidgets('la tuile nue rend ZÉRO conteneur, ZÉRO coiffe, UNE colonne', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
          ),
        ),
      );
      expect(
        under<DecoratedBox>(tester),
        0,
        reason:
            '🔴 une carte est apparue sans déclaration : tout hôte du paquet '
            'hériterait du rendu IFFD sans l\'avoir demandé',
      );
      expect(under<Padding>(tester), 0, reason: '🔴 marge non demandée');
      expect(
        under<Column>(tester),
        1,
        reason:
            '🔴 seule la Column INTERNE des blocs doit exister : une seconde '
            'signifierait un conteneur de composition ajouté',
      );
      expect(renderedTexts(tester), <String>['corps']);
    });

    testWidgets('un skin SANS coquille déclarée ne dessine rien non plus', (
      WidgetTester tester,
    ) async {
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
            // Un skin RENSEIGNÉ — mais sa coquille n'est pas déclarée.
            skin: const ZChatNotebookSkin(bubbleWidthFactor: 0.5),
          ),
        ),
      );
      expect(
        under<DecoratedBox>(tester),
        0,
        reason:
            '🔴 la coquille est un EFFET DE BORD d\'un réglage voisin : régler '
            'la largeur de bulle ne doit pas faire naître une carte',
      );
      expect(under<Padding>(tester), 0);
    });

    testWidgets('le bouton de dépli nu reste un texte aligné au DÉBUT', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(harness(collapsible()));
      await tester.pumpAndSettle();
      expect(
        under<DecoratedBox>(tester),
        0,
        reason: '🔴 une pilule est apparue sans coquille déclarée',
      );
      final Rect tile = tester.getRect(find.byType(ZChatMessageTile));
      final Rect target = toggleRect(tester);
      expect(
        target.left,
        closeTo(tile.left, 0.5),
        reason:
            '🔴 la cible du bouton ne part plus du bord de départ : le rendu '
            'passif a changé',
      );
    });
  });

  group('🔴 B-B — la COQUILLE déclarée : carte et filet', () {
    testWidgets('déclarée vide, elle rend la carte et son filet de référence', (
      WidgetTester tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              scheme = Theme.of(context).colorScheme;
              return ZChatMessageTile(
                message: assistant(<ZContentBlock>[
                  const ZTextBlock(text: 'corps'),
                ]),
                shell: const ZChatTileShell(),
              );
            },
          ),
        ),
      );
      expect(under<DecoratedBox>(tester), 1);
      final BoxDecoration d = card(tester);
      expect(
        d.borderRadius,
        BorderRadius.all(ZChatNotebookReference.tileRadius),
      );
      final BorderSide side = (d.border! as Border).top;
      expect(side.width, ZChatNotebookReference.tileBorderWidth);
      expect(
        side.color,
        scheme.onSurfaceVariant,
        reason:
            '🔴 le filet doit venir d\'un RÔLE du `ColorScheme` de l\'hôte, '
            'jamais d\'un littéral (FR-26)',
      );
      expect(
        d.color,
        isNull,
        reason:
            '🔴 la carte de référence est CERNÉE, pas remplie : un fond '
            'inventé masquerait la surface de l\'hôte',
      );
    });

    testWidgets('chaque champ déclaré prime sur la référence', (
      WidgetTester tester,
    ) async {
      const Color filet = Color(0xFF112233);
      const Color fond = Color(0xFF445566);
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            shell: const ZChatTileShell(
              borderColor: filet,
              borderWidth: 3,
              radius: Radius.circular(2),
              backgroundColor: fond,
              padding: EdgeInsetsDirectional.all(11),
              margin: EdgeInsetsDirectional.all(7),
            ),
          ),
        ),
      );
      final BoxDecoration d = card(tester);
      expect((d.border! as Border).top.color, filet);
      expect((d.border! as Border).top.width, 3);
      expect(d.borderRadius, const BorderRadius.all(Radius.circular(2)));
      expect(d.color, fond);
      final List<Padding> pads = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(ZChatMessageTile),
              matching: find.byType(Padding),
            ),
          )
          .toList();
      expect(pads.first.padding, const EdgeInsetsDirectional.all(7));
      expect(pads.last.padding, const EdgeInsetsDirectional.all(11));
    });

    testWidgets('une épaisseur nulle ne peint AUCUN côté', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            shell: const ZChatTileShell(borderWidth: 0),
          ),
        ),
      );
      expect(
        card(tester).border,
        isNull,
        reason:
            '🔴 un côté d\'épaisseur nulle serait un décor invisible monté '
            'pour rien (AD-4) — une coquille sans cadre doit être exprimable',
      );
    });
  });

  group('🔴 B-C — la COIFFE : le SUJET du tour, distinct de l\'IDENTITÉ', () {
    testWidgets('la question coiffe sa réponse, et la précède', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          user('Quelle est la question posee ?'),
          assistant(<ZContentBlock>[
            const ZTextBlock(text: 'la reponse'),
          ], id: 'a1'),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            shell: const ZChatTileShell(topicOf: zChatPrecedingRequestTopic),
          ),
        ),
      );
      expect(find.text('Quelle est la question posee ?'), findsNWidgets(2));
      final Rect coiffe = tester.getRect(
        find
            .descendant(
              of: find.byWidgetPredicate(
                (Widget w) => w is ZChatMessageTile && w.message.id == 'a1',
              ),
              matching: find.text('Quelle est la question posee ?'),
            )
            .first,
      );
      final Rect corps = tester.getRect(find.text('la reponse'));
      expect(
        coiffe.bottom,
        lessThanOrEqualTo(corps.top),
        reason: '🔴 la coiffe doit PRÉCÉDER le corps (ordre de lecture, AD-13)',
      );
    });

    testWidgets('un message d\'UTILISATEUR n\'est jamais coiffé', (
      WidgetTester tester,
    ) async {
      expect(
        zChatPrecedingRequestTopic(user('q'), user('q0')),
        isNull,
        reason: '🔴 une question coiffée d\'une autre question est un doublon',
      );
      expect(
        zChatPrecedingRequestTopic(
          assistant(<ZContentBlock>[const ZTextBlock(text: 'r')]),
          null,
        ),
        isNull,
        reason: '🔴 sans question qui précède, il n\'y a pas de sujet à coiffer',
      );
    });

    testWidgets('🔴 le SUJET n\'est PAS l\'identité : le notebook, qui masque '
        'l\'identité, coiffe pourtant ses réponses', (
      WidgetTester tester,
    ) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          user('le sujet du tour'),
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')], id: 'a1'),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            skin: const ZChatNotebookSkin(
              tile: ZChatTileShell(topicOf: zChatPrecedingRequestTopic),
            ),
          ),
        ),
      );
      expect(
        find.text('le sujet du tour'),
        findsNWidgets(2),
        reason:
            '🔴 le sujet a été confondu avec l\'identité : le notebook masque '
            'l\'identité, PAS le sujet — c\'est le contresens que la CR '
            'redoute',
      );
    });

    testWidgets('🔴 régler l\'IDENTITÉ ne fait apparaître AUCUNE coiffe '
        '(compte ABSOLU)', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            identityBuilder: (BuildContext context, ZChatMessage m) =>
                const Text('un interlocuteur'),
          ),
        ),
      );
      expect(
        collectSemantics(
          tester,
          (SemanticsNode n) => n.flagsCollection.isHeader,
        ),
        isEmpty,
        reason:
            '🔴 l\'identité a produit une COIFFE : les deux créneaux se sont '
            'confondus',
      );
      handle.dispose();
    });

    testWidgets('AD-10 — un résolveur de sujet qui LÈVE perd la coiffe, pas '
        'le message', (WidgetTester tester) async {
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          user('q'),
          assistant(<ZContentBlock>[const ZTextBlock(text: 'corps')], id: 'a1'),
        ],
      );
      addTearDown(rig.controller.dispose);
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(
          harness(
            ZChatConversationView(
              controller: rig.controller,
              shell: ZChatTileShell(
                topicOf: (ZChatMessage m, ZChatMessage? r) =>
                    throw StateError('hote defaillant'),
              ),
            ),
          ),
        );
      });
      expect(
        find.text('corps'),
        findsOneWidget,
        reason: '🔴 le message est TOMBÉ avec la coiffe — AD-10 violé',
      );
      expect(
        caught.map((FlutterErrorDetails d) => '${d.context}').join(),
        contains(kZChatSeamTopic),
        reason:
            '🔴 sans le nom du seam, l\'hôte lit une pile de socle sans savoir '
            'lequel de ses résolveurs a levé',
      );
    });
  });

  group('🔴 B-D — le BOUTON DE DÉPLI : forme, alignement, remplissage', () {
    testWidgets('déclaré, il est CENTRÉ, plein, et garde sa cible de 48 dp', (
      WidgetTester tester,
    ) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              scheme = Theme.of(context).colorScheme;
              return collapsible(shell: const ZChatTileShell());
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Rect tile = tester.getRect(find.byType(ZChatMessageTile));
      final Rect target = toggleRect(tester);
      expect(
        target.center.dx,
        closeTo(tile.center.dx, 0.5),
        reason: '🔴 le bouton de référence est CENTRÉ',
      );
      expect(
        target.height,
        greaterThanOrEqualTo(48),
        reason: '🔴 invariant AD-13 : la cible ne descend pas sous 48 dp',
      );
      expect(target.width, greaterThanOrEqualTo(48));
      final BoxDecoration d = pill(tester);
      expect(
        d.borderRadius,
        BorderRadius.all(ZChatNotebookReference.tileToggleRadius),
      );
      expect(
        d.color,
        scheme.primaryContainer,
        reason:
            '🔴 le remplissage doit venir d\'un RÔLE contrasté, jamais d\'un '
            'littéral (FR-26)',
      );
    });

    testWidgets('forme, alignement et remplissage suivent les jetons déclarés',
        (WidgetTester tester) async {
      late ColorScheme scheme;
      await tester.pumpWidget(
        harness(
          Builder(
            builder: (BuildContext context) {
              scheme = Theme.of(context).colorScheme;
              return collapsible(
                shell: const ZChatTileShell(
                  toggle: ZChatTileToggleStyle(
                    alignment: AlignmentDirectional.centerEnd,
                    radius: Radius.circular(3),
                    padding: EdgeInsetsDirectional.symmetric(horizontal: 40),
                    fillSlotIndex: 1,
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Rect tile = tester.getRect(find.byType(ZChatMessageTile));
      final Rect target = toggleRect(tester);
      // Mesuré contre la marge INTERNE de la carte : c'est elle qui borne la
      // largeur alignable, pas le bord de la tuile.
      expect(
        tile.right - target.right,
        closeTo(ZChatNotebookReference.tilePadding.end, 0.5),
        reason: '🔴 l\'alignement déclaré n\'est pas appliqué',
      );
      expect(
        target.left - tile.left,
        greaterThan(ZChatNotebookReference.tilePadding.start + 1),
        reason:
            '🔴 le bouton touche les DEUX bords : il n\'est pas aligné, il '
            'est étiré',
      );
      final BoxDecoration d = pill(tester);
      expect(d.borderRadius, const BorderRadius.all(Radius.circular(3)));
      expect(
        d.color,
        scheme.secondaryContainer,
        reason: '🔴 le slot de rôle déclaré n\'est pas celui qui peint',
      );
    });

    testWidgets('🔴 RTL — `centerStart` bascule de lui-même, sans second '
        'réglage', (WidgetTester tester) async {
      for (final TextDirection sens in TextDirection.values) {
        await tester.pumpWidget(
          harness(
            collapsible(
              shell: const ZChatTileShell(
                toggle: ZChatTileToggleStyle(
                  alignment: AlignmentDirectional.centerStart,
                ),
              ),
            ),
            direction: sens,
          ),
        );
        await tester.pumpAndSettle();
        final Rect tile = tester.getRect(find.byType(ZChatMessageTile));
        final Rect target = toggleRect(tester);
        final double marge = ZChatNotebookReference.tilePadding.start;
        if (sens == TextDirection.ltr) {
          expect(
            target.left - tile.left,
            closeTo(marge, 0.5),
            reason: '🔴 en LTR, le début est à GAUCHE',
          );
          expect(tile.right - target.right, greaterThan(marge + 1));
        } else {
          expect(
            tile.right - target.right,
            closeTo(marge, 0.5),
            reason:
                '🔴 en RTL, le début est à DROITE : un alignement non '
                'directionnel casse l\'interface (AD-13)',
          );
          expect(target.left - tile.left, greaterThan(marge + 1));
        }
      }
    });

    testWidgets('`filled: false` garde la forme et ne peint RIEN', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          collapsible(
            shell: const ZChatTileShell(
              toggle: ZChatTileToggleStyle(filled: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(pill(tester).color, isNull);
    });

    testWidgets('le bouton déclaré reste un BOUTON, et bascule vraiment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(collapsible(shell: const ZChatTileShell())),
      );
      await tester.pumpAndSettle();
      final double replie = tester
          .getRect(find.byType(ZChatMessageTile))
          .height;
      await tester.tap(
        find.descendant(
          of: find.byType(ZChatMessageTile),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(ZChatMessageTile)).height,
        greaterThan(replie),
        reason:
            '🔴 la pilule est visible mais INERTE : le geste a été perdu en '
            'changeant de forme',
      );
    });
  });

  group('🔴 B-E — l\'HORODATAGE : format déclaré, repli sans exception', () {
    final DateTime stamp = DateTime(2025, 4, 19, 7, 42, 30);

    testWidgets('la coquille déclarée rend le format de référence', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: ZChatMessage(
              id: 'a1',
              conversationId: 'c1',
              role: ZChatRole.assistant,
              contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'corps')],
              createdAt: stamp,
            ),
            shell: const ZChatTileShell(),
          ),
        ),
      );
      expect(
        find.text('19/04/2025 07:42:30'),
        findsOneWidget,
        reason:
            '🔴 le format de référence est celui de '
            '`ZChatNotebookReference.timestampFormatPattern`',
      );
    });

    testWidgets('sans coquille, AUCUN horodatage (compte ABSOLU)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: ZChatMessage(
              id: 'a1',
              conversationId: 'c1',
              role: ZChatRole.assistant,
              contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'corps')],
              createdAt: stamp,
            ),
          ),
        ),
      );
      expect(renderedTexts(tester), <String>['corps']);
    });

    testWidgets('`showTimestamp: false` retire l\'horodatage, la carte reste', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: ZChatMessage(
              id: 'a1',
              conversationId: 'c1',
              role: ZChatRole.assistant,
              contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'corps')],
              createdAt: stamp,
            ),
            shell: const ZChatTileShell(showTimestamp: false),
          ),
        ),
      );
      expect(renderedTexts(tester), <String>['corps']);
      expect(under<DecoratedBox>(tester), 1);
    });

    testWidgets('un formateur d\'hôte prime sur la référence', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: ZChatMessage(
              id: 'a1',
              conversationId: 'c1',
              role: ZChatRole.assistant,
              contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'corps')],
              createdAt: stamp,
            ),
            shell: ZChatTileShell(
              timestampFormatter: (BuildContext c, DateTime v) =>
                  '${v.year}-${v.month}',
            ),
          ),
        ),
      );
      expect(find.text('2025-4'), findsOneWidget);
      expect(find.text('19/04/2025 07:42:30'), findsNothing);
    });

    testWidgets('🔴 AD-10 — un formateur qui LÈVE retombe sur la référence, '
        'sans exception qui remonte', (WidgetTester tester) async {
      final List<FlutterErrorDetails> caught = await captureErrors(() async {
        await tester.pumpWidget(
          harness(
            ZChatMessageTile(
              message: ZChatMessage(
                id: 'a1',
                conversationId: 'c1',
                role: ZChatRole.assistant,
                contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'corps')],
                createdAt: stamp,
              ),
              shell: ZChatTileShell(
                timestampFormatter: (BuildContext c, DateTime v) =>
                    throw StateError('hote defaillant'),
              ),
            ),
          ),
        );
      });
      expect(
        find.text('19/04/2025 07:42:30'),
        findsOneWidget,
        reason: '🔴 le repli sur le format de référence n\'a pas eu lieu',
      );
      expect(find.text('corps'), findsOneWidget);
      expect(
        caught.map((FlutterErrorDetails d) => '${d.context}').join(),
        contains(kZChatSeamTimestamp),
        reason: '🔴 l\'exception d\'hôte a été AVALÉE : indiagnosticable',
      );
    });
  });

  group('🔴 B-F — A11Y : la coiffe est ANNONCÉE comme un EN-TÊTE', () {
    testWidgets('la CONTRAINTE DÉCLARÉE — pas le plancher du SDK : le nœud '
        'porte `isHeader` et le sujet ENTIER, même tronqué', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      const String sujet =
          'un sujet de tour deliberement tres long qui depasse largement la '
          'seule ligne que la reference autorise a afficher';
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            shell: const ZChatTileShell(),
            topic: sujet,
          ),
        ),
      );
      final List<SemanticsNode> entetes = collectSemantics(
        tester,
        (SemanticsNode n) => n.flagsCollection.isHeader,
      );
      expect(
        entetes,
        hasLength(1),
        reason:
            '🔴 `isHeader` est la contrainte que NOUS déclarons : un `Text` '
            'nu produit un nœud étiqueté sans jamais produire un en-tête. '
            'Zéro = la coiffe n\'est qu\'un texte de plus ; deux = elle est '
            'annoncée en double.',
      );
      expect(
        entetes.single.label,
        sujet,
        reason:
            '🔴 la troncature est VISUELLE : un lecteur d\'écran doit '
            'entendre le sujet entier',
      );
      final Text rendu = tester.widget<Text>(find.text(sujet));
      expect(rendu.maxLines, ZChatNotebookReference.tileTopicMaxLines);
      expect(rendu.overflow, TextOverflow.ellipsis);
      handle.dispose();
    });

    testWidgets('la GRAISSE de la coiffe est celle de la référence, et rien '
        'd\'autre n\'est figé', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            shell: const ZChatTileShell(),
            topic: 'sujet',
          ),
        ),
      );
      final Text rendu = tester.widget<Text>(find.text('sujet'));
      expect(
        rendu.style!.fontWeight,
        ZChatNotebookReference.messageTitleWeight,
      );
    });
  });

  group('🔴 B-G — AD-2 : la coiffe ne reconstruit pas le corps', () {
    testWidgets('basculer le dépli ne ré-invoque AUCUN rendu de bloc', (
      WidgetTester tester,
    ) async {
      final DecliningRenderer renderer = DecliningRenderer();
      await tester.pumpWidget(
        harness(
          collapsible(shell: const ZChatTileShell(), topic: 'sujet'),
          renderer: renderer,
        ),
      );
      await tester.pumpAndSettle();
      final int avant = renderer.seen.length;
      expect(avant, greaterThan(0), reason: '🔴 GARDE VACUELLE : aucun bloc vu');
      await tester.tap(
        find.descendant(
          of: find.byType(ZChatMessageTile),
          matching: find.byType(GestureDetector),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        renderer.seen.length,
        avant,
        reason:
            '🔴 le dépli a reconstruit les blocs : la coquille a fait entrer '
            'le corps du message dans la tranche du bouton (AD-2)',
      );
    });
  });
}
