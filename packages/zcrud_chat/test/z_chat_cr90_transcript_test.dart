// La persistance du fil, pièce PARTAGÉE entre la conversation simple et le
// fil de travail. Ce que ce fichier prouve :
//
// * `ZChatTranscriptBinding` : `attach` UNE fois sur deux instantanés, le
//   second relayé (identités changées) sans rebrancher le fil ni couper une
//   requête en vol ; un tour réglé ⇒ `append` une fois par message, avec le
//   message final (question puis réponse) ; un message connu qui change ⇒
//   `update` ; un `Left` ou une exception du port est PUBLIÉ, jamais levé ;
//   une lecture qui échoue ouvre un fil VIERGE ; `dispose` annule (la source
//   voit le `cancel`, plus aucune écriture, plus aucune amorce) ;
// * `ZChatConversationController` : avec `transcript`, le fil vient du dépôt
//   et chaque tour y est écrit ; sans, `initialMessages` est la source (même
//   instances) et rien n'existe du dépôt ;
// * `ZChatConversationScreen(transcript:)` : UN abonnement sur deux `build`,
//   libéré au `dispose` ; le fil affiché est celui du dépôt ; l'envoi est
//   persisté ; sans `transcript`, une seule tranche d'échec — l'arbre
//   d'aujourd'hui ;
// * gardes de source : la mécanique n'existe qu'en UN site de `lib/` ; les
//   deux contrôleurs la COMPOSENT ; la surface du fil de travail est
//   inchangée (égalité d'ensemble) ; la surface de la conversation est
//   exactement celle annoncée.
//
// Gardes DÉJÀ existantes, citées et non doublonnées : le fil de travail bout
// en bout (`z_chat_lot_f_notebook_test.dart`, F1 « le FIL »), l'écran de
// conversation ≡ briques (`z_chat_lot_rt_routing_test.dart`, RT-SCREEN) et
// G-CH1 (`z_chat_structure_guard_test.dart`).
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

const String _bindingFile = 'lib/src/presentation/z_chat_transcript_binding.dart';
const String _conversationFile =
    'lib/src/presentation/z_chat_conversation_controller.dart';
const String _notebookFile =
    'lib/src/presentation/notebook/z_chat_notebook_controller.dart';
const String _screenFile =
    'lib/src/presentation/view/z_chat_conversation_screen.dart';

ZChatMessage _user(String id, String text) => ZChatMessage(
      id: id,
      conversationId: 'c1',
      role: ZChatRole.user,
      contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
    );

ZChatMessage _assistant(String id, String text) => ZChatMessage(
      id: id,
      conversationId: 'c1',
      role: ZChatRole.assistant,
      contentBlocks: <ZContentBlock>[ZTextBlock(text: text)],
    );

/// Compteur de notifications, lisible après coup.
class _Tally {
  _Tally(Listenable l) {
    l.addListener(() => count++);
  }
  int count = 0;
}

/// Transcript qui ENREGISTRE chaque écriture, COMPTE les ouvertures du fil et
/// observe l'annulation. La lecture est celle de la référence en mémoire.
class _Recording implements ZChatTranscriptPort {
  _Recording(this.inner);
  final ZChatInMemoryTranscript inner;
  final List<ZChatMessage> appends = <ZChatMessage>[];
  final List<ZChatMessage> updates = <ZChatMessage>[];
  int opens = 0;
  int cancels = 0;

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) {
    opens++;
    late final StreamController<List<ZChatMessage>> out;
    StreamSubscription<List<ZChatMessage>>? sub;
    out = StreamController<List<ZChatMessage>>(
      onListen: () {
        sub = inner.messages(conversationId).listen(out.add, onError: out.addError);
      },
      onCancel: () async {
        cancels++;
        await sub?.cancel();
      },
    );
    return out.stream;
  }

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) {
    appends.add(message);
    return inner.append(message);
  }

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) {
    updates.add(message);
    return inner.update(message);
  }
}

