/// Adaptateur **par route** du port de génération de carte mentale.
///
/// Le port d'étude reste NEUTRE : `routeId` y est une donnée de la requête,
/// jamais une URL ni un transport. Cet adaptateur est la couche qui lit une
/// route dans un catalogue, la soumet à une gouvernance, puis délègue au
/// port que l'hôte a branché sur cette route.
///
/// La requête de ce contrat **transporte** un `routeId` : quand l'appelant en
/// nomme un, il prime et est reconduit verbatim ; sinon la route résolue par
/// le catalogue y est estampillée avant délégation.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmapNode;
import 'package:zcrud_study/zcrud_study.dart';

import 'z_routed_study_dispatch.dart';

/// Répartit chaque génération de carte mentale vers le port de sa route.
class ZChatRoutedMindmapGenerationPort implements ZMindmapGenerationPort {
  /// Construit l'adaptateur routé.
  ///
  /// [taskKey] est la clé de tâche **de l'hôte** sous laquelle le routeur
  /// déclare sa route : ce paquet n'en publie aucune constante et n'en
  /// interprète aucune valeur. [gate] refuse tout par défaut — une route
  /// gouvernée doit être ouverte explicitement.
  const ZChatRoutedMindmapGenerationPort({
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

  /// Annuaire des ports, par identité opaque (gestionnaire, route ou nom de
  /// route).
  final Map<String, ZMindmapGenerationPort> handlers;

  /// Port de repli, ou `null` — sans repli, une route non desservie rend un
  /// `ZNotFoundFailure` unique.
  final ZMindmapGenerationPort? fallback;

  /// Clé de tâche opaque sous laquelle la route est déclarée.
  final String taskKey;

  @override
  Future<ZResult<List<ZMindmapNode>>> generateMindmap(
    ZMindmapGenerationRequest request,
  ) async {
    final ZResult<ZRoutedStudyTarget<ZMindmapGenerationPort>> target =
        await zResolveRoutedStudyPort<ZMindmapGenerationPort>(
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
      return Left<ZFailure, List<ZMindmapNode>>(failure);
    }
    final ZRoutedStudyTarget<ZMindmapGenerationPort> t =
        zRoutedStudyValueOf(target)!;
    try {
      return await t.port.generateMindmap(request.withRouteId(t.routeId));
    } catch (error) {
      return Left<ZFailure, List<ZMindmapNode>>(
        zRoutedStudyThrowFailure(error),
      );
    }
  }
}
