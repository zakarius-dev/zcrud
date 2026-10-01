/// Finalisation d'un tour : l'ordre de lecture est celui du flux.
///
/// Un bloc structuré ferme le segment de texte ouvert. Sans ça, tout le
/// texte se retrouve avant tous les blocs, et « texte, citation, texte »
/// se lit « texte entier, puis citation ».
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';

ZResult<ZChatStreamEvent> _table() => Right<ZFailure, ZChatStreamEvent>(
  const ZChatContentBlockEvent(
    block: ZTableBlock(
      headers: <String>['code'],
      rows: <List<String>>[
        <String>['0101'],
      ],
    ),
  ),
);

Future<ZChatMessage> _reply(
  ZChatController controller,
  FakeStreamPort port,
  List<ZResult<ZChatStreamEvent>> events,
) async {
  controller.composer.text = 'question';
  final Future<ZResult<ZChatRequestToken>> sending = controller.send();
  await pumpEventQueue();
  for (final ZResult<ZChatStreamEvent> event in events) {
    port.last.add(event);
  }
  await pumpEventQueue();
  await sending;
  return controller.messages.value.last;
}

void main() {
  test('texte, bloc, texte : trois segments dans cet ordre', () async {
    final harness = buildController();
    addTearDown(harness.controller.dispose);
    addTearDown(harness.port.closeAll);

    final ZChatMessage reply = await _reply(
      harness.controller,
      harness.port,
      <ZResult<ZChatStreamEvent>>[
        tok('avant'),
        _table(),
        tok('après'),
        done(id: 'a1'),
      ],
    );

    expect(reply.role, ZChatRole.assistant);
    expect(reply.contentBlocks, hasLength(3));
    expect((reply.contentBlocks[0] as ZTextBlock).text, 'avant');
    expect(reply.contentBlocks[1], isA<ZTableBlock>());
    expect(
      (reply.contentBlocks[2] as ZTextBlock).text,
      'après',
      reason:
          '🔴 le texte entier est placé AVANT les blocs : la suite '
          '« après » a rejoint « avant »',
    );
  });

  test('un tour sans bloc reste un seul segment de texte', () async {
    final harness = buildController();
    addTearDown(harness.controller.dispose);
    addTearDown(harness.port.closeAll);

    final ZChatMessage reply = await _reply(
      harness.controller,
      harness.port,
      <ZResult<ZChatStreamEvent>>[tok('bonjour'), done(id: 'a1')],
    );

    expect(reply.contentBlocks, hasLength(1));
    expect((reply.contentBlocks.single as ZTextBlock).text, 'bonjour');
  });

  test('bloc puis texte : le texte ne repasse pas devant', () async {
    final harness = buildController();
    addTearDown(harness.controller.dispose);
    addTearDown(harness.port.closeAll);

    final ZChatMessage reply = await _reply(
      harness.controller,
      harness.port,
      <ZResult<ZChatStreamEvent>>[_table(), tok('suite'), done(id: 'a1')],
    );

    expect(reply.contentBlocks.first, isA<ZTableBlock>());
    expect((reply.contentBlocks.last as ZTextBlock).text, 'suite');
  });

  test('une coupure conserve le même ordre', () async {
    final harness = buildController(maxResumeAttempts: 0);
    addTearDown(harness.controller.dispose);
    addTearDown(harness.port.closeAll);

    final ZChatMessage reply = await _reply(
      harness.controller,
      harness.port,
      <ZResult<ZChatStreamEvent>>[
        tok('avant'),
        _table(),
        tok('après'),
        interrupted('r0'),
      ],
    );

    expect(reply.contentBlocks, hasLength(3));
    expect((reply.contentBlocks[0] as ZTextBlock).text, 'avant');
    expect(reply.contentBlocks[1], isA<ZTableBlock>());
    expect((reply.contentBlocks[2] as ZTextBlock).text, 'après');
  });

  test('les segments sont lisibles avant la fin du tour', () async {
    final harness = buildController();
    addTearDown(harness.controller.dispose);
    addTearDown(harness.port.closeAll);

    harness.controller.composer.text = 'question';
    final Future<ZResult<ZChatRequestToken>> sending = harness.controller
        .send();
    await pumpEventQueue();
    final String requestId = harness.port.calls.single.token.requestId;
    harness.port.last.add(tok('avant'));
    await pumpEventQueue();
    harness.port.last.add(_table());
    await pumpEventQueue();

    final List<ZContentBlock> live = harness.controller
        .streamBlocks(requestId)
        .value;
    expect(live, hasLength(2));
    expect((live[0] as ZTextBlock).text, 'avant');
    expect(live[1], isA<ZTableBlock>());

    harness.port.last.add(tok('après'));
    await pumpEventQueue();
    final List<ZContentBlock> grown = harness.controller
        .streamBlocks(requestId)
        .value;
    expect(grown, hasLength(3));
    expect((grown[2] as ZTextBlock).text, 'après');

    harness.port.last.add(done(id: 'a1'));
    await pumpEventQueue();
    await sending;
  });
}
