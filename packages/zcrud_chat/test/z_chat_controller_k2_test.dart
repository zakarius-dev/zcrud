/// Lot K2 (chantier composer-lex) — **comportement** des verbes ajoutés à
/// `ZChatController` (mode ÉDITION + BROUILLON À COMPTEUR, G-CH1 étendue par
/// arbitrage owner du 2026-08-07).
///
/// Ce que ce fichier MESURE :
/// * **ED** — le mode édition : pré-remplissage, refus typé de `send()`,
///   soumission par `runAction(ZChatEditAction)` (confirmation comprise),
///   restitution EXACTE du brouillon d'avant l'édition (dans les deux issues :
///   annulation ET succès) — le brouillon d'avant est TOUJOURS non vide dans
///   ces gardes, pour que la restitution ne puisse pas être vacuellement verte ;
/// * **SD** — le brouillon à compteur : re-semer un texte IDENTIQUE signale
///   quand même (le mécanisme `draftSuggestionSeq` de lex), et un semis
///   pendant l'édition est REFUSÉ sans incrément ;
/// * **G10-P2 rejouée** : toutes les écritures passent par le contrôleur — les
///   gardes de source (`z_chat_structure_guard_test.dart` G-CH4,
///   `z_chat_capture_guard_test.dart` G10-P2) restent le grep outillé ; ici on
///   mesure le COMPORTEMENT qui en découle.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';

