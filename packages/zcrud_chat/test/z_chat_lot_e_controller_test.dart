// Lot E — garanties et capacités du contrôleur : annulation (E1), édition
// rejouée (E2), requêtes sur le fil (E3), régénération (E4), annonces (E5).
//
// Gardes DÉJÀ existantes, citées et non doublonnées :
// * `z_chat_token_lifecycle_test.dart:35`  — deux flux s'annulent
//   INDÉPENDAMMENT (`t0.isCancelled`, `t1` intact) ;
// * `z_chat_token_lifecycle_test.dart:183` — une annulation volontaire n'est
//   JAMAIS reprise, phase `cancelled` ;
// * `z_chat_action_flow_test.dart:133`     — saisie intacte, partiel conservé
//   en message d'assistant, `Left` avec `cancelledByUser == true` ;
// * `z_chat_structure_guard_test.dart` G-CH1 — AUCUN `cancel()` public : le
//   seul chemin est `runAction(ZChatCancelAction(requestId))`.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';

/// Port de cycle de vie PILOTÉ : `trimAfter` rend ce que le test décide et
/// photographie la longueur du fil AU MOMENT de l'appel (preuve d'ordre).
class FakeLifecycle implements ZChatConversationLifecyclePort {
  FakeLifecycle(this._threadLength);

  final int Function() _threadLength;
  final List<({String conversationId, String messageId, int threadAtCall})>
      trims = <({String conversationId, String messageId, int threadAtCall})>[];
  ZFailure? failWith;
  Object? throwWith;

  @override
  Future<ZResult<int>> trimAfter({
    required String conversationId,
    required String messageId,
  }) async {
    trims.add((
      conversationId: conversationId,
      messageId: messageId,
      threadAtCall: _threadLength(),
    ));
    final Object? boom = throwWith;
    if (boom != null) throw boom;
    final ZFailure? f = failWith;
    if (f != null) return Left<ZFailure, int>(f);
    return const Right<ZFailure, int>(1);
  }

