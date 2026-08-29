/// Adaptateur **par route** du port d'explication one-shot.
///
/// La requête de ce contrat **transporte** un `routeId` : quand l'appelant en
/// nomme un, il prime et est reconduit verbatim ; sinon la route résolue par
/// le catalogue y est estampillée avant délégation.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'z_routed_study_dispatch.dart';

/// Répartit chaque explication vers le port de sa route.
class ZChatRoutedAiExplanationPort implements ZAiExplanationPort {
  /// Construit l'adaptateur routé.
  ///
  /// [taskKey] est la clé de tâche **de l'hôte** sous laquelle le routeur
  /// déclare sa route : ce paquet n'en publie aucune constante et n'en
  /// interprète aucune valeur. [gate] refuse tout par défaut.
  const ZChatRoutedAiExplanationPort({
    required this.catalog,
    required this.routerId,
    required this.handlers,
    required this.taskKey,
    this.gate = const ZDenyAllChatRouteGate(),
    this.fallback,
  });

  /// Catalogue où lire le routeur.
  final ZChatRouteCatalogPort catalog;

  /// Identité du routeur à résoudre dans [catalog].
  final String routerId;

  /// Gouvernance de la route (refus par défaut).
  final ZChatRouteGate gate;

  /// Annuaire des ports, par identité opaque.
  final Map<String, ZAiExplanationPort> handlers;

  /// Port de repli, ou `null`.
  final ZAiExplanationPort? fallback;

  /// Clé de tâche opaque sous laquelle la route est déclarée.
  final String taskKey;

  @override
  Future<ZResult<String>> explain(ZAiExplanationRequest request) async {
    final ZResult<ZRoutedStudyTarget<ZAiExplanationPort>> target =
        await zResolveRoutedStudyPort<ZAiExplanationPort>(
      catalog: catalog,
      routerId: routerId,
      gate: gate,
      handlers: handlers,
      taskKey: taskKey,
      requestRouteId: request.routeId,
      fallback: fallback,
    );
    final ZFailure? failure = zRoutedStudyFailureOf(target);
    if (failure != null) return Left<ZFailure, String>(failure);
    final ZRoutedStudyTarget<ZAiExplanationPort> t =
        zRoutedStudyValueOf(target)!;
    try {
      return await t.port.explain(request.withRouteId(t.routeId));
    } catch (error) {
      return Left<ZFailure, String>(zRoutedStudyThrowFailure(error));
    }
  }
}
