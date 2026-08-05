/// CR-IFFD-71 — comportement des **créneaux par message** (`identityBuilder` /
/// `actionsBuilder`) sur `ZChatMessageTile` et leur traversée de la vue.
///
/// Ce que ce fichier prouve, mesure à l'appui :
/// * défaut inchangé : sans créneau, l'arbre rendu est celui d'avant la CR ;
/// * AD-4 : builder nul OU builder rendant `null` ⇒ **absent de l'arbre** ;
/// * ordre : identité AU-DESSUS des blocs, actions EN DESSOUS ;
/// * AD-10 : un builder d'hôte qui lève perd LE CRÉNEAU, jamais le message —
///   et l'échec est relayé à `FlutterError` avec le nom du seam ;
/// * SM-1 : basculer le dépli ne ré-invoque AUCUN builder d'hôte ;
/// * AD-13 : la GÉOMÉTRIE rendue d'une cible d'action de 48 dp reste ≥ 48 dp
///   (leçon `widthFactor` de `z_chat_diffusion_bar.dart` : on mesure le rendu,
///   pas les contraintes) ;
/// * la sémantique de bouton d'une action d'hôte n'est PAS avalée par le nœud
///   d'annonce du message (`excludeSemantics` ne couvre que les blocs).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Capture les erreurs relayées à `FlutterError` pendant [body] (patron
/// `z_chat_epic_review_guard_test.dart`).
Future<List<FlutterErrorDetails>> captureFlutterErrors(
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

void main() {
  group('CR71-S1 — défauts STRICTEMENT inchangés', () {
    testWidgets('sans créneau, la tuile rend exactement les mêmes textes '
        'qu\'avant (aucun conteneur ajouté)', (WidgetTester tester) async {
      final ZChatMessage message = assistant(<ZContentBlock>[
        const ZTextBlock(text: 'corps'),
      ]);
      await tester.pumpWidget(harness(ZChatMessageTile(message: message)));
      expect(renderedTexts(tester), <String>['corps']);
      // Le retour est le CŒUR nu : aucune Column de composition n'enveloppe la
      // tuile quand les deux créneaux sont nuls (le chemin `return core`).
      expect(
        find.descendant(
          of: find.byType(ZChatMessageTile),
          matching: find.byType(Column),
        ),
        findsOneWidget,
        reason:
            '🔴 seule la Column INTERNE des blocs doit exister : une '
            'seconde Column signifierait que le chemin par défaut a changé '
            'd\'arbre — la CR est ADDITIVE.',
      );
    });
  });

  group('CR71-S2 — AD-4 : un créneau rendu `null` est ABSENT de l\'arbre', () {
    testWidgets('le builder peut cibler CERTAINS messages seulement', (
      WidgetTester tester,
    ) async {
      const Key present = ValueKey<String>('cr71-actions-m1');
      await tester.pumpWidget(
        harness(
          Column(
            children: <Widget>[
              ZChatMessageTile(
                message: assistant(<ZContentBlock>[
                  const ZTextBlock(text: 'reponse'),
                ], id: 'm1'),
                actionsBuilder: (BuildContext context, ZChatMessage m) =>
                    m.role == ZChatRole.assistant
                    ? const SizedBox(key: present, width: 48, height: 48)
                    : null,
              ),
              ZChatMessageTile(
                message: const ZChatMessage(
                  id: 'm2',
                  conversationId: 'c1',
                  role: ZChatRole.user,
                  contentBlocks: <ZContentBlock>[ZTextBlock(text: 'question')],
                ),
                actionsBuilder: (BuildContext context, ZChatMessage m) =>
                    m.role == ZChatRole.assistant
                    ? const SizedBox(width: 48, height: 48)
                    : null,
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(present), findsOneWidget);
      // Sur le message utilisateur, le builder a rendu `null` : AUCUN widget
      // inséré — pas un `SizedBox.shrink`, RIEN (AD-4).
      final Iterable<Element> userTileBoxes = find
          .descendant(
            of: find.byWidgetPredicate(
              (Widget w) => w is ZChatMessageTile && w.message.id == 'm2',
            ),
            matching: find.byType(SizedBox),
          )
          .evaluate();
      expect(
        userTileBoxes,
        isEmpty,
        reason: '🔴 un créneau rendu `null` doit être ABSENT, pas vide',
      );
    });
  });

  group('CR71-S3 — ordre : identité AU-DESSUS, actions EN DESSOUS', () {
    testWidgets('la géométrie verticale des créneaux encadre les blocs', (
      WidgetTester tester,
    ) async {
      const Key idKey = ValueKey<String>('cr71-identity');
      const Key actKey = ValueKey<String>('cr71-actions');
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            identityBuilder: (BuildContext context, ZChatMessage m) =>
                const SizedBox(key: idKey, width: 48, height: 48),
            actionsBuilder: (BuildContext context, ZChatMessage m) =>
                const SizedBox(key: actKey, width: 48, height: 48),
          ),
        ),
      );
      final double identityBottom = tester.getBottomLeft(find.byKey(idKey)).dy;
      final double contentTop = tester.getTopLeft(find.text('corps')).dy;
      final double contentBottom = tester.getBottomLeft(find.text('corps')).dy;
      final double actionsTop = tester.getTopLeft(find.byKey(actKey)).dy;
      expect(
        identityBottom,
        lessThanOrEqualTo(contentTop),
        reason: '🔴 l\'identité doit PRÉCÉDER les blocs (ordre de lecture)',
      );
      expect(
        actionsTop,
        greaterThanOrEqualTo(contentBottom),
        reason: '🔴 les actions doivent SUIVRE les blocs',
      );
    });

    testWidgets('les actions restent HORS de la zone repliable : repliées, '
        'elles restent visibles et cliquables', (WidgetTester tester) async {
      const Key actKey = ValueKey<String>('cr71-actions');
      int taps = 0;
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[longText(40)]),
            collapsedMaxHeight: 96,
            actionsBuilder: (BuildContext context, ZChatMessage m) =>
                GestureDetector(
                  key: actKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox(width: 48, height: 48),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(actKey), findsOneWidget);
      await tester.tap(find.byKey(actKey));
      expect(
        taps,
        1,
        reason:
            '🔴 une action sous le clip du repli serait visible mais '
            'INERTE — le hit-test du contenu replié rejette hors zone',
      );
    });
  });

  group(
    'CR71-S4 — AD-10 : un builder qui LÈVE perd le créneau, pas le message',
    () {
      testWidgets('le message reste rendu, l\'échec est relayé avec le nom du '
          'seam', (WidgetTester tester) async {
        final List<FlutterErrorDetails> caught = await captureFlutterErrors(
          () async {
            await tester.pumpWidget(
              harness(
                ZChatMessageTile(
                  message: assistant(<ZContentBlock>[
                    const ZTextBlock(text: 'corps'),
                  ]),
                  identityBuilder: (BuildContext context, ZChatMessage m) =>
                      throw StateError('hote defaillant'),
                  actionsBuilder: (BuildContext context, ZChatMessage m) =>
                      const SizedBox(
                        key: ValueKey<String>('cr71-actions'),
                        width: 48,
                        height: 48,
                      ),
                ),
              ),
            );
          },
        );
        expect(
          find.text('corps'),
          findsOneWidget,
          reason: '🔴 le message est TOMBÉ avec le créneau — AD-10 violé',
        );
        expect(
          find.byKey(const ValueKey<String>('cr71-actions')),
          findsOneWidget,
          reason: '🔴 l\'échec d\'UN créneau ne doit pas emporter L\'AUTRE',
        );
        expect(
          caught,
          isNotEmpty,
          reason:
              '🔴 l\'exception d\'hôte a été AVALÉE en silence : '
              'indiagnosticable',
        );
        expect(
          caught.map((FlutterErrorDetails d) => '${d.context}').join(),
          contains(kZChatSeamIdentitySlot),
          reason:
              '🔴 sans le nom du seam, l\'hôte lit une pile dans du code de '
              'socle sans savoir lequel de ses builders a levé',
        );
      });
    },
  );

  group('CR71-S5 — SM-1 : le dépli ne ré-invoque AUCUN builder d\'hôte', () {
    testWidgets('compte d\'invocations STABLE au travers d\'une bascule', (
      WidgetTester tester,
    ) async {
      int identityCalls = 0;
      int actionsCalls = 0;
      await tester.pumpWidget(
        harness(
          // Scrollable d'HÔTE : le dépli d'un long message doit pouvoir
          // grandir sans déborder le Scaffold du test (infra, pas sujet).
          SingleChildScrollView(
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 96,
              identityBuilder: (BuildContext context, ZChatMessage m) {
                identityCalls++;
                return const SizedBox(width: 48, height: 48);
              },
              actionsBuilder: (BuildContext context, ZChatMessage m) {
                actionsCalls++;
                return const SizedBox(width: 48, height: 48);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final int identityBefore = identityCalls;
      final int actionsBefore = actionsCalls;
      expect(identityBefore, greaterThan(0));

      // Bascule RÉELLE du dépli, par le bouton interne.
      await tester.tap(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!));
      await tester.pumpAndSettle();

      expect(
        identityCalls,
        identityBefore,
        reason:
            '🔴 le dépli a reconstruit le créneau d\'identité : les '
            'créneaux doivent vivre HORS du ValueListenableBuilder du dépli',
      );
      expect(
        actionsCalls,
        actionsBefore,
        reason: '🔴 le dépli a reconstruit le créneau d\'actions (SM-1)',
      );
    });
  });

  group('CR71-S6 — AD-13 : géométrie RENDUE des cibles, pas contraintes', () {
    testWidgets('une cible d\'action de 48 dp mesure ≥ 48×48 une fois rendue', (
      WidgetTester tester,
    ) async {
      const Key actKey = ValueKey<String>('cr71-target');
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            actionsBuilder: (BuildContext context, ZChatMessage m) =>
                const SizedBox(key: actKey, width: 48, height: 48),
          ),
        ),
      );
      final Size size = tester.getSize(find.byKey(actKey));
      expect(
        size.width,
        greaterThanOrEqualTo(48.0),
        reason:
            '🔴 la tuile a COMPRIMÉ la cible d\'hôte sous 48 dp — le '
            'précédent `widthFactor` : on mesure la géométrie, jamais les '
            'contraintes',
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('la sémantique de BOUTON d\'une action d\'hôte survit au nœud '
        'd\'annonce du message', (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              const ZTextBlock(text: 'corps'),
            ]),
            actionsBuilder: (BuildContext context, ZChatMessage m) => Semantics(
              button: true,
              label: 'generer',
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) =>
              n.getSemanticsData().flagsCollection.isButton &&
              n.label.contains('generer'),
        ),
        isNotNull,
        reason:
            '🔴 le bouton d\'hôte est AVALÉ par `excludeSemantics` : le '
            'créneau doit rester une SŒUR du nœud d\'annonce, jamais son '
            'enfant',
      );
      handle.dispose();
    });
  });

  group('CR71-S7 — les créneaux TRAVERSENT la vue (fabrique unique)', () {
    testWidgets('`ZChatConversationView(identityBuilder:, actionsBuilder:)` '
        'atteint chaque tuile', (WidgetTester tester) async {
      // 🔴 Doublures PARTAGÉES (`support/z_chat_fakes.dart`) — jamais
      // recopiées ici (source unique).
      final rig = buildController(
        initialMessages: <ZChatMessage>[
          for (int i = 0; i < 2; i++)
            assistant(<ZContentBlock>[ZTextBlock(text: 'msg $i')], id: 'm$i'),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            identityBuilder: (BuildContext context, ZChatMessage m) => SizedBox(
              key: ValueKey<String>('id-${m.id}'),
              width: 48,
              height: 48,
            ),
            actionsBuilder: (BuildContext context, ZChatMessage m) => SizedBox(
              key: ValueKey<String>('act-${m.id}'),
              width: 48,
              height: 48,
            ),
          ),
        ),
      );
      for (final String id in <String>['m0', 'm1']) {
        expect(find.byKey(ValueKey<String>('id-$id')), findsOneWidget);
        expect(find.byKey(ValueKey<String>('act-$id')), findsOneWidget);
      }
    });
  });
}
