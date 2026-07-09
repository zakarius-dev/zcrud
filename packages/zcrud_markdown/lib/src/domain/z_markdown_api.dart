import 'package:zcrud_core/zcrud_core.dart';

/// Marqueur d'API publique de `zcrud_markdown` (placeholder E1-2).
///
/// Substance réelle posée dans la feature-story dédiée. Référence les
/// marqueurs des dépendances `zcrud_*` pour rendre les arêtes AD-1
/// effectivement utilisées (acyclicité tangible, pas d'import mort).
abstract final class ZMarkdownApi {
  const ZMarkdownApi._();

  /// Version de l'API publique au stade squelette.
  static const String version = '0.0.1';

  /// Rattache l'arête AD-1 `zcrud_markdown -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;
}
