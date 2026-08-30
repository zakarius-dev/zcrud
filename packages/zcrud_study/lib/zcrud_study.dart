/// Barrel d'API publique de `zcrud_study`.
///
/// Paquet de présentation de l'orchestration « study tools » : hub de
/// contenu, sections d'outils composables, génération de flashcards par IA,
/// partage et modération, session de révision assemblée, examens et
/// rappels, cartes par défaut pour chaque type de contenu. API publique :
/// ce barrel ; implémentation sous `lib/src/`. `zcrud_study` dépend de
/// `zcrud_core` et `zcrud_study_kernel`, jamais l'inverse (invariant AD-1).
library;

// ── Seams IA neutres (domaine) ──────────────────────────────────────────
//
// Ports `abstract interface class` retournant `Either<ZFailure, T>`
// (invariant AD-5), sans aucun SDK IA, prompt, endpoint ni clé en surface
// (invariant AD-12). La provenance de flashcard passe par
// `ZFlashcardSource`/`ZSourceRegistry` (importés depuis
// `package:zcrud_flashcard/…`, non ré-exportés ici).
export 'src/domain/z_ai_explanation_port.dart';
// Pendant PROGRESSIF du seam d'explication : `ZAiExplanationStreamPort` rend
// un flux NU d'avancements cumulatifs (`ZGenerationProgress`), avec un
// `isAvailable` qui permet d'en couper le progressif à chaud sans retirer le
// port. Contrat SÉPARÉ et optionnel : un hôte qui ne l'implémente pas garde
// exactement la voie one-shot. `ZInertAiExplanationStreamPort` est le défaut
// inerte (`const`).
export 'src/domain/z_ai_explanation_stream_port.dart';
export 'src/domain/z_education_quota_info.dart';
export 'src/domain/z_flashcard_generation_port.dart';
// Défauts purs de génération de flashcards : bornes `[1, 50]`
// (`zGenerationCountBounds`/`zClampGenerationCount`, défaut `10` si `null`),
// répartition équitable déterministe (`zEvenTypesDistribution`) et
// normalisation défensive (`zNormalizeTypesDistribution`). Source unique,
// jamais dupliquée dans un widget.
export 'src/domain/z_flashcard_generation_defaults.dart';
// Agrégat PUR des trois seaux SRS d'un dossier (apprises / à réviser / à
// apprendre) : calculé UNE fois par l'hôte quand ses données changent, par
// délégation à la partition du domaine flashcard — jamais une seconde
// formule, jamais un recalcul au rendu.
export 'src/domain/z_folder_progress_summary.dart';
// Seam IA neutre de génération de carte mentale : port retournant une forêt
// éphémère de `ZMindmapNode` (jamais un `ZMindmap` persisté) et une requête
// d'union dont l'identifiant de modèle est opaque. `ZMindmapNode` est
// importé de `package:zcrud_mindmap/…`.
export 'src/domain/z_mindmap_generation_port.dart';
export 'src/domain/z_note_summary_port.dart';
// Seam de génération de podcast : port retournant un `ZStudyPodcast` et une
// requête adressée par contenu (`sourceHash` opaque fourni par l'appelant,
// aucun hachage dans le domaine). `ZStudyPodcast` et ses enums viennent du
// kernel et ne sont pas ré-exportés (importer `package:zcrud_study_kernel/…`).
export 'src/domain/z_podcast_generation_port.dart';

// ── Partage communautaire optionnel et modération ───────────────────────
//
// Entités de partage contrôlées par le propriétaire
// (`ZStudyMembership`/`ZShareLink` révocable/`ZPublicStudyFolder`/
// `ZStudyFolderReport`), extension concrète opt-in `ZStudySharingExtension`
// (à injecter comme `extensionParser` du slot d'extension du kernel, non
// ré-exporté), garde ACL pure `ZStudySharingAcl` et ports neutres
// `ZStudySharingPort`/`ZStudyModerationPort`. Aucun état personnel
// (répétition espacée, ordre, lecture) n'y transite jamais.
export 'src/domain/z_public_study_folder.dart';
export 'src/domain/z_share_link.dart';
export 'src/domain/z_study_folder_report.dart';
export 'src/domain/z_study_membership.dart';
export 'src/domain/z_study_moderation_port.dart';
// `zFilterByScope` applique un `ZStudyScopeFilter` là où une liste d'écran
// est DÉJÀ filtrée, via une projection item → rattachement fournie par
// l'hôte ; sans filtre ou sans projection, il rend l'instance reçue.
export 'src/domain/z_study_scope_filtering.dart';
export 'src/domain/z_study_sharing_acl.dart';
export 'src/domain/z_study_sharing_admin_port.dart';
export 'src/domain/z_study_sharing_extension.dart';
export 'src/domain/z_study_sharing_port.dart';
export 'src/domain/z_study_sharing_read_port.dart';

