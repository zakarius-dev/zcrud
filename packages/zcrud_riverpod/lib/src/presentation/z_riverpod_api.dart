import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_riverpod`.
///
/// Référence les marqueurs des dépendances `zcrud_*` pour rendre l'arête
/// acyclique (invariant AD-1) effectivement utilisée — pas d'import mort.
abstract final class ZRiverpodApi {
  const ZRiverpodApi._();

  /// Version de l'API publique de ce paquet.
  static const String version = '0.0.1';

  /// Rattache l'arête (invariant AD-1) `zcrud_riverpod -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;
}
