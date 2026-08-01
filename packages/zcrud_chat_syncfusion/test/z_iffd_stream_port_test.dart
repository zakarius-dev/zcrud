// Gardes du PORT (CHAT-6, AD-5/AD-10) : la frontière vue depuis le kernel.
//
// Ce que le port doit garantir à un appelant qui ne connaît QUE
// `ZChatStreamPort` : un événement terminal quand le flux s'achève, un `Left`
// typé quand il casse, un `Left` marqué `cancelledByUser` quand l'utilisateur
// arrête — et **jamais** une exception qui s'échappe.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_syncfusion/zcrud_chat_syncfusion.dart';
import 'package:zcrud_core/domain.dart';

ZChatGenerationRequest req() => ZChatGenerationRequest(
  style: ZChatGenerationStyle('chat'),
  conversationId: 'c1',
);

ZIffdTextStreamPort portOf(Stream<String> Function() open) =>
    ZIffdTextStreamPort(
      open: (ZChatGenerationRequest request, ZChatRequestToken token) => open(),
    );

void main() {
  test('flux nominal : événements typés puis `ZChatDoneEvent`', () async {
    final ZIffdTextStreamPort port = portOf(
      () => Stream<String>.fromIterable(<String>[
        '<RAG_THINKING>je cherche</RAG_THINKING>',
        'La réponse.',
      ]),
    );
    final List<ZResult<ZChatStreamEvent>> out = await port
        .stream(req(), token: ZChatRequestToken('t1'))
        .toList();

    final List<ZChatStreamEvent> rights = <ZChatStreamEvent>[
      for (final ZResult<ZChatStreamEvent> e in out)
        ...e.fold((_) => const <ZChatStreamEvent>[], (ZChatStreamEvent v) => <ZChatStreamEvent>[v]),
    ];
    expect(rights.whereType<ZChatThinkingEvent>(), isNotEmpty);
    expect(
      rights.whereType<ZChatTokenEvent>().map((ZChatTokenEvent e) => e.content).join(),
      'La réponse.',
    );
    final ZChatDoneEvent done = rights.whereType<ZChatDoneEvent>().single;
    expect(done.conversationId, 'c1');
  });

  test('AD-10 · une exception du transport devient un `Left` typé', () async {
    final ZIffdTextStreamPort port = portOf(() async* {
      yield 'partiel';
      throw StateError('socket fermée');
    });
    late List<ZResult<ZChatStreamEvent>> out;
    // Ne lève JAMAIS côté appelant.
    out = await port.stream(req(), token: ZChatRequestToken('t2')).toList();

    // Le contenu déjà reçu n'est pas perdu…
    final String answer = out
        .expand(
          (ZResult<ZChatStreamEvent> e) =>
              e.fold((_) => const <ZChatStreamEvent>[], (ZChatStreamEvent v) => <ZChatStreamEvent>[v]),
        )
        .whereType<ZChatTokenEvent>()
        .map((ZChatTokenEvent e) => e.content)
        .join();
    expect(answer, 'partiel');

    // …et la coupure est typée, avec l'identité de LA requête concernée.
    final ZFailure f = out
        .expand(
          (ZResult<ZChatStreamEvent> e) =>
              e.fold((ZFailure x) => <ZFailure>[x], (_) => const <ZFailure>[]),
        )
        .single;
    expect(f, isA<ZChatStreamInterruptedFailure>());
    final ZChatStreamInterruptedFailure i = f as ZChatStreamInterruptedFailure;
    expect(i.requestId, 't2');
    expect(i.cancelledByUser, isFalse);
    expect(i.eventsReceived, greaterThan(0));
    // Aucun `ZChatDoneEvent` sur un flux cassé.
    expect(
      out.expand(
        (ZResult<ZChatStreamEvent> e) =>
            e.fold((_) => const <ZChatStreamEvent>[], (ZChatStreamEvent v) => <ZChatStreamEvent>[v]),
      ).whereType<ZChatDoneEvent>(),
      isEmpty,
    );
  });

  test('annulation VOULUE : `cancelledByUser` la distingue d\'une panne',
      () async {
    final ZChatRequestToken token = ZChatRequestToken('t3');
    final ZIffdTextStreamPort port = portOf(() async* {
      yield 'a';
      token.cancel();
      yield 'b';
    });
    final List<ZResult<ZChatStreamEvent>> out = await port
        .stream(req(), token: token)
        .toList();
    final ZChatStreamInterruptedFailure i = out
        .expand(
          (ZResult<ZChatStreamEvent> e) =>
              e.fold((ZFailure x) => <ZFailure>[x], (_) => const <ZFailure>[]),
        )
        .whereType<ZChatStreamInterruptedFailure>()
        .single;
    expect(i.cancelledByUser, isTrue);
    expect(i.requestId, 't3');
  });

  test('deux requêtes concurrentes : annuler l\'une n\'affecte PAS l\'autre',
      () async {
    final ZChatRequestToken a = ZChatRequestToken('a');
    final ZChatRequestToken b = ZChatRequestToken('b');
    final ZIffdTextStreamPort port = ZIffdTextStreamPort(
      open: (ZChatGenerationRequest _, ZChatRequestToken t) async* {
        yield 'x-${t.requestId}';
        await Future<void>.delayed(Duration.zero);
        yield 'y-${t.requestId}';
      },
    );
    a.cancel();
    final List<ZResult<ZChatStreamEvent>> outA =
        await port.stream(req(), token: a).toList();
    final List<ZResult<ZChatStreamEvent>> outB =
        await port.stream(req(), token: b).toList();

    expect(
      outA
          .expand(
            (ZResult<ZChatStreamEvent> e) =>
                e.fold((ZFailure x) => <ZFailure>[x], (_) => const <ZFailure>[]),
          )
          .whereType<ZChatStreamInterruptedFailure>()
          .single
          .cancelledByUser,
      isTrue,
    );
    // B s'achève normalement : le jeton de A ne l'a pas touché.
    expect(
      outB
          .expand(
            (ZResult<ZChatStreamEvent> e) => e.fold(
              (_) => const <ZChatStreamEvent>[],
              (ZChatStreamEvent v) => <ZChatStreamEvent>[v],
            ),
          )
          .whereType<ZChatDoneEvent>(),
      hasLength(1),
    );
  });
}
