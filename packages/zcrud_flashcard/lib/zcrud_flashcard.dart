/// Barrel d'API publique de `zcrud_flashcard`.
///
/// - E9-1 : `ZFlashcard` (entité canonique codegen) + `ZChoice` +
///   `ZFlashcardType` + provenance ouverte `ZFlashcardSource`.
/// - E9-2 : SRS pluggable `ZRepetitionInfo` + `ZSrsScheduler`/`ZSm2Scheduler` +
///   `ZSrsConfig`.
/// - E9-3 : organisation `ZStudyFolder` + `ZReviewMode` + `ZStudySessionConfig`,
///   primitives PURES `validatePlacement` (hiérarchie 2 niveaux) et
///   `ZStudySessionSelector` (sélection filtrée).
/// - E9-4 : couche `data/` offline-first — `ZFlashcardRepository` (coordinateur
///   composant les ports neutres d'E5) + port SRS séparé `ZRepetitionStore`
///   (invariant SRS top-level, voie d'écriture unique `reviewCard`).
/// - E9-5 : couche `presentation/` — widgets d'édition **additifs** servis via
///   `ZWidgetRegistry` (`registerZFlashcardEditors`, sélecteur de type/QCM/
///   vrai-faux), fabriques `ZFlashcardEditionFields`, validation éditeur
///   `ZFlashcardEditionValidator`, scope `ZFlashcardEditingScope`. Déplacement
///   de carte + re-sync `folderId` SRS (M1) et idempotence `initRepetition` +
///   `resetRepetition` (L2) côté `ZFlashcardRepository`.
///
/// **Extensions générées masquées (`hide`)** : `ZRepetitionInfoZcrud` (E9-2),
/// `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` (E9-3) portent un
/// `copyWith`/`toMap` internes ; la (dé)sérialisation et la copie passent par
/// l'API d'instance (`fromMap`/`toMap`/`copyWith` à sentinelle), pas par
/// l'extension générée (qui remettrait `extra`/`extension` à leurs défauts →
/// perte silencieuse).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_flashcard_repository.dart';
export 'src/data/z_repetition_store.dart';
export 'src/domain/z_choice.dart';
export 'src/domain/z_flashcard.dart';
export 'src/domain/z_flashcard_api.dart';
export 'src/domain/z_flashcard_source.dart';
export 'src/domain/z_flashcard_type.dart';
export 'src/domain/z_repetition_info.dart' hide ZRepetitionInfoZcrud;
export 'src/domain/z_review_mode.dart';
export 'src/domain/z_sm2_scheduler.dart';
export 'src/domain/z_srs_config.dart';
export 'src/domain/z_srs_scheduler.dart';
export 'src/domain/z_study_folder.dart' hide ZStudyFolderZcrud;
export 'src/domain/z_study_folder_hierarchy.dart';
export 'src/domain/z_study_session_config.dart' hide ZStudySessionConfigZcrud;
export 'src/domain/z_study_session_selector.dart';
// E9-5 — couche presentation/ (widgets d'édition additifs).
export 'src/presentation/z_flashcard_choices_field_widget.dart';
export 'src/presentation/z_flashcard_editing_scope.dart';
export 'src/presentation/z_flashcard_edition_validator.dart';
export 'src/presentation/z_flashcard_editor_config.dart';
export 'src/presentation/z_flashcard_editors.dart';
export 'src/presentation/z_flashcard_true_false_field_widget.dart';
export 'src/presentation/z_flashcard_type_field_widget.dart';
