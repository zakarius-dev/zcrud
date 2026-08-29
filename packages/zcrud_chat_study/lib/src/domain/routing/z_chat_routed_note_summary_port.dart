/// Adaptateur **par route** du port de résumé de note.
///
/// ## Route par CONFIGURATION
///
/// `ZNoteSummaryRequest` ne transporte **pas** de `routeId` : la route ne
/// peut donc pas venir de l'appel. Elle vient entièrement de la
/// configuration — la clé de tâche déclarée à la construction, résolue dans
/// le catalogue. La requête est ensuite déléguée **verbatim** : cet
/// adaptateur n'y injecte rien, et surtout pas une route déguisée en clé
/// d'`extra` (elle serait écartée à la lecture et créerait un second
/// vocabulaire de transport).
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'z_routed_study_dispatch.dart';

/// Répartit chaque résumé de note vers le port de sa route.
class ZChatRoutedNoteSummaryPort implements ZNoteSummaryPort {
  /// Construit l'adaptateur routé.
  ///
  /// [taskKey] est la clé de tâche **de l'hôte** sous laquelle le routeur
  /// déclare sa route. [gate] refuse tout par défaut.
  const ZChatRoutedNoteSummaryPort({
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
  final Map<String, ZNoteSummaryPort> handlers;

  /// Port de repli, ou `null`.
  final ZNoteSummaryPort? fallback;

  /// Clé de tâche opaque sous laquelle la route est déclarée.
  final String taskKey;

  @override
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request) async {
    final ZResult<ZRoutedStudyTarget<ZNoteSummaryPort>> target =
        await zResolveRoutedStudyPort<ZNoteSummaryPort>(
      catalog: catalog,
      routerId: routerId,
      gate: gate,
      handlers: handlers,
      taskKey: taskKey,
      requestRouteId: null,
      fallback: fallback,
    );
    final ZFailure? failure = zRoutedStudyFailureOf(target);
    if (failure != null) return Left<ZFailure, String>(failure);
    final ZRoutedStudyTarget<ZNoteSummaryPort> t = zRoutedStudyValueOf(target)!;
    try {
      return await t.port.summarize(request);
    } catch (error) {
      return Left<ZFailure, String>(zRoutedStudyThrowFailure(error));
    }
  }
}