// ── Examens et rappels ───────────────────────────────────────────────────
//
// `ZExamEditor` compose un `ZExam` (saisie préservée, heure typée
// `ZReminderTime`) ; `ZExamRemindersSection` dérive les examens approchants
// via un adaptateur et expose la liste à l'application, qui reste seule
// responsable de la planification des notifications système. `ZExam` et
// `ZReminderTime` ne sont pas ré-exportés (importer `package:zcrud_exam/…`).
export 'src/presentation/z_content_hub_launcher.dart';
export 'src/presentation/z_content_hub_reference.dart';
export 'src/presentation/z_content_hub_sheet.dart';
// Vue des tâches du jour : `ZDailyTasksView` est un corps composable (aucun
// `Scaffold`) qui rend un bandeau de sept jours, une liste virtualisée et un
// état vide injecté, à partir des tâches agrégées par le kernel. Valeurs de
// rendu centralisées dans `ZDailyTasksReference`.
export 'src/presentation/z_daily_tasks_reference.dart';
export 'src/presentation/z_daily_tasks_view.dart';
// Cartes de rendu par défaut, une par type de contenu d'étude : document,
// examen, flashcard, dossier, carte mentale, note. Chacune est composée à
// partir des primitives du paquet (`ZStudyToolsItemCard`, `ZFolderCard`…) ;
// aucune n'est un rendu réécrit isolément. Les cartes document et note
// restent autonomes sur des primitives, car leurs modèles vivent dans des
// paquets qui ne sont pas des dépendances de `zcrud_study`.
export 'src/presentation/z_default_document_card.dart';
export 'src/presentation/z_default_exam_card.dart';
export 'src/presentation/z_default_flashcard_card.dart';
export 'src/presentation/z_default_folder_card.dart';
export 'src/presentation/z_default_mindmap_card.dart';
export 'src/presentation/z_default_note_card.dart';
export 'src/presentation/z_exam_editor.dart';
export 'src/presentation/z_exam_reminders.dart'
    show
        ZApproachingReminder,
        approachingReminders,
        examDailyTasks,
        zExamAsApproaching;
export 'src/presentation/z_exam_reminders_section.dart';
// Explication IA : le contrôleur porte le cycle de vie (états, jeton de
// fraîcheur, anti-double-soumission), la tranche cumulative du rendu
// progressif et l'HISTORIQUE de versions en mémoire ; la vue rend la version
// courante par un slot de rendu injecté, la barre de traitements et le
// sélecteur de versions. Les clés de style et d'opération sont du vocabulaire
// de l'HÔTE, transmises verbatim. Rien n'est écrit par ce paquet : une
// explication matérialisée sort par le handoff `onPersist`.
export 'src/presentation/z_explanation_controller.dart';
export 'src/presentation/z_explanation_view.dart';
export 'src/presentation/z_feature_availability.dart';