  @override
  Future<ZResult<Unit>> retire(String conversationId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> restore(String conversationId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<int>> retireAll(List<String> conversationIds) async =>
      const Right<ZFailure, int>(0);
}

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

/// Fil de référence : Q1 → R1 → Q2 → R2.
List<ZChatMessage> _thread() => <ZChatMessage>[
      _user('q1', 'première question'),
      _assistant('r1', 'première réponse'),
      _user('q2', 'seconde question'),
      _assistant('r2', 'seconde réponse'),
    ];

/// Contrôleur câblé AVEC le port de cycle de vie (capacités natives).
({
  ZChatController controller,
  FakeStreamPort port,
  SpyExecutor executor,
  FakeLifecycle lifecycle,
}) buildNative({
  List<ZChatMessage> initialMessages = const <ZChatMessage>[],
  ZChatLiveLabels labels = ZChatLiveLabels.none,
}) {
  final FakeStreamPort port = FakeStreamPort();
  final SpyExecutor executor = SpyExecutor();
  final SeqIds ids = SeqIds();
  late final ZChatController controller;
  final FakeLifecycle lifecycle = FakeLifecycle(
    () => controller.messages.value.length,
  );
  controller = ZChatController(
    streamPort: port,
    actionExecutor: executor,
    confirm: (ZChatActionPlan _) async => true,
    newRequestId: ids.next,
    buildRequest: (ZChatDraft draft) => ZChatGenerationRequest(
      style: ZChatGenerationStyle('test'),
      subject: draft.text,
      attachmentIds: draft.attachmentIds,
    ),
    lifecycle: lifecycle,
    liveLabels: labels,
    conversationId: 'c1',
    initialMessages: initialMessages,
  );
  return (
    controller: controller,
    port: port,
    executor: executor,
    lifecycle: lifecycle,
  );
}

void main() {
  group('🔴 E1 — la garantie d\'annulation, écrite ET gardée', () {
    test('le port est NOTIFIÉ par `whenCancelled` du jeton désigné, et son '
        'abonnement est fermé', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      final ZChatRequestToken token = harness.port.calls.single.token;
      bool portNotified = false;
      unawaited(token.whenCancelled.then((_) => portNotified = true));
      bool subscriptionCancelled = false;
      harness.port.last.onCancel = () => subscriptionCancelled = true;

      await c.runAction(const ZChatCancelAction(requestId: 'r0'));
      await sending;
      await pumpEventQueue();

      expect(portNotified, isTrue,
          reason: '🔴 `whenCancelled` ne s\'est pas résolu : le port ne peut '
              'pas fermer son transport — la génération serveur continue');
      expect(subscriptionCancelled, isTrue,
          reason: '🔴 l\'abonnement au flux n\'a pas été fermé');
    });

    test('le partiel reçu est CONSERVÉ et MARQUÉ interrompu ; phase '
        '`cancelled` ; `Left` voulu', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('partiel '));
      harness.port.last.add(tok('reçu'));
      await pumpEventQueue();

      await c.runAction(const ZChatCancelAction(requestId: 'r0'));
      final ZResult<ZChatRequestToken> res = await sending;
      await pumpEventQueue();

      final ZChatMessage last = c.messages.value.last;
      expect(last.role, ZChatRole.assistant);
      expect(c.contentOf(last.id!), 'partiel reçu',
          reason: '🔴 le partiel est PERDU — le défaut lex C2');
      expect(c.isInterrupted(last.id!), isTrue,
          reason: '🔴 conservé mais pas MARQUÉ : la vue ne peut pas signaler '
              'une réponse tronquée');
      expect(last.id, isNot('r0'),
          reason: '🔴 la réponse partielle porte l\'identité de la QUESTION '
              'optimiste : `messageById` ne peut plus les distinguer');
      expect(c.contentOf('r0'), 'question',
          reason: 'la question optimiste reste adressable par `requestId`');
      expect(c.progress('r0').value.phase, ZChatPhase.cancelled);
      expect(c.activeRequests.value, isEmpty);
      expect(
        res.fold((ZFailure f) => f, (_) => null),
        isA<ZChatStreamInterruptedFailure>()
            .having((e) => e.cancelledByUser, 'cancelledByUser', isTrue),
      );
    });

    test('une réponse ACHEVÉE n\'est pas marquée interrompue ; une identité '
        'inconnue rend `false`, jamais une exception', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('ok'));
      harness.port.last.add(done(id: 'm1'));
      await sending;
      await pumpEventQueue();

      expect(c.isInterrupted('m1'), isFalse);
      expect(c.isInterrupted('inconnu'), isFalse);
    });

    test('`attach` OUBLIE les marques d\'interruption de l\'ancienne '
        'conversation', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('partiel'));
      await pumpEventQueue();
      await c.runAction(const ZChatCancelAction(requestId: 'r0'));
      await sending;
      await pumpEventQueue();
      final String partialId = c.messages.value.last.id!;
      expect(c.isInterrupted(partialId), isTrue);

      c.attach(conversationId: 'c2');
      expect(c.isInterrupted(partialId), isFalse);
    });
  });

  group('🔴 E3 — requêtes PURES sur le fil', () {
    test('`messageById` / `replyToOf` / `contentOf` — O(n), jamais '
        'd\'exception, `null` si absent', () {
      final harness = buildController(initialMessages: _thread());
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      expect(c.messageById('q2')?.role, ZChatRole.user);
      expect(c.messageById('absent'), isNull);
      expect(c.replyToOf('q1')?.id, 'r1',
          reason: 'question → SA réponse');
      expect(c.replyToOf('r2')?.id, 'q2',
          reason: 'réponse → SA question');
      expect(c.replyToOf('absent'), isNull);
      expect(c.contentOf('r1'), 'première réponse');
      expect(c.contentOf('absent'), isNull);
    });

    test('`replyToOf` ne traverse JAMAIS une autre question : une question '
        'sans réponse rend `null`', () {
      final harness = buildController(
        initialMessages: <ZChatMessage>[
          _user('q1', 'a'),
          _user('q2', 'b'),
          _assistant('r2', 'c'),
        ],
      );
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      expect(c.replyToOf('q1'), isNull,
          reason: '🔴 `r2` répond à `q2`, pas à `q1`');
      expect(c.replyToOf('q2')?.id, 'r2');
    });

    test('`contentOf` ne garde que les blocs de TEXTE, joints par un saut '
        'de ligne', () {
      final harness = buildController(
        initialMessages: <ZChatMessage>[
          ZChatMessage(
            id: 'm',
            role: ZChatRole.assistant,
            contentBlocks: <ZContentBlock>[
              const ZTextBlock(text: 'un'),
              ZCustomContentBlock('table', <String, dynamic>{}),
              const ZTextBlock(text: 'deux'),
            ],
          ),
        ],
      );
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      expect(c.contentOf('m'), 'un\ndeux');
    });

    test('`previewEditImpact` compte les POSTÉRIEURS ; absent ⇒ 0', () {
      final harness = buildController(initialMessages: _thread());
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      expect(c.previewEditImpact('q1'), 3);
      expect(c.previewEditImpact('q2'), 1);
      expect(c.previewEditImpact('r2'), 0);
      expect(c.previewEditImpact('absent'), 0);
    });

    test('AD-2 — une requête pure ne notifie AUCUNE tranche', () {
      final harness = buildController(initialMessages: _thread());
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      int notified = 0;
      void bump() => notified++;
      c.addListener(bump);
      c.messages.addListener(bump);
      c.liveAnnouncement.addListener(bump);
      c.editing.addListener(bump);

      c.messageById('q1');
      c.replyToOf('q1');
      c.contentOf('r1');
      c.previewEditImpact('q1');
      c.isInterrupted('r1');

      expect(notified, 0);
    });
  });

  group('🔴 E2 — édition rejouée, NATIVE avec le port, DÉLÉGUÉE sans', () {
    test('SANS port : l\'exécuteur de l\'hôte reçoit `editAndResend`, aucun '
        'flux n\'est ouvert (défaut inchangé)', () async {
      final harness = buildController(initialMessages: _thread());
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.startEditing(messageId: 'q2', originalText: 'seconde question');
      await c.runAction(
        const ZChatEditAction(messageId: 'q2', newText: 'corrigée'),
      );
      expect(harness.executor.calls['editAndResend'], 1);
      expect(harness.port.calls, isEmpty);
    });

    test('ORDRE STRICT : un `trimAfter` REFUSÉ ne détruit RIEN localement, la '
        'session reste ouverte, l\'exécuteur n\'est pas touché', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      rig.lifecycle.failWith = const ZServerFailure('refusé');

      c.startEditing(messageId: 'q2', originalText: 'seconde question');
      final ZResult<ZChatActionOutcome> res = await c.runAction(
        const ZChatEditAction(messageId: 'q2', newText: 'corrigée'),
      );

      expect(res.isLeft(), isTrue);
      expect(c.lastFailure.value, isA<ZServerFailure>());
      expect(c.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1', 'q2', 'r2'],
          reason: '🔴 destruction locale AVANT l\'accord de l\'hôte');
      expect(c.editing.value, isNotNull,
          reason: 'la session survit : l\'utilisateur peut réessayer');
      expect(rig.port.calls, isEmpty);
      expect(harnessEffects(rig.executor), 0);
    });

    test('un port qui LÈVE vaut un refus (AD-10) — même garantie', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      rig.lifecycle.throwWith = StateError('boom');

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        const ZChatEditAction(messageId: 'q2', newText: 'corrigée'),
      );
      expect(res.isLeft(), isTrue);
      expect(c.messages.value, hasLength(4));
    });

    test('SUCCÈS : `trimAfter` est appelé sur le fil ENTIER, puis troncature '
        'locale, puis nouveau tour par le cycle unique', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      c.composer.text = 'brouillon en cours';
      c.startEditing(messageId: 'q2', originalText: 'seconde question');
      final Future<ZResult<ZChatActionOutcome>> running = c.runAction(
        const ZChatEditAction(messageId: 'q2', newText: 'corrigée'),
      );
      await pumpEventQueue();

      expect(rig.lifecycle.trims.single.messageId, 'q2');
      expect(rig.lifecycle.trims.single.conversationId, 'c1');
      expect(rig.lifecycle.trims.single.threadAtCall, 4,
          reason: '🔴 le fil avait DÉJÀ été tronqué quand l\'hôte a été '
              'consulté : mauvais ordre');
      expect(rig.executor.calls['editAndResend'], isNull,
          reason: 'natif : l\'exécuteur de l\'hôte n\'est pas doublé');
      expect(rig.port.calls, hasLength(1));
      expect(rig.port.calls.single.request.subject, 'corrigée');
      expect(c.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1', 'r0'],
          reason: 'le message édité et ses postérieurs partent ; la question '
              'corrigée est ré-émise (message optimiste `r0`)');
      expect(c.editing.value, isNull, reason: 'la session est close');
      expect(c.composer.text, isEmpty,
          reason: 'le nouveau tour a vidé la saisie (comme `send`)');

      rig.port.last.add(tok('nouvelle réponse'));
      rig.port.last.add(done(id: 'r3'));
      final ZResult<ZChatActionOutcome> res = await running;
      await pumpEventQueue();

      expect(res.isRight(), isTrue);
      expect(res.fold((_) => null, (o) => o.affectedMessageIds),
          <String>['q2', 'r2']);
      expect(c.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1', 'r0', 'r3']);
    });

    test('ROLLBACK : si le nouveau tour n\'a RIEN produit, les messages '
        'retirés localement sont RESTITUÉS et le texte corrigé revient dans '
        'la saisie', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      c.startEditing(messageId: 'q2', originalText: 'seconde question');
      final Future<ZResult<ZChatActionOutcome>> running = c.runAction(
        const ZChatEditAction(messageId: 'q2', newText: 'corrigée'),
      );
      await pumpEventQueue();
      rig.port.last.add(interrupted('r0'));
      final ZResult<ZChatActionOutcome> res = await running;
      await pumpEventQueue();

      expect(res.isLeft(), isTrue);
      expect(c.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1', 'q2', 'r2'],
          reason: '🔴 une panne du nouveau tour a coûté la fin du fil');
      expect(c.composer.text, 'corrigée',
          reason: 'une panne ne coûte pas la frappe (AD-10)');
    });

    test('un message ABSENT du fil : `Left(ZNotFoundFailure)`, aucun appel '
        'au port', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        const ZChatEditAction(messageId: 'nope', newText: 'x'),
      );
      expect(res.fold((ZFailure f) => f, (_) => null),
          isA<ZNotFoundFailure>());
      expect(rig.lifecycle.trims, isEmpty);
    });
  });

  group('🔴 E4 — régénération : REMPLACER, jamais ajouter', () {
    test('SANS port : l\'exécuteur de l\'hôte reçoit `regenerate` (défaut '
        'inchangé)', () async {
      final harness = buildController(initialMessages: _thread());
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      await c.runAction(const ZChatRegenerateAction(messageId: 'r1'));
      expect(harness.executor.calls['regenerate'], 1);
      expect(harness.port.calls, isEmpty);
    });

    test('NATIF : la réponse visée est remplacée À SA PLACE, la question '
        'n\'est pas ré-émise, la requête est rebâtie depuis la question '
        'appariée', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      final Future<ZResult<ZChatActionOutcome>> running = c.runAction(
        const ZChatRegenerateAction(messageId: 'r1'),
      );
      await pumpEventQueue();

      expect(rig.lifecycle.trims.single.messageId, 'q1',
          reason: 'l\'élagage vise la QUESTION : tout ce qui la suit est '
              'remplacé');
      expect(rig.port.calls.single.request.subject, 'première question');
      expect(c.messages.value.map((ZChatMessage m) => m.id), <String>['q1'],
          reason: 'aucun message optimiste : la question existe déjà');
      expect(rig.executor.calls['regenerate'], isNull);

      rig.port.last.add(tok('réponse régénérée'));
      rig.port.last.add(done(id: 'r1b'));
      final ZResult<ZChatActionOutcome> res = await running;
      await pumpEventQueue();

      expect(res.isRight(), isTrue);
      expect(c.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1b'],
          reason: '🔴 la nouvelle réponse a été AJOUTÉE au lieu de REMPLACER');
      expect(c.contentOf('r1b'), 'réponse régénérée');
    });

    test('NATIF : une réponse produite DANS la session rejoue la requête '
        'D\'ORIGINE telle quelle, réglages de l\'action par-dessus', () async {
      final rig = buildNative();
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send(
        settings: const ZChatGenerationSettings(
          responseLength: ZChatResponseLength.concise,
        ),
      );
      await pumpEventQueue();
      rig.port.last.add(tok('réponse'));
      rig.port.last.add(done(id: 'm1'));
      await sending;
      await pumpEventQueue();
      final ZChatGenerationRequest original = rig.port.calls.single.request;

      final Future<ZResult<ZChatActionOutcome>> running = c.runAction(
        const ZChatRegenerateAction(messageId: 'm1'),
      );
      await pumpEventQueue();
      expect(identical(rig.port.calls[1].request, original), isTrue,
          reason: '🔴 la requête d\'origine n\'est pas rejouée telle quelle');

      rig.port.last.add(tok('bis'));
      rig.port.last.add(done(id: 'm2'));
      await running;
      await pumpEventQueue();

      // Avec réglages : la requête est DÉRIVÉE de l'origine, pas rebâtie.
      final Future<ZResult<ZChatActionOutcome>> again = c.runAction(
        const ZChatRegenerateAction(
          messageId: 'm2',
          settings: ZChatGenerationSettings(
            responseLength: ZChatResponseLength.detailed,
          ),
        ),
      );
      await pumpEventQueue();
      expect(rig.port.calls[2].request.responseLength,
          ZChatResponseLength.detailed);
      expect(rig.port.calls[2].request.subject, original.subject);
      rig.port.last.add(done(id: 'm3'));
      await again;
    });

    test('ROLLBACK : un tour qui ne produit RIEN restitue l\'ancienne réponse '
        'à sa place', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      final Future<ZResult<ZChatActionOutcome>> running = c.runAction(
        const ZChatRegenerateAction(messageId: 'r1'),
      );
      await pumpEventQueue();
      rig.port.last.add(interrupted('r0'));
      final ZResult<ZChatActionOutcome> res = await running;
      await pumpEventQueue();

      expect(res.isLeft(), isTrue);
      expect(c.messages.value.map((ZChatMessage m) => m.id),
          <String>['q1', 'r1', 'q2', 'r2'],
          reason: '🔴 l\'échec a coûté la réponse qu\'on voulait remplacer');
      expect(c.composer.text, isEmpty,
          reason: 'aucune saisie n\'est restituée : il n\'y en avait pas');
    });

    test('un `trimAfter` REFUSÉ laisse le fil INTACT', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      rig.lifecycle.failWith = const ZServerFailure('refusé');

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        const ZChatRegenerateAction(messageId: 'r1'),
      );
      expect(res.isLeft(), isTrue);
      expect(c.messages.value, hasLength(4));
      expect(rig.port.calls, isEmpty);
    });

    test('une réponse SANS question appariée : `Left(ZNotFoundFailure)`',
        () async {
      final rig = buildNative(
        initialMessages: <ZChatMessage>[_assistant('orphan', 'x')],
      );
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        const ZChatRegenerateAction(messageId: 'orphan'),
      );
      expect(res.fold((ZFailure f) => f, (_) => null),
          isA<ZNotFoundFailure>());
      expect(rig.lifecycle.trims, isEmpty);
    });

    test('AD-2 — une régénération native ne déclenche JAMAIS le canal global '
        '(`notifyListeners`)', () async {
      final rig = buildNative(initialMessages: _thread());
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      int global = 0;
      c.addListener(() => global++);

      final Future<ZResult<ZChatActionOutcome>> running = c.runAction(
        const ZChatRegenerateAction(messageId: 'r2'),
      );
      await pumpEventQueue();
      rig.port.last.add(tok('x'));
      rig.port.last.add(done(id: 'r2b'));
      await running;
      await pumpEventQueue();

      expect(global, 0);
    });
  });

  group('🔴 E5 — annonces de région live : les TEXTES sont à l\'hôte', () {
    const ZChatLiveLabels labels = ZChatLiveLabels(
      generationStarted: '[début]',
      generationCompleted: _completed,
      generationCancelled: _cancelled,
      generationFailed: '[échec]',
      editingStarted: '[édition]',
    );

    test('avec libellés : début, fin, annulation, échec, édition sont '
        'tous annoncés', () async {
      final rig = buildNative(initialMessages: _thread(), labels: labels);
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      final List<String> heard = <String>[];
      c.liveAnnouncement.addListener(() {
        if (c.liveAnnouncement.value.isNotEmpty) {
          heard.add(c.liveAnnouncement.value);
        }
      });

      // Début + fin.
      c.composer.text = 'q';
      Future<ZResult<ZChatRequestToken>> s = c.send();
      await pumpEventQueue();
      rig.port.last.add(tok('réponse'));
      rig.port.last.add(done(id: 'm1'));
      await s;
      await pumpEventQueue();
      // Début + annulation avec partiel.
      c.composer.text = 'q';
      s = c.send();
      await pumpEventQueue();
      rig.port.last.add(tok('part'));
      await pumpEventQueue();
      await c.runAction(const ZChatCancelAction(requestId: 'r1'));
      await s;
      await pumpEventQueue();
      // Début + échec sans rien.
      c.composer.text = 'q';
      s = c.send();
      await pumpEventQueue();
      rig.port.last.add(interrupted('r2'));
      await s;
      await pumpEventQueue();
      // Édition.
      c.startEditing(messageId: 'q1', originalText: 'première question');

      expect(heard, <String>[
        '[début]',
        '[fin: réponse]',
        '[début]',
        '[annulé: part]',
        '[début]',
        '[échec]',
        '[édition]',
      ]);
    });

    test('SANS libellés : début, échec et édition sont SILENCIEUX — aucun '
        'texte inventé ; fin et annulation annoncent le CONTENU nu', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      final List<String> heard = <String>[];
      c.liveAnnouncement.addListener(() => heard.add(c.liveAnnouncement.value));

      c.composer.text = 'q';
      Future<ZResult<ZChatRequestToken>> s = c.send();
      await pumpEventQueue();
      expect(heard, isEmpty, reason: '🔴 un début a annoncé un texte — d\'où '
          'vient-il ? Le socle n\'en écrit aucun (FR-26)');
      harness.port.last.add(tok('réponse'));
      harness.port.last.add(done(id: 'm1'));
      await s;
      await pumpEventQueue();
      expect(heard, <String>['réponse']);

      c.composer.text = 'q';
      s = c.send();
      await pumpEventQueue();
      harness.port.last.add(interrupted('r1'));
      await s;
      await pumpEventQueue();
      c.startEditing(messageId: 'r0', originalText: 'q');
      expect(heard, <String>['réponse'],
          reason: 'échec sans contenu et édition : muets');
    });

    test('un MÊME texte annoncé deux fois de suite notifie DEUX fois (un '
        'jalon est un événement, pas un état)', () async {
      final rig = buildNative(labels: labels);
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      int starts = 0;
      c.liveAnnouncement.addListener(() {
        if (c.liveAnnouncement.value == '[début]') starts++;
      });

      c.composer.text = 'a';
      final Future<ZResult<ZChatRequestToken>> first = c.send();
      c.composer.text = 'b';
      final Future<ZResult<ZChatRequestToken>> second = c.send();
      await pumpEventQueue();
      expect(starts, 2,
          reason: '🔴 le second départ est resté muet : un `ValueNotifier` '
              'ignore une valeur égale');
      await rig.port.closeAll();
      await first;
      await second;
    });

    test('AD-2 — une annonce ne notifie NI `messages` NI `editing` NI le '
        'canal global', () {
      final rig = buildNative(initialMessages: _thread(), labels: labels);
      final ZChatController c = rig.controller;
      addTearDown(c.dispose);
      int others = 0;
      c.addListener(() => others++);
      c.messages.addListener(() => others++);
      c.canSend.addListener(() => others++);
      int announced = 0;
      c.liveAnnouncement.addListener(() => announced++);

      // `startEditing` écrit la saisie (canSend peut bouger) : on mesure
      // donc l'annonce seule via une édition à saisie inchangée.
      c.startEditing(messageId: 'q1', originalText: '');
      expect(announced, 1);
      expect(others, 0);
    });
  });
}

String _completed(String content) => '[fin: $content]';
String _cancelled(String partial) => '[annulé: $partial]';

/// Total des effets RÉELS de l'exécuteur (hors estimation).
int harnessEffects(SpyExecutor executor) => executor.effectCount;
