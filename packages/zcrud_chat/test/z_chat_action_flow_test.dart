/// Gardes de COMPORTEMENT des verbes — CHAT-2.
///
/// Chacune vise **un** des neuf symptômes mesurés sur l'assistant d'IFFD, tous
/// issus de la même cause racine (« un verbe = un seul site d'appel ») :
///
/// | Symptôme IFFD | Emplacement | Garde ici |
/// |---|---|---|
/// | suppression **silencieuse** avec cascade Q+R | `chatbot_conversation_screen.dart:3886` | `la confirmation PRÉCÈDE l'effet` |
/// | annuler **détruit la saisie** | `:3618-3672` | `annuler ne touche JAMAIS la saisie` |
/// | texte d'exception affiché **comme une réponse** | défaut n°4 | `un échec ne devient jamais un message` |
/// | verbe **mort** (`onTap: () {}`) | `:1513`, `:4208` | `un verbe non supporté rend un Left, jamais un silence` |
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';

void main() {
  group('🔴 la confirmation PRÉCÈDE l\'effet', () {
    test('un REFUS laisse TOUS les compteurs d\'effet à ZÉRO', () async {
      final harness = buildController(answer: false);
      addTearDown(harness.controller.dispose);

      final ZResult<ZChatActionOutcome> res = await harness.controller.runAction(
        const ZChatDeleteAction(messageId: 'm1'),
      );

      expect(harness.confirmed, hasLength(1),
          reason: '🔴 la question n\'a même pas été POSÉE — c\'est la surface B '
              'd\'IFFD (`:3886`), où supprimer était silencieux');
      expect(harness.confirmed.single.requiresConfirmation, isTrue);
      expect(harness.executor.effectCount, 0,
          reason: '🔴 un effet a été exécuté MALGRÉ le refus : '
              '${harness.executor.calls}');
      expect(res.isLeft(), isTrue);
      expect(
        res.fold((ZFailure f) => f, (_) => null),
        isA<ZChatActionNotConfirmedFailure>().having(
          (ZChatActionNotConfirmedFailure f) => f.verb,
          'verb',
          'delete',
        ),
      );
    });

    test('un seam de confirmation qui LÈVE vaut un refus (AD-10)', () async {
      final harness = buildController(
        confirm: (ZChatActionPlan _) async => throw StateError('boom'),
      );
      addTearDown(harness.controller.dispose);

      final ZResult<ZChatActionOutcome> res = await harness.controller.runAction(
        const ZChatDeleteAction(messageId: 'm1'),
      );

      expect(harness.executor.effectCount, 0,
          reason: '🔴 une exception dans le dialogue de l\'hôte a DÉTRUIT des '
              'messages — le repli doit être le refus, jamais la destruction');
      expect(res.isLeft(), isTrue);
    });

    test('un ACCORD exécute l\'effet et retire les messages (soft-delete)',
        () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      harness.executor.affected = <String>['a', 'b'];
      c.attach(
        conversationId: 'c1',
        messages: <ZChatMessage>[
          const ZChatMessage(id: 'a'),
          const ZChatMessage(id: 'b'),
          const ZChatMessage(id: 'z'),
        ],
      );

      final ZResult<ZChatActionOutcome> res =
          await c.runAction(const ZChatDeleteAction(messageId: 'a'));

      expect(harness.executor.calls['softDeleteMessages'], 1);
      expect(res.isRight(), isTrue);
      expect(
        c.messages.value.map((ZChatMessage m) => m.id).toList(),
        <String>['z'],
        reason: '🔴 la CASCADE annoncée par l\'issue doit être appliquée : '
            'IFFD supprimait question ET réponse sans jamais le dire',
      );
    });

    test('un verbe NON destructeur ne pose AUCUNE question', () async {
      final harness = buildController();
      addTearDown(harness.controller.dispose);

      final ZResult<ZChatActionOutcome> res = await harness.controller.runAction(
        const ZChatCopyAction(messageId: 'm1'),
      );

      expect(harness.confirmed, isEmpty,
          reason: 'confirmer une copie serait du bruit — le PLAN décide, '
              'jamais le verbe pris isolément');
      expect(harness.executor.calls['renderForCopy'], 1,
          reason: '🔴 VERBE MORT : c\'est le défaut « Copier » d\'IFFD '
              '(`onTap: () {}`, `:1513`)');
      expect(res.fold((_) => null, (ZChatActionOutcome o) => o.copyPayload),
          'rendu');
    });

    test('une cascade Q+R exige la confirmation MÊME sur un verbe déclaré non '
        'destructeur', () async {
      final harness = buildController(answer: false);
      addTearDown(harness.controller.dispose);
      harness.executor.impact = const ZChatActionImpact(
        affectedMessageCount: 2,
        cascadesToRequestAndResponse: true,
      );

      await harness.controller.runAction(
        const ZChatRegenerateAction(messageId: 'm1'),
      );

      expect(harness.confirmed, hasLength(1),
          reason: '🔴 `isDestructive` SEUL laisserait passer une cascade Q+R '
              'non annoncée — le défaut IFFD n°1');
      expect(harness.executor.effectCount, 0);
    });
  });

  group('🔴 annuler ne touche JAMAIS la saisie', () {
    test('la saisie tapée PENDANT le flux survit à l\'annulation', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'première question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      expect(c.composer.text, isEmpty, reason: 'la soumission vide la saisie');

      // L'utilisateur retape pendant que la réponse arrive.
      c.composer.text = 'question suivante';
      c.setAttachments(<String>['pj1']);
      harness.port.last.add(tok('partiel'));
      await pumpEventQueue();

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        ZChatCancelAction(requestId: 'r0', draft: c.currentDraft),
      );
      await pumpEventQueue();

      expect(
        c.composer.text,
        'question suivante',
        reason: '🔴 LE DÉFAUT IFFD `:3618-3672` : la poubelle de « Réflexion en '
            'cours » arrête la génération PUIS supprime la question tapée. La '
            'saisie doit être INTACTE — sans confirmation ni toast à afficher.',
      );
      expect(c.attachmentIds.value, <String>['pj1'],
          reason: '🔴 les pièces jointes de la saisie aussi');
      expect(harness.executor.calls['cancelRequest'], 1);
      expect(harness.confirmed, isEmpty,
          reason: 'un ARRÊT doit être immédiat : confirmer « voulez-vous '
              'vraiment arrêter ? » est le contraire du besoin');
      expect(res.fold((_) => null, (ZChatActionOutcome o) => o.preservedDraft),
          isNotNull);

      final ZResult<ZChatRequestToken> sent = await sending;
      expect(sent.isLeft(), isTrue);
      final ZFailure? f = sent.fold((ZFailure f) => f, (_) => null);
      expect(
        f,
        isA<ZChatStreamInterruptedFailure>().having(
          (ZChatStreamInterruptedFailure e) => e.cancelledByUser,
          'cancelledByUser',
          isTrue,
        ),
        reason: '🔴 un arrêt VOULU n\'est pas une erreur : les aplatir '
            'forcerait l\'hôte à afficher un échec sur un geste volontaire',
      );
      // Le contenu partiel déjà lu est CONSERVÉ (AD-10).
      expect(c.messages.value.last.role, ZChatRole.assistant);
    });
  });

  group('🔴 un échec ne devient JAMAIS un message', () {
    test('un `Left` du flux vit dans `lastFailure`, hors de `messages`',
        () async {
      final harness = buildController(maxResumeAttempts: 0);
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(
        Left<ZFailure, ZChatStreamEvent>(
          const ZChatModerationFailure('contenu refusé'),
        ),
      );
      final ZResult<ZChatRequestToken> res = await sending;
      await pumpEventQueue();

      expect(res.isLeft(), isTrue);
      expect(c.lastFailure.value, isA<ZChatModerationFailure>());
      expect(
        c.messages.value.where((ZChatMessage m) => m.role == ZChatRole.assistant),
        isEmpty,
        reason: '🔴 DÉFAUT IFFD n°4 : le texte brut de l\'échec poussé dans le '
            'corps d\'un message et affiché comme la réponse de l\'assistant',
      );
      expect(
        c.messages.value,
        isEmpty,
        reason: 'rien n\'a été produit : le message optimiste est retiré',
      );
      expect(
        c.composer.text,
        'question',
        reason: '🔴 AD-10 : une panne ne coûte PAS la frappe de l\'utilisateur',
      );
    });

    test('un port qui LÈVE rend un `Left` — aucune exception ne s\'échappe',
        () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      harness.port.throwOnCall = StateError('transport mort');

      c.composer.text = 'question';
      final ZResult<ZChatRequestToken> res = await c.send();

      expect(res.isLeft(), isTrue);
      expect(c.lastFailure.value, isA<ZDomainFailure>());
    });

    test('une saisie vide est refusée sans jamais ouvrir de flux', () async {
      final harness = buildController();
      addTearDown(harness.controller.dispose);

      final ZResult<ZChatRequestToken> res = await harness.controller.send();

      expect(res.isLeft(), isTrue);
      expect(harness.port.calls, isEmpty);
    });

    test('un verbe non supporté par l\'hôte rend un `Left`, jamais un silence',
        () async {
      final harness = buildController();
      addTearDown(harness.controller.dispose);
      harness.executor.failWith = const ZUnsupportedOperationFailure(
        'non implémenté',
        operation: 'renderForCopy',
      );

      final ZResult<ZChatActionOutcome> res = await harness.controller.runAction(
        const ZChatCopyAction(messageId: 'm1'),
      );

      expect(res.isLeft(), isTrue);
      expect(harness.controller.lastFailure.value,
          isA<ZUnsupportedOperationFailure>());
    });
  });

  group('canSend — une tranche qui ne signale QU\'aux transitions', () {
    test('taper le 2ᵉ caractère ne notifie pas', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      int signals = 0;
      c.canSend.addListener(() => signals++);

      c.composer.text = 'a';
      expect(signals, 1);
      expect(c.canSend.value, isTrue);
      c.composer.text = 'ab';
      c.composer.text = 'abc';
      expect(signals, 1,
          reason: '🔴 un `ValueNotifier<bool>` ne doit pas republier une valeur '
              'ÉGALE : sinon le bouton d\'envoi se reconstruit à chaque touche');
      c.composer.text = '';
      expect(signals, 2);
      expect(c.canSend.value, isFalse);
    });
  });
}