/// Transcript dont les ÉCRITURES rendent `Left`.
class _Failing extends _Recording {
  _Failing(super.inner);

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) async {
    appends.add(message);
    return const Left<ZFailure, ZChatMessage>(ZCacheFailure('disk full'));
  }

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) async {
    updates.add(message);
    return const Left<ZFailure, ZChatMessage>(ZCacheFailure('disk full'));
  }
}

/// Transcript dont les ÉCRITURES lèvent.
class _Throwing extends _Recording {
  _Throwing(super.inner);

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) {
    appends.add(message);
    throw StateError('boom');
  }
}

/// Transcript dont la LECTURE est un flux fourni par le test.
class _BrokenRead implements ZChatTranscriptPort {
  _BrokenRead(this.source);
  final Stream<List<ZChatMessage>> source;

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) => source;

  @override
  Future<ZResult<ZChatMessage>> append(ZChatMessage message) async =>
      Right<ZFailure, ZChatMessage>(message);

  @override
  Future<ZResult<ZChatMessage>> update(ZChatMessage message) async =>
      Right<ZFailure, ZChatMessage>(message);
}

/// Transcript dont `messages` LÈVE à l'appel.
class _ThrowingRead extends _BrokenRead {
  _ThrowingRead() : super(const Stream<List<ZChatMessage>>.empty());

  @override
  Stream<List<ZChatMessage>> messages(String conversationId) =>
      throw StateError('no backend');
}

ZChatController _chat(FakeStreamPort stream) => ZChatController(
      streamPort: stream,
      actionExecutor: const ZChatUnsupportedActionExecutor(),
      confirm: zChatConfirmWithoutDialog,
      newRequestId: ZChatSequentialRequestIds('c1').call,
      buildRequest: ZChatDraftRequestBuilder(
        style: ZChatGenerationStyle.converse,
        conversationId: 'c1',
      ).call,
      conversationId: 'c1',
    );

typedef _Rig = ({
  ZChatController chat,
  ZChatTranscriptBinding binding,
  _Recording transcript,
  FakeStreamPort stream,
  List<(List<ZChatMessage>, Set<String>)> relayed,
});

/// Un contrôleur nu, lié à un fil « q1 → r1 » déjà amorcé.
Future<_Rig> _rig({_Recording Function(ZChatInMemoryTranscript)? wrap}) async {
  final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
  addTearDown(inner.dispose);
  await inner.append(_user('q1', 'question une'));
  await inner.append(_assistant('r1', 'réponse une'));
  final _Recording transcript = (wrap ?? _Recording.new)(inner);
  final FakeStreamPort stream = FakeStreamPort();
  addTearDown(stream.closeAll);
  final ZChatController chat = _chat(stream);
  addTearDown(chat.dispose);
  final List<(List<ZChatMessage>, Set<String>)> relayed =
      <(List<ZChatMessage>, Set<String>)>[];
  final ZChatTranscriptBinding binding = ZChatTranscriptBinding(
    transcript: transcript,
    chat: chat,
    conversationId: 'c1',
    onChanged: (List<ZChatMessage> s, Set<String> ids) => relayed.add((s, ids)),
  );
  addTearDown(binding.dispose);
  await pumpEventQueue();
  return (
    chat: chat,
    binding: binding,
    transcript: transcript,
    stream: stream,
    relayed: relayed,
  );
}

/// Joue un tour complet : question saisie, réponse [reply] en deux jetons.
Future<void> _turn(_Rig r, String question, String reply, {String id = 'a2'}) async {
  r.chat.composer.text = question;
  final Future<ZResult<ZChatRequestToken>> sending = r.chat.send();
  await pumpEventQueue();
  r.stream.last.add(tok(reply.substring(0, 3)));
  r.stream.last.add(tok(reply.substring(3)));
  r.stream.last.add(done(id: id));
  await r.stream.closeAll();
  await sending;
  await pumpEventQueue();
}

