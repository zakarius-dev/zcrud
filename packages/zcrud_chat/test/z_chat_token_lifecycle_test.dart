/// Cycle de vie des jetons — **un jeton par requête**, **reprise sans rejeu**.
///
/// ## 🔴 Le défaut IFFD, mesuré sur disque
///
/// ```dart
/// // iffd/lib/src/data/repositories/iffd_ai_repository_impl.dart:29
/// CancelToken cancel = CancelToken();                       // champ d'INSTANCE
/// void cancelAIGenerate() { cancel.cancel(); cancel = CancelToken(); } // :375-377
/// ```
///
/// Le dépôt est un singleton partagé par tous les écrans : « annuler » y coupe
/// **la dernière requête lancée**, pas celle que l'utilisateur désigne. Deux
/// générations concurrentes, et le geste « stop » de l'une tue l'autre.
///
/// ## 🔴 Reprise — la seule obligation ACTIVE du client
///
/// Le protocole de lex est reprenable : à la reconnexion, le client **doit**
/// renvoyer la position du dernier événement reçu **sous la même identité de
/// tour**, sinon le serveur rejoue le tour (message dupliqué, quota consommé
/// deux fois). Ces gardes vérifient les **quatre** faces du « sans rejeu » :
/// même `requestId`, même requête, texte accumulé conservé, message utilisateur
/// non ré-émis.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';

