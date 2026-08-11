import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_intl`.
///
/// Référence les marqueurs des dépendances `zcrud_*` pour rendre les
/// arêtes du graphe de dépendances (invariant AD-1) effectivement
/// utilisées — un import n'est jamais mort.
abstract final class ZIntlApi {
  const ZIntlApi._();

  /// Version du marqueur d'API publique de ce paquet.
  static const String version = '0.0.1';

  /// Rattache l'arête `zcrud_intl -> zcrud_core` (invariant AD-1).
  static const String coreApiVersion = ZCoreApi.version;
}
