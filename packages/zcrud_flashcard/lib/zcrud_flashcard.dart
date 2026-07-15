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

// ES-1.1 — `ZStudyFolder` + hiérarchie + `ZReviewMode` + `ZStudySessionConfig` +
// `ZStudySessionSelector` + le port `ZSessionCandidate` sont REMONTÉS dans
// `zcrud_study_kernel` (source unique, AD-18). Réexport depuis son barrel : le
// kernel masque déjà `ZStudyFolderZcrud`/`ZStudySessionConfigZcrud` (politique
// `hide` identique à l'ancienne surface `zcrud_flashcard`). L'ergonomie typée
// `ZFlashcardType` de la config est restituée par
// `z_study_session_config_flashcard_x.dart` (ci-dessous).
//
// ES-1.2 (D3, solde LOW-1 du code-review ES-1.1) — narrowing par liste `hide`
// (JAMAIS `show`) : un `show` explicite devrait aussi énumérer les symboles
// GÉNÉRÉS du kernel (`registerZStudyFolder`, `registerZStudySessionConfig`,
// field-specs via `part '*.g.dart'`) — un oubli casserait un consommateur
// externe (migration DODLP). Le `hide` ci-dessous ne retire QUE les symboles
// ES-1.2 (utilitaires hors périmètre flashcard, connus par construction) et
// préserve donc INTÉGRALEMENT la surface historique E9, symboles générés
// inclus (prouvé par le test de surface positive
// `test/z_public_surface_test.dart`).
//
// RÈGLE DE MAINTENANCE (définitive) : tout NOUVEAU symbole public ajouté au
// barrel `zcrud_study_kernel` qui n'a rien à voir avec les flashcards DOIT être
// ajouté à cette liste `hide` (ex. futur `ZSyncMeta` d'ES-1.3, entités ES-2, …).
//
// Cette règle est OUTILLÉE (finding L4 du code-review ES-1.2), pas seulement
// écrite : `test/z_kernel_surface_guard_test.dart` croise les symboles publics
// RÉELS du barrel kernel avec cette liste `hide` + une allowlist explicite. Tout
// symbole kernel non classé fait ÉCHOUER les tests → la fuite silencieuse est
// impossible. Ne pas contourner ce garde : le mettre à jour EN CONSCIENCE.
export 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    hide
        ZColorPalette,
        ZKeyHash,
        zFnv1a32,
        ZUnorderedPlacement,
        applyOrder,
        normalizeTagTitle,
        dedupeByNormalizedTitle,
        // ES-2.4 — `ZFolderContentsOrder` : ordre de contenu de dossier study
        // PERSONNEL, NON pertinent flashcard ⇒ hors surface publique flashcard.
        ZFolderContentsOrder,
        ZFolderContentsOrderExtensionParser,
        kSectionOrdersKey,
        // ES-2.7 — vue « rythme du jour » (résultat de session + tâches
        // quotidiennes + agrégation via le port neutre `ZApproachingExam`) :
        // symboles study-niveau, NON pertinents flashcard ⇒ hors surface
        // publique flashcard (précédent EXACT `ZFolderContentsOrder`).
        ZStudySessionResult,
        ZDailyStudyTask,
        ZDueCardsTask,
        ZExamTask,
        ZApproachingExam,
        aggregateDailyStudyTasks,
        // ES-2.8 — podcast *content-addressed* (`ZStudyPodcast` + 3 enums +
        // fraîcheur `ZPodcastFreshness`/`podcastFreshness`) : symboles
        // study-niveau, NON pertinents flashcard ⇒ hors surface publique
        // flashcard (précédent EXACT `ZFolderContentsOrder` / ES-2.7).
        ZStudyPodcast,
        ZStudyPodcastExtensionParser,
        ZPodcastSourceKind,
        ZPodcastMode,
        ZPodcastStatus,
        ZPodcastFreshness,
        podcastFreshness;

export 'src/data/z_flashcard_repository.dart';
export 'src/data/z_repetition_store.dart';
export 'src/domain/z_choice.dart';
// 🔴 H3 (code-review ES-2.1, remédiation) — `hide ZFlashcardZcrud` MANQUAIT.
//
// `ZFlashcard` est `ZExtensible` ET porte le canal hors-codegen `source`. Son
// extension GÉNÉRÉE était **EXPORTÉE PUBLIQUEMENT** : le `copyWith` généré ne
// connaît QUE les champs `@ZcrudField` — il IGNORE `extra`, `extension` et
// `source`, et les REMET AUX DÉFAUTS.
//
//     import 'package:zcrud_flashcard/zcrud_flashcard.dart';
//     ZFlashcardZcrud(card).copyWith(question: 'x')
//     // ⇒ extra, extension ET source : DÉTRUITS, en silence.
//
// Le `copyWith` d'INSTANCE ne masque que l'appel IMPLICITE ; l'appel EXPLICITE
// d'extension restait ouvert depuis l'API PUBLIQUE. Ses 3 sœurs `ZExtensible` du
// repo étaient `hide` (`ZStudyFolderZcrud`, `ZRepetitionInfoZcrud`,
// `ZStudySessionConfigZcrud`) : **seule l'entité PHARE avait été oubliée** — sous
// 1000+ tests verts, parce que la politique `hide` vivait en COMMENTAIRE et
// qu'AUCUNE machine ne la tenait. C'est la MÊME faute que H1.
//
// ⇒ La règle est désormais **TENUE PAR LE GATE** : `gate:reserved-keys` règle (h)
//   (`scripts/ci/gate_reserved_keys.dart`), avec sa fixture d'échec isolée
//   (`prove_gates.dart` › `hide-extension-generee-exportee`).
export 'src/domain/z_flashcard.dart' hide ZFlashcardZcrud;
export 'src/domain/z_flashcard_api.dart';
export 'src/domain/z_flashcard_source.dart';
export 'src/domain/z_flashcard_type.dart';
export 'src/domain/z_repetition_info.dart' hide ZRepetitionInfoZcrud;
export 'src/domain/z_sm2_scheduler.dart';
export 'src/domain/z_srs_config.dart';
export 'src/domain/z_srs_scheduler.dart';
// ES-1.1 — ergonomie typée `ZFlashcardType` restituée sur `ZStudySessionConfig`
// (le noyau neutralise `types` en `List<String>`).
export 'src/domain/z_study_session_config_flashcard_x.dart';
// E9-5 — couche presentation/ (widgets d'édition additifs).
export 'src/presentation/z_flashcard_choices_field_widget.dart';
export 'src/presentation/z_flashcard_editing_scope.dart';
export 'src/presentation/z_flashcard_edition_validator.dart';
export 'src/presentation/z_flashcard_editor_config.dart';
export 'src/presentation/z_flashcard_editors.dart';
export 'src/presentation/z_flashcard_true_false_field_widget.dart';
export 'src/presentation/z_flashcard_type_field_widget.dart';
