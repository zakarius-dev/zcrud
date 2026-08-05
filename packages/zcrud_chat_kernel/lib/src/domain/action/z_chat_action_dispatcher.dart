// Répartiteur **UNIQUE** des actions de message — `ZChatActionDispatcher`.
//
// CHAT-0b, décisions **D1**, **D2**, **D4**, **D5**.
//
// ## 🔴 Exactement deux membres publics
//
// `prepare` et `execute` — **rien d'autre**. Aucune méthode par verbe, aucun
// raccourci de confort (`deleteMessage()`, `regenerate()`…) : chaque membre
// public ajouté serait **un site d'appel de plus**, donc une divergence
// possible entre deux surfaces d'UI. La garde **G-U2** asserte l'**égalité
// d'ensemble** de cette surface (« contient prepare et execute » ne mordrait
// pas).
//
// ## 🔴 Aucun état (D4)
//
// Son **seul** champ est [executor], `final`. Aucun champ mutable, aucun
// `late`, aucun `static` mutable, **aucun jeton d'annulation d'instance** — le
// défaut IFFD était précisément un `CancelToken` d'instance partagé : annuler
// un flux annulait le mauvais. L'annulation s'adresse **par `requestId`**
// (garde **G-T1**, volets source *et* comportement).
//
// ## 🔴 Rien ne lève (D5, AD-10)
//
// Chaque appel à l'executor est **enveloppé** : une implémentation hôte qui
// lève produit un `Left`, jamais une propagation, et **jamais un message**
// qui pourrait se déguiser en réponse (défaut IFFD n°4 — texte d'exception
// brut affiché comme contenu de bulle). L'issue ne porte aucun texte libre
// autre que `copyPayload` (garde **G-E2**).
//
// ```dart
// final ZChatActionPlan? plan = (await dispatcher.prepare(action))
//     .fold((_) => null, (ZChatActionPlan p) => p);
// if (plan == null) return;                       // échec d'estimation
// final jeton = plan.requiresConfirmation
//     ? (await monDialogueDeConfirmation() ? plan.confirmedByUser() : null)
//     : plan.proceedWithoutConfirmation();        // rend null si destructeur
// if (jeton == null) return;
// final issue = await dispatcher.execute(jeton);
// ```
part of 'z_chat_action_plan.dart';



/// Le **seul** site d'appel des membres de [ZChatActionExecutor].
final class ZChatActionDispatcher {
  /// Construit un répartiteur sur un [executor] d'hôte.
  const ZChatActionDispatcher(this.executor);

  /// Port d'effet. 🚫 Ne **jamais** l'invoquer directement : ses membres ne
  /// s'appellent que depuis ce fichier (garde **G-U1**).
  final ZChatActionExecutor executor;

  /// Chiffre l'impact et rend le plan — **avant** toute destruction (D6).
  Future<ZResult<ZChatActionPlan>> prepare(ZChatAction action) async {
    final ZResult<ZChatActionImpact> impact = await _guard<ZChatActionImpact>(
      () => executor.estimateImpact(action),
      'estimateImpact',
    );
    return impact.map(
      (ZChatActionImpact i) => ZChatActionPlan._(action: action, impact: i),
    );
  }

