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

// --- API STABLE E11a-3 (ne JAMAIS retirer/renommer) ---
export 'src/data/z_export_api.dart' show ZExportApi;
export 'src/data/z_export_table.dart' show ZExportTable;
export 'src/data/z_exporter.dart' show ZExporter;

// --- Ajouts additifs E11b-3 ---
export 'src/data/z_file_save_result.dart' show ZFileSaveResult;
export 'src/data/z_file_saver.dart' show ZFileSaver;
export 'src/data/z_pdf_creation_service.dart' show ZPdfCreationService;
export 'src/data/z_pdf_export_options.dart' show ZPdfExportOptions, ZPdfOrientation;
