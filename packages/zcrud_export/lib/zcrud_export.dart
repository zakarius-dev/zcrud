/// Barrel d'API publique de `zcrud_export`.
///
/// Export tabulaire **neutre** : `ZListRenderRequest` (colonnes dérivées + lignes
/// du cœur `zcrud_core`) → bytes Excel (`.xlsx`) / PDF via [ZExporter].
///
/// **Isolation (AD-1/AD-8/SM-5)** : les backends Syncfusion (`syncfusion_flutter_xlsio`
/// / `_pdf`) sont CONFINÉS à `lib/src/data/z_{excel,pdf}_exporter.dart` et ne
/// sont JAMAIS réexportés ici. Ce barrel n'expose AUCUN symbole Syncfusion ; les
/// signatures publiques sont neutres (entrées `zcrud_core`, sorties `Uint8List`).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
///
/// **E11b-3 (additif, jamais de retrait — leçon rétro : la suppression de
/// `ZExportApi` en E11a-3 avait cassé `zcrud_flashcard`)** : au-delà de l'export
/// tabulaire, ce barrel expose désormais aussi l'assemblage images→PDF
/// ([ZPdfCreationService]), la sauvegarde cross-platform ([ZFileSaver] /
/// [ZFileSaveResult]) et les options de mise en page PDF anti-rognage
/// ([ZPdfExportOptions] / [ZPdfOrientation]). Tous NEUTRES (bytes/chaînes),
/// Syncfusion/`dart:io`/`package:web` restant confinés hors du barrel.
library;

// Exports triés alphabétiquement (`directives_ordering`). API STABLE E11a-3
// (`ZExportApi`/`ZExportTable`/`ZExporter`) : ne JAMAIS retirer/renommer (la
// suppression de `ZExportApi` en E11a-3 avait cassé `zcrud_flashcard`). Ajouts
// E11b-3 (`ZFileSaver*`/`ZPdfCreationService`/`ZPdfExportOptions`) et su-11
// (gabarit PDF flashcards `ZFlashcardPdf*` + port PUR `ZLatexRasterizer` +
// `ZAnswerVisibility` + `ZExportedFile`) — tous ADDITIFS, aucun symbole
// Syncfusion réexporté (AD-42, l'impl concrète du rasteriseur vit dans
// `zcrud_export_ui`).
export 'src/data/z_answer_visibility.dart' show ZAnswerVisibility;
export 'src/data/z_export_api.dart' show ZExportApi;
export 'src/data/z_export_table.dart' show ZExportTable;
export 'src/data/z_exported_file.dart' show ZExportedFile;
export 'src/data/z_exporter.dart' show ZExporter;
export 'src/data/z_file_save_result.dart' show ZFileSaveResult;
export 'src/data/z_file_saver.dart' show ZFileSaver;
export 'src/data/z_flashcard_pdf_input.dart'
    show
        ZFlashcardPdfCard,
        ZFlashcardPdfChoice,
        ZFlashcardPdfInput,
        ZFlashcardPdfLabels,
        kFlashcardPdfTypeExercise,
        kFlashcardPdfTypeFillBlank,
        kFlashcardPdfTypeMultipleChoice,
        kFlashcardPdfTypeOpenQuestion,
        kFlashcardPdfTypeShortAnswer,
        kFlashcardPdfTypeTrueOrFalse;
export 'src/data/z_flashcard_pdf_template.dart' show ZFlashcardPdfTemplate;
export 'src/data/z_pdf_creation_service.dart' show ZPdfCreationService;
export 'src/data/z_pdf_export_options.dart' show ZPdfExportOptions, ZPdfOrientation;
export 'src/domain/z_latex_rasterizer.dart' show ZLatexRasterizer;