/// Noms des membres PUBLICS déclarés au premier niveau de [className]
/// (même découpeur que G-CH1).
Set<String> _publicMembers(String file, String className) {
  final List<String> lines = stripped(libFile(file));
  final int start = lines.indexWhere(
    (String l) => RegExp('^class\\s+$className\\b').hasMatch(l),
  );
  expect(start, greaterThanOrEqualTo(0),
      reason: '🔴 `$className` introuvable — la garde serait VACUELLE');
  final List<String> body = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\}').hasMatch(lines[i])) break;
    body.add(lines[i]);
  }
  expect(body.length, greaterThan(20),
      reason: '🔴 corps de classe quasi vide : découpeur cassé');
  final RegExp getter = RegExp(r'^\s{2}[\w<>?,\s.]*\bget\s+(\w+)\b');
  final RegExp field = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*\s(\w+)\s*[;=]');
  final RegExp method = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*\(');
  final Set<String> names = <String>{};
  for (final String l in body) {
    if (!RegExp(r'^\s{2}\S').hasMatch(l)) continue;
    final RegExpMatch? m =
        getter.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m == null) continue;
    final String name = m.group(1)!;
    if (name.startsWith('_')) continue;
    if (name == className) continue;
    if (name == 'override') continue;
    names.add(name);
  }
  return names;
}

