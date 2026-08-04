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
// CR-IFFD-47 — carte de flashcard PAR DÉFAUT du socle : widget AUTONOME sur le
// modèle `ZFlashcard` (accent dérivé d'une clé STABLE, pastille de type, zone de
// balises affichée MÊME VIDE en appel à l'action, énoncé tronqué, puce de pied
// redisant le type EN TEXTE — AD-13). Composé de primitives existantes
// (`ZStudyToolsItemCard` + `ZTagChips` + `remapColorKey`/`zResolveColorKeyOrSlot`),
// aucune carte réécrite. La voie TYPÉE qui porte les données est
// `ZStudyToolsSectionSpec.flashcards(cards:)` ; `itemBuilder` reste REQUIS dans
// le constructeur principal (aucune régression possible pour un hôte existant).
// CR-IFFD-48 — la règle généralisée : quand le socle offre une fonctionnalité,
// il offre un rendu par défaut. Quatre cartes : document (icône TYPÉE par
// format — mapping ouvert injectable, jamais un enum fermé), note, carte
// mentale (vignette structurelle déterministe) et examen. Structure et
// proportions portées par le socle ; couleurs et graisses exprimées en RÔLES
// du `ColorScheme`/`TextTheme` de l'hôte (zéro jeton nouveau — mesuré).
// Voies typées : `.mindmaps(maps:)` (`ZMindmap`, arête ES-7.1) et
// `.exams(exams:)` (`ZExam`, arête ES-9.2). Documents et notes restent des
// cartes AUTONOMES sur primitives : leurs modèles (`ZStudyDocument`/
// `ZSmartNote`) vivent dans `zcrud_document`/`zcrud_note`, qui ne sont PAS des
// dépendances de `zcrud_study` — une voie typée exigerait une arête nouvelle
// (interdite, AD-1).
export 'src/presentation/z_default_document_card.dart';
export 'src/presentation/z_default_exam_card.dart';
export 'src/presentation/z_default_flashcard_card.dart';
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
// SUF-2 (AC1..AC11, AD-2/AD-4/AD-10/AD-13/AD-45/FR-26) — carte de dossier
// d'étude à PROPS PRIMITIVES (jamais l'entité ZStudyFolder) : accent DÉRIVÉ de
// `colorKey` via `zResolveColorKeyOrSlot` (aucune table locale), slot compteur/
// badges + slot menu, badge « Archivé » à libellé INJECTÉ, cible ≥ 48 dp,
// grille adaptative posée par l'appelant (ZAdaptiveGrid.builder). Réplique
// neutre du natif lex `FolderCard` sans gestionnaire d'état (AD-2).
export 'src/presentation/z_folder_card.dart';
export 'src/presentation/z_folder_card_chrome.dart';
export 'src/presentation/z_subfolder_item_chrome.dart'
    show ZCountBadge, ZCountBadgeRow, ZCountBadgeSpec;
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
// CR-IFFD-49 — item de RAIL borné en largeur, PUBLIC : même résolution
// (paramètre > token `ZcrudTheme.railItemWidth` > repli 280 dp) pour les voies
// typées du socle ET les surfaces assemblées par l'hôte.
export 'src/presentation/z_rail_item.dart';
export 'src/presentation/z_reorder_ids.dart';
// CR-LEX-74 — ce fichier expose DEUX enveloppes du MÊME contenu de sections :
// `ZSectionedStudyLayout` (boîte, `ListView.builder`) et `ZSectionedStudySliver`
// (sliver, `SliverList.builder`) — cette dernière s'assemble dans les `slivers:`
// d'un `CustomScrollView` sans défilement imbriqué, donc SANS tuer une
// `SliverAppBar` rétractable. Contenu/ordre/clés = source unique partagée.
export 'src/presentation/z_sectioned_study_layout.dart';
// SUF-3 (AC1..AC16, AD-2/AD-13/AD-4/AD-10) — ossature de page-détail d'un dossier
// d'étude : `ZStudyFolderDetail` COMPOSE le page-shell SUF-1 (`ZPageScaffold`),
// l'onglet Matériel (`ZSectionedStudyLayout`), l'onglet Progression
// (`ZStudyProgressRings`/`zcrud_session`) et une navigation de sous-dossiers
// ADAPTATIVE (sidebar redimensionnable/repliable ↔ sélecteur compact, bascule
// via `ZResponsiveLayout` au seuil 600). Sous-dossiers via le VO OPAQUE
// `ZSubfolderRef` + descripteur `ZSubfolderNavSpec` (labels/slots injectés) —
// jamais l'entité kernel. État (sélection/repli/largeur) DÉTENU par le widget
// (`ValueNotifier`), rebuilds granulaires (AD-2), aucune I/O (largeur persistée
// par callback injecté). Arête `zcrud_study → zcrud_session` ACYCLIQUE (D2).
// CR-53 — `ZMaterialSlotBuilder` (typedef NOUVEAU, COEXISTANT avec
// `ZMaterialSectionsBuilder` qui reste INCHANGÉ) : slots libres en-tête/pied de
// l'onglet Matériel, par sous-dossier sélectionné.
export 'src/presentation/z_study_folder_detail.dart'
    show
        ZStudyFolderDetail,
        ZMaterialSectionsBuilder,
        ZMaterialSlotBuilder,
        // CR-IFFD-45 — hauteur MESURÉE de la bande de navigation hissée : elle
        // est publique pour que l'hôte puisse composer sa propre déclaration
        // (`subfolderNavBandHeight`) à partir d'elle, au lieu de recopier 48.
        kZSubfolderNavBandHeight;
export 'src/presentation/z_study_mindmap_section.dart';
// CR-IFFD-16 (voie B) — carte d'item de BASE à slots : le socle fournit la
// structure et l'accessibilite (>= 48 dp, Semantics, RTL) une fois pour toutes ;
// la semantique metier de l'hote arrive par les slots.
export 'src/presentation/z_study_card_reference.dart';
export 'src/presentation/z_study_document_card.dart';
export 'src/presentation/z_study_note_card.dart';
export 'src/presentation/z_study_tools_item_card.dart';
export 'src/presentation/z_study_tools_page.dart';
export 'src/presentation/z_study_tools_section_spec.dart';
// SUF-3 — descripteurs de nav de sous-dossiers (VO opaque + spec agrégé) et les
// deux briques de nav adaptative (sidebar grand écran / sélecteur compact).
export 'src/presentation/z_subfolder_compact_selector.dart';
// CR-IFFD-40 — surface étroite par DÉFAUT (barre de sélection), aiguillage et
// seam de SUBSTITUTION DE SURFACE (patron `ZListRenderer`/`ZChatShellRenderer`).
export 'src/presentation/z_subfolder_narrow_nav.dart';
export 'src/presentation/z_subfolder_nav_renderer.dart';
export 'src/presentation/z_subfolder_nav_spec.dart';
export 'src/presentation/z_subfolder_ref.dart';
// CR-IFFD-45 — pilotage EXTERNE optionnel de la sélection de fratrie (patron
// `ZDisplayState` de `zcrud_core`, décliné sur `String?`). `null` ⇒ la page
// détient l'état comme avant : aucun hôte existant ne bouge.
export 'src/presentation/z_subfolder_selection_controller.dart';
export 'src/presentation/z_subfolder_selector_bar.dart';
export 'src/presentation/z_subfolder_sidebar.dart';
export 'src/presentation/z_tag_chips.dart';
export 'src/presentation/z_tag_editor.dart';