  /// Exécute une action **confirmée**.
  ///
  /// 🔴 Le refus précède l'effet : un plan exigeant confirmation dont le jeton
  /// n'est pas confirmé rend `Left(ZChatActionNotConfirmedFailure)` **sans
  /// toucher l'executor** (AC7 — espion à compteur nul).
  Future<ZResult<ZChatActionOutcome>> execute(
    ZChatConfirmedAction confirmed,
  ) async {
    if (confirmed.plan.requiresConfirmation && !confirmed.userConfirmed) {
      return Left<ZFailure, ZChatActionOutcome>(
        ZChatActionNotConfirmedFailure(verb: confirmed.plan.action.verb),
      );
    }
    switch (confirmed.plan.action) {
      case final ZChatEditAction a:
        final ZResult<List<String>> r = await _guard<List<String>>(
          () => executor.editAndResend(
            messageId: a.messageId,
            newText: a.newText,
          ),
          'editAndResend',
        );
        return r.map(
          (List<String> ids) => ZChatActionOutcome(
            verb: a.verb,
            affectedMessageIds: ids,
            preservedDraft: a.draft,
          ),
        );
      case final ZChatRegenerateAction a:
        // 🔴 Lot β — les réglages d'une régénération DOIVENT atteindre l'hôte,
        // ou être REFUSÉS ; jamais tomber en silence. Le défaut mesuré au
        // § 1.1 de l'étude CR-IFFD-72 est exactement là : six drapeaux de
        // corpus transmis par le contrôleur d'IFFD puis jetés par le
        // repository, sans qu'aucun appelant puisse s'en apercevoir.
        //
        // Le port historique reste INTOUCHÉ (ajouter un paramètre, même
        // optionnel, invalide tout override existant — incident du
        // 2026-08-01). L'hôte opte pour la forme riche en implémentant
        // `ZChatSettingsAwareActionExecutor` EN PLUS.
        final ZChatActionExecutor ex = executor;
        if (a.overridesRequest && ex is! ZChatSettingsAwareActionExecutor) {
          return Left<ZFailure, ZChatActionOutcome>(
            const ZUnsupportedOperationFailure(
              'this executor cannot honour regeneration settings or corpus '
              'scope',
              operation: 'regenerateWithSettings',
            ),
          );
        }
        final ZResult<List<String>> r;
        if (a.overridesRequest) {
          // Le `as` ne peut pas échouer : le refus ci-dessus l'a garanti. Les
          // deux interfaces sont SŒURS (aucune n'étend l'autre), d'où la
          // conversion explicite plutôt qu'une promotion de type.
          final ZChatSettingsAwareActionExecutor aware =
              ex as ZChatSettingsAwareActionExecutor;
          r = await _guard<List<String>>(
            () => aware.regenerateWithSettings(a),
            'regenerateWithSettings',
          );
        } else {
          r = await _guard<List<String>>(
            () => executor.regenerate(messageId: a.messageId),
            'regenerate',
          );
        }
        return r.map(
          (List<String> ids) =>
              ZChatActionOutcome(verb: a.verb, affectedMessageIds: ids),
        );
      case final ZChatDeleteAction a:
        final ZResult<List<String>> r = await _guard<List<String>>(
          () => executor.softDeleteMessages(
            messageId: a.messageId,
            cascadeToPair: a.cascadeToPair,
          ),
          'softDeleteMessages',
        );
        return r.map(
          (List<String> ids) => ZChatActionOutcome(
            verb: a.verb,
            affectedMessageIds: ids,
            softDeleted: true,
          ),
        );
      case final ZChatCancelAction a:
        // 🔴 D3 : UNIQUEMENT `cancelRequest`. Aucun retrait, aucune reprise —
        // le défaut IFFD `:3618-3672` faisait suivre l'arrêt d'un `delete` de
        // la question tapée. Le brouillon est rendu INTACT, y compris quand
        // l'annulation échoue (il n'est jamais remis à l'executor) — G-A1/G-A2.
        final ZResult<Unit> r = await _guard<Unit>(
          () => executor.cancelRequest(a.requestId),
          'cancelRequest',
        );
        return r.map(
          (Unit _) =>
              ZChatActionOutcome(verb: a.verb, preservedDraft: a.draft),
        );
      case final ZChatCopyAction a:
        final ZResult<String> r = await _guard<String>(
          () => executor.renderForCopy(
            messageId: a.messageId,
            format: a.format,
          ),
          'renderForCopy',
        );
        return r.map(
          (String text) => ZChatActionOutcome(
            verb: a.verb,
            affectedMessageIds: <String>[a.messageId],
            copyPayload: text,
          ),
        );
      case final ZChatCustomAction a:
        final ZResult<List<String>> r = await _guard<List<String>>(
          () => executor.executeCustom(a),
          'executeCustom',
        );
        return r.map(
          (List<String> ids) =>
              ZChatActionOutcome(verb: a.verb, affectedMessageIds: ids),
        );
    }
  }

  /// Enveloppe un appel d'executor : une implémentation hôte qui **lève** rend
  /// un `Left`, jamais une propagation (AD-10).
  ///
  /// 🔴 Le texte brut de l'exception n'est **pas** repris : seul son type l'est.
  /// C'est le défaut IFFD n°4 (message d'exception affiché comme réponse) qu'on
  /// rend inexprimable — et l'issue, elle, n'en porte aucune trace.
  Future<ZResult<T>> _guard<T>(
    Future<ZResult<T>> Function() body,
    String operation,
  ) async {
    try {
      return await body();
    } catch (e) {
      return Left<ZFailure, T>(
        ZDomainFailure(
          'chat action executor failed with ${e.runtimeType} '
          'during $operation',
        ),
      );
    }
  }
}
