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
        // SU-1 (AD-38) — `zSectionKey` : constructeur canonique des clés de
        // `ZFolderContentsOrder.sectionOrders`. Même FAMILLE que les symboles
        // ci-dessus (`applyOrder`/`kSectionOrdersKey`, déjà masqués) : ordre de
        // contenu de dossier study, NON pertinent flashcard ⇒ hors surface
        // publique flashcard. Un consommateur qui compose une clé importe
        // `zcrud_study_kernel` (foyer unique — jamais de recopie à la main).
        zSectionKey,
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
        podcastFreshness,
        // ES-3.1 — port CRUD offline-first générique `ZStudyRepository<T>` : port
        // DATA study-niveau (Template Method `validate`→`persist`), NON pertinent
        // pour la surface flashcard historique ⇒ hors surface publique flashcard
        // (précédent EXACT `ZFolderContentsOrder` / ES-2.7 / ES-2.8).
        ZStudyRepository,
        // ES-3.3 — registre DÉCLARATIF de cascade (`ZCascadeEdge` +
        // `ZCascadeRegistry`) : mécanisme study-niveau de suppression bornée,
        // NON pertinent pour la surface flashcard historique ⇒ hors surface
        // publique flashcard (précédent EXACT `ZStudyRepository` / ES-3.1, D10).
        ZCascadeEdge,
        ZCascadeRegistry,
        // SU-6 (FR-SU11, D1/D3) — flamme d'assiduité (`ZStudyStreak` +
        // `zAdvanceStreak` + le jour civil) : compteur d'assiduité STUDY-niveau,
        // dépendant de dates SEULES et d'AUCUN concept flashcard (ni `ZSrsConfig`,
        // ni `ZRepetitionInfo`) ⇒ NON pertinent pour la surface flashcard
        // historique (précédent EXACT `ZStudyRepository` / ES-3.1, `ZCascadeEdge` /
        // ES-3.3). Le consommateur du streak est `zcrud_session`, qui importe le
        // barrel `zcrud_study_kernel` DIRECTEMENT (foyer unique).
        ZStudyStreak,
        ZStreakOutcome,
        ZStreakAdvance,
        zIsGradedMode,
        zAdvanceStreak,
        ZCivilDayOf,
        zLocalCivilDay,
        zFormatCivilDay,
        zIsCivilDay,
        zParseCivilDayNumber,
        zCivilDayNumber;

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
// SU-3 (AC2/AC3, AD-35) — port d'évaluation ADVISORY : il SUGGÈRE une qualité,
// il ne NOTE jamais et n'écrit JAMAIS le SRS (AD-33). Foyer IMPOSÉ par le graphe
// (AD-1) : `zcrud_study` dépend de `zcrud_flashcard` ⇒ le loger à côté de
// `ZFlashcardGenerationPort` créerait un CYCLE.
export 'src/domain/z_flashcard_answer_evaluation_port.dart';
export 'src/domain/z_flashcard_api.dart';
// SU-8 (AC13, FR-SU21, AD-45/D6) — « dupliquer pour modifier » : copie ÉPHÉMÈRE
// (`id: null`, `isReadOnly: false`, `createdAt`/`updatedAt` null) — AUCUN état
// personnel (ni SRS ni ordre : entités SÉPARÉES indexant des ids, inatteignables
// sans id — PROUVÉ, pas supposé). L'original n'est JAMAIS muté. Ctor nominal et
// non `copyWith` (qui ne peut pas remettre `id` à null ⇒ écraserait l'original).
export 'src/domain/z_flashcard_duplicate.dart';
// SU-6 (FR-SU12, D1) — filtres test/examen PURS : `ZMasteryLevel`/
// `zMasteryLevelOf` (bornes TOUTES lues sur `ZSrsConfig`, `clampQuality` UNIQUE
// voie de clamp — AD-46), `ZFlashcardTestFilters`, `zApplyTestFilters` (DÉLÈGUE
// dossier ∧ tags ∧ types à `ZStudySessionSelector` — jamais réécrits),
// `zDrawQuestions`/`zShuffleChoices` (aléa INJECTÉ — D5).
//
// SU-8 (AC5/AC6/AC7) — filtres de CONSULTATION, dans le MÊME fichier (ils
// partagent `zMatchesSourceKind`, l'implémentation UNIQUE du prédicat de
// provenance) mais fonction DISTINCTE : `ZFlashcardSearchField` (enum),
// `ZFlashcardBrowseFilters`, `zApplyBrowseFilters` — qui DÉLÈGUE dossier ∧ tags ∧
// types à `ZStudySessionSelector.matches` et JAMAIS à `selectFrom` (son plafond
// `count` tronquerait la liste). AUCUN `Random`, AUCUN `questionCount` : une
// liste de gestion ne TIRE pas (un dossier de 2 000 cartes en afficherait 10).
export 'src/domain/z_flashcard_filters.dart';
// SU-3 (AC5, AD-36) — port d'indices : appelé UNIQUEMENT après épuisement de
// l'indice STOCKÉ (`ZFlashcard.hint`), avec les indices déjà montrés
// (anti-répétition). Résultat ÉPHÉMÈRE : jamais persisté sur la carte.
export 'src/domain/z_flashcard_hint_port.dart';
// SU-3 (AC1, AD-35) — évaluation LOCALE exacte QCM/VF (le port n'est JAMAIS
// appelé pour ces deux types). `zIsLocallyEvaluatedType` est la voie de ROUTAGE
// (par le TYPE, jamais par un retour `null` — cf. dartdoc) : elle est appelée par
// `ZFlashcardAnswerInput._submitWritten`, SEUL point d'où le port est atteignable,
// qui REFUSE d'appeler le port pour un type qu'elle déclare local.
export 'src/domain/z_flashcard_local_evaluation.dart';
// SU-8 (AC4, D5) — normalisation de recherche : strippe les marques combinantes
// U+0300–U+036F (comble la limite **L-2 / NFD** de `zFoldDiacritics`) puis
// **DÉLÈGUE** à `zFoldDiacritics` (`zcrud_core`) — la table de repli reste
// UNIQUE, jamais recopiée ici — et replie les espaces (dont insécables). Gardé
// par `test/z_flashcard_search_single_fold_table_test.dart`.
export 'src/domain/z_flashcard_search_text.dart';
// SU-8 (AC8) — tri PUR, STABLE et TOTAL : `ZFlashcardSortMode` (enum),
// `zSortFlashcards`. `manual` ne trie PAS (l'ordre manuel appartient à
// `ZFolderContentsOrder`/`applyOrder` — AD-38, jamais une 2e voie).
export 'src/domain/z_flashcard_sort.dart';
export 'src/domain/z_flashcard_source.dart';
export 'src/domain/z_flashcard_type.dart';
// SU-3 (AC6, AD-36) — PROPRIÉTAIRE UNIQUE de la pénalité d'indices. Appliqué EN
// DERNIER, sur la valeur RENDUE (y compris celle du port) : « un port qui rend
// 10 indices ne contourne pas le plafond ». Plancher DÉRIVÉ (`passThreshold-1`).
export 'src/domain/z_hint_penalty.dart';
export 'src/domain/z_repetition_info.dart' hide ZRepetitionInfoZcrud;
// SU-2 (AC2) — transition de révélation question→réponse (enum, jamais un
// booléen ; Reduce Motion PRIME sur sa valeur).
export 'src/domain/z_reveal_transition.dart';
// SU-6 (FR-SU10, D1) — catégorisation PURE O(1)/carte (lookup Map, jamais
// `firstWhere`) : `ZSessionCategories`/`zCategorize`/`zIndexSrsById`.
export 'src/domain/z_session_categorization.dart';
export 'src/domain/z_sm2_scheduler.dart';
export 'src/domain/z_srs_config.dart';
export 'src/domain/z_srs_scheduler.dart';
// ES-1.1 — ergonomie typée `ZFlashcardType` restituée sur `ZStudySessionConfig`
// (le noyau neutralise `types` en `List<String>`).
export 'src/domain/z_study_session_config_flashcard_x.dart';
// E9-5 — couche presentation/ (widgets d'édition additifs).
export 'src/presentation/z_flashcard_choices_field_widget.dart';
// SU-1 (AD-40) — contrat de slot de rendu de contenu + défaut texte brut
// thématisé. L'adaptateur markdown/LaTeX injectable relève de su-2.
export 'src/presentation/z_flashcard_content_slot.dart';
export 'src/presentation/z_flashcard_editing_scope.dart';
export 'src/presentation/z_flashcard_edition_validator.dart';
export 'src/presentation/z_flashcard_editor_config.dart';
export 'src/presentation/z_flashcard_editors.dart';
// SU-2 (AC6, AD-40) — adaptateur markdown/LaTeX **opt-in**, chez le CONSOMMATEUR
// (jamais dans `zcrud_markdown` : ce serait un cycle, AD-1). Le défaut de
// `ZFlashcardReviewCard` reste le texte brut de su-1.
export 'src/presentation/z_flashcard_markdown_content.dart';
// SU-2 (AC1..AC7) — carte de révision adaptative (6 types + révélation).
export 'src/presentation/z_flashcard_review_card.dart';
export 'src/presentation/z_flashcard_true_false_field_widget.dart';
export 'src/presentation/z_flashcard_type_field_widget.dart';
// SU-2 (AC3) — primitive UNIQUE de Reduce Motion (su-4/su-5 la réutiliseront).
export 'src/presentation/z_reduce_motion.dart';
