import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_generator`.
///
/// Référence les marqueurs des dépendances `zcrud_*` pour rendre les arêtes
/// acycliques (invariant AD-1) effectivement utilisées — pas d'import mort.
abstract final class ZGeneratorApi {
  const ZGeneratorApi._();

  /// Version de l'API publique de ce paquet.
  static const String version = '0.0.1';

  /// Rattache l'arête (invariant AD-1) `zcrud_generator -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;

  /// Rattache l'arête (invariant AD-1) `zcrud_generator -> zcrud_annotations`.
  static const String annotationsApiVersion = ZAnnotationsApi.version;
}