void main() {
  group('🔴 un jeton PAR requête', () {
    test('deux flux concurrents s\'annulent INDÉPENDAMMENT', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'première';
      final Future<ZResult<ZChatRequestToken>> first = c.send();
      await pumpEventQueue();
      c.composer.text = 'seconde';
      final Future<ZResult<ZChatRequestToken>> second = c.send();
      await pumpEventQueue();

      expect(harness.port.calls, hasLength(2));
      expect(c.activeRequests.value, <String>['r0', 'r1']);
      final ZChatRequestToken t0 = harness.port.calls[0].token;
      final ZChatRequestToken t1 = harness.port.calls[1].token;
      expect(identical(t0, t1), isFalse,
          reason: '🔴 UN SEUL jeton pour deux requêtes = le défaut IFFD exact');

      await c.runAction(const ZChatCancelAction(requestId: 'r0'));
      await pumpEventQueue();

      expect(t0.isCancelled, isTrue);
      expect(
        t1.isCancelled,
        isFalse,
        reason: '🔴 annuler `r0` a coupé `r1` : c\'est EXACTEMENT '
            '`cancelAIGenerate()` d\'IFFD, qui annule « la courante » — '
            'c\'est-à-dire la DERNIÈRE lancée, pas celle qu\'on désigne.',
      );

      // Le second flux va au bout, imperturbable.
      harness.port.at(1).add(tok('réponse 2'));
      harness.port.at(1).add(done(id: 'm2'));
      final ZResult<ZChatRequestToken> ok = await second;
      await pumpEventQueue();
      expect(ok.isRight(), isTrue);
      expect(c.streamText('r1').value, 'réponse 2');

      final ZResult<ZChatRequestToken> ko = await first;
      expect(ko.isLeft(), isTrue);
      expect(c.activeRequests.value, isEmpty);
    });

    test('les tranches par requête sont des instances STABLES', () {
      final harness = buildController();
      addTearDown(harness.controller.dispose);
      expect(
        identical(
          harness.controller.streamText('r0'),
          harness.controller.streamText('r0'),
        ),
        isTrue,
        reason: '🔴 une NOUVELLE instance à chaque appel ferait se ré-abonner '
            'tout `ValueListenableBuilder` à chaque `build` — et la mesure SM-1 '
            'deviendrait fausse dans le sens le plus coûteux',
      );
      expect(
        identical(
          harness.controller.progress('r0'),
          harness.controller.progress('r0'),
        ),
        isTrue,
      );
      expect(
        identical(
          harness.controller.streamText('r0'),
          harness.controller.streamText('r1'),
        ),
        isFalse,
      );
    });
  });

  group('🔴 reprise SANS REJEU, sous la MÊME identité', () {
    test('une coupure SUBIE reprend à la position reçue, sans rejouer le tour',
        () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('AB', seq: 's1'));
      await pumpEventQueue();
      harness.port.last.add(interrupted('r0'));
      await pumpEventQueue();

      expect(harness.port.calls, hasLength(2),
          reason: '🔴 aucune reprise tentée — le flux coupé reste coupé');
      final ZChatRequestToken resumed = harness.port.calls[1].token;

      expect(
        resumed.requestId,
        'r0',
        reason: '🔴 IDENTITÉ CHANGÉE : le serveur ne reconnaîtrait plus le tour '
            'et le REJOUERAIT (message dupliqué, quota consommé deux fois) ; et '
            'le geste « stop » de l\'utilisateur ne viserait plus la même chose.',
      );
      expect(resumed.lastSequenceId, 's1',
          reason: '🔴 sans position de reprise, le backend renvoie le tour '
              'DEPUIS LE DÉBUT');
      expect(resumed.isResumption, isTrue);
      expect(identical(resumed, harness.port.calls[0].token), isFalse,
          reason: 'la tentative coupée reste close ; la reprise est annulable '
              'indépendamment');
      expect(
        identical(harness.port.calls[1].request, harness.port.calls[0].request),
        isTrue,
        reason: '🔴 requête RECONSTRUITE : un prompt recomposé à la reconnexion '
            'est un second tour déguisé',
      );

      expect(c.streamText('r0').value, 'AB',
          reason: '🔴 le texte déjà reçu a été REMIS À ZÉRO : la reprise '
              'écraserait ce que l\'utilisateur a déjà lu');
      expect(
        c.messages.value.where((ZChatMessage m) => m.role == ZChatRole.user),
        hasLength(1),
        reason: '🔴 REJEU : le message utilisateur a été ré-émis par la reprise',
      );
      expect(c.progress('r0').value.phase, ZChatPhase.resuming);
      expect(c.progress('r0').value.resumeAttempts, 1);

      harness.port.at(1).add(tok('CD', seq: 's2'));
      harness.port.at(1).add(done());
      final ZResult<ZChatRequestToken> res = await sending;
      await pumpEventQueue();

      expect(res.isRight(), isTrue);
      expect(c.streamText('r0').value, 'ABCD',
          reason: '🔴 le texte doit être la CONCATÉNATION des deux tentatives');
      expect(
        c.messages.value.where((ZChatMessage m) => m.role == ZChatRole.user),
        hasLength(1),
      );
      expect(
        c.messages.value.where(
          (ZChatMessage m) => m.role == ZChatRole.assistant,
        ),
        hasLength(1),
        reason: '🔴 DEUX réponses = le tour a été rejoué',
      );
      expect(c.progress('r0').value.phase, ZChatPhase.done);
      expect(c.liveAnnouncement.value, 'ABCD');
    });

    test('une ANNULATION VOLONTAIRE n\'est JAMAIS reprise', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('AB', seq: 's1'));
      await pumpEventQueue();
      await c.runAction(const ZChatCancelAction(requestId: 'r0'));
      await sending;
      await pumpEventQueue();

      expect(
        harness.port.calls,
        hasLength(1),
        reason: '🔴 reprendre après un « stop » explicite relancerait la '
            'génération que l\'utilisateur vient d\'arrêter — et consommerait '
            'son quota contre son gré',
      );
      expect(c.progress('r0').value.phase, ZChatPhase.cancelled);
    });

    test('la reprise est BORNÉE (`maxResumeAttempts`)', () async {
      final harness = buildController(maxResumeAttempts: 1);
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('A', seq: 's1'));
      await pumpEventQueue();
      harness.port.last.add(interrupted('r0'));
      await pumpEventQueue();
      harness.port.last.add(interrupted('r0'));
      final ZResult<ZChatRequestToken> res = await sending;
      await pumpEventQueue();

      expect(harness.port.calls, hasLength(2),
          reason: '🔴 boucle de reprise NON BORNÉE : un backend durablement '
              'coupé ferait tourner le client indéfiniment');
      expect(res.isLeft(), isTrue);
      expect(c.progress('r0').value.phase, ZChatPhase.failed);
    });

    test('sans position de reprise, aucune reprise n\'est tentée', () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      // Aucun `sequenceId` : le backend n'est pas reprenable.
      harness.port.last.add(tok('A'));
      await pumpEventQueue();
      harness.port.last.add(interrupted('r0'));
      final ZResult<ZChatRequestToken> res = await sending;
      await pumpEventQueue();

      expect(harness.port.calls, hasLength(1),
          reason: '🔴 `null` signifie « depuis le début », JAMAIS « depuis 0 » : '
              'reprendre sans position rejouerait le tour entier');
      expect(res.isLeft(), isTrue);
    });

    test('la fermeture du flux SANS événement terminal est une interruption',
        () async {
      final harness = buildController(maxResumeAttempts: 0);
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      harness.port.last.add(tok('partiel', seq: 's1'));
      await pumpEventQueue();
      await harness.port.last.close();
      final ZResult<ZChatRequestToken> res = await sending;
      await pumpEventQueue();

      expect(res.isLeft(), isTrue);
      expect(
        res.fold((ZFailure f) => f, (_) => null),
        isA<ZChatStreamInterruptedFailure>().having(
          (ZChatStreamInterruptedFailure f) => f.cancelledByUser,
          'cancelledByUser',
          isFalse,
        ),
      );
      expect(
        c.messages.value.last.role,
        ZChatRole.assistant,
        reason: '🔴 AD-10 : le contenu partiel DÉJÀ LU est conservé',
      );
    });
  });

  group('`attach` — le SEUL changement structurel', () {
    test('change de conversation, annule TOUT en vol, et notifie UNE fois',
        () async {
      final harness = buildController();
      final ZChatController c = harness.controller;
      addTearDown(c.dispose);
      int global = 0;
      c.addListener(() => global++);

      c.composer.text = 'question';
      final Future<ZResult<ZChatRequestToken>> sending = c.send();
      await pumpEventQueue();
      final ZChatRequestToken token = harness.port.calls.single.token;

      c.attach(conversationId: 'autre');
      await sending;
      await pumpEventQueue();

      expect(global, 1,
          reason: '🔴 `notifyListeners()` est RÉSERVÉ aux changements '
              'structurels : une seule notification pour un seul changement');
      expect(token.isCancelled, isTrue);
      expect(c.conversationId, 'autre');
      expect(c.messages.value, isEmpty);
      expect(c.composer.text, isEmpty);
      expect(c.activeRequests.value, isEmpty);
    });
  });
}
