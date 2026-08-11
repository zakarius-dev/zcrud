import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_get`.
///
/// Référence les marqueurs des dépendances `zcrud_*` pour rendre les arêtes
/// invariant AD-1 effectivement utilisées (acyclicité tangible, pas d'import
/// mort).
abstract final class ZGetApi {
  const ZGetApi._();

  /// Version de l'API publique du paquet.
  static const String version = '0.0.1';

  /// Rattache l'arête invariant AD-1 `zcrud_get -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;
}
