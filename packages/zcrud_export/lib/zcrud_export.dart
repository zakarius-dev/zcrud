/// Barrel d'API publique de `zcrud_export`.
///
/// Export tabulaire **neutre** : `ZListRenderRequest` (colonnes dérivées + lignes
/// du cœur `zcrud_core`) → bytes Excel (`.xlsx`) / PDF via [ZExporter].
///
/// **Isolation (invariants AD-1/AD-8)** : les backends Syncfusion
/// (`syncfusion_flutter_xlsio` / `_pdf`) sont CONFINÉS à
/// `lib/src/data/z_{excel,pdf}_exporter.dart` et ne sont JAMAIS réexportés
/// ici. Ce barrel n'expose AUCUN symbole Syncfusion ; les signatures
/// publiques sont neutres (entrées `zcrud_core`, sorties `Uint8List`).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
///
/// Au-delà de l'export tabulaire, ce barrel expose aussi l'assemblage
/// images→PDF ([ZPdfCreationService]), la sauvegarde cross-platform
/// ([ZFileSaver] / [ZFileSaveResult]) et les options de mise en page PDF
/// anti-rognage ([ZPdfExportOptions] / [ZPdfOrientation]). Tous NEUTRES
/// (bytes/chaînes), Syncfusion/`dart:io`/`package:web` restant confinés hors
/// du barrel. Cette surface est **additive et stable** : aucun symbole n'en
/// est jamais retiré ni renommé, un paquet aval pouvant s'y ancrer
/// durablement.
library;

// Exports triés alphabétiquement (`directives_ordering`). Aucun symbole
// Syncfusion réexporté (l'impl concrète du rasteriseur vit dans
// `zcrud_export_ui`).
//
// Le PDF et les pièces neutres vivent dans `zcrud_export_pdf`, qui n'a aucune
// dépendance tableur. Ce paquet le ré-exporte intégralement et n'ajoute que
// l'Excel : la surface publique de `zcrud_export` reste ainsi inchangée pour
// un consommateur existant. Un hôte PDF-seul bascule sur `zcrud_export_pdf`
// et perd `syncfusion_flutter_xlsio`, `syncfusion_officecore` et `jiffy`.
export 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

export 'src/data/z_csv_list_exporter.dart' show ZCsvListExporter;
export 'src/data/z_export_api.dart' show ZExportApi;
export 'src/data/z_exporter.dart' show ZExporter;
export 'src/data/z_xlsx_list_exporter.dart' show ZXlsxListExporter;
