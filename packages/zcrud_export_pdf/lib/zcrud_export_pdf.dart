/// API publique d'export **PDF** de zcrud — sans aucune dépendance tableur.
///
/// Un hôte qui n'exporte que du PDF n'a besoin d'aucune dépendance tableur
/// (`syncfusion_flutter_xlsio` et ses transitifs `syncfusion_officecore`,
/// `jiffy`). Dart n'ayant pas de dépendance optionnelle, seule une frontière
/// de paquet peut les écarter.
///
/// **Un hôte PDF-seul dépend de CE paquet.** `zcrud_export` le ré-exporte
/// intégralement en y ajoutant l'Excel : aucun consommateur existant ne change.
///
/// **Isolation (invariants AD-1/AD-8)** : `syncfusion_flutter_pdf` est CONFINÉ
/// aux impls concrètes sous `lib/src/data/` — aucun type Syncfusion n'apparaît
/// dans cette API (bytes neutres `Uint8List`, tables neutres).
library;

export 'src/data/z_answer_visibility.dart' show ZAnswerVisibility;
export 'src/data/z_export_table.dart' show ZExportTable;
export 'src/data/z_exported_file.dart' show ZExportedFile;
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
export 'src/data/z_pdf_export_options.dart'
    show ZPdfExportOptions, ZPdfHeaderSpec, ZPdfOrientation;
export 'src/data/z_pdf_exporter.dart' show buildPdfBytes;
export 'src/data/z_pdf_list_exporter.dart' show ZPdfListExporter;
export 'src/domain/z_font_coverage.dart' show ZFontCoverage;
export 'src/domain/z_latex_rasterizer.dart' show ZLatexRasterizer;
// Port de police TrueType. Sans lui, tout Unicode hors WinAnsi (arabe, grec,
// CJK, emoji) est réduit en `?` à l'export — le fournir est le seul
// contournement possible, le gabarit n'exposant aucun autre point
// d'injection.
export 'src/domain/z_pdf_font_provider.dart' show ZPdfFontProvider;
