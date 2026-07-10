import 'package:zcrud_core/domain.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Marqueur d'API publique de `zcrud_mindmap` (placeholder E1-2).
///
/// Substance réelle posée dans la feature-story dédiée. Référence les
/// marqueurs des dépendances `zcrud_*` pour rendre les arêtes AD-1
/// effectivement utilisées (acyclicité tangible, pas d'import mort).
abstract final class ZMindmapApi {
  const ZMindmapApi._();

  /// Version de l'API publique au stade squelette.
  static const String version = '0.0.1';

  /// Rattache l'arête AD-1 `zcrud_mindmap -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;

  /// Rattache l'arête AD-1 `zcrud_mindmap -> zcrud_markdown`.
  static const String markdownApiVersion = ZMarkdownApi.version;
}