// ── Flashcards : réordonnancement, liste, génération IA, édition en lot ──
//
// `zReorderFlashcards` est l'unique voie de réordonnancement (glisser et
// boutons d'accessibilité y aboutissent tous deux). `ZFlashcardListView`
// rend la liste avec recherche, filtres, tri, ordre manuel et sélection
// multiple opt-in. Le flux de génération IA (`ZFlashcardGenerationController`,
// `ZFlashcardGenerationSheet`) est absent sans port fourni — jamais un
// indicateur booléen codé en dur. `ZMultiFlashcardEditor` édite un lot de
// cartes en régime de brouillon déclaré, avec un commit unique injecté comme
// seul franchissement de la frontière de persistance.
export 'src/presentation/z_flashcard_card_reference.dart';
// 🔴 NON-RUPTURE — le calculateur de teinte lisible a REMONTÉ dans le cœur
// (`zcrud_core/lib/src/presentation/theme/z_readable_tint.dart`), pour que
// `zcrud_chat` cesse d'en porter une copie sans acquérir d'arête latérale
// vers ce paquet (invariant AD-1). Les six symboles restent atteignables
// depuis `zcrud_study` SOUS LES MÊMES NOMS : un hôte qui les importait d'ici
// n'a rien à changer. Retirer ce ré-export CASSERAIT ces hôtes.
export 'package:zcrud_core/zcrud_core.dart'
    show
        kZNonTextMinContrast,
        kZTextMinContrast,
        zCompositeOver,
        zContrastRatio,
        zReadableTintOn,
        zRelativeLuminance;
export 'src/presentation/z_flashcard_list_view.dart';
export 'src/presentation/z_folder_card.dart';
export 'src/presentation/z_folder_card_chrome.dart';
export 'src/presentation/z_folder_card_reference.dart';
// Barre segmentée de progression d'un dossier : elle consomme la VALEUR
// agrégée (`ZFolderProgressSummary`) — jamais les flux, jamais un recalcul
// au rendu.
export 'src/presentation/z_folder_progress_bar.dart';
// ── Surfaces de partage et galerie publique ──────────────────────────────
//
// `ZFolderSharingSheet` monte les gestes de `ZStudySharingPort` (lien
// révocable, adhésions, publication) ; `ZPublicGalleryView` rend un flux de
// fiches publiées avec « rejoindre », « copier » et, si un
// `ZStudyModerationPort` est fourni, « signaler ». Les deux naissent
// FERMÉES : le portail `zSharingAccessGranted` exige la disponibilité de la
// fonctionnalité ET l'accord de `ZAcl` — sans `ZcrudScope`, tout est refusé,
// et un refus rend un état « accès refusé » annoncé, jamais une surface
// vide. Aucune saisie d'invitation n'est interprétée par le socle : elle
// passe par le `principalResolver` de l'hôte. Les entrées de menu
// (`zFolderSharingItemAction`, `zPublicGalleryItemAction`) rendent `null`
// tant que le câblage ou l'autorisation manque.
export 'src/presentation/z_folder_sharing_sheet.dart';
export 'src/presentation/z_public_gallery_view.dart';
export 'src/presentation/z_study_sharing_entries.dart';
export 'src/presentation/z_study_sharing_gate.dart';
export 'src/presentation/z_subfolder_item_chrome.dart'
    show ZCountBadge, ZCountBadgeRow, ZCountBadgeSpec;
