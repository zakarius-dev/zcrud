/// Adaptateur **par route** du port de génération de podcast.
///
/// ## Route par CONFIGURATION
///
/// `ZPodcastGenerationRequest` ne transporte **pas** de `routeId` : la route
/// vient entièrement de la configuration (clé de tâche + catalogue), et la
/// requête est déléguée **verbatim** — aucune route n'est injectée dans son
/// `extra`.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyPodcast;

import 'z_routed_study_dispatch.dart';

/// Répartit chaque génération de podcast vers le port de sa route.
class ZChatRoutedPodcastGenerationPort implements ZPodcastGenerationPort {
  /// Construit l'adaptateur routé.
  ///
  /// [taskKey] est la clé de tâche **de l'hôte** sous laquelle le routeur
  /// déclare sa route. [gate] refuse tout par défaut.
  const ZChatRoutedPodcastGenerationPort({
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
  final Map<String, ZPodcastGenerationPort> handlers;

  /// Port de repli, ou `null`.
  final ZPodcastGenerationPort? fallback;

  /// Clé de tâche opaque sous laquelle la route est déclarée.
  final String taskKey;

  @override
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  ) async {
    final ZResult<ZRoutedStudyTarget<ZPodcastGenerationPort>> target =
        await zResolveRoutedStudyPort<ZPodcastGenerationPort>(
      catalog: catalog,
      routerId: routerId,
      gate: gate,
      handlers: handlers,
      taskKey: taskKey,
      requestRouteId: null,
      fallback: fallback,
    );
    final ZFailure? failure = zRoutedStudyFailureOf(target);
    if (failure != null) return Left<ZFailure, ZStudyPodcast>(failure);
    final ZRoutedStudyTarget<ZPodcastGenerationPort> t =
        zRoutedStudyValueOf(target)!;
    try {
      return await t.port.generatePodcast(request);
    } catch (error) {
      return Left<ZFailure, ZStudyPodcast>(zRoutedStudyThrowFailure(error));
    }
  }
}
