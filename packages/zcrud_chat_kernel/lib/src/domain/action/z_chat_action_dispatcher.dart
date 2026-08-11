// Répartiteur **UNIQUE** des actions de message — `ZChatActionDispatcher`.
//
// ## Exactement deux membres publics
//
// `prepare` et `execute` — **rien d'autre**. Aucune méthode par verbe, aucun
// raccourci de confort (`deleteMessage()`, `regenerate()`…) : chaque membre
// public ajouté serait **un site d'appel de plus**, donc une divergence
// possible entre deux surfaces d'UI.
//
// ## Aucun état
//
// Son **seul** champ est [executor], `final`. Aucun champ mutable, aucun
// `late`, aucun `static` mutable, **aucun jeton d'annulation d'instance** — un
// `CancelToken` d'instance partagé entre plusieurs requêtes en vol ferait
// annuler le mauvais flux. L'annulation s'adresse **par `requestId`**.
//
// ## Rien ne lève (invariant AD-10)
//
// Chaque appel à l'executor est **enveloppé** : une implémentation hôte qui
// lève produit un `Left`, jamais une propagation, et **jamais un message**
// qui pourrait se déguiser en réponse (texte d'exception brut affiché comme
// contenu de bulle). L'issue ne porte aucun texte libre autre que
// `copyPayload`.
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

  /// Port d'effet. Ne **jamais** l'invoquer directement : ses membres ne
  /// s'appellent que depuis ce fichier.
  final ZChatActionExecutor executor;

  /// Chiffre l'impact et rend le plan — **avant** toute destruction.
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
  /// Le refus précède l'effet : un plan exigeant confirmation dont le jeton
  /// n'est pas confirmé rend `Left(ZChatActionNotConfirmedFailure)` **sans
  /// toucher l'executor**.
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
        // Les réglages d'une régénération DOIVENT atteindre l'hôte, ou être
        // REFUSÉS ; jamais tomber en silence. Un réglage transmis à l'appel
        // puis jeté par la couche d'accès aux données, sans qu'aucun
        // appelant puisse s'en apercevoir, est exactement le repli muet que
        // ce chemin ferme.
        //
        // Le port historique reste INTOUCHÉ : ajouter un paramètre, même
        // optionnel, à une méthode existante invaliderait tout override
        // hôte (un override Dart doit accepter tous les paramètres nommés
        // de la déclaration qu'il redéfinit). L'hôte opte pour la forme
        // riche en implémentant `ZChatSettingsAwareActionExecutor` EN PLUS.
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
        // UNIQUEMENT `cancelRequest`. Aucun retrait, aucune reprise : faire
        // suivre l'arrêt d'un `delete` effacerait la question tapée. Le
        // brouillon est rendu INTACT, y compris quand l'annulation échoue
        // (il n'est jamais remis à l'executor).
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
  /// un `Left`, jamais une propagation (invariant AD-10).
  ///
  /// Le texte brut de l'exception n'est **pas** repris : seul son type l'est.
  /// Une exception affichée telle quelle comme réponse serait exactement le
  /// défaut que cette enveloppe rend inexprimable — et l'issue, elle, n'en
  /// porte aucune trace.
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
