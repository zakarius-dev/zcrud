/// Barrel d'API publique de `zcrud_study`.
///
/// Package de PRÉSENTATION de l'orchestration « study tools » (AD-25). ES-5.1
/// expose le SOCLE de décomposabilité : le descripteur de section paramétrique
/// [ZStudyToolsSectionSpec] et l'échafaudage de composition
/// [ZSectionedStudyLayout] (liste de sections INDÉPENDANTES, une frontière de
/// widget/Key par section). API publique = ce barrel ; implémentation sous
/// `lib/src/` (AD-1 : `zcrud_study → zcrud_core`/`zcrud_study_kernel`, jamais
/// l'inverse ; CORE OUT=0).
library;

// ES-9.1 — seams IA neutres (domaine, premier `lib/src/domain/` du package) :
// ports `abstract interface class` `Either<ZFailure,·>` (AD-5/AD-11) + VO de
// quota fail-open. Aucun SDK IA / prompt / endpoint / clé en surface (AD-12) ;
// la provenance passe par `ZFlashcardSource`/`ZSourceRegistry` (importés depuis
// `package:zcrud_flashcard/…`, NON ré-exportés ici).
export 'src/domain/z_ai_explanation_port.dart';
export 'src/domain/z_education_quota_info.dart';
export 'src/domain/z_flashcard_generation_port.dart';
// SU-9 (AC3/AC4, AD-37/AD-10) — défauts PURS de génération : bornes `[1,50]`
// (`zGenerationCountBounds`/`zClampGenerationCount`, défaut null=10), répartition
// équitable déterministe (`zEvenTypesDistribution`) et normalisation défensive
// (`zNormalizeTypesDistribution` : négatifs→0, types inconnus écartés, distribution
// fournie fait foi). SOURCE UNIQUE — jamais dupliquée dans un widget.
export 'src/domain/z_flashcard_generation_defaults.dart';
// SU-12 (FR-SU18, AD-37/AD-5/AD-10) — seam IA neutre de génération de carte
// mentale : port `abstract interface class` `Future<ZResult<List<ZMindmapNode>>>`
// (forêt ÉPHÉMÈRE sans id/folderId — PAS `ZMindmap`) + request VO d'union
// (`modelId` OPAQUE ; omet `typesDistribution`/`provenance` flashcard-spécifiques).
// Aucune impl (app-side). `ZMindmapNode` importé de `package:zcrud_mindmap/…`.
export 'src/domain/z_mindmap_generation_port.dart';
export 'src/domain/z_note_summary_port.dart';

// ES-9.3 — seam de génération de podcast (domaine) : port `abstract interface
// class` `Future<ZResult<ZStudyPodcast>>` (AD-5/AD-11/AD-26) + request VO
// content-addressed (`sourceHash` OPAQUE FOURNI, D4 — aucun crypto). `ZStudyPodcast`
// et les enums (`ZPodcastSourceKind`/`ZPodcastMode`) viennent du kernel et NE sont
// PAS ré-exportés (le consommateur importe `package:zcrud_study_kernel/…`). Aucun
// SDK IA/TTS/HTTP/crypto en surface (AD-12).
export 'src/domain/z_podcast_generation_port.dart';

// ES-9.4 — communauté / partage OPTIONNEL + modération (FR-S32, AD-26/AD-20).
// Entités de partage owner-contrôlées (`ZStudyMembership`/`ZShareLink` révocable/
// `ZPublicStudyFolder`/`ZStudyFolderReport`), extension concrète opt-in
// `ZStudySharingExtension implements ZExtension` (injectée comme `extensionParser`
// du slot `ZStudyFolder.extension` du kernel — NON ré-exporté), garde ACL PURE
// `ZStudySharingAcl` (dette sécu lex corrigée par conception, AC5/DW-ES94-1) et
// ports neutres `ZStudySharingPort`/`ZStudyModerationPort` (`Either<ZFailure,·>`,
// flux nus). AUCUN SDK/secret/endpoint (AD-11/AD-12). État personnel (SRS/ordre/
// lecture) JAMAIS emporté (AC3).
export 'src/domain/z_public_study_folder.dart';
export 'src/domain/z_share_link.dart';
export 'src/domain/z_study_folder_report.dart';
export 'src/domain/z_study_membership.dart';
export 'src/domain/z_study_moderation_port.dart';
export 'src/domain/z_study_sharing_acl.dart';
export 'src/domain/z_study_sharing_extension.dart';
export 'src/domain/z_study_sharing_port.dart';

// ES-9.2 — UI examens + rappels approchants (FR-S9/FR-S10) : éditeur `ZExamEditor`
// (compose `ZExam`, saisie préservée, `id==null` AD-14, heure TYPÉE `ZReminderTime`
// AD-28), section `ZExamRemindersSection` (approchants dérivés via l'adaptateur
// `ZApproachingExam` + `aggregateDailyStudyTasks`, `now` INJECTÉ, exposition à l'app
// — planification OS app-side, AC5). `ZExam`/`ZReminderTime` NON ré-exportés (le
// consommateur importe `package:zcrud_exam/…`).
export 'src/presentation/z_content_hub_sheet.dart';
export 'src/presentation/z_exam_editor.dart';
export 'src/presentation/z_exam_reminders.dart'
    show
        ZApproachingReminder,
        approachingReminders,
        examDailyTasks,
        zExamAsApproaching;
