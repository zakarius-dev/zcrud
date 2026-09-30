/// Avis d'avancement, raisonnement cumulé, renvois et fil adopté au repos.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

void main() {
  test(
    'un avis et un raisonnement restent sur la progression, pas dans le texte',
    () async {
      final harness = buildController();
      addTearDown(harness.controller.dispose);
      addTearDown(harness.port.closeAll);
      harness.controller.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = harness.controller
          .send();
      await pumpEventQueue();
      final String id = harness.controller.activeRequests.value.single;
      harness.port.last.add(
        const Right<ZFailure, ZChatStreamEvent>(
          ZChatStatusEvent(phase: 'search', detail: 'codes'),
        ),
      );
      harness.port.last.add(
        const Right<ZFailure, ZChatStreamEvent>(
          ZChatReasoningEvent(content: 'parce que '),
        ),
      );
      harness.port.last.add(
        Right<ZFailure, ZChatStreamEvent>(
          ZChatCustomStreamEvent('reasoning', <String, dynamic>{
            'content': 'la note',
          }),
        ),
      );
      await pumpEventQueue();
      final ZChatStreamProgress progress = harness.controller
          .progress(id)
          .value;
      expect(progress.statuses.single.phase, 'search');
      expect(progress.statuses.single.detail, 'codes');
      expect(progress.reasoning, 'parce que la note');
      expect(harness.controller.streamText(id).value, isEmpty);
      harness.port.last.add(done(id: 'a1'));
      await harness.port.closeAll();
      await sending;
    },
  );

  test('la source d\'un renvoi est lue à partir de 1', () {
    final harness = buildController();
    addTearDown(harness.controller.dispose);
    final ZChatMessage message = ZChatMessage(
      sources: const <ZChatSource>[
        ZChatSource(displayText: 'article'),
        ZChatSource(displayText: 'note'),
      ],
    );
    expect(
      harness.controller.citationSource(1, message: message)?.displayText,
      'article',
    );
    expect(
      harness.controller.citationSource(2, message: message)?.displayText,
      'note',
    );
    expect(harness.controller.citationSource(0, message: message), isNull);
    expect(harness.controller.citationSource(3, message: message), isNull);
  });

  testWidgets(
    'un renvoi [1] appelle le rappel, un texte sans rappel reste un Text',
    (WidgetTester tester) async {
      int? tapped;
      final ZChatMessage message = ZChatMessage(
        role: ZChatRole.assistant,
        contentBlocks: const <ZContentBlock>[
          ZTextBlock(text: 'voir [1] et la suite'),
        ],
      );
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: message,
            onCitationTap: (int index) => tapped = index,
          ),
        ),
      );
    await tester.tap(find.text('[1]'));
    expect(tapped, 1);

      await tester.pumpWidget(harness(ZChatMessageTile(message: message)));
      expect(find.text('voir [1] et la suite'), findsOneWidget);
      expect(tapped, 1);
    },
  );

  testWidgets('le créneau de réflexion est entre l\'identité et le texte', (
    WidgetTester tester,
  ) async {
    final ZChatMessage message = ZChatMessage(
      role: ZChatRole.assistant,
      contentBlocks: const <ZContentBlock>[ZTextBlock(text: 'réponse')],
    );
    await tester.pumpWidget(
      harness(
        ZChatMessageTile(
          message: message,
          identityBuilder: (_, _) => const Text('qui'),
          thinkingBuilder: (_, _) => const Text('pourquoi'),
        ),
      ),
    );
    expect(find.text('pourquoi'), findsOneWidget);
    final Column column = tester.widget<Column>(
      find
          .ancestor(of: find.text('pourquoi'), matching: find.byType(Column))
          .first,
    );
    expect((column.children[0] as Text).data, 'qui');
    expect((column.children[1] as Text).data, 'pourquoi');
  });

  test('un instantané au repos remplace le fil sans attach', () async {
    final harness = buildController();
    addTearDown(harness.controller.dispose);
    final ZChatInMemoryTranscript transcript = ZChatInMemoryTranscript();
    addTearDown(transcript.dispose);
    await transcript.append(
      const ZChatMessage(
        id: 'a',
        conversationId: 'c',
        role: ZChatRole.user,
        contentBlocks: <ZContentBlock>[ZTextBlock(text: 'un')],
      ),
    );
    int structural = 0;
    harness.controller.addListener(() => structural++);
    final ZChatTranscriptBinding binding = ZChatTranscriptBinding(
      transcript: transcript,
      chat: harness.controller,
      conversationId: 'c',
    );
    addTearDown(binding.dispose);
    await pumpEventQueue();
    expect(harness.controller.messages.value.single.content, 'un');
    final int afterAttach = structural;
    await transcript.update(
      const ZChatMessage(
        id: 'a',
        conversationId: 'c',
        role: ZChatRole.user,
        contentBlocks: <ZContentBlock>[ZTextBlock(text: 'deux')],
      ),
    );
    await pumpEventQueue();
    expect(harness.controller.messages.value.single.content, 'deux');
    expect(structural, afterAttach);
  });

  testWidgets('un contrôleur externe survit au dispose de l\'écran', (
    WidgetTester tester,
  ) async {
    final FakeStreamPort port = FakeStreamPort();
    addTearDown(port.closeAll);
    final ZChatConversationController owned = ZChatConversationController(
      streamPort: port,
      conversationId: 'c',
      initialMessages: const <ZChatMessage>[
        ZChatMessage(
          id: 'm',
          contentBlocks: <ZContentBlock>[ZTextBlock(text: 'salut')],
        ),
      ],
    );
    addTearDown(owned.dispose);
    await tester.pumpWidget(
      harness(
        ZChatConversationScreen(
          controller: owned,
          cursorColor: const Color(0xFF112233),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('salut'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(owned.chat.messages.value.single.content, 'salut');
  });
}
