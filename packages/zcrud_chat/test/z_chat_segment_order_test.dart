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
    expect((reply.contentBlocks[2] as ZTextBlock).text, 'après',
        reason: '🔴 le texte entier est placé AVANT les blocs : la suite '
            '« après » a rejoint « avant »');
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
      <ZResult<ZChatStreamEvent>>[
        _table(),
        tok('suite'),
        done(id: 'a1'),
      ],
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
}
