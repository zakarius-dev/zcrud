import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// Marqueur d'API publique de `zcrud_export_ui` (arêtes AD-1).
///
/// Point d'ancrage STABLE de l'API publique du satellite (patron `ZExportApi` /
/// `ZCoreApi`) : il rattache les DEUX arêtes AD-1 sortantes de ce package —
/// `zcrud_export_ui -> zcrud_export` (le port `ZLatexRasterizer` implémenté ici,
/// et les bytes produits par `ZFlashcardPdfTemplate`) et `zcrud_export_ui ->
/// zcrud_core`. La substance réelle est le rasteriseur concret + les services de
/// preview/impression/partage ; ce marqueur ne fait qu'exposer une version d'API.
abstract final class ZExportUiApi {
  const ZExportUiApi._();

  /// Version de l'API publique (marqueur ; distincte de la version du package).
  static const String version = '0.1.0';

  /// Rattache l'arête AD-1 `zcrud_export_ui -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;

  /// Rattache l'arête AD-1 `zcrud_export_ui -> zcrud_export`.
  static const String exportApiVersion = ZExportApi.version;
}
