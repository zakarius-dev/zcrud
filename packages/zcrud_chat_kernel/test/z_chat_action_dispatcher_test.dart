// CHAT-0b — comportement du répartiteur UNIQUE `ZChatActionDispatcher`.
//
// 🔴 Ces tests ne valident pas du code : ils rendent IMPOSSIBLE À RÉINTRODUIRE
// la famille de défauts mesurée sur l'assistant IA d'IFFD, dont la cause racine
// est UNIQUE — « un verbe = un seul site d'appel » n'y était pas tenu :
//
// | Défaut IFFD | Ce qui l'interdit ici |
// |---|---|
// | suppression SANS confirmation, cascade Q+R silencieuse (`:3886`) | `execute` refuse un jeton non confirmé SANS TOUCHER l'executor |
// | annuler DÉTRUIT la saisie (`:3618-3672` — `stop()` puis `delete()`) | `cancel` ne route QUE `cancelRequest`, et rend `preservedDraft` INTACT |
// | deux implémentations divergentes du même verbe (barre vs en-tête) | un `switch` scellé, un seul chemin par verbe |
// | `CancelToken` d'INSTANCE partagé (annuler le mauvais flux) | l'annulation s'adresse par `requestId`, le répartiteur est SANS ÉTAT |
// | « Copier » MORT (`onTap: () {}`) | un verbe non supporté rend `Left(ZUnsupportedOperationFailure)`, jamais un silence |
// | texte d'exception AFFICHÉ comme réponse | tout jet est enveloppé en `Left`, et le message brut n'est PAS repris |
//
// Package PUR-DART : `dart test` (pas `flutter test`).
library;

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

/// Executor d'hôte ESPION : enregistre chaque membre réellement invoqué et ses
/// arguments. C'est lui qui prouve les assertions « l'executor n'a PAS été
/// touché » (compteur nul) — un test qui se contenterait de regarder le `Left`
/// rendu ne rougirait PAS si l'effet destructeur avait déjà eu lieu.
class _SpyExecutor implements ZChatActionExecutor {
  _SpyExecutor({
    this.impact = const ZChatActionImpact(),
    this.failure,
    this.throwOnEveryMember = false,
  });

  final ZChatActionImpact impact;

  /// Si non nul, CHAQUE membre d'effet rend ce `Left`.
  final ZFailure? failure;

  /// Si vrai, chaque membre LÈVE (implémentation hôte fautive, AD-10).
  final bool throwOnEveryMember;

  /// Journal ordonné `membre(args)`.
  final List<String> calls = <String>[];

  /// Nombre d'appels reçus, tous membres confondus.
  int get callCount => calls.length;

  /// Combien de fois [member] a été invoqué.
  int countOf(String member) =>
      calls.where((String c) => c.startsWith('$member(')).length;

  ZResult<T> _reply<T>(String journal, T value) {
    calls.add(journal);
    if (throwOnEveryMember) throw StateError('hôte fautif — $journal');
    final ZFailure? f = failure;
    return f == null ? Right<ZFailure, T>(value) : Left<ZFailure, T>(f);
  }

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      _reply<ZChatActionImpact>('estimateImpact(${action.verb})', impact);

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async =>
      _reply<List<String>>(
        'editAndResend($messageId,$newText)',
        <String>[messageId, 'regenerated'],
      );

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async =>
      _reply<List<String>>('regenerate($messageId)', <String>[messageId]);

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async =>
      _reply<List<String>>(
        'softDeleteMessages($messageId,$cascadeToPair)',
        <String>[messageId, if (cascadeToPair) 'pair'],
      );

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async =>
      _reply<Unit>('cancelRequest($requestId)', unit);

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async =>
      _reply<String>('renderForCopy($messageId,${format.name})', 'rendu');

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      _reply<List<String>>('executeCustom(${action.verb})', <String>['x']);
}

/// Executor qui ne supporte AUCUN verbe (défaut « Copier » d'IFFD, mais
/// EXPLICITE : un `Left` typé, jamais un `onTap: () {}`).
class _UnsupportingExecutor extends _SpyExecutor {
  _UnsupportingExecutor()
      : super(
          failure: const ZUnsupportedOperationFailure(
            'verbe non câblé par cet hôte',
            operation: 'renderForCopy',
          ),
        );
}