void main() {
  group('🔴 CR90-B — la pièce de transcript : UNE amorce, un relais', () {
    test('`attach` est appelé UNE fois sur deux instantanés ; le second est '
        'RELAYÉ avec les identités changées, sans couper une requête en vol',
        () async {
      final _Rig r = await _rig();
      // `attach` est le SEUL déclencheur de `notifyListeners` du contrôleur
      // de conversation : compter ses notifications compte les `attach`.
      final _Tally attaches = _Tally(r.chat);
      expect(r.binding.isAttached, isTrue);
      expect(r.chat.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1']);
      expect(r.relayed, isEmpty, reason: 'le premier instantané AMORCE, il n\'est pas relayé');

      // Une requête en vol, qu'un second instantané ne doit PAS annuler.
      r.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = r.chat.send();
      await pumpEventQueue();
      expect(r.chat.activeRequests.value, hasLength(1));
      // L'écriture de la question a fait ré-émettre le dépôt : ce second
      // instantané est relayé avec la seule identité nouvelle.
      expect(r.relayed.map(((List<ZChatMessage>, Set<String>) e) => e.$2),
          <Set<String>>[<String>{'c1:0'}],
          reason: '🔴 l\'instantané qui suit l\'écriture n\'est pas relayé tel quel');

      await r.transcript.inner.update(_assistant('r1', 'réponse une, éditée'));
      await pumpEventQueue();
      expect(attaches.count, 0, reason: '🔴 `attach` rebranché sur un instantané');
      expect(r.chat.activeRequests.value, hasLength(1),
          reason: '🔴 le second instantané a coupé la requête en vol');
      expect(r.relayed, hasLength(2), reason: '🔴 le troisième instantané n\'est pas relayé');
      expect(r.relayed.last.$2, <String>{'r1'},
          reason: '🔴 les identités changées ne sont pas celles du diff');
      expect(r.binding.latest.map((ZChatMessage m) => m.content),
          contains('réponse une, éditée'),
          reason: '`latest` suit le dépôt');

      r.stream.last.add(done(id: 'a2'));
      await r.stream.closeAll();
      await sending;
      await pumpEventQueue();
    });

    test('un tour réglé ⇒ `append` UNE fois par message, avec le message '
        'FINAL : la question, puis la réponse — jamais `update`', () async {
      final _Rig r = await _rig();
      await _turn(r, 'question deux', 'réponse deux');
      expect(r.transcript.appends.map((ZChatMessage m) => m.role),
          <ZChatRole>[ZChatRole.user, ZChatRole.assistant],
          reason: '🔴 ordre ou nombre d\'`append` : ${r.transcript.appends}');
      expect(r.transcript.appends[0].content, 'question deux');
      expect(r.transcript.appends[1].id, 'a2');
      expect(r.transcript.appends[1].content, 'réponse deux',
          reason: '🔴 la réponse écrite n\'est pas le message FINAL');
      expect(r.transcript.updates, isEmpty,
          reason: '🔴 un message nouveau a été écrit par `update`');
      expect(r.binding.lastFailure.value, isNull);
      // Ce qui vient du dépôt n'y retourne pas.
      expect(r.transcript.appends.map((ZChatMessage m) => m.id),
          isNot(contains('q1')));
    });

    test('un message CONNU qui change ⇒ `update`, pas `append`', () async {
      final _Rig r = await _rig();
      // Le seul geste qui remplace un message connu à identité constante
      // dans le fil du contrôleur est un rebranchement du fil : il suffit à
      // prouver la branche `update`.
      r.chat.attach(conversationId: 'c1', messages: <ZChatMessage>[
        _user('q1', 'question une'),
        _assistant('r1', 'réponse une, corrigée'),
      ]);
      await pumpEventQueue();
      expect(r.transcript.updates.map((ZChatMessage m) => m.id), <String>['r1'],
          reason: '🔴 le message connu n\'a pas été mis à jour');
      expect(r.transcript.updates.single.content, 'réponse une, corrigée');
      expect(r.transcript.appends, isEmpty,
          reason: '🔴 un message connu a été ré-ajouté');
    });

    test('un `Left` d\'écriture est PUBLIÉ dans `lastFailure`, le fil local '
        'reste intact', () async {
      final _Rig r = await _rig(wrap: _Failing.new);
      final _Tally failures = _Tally(r.binding.lastFailure);
      await _turn(r, 'question deux', 'réponse deux');
      expect(r.binding.lastFailure.value, const ZCacheFailure('disk full'));
      expect(failures.count, greaterThanOrEqualTo(1));
      expect(r.transcript.appends, hasLength(2));
      expect(r.chat.messages.value, hasLength(4),
          reason: 'l\'échec d\'écriture ne coûte rien au fil affiché');
    });

    test('un port qui LÈVE à l\'écriture est publié en `ZDomainFailure`, '
        'jamais levé', () async {
      final _Rig r = await _rig(wrap: _Throwing.new);
      r.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = r.chat.send();
      await pumpEventQueue();
      expect(r.binding.lastFailure.value, isA<ZDomainFailure>(),
          reason: '🔴 l\'exception du port n\'est pas publiée');
      r.stream.last.add(done(id: 'a2'));
      await r.stream.closeAll();
      await sending;
      await pumpEventQueue();
    });

    test('un fil ILLISIBLE ouvre un fil VIERGE : erreur avant tout instantané, '
        'ou `messages` qui lève à l\'appel', () async {
      final StreamController<List<ZChatMessage>> broken =
          StreamController<List<ZChatMessage>>();
      final FakeStreamPort stream = FakeStreamPort();
      final ZChatController chat = _chat(stream);
      addTearDown(chat.dispose);
      final _Tally attaches = _Tally(chat);
      final ZChatTranscriptBinding binding = ZChatTranscriptBinding(
        transcript: _BrokenRead(broken.stream),
        chat: chat,
        conversationId: 'c1',
      );
      addTearDown(binding.dispose);
      broken.addError(StateError('firestore down'));
      await broken.close();
      await pumpEventQueue();
      expect(attaches.count, 1, reason: '🔴 pas d\'amorce sur un fil illisible');
      expect(chat.messages.value, isEmpty);

      final ZChatController chat2 = _chat(stream);
      addTearDown(chat2.dispose);
      final _Tally attaches2 = _Tally(chat2);
      final ZChatTranscriptBinding binding2 = ZChatTranscriptBinding(
        transcript: _ThrowingRead(),
        chat: chat2,
        conversationId: 'c1',
      );
      addTearDown(binding2.dispose);
      await pumpEventQueue();
      expect(attaches2.count, 1, reason: '🔴 un port qui lève à l\'appel tue l\'écran');
      expect(binding2.isAttached, isTrue);
    });

    test('`dispose` ANNULE : la source voit le `cancel`, plus aucune écriture, '
        'plus aucune amorce', () async {
      bool cancelled = false;
      final StreamController<List<ZChatMessage>> source =
          StreamController<List<ZChatMessage>>(onCancel: () => cancelled = true);
      addTearDown(source.close);
      final FakeStreamPort stream = FakeStreamPort();
      final ZChatController chat = _chat(stream);
      addTearDown(chat.dispose);
      final _Recording transcript = _Recording(ZChatInMemoryTranscript());
      addTearDown(transcript.inner.dispose);
      final ZChatTranscriptBinding binding = ZChatTranscriptBinding(
        transcript: _BrokenRead(source.stream),
        chat: chat,
        conversationId: 'c1',
      );
      final _Tally attaches = _Tally(chat);
      // Pas encore amorcé : `dispose` avant tout instantané.
      expect(cancelled, isFalse);
      binding.dispose();
      await pumpEventQueue();
      expect(cancelled, isTrue, reason: '🔴 l\'abonnement survit au dispose');
      source.add(<ZChatMessage>[_assistant('r1', 'après dispose')]);
      await pumpEventQueue();
      expect(attaches.count, 0, reason: '🔴 un instantané a amorcé après dispose');

      // Plus aucun écouteur du fil : un message nouveau n'est pas écrit.
      final ZChatController chat2 = _chat(stream);
      addTearDown(chat2.dispose);
      final ZChatTranscriptBinding binding2 = ZChatTranscriptBinding(
        transcript: transcript,
        chat: chat2,
        conversationId: 'c1',
      );
      await pumpEventQueue();
      binding2.dispose();
      chat2.attach(conversationId: 'c1', messages: <ZChatMessage>[_user('q9', 'x')]);
      await pumpEventQueue();
      expect(transcript.appends, isEmpty,
          reason: '🔴 un écouteur du fil survit au dispose');
      expect(transcript.cancels, 1);
    });
  });

  group('🔴 CR90-C — `ZChatConversationController` compose la pièce', () {
    test('AVEC `transcript` : le fil vient du dépôt, `initialMessages` n\'est '
        'pas lu, chaque tour est écrit, `dispose` libère', () async {
      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      await inner.append(_user('q1', 'question une'));
      await inner.append(_assistant('r1', 'réponse une'));
      final _Recording transcript = _Recording(inner);
      final FakeStreamPort stream = FakeStreamPort();
      addTearDown(stream.closeAll);
      final ZChatConversationController c = ZChatConversationController(
        streamPort: stream,
        conversationId: 'c1',
        transcript: transcript,
        initialMessages: <ZChatMessage>[_user('x0', 'ignoré')],
      );
      await pumpEventQueue();
      expect(c.isPersisted, isTrue);
      expect(c.chat.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1'],
          reason: '🔴 le fil n\'est pas celui du dépôt');
      expect(transcript.appends, isEmpty,
          reason: '🔴 `initialMessages` a été écrit au dépôt');

      c.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = c.chat.send();
      await pumpEventQueue();
      stream.last.add(tok('réponse deux'));
      stream.last.add(done(id: 'a2'));
      await stream.closeAll();
      await sending;
      await pumpEventQueue();
      expect(transcript.appends.map((ZChatMessage m) => m.content),
          <String>['question deux', 'réponse deux']);
      expect(c.lastFailure.value, isNull);
      expect(c.messageById('a2')?.content, 'réponse deux');
      expect(c.replyToOf('a2')?.content, 'question deux');
      expect(c.contentOf('q1'), 'question une');

      expect(transcript.opens, 1);
      c.dispose();
      await pumpEventQueue();
      expect(transcript.cancels, 1, reason: '🔴 l\'abonnement survit au dispose');
      expect(() => c.chat.composer.addListener(() {}), throwsFlutterError,
          reason: 'le contrôleur composé est libéré');
    });

    test('AVEC `transcript` : `initialMessages` n\'est pas lu, MÊME avant le '
        'premier instantané — le fil est vide tant que le dépôt n\'a pas parlé',
        () async {
      final StreamController<List<ZChatMessage>> silent =
          StreamController<List<ZChatMessage>>();
      addTearDown(silent.close);
      final FakeStreamPort stream = FakeStreamPort();
      final ZChatConversationController c = ZChatConversationController(
        streamPort: stream,
        conversationId: 'c1',
        transcript: _BrokenRead(silent.stream),
        initialMessages: <ZChatMessage>[_user('x0', 'fil statique')],
      );
      addTearDown(c.dispose);
      await pumpEventQueue();
      expect(c.chat.messages.value, isEmpty,
          reason: '🔴 `initialMessages` affiché alors qu\'un dépôt est fourni');
      silent.add(<ZChatMessage>[_user('q1', 'question une')]);
      await pumpEventQueue();
      expect(c.chat.messages.value.single.id, 'q1');
    });

    test('AVEC `transcript` : un `Left` d\'écriture est sur `lastFailure` du '
        'contrôleur — la tranche est CELLE de la pièce', () async {
      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      final _Failing failing = _Failing(inner);
      final FakeStreamPort stream = FakeStreamPort();
      addTearDown(stream.closeAll);
      final ZChatConversationController c = ZChatConversationController(
        streamPort: stream,
        conversationId: 'c1',
        transcript: failing,
      );
      addTearDown(c.dispose);
      await pumpEventQueue();
      c.chat.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = c.chat.send();
      await pumpEventQueue();
      expect(c.lastFailure.value, const ZCacheFailure('disk full'));
      expect(c.chat.lastFailure.value, isNull,
          reason: 'un échec d\'écriture n\'est pas un échec de tour');
      stream.last.add(done(id: 'a1'));
      await stream.closeAll();
      await sending;
      await pumpEventQueue();
    });

    test('SANS `transcript` : ÉTALON — `initialMessages` est la source (mêmes '
        'instances), `lastFailure` reste `null`, rien n\'est persisté', () async {
      final List<ZChatMessage> initial = <ZChatMessage>[
        _user('q1', 'question une'),
        _assistant('r1', 'réponse une'),
      ];
      final FakeStreamPort stream = FakeStreamPort();
      addTearDown(stream.closeAll);
      final ZChatConversationController c = ZChatConversationController(
        streamPort: stream,
        conversationId: 'c1',
        initialMessages: initial,
      );
      addTearDown(c.dispose);
      final _Tally attaches = _Tally(c.chat);
      await pumpEventQueue();
      expect(c.isPersisted, isFalse);
      expect(attaches.count, 0, reason: '🔴 une amorce sans dépôt');
      expect(c.chat.messages.value, hasLength(2));
      for (int i = 0; i < initial.length; i++) {
        expect(identical(c.chat.messages.value[i], initial[i]), isTrue,
            reason: '🔴 le fil initial a été copié ou remplacé (index $i)');
      }
      c.chat.composer.text = 'question deux';
      final Future<ZResult<ZChatRequestToken>> sending = c.chat.send();
      await pumpEventQueue();
      stream.last.add(tok('réponse deux'));
      stream.last.add(done(id: 'a2'));
      await stream.closeAll();
      await sending;
      await pumpEventQueue();
      expect(c.lastFailure.value, isNull);
      expect(c.chat.messages.value, hasLength(4));
    });
  });

  group('🔴 CR90-S — `ZChatConversationScreen(transcript:)`', () {
    testWidgets('AVEC `transcript` : UN abonnement sur deux `build`, le fil '
        'affiché est celui du dépôt, l\'envoi est persisté, `dispose` libère',
        (WidgetTester tester) async {
      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      await inner.append(_user('q1', 'question une'));
      await inner.append(_assistant('r1', 'réponse une'));
      final _Recording transcript = _Recording(inner);
      final FakeStreamPort stream = FakeStreamPort();
      addTearDown(stream.closeAll);
      Widget screen({List<String> hints = const <String>[]}) => harness(
            ZChatConversationScreen(
              streamPort: stream,
              transcript: transcript,
              conversationId: 'c1',
              initialMessages: <ZChatMessage>[_user('x0', 'fil statique ignoré')],
              cursorColor: const Color(0xFF000000),
              hints: hints,
            ),
          );
      await tester.pumpWidget(screen());
      await tester.pump();
      expect(find.text('réponse une'), findsOneWidget,
          reason: '🔴 le fil affiché n\'est pas celui du dépôt');
      expect(find.text('fil statique ignoré'), findsNothing,
          reason: '🔴 `initialMessages` lu malgré le dépôt');
      await tester.pumpWidget(screen(hints: const <String>['x']));
      await tester.pump();
      expect(transcript.opens, 1, reason: '🔴 le fil a été rouvert : contrôleur recréé');

      final ZChatController chat = tester
          .widget<ZChatConversationView>(find.byType(ZChatConversationView))
          .controller;
      chat.composer.text = 'question deux';
      unawaited(chat.send());
      await tester.pump();
      stream.last.add(tok('réponse deux'));
      stream.last.add(done(id: 'a2'));
      await stream.closeAll();
      await tester.pump();
      await tester.pump();
      expect(transcript.appends.map((ZChatMessage m) => m.content),
          <String>['question deux', 'réponse deux'],
          reason: '🔴 l\'envoi n\'est pas persisté');

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(transcript.cancels, 1,
          reason: '🔴 `dispose` n\'a pas libéré l\'abonnement au dépôt');
    });

    testWidgets('SANS `transcript` : `initialMessages` reste la source et une '
        'SEULE tranche d\'échec est montée ; avec, DEUX', (WidgetTester tester) async {
      final FakeStreamPort stream = FakeStreamPort();
      addTearDown(stream.closeAll);
      Widget? failure(BuildContext _, ZFailure f) => Text(f.toString());
      await tester.pumpWidget(harness(ZChatConversationScreen(
        streamPort: stream,
        conversationId: 'c1',
        initialMessages: <ZChatMessage>[_assistant('r1', 'réponse statique')],
        cursorColor: const Color(0xFF000000),
        failureBuilder: failure,
      )));
      await tester.pump();
      expect(find.text('réponse statique'), findsOneWidget);
      expect(find.byType(ValueListenableBuilder<ZFailure?>), findsOneWidget,
          reason: '🔴 sans dépôt, l\'arbre doit être celui d\'aujourd\'hui : '
              'une tranche d\'échec (tour), pas deux');
      await tester.pumpWidget(const SizedBox());

      final ZChatInMemoryTranscript inner = ZChatInMemoryTranscript();
      addTearDown(inner.dispose);
      await tester.pumpWidget(harness(ZChatConversationScreen(
        streamPort: stream,
        transcript: inner,
        conversationId: 'c1',
        cursorColor: const Color(0xFF000000),
        failureBuilder: failure,
      )));
      await tester.pump();
      expect(find.byType(ValueListenableBuilder<ZFailure?>), findsNWidgets(2),
          reason: '🔴 avec dépôt, l\'échec d\'écriture du fil n\'est pas présenté');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('🔴 CR90-G — gardes de source', () {
    test('la MÉCANIQUE n\'existe qu\'en UN site de `lib/` : écritures, '
        'lecture et abonnement au dépôt vivent dans la pièce partagée', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<RegExp> mechanic = <RegExp>[
        RegExp(r'\.append\('),
        RegExp(r'\.update\('),
        RegExp(r'zChatTranscriptOrEmpty\('),
        RegExp(r'\.messages\(\w*\)'),
        RegExp(r'\b_listen\('),
      ];
      final List<String> offenders = <String>[];
      int inBinding = 0;
      for (final MapEntry<String, List<String>> e in lib.entries) {
        final bool binding = e.key.replaceAll(r'\', '/').endsWith(_bindingFile);
        for (int i = 0; i < e.value.length; i++) {
          for (final RegExp m in mechanic) {
            if (!m.hasMatch(e.value[i])) continue;
            if (binding) {
              inBinding++;
            } else {
              offenders.add('${e.key}:${i + 1} → ${m.pattern}');
            }
          }
        }
      }
      expect(inBinding, greaterThanOrEqualTo(3),
          reason: '🔴 GARDE VACUELLE : la pièce partagée ne porte pas la mécanique');
      expect(offenders, isEmpty,
          reason: '🔴 la mécanique de transcript est DUPLIQUÉE hors de '
              '`$_bindingFile` :\n${offenders.join('\n')}');
    });

    test('les DEUX contrôleurs COMPOSENT la pièce — une construction chacun, '
        'et le fil de travail n\'a plus ni abonnement ni base d\'écriture à lui', () {
      // `(` suivi de `{` est la DÉCLARATION du constructeur, pas un site.
      final RegExp ctor = RegExp(r'\bZChatTranscriptBinding\((?!\{)');
      final Map<String, List<String>> lib = strippedLib();
      final Map<String, int> sites = <String, int>{};
      for (final MapEntry<String, List<String>> e in lib.entries) {
        final int n = e.value.where(ctor.hasMatch).length;
        if (n > 0) sites[e.key.replaceAll(r'\', '/')] = n;
      }
      expect(sites.keys.map((String k) => k.split('/lib/').last).toSet(),
          <String>{
            _notebookFile.replaceFirst('lib/', ''),
            _conversationFile.replaceFirst('lib/', ''),
          },
          reason: '🔴 sites de composition : $sites');
      expect(sites.values.toSet(), <int>{1});
      final String notebook = stripped(libFile(_notebookFile)).join('\n');
      for (final String gone in <String>[
        'StreamSubscription',
        '_written',
        '_attached',
        'ZChatTranscriptPort _transcript',
      ]) {
        expect(notebook.contains(gone), isFalse,
            reason: '🔴 `$gone` : le fil de travail garde une copie de la mécanique');
      }
    });

    test('la surface du fil de travail est INCHANGÉE — égalité d\'ensemble', () {
      expect(_publicMembers(_notebookFile, 'ZChatNotebookController'), <String>{
        'chat',
        'conversationId',
        'registry',
        'readOnly',
        'lastFailure',
        'liveAnnouncement',
        'markArtifact',
        'statusOf',
        'failureOf',
        'verbsFor',
        'messageById',
        'replyToOf',
        'contentOf',
        'setReadOnly',
        'runArtifactVerb',
        'cancelArtifact',
        'refreshArtifact',
        'dispose',
      });
    });

    test('la surface de la conversation simple et de la pièce — égalité '
        'd\'ensemble', () {
      expect(
        _publicMembers(_conversationFile, 'ZChatConversationController'),
        <String>{
          'chat',
          'conversationId',
          'isPersisted',
          'lastFailure',
          'messageById',
          'replyToOf',
          'contentOf',
          'dispose',
        },
      );
      expect(_publicMembers(_bindingFile, 'ZChatTranscriptBinding'), <String>{
        'conversationId',
        'latest',
        'isAttached',
        'lastFailure',
        'dispose',
      });
    });

    test('l\'écran RELAIE `transcript` au contrôleur de conversation et le '
        'libère', () {
      final String src = stripped(libFile(_screenFile)).join('\n');
      expect(RegExp(r'transcript:\s*widget\.transcript\b').hasMatch(src), isTrue,
          reason: '🔴 `transcript` est déclaré mais n\'atteint pas le contrôleur');
      expect(src.contains('_conversation.dispose()'), isTrue,
          reason: '🔴 le contrôleur de conversation n\'est pas libéré');
      expect(RegExp(r'\bZChatTranscriptBinding\b').hasMatch(src), isFalse,
          reason: '🔴 l\'écran compose la pièce lui-même, à côté du contrôleur');
    });

    test('🔬 contre-preuve — les motifs de la garde de site VOIENT une copie', () {
      expect(RegExp(r'\.append\(').hasMatch('    unawaited(_t.append(m));'), isTrue);
      expect(RegExp(r'\.messages\(\w*\)').hasMatch('  transcript.messages(id)'), isTrue);
      expect(RegExp(r'\.messages\(\w*\)').hasMatch('  chat.messages.value'), isFalse,
          reason: 'la tranche `messages` du contrôleur n\'est pas une lecture du dépôt');
      expect(RegExp(r'\b_listen\(').hasMatch('    _subscription = _listen(() => x);'), isTrue);
    });
  });
}
