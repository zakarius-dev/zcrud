import 'package:zcrud_core/domain.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Marqueur d'API publique de `zcrud_flashcard` (placeholder E1-2).
///
/// Substance réelle posée dans la feature-story dédiée. Référence les
/// marqueurs des dépendances `zcrud_*` pour rendre les arêtes AD-1
/// effectivement utilisées (acyclicité tangible, pas d'import mort).
abstract final class ZFlashcardApi {
  const ZFlashcardApi._();

  /// Version de l'API publique (E9-2 : sous-système SRS pluggable posé —
  /// `ZRepetitionInfo` + `ZSrsScheduler`/`ZSm2Scheduler` + `ZSrsConfig`).
  static const String version = '0.2.0';

  /// Rattache l'arête AD-1 `zcrud_flashcard -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;

  /// Rattache l'arête AD-1 `zcrud_flashcard -> zcrud_markdown`.
  static const String markdownApiVersion = ZMarkdownApi.version;

  // CR-LEX-17 — l'arête `zcrud_flashcard -> zcrud_export` est SUPPRIMÉE.
  //
  // Elle n'existait que pour rendre l'arête « tangible » (marquage E1-2) : aucun
  // code de ce package n'utilisait la moindre capacité d'export. Mais en
  // `dependencies` RUNTIME, elle tirait `zcrud_export` — donc les moteurs
  // Syncfusion XLSIO et PDF, épinglés en majeure — dans le graphe de TOUT hôte
  // affichant une simple carte de révision.
  //
  // Coût mesuré côté lex_douane : intersection VIDE avec leur Syncfusion 33.x
  // (`syncfusion_flutter_pdfviewer` 33.x verrouille `syncfusion_flutter_pdf`
  // ^33.2.15), donc AUCUNE ligne de Dart ne compilait — et le seul contournement
  // était une montée de version MAJEURE sur des surfaces de production.
  //
  // Une surface de PRÉSENTATION ne doit pas imposer une capacité orthogonale.
  // L'export flashcard, le jour où il existera, vivra dans un satellite dédié.
}
