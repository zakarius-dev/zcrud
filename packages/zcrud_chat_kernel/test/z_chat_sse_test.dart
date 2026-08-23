// Gardes de l'ouvreur SSE (`zChatSseLines`) et de l'adaptateur
// `ZChatSseStreamPort` : octets → lignes → événements, annulation immédiate,
// fin propre / fin subie, tolérance aux lignes mal formées.
//
// Chaque garde a été vue ROUGE par injection (campagne R3, journal dans le
// rapport du lot) : la source retouchée, l'assertion nommée rougit.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Une source d'octets pilotée : `push` écrit, `onCancel` est observable.
class _Source {
  _Source() {
    controller = StreamController<List<int>>(
      onCancel: () {
        cancelled++;
      },
    );
  }

  late final StreamController<List<int>> controller;
  int cancelled = 0;

  Stream<List<int>> get bytes => controller.stream;

  void push(String text) => controller.add(utf8.encode(text));

  void pushBytes(List<int> raw) => controller.add(raw);

  Future<void> close() => controller.close();
}

/// Vide la file de microtâches et de tâches — sans émettre aucun octet.
Future<void> _settle() async {
  for (int i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<String> _values(List<ZChatSseLine> lines) =>
    <String>[for (final ZChatSseLine l in lines) l.value];

void main() {
  group('SSE-1 — octets → lignes', () {
    test('les lignes VIDES sont conservées : elles séparent les événements',
        () async {
      final Stream<ZChatSseLine> lines = zChatSseLines(
        Stream<List<int>>.value(utf8.encode('data: a\n\ndata: b\n\n')),
      );
      final List<ZChatSseLine> got = await lines.toList();
      expect(got.map((ZChatSseLine l) => l.field).toList(), <ZChatSseField>[
        ZChatSseField.data,
        ZChatSseField.blank,
        ZChatSseField.data,
        ZChatSseField.blank,
      ]);
      expect(got[1].isBlank, isTrue);
      expect(got[1].value, '');
    });

    test('`data: ` est retiré UNE seule fois : `data: data: x` ⇒ `data: x`',
        () async {
      final List<ZChatSseLine> got = await zChatSseLines(
        Stream<List<int>>.value(
          utf8.encode('data: data: x\ndata:y\ndata: \n'),
        ),
      ).toList();
      expect(_values(got), <String>['data: x', 'y', '']);
      expect(got.every((ZChatSseLine l) => l.isData), isTrue);
      // La ligne brute reste disponible, intacte.
      expect(got.first.raw, 'data: data: x');
    });

    test('`\\r\\n` et `\\n` sont deux terminateurs ; un fragment coupé au '
        'milieu d\'une ligne est recollé', () async {
      final _Source src = _Source();
      final Future<List<ZChatSseLine>> collected =
          zChatSseLines(src.bytes).toList();
      src.push('data: hel');
      src.push('lo\r\ndata: wor');
      src.push('ld\n');
      await src.close();
      expect(_values(await collected), <String>['hello', 'world']);
    });

    test('UTF-8 MALFORMÉ ne tue pas le flux : l\'octet est remplacé, les '
        'lignes suivantes arrivent', () async {
      final _Source src = _Source();
      final List<ZChatSseLine> got = <ZChatSseLine>[];
      Object? error;
      final Future<void> done = zChatSseLines(src.bytes)
          .listen(got.add, onError: (Object e) => error = e)
          .asFuture<void>();
      src.pushBytes(<int>[...utf8.encode('data: a'), 0xFF, 0xFE, 0x0A]);
      src.push('data: b\n');
      await src.close();
      await done;
      expect(error, isNull, reason: 'un octet invalide n\'est pas une erreur');
      expect(got.length, 2);
      expect(got[0].value, startsWith('a'));
      expect(got[0].value, contains('�'));
      expect(got[1].value, 'b');
    });

    test('`id:` alimente la position de reprise de la ligne et des suivantes, '
        'à travers les séparateurs ; un `id:` vide la remet à null', () async {
      final List<ZChatSseLine> got = await zChatSseLines(
        Stream<List<int>>.value(utf8.encode(
          'data: a\nid: 7\ndata: b\n\ndata: c\nid:\ndata: d\n',
        )),
      ).toList();
      final Map<String, String?> seqByValue = <String, String?>{
        for (final ZChatSseLine l in got.where((ZChatSseLine l) => l.isData))
          l.value: l.sequenceId,
      };
      expect(seqByValue, <String, String?>{
        'a': null,
        'b': '7',
        'c': '7',
        'd': null,
      });
      expect(got[1].field, ZChatSseField.id);
      expect(got[1].sequenceId, '7',
          reason: 'la ligne `id:` porte déjà sa propre position');
    });

    test('`event:` et `retry:` sont EXPOSÉS, jamais interprétés ; le nom '
        'd\'événement vaut pour le bloc courant seulement', () async {
      final List<ZChatSseLine> got = await zChatSseLines(
        Stream<List<int>>.value(utf8.encode(
          'event: token\nretry: 3000\ndata: a\n\ndata: b\n',
        )),
      ).toList();
      expect(got[0].field, ZChatSseField.event);
      expect(got[0].value, 'token');
      expect(got[1].field, ZChatSseField.retry);
      expect(got[1].value, '3000',
          reason: 'valeur brute : aucune conversion, aucune temporisation');
      expect(got[2].eventName, 'token');
      expect(got[3].isBlank, isTrue);
      expect(got[3].eventName, isNull);
      expect(got[4].value, 'b');
      expect(got[4].eventName, isNull,
          reason: 'le nom d\'événement ne survit pas au séparateur');
    });

    test('commentaire (`:` en tête) et ligne sans champ connu : rendus, '
        'classés, jamais une erreur', () async {
      final List<ZChatSseLine> got = await zChatSseLines(
        Stream<List<int>>.value(utf8.encode(
          ': keepalive\n###LINE###\nfoo: bar\n',
        )),
      ).toList();
      expect(got[0].field, ZChatSseField.comment);
      expect(got[0].value, ' keepalive');
      expect(got[1].field, ZChatSseField.other);
      expect(got[1].value, '###LINE###');
      expect(got[2].field, ZChatSseField.other);
      expect(got[2].value, 'foo: bar',
          reason: 'un champ inconnu est rendu VERBATIM, préfixe compris');
    });

    test('`zChatClassifySseLine` ne tient aucun état', () {
      expect(zChatClassifySseLine('id: 3').sequenceId, isNull);
      expect(zChatClassifySseLine('').field, ZChatSseField.blank);
      expect(zChatClassifySseLine('data:').value, '');
    });
  });

  group('SSE-2 — fin, annulation, libération', () {
    test('`[DONE]` est émis PUIS le flux se ferme ; la source est libérée et '
        '`onClose` appelé une fois', () async {
      int closes = 0;
      // La source ne se ferme jamais d'elle-même : c'est `[DONE]` qui termine.
      final _Source src2 = _Source();
      final List<ZChatSseLine> lines = <ZChatSseLine>[];
      bool done = false;
      zChatSseLines(src2.bytes, onClose: () => closes++)
          .listen(lines.add, onDone: () => done = true);
      src2.push('data: a\ndata: [DONE]\ndata: jamais-lu\n');
      await _settle();
      expect(done, isTrue, reason: '🔴 `[DONE]` doit fermer le flux rendu');
      expect(_values(lines), <String>['a', '[DONE]']);
      expect(lines.last.isDone, isTrue);
      expect(src2.cancelled, 1, reason: 'la source est désabonnée');
      expect(closes, 1);
      await src2.close();
      await _settle();
      expect(closes, 1, reason: '`onClose` : exactement une fois');
    });

    test('🔴 le `cancel` du jeton ferme la source IMMÉDIATEMENT — sans '
        'attendre une ligne suivante', () async {
      final _Source src = _Source();
      final ZChatRequestToken token = ZChatRequestToken('r1');
      int closes = 0;
      Object? error;
      bool done = false;
      final List<ZChatSseLine> got = <ZChatSseLine>[];
      zChatSseLines(src.bytes, token: token, onClose: () => closes++).listen(
        got.add,
        onError: (Object e) => error = e,
        onDone: () => done = true,
      );
      src.push('data: a\n');
      await _settle();
      expect(_values(got), <String>['a']);
      expect(src.cancelled, 0);

      token.cancel();
      await _settle(); // AUCUN octet poussé entre le cancel et la mesure.

      expect(src.cancelled, 1,
          reason: '🔴 la source doit être désabonnée au cancel, pas au '
              'prochain événement');
      expect(closes, 1);
      expect(done, isTrue, reason: 'le flux rendu se ferme proprement');
      expect(error, isNull, reason: 'une annulation n\'est pas une erreur');
      // Ce qui arrive après n'est plus lu.
      src.push('data: b\n');
      await _settle();
      expect(_values(got), <String>['a']);
      await src.close();
    });

    test('un jeton DÉJÀ annulé à l\'abonnement ⇒ la source n\'est jamais '
        'écoutée', () async {
      final ZChatRequestToken token = ZChatRequestToken('r0')..cancel();
      bool listened = false;
      final Stream<List<int>> bytes = StreamController<List<int>>(
        onListen: () => listened = true,
      ).stream;
      int closes = 0;
      final List<ZChatSseLine> got =
          await zChatSseLines(bytes, token: token, onClose: () => closes++)
              .toList();
      expect(got, isEmpty);
      expect(listened, isFalse);
      expect(closes, 1);
    });

    test('annuler l\'abonnement AVAL libère la source de la même façon',
        () async {
      final _Source src = _Source();
      int closes = 0;
      final StreamSubscription<ZChatSseLine> sub =
          zChatSseLines(src.bytes, onClose: () => closes++).listen((_) {});
      src.push('data: a\n');
      await _settle();
      await sub.cancel();
      expect(src.cancelled, 1);
      expect(closes, 1);
      await src.close();
    });

    test('une ERREUR de la source traverse (condition de transport) et libère '
        'la source une fois', () async {
      final _Source src = _Source();
      int closes = 0;
      final List<ZChatSseLine> got = <ZChatSseLine>[];
      Object? error;
      final Completer<void> done = Completer<void>();
      zChatSseLines(src.bytes, onClose: () => closes++).listen(
        got.add,
        onError: (Object e) => error = e,
        onDone: done.complete,
      );
      src.push('data: a\n');
      src.controller.addError(StateError('socket reset'));
      await done.future;
      expect(_values(got), <String>['a']);
      expect(error, isA<StateError>());
      expect(closes, 1);
    });

    test('la pause aval est propagée à la source', () async {
      bool paused = false;
      final StreamController<List<int>> c = StreamController<List<int>>(
        onPause: () => paused = true,
        onResume: () => paused = false,
      );
      final StreamSubscription<ZChatSseLine> sub =
          zChatSseLines(c.stream).listen((_) {});
      await _settle();
      sub.pause();
      await _settle();
      expect(paused, isTrue);
      sub.resume();
      await _settle();
      expect(paused, isFalse);
      await sub.cancel();
      await c.close();
    });
  });

  group('SSE-3 — `ZChatSseStreamPort`', () {
    final ZChatGenerationRequest req =
        ZChatGenerationRequest(style: ZChatGenerationStyle.converse);

    ZChatSseStreamPort portOn(
      _Source src, {
      List<ZChatRequestToken>? closed,
      ZChatSseLineDecoder? decode,
      ZChatSseOpener? open,
    }) =>
        ZChatSseStreamPort(
          open: open ?? (_, _) async => src.bytes,
          decode: decode ?? zChatSseJsonLineDecoder(),
          onClose: closed?.add,
        );

    Future<List<ZResult<ZChatStreamEvent>>> run(
      ZChatSseStreamPort port,
      _Source src,
      String payload, {
      ZChatRequestToken? token,
      bool closeSource = true,
    }) async {
      final Future<List<ZResult<ZChatStreamEvent>>> collected =
          port.stream(req, token: token ?? ZChatRequestToken('t')).toList();
      await _settle();
      src.push(payload);
      if (closeSource) await src.close();
      return collected;
    }

    ZFailure? lastFailure(List<ZResult<ZChatStreamEvent>> r) =>
        r.isEmpty ? null : r.last.fold((ZFailure f) => f, (_) => null);

    test('JSON par ligne ⇒ événements typés ; la position `id:` est portée '
        'sur l\'événement quand la charge utile ne la répète pas', () async {
      final _Source src = _Source();
      final List<ZChatRequestToken> closed = <ZChatRequestToken>[];
      final ZChatRequestToken token = ZChatRequestToken('t1');
      final List<ZResult<ZChatStreamEvent>> r = await run(
        portOn(src, closed: closed),
        src,
        'id: 1\ndata: {"type":"token","content":"Bon"}\n\n'
        'id: 2\ndata: {"type":"token","content":"jour","sequence_id":"x2"}\n\n'
        'data: {"type":"done","message_id":"m1","conversation_id":"c1"}\n\n',
        token: token,
      );
      expect(r.length, 3);
      expect(r.every((ZResult<ZChatStreamEvent> e) => e.isRight()), isTrue,
          reason: 'fin PROPRE : aucun Left');
      final List<ZChatStreamEvent> ev = <ZChatStreamEvent>[
        for (final ZResult<ZChatStreamEvent> e in r)
          e.fold((_) => throw StateError('left'), (ZChatStreamEvent x) => x),
      ];
      expect(ev[0], const ZChatTokenEvent(content: 'Bon', sequenceId: '1'));
      expect(ev[1].sequenceId, 'x2',
          reason: 'la charge utile qui porte sa position l\'emporte');
      expect(ev[2], isA<ZChatDoneEvent>());
      expect(ev[2].sequenceId, '2',
          reason: 'la dernière position SSE vaut pour les lignes suivantes');
      expect(closed, <ZChatRequestToken>[token],
          reason: '`onClose` reçoit le jeton de LA requête, une fois');
    });

    test('`[DONE]` sans `ZChatDoneEvent` est une fin PROPRE : aucun Left, '
        'la source est libérée', () async {
      final _Source src = _Source();
      final List<ZResult<ZChatStreamEvent>> r = <ZResult<ZChatStreamEvent>>[];
      bool done = false;
      portOn(src)
          .stream(req, token: ZChatRequestToken('d'))
          .listen(r.add, onDone: () => done = true);
      await _settle();
      src.push('data: {"type":"token","content":"a"}\n\ndata: [DONE]\n\n');
      await _settle();
      expect(done, isTrue, reason: '🔴 `[DONE]` doit fermer le flux du port');
      expect(r.length, 1);
      expect(r.single.isRight(), isTrue);
      expect(src.cancelled, 1);
      await src.close();
    });

    test('la source se termine SANS fin propre ⇒ dernier élément '
        '`Left(ZChatStreamInterruptedFailure)` subie, avec le compte reçu',
        () async {
      final _Source src = _Source();
      final List<ZResult<ZChatStreamEvent>> r = await run(
        portOn(src),
        src,
        'data: {"type":"token","content":"a"}\n\n'
        'data: {"type":"token","content":"b"}\n\n',
        token: ZChatRequestToken('coupe'),
      );
      expect(r.length, 3);
      final ZFailure? f = lastFailure(r);
      expect(f, isA<ZChatStreamInterruptedFailure>());
      final ZChatStreamInterruptedFailure cut =
          f! as ZChatStreamInterruptedFailure;
      expect(cut.requestId, 'coupe');
      expect(cut.eventsReceived, 2);
      expect(cut.cancelledByUser, isFalse);
    });

    test('🔴 `cancel` du jeton ⇒ source libérée IMMÉDIATEMENT et dernier '
        'élément `Left(interrompu, cancelledByUser: true)`', () async {
      final _Source src = _Source();
      final List<ZChatRequestToken> closed = <ZChatRequestToken>[];
      final ZChatRequestToken token = ZChatRequestToken('stop');
      final List<ZResult<ZChatStreamEvent>> got = <ZResult<ZChatStreamEvent>>[];
      bool done = false;
      portOn(src, closed: closed)
          .stream(req, token: token)
          .listen(got.add, onDone: () => done = true);
      await _settle();
      src.push('data: {"type":"token","content":"a"}\n\n');
      await _settle();
      expect(got.length, 1);

      token.cancel();
      await _settle(); // aucun octet poussé.

      expect(src.cancelled, 1, reason: '🔴 le socket doit être coupé au stop');
      expect(closed, <ZChatRequestToken>[token]);
      expect(done, isTrue);
      expect(got.length, 2);
      final ZFailure? f = lastFailure(got);
      expect(f, isA<ZChatStreamInterruptedFailure>());
      expect((f! as ZChatStreamInterruptedFailure).cancelledByUser, isTrue);
      expect((f as ZChatStreamInterruptedFailure).eventsReceived, 1);
      await src.close();
    });

    test('deux requêtes concurrentes : annuler l\'une ne touche pas l\'autre',
        () async {
      final _Source s1 = _Source();
      final _Source s2 = _Source();
      final ZChatRequestToken t1 = ZChatRequestToken('a');
      final ZChatRequestToken t2 = ZChatRequestToken('b');
      final ZChatSseStreamPort port = ZChatSseStreamPort(
        open: (_, ZChatRequestToken t) async =>
            identical(t, t1) ? s1.bytes : s2.bytes,
        decode: zChatSseJsonLineDecoder(),
      );
      final Future<List<ZResult<ZChatStreamEvent>>> f1 =
          port.stream(req, token: t1).toList();
      final Future<List<ZResult<ZChatStreamEvent>>> f2 =
          port.stream(req, token: t2).toList();
      await _settle();
      t1.cancel();
      await _settle();
      expect(s1.cancelled, 1);
      expect(s2.cancelled, 0, reason: '🔴 annulation croisée');
      s2.push('data: {"type":"done"}\n\n');
      await s2.close();
      expect((await f1).single.isLeft(), isTrue);
      expect((await f2).single.isRight(), isTrue);
      await s1.close();
    });

    test('un OUVREUR qui lève ⇒ un seul Left typé, zéro événement', () async {
      final _Source src = _Source();
      final List<ZChatRequestToken> closed = <ZChatRequestToken>[];
      final ZChatRequestToken token = ZChatRequestToken('auth');
      final List<ZResult<ZChatStreamEvent>> r = await portOn(
        src,
        closed: closed,
        open: (_, _) async => throw StateError('401'),
      ).stream(req, token: token).toList();
      expect(r.length, 1);
      final ZFailure? f = lastFailure(r);
      expect(f, isA<ZChatStreamInterruptedFailure>());
      expect((f! as ZChatStreamInterruptedFailure).eventsReceived, 0);
      expect(f.message, contains('401'));
      expect(closed, <ZChatRequestToken>[token]);
    });

    test('un DÉCODEUR qui lève perd sa ligne, jamais le flux (AD-10) ; un '
        '`Left` rendu par le décodeur traverse et le flux continue', () async {
      final _Source src = _Source();
      final ZChatSseLineDecoder json = zChatSseJsonLineDecoder();
      final List<ZResult<ZChatStreamEvent>> r = <ZResult<ZChatStreamEvent>>[];
      Object? error;
      bool done = false;
      final ZChatSseStreamPort port = portOn(
        src,
        decode: (ZChatSseLine l) {
          if (l.value == 'boom') throw StateError('décodeur cassé');
          if (l.value == 'err') {
            return const Left<ZFailure, ZChatStreamEvent>(
              ZChatProviderFailure('agent', code: 'AGENT_TIMEOUT'),
            );
          }
          return json(l);
        },
      );
      // Zone gardée : une exception qui s'échapperait du décodeur vers le
      // flux est CAPTURÉE ici et mesurée par assertion, pas par plantage.
      await runZonedGuarded<Future<void>>(() async {
        port.stream(req, token: ZChatRequestToken('dec')).listen(
              r.add,
              onError: (Object e) => error = e,
              onDone: () => done = true,
            );
        await _settle();
        src.push('data: boom\n\ndata: err\n\n'
            'data: {"type":"token","content":"ok"}\n\n'
            'data: {"type":"done"}\n\n');
        await src.close();
        await _settle();
      }, (Object e, StackTrace _) => error ??= e);
      expect(error, isNull,
          reason: '🔴 un décodeur qui lève ne doit jamais faire erreur le flux');
      expect(done, isTrue);
      expect(r.length, 3);
      expect(r[0].isLeft(), isTrue);
      expect(r[1].isRight(), isTrue);
      expect(r[2].fold((_) => null, (ZChatStreamEvent e) => e),
          isA<ZChatDoneEvent>());
    });

    test('décodeur JSON : `event:` tient lieu de `type` quand la charge '
        'utile n\'en porte pas ; JSON illisible, séparateur, `[DONE]` ⇒ null',
        () async {
      final ZChatSseLineDecoder d = zChatSseJsonLineDecoder();
      final List<ZChatSseLine> lines = await zChatSseLines(
        Stream<List<int>>.value(utf8.encode(
          'event: token\ndata: {"content":"x"}\n\ndata: {pas du json\n'
          'data: [DONE]\n',
        )),
      ).toList();
      final ZResult<ZChatStreamEvent>? ev = d(lines[1]);
      expect(ev, isNotNull);
      expect(ev!.fold((_) => null, (ZChatStreamEvent e) => e),
          const ZChatTokenEvent(content: 'x'));
      expect(d(lines[0]), isNull, reason: 'ligne `event:`');
      expect(d(lines[2]), isNull, reason: 'séparateur');
      expect(d(lines[3]), isNull, reason: 'JSON illisible : sauté');
      expect(d(lines[4]), isNull, reason: '`[DONE]` n\'est pas un événement');
    });

    test('annuler l\'abonnement aval libère la source et appelle `onClose`',
        () async {
      final _Source src = _Source();
      final List<ZChatRequestToken> closed = <ZChatRequestToken>[];
      final ZChatRequestToken token = ZChatRequestToken('aval');
      final StreamSubscription<ZResult<ZChatStreamEvent>> sub =
          portOn(src, closed: closed).stream(req, token: token).listen((_) {});
      await _settle();
      await sub.cancel();
      await _settle();
      expect(src.cancelled, 1);
      expect(closed, <ZChatRequestToken>[token]);
      await src.close();
    });
  });
}
