/// Adaptateur **par route** du port d'explication progressive.
///
/// Le flux du port retenu est **relayé tel quel** : ni filtrage, ni
/// réordonnancement, ni réémission — chaque événement traverse dans l'ordre
/// où il est produit. Annuler l'abonnement rendu ferme l'abonnement amont.
///
/// ## Disponibilité
///
/// La résolution d'une route est asynchrone ; `isAvailable` ne l'est pas. Cet
/// adaptateur répond donc sur ce qu'il peut savoir sans attendre : le
/// progressif est utilisable si **au moins un** port de l'annuaire (ou le
/// repli) se déclare disponible. Une route gouvernée peut malgré tout refuser
/// à l'appel — `isAvailable` annonce une capacité, jamais un droit.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'z_routed_study_dispatch.dart';

/// Répartit chaque explication progressive vers le port de sa route.
class ZChatRoutedAiExplanationStreamPort implements ZAiExplanationStreamPort {
  /// Construit l'adaptateur routé.
  ///
  /// [taskKey] est la clé de tâche **de l'hôte** sous laquelle le routeur
  /// déclare sa route. [gate] refuse tout par défaut.
  const ZChatRoutedAiExplanationStreamPort({
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
  final Map<String, ZAiExplanationStreamPort> handlers;

  /// Port de repli, ou `null`.
  final ZAiExplanationStreamPort? fallback;

  /// Clé de tâche opaque sous laquelle la route est déclarée.
  final String taskKey;

  @override
  bool get isAvailable =>
      handlers.values.any((ZAiExplanationStreamPort p) => p.isAvailable) ||
      (fallback?.isAvailable ?? false);

  @override
  Stream<ZResult<ZGenerationProgress>> explainStream(
    ZAiExplanationRequest request,
  ) async* {
    final ZResult<ZRoutedStudyTarget<ZAiExplanationStreamPort>> target =
        await zResolveRoutedStudyPort<ZAiExplanationStreamPort>(
      catalog: catalog,
      routerId: routerId,
      gate: gate,
      handlers: handlers,
      taskKey: taskKey,
      requestRouteId: request.routeId,
      fallback: fallback,
    );
    final ZFailure? failure = zRoutedStudyFailureOf(target);
    if (failure != null) {
      yield Left<ZFailure, ZGenerationProgress>(failure);
      return;
    }
    final ZRoutedStudyTarget<ZAiExplanationStreamPort> t =
        zRoutedStudyValueOf(target)!;
    // `yield*` relaie l'abonnement amont : les événements passent sans copie
    // ni réordonnancement, et l'annulation de l'abonnement aval ferme
    // l'abonnement amont.
    try {
      yield* t.port.explainStream(request.withRouteId(t.routeId));
    } catch (error) {
      yield Left<ZFailure, ZGenerationProgress>(
        zRoutedStudyThrowFailure(error),
      );
    }
  }
}
