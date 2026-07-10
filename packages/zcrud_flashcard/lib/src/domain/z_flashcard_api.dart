import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Marqueur d'API publique de `zcrud_flashcard` (placeholder E1-2).
///
/// Substance réelle posée dans la feature-story dédiée. Référence les
/// marqueurs des dépendances `zcrud_*` pour rendre les arêtes AD-1
/// effectivement utilisées (acyclicité tangible, pas d'import mort).
abstract final class ZFlashcardApi {
  const ZFlashcardApi._();

  /// Version de l'API publique (E9-2 : sous-système SRS pluggable posé —
  /// `ZRepetitionInfo` + `ZSrsScheduler`/`ZSm2Scheduler` + `ZSrsConfig`).
  static const String version = '0.2.0';

  /// Rattache l'arête AD-1 `zcrud_flashcard -> zcrud_core`.
  static const String coreApiVersion = ZCoreApi.version;

  /// Rattache l'arête AD-1 `zcrud_flashcard -> zcrud_markdown`.
  static const String markdownApiVersion = ZMarkdownApi.version;

  /// Rattache l'arête AD-1 `zcrud_flashcard -> zcrud_export`.
  static const String exportApiVersion = ZExportApi.version;
}
