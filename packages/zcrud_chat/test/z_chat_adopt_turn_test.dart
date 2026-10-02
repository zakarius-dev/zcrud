@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

void main() {
  test(
    'adoptTurn établit sources, niveau, et une identité distincte',
    () async {
      final ZChatController controller = _controller();
      addTearDown(controller.dispose);
      final ZResult<ZChatRequestToken> done = await controller.adoptTurn(
        Stream<ZResult<ZChatStreamEvent>>.fromIterable(
          <ZResult<ZChatStreamEvent>>[
            const Right<ZFailure, ZChatStreamEvent>(
              ZChatSourcesPreviewEvent(
                sources: <ZChatSource>[ZChatSource(displayText: 'article 12')],
              ),
            ),
            const Right<ZFailure, ZChatStreamEvent>(
              ZChatTokenEvent(content: 'réponse'),
            ),
            const Right<ZFailure, ZChatStreamEvent>(
              ZChatDoneEvent(
                metadata: <String, dynamic>{
                  'level': 'detail',
                  'grounded': true,
                },
              ),
            ),
          ],
        ),
      );
      expect(done.isRight(), isTrue);
      expect(controller.messages.value, hasLength(1));
      final ZChatMessage reply = controller.messages.value.single;
      expect(reply.role, ZChatRole.assistant);
      expect(reply.level, 'detail');
      expect(reply.grounded, isTrue);
      expect(reply.sources, isNotNull);
      expect(reply.sources!.single.displayText, 'article 12');
      expect(
        reply.id,
        isNot(done.getOrElse(() => throw StateError('')).requestId),
      );
      expect(controller.composer.text, isEmpty);
    },
  );

  test('send sans message utilisateur ne vide pas le brouillon', () async {
    final ZChatController controller = _controller(port: _DonePort());
    addTearDown(controller.dispose);
    controller.composer.text = 'brouillon';
    final ZResult<ZChatRequestToken> sent = await controller.send(
      draft: const ZChatDraft(text: 'question suggérée'),
      emitsUserMessage: true,
    );
    expect(sent.isRight(), isTrue);
    expect(controller.composer.text, 'brouillon');
    expect(
      controller.messages.value.map((ZChatMessage m) => m.role).toList(),
      <ZChatRole>[ZChatRole.user, ZChatRole.assistant],
    );
  });

  test('un état d\'ingestion inconnu ne devient pas prêt', () {
    expect(
      ZNotebookIngestionState.fromJson('no_text'),
      ZNotebookIngestionState.unknown,
    );
    expect(ZNotebookIngestionState.fromJson(''), ZNotebookIngestionState.ready);
  });

  testWidgets('reverse garde le premier message au-dessus du second', (
    WidgetTester tester,
  ) async {
    final ZChatController controller = _controller(
      messages: <ZChatMessage>[
        const ZChatMessage(
          id: 'm0',
          role: ZChatRole.user,
          contentBlocks: <ZContentBlock>[ZTextBlock(text: 'ancien')],
        ),
        const ZChatMessage(
          id: 'm1',
          role: ZChatRole.assistant,
          contentBlocks: <ZContentBlock>[ZTextBlock(text: 'récent')],
        ),
      ],
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(ZChatConversationView(controller: controller, reverse: true)),
    );
    final double oldTop = tester.getTopLeft(find.text('ancien')).dy;
    final double newTop = tester.getTopLeft(find.text('récent')).dy;
    expect(oldTop, lessThan(newTop));
  });

  test(
    'adoptTurn donne le jeton tout de suite et laisse remplacer le fil',
    () async {
      final ZChatController controller = _controller();
      addTearDown(controller.dispose);
      ZChatRequestToken? seen;
      final Completer<void> gate = Completer<void>();
      final Future<ZResult<ZChatRequestToken>> done = controller.adoptTurn(
        Stream<ZResult<ZChatStreamEvent>>.fromFuture(
          gate.future.then(
            (_) => const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent()),
          ),
        ),
        requestId: 'tour-1',
        settle: false,
        onStarted: (ZChatRequestToken token) => seen = token,
      );
      expect(seen?.requestId, 'tour-1');
      expect(controller.activeRequests.value, <String>['tour-1']);
      controller.adoptMessages(<ZChatMessage>[
        const ZChatMessage(
          id: 'hote',
          conversationId: 'c1',
          role: ZChatRole.user,
          contentBlocks: <ZContentBlock>[ZTextBlock(text: 'question')],
        ),
      ]);
      expect(controller.messages.value.single.id, 'hote');
      gate.complete();
      final ZResult<ZChatRequestToken> settled = await done;
      expect(settled.isRight(), isTrue);
      expect(controller.messages.value.single.id, 'hote');
      expect(controller.activeRequests.value, isEmpty);
    },
  );

  test('adoptTurn ancré écrit la réponse sous la question', () async {
    final ZChatController controller = _controller(messages: _thread());
    addTearDown(controller.dispose);
    final ZResult<ZChatRequestToken> done = await controller.adoptTurn(
      _reply('nouveau'),
      afterMessageId: 'question',
    );
    expect(done.isRight(), isTrue);
    expect(controller.messages.value.map(_text).toList(), <String>[
      'question',
      'nouveau',
      'ancienne',
      'suite',
    ]);
  });

  test(
    'insertAt place la réponse, et l\'identité l\'emporte sur l\'index',
    () async {
      final ZChatController byIndex = _controller(messages: _thread());
      addTearDown(byIndex.dispose);
      await byIndex.adoptTurn(_reply('nouveau'), insertAt: 1);
      expect(byIndex.messages.value.map(_text).toList(), <String>[
        'question',
        'nouveau',
        'ancienne',
        'suite',
      ]);

      final ZChatController both = _controller(messages: _thread());
      addTearDown(both.dispose);
      await both.adoptTurn(
        _reply('nouveau'),
        afterMessageId: 'question',
        insertAt: 0,
      );
      expect(both.messages.value.map(_text).toList().first, 'question');
      expect(both.messages.value.map(_text).toList()[1], 'nouveau');
    },
  );

  test(
    'une ancre inconnue retombe sur l\'index, sinon en fin de fil',
    () async {
      final ZChatController tail = _controller(messages: _thread());
      addTearDown(tail.dispose);
      await tail.adoptTurn(_reply('nouveau'), afterMessageId: 'absent');
      expect(tail.messages.value.map(_text).toList().last, 'nouveau');

      final ZChatController fallback = _controller(messages: _thread());
      addTearDown(fallback.dispose);
      await fallback.adoptTurn(
        _reply('nouveau'),
        afterMessageId: 'absent',
        insertAt: 1,
      );
      expect(fallback.messages.value.map(_text).toList(), <String>[
        'question',
        'nouveau',
        'ancienne',
        'suite',
      ]);
    },
  );

  test('displayIndexOf suit la question quand le fil est remplacé', () async {
    final ZChatController controller = _controller(
      messages: <ZChatMessage>[
        _msg('suite', 'suite'),
        _msg('question', 'question'),
      ],
    );
    addTearDown(controller.dispose);
    final Completer<void> gate = Completer<void>();
    final Future<ZResult<ZChatRequestToken>> done = controller.adoptTurn(
      Stream<ZResult<ZChatStreamEvent>>.fromFuture(
        gate.future.then(
          (_) => const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent()),
        ),
      ),
      afterMessageId: 'question',
      settle: false,
      requestId: 'tour-1',
    );
    expect(controller.displayIndexOf('tour-1'), 2);
    expect(controller.displayIndexOf('inconnu'), isNull);
    controller.adoptMessages(_thread());
    expect(controller.displayIndexOf('tour-1'), 1);
    gate.complete();
    await done;
    expect(controller.displayIndexOf('tour-1'), isNull);
  });

  test('la coquille voit le tour ancré entre les messages', () {
    final ZChatShellRenderRequest anchored = ZChatShellRenderRequest(
      messages: _thread(),
      activeRequestIds: const <String>['tour-1'],
      streamAnchors: const <String, int>{'tour-1': 1},
      itemBuilder: (BuildContext _, int _) => const SizedBox.shrink(),
    );
    expect(anchored.itemCount, 4);
    expect(anchored.messageAt(0)?.id, 'question');
    expect(anchored.isStreamingAt(1), isTrue);
    expect(anchored.requestIdAt(1), 'tour-1');
    expect(anchored.messageAt(2)?.id, 'ancienne');
    expect(anchored.messageAt(3)?.id, 'suite');

    final ZChatShellRenderRequest tail = ZChatShellRenderRequest(
      messages: _thread(),
      activeRequestIds: const <String>['tour-1'],
      itemBuilder: (BuildContext _, int _) => const SizedBox.shrink(),
    );
    expect(tail.isStreamingAt(3), isTrue);
    expect(tail.messageAt(2)?.id, 'suite');
    expect(tail.requestIdAt(0), isNull);
  });

  testWidgets(
    'le tour ancré reste sous sa question et la suite reste visible',
    (WidgetTester tester) async {
      final ZChatController controller = _controller(messages: _thread());
      addTearDown(controller.dispose);
      final Completer<void> gate = Completer<void>();
      final Future<ZResult<ZChatRequestToken>> done = controller.adoptTurn(
        Stream<ZResult<ZChatStreamEvent>>.fromFuture(
          gate.future.then(
            (_) => const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent()),
          ),
        ),
        afterMessageId: 'question',
        settle: false,
        requestId: 'tour-1',
      );
      await tester.pumpWidget(
        harness(ZChatConversationView(controller: controller)),
      );
      await tester.pump();
      final double question = tester.getTopLeft(find.text('question')).dy;
      final double live = tester
          .getTopLeft(find.byKey(const ValueKey<String>('stream#tour-1')))
          .dy;
      final double previous = tester.getTopLeft(find.text('ancienne')).dy;
      final double later = tester.getTopLeft(find.text('suite')).dy;
      expect(question, lessThan(live));
      expect(live, lessThan(previous));
      expect(previous, lessThan(later));
      gate.complete();
      await done;
    },
  );

  test('le singulier d\'une année ne porte pas de marqueur (s)', () {
    expect(zChatPluralCategory(const Locale('fr'), 1), 'one');
    expect(zChatPluralCategory(const Locale('ar'), 2), 'two');
    expect(zChatPluralCategory(const Locale('ar'), 5), 'few');
  });
}

