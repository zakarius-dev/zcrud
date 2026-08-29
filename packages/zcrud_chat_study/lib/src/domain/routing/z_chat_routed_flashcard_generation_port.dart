/// Adaptateur **par route** du port de génération de flashcards.
///
/// ## Route par CONFIGURATION
///
/// `ZFlashcardGenerationRequest` ne transporte **pas** de `routeId` : la
/// route vient entièrement de la configuration (clé de tâche + catalogue), et
/// la requête est déléguée **verbatim** — ni `provenance`, ni
/// `typesDistribution`, ni `extra` ne sont réécrits au passage.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZFlashcard;
import 'package:zcrud_study/zcrud_study.dart';

import 'z_routed_study_dispatch.dart';

/// Répartit chaque génération de flashcards vers le port de sa route.
class ZChatRoutedFlashcardGenerationPort implements ZFlashcardGenerationPort {
  /// Construit l'adaptateur routé.
  ///
  /// [taskKey] est la clé de tâche **de l'hôte** sous laquelle le routeur
  /// déclare sa route. [gate] refuse tout par défaut.
  const ZChatRoutedFlashcardGenerationPort({
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
  final Map<String, ZFlashcardGenerationPort> handlers;

  /// Port de repli, ou `null`.
  final ZFlashcardGenerationPort? fallback;

  /// Clé de tâche opaque sous laquelle la route est déclarée.
  final String taskKey;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  ) async {
    final ZResult<ZRoutedStudyTarget<ZFlashcardGenerationPort>> target =
        await zResolveRoutedStudyPort<ZFlashcardGenerationPort>(
      catalog: catalog,
      routerId: routerId,
      gate: gate,
      handlers: handlers,
      taskKey: taskKey,
      requestRouteId: null,
      fallback: fallback,
    );
    final ZFailure? failure = zRoutedStudyFailureOf(target);
    if (failure != null) return Left<ZFailure, List<ZFlashcard>>(failure);
    final ZRoutedStudyTarget<ZFlashcardGenerationPort> t =
        zRoutedStudyValueOf(target)!;
    try {
      return await t.port.generateFlashcards(request);
    } catch (error) {
      return Left<ZFailure, List<ZFlashcard>>(zRoutedStudyThrowFailure(error));
    }
  }
}
