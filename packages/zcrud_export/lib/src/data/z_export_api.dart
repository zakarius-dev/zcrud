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
  /// Suit les évolutions **additives** de la surface publique (dernier ajout :
  /// les exporteurs de liste `ZCsvListExporter`/`ZXlsxListExporter`, et
  /// `ZPdfListExporter` côté `zcrud_export_pdf`, qui réalisent le port
  /// `ZListExporter` du cœur). Le **nom** du champ reste `version` (consommé
  /// par `zcrud_flashcard`) — jamais renommé, jamais de retrait.
  static const String version = '0.3.0';

  /// Rattache l'arête AD-1 `zcrud_export -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;
}
