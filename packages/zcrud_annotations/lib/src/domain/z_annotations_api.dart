import 'package:zcrud_core/edition.dart';

/// Marqueur d'API publique de `zcrud_annotations`.
///
/// Référence les marqueurs des dépendances `zcrud_*` pour rendre l'arête
/// acyclique vers `zcrud_core` (invariant AD-1) effectivement utilisée — pas
/// d'import mort.
abstract final class ZAnnotationsApi {
  const ZAnnotationsApi._();

  /// Version de l'API publique de ce paquet.
  static const String version = '0.0.1';

  /// Rattache l'arête (invariant AD-1) `zcrud_annotations -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;
}