void main() {
  group('🔴 ED — le mode ÉDITION (mécanisme lex 68.3 + 103.1, porté)', () {
    test('ED-1 — `startEditing` pré-remplit ; `cancelEditing` RESTITUE le '
        'brouillon d\'avant, EXACTEMENT', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;

      // 🔴 Snapshot NON VACANT : l'état d'avant DIFFÈRE du texte édité.
      c.composer.text = 'brouillon en cours';
      c.setAttachments(const <String>['a1']);
      expect(c.editing.value, isNull);

      c.startEditing(messageId: 'm7', originalText: 'texte envoyé');
      expect(c.editing.value,
          const ZChatEditingSession(messageId: 'm7', originalText: 'texte envoyé'));
      expect(c.composer.text, 'texte envoyé',
          reason: '🔴 la saisie n\'est pas pré-remplie : le mécanisme lex '
              '(`chat_input.dart:433-436`) n\'est pas porté');

      c.cancelEditing();
      expect(c.editing.value, isNull);
      expect(c.composer.text, 'brouillon en cours',
          reason: '🔴 annuler l\'édition a PERDU le brouillon d\'avant — le '
              'défaut lex (`_controller.clear()`) reproduit au lieu d\'être '
              'corrigé');
      expect(c.currentDraft.attachmentIds, const <String>['a1']);
    });

    test('ED-2 — `send()` pendant une édition : REFUS TYPÉ, aucun flux, aucun '
        'message', () async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      c.startEditing(messageId: 'm7', originalText: 'texte envoyé');

      final int messagesBefore = c.messages.value.length;
      final ZResult<ZChatRequestToken> res = await c.send();
      expect(res.isLeft(), isTrue,
          reason: '🔴 `send()` a accepté pendant l\'édition : le même texte '
              'peut devenir tantôt nouveau message, tantôt ré-exécution — la '
              'fourche que le refus existe pour interdire');
      expect(c.lastFailure.value, isA<ZDomainFailure>());
      expect(rig.port.calls, isEmpty,
          reason: '🔴 un flux a été ouvert malgré le refus');
      expect(c.messages.value.length, messagesBefore);
      expect(c.editing.value, isNotNull,
          reason: '🔴 le refus a cassé la session d\'édition');
      expect(c.composer.text, 'texte envoyé',
          reason: '🔴 le refus a touché la saisie');
    });

    test('ED-3 — `runAction(ZChatEditAction)` CONFIRMÉE : l\'exécuteur reçoit '
        'l\'édition, la session se FERME, le brouillon d\'avant est RESTITUÉ',
        () async {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      c.composer.text = 'brouillon en cours';
      c.startEditing(messageId: 'm7', originalText: 'texte envoyé');
      c.composer.text = 'texte corrigé'; // l'utilisateur retouche

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        ZChatEditAction(
          messageId: 'm7',
          newText: 'texte corrigé',
          draft: c.currentDraft,
        ),
      );
      expect(res.isRight(), isTrue);
      expect(rig.confirmed, isNotEmpty,
          reason: '🔴 une édition est DESTRUCTIVE (cascade) : la question doit '
              'être posée');
      expect(rig.executor.calls['editAndResend'], 1,
          reason: '🔴 l\'exécuteur n\'a pas reçu l\'édition — ou l\'a reçue '
              'deux fois');
      expect(rig.port.calls, isEmpty,
          reason: '🔴 le socle a OUVERT UN FLUX après l\'édition : '
              '`editAndResend` régénère côté hôte (contrat CHAT-0b) — un '
              'second flux serait un tour joué DEUX fois');
      expect(c.editing.value, isNull,
          reason: '🔴 la session d\'édition survit à son propre succès');
      expect(c.composer.text, 'brouillon en cours',
          reason: '🔴 le brouillon d\'avant l\'édition n\'est pas restitué');
    });

    test('ED-4 — édition REFUSÉE à la confirmation : session ET texte édité '
        'INTACTS', () async {
      final rig = buildController(answer: false);
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      c.startEditing(messageId: 'm7', originalText: 'texte envoyé');
      c.composer.text = 'texte corrigé';

      final ZResult<ZChatActionOutcome> res = await c.runAction(
        ZChatEditAction(
          messageId: 'm7',
          newText: 'texte corrigé',
          draft: c.currentDraft,
        ),
      );
      expect(res.isLeft(), isTrue);
      expect(rig.executor.effectCount, 0,
          reason: '🔴 un refus a produit un EFFET');
      expect(c.editing.value, isNotNull,
          reason: '🔴 le refus a fermé la session : l\'utilisateur perd son '
              'contexte d\'édition (AC4 lex : « sans perte du texte »)');
      expect(c.composer.text, 'texte corrigé',
          reason: '🔴 le refus a touché le texte en cours d\'édition');
    });

    test('ED-5 — `attach` (changement de conversation) FERME la session', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      c.startEditing(messageId: 'm7', originalText: 'texte envoyé');
      c.attach(conversationId: 'c2');
      expect(c.editing.value, isNull,
          reason: '🔴 une session d\'édition a survécu à un changement de '
              'conversation : on éditerait un message d\'une AUTRE '
              'conversation');
    });
  });

  group('🔴 SD — le BROUILLON À COMPTEUR (mécanisme lex 103.5, porté)', () {
    test('SD-1 — semer remplit la saisie et INCRÉMENTE ; un texte IDENTIQUE '
        'signale QUAND MÊME', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      int signals = 0;
      c.draftSeeds.addListener(() => signals++);

      c.seedDraft('suggestion');
      expect(c.composer.text, 'suggestion');
      expect(c.draftSeeds.value, 1);
      expect(signals, 1);

      // 🔴 LE cas pour lequel le compteur existe : le TextEditingController ne
      // notifie pas une valeur égale — sans compteur, ce second geste serait
      // INVISIBLE pour l'hôte (focus, défilement). C'est le
      // `draftSuggestionSeq` de lex (`chat_input_controller.dart:45-48`).
      c.seedDraft('suggestion');
      expect(c.draftSeeds.value, 2,
          reason: '🔴 un semis à texte identique ne signale pas : le mécanisme '
              'à compteur de lex n\'est pas porté, seul son cas facile l\'est');
      expect(signals, 2);
    });

    test('SD-2 — REFUSÉ pendant une édition : saisie intacte, compteur '
        'INCHANGÉ (la règle de priorité lex)', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      c.startEditing(messageId: 'm7', originalText: 'texte envoyé');

      c.seedDraft('suggestion');
      expect(c.composer.text, 'texte envoyé',
          reason: '🔴 un brouillon a ÉCRASÉ une édition en cours — lex '
              'l\'interdit explicitement (`chat_input.dart:447-451`)');
      expect(c.draftSeeds.value, 0,
          reason: '🔴 le compteur a compté un semis NON appliqué : un hôte '
              'donnerait le focus sur un champ qui n\'a pas changé');
    });

    test('SD-3 — le semis garde les pièces jointes en attente', () {
      final rig = buildController();
      addTearDown(rig.controller.dispose);
      final ZChatController c = rig.controller;
      c.setAttachments(const <String>['a1']);
      c.seedDraft('suggestion');
      expect(c.currentDraft.attachmentIds, const <String>['a1'],
          reason: '🔴 semer un texte a JETÉ les pièces jointes : le geste '
              'porte sur le texte, jamais sur les fichiers');
    });
  });
}