export 'src/presentation/z_flashcard_generation_controller.dart';
export 'src/presentation/z_flashcard_generation_sheet.dart';
export 'src/presentation/z_flashcard_tag_confirm_sheet.dart';
// Aperçu de flashcard en lecture seule : compose le rendu de révision
// existant et n'introduit aucun rendu parallèle. Sur une carte en lecture
// seule, les actions d'édition et de suppression sont structurellement
// absentes plutôt que grisées.
export 'src/presentation/z_flashcard_preview.dart';
export 'src/presentation/z_flashcard_reorder.dart';
export 'src/presentation/z_item_actions_menu.dart';
// Génération de carte mentale par IA : le contrôleur porte le cycle de vie
// (états, jeton de fraîcheur, matérialisation), la feuille assemble la saisie,
// la revue dans l'éditeur d'outline et la validation. Rien n'est écrit avant
// le handoff à l'appelant.
export 'src/presentation/z_mindmap_generation_controller.dart';
export 'src/presentation/z_mindmap_generation_sheet.dart';
export 'src/presentation/z_multi_flashcard_editor.dart';
export 'src/presentation/z_multi_flashcard_editor_controller.dart';
// Résumé de note par IA : le contrôleur porte le cycle de vie (états, jeton de
// fraîcheur, anti-double-soumission), la feuille assemble la saisie, la revue
// du résumé et ses deux issues. Rien n'est écrit par ce paquet : le résumé
// sort par les handoffs « insérer en tête » et « nouvelle note », et c'est
// l'application qui écrit.
export 'src/presentation/z_note_summary_controller.dart';
export 'src/presentation/z_note_summary_sheet.dart';
// Podcast : présentation de l'entité `ZStudyPodcast` du kernel, jusqu'ici sans
// aucune surface. `ZPodcastCard` rend statut et fraîcheur par libellés injectés
// (les clés du kernel ne sont jamais affichées nues), propose « régénérer » et
// monte `ZPodcastAudioPlayer` uniquement si un `ZAudioPlaybackPort` disponible
// est fourni ET que le podcast porte un audio. `ZPodcastGenerationController`
// porte le cycle de vie au-dessus de `ZPodcastGenerationPort` et remet son
// résultat par handoff — il n'écrit rien. `zPodcastHubEntry` construit l'entrée
// de hub de la famille, ou `null` quand elle n'est pas câblée.
export 'src/presentation/z_podcast_audio_player.dart';
export 'src/presentation/z_podcast_card.dart';
export 'src/presentation/z_podcast_generation_controller.dart';
export 'src/presentation/z_podcast_hub_entry.dart';
// Seam de suppression en cascade d'une flashcard : compose la suppression de
// la carte puis la purge de son état de répétition espacée. Vit dans
// `lib/src/data/` parce qu'il importe un store, un symbole banni de la
// couche présentation — le widget de liste reste pur (seam injecté).
export 'src/data/z_flashcard_cascade_delete.dart';

// ── Primitives de mise en page et d'accessibilité ────────────────────────
//
// Utilitaires partagés par les voies typées de ce paquet et par les
// surfaces assemblées par l'hôte : fondu de dépassement mesurable
// (`ZRenderFadedOverflow`), item de rail borné en largeur (`ZRailItem`),
// utilitaires de réordonnancement d'index (`zReorderIds`).
export 'src/presentation/z_faded_overflow.dart';
export 'src/presentation/z_rail_item.dart';
export 'src/presentation/z_reorder_ids.dart';
// Ce fichier expose deux enveloppes du même contenu de sections :
// `ZSectionedStudyLayout` (boîte, `ListView.builder`) et
// `ZSectionedStudySliver` (sliver, `SliverList.builder`, assemblable dans
// les `slivers:` d'un `CustomScrollView` sans défilement imbriqué). Le
// contenu, l'ordre et les clés viennent d'une source unique partagée : les
// deux chemins ne peuvent pas diverger.
export 'src/presentation/z_sectioned_study_layout.dart';

// ── Page-détail d'un dossier d'étude ──────────────────────────────────────
//
// `ZStudyFolderDetail` compose un page-shell, l'onglet Matériel
// (`ZSectionedStudyLayout`), l'onglet Progression et une navigation de
// sous-dossiers adaptative (sidebar redimensionnable sur grand écran,
// sélecteur compact sur petit écran). Les sous-dossiers voyagent par le
// value-object opaque `ZSubfolderRef` et le descripteur `ZSubfolderNavSpec`
// — jamais l'entité du kernel. L'état (sélection, repli, largeur) est
// détenu par le widget, avec des rebuilds granulaires (invariant AD-2).
export 'src/presentation/z_study_folder_detail.dart'
    show
        ZStudyFolderDetail,
        ZMaterialSectionsBuilder,
        ZMaterialSlotBuilder,
        // Hauteur mesurée de la bande de navigation hissée : publique pour
        // que l'hôte puisse composer sa propre déclaration
        // (`subfolderNavBandHeight`) à partir d'elle plutôt que de la
        // recopier.
        kZSubfolderNavBandHeight;
