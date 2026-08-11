import 'package:zcrud_core/domain.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Marqueur de version de l'API publique de `zcrud_flashcard`.
///
/// Référence les marqueurs de version des dépendances `zcrud_*` pour rendre
/// les arêtes du graphe de dépendances (invariant AD-1) effectivement
/// utilisées par du code, plutôt que déclarées sans usage.
abstract final class ZFlashcardApi {
  const ZFlashcardApi._();

  /// Version de l'API publique.
  static const String version = '0.2.0';

  /// Rattache l'arête `zcrud_flashcard -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;

  /// Rattache l'arête `zcrud_flashcard -> zcrud_markdown`.
  static const String markdownApiVersion = ZMarkdownApi.version;

  // Ce paquet ne dépend pas de `zcrud_export` : une surface de présentation
  // ne doit pas imposer une capacité orthogonale à ses consommateurs. Un
  // export flashcard, le jour où il existera, vivra dans un satellite dédié.
}