ZChatController _controller({
  List<ZChatMessage> messages = const [],
  ZChatStreamPort? port,
}) {
  return ZChatController(
    streamPort: port ?? FakeStreamPort(),
    actionExecutor: const ZChatUnsupportedActionExecutor(),
    confirm: (ZChatActionPlan _) async => true,
    newRequestId: _Seq().next,
    buildRequest: (ZChatDraft draft) => ZChatGenerationRequest(
      style: ZChatGenerationStyle.converse,
      subject: draft.text,
    ),
    conversationId: 'c1',
    initialMessages: messages,
  );
}

class _Seq {
  int _n = 0;
  String next() => 'r${_n++}';
}

ZChatMessage _msg(String id, String text, {ZChatRole role = ZChatRole.user}) {
  return ZChatMessage(
    id: id,
    conversationId: 'c1',
    role: role,
    contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
  );
}

List<ZChatMessage> _thread() => <ZChatMessage>[
  _msg('question', 'question'),
  _msg('ancienne', 'ancienne', role: ZChatRole.assistant),
  _msg('suite', 'suite'),
];

String _text(ZChatMessage message) {
  final ZContentBlock block = message.contentBlocks.first;
  return block is ZTextBlock ? block.text : '';
}

Stream<ZResult<ZChatStreamEvent>> _reply(String text) {
  return Stream<ZResult<ZChatStreamEvent>>.fromIterable(
    <ZResult<ZChatStreamEvent>>[
      Right<ZFailure, ZChatStreamEvent>(ZChatTokenEvent(content: text)),
      const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent()),
    ],
  );
}

class _DonePort implements ZChatStreamPort {
  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) async* {
    yield const Right<ZFailure, ZChatStreamEvent>(
      ZChatTokenEvent(content: 'ok'),
    );
    yield const Right<ZFailure, ZChatStreamEvent>(ZChatDoneEvent());
  }
}