/// Prépare puis confirme — le chemin nominal complet de l'hôte.
Future<ZResult<ZChatActionOutcome>> _runConfirmed(
  ZChatActionDispatcher d,
  ZChatAction action,
) async =>
    d.execute(_plan(await d.prepare(action)).confirmedByUser());

ZChatActionPlan _plan(ZResult<ZChatActionPlan> r) => r.fold(
      (ZFailure f) => throw StateError('attendu Right, reçu $f'),
      (ZChatActionPlan p) => p,
    );

ZChatActionOutcome _right(ZResult<ZChatActionOutcome> r) => r.fold(
      (ZFailure f) => throw StateError('attendu Right, reçu $f'),
      (ZChatActionOutcome o) => o,
    );

ZFailure _left(ZResult<Object?> r) => r.fold(
      (ZFailure f) => f,
      (Object? v) => throw StateError('attendu Left, reçu $v'),
    );

void main() {
  group('prepare — l\'impact est CHIFFRÉ avant toute destruction (D6)', () {
    test('route vers `estimateImpact` et RIEN d\'autre', () async {
      final _SpyExecutor spy = _SpyExecutor(
        impact: const ZChatActionImpact(
          affectedMessageCount: 2,
          posteriorMessageCount: 1,
          cascadesToRequestAndResponse: true,
        ),
      );
      final ZResult<ZChatActionPlan> r = await ZChatActionDispatcher(spy)
          .prepare(const ZChatDeleteAction(messageId: 'm1'));

      expect(spy.calls, <String>['estimateImpact(delete)']);
      final ZChatActionPlan plan = _plan(r);
      expect(plan.action, const ZChatDeleteAction(messageId: 'm1'));
      expect(plan.impact.affectedMessageCount, 2);
      expect(plan.impact.cascadesToRequestAndResponse, isTrue,
          reason: '🔴 défaut IFFD n°1 : la cascade Q+R n\'était CHIFFRÉE par '
              'aucune des deux surfaces. Ici elle est une donnée du plan.');
    });

    test('un échec d\'estimation ne produit AUCUN plan', () async {
      final _SpyExecutor spy =
          _SpyExecutor(failure: const ZDomainFailure('hors ligne'));
      final ZResult<ZChatActionPlan> r = await ZChatActionDispatcher(spy)
          .prepare(const ZChatDeleteAction(messageId: 'm1'));
      expect(_left(r), const ZDomainFailure('hors ligne'));
    });

    test('un executor qui LÈVE rend un `Left`, jamais une exception qui '
        's\'échappe (AD-10)', () async {
      final _SpyExecutor spy = _SpyExecutor(throwOnEveryMember: true);
      final ZResult<ZChatActionPlan> r = await ZChatActionDispatcher(spy)
          .prepare(const ZChatCopyAction(messageId: 'm1'));
      final ZFailure f = _left(r);
      expect(f, isA<ZDomainFailure>());
      expect(f.message, contains('estimateImpact'));
      expect(f.message, contains('StateError'),
          reason: 'le TYPE de l\'exception est un diagnostic légitime');
      expect(f.message, isNot(contains('hôte fautif')),
          reason: '🔴 défaut IFFD n°4 : le TEXTE BRUT de l\'exception ne doit '
              'JAMAIS transiter — c\'est ainsi qu\'il finissait affiché comme '
              'contenu de bulle.');
    });
  });

  group('execute — routage : un verbe, UN seul effet', () {
    test('chaque verbe n\'invoque QUE son membre (aucune variante)', () async {
      final Map<ZChatAction, String> attendu = <ZChatAction, String>{
        const ZChatEditAction(messageId: 'm1', newText: 'neuf'):
            'editAndResend(m1,neuf)',
        const ZChatRegenerateAction(messageId: 'm2'): 'regenerate(m2)',
        const ZChatDeleteAction(messageId: 'm3'): 'softDeleteMessages(m3,true)',
        const ZChatCancelAction(requestId: 'r4'): 'cancelRequest(r4)',
        const ZChatCopyAction(messageId: 'm5'): 'renderForCopy(m5,plainText)',
        const ZChatCustomAction(
          verb: 'pin',
          isDestructive: false,
          cascades: false,
        ): 'executeCustom(pin)',
      };
      for (final MapEntry<ZChatAction, String> e in attendu.entries) {
        final _SpyExecutor spy = _SpyExecutor();
        await _runConfirmed(ZChatActionDispatcher(spy), e.key);
        expect(
          spy.calls,
          <String>['estimateImpact(${e.key.verb})', e.value],
          reason: '🔴 verbe `${e.key.verb}` : le répartiteur doit invoquer '
              'EXACTEMENT un membre d\'effet, celui-là. IFFD portait TROIS '
              'implémentations divergentes de `regenerate` (:1979 delete+'
              'resend, :2000 refresh, :2026 create additif).',
        );
      }
    });

    test('`delete` est SOFT et ne cascade que si l\'action le dit (AD-9)',
        () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionOutcome out = _right(await _runConfirmed(
        ZChatActionDispatcher(spy),
        const ZChatDeleteAction(messageId: 'm3', cascadeToPair: false),
      ));
      expect(spy.calls.last, 'softDeleteMessages(m3,false)');
      expect(out.softDeleted, isTrue,
          reason: 'lex et IFFD font un HARD delete : zcrud PRIME (AD-9)');
      expect(out.affectedMessageIds, <String>['m3']);
    });

    test('`copy` rend le payload et ne touche QUE sa cible', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionOutcome out = _right(await _runConfirmed(
        ZChatActionDispatcher(spy),
        const ZChatCopyAction(messageId: 'm5', format: ZChatCopyFormat.markdown),
      ));
      expect(spy.calls.last, 'renderForCopy(m5,markdown)');
      expect(out.copyPayload, 'rendu');
      expect(out.affectedMessageIds, <String>['m5']);
      expect(out.softDeleted, isFalse);
    });

    test('un verbe NON SUPPORTÉ rend un `Left` typé — jamais un silence',
        () async {
      final _UnsupportingExecutor spy = _UnsupportingExecutor();
      // 🔴 Le plan passe par `prepare` : son constructeur est PRIVÉ depuis la
      // correction de fin d'epic (aucun plan sans impact chiffré).
      // L'espion refuse TOUS ses membres, `estimateImpact` compris : le plan
      // est donc bâti par un executor NEUTRE, puis l'exécution est confiée à
      // l'espion. Le volet testé — le verbe non câblé — est inchangé.
      final ZChatActionPlan plan = _plan(await ZChatActionDispatcher(
        _SpyExecutor(),
      ).prepare(const ZChatCopyAction(messageId: 'm5')));
      final ZFailure f =
          _left(await ZChatActionDispatcher(spy).execute(plan.confirmedByUser()));
      expect(f, isA<ZUnsupportedOperationFailure>());
      expect((f as ZUnsupportedOperationFailure).operation, 'renderForCopy',
          reason: '🔴 défaut IFFD « Copier » : le verbe existait dans l\'UI et '
              'n\'était câblé nulle part (`onTap: () {}` l.1513). L\'hôte doit '
              'pouvoir MASQUER l\'action sans parser une chaîne.');
      expect(spy.countOf('renderForCopy'), 1);
    });

    test('CHAQUE membre qui LÈVE est enveloppé en `Left` (AD-10)', () async {
      for (final ZChatAction a in <ZChatAction>[
        const ZChatEditAction(messageId: 'm', newText: 'n'),
        const ZChatRegenerateAction(messageId: 'm'),
        const ZChatDeleteAction(messageId: 'm'),
        const ZChatCancelAction(requestId: 'r'),
        const ZChatCopyAction(messageId: 'm'),
        const ZChatCustomAction(
          verb: 'pin',
          isDestructive: false,
          cascades: false,
        ),
      ]) {
        final _SpyExecutor spy = _SpyExecutor(throwOnEveryMember: true);
        // `estimateImpact` lève elle aussi ⇒ le plan est bâti par un executor
        // NEUTRE, puis l'exécution est confiée à l'espion fautif. Le volet
        // testé reste l'ENVELOPPEMENT des membres d'effet.
        final ZChatActionPlan plan =
            _plan(await ZChatActionDispatcher(_SpyExecutor()).prepare(a));
        final ZResult<ZChatActionOutcome> r =
            await ZChatActionDispatcher(spy).execute(plan.confirmedByUser());
        final ZFailure f = _left(r);
        expect(f, isA<ZDomainFailure>(), reason: 'verbe ${a.verb}');
        expect(f.message, isNot(contains('hôte fautif')), reason: a.verb);
      }
    });
  });

  group('🔴 confirmation — le refus PRÉCÈDE l\'effet (défaut IFFD n°1)', () {
    test('une destruction ne peut PAS emprunter le raccourci sûr', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionPlan plan = _plan(await ZChatActionDispatcher(spy)
          .prepare(const ZChatDeleteAction(messageId: 'm1')));
      expect(plan.requiresConfirmation, isTrue);
      expect(plan.proceedWithoutConfirmation(), isNull,
          reason: '🔴 le raccourci SÛR est refusé sur une destruction : c\'est '
              'une contrainte de COMPILATION (`ZChatConfirmedAction?`), pas '
              'une discipline. C\'est le premier verrou.');
      expect(plan.confirmedByUser().userConfirmed, isTrue);
    });

    test('🔴 ESPION À COMPTEUR NUL — un jeton non confirmé sur un plan qui '
        'EXIGE la confirmation rend `Left` SANS TOUCHER l\'executor', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionDispatcher d = ZChatActionDispatcher(spy);
      final _MuableCustomAction sournoise = _MuableCustomAction();

      // Temps 1 — l'action se déclare inoffensive : jeton NON confirmé obtenu.
      final ZChatActionPlan plan = _plan(await d.prepare(sournoise));
      expect(plan.requiresConfirmation, isFalse);
      final ZChatConfirmedAction jeton = plan.proceedWithoutConfirmation()!;
      expect(jeton.userConfirmed, isFalse);

      // Temps 2 — elle bascule en destructrice (cf. `_MuableCustomAction`).
      sournoise.devenuDestructeur = true;
      expect(plan.requiresConfirmation, isTrue);

      spy.calls.clear();
      final ZFailure f = _left(await d.execute(jeton));
      expect(f, isA<ZChatActionNotConfirmedFailure>());
      expect((f as ZChatActionNotConfirmedFailure).verb, 'purgeHote',
          reason: 'le verbe refusé est NOMMÉ : l\'hôte réagit sans parser de '
              'texte (rouvrir le dialogue ≠ remonter une panne).');
      expect(spy.callCount, 0,
          reason: '🔴 C\'EST LE TEST DU LOT. IFFD supprimait question ET '
              'réponse depuis sa surface B (`:3886-3908`) sans jamais '
              'consulter la confirmation. Ici l\'executor n\'est même pas '
              'ATTEINT — un test qui se contenterait de lire le `Left` ne '
              'rougirait pas si l\'effet avait déjà eu lieu.');
    });

    test('le refus ne dépend PAS du verbe mais du PLAN (D6)', () async {
      // `regenerate` n'est ni destructeur ni cascadant : seul l'impact CHIFFRÉ
      // (> 1 message touché) impose la confirmation. IFFD ne confirmait jamais
      // ce verbe — et l'une de ses trois variantes détruisait les messages
      // postérieurs.
      final _SpyExecutor spy =
          _SpyExecutor(impact: const ZChatActionImpact(affectedMessageCount: 4));
      final ZChatActionPlan plan = _plan(await ZChatActionDispatcher(spy)
          .prepare(const ZChatRegenerateAction(messageId: 'm2')));
      expect(plan.action.isDestructive, isFalse);
      expect(plan.action.cascades, isFalse);
      expect(plan.requiresConfirmation, isTrue,
          reason: '🔴 4 messages touchés ⇒ confirmation, même sur un verbe '
              'déclaré non destructeur. Ne garder que `isDestructive` '
              'laisserait passer la cascade Q+R non annoncée d\'IFFD.');
      expect(plan.proceedWithoutConfirmation(), isNull);
    });

    test('un plan SANS exigence s\'exécute par le raccourci sûr', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionDispatcher d = ZChatActionDispatcher(spy);
      final ZChatActionPlan plan =
          _plan(await d.prepare(const ZChatCopyAction(messageId: 'm5')));
      expect(plan.requiresConfirmation, isFalse);
      final ZChatConfirmedAction? jeton = plan.proceedWithoutConfirmation();
      expect(jeton, isNotNull);
      expect(_right(await d.execute(jeton!)).verb, 'copy');
      expect(spy.countOf('renderForCopy'), 1);
    });
  });

  group('🔴 annulation — la SAISIE SURVIT (défaut IFFD n°2)', () {
    const ZChatDraft saisie = ZChatDraft(
      text: 'ma question à moitié tapée',
      attachmentIds: <String>['a1', 'a2'],
    );

    test('`cancel` ne route QUE `cancelRequest` — aucun retrait, aucune '
        'reprise', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionOutcome out = _right(await _runConfirmed(
        ZChatActionDispatcher(spy),
        const ZChatCancelAction(requestId: 'r4', draft: saisie),
      ));
      expect(spy.calls, <String>['estimateImpact(cancel)', 'cancelRequest(r4)']);
      expect(spy.countOf('softDeleteMessages'), 0,
          reason: '🔴 IFFD `chatbot_conversation_screen.dart:3618-3672` : la '
              'poubelle de « Réflexion en cours » appelait '
              '`stopSubjectExplaningOnError()` PUIS `delete(id)` — la question '
              'tapée disparaissait, sans confirmation ni toast.');
      expect(spy.countOf('editAndResend'), 0);
      expect(out.preservedDraft, saisie,
          reason: '🔴 la saisie doit être rendue INTACTE, texte ET pièces '
              'jointes.');
      expect(out.preservedDraft!.text, 'ma question à moitié tapée');
      expect(out.preservedDraft!.attachmentIds, <String>['a1', 'a2']);
      expect(out.softDeleted, isFalse);
      expect(out.affectedMessageIds, isEmpty);
    });

    test('même sur le CHEMIN D\'ÉCHEC, la saisie n\'est ni remise à l\'executor '
        'ni détruite (G-A1/G-A2)', () async {
      final _SpyExecutor spy =
          _SpyExecutor(failure: const ZDomainFailure('flux déjà terminé'));
      const ZChatCancelAction action =
          ZChatCancelAction(requestId: 'r4', draft: saisie);
      // Plan bâti par un executor NEUTRE : l'espion de CE test échoue sur
      // TOUS ses membres (`failure:`), `estimateImpact` compris. `spy.calls`
      // reste donc l'observation exacte de ce que l'ÉCHEC d'annulation
      // déclenche — et rien d'autre.
      final ZChatActionPlan plan = _plan(
        await ZChatActionDispatcher(_SpyExecutor()).prepare(action),
      );
      final ZFailure f = _left(
        await ZChatActionDispatcher(spy).execute(plan.confirmedByUser()),
      );
      expect(f, const ZDomainFailure('flux déjà terminé'));
      expect(spy.calls, <String>['cancelRequest(r4)'],
          reason: '🔴 un échec d\'annulation ne DÉCLENCHE RIEN d\'autre — '
              'surtout pas un retrait de rattrapage.');
      expect(action.draft, saisie,
          reason: 'la saisie portée par l\'action est intacte : l\'hôte peut '
              'la restituer telle quelle.');
    });

    test('`edit` préserve aussi la saisie (D3)', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionOutcome out = _right(await _runConfirmed(
        ZChatActionDispatcher(spy),
        const ZChatEditAction(
          messageId: 'm1',
          newText: 'reformulé',
          draft: saisie,
        ),
      ));
      expect(out.preservedDraft, saisie);
      expect(out.affectedMessageIds, <String>['m1', 'regenerated']);
    });

    test('les verbes qui ne PROMETTENT rien ne rendent AUCUN brouillon',
        () async {
      for (final ZChatAction a in <ZChatAction>[
        const ZChatRegenerateAction(messageId: 'm'),
        const ZChatDeleteAction(messageId: 'm'),
        const ZChatCopyAction(messageId: 'm'),
      ]) {
        expect(a.preservesDraft, isFalse, reason: a.verb);
        final ZChatActionOutcome out = _right(
          await _runConfirmed(ZChatActionDispatcher(_SpyExecutor()), a),
        );
        expect(out.preservedDraft, isNull, reason: a.verb);
      }
      // …et RÉCIPROQUEMENT : tout verbe qui le promet le tient.
      for (final ZChatAction a in <ZChatAction>[
        const ZChatCancelAction(requestId: 'r', draft: saisie),
        const ZChatEditAction(messageId: 'm', newText: 'n', draft: saisie),
      ]) {
        expect(a.preservesDraft, isTrue, reason: a.verb);
        final ZChatActionOutcome out = _right(
          await _runConfirmed(ZChatActionDispatcher(_SpyExecutor()), a),
        );
        expect(out.preservedDraft, saisie, reason: a.verb);
      }
    });
  });

  group('🔴 adressage par `requestId` — aucun jeton d\'instance (D4)', () {
    test('annuler la requête B n\'annule QUE B', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionDispatcher d = ZChatActionDispatcher(spy);
      await _runConfirmed(d, const ZChatCancelAction(requestId: 'B'));
      expect(spy.calls.last, 'cancelRequest(B)',
          reason: '🔴 IFFD partageait UN `CancelToken` d\'instance : annuler un '
              'message pouvait annuler le MAUVAIS flux. Ici l\'identité de la '
              'requête traverse le contrat.');
      await _runConfirmed(d, const ZChatCancelAction(requestId: 'A'));
      expect(spy.calls.last, 'cancelRequest(A)');
    });

    test('le répartiteur est SANS ÉTAT : deux instances sur le même executor '
        'sont interchangeables, et l\'ordre n\'influe pas', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionDispatcher d1 = ZChatActionDispatcher(spy);
      final ZChatActionDispatcher d2 = ZChatActionDispatcher(spy);
      await _runConfirmed(d1, const ZChatCancelAction(requestId: 'A'));
      await _runConfirmed(d2, const ZChatCancelAction(requestId: 'B'));
      await _runConfirmed(d1, const ZChatCancelAction(requestId: 'C'));
      expect(
        spy.calls.where((String c) => c.startsWith('cancelRequest')).toList(),
        <String>['cancelRequest(A)', 'cancelRequest(B)', 'cancelRequest(C)'],
      );
    });

    test('deux annulations CONCURRENTES gardent chacune son identité', () async {
      final _SpyExecutor spy = _SpyExecutor();
      final ZChatActionDispatcher d = ZChatActionDispatcher(spy);
      final List<ZResult<ZChatActionOutcome>> r =
          await Future.wait(<Future<ZResult<ZChatActionOutcome>>>[
        _runConfirmed(d, const ZChatCancelAction(requestId: 'X')),
        _runConfirmed(d, const ZChatCancelAction(requestId: 'Y')),
      ]);
      expect(
        spy.calls.where((String c) => c.startsWith('cancelRequest')).toSet(),
        <String>{'cancelRequest(X)', 'cancelRequest(Y)'},
      );
      expect(r.every((ZResult<ZChatActionOutcome> e) => e.isRight()), isTrue);
    });
  });
}

