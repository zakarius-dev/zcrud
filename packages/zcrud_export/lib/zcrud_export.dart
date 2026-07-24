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
// CR-LEX-40 : le PDF et les pièces NEUTRES vivent désormais dans
// `zcrud_export_pdf`, qui n'a AUCUNE dépendance tableur. Ce paquet le
// ré-exporte INTÉGRALEMENT et n'ajoute que l'Excel : la surface publique de
// `zcrud_export` est donc INCHANGÉE — aucun consommateur ne casse. Un hôte
// PDF-seul bascule sur `zcrud_export_pdf` et perd `syncfusion_flutter_xlsio`,
// `syncfusion_officecore` et `jiffy`.
export 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

export 'src/data/z_export_api.dart' show ZExportApi;
export 'src/data/z_exporter.dart' show ZExporter;
