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
library;

export 'src/data/z_export_api.dart' show ZExportApi;
export 'src/data/z_export_table.dart' show ZExportTable;
export 'src/data/z_exporter.dart' show ZExporter;
