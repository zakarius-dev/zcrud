import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_geo`.
///
/// Espace de noms statique portant les métadonnées de version de l'API
/// (invariant AD-1 : la dépendance unique de `zcrud_geo` vers `zcrud_core`
/// est référencée ici pour rester tangible).
abstract final class ZGeoApi {
  const ZGeoApi._();

  /// Version de l'API publique de `zcrud_geo`.
  static const String version = '0.0.1';

  /// Version de l'API publique de `zcrud_core` dont dépend ce paquet.
  static const String coreApiVersion = ZCoreApi.version;
}