/// Action d'hôte dont la DESTRUCTIVITÉ change après coup — le seul moyen, dans
/// tout le contrat, d'obtenir un `ZChatConfirmedAction` NON confirmé sur un plan
/// qui EXIGE la confirmation.
///
/// 🔴 Ce n'est pas un artifice de test, c'est le trou réel du contrat, et la
/// raison d'être du re-contrôle de `execute` :
/// * `ZChatAction` est **scellée** ⇒ aucun hôte ne peut créer un variant direct ;
/// * `ZChatActionPlan` est `final` ⇒ `requiresConfirmation` n'est pas surchargeable ;
/// * le constructeur de `ZChatConfirmedAction` est **privé** ⇒ le jeton n'est pas
///   forgeable.
/// MAIS `ZChatCustomAction` (variant OUVERT d'AD-4) n'est **ni** `final` **ni**
/// `sealed` : un hôte peut en hériter et remplacer le champ `isDestructive` par
/// un **getter mutable**. Il obtient alors un jeton non confirmé pendant que
/// l'action se déclare inoffensive, puis bascule. C'est exactement la « surface
/// B » d'IFFD, réintroduite par la porte de service — et c'est le re-contrôle de
/// `execute` (et lui seul) qui l'arrête AVANT l'effet.
class _MuableCustomAction extends ZChatCustomAction {
  _MuableCustomAction()
      : super(verb: 'purgeHote', isDestructive: false, cascades: false);

  /// Bascule la destructivité APRÈS l'obtention du jeton.
  bool devenuDestructeur = false;

  @override
  bool get isDestructive => devenuDestructeur;
}
