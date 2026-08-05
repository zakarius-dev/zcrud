/// CR-IFFD-71 — la surface **notebook** (`ZChatNotebookView`).
///
/// Ce que ce fichier prouve :
/// * les DEUX surfaces rendent par la MÊME fabrique de tuile (anti-divergence,
///   motif CR-LEX-78) — le couple CR71-N1a/N1b rougit ENSEMBLE si la fabrique
///   régresse (démontré par injection R3, cf. rapport du lot) ;
/// * le notebook ne rend AUCUNE identité (défaut d'usage), et son créneau
///   d'actions atteint chaque message ;
/// * SM-1 : le créneau d'actions ne casse PAS le culling — sur un fil de 100
///   messages, le NOMBRE DE TUILES CONSTRUITES est mesuré très inférieur à 100
///   (compté par les invocations du builder d'hôte, qui ne peut être invoqué
///   que par une tuile réellement construite).
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

/// Le fil témoin, IDENTIQUE pour les deux surfaces.
List<ZChatMessage> thread(int count) => <ZChatMessage>[
  for (int i = 0; i < count; i++)
    assistant(<ZContentBlock>[ZTextBlock(text: 'msg $i')], id: 'm$i'),
];

void main() {
  group('CR71-N1 — anti-divergence : MÊME fabrique, MÊME rendu', () {
    testWidgets(
      'N1a — la CONVERSATION rend le fil témoin par ZChatMessageTile',
      (WidgetTester tester) async {
        final rig = buildController(initialMessages: thread(3));
        addTearDown(rig.controller.dispose);
        await tester.pumpWidget(
          harness(ZChatConversationView(controller: rig.controller)),
        );
        expect(find.byType(ZChatMessageTile), findsNWidgets(3));
        expect(renderedTexts(tester), <String>['msg 0', 'msg 1', 'msg 2']);
      },
    );

    testWidgets('N1b — le NOTEBOOK rend le MÊME fil, par les MÊMES tuiles', (
      WidgetTester tester,
    ) async {
      final rig = buildController(initialMessages: thread(3));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(ZChatNotebookView(controller: rig.controller)),
      );
      // 🔴 La composition est STRUCTURELLE : le notebook monte la vue de
      // conversation elle-même — pas un widget « ressemblant ».
      expect(
        find.byType(ZChatConversationView),
        findsOneWidget,
        reason:
            '🔴 le notebook ne délègue plus à la racine commune : '
            'c\'est le début d\'une « surface B » (motif CR-LEX-78)',
      );
      expect(find.byType(ZChatMessageTile), findsNWidgets(3));
      expect(
        renderedTexts(tester),
        <String>['msg 0', 'msg 1', 'msg 2'],
        reason:
            '🔴 les deux surfaces divergent sur le rendu d\'un même '
            'fil : la fabrique n\'est plus partagée',
      );
    });
  });

  group('CR71-N2 — défauts d\'usage du notebook', () {
    testWidgets('sans réglage, le notebook rend le fil NU (aucune identité, '
        'aucune action) — CR-56 : un défaut se juge sans réglage', (
      WidgetTester tester,
    ) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(ZChatNotebookView(controller: rig.controller)),
      );
      expect(
        renderedTexts(tester),
        <String>['msg 0', 'msg 1'],
        reason:
            '🔴 le notebook sans réglage doit rendre le fil, rien que '
            'le fil',
      );
    });

    testWidgets('le créneau d\'actions atteint CHAQUE message du notebook', (
      WidgetTester tester,
    ) async {
      final rig = buildController(initialMessages: thread(2));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            actionsBuilder: (BuildContext context, ZChatMessage m) => SizedBox(
              key: ValueKey<String>('nb-act-${m.id}'),
              width: 48,
              height: 48,
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('nb-act-m0')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('nb-act-m1')), findsOneWidget);
    });
  });

  group('CR71-N3 — SM-1 : le créneau d\'actions ne casse pas le CULLING', () {
    testWidgets('fil de 100 messages : le builder d\'actions n\'est invoqué '
        'que pour les tuiles réellement construites', (
      WidgetTester tester,
    ) async {
      final Set<String> built = <String>{};
      final rig = buildController(initialMessages: thread(100));
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatNotebookView(
            controller: rig.controller,
            actionsBuilder: (BuildContext context, ZChatMessage m) {
              built.add(m.id ?? '');
              return const SizedBox(width: 48, height: 48);
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Le mécanisme d'abord (leçon de G-R2) : le délégué reste PARESSEUX.
      final ListView list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.childrenDelegate,
        isA<SliverChildBuilderDelegate>(),
        reason:
            '🔴 le créneau a fait basculer la liste hors du délégué '
            'paresseux : les 100 tuiles seraient construites',
      );

      // Puis la MESURE demandée par la CR : nombre de tuiles construites.
      expect(
        built,
        isNotEmpty,
        reason:
            '🔴 mesure VACUELLE : aucun builder invoqué — le créneau '
            'n\'est pas monté, la mesure ne porte sur rien',
      );
      expect(
        built.length,
        lessThan(50),
        reason:
            '🔴 ${built.length}/100 tuiles construites : le créneau '
            'd\'actions a cassé le culling (chaque invocation du builder '
            'trahit une tuile réellement construite)',
      );
    });
  });
}