export 'src/presentation/z_exam_reminders_section.dart';
export 'src/presentation/z_feature_availability.dart';
// SU-8 (AC9-AC12, AD-38) — UNIQUE voie de réordonnancement des flashcards :
// `zReorderFlashcards` (drag ET boutons a11y y aboutissent tous deux ; délègue à
// `zReorderIds` puis persiste via `copyWith(sectionOrders:)`), clé canonique
// `zFlashcardsSectionKey` (⇒ `zSectionKey`, clé nue VERBATIM « flashcards » —
// RISQUE DE DONNÉES : toute dérive orphelinerait l'ordre persisté EN SILENCE, car
// `applyOrder` est TOTAL), et `zMoveUpIndices`/`zMoveDownIndices` (`null` ⇒ bouton
// ABSENT : le 1er ne remonte pas, le dernier ne descend pas).
export 'src/presentation/z_flashcard_list_view.dart';
// SU-9 (AC1..AC13, AD-37/AD-43) — flux UI de génération IA : contrôleur pur
// `ChangeNotifier` (statut ENUM, jeton de fraîcheur, handoff `onGenerated` — AUCUN
// store, rien de persisté), feuille de génération (source depuis `ZSourceRegistry`
// via `ZGenerationSourceOption`, slider 1..50, `FilterChip` par type, `modelId`
// OPAQUE, aperçu via `ZFlashcardPreview`), point d'entrée conditionnel
// (`ZFlashcardGenerationLauncher`/`ZFlashcardGenerationScope` : option ABSENTE sans
// port), et confirmation de tags réutilisant `ZTagEditor`. Cartes ÉPHÉMÈRES
// (`id==null`), fuite du résultat fermée sur toute voie (AC6).
export 'src/presentation/z_flashcard_generation_controller.dart';
export 'src/presentation/z_flashcard_generation_sheet.dart';
export 'src/presentation/z_flashcard_tag_confirm_sheet.dart';
// SU-8 (AC14, AD-45) — aperçu LECTURE SEULE : COMPOSE `ZFlashcardReviewCard`
// (su-2) et ne rend RIEN lui-même (jamais un rendu parallèle, qui divergerait en
// silence). Sur une carte `isReadOnly`, `onEdit`/`onDelete` sont forcés à `null`
// ⇒ actions ABSENTES (jamais grisées) — la carte porte la MÊME garde : les deux
// voies convergent, jamais deux règles concurrentes.
export 'src/presentation/z_flashcard_preview.dart';
export 'src/presentation/z_flashcard_reorder.dart';
export 'src/presentation/z_item_actions_menu.dart';
// ME-2 (AC1..AC10, FR-SU20, AD-43/AD-44/AD-39/AD-45) — multi-éditeur de
// flashcards en régime BROUILLON DÉCLARÉ (`ZEditingMode.draft`) : contrôleur de
// brouillon EN MÉMOIRE (`ChangeNotifier` pur, tranches `orderKeys`/`isDirty`
// disjointes, aucun store), widget `ZMultiFlashcardEditor` qui COMPOSE me-1
// (sélection + `applyCommonField`, `clearSucceededFromSelection` défaut `false`
// CONSOMMÉ), su-2 (`ZFlashcardReviewCard` pour l'aperçu), su-9 (`onGenerated` ⇒
// ajout éphémère), `zcrud_responsive` (split-view) et le `ZDiscardChangesGuard`
// EXISTANT (zcrud_ui_kit). Commit unique injecté = SEUL franchissement de la
// frontière de persistance (AD-43) ; un échec de commit préserve le brouillon.
export 'src/presentation/z_multi_flashcard_editor.dart';
export 'src/presentation/z_multi_flashcard_editor_controller.dart';
// ME-3 (AC4/AC5/AC7, FR-SU19, AD-21/AD-39/AD-10) — seam de CASCADE de
// suppression flashcard : `zFlashcardCascadeDeleteRoot` compose la suppression
// de la carte PUIS la purge de son état SRS (`ZRepetitionStore.deleteByCard`),
// matérialisant le `deleteRoot` INJECTÉ attendu par `batchDelete` (me-1). Vit
// dans `lib/src/data/` (importe `ZRepetitionStore`, banni de la présentation) —
// le widget de liste reste PUR (seam injecté). CORE OUT=0, arête existante.
export 'src/data/z_flashcard_cascade_delete.dart';
export 'src/presentation/z_reorder_ids.dart';
export 'src/presentation/z_sectioned_study_layout.dart';
export 'src/presentation/z_study_mindmap_section.dart';
export 'src/presentation/z_study_tools_page.dart';
export 'src/presentation/z_study_tools_section_spec.dart';
export 'src/presentation/z_tag_chips.dart';
export 'src/presentation/z_tag_editor.dart';
