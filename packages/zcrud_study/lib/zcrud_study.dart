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
export 'src/presentation/z_item_actions_menu.dart';
export 'src/presentation/z_reorder_ids.dart';
export 'src/presentation/z_sectioned_study_layout.dart';
export 'src/presentation/z_study_mindmap_section.dart';
export 'src/presentation/z_study_tools_page.dart';
export 'src/presentation/z_study_tools_section_spec.dart';
export 'src/presentation/z_tag_chips.dart';
export 'src/presentation/z_tag_editor.dart';