export 'src/presentation/z_study_mindmap_section.dart';
// Carte d'item de base à slots : ce paquet fournit la structure et
// l'accessibilité (cible ≥ 48 dp, `Semantics`, RTL) une fois pour toutes ;
// la sémantique métier de l'hôte arrive par les slots.
export 'src/presentation/z_study_card_reference.dart';
export 'src/presentation/z_study_document_card.dart';
// Table de référence des états vides par nature de contenu — glyphes, tailles
// et clés opaques ; le rendu reste celui de `ZEmptyState`.
export 'src/presentation/z_study_empty_state_reference.dart';
export 'src/presentation/z_study_note_card.dart';

// ── La structure d'étude dans les écrans ────────────────────────────────
//
// 🔴 La structure ACADÉMIQUE (organisations, unités, groupes, programmes)
// n'est PAS l'arborescence des dossiers : elle dit à quoi un contenu se
// rattache et dans quelle portée on travaille, jamais où il est rangé.
//
// `ZStudyPathBar` déroule le chemin d'un `ZStudyContext` sans aucune
// résolution (les libellés viennent des instantanés) ; `ZStudyScopeBar`
// montre la portée courante en puces retirables et propose le filtre
// réduit. Le troisième membre du trio, `ZStudyUnitPicker`, est exporté plus
// bas — l'ordre alphabétique des directives le sépare de ses jumeaux.
export 'src/presentation/z_study_path_bar.dart';
export 'src/presentation/z_study_scope_bar.dart';

// ── Écran de session de révision assemblé ────────────────────────────────
//
// Le moteur de révision est entièrement porté par `zcrud_session` (trois
// runtimes, glisseur, saisie, notation, résumé), mais son assemblage en
// écran n'existe que dans ce paquet, en trois responsabilités disjointes :
// `ZStudySessionView` est le corps composable (aucun `Scaffold` ni route) ;
// `ZStudySessionHost` détient le runtime (via une table unique, jamais
// redécidée) et reçoit son `ZSessionReviewer` injecté ; `ZStudySessionScaffold`
// est l'enveloppe de page mince par-dessus le page-shell. Cet écran vit
// délibérément dans `zcrud_study` et non dans `zcrud_session`, dont la
// présentation reste des widgets purs sans runtime détenu. Les valeurs de
// rendu sont centralisées dans `ZStudySessionReference`, sans aucune
// couleur littérale.
export 'src/presentation/z_study_session_host.dart';
export 'src/presentation/z_study_session_mode.dart';
export 'src/presentation/z_study_session_reference.dart';
export 'src/presentation/z_study_session_scaffold.dart';
export 'src/presentation/z_study_session_slices.dart';
export 'src/presentation/z_study_session_view.dart';
export 'src/presentation/z_study_tools_item_card.dart';
export 'src/presentation/z_study_tools_page.dart';
export 'src/presentation/z_study_tools_section_spec.dart';
// Troisième membre du trio « structure d'étude dans les écrans » (cf. la
// section plus haut) : `ZStudyUnitPicker` choisit un conteneur dans une
// forêt IMMUABLE fournie par l'hôte (données, pas port) et rend la
// `ZStudyRef` exacte, sans jamais modifier la structure.
export 'src/presentation/z_study_unit_picker.dart';

// ── Navigation de sous-dossiers ───────────────────────────────────────────
//
// Descripteurs de navigation (value-object opaque et descripteur agrégé) et
// les deux briques de navigation adaptative : sidebar grand écran et
// sélecteur compact petit écran, derrière un seam de substitution de
// surface pour un rendu personnalisé.
export 'src/presentation/z_subfolder_compact_selector.dart';
export 'src/presentation/z_subfolder_narrow_nav.dart';
export 'src/presentation/z_subfolder_nav.dart';
export 'src/presentation/z_subfolder_nav_renderer.dart';
export 'src/presentation/z_subfolder_nav_spec.dart';
export 'src/presentation/z_subfolder_ref.dart';
// Pilotage externe optionnel de la sélection de fratrie de sous-dossiers.
// `null` signifie que la page détient l'état comme par défaut.
export 'src/presentation/z_subfolder_selection_controller.dart';
export 'src/presentation/z_subfolder_selector_bar.dart';
export 'src/presentation/z_subfolder_sidebar.dart';
export 'src/presentation/z_subject_chip.dart';
export 'src/presentation/z_tag_chips.dart';
export 'src/presentation/z_tag_editor.dart';
