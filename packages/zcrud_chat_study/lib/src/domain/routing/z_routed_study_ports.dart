/// Câblage d'ensemble des six ports d'étude **routés** —
/// `buildRoutedStudyPorts`.
///
/// Un hôte qui gouverne ses générations par route branche les six ports en
/// **une seule expression** : un catalogue, un routeur, un gate, les clés de
/// tâche de son vocabulaire, puis un annuaire de ports par famille. Il n'y a
/// rien d'autre à assembler.
///
/// ```dart
/// final ZRoutedStudyPorts ports = buildRoutedStudyPorts(
///   catalog: catalog,
///   routerId: 'study',
///   gate: myGate,
///   taskKeys: const ZRoutedStudyTaskKeys(
///     mindmap: 'generate_mindmap',
///     noteSummary: 'summarize_note',
///     explanation: 'explain',
///     explanationStream: 'explain',
///     podcast: 'generate_podcast',
///     flashcards: 'generate_flashcards',
///   ),
///   mindmapHandlers: <String, ZMindmapGenerationPort>{'default': myMindmap},
/// );
/// ```
///
/// Les clés de tâche ci-dessus sont des **exemples** : ce paquet n'en publie
/// aucune constante et n'interprète aucune valeur — le vocabulaire appartient
/// entièrement à l'hôte, qui doit le faire coïncider avec ce que son routeur
/// déclare.
///
/// Une famille dont l'annuaire est vide et sans repli reste câblée : elle
/// rend un refus typé à l'appel plutôt que d'être absente de l'arbre. C'est
/// délibéré — un port manquant se découvre au `null`, un port qui refuse se
/// découvre par un `Left` lisible.
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_study/zcrud_study.dart';

import 'z_chat_routed_ai_explanation_port.dart';
import 'z_chat_routed_ai_explanation_stream_port.dart';
import 'z_chat_routed_flashcard_generation_port.dart';
import 'z_chat_routed_mindmap_generation_port.dart';
import 'z_chat_routed_note_summary_port.dart';
import 'z_chat_routed_podcast_generation_port.dart';

/// Les clés de tâche sous lesquelles le routeur de l'hôte déclare ses routes.
///
/// Six clés **requises** et opaques : aucune valeur par défaut n'est fournie,
/// car un défaut du socle deviendrait un vocabulaire imposé aux hôtes. Deux
/// familles peuvent partager la même clé (une explication one-shot et sa
/// version progressive empruntent souvent la même route).
class ZRoutedStudyTaskKeys {
  /// Construit le jeu de clés de tâche.
  const ZRoutedStudyTaskKeys({
    required this.mindmap,
    required this.noteSummary,
    required this.explanation,
    required this.explanationStream,
    required this.podcast,
    required this.flashcards,
  });

  /// Clé de tâche de la génération de carte mentale.
  final String mindmap;

  /// Clé de tâche du résumé de note.
  final String noteSummary;

  /// Clé de tâche de l'explication one-shot.
  final String explanation;

  /// Clé de tâche de l'explication progressive.
  final String explanationStream;

  /// Clé de tâche de la génération de podcast.
  final String podcast;

  /// Clé de tâche de la génération de flashcards.
  final String flashcards;
}

/// Les six ports d'étude routés, câblés sur un même catalogue et un même
/// gate. Valeur immuable : aucun état, aucun cycle de vie à gérer.
class ZRoutedStudyPorts {
  /// Construit l'ensemble des six ports.
  const ZRoutedStudyPorts({
    required this.mindmap,
    required this.noteSummary,
    required this.explanation,
    required this.explanationStream,
    required this.podcast,
    required this.flashcards,
  });

  /// Port de génération de carte mentale, routé.
  final ZMindmapGenerationPort mindmap;

  /// Port de résumé de note, routé.
  final ZNoteSummaryPort noteSummary;

  /// Port d'explication one-shot, routé.
  final ZAiExplanationPort explanation;

  /// Port d'explication progressive, routé.
  final ZAiExplanationStreamPort explanationStream;

  /// Port de génération de podcast, routé.
  final ZPodcastGenerationPort podcast;

  /// Port de génération de flashcards, routé.
  final ZFlashcardGenerationPort flashcards;
}

/// Câble les six ports d'étude sur [catalog] et [routerId] en une expression.
///
/// [gate] refuse tout par défaut : une route gouvernée doit être ouverte
/// explicitement. Chaque famille reçoit son annuaire de ports (`…Handlers`,
/// vide par défaut) et son repli optionnel (`…Fallback`, `null` par défaut).
ZRoutedStudyPorts buildRoutedStudyPorts({
  required ZChatRouteCatalogPort catalog,
  required String routerId,
  required ZRoutedStudyTaskKeys taskKeys,
  ZChatRouteGate gate = const ZDenyAllChatRouteGate(),
  Map<String, ZMindmapGenerationPort> mindmapHandlers =
      const <String, ZMindmapGenerationPort>{},
  ZMindmapGenerationPort? mindmapFallback,
  Map<String, ZNoteSummaryPort> noteSummaryHandlers =
      const <String, ZNoteSummaryPort>{},
  ZNoteSummaryPort? noteSummaryFallback,
  Map<String, ZAiExplanationPort> explanationHandlers =
      const <String, ZAiExplanationPort>{},
  ZAiExplanationPort? explanationFallback,
  Map<String, ZAiExplanationStreamPort> explanationStreamHandlers =
      const <String, ZAiExplanationStreamPort>{},
  ZAiExplanationStreamPort? explanationStreamFallback,
  Map<String, ZPodcastGenerationPort> podcastHandlers =
      const <String, ZPodcastGenerationPort>{},
  ZPodcastGenerationPort? podcastFallback,
  Map<String, ZFlashcardGenerationPort> flashcardHandlers =
      const <String, ZFlashcardGenerationPort>{},
  ZFlashcardGenerationPort? flashcardFallback,
}) => ZRoutedStudyPorts(
  mindmap: ZChatRoutedMindmapGenerationPort(
    catalog: catalog,
    routerId: routerId,
    gate: gate,
    handlers: mindmapHandlers,
    fallback: mindmapFallback,
    taskKey: taskKeys.mindmap,
  ),
  noteSummary: ZChatRoutedNoteSummaryPort(
    catalog: catalog,
    routerId: routerId,
    gate: gate,
    handlers: noteSummaryHandlers,
    fallback: noteSummaryFallback,
    taskKey: taskKeys.noteSummary,
  ),
  explanation: ZChatRoutedAiExplanationPort(
    catalog: catalog,
    routerId: routerId,
    gate: gate,
    handlers: explanationHandlers,
    fallback: explanationFallback,
    taskKey: taskKeys.explanation,
  ),
  explanationStream: ZChatRoutedAiExplanationStreamPort(
    catalog: catalog,
    routerId: routerId,
    gate: gate,
    handlers: explanationStreamHandlers,
    fallback: explanationStreamFallback,
    taskKey: taskKeys.explanationStream,
  ),
  podcast: ZChatRoutedPodcastGenerationPort(
    catalog: catalog,
    routerId: routerId,
    gate: gate,
    handlers: podcastHandlers,
    fallback: podcastFallback,
    taskKey: taskKeys.podcast,
  ),
  flashcards: ZChatRoutedFlashcardGenerationPort(
    catalog: catalog,
    routerId: routerId,
    gate: gate,
    handlers: flashcardHandlers,
    fallback: flashcardFallback,
    taskKey: taskKeys.flashcards,
  ),
);
