import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_export` (édge AD-1).
///
/// Conserve un point d'ancrage STABLE de l'API publique du package (comme
/// `ZCoreApi`/`ZMarkdownApi`/… pour les autres packages) : il rattache l'arête
/// AD-1 `zcrud_export -> zcrud_core` (import effectivement utilisé) et il est
/// référencé par les packages en aval (`zcrud_flashcard`, `zcrud_mindmap`) pour
/// rendre leurs arêtes `-> zcrud_export` tangibles. La substance d'export réelle
/// est [ZExporter] ; ce marqueur ne fait qu'exposer une version d'API stable.
abstract final class ZExportApi {
  const ZExportApi._();

  /// Version de l'API publique (marqueur ; distincte de la version du package).
  ///
  /// Bump E11b-3 `0.0.1 → 0.1.0` : ajouts ADDITIFS (`ZPdfCreationService`,
  /// `ZFileSaver`/`ZFileSaveResult`, `ZPdfExportOptions`/`ZPdfOrientation`).
  ///
  /// Bump su-11 `0.1.0 → 0.2.0` : ajouts ADDITIFS (gabarit PDF flashcards
  /// `ZFlashcardPdfTemplate`, port PUR `ZLatexRasterizer`, `ZAnswerVisibility`,
  /// `ZFlashcardPdfInput`/`ZFlashcardPdfCard`/`ZFlashcardPdfChoice`/
  /// `ZFlashcardPdfLabels`, `ZExportedFile`). Le **nom** du champ reste `version`
  /// (consommé par `zcrud_flashcard`) — jamais renommé, jamais de retrait.
  static const String version = '0.2.0';

  /// Rattache l'arête AD-1 `zcrud_export -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;
}
