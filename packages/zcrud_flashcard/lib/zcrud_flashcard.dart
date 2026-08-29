/// Barrel d'API publique de `zcrud_flashcard`.
///
/// Flashcards en répétition espacée :
/// - `ZFlashcard` (entité canonique) + `ZChoice` + `ZFlashcardType` +
///   provenance ouverte `ZFlashcardSource` ;
/// - SRS pluggable : `ZRepetitionInfo` + `ZSrsScheduler`/`ZSm2Scheduler` +
///   `ZSrsConfig` (invariant AD-9 : l'état de répétition espacée est séparé
///   de la carte) ;
/// - organisation `ZStudyFolder` + `ZReviewMode` + `ZStudySessionConfig`,
///   primitives pures `validatePlacement` (hiérarchie à deux niveaux) et
///   `ZStudySessionSelector` (sélection filtrée) ;
/// - couche `data/` offline-first : `ZFlashcardRepository` (coordinateur
///   composant les ports neutres du cœur) et le port SRS séparé
///   `ZRepetitionStore` (invariant SRS top-level, voie d'écriture unique
///   `reviewCard`) ;
/// - couche `presentation/` : widgets d'édition additifs servis via le
///   registre de widgets du cœur (sélecteur de type, QCM, vrai-faux),
///   fabriques de champs d'édition, validation d'éditeur, scope
///   d'édition. Déplacement de carte avec re-synchronisation du `folderId`
///   SRS, et idempotence de l'inscription/reset côté
///   `ZFlashcardRepository`.
///
/// ## Extensions générées masquées
///
/// `ZRepetitionInfoZcrud`, `ZStudyFolderZcrud` et `ZStudySessionConfigZcrud`
/// portent un `copyWith`/`toMap` internes ; la (dé)sérialisation et la copie
/// passent par l'API d'instance (`fromMap`/`toMap`/`copyWith` à sentinelle),
/// pas par l'extension générée (qui remettrait `extra`/`extension` à leurs
/// défauts et perdrait silencieusement des données).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// `ZStudyFolder`, la hiérarchie de dossiers, `ZReviewMode`,
// `ZStudySessionConfig`, `ZStudySessionSelector` et le port
// `ZSessionCandidate` sont portés par `zcrud_study_kernel` (source unique) et
// réexportés depuis son barrel : le noyau masque déjà ses propres extensions
// générées (même politique `hide`). L'ergonomie typée `ZFlashcardType` de la
// config est restituée par `z_study_session_config_flashcard_x.dart`
// (ci-dessous).
//
// Le `hide` ci-dessous opère par liste (jamais un `show`) : un `show`
// explicite devrait aussi énumérer les symboles générés du noyau
// (fonctions d'enregistrement, spécifications de champs via les fichiers
// `part`) — un oubli casserait un consommateur externe. Le `hide` ne retire
// que les symboles hors périmètre flashcard, connus par construction, et
// préserve donc intégralement la surface historique du paquet, symboles
// générés inclus (prouvé par un test de surface positive dédié).
//
// Règle de maintenance : tout nouveau symbole public ajouté au barrel du
// noyau qui n'a rien à voir avec les flashcards doit être ajouté à cette
// liste `hide`. Cette règle est outillée, pas seulement écrite : un test
// dédié croise les symboles publics réels du barrel du noyau avec cette
// liste `hide` plus une liste d'exceptions explicite. Tout symbole du noyau
// non classé fait échouer les tests, rendant la fuite silencieuse
// impossible.
export 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    hide
        ZColorPalette,
        ZKeyHash,
        zFnv1a32,
        ZUnorderedPlacement,
        applyOrder,
        normalizeTagTitle,
        dedupeByNormalizedTitle,
        // Ordre de contenu de dossier study, personnel, non pertinent
        // flashcard ⇒ hors surface publique flashcard.
        ZFolderContentsOrder,
        ZFolderContentsOrderExtensionParser,
        kSectionOrdersKey,
        // Même famille : constructeur canonique des clés de
        // `ZFolderContentsOrder.sectionOrders`, non pertinent flashcard.
        // Un consommateur qui compose une clé importe `zcrud_study_kernel`
        // (foyer unique — jamais de recopie à la main).
        zSectionKey,
        // Vue « rythme du jour » (résultat de session, tâches quotidiennes,
        // agrégation via le port neutre `ZApproachingExam`) : symboles
        // study-niveau, non pertinents flashcard.
        ZStudySessionResult,
        ZDailyStudyTask,
        ZDueCardsTask,
        ZExamTask,
        ZApproachingExam,
        aggregateDailyStudyTasks,
        // Ports neutres `ZStudyDocumentRef`/`ZStudyNoteRef` : existent pour
        // que le socle de présentation study puisse nommer un
        // document/une note sans arête vers les paquets document/note
        // (invariant AD-1). Aucun rapport avec la surface flashcard
        // historique.
        ZStudyDocumentRef,
        ZStudyNoteRef,
        ZStudySubjectRef,
        // Podcast content-addressed : symboles study-niveau, non pertinents
        // flashcard.
        ZStudyPodcast,
        ZStudyPodcastExtensionParser,
        ZPodcastSourceKind,
        ZPodcastMode,
        ZPodcastStatus,
        ZPodcastFreshness,
        podcastFreshness,
        // Port CRUD offline-first générique `ZStudyRepository<T>` : port
        // data study-niveau, non pertinent pour la surface flashcard
        // historique.
        ZStudyRepository,
        // Registre déclaratif de cascade (`ZCascadeEdge` +
        // `ZCascadeRegistry`) : mécanisme study-niveau de suppression
        // bornée, non pertinent flashcard.
        ZCascadeEdge,
        ZCascadeRegistry,
        // Flamme d'assiduité (`ZStudyStreak` + `zAdvanceStreak` + le jour
        // civil) : compteur d'assiduité study-niveau, dépendant de dates
        // seules et d'aucun concept flashcard. Le consommateur du streak
        // importe le barrel `zcrud_study_kernel` directement (foyer
        // unique).
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
        zCivilDayNumber,
        // Modèle de STRUCTURE study (organisations, programmes, cours, périodes,
        // offres, participations, référentiels de compétences, partages…) et
        // leurs analyseurs d'extension : entités study-niveau, sans rapport avec
        // la surface flashcard historique.
        ZExternalRef,
        ZStudyArtifact,
        ZStudyBinding,
        ZStudyCalendar,
        ZStudyCalendarExtensionParser,
        ZStudyClassification,
        ZStudyClassificationConstraint,
        ZStudyClassificationExtensionParser,
        ZStudyCompetency,
        ZStudyCompetencyExtensionParser,
        ZStudyCompetencyFramework,
        ZStudyCompetencyFrameworkExtensionParser,
        ZStudyCompetencyRelation,
        ZStudyCourse,
        ZStudyCourseExtensionParser,
        ZStudyCurriculum,
        ZStudyCurriculumExtensionParser,
        ZStudyExplanation,
        ZStudyExplanationExtensionParser,
        ZStudyGroup,
        ZStudyGroupExtensionParser,
        ZStudyOffering,
        ZStudyOfferingAudience,
        ZStudyOfferingAudienceExtensionParser,
        ZStudyOfferingExtensionParser,
        ZStudyOrgUnit,
        ZStudyOrgUnitExtensionParser,
        ZStudyOrganization,
        ZStudyOrganizationExtensionParser,
        ZStudyParticipation,
        ZStudyParticipationExtensionParser,
        ZStudyPeriod,
        ZStudyPeriodExtensionParser,
        ZStudyPrincipal,
        ZStudyPrincipalExtensionParser,
        ZStudyProgram,
        ZStudyProgramCourse,
        ZStudyProgramCourseExtensionParser,
        ZStudyProgramExtensionParser,
        ZStudyRef,
        ZStudyRelation,
        ZStudyRoleBinding,
        ZStudyRoleBindingExtensionParser,
        ZStudySession,
        ZStudySessionExtensionParser,
        ZStudyShareGrant,
        ZStudyShareGrantExtensionParser,
        ZStudySubject,
        ZStudySubjectExtensionParser,
        ZStudyTopic,
        ZStudyTopicCompetency,
        ZStudyTopicExtensionParser,
        ZStudyWorkspace,
        ZStudyWorkspaceExtensionParser,
        // Ports neutres de structure (lecture, import, résolution du principal) et
        // leurs implémentations INERTES : contrats data study-niveau.
        ZInertStudyPrincipalResolver,
        ZInertStudyStructureImportPort,
        ZInertStudyStructurePort,
        ZStudyContextResolver,
        ZStudyPrincipalResolver,
        ZStudyStructureImport,
        ZStudyStructureImportPort,
        ZStudyStructureImportReport,
        ZStudyStructurePort,
        ZStudyStructureSnapshot,
        // Ontologie de structure (familles, capacités, règles de contenance et
        // d'affichage, vocabulaires) et ses validateurs.
        ZStudyContainmentRule,
        ZStudyDisplayRules,
        ZStudyKindSpec,
        ZStudyOntology,
        ZStudyOntologyPresets,
        ZStudyVocabulary,
        ZStudyVocabularySpec,
        ZStudyVocabularyValue,
        zHasCapability,
        zValidatePlacement,
        zValidateVocabularyUse,
        // Graphe de structure : contexte, filtre de portée, détection de cycle,
        // profondeur/ancêtres et visibilité. Primitives study-niveau.
        ZStudyContext,
        ZStudyScopeFilter,
        zArtifactIsVisibleFrom,
        zDepthOf,
        zDetectCycle,
        zIsVisibleFrom,
        zMatchesScopeFilter,
        zRecomputeAncestorIds,
        zValidateCompetencyGraph,
        // Primitives de (dé)sérialisation et d'égalité partagées par le modèle de
        // structure : outillage interne au kernel, jamais une API flashcard.
        zStringListEquals,
        zStringSetEquals,
        zStringSetHash,
        zStudyAsJsonMap,
        zStudyDecodeBindings,
        zStudyDecodeClassificationConstraints,
        zStudyDecodeCompetencyRelations,
        zStudyDecodeExternalRefs,
        zStudyDecodeList,
        zStudyDecodeRefs,
        zStudyDecodeRelations,
        zStudyDecodeStringSet,
        zStudyDecodeTopicCompetencies,
        zStudyEncodeList,
        zStudyListEquals,
        zStudyPrune,
        // Clés canoniques du modèle de structure (familles, statuts, rôles, accès,
        // héritages, propagations, types de référence…) : jetons study-niveau.
        kZStudyAccessComment,
        kZStudyAccessKeys,
        kZStudyAccessManage,
        kZStudyAccessRead,
        kZStudyAccessWrite,
        kZStudyAcyclicCompetencyRelations,
        kZStudyCapabilityAcceptsParticipation,
        kZStudyCapabilityCanBeOfferingAudience,
        kZStudyCapabilityCanBeScoped,
        kZStudyCapabilityCanOwnResources,
        kZStudyCapabilityHierarchical,
        kZStudyCompetencyRelationContains,
        kZStudyCompetencyRelationEquivalent,
        kZStudyCompetencyRelationPrerequisite,
        kZStudyCompetencyRelationRelated,
        kZStudyCompetencyRelations,
        kZStudyFamilyCourse,
        kZStudyFamilyGroup,
        kZStudyFamilyOrgUnit,
        kZStudyFamilyOrganization,
        kZStudyFamilyPeriod,
        kZStudyFamilyProgram,
        kZStudyFamilyTopic,
        kZStudyInheritanceDescendants,
        kZStudyInheritanceExact,
        kZStudyInheritanceNone,
        kZStudyInheritances,
        kZStudyOfferingStatusActive,
        kZStudyOfferingStatusArchived,
        kZStudyOfferingStatusCancelled,
        kZStudyOfferingStatusCompleted,
        kZStudyOfferingStatusDraft,
        kZStudyOfferingStatusScheduled,
        kZStudyOfferingStatuses,
        kZStudyPropagationAncestors,
        kZStudyPropagationDescendants,
        kZStudyPropagationExact,
        kZStudyPropagationMembers,
        kZStudyPropagationNone,
        kZStudyPropagationOfferings,
        kZStudyPropagations,
        kZStudyRefTypeCompetency,
        kZStudyRefTypeCompetencyFramework,
        kZStudyRefTypeCourse,
        kZStudyRefTypeCurriculum,
        kZStudyRefTypeExplanation,
        kZStudyRefTypeFolder,
        kZStudyRefTypeGroup,
        kZStudyRefTypeOffering,
        kZStudyRefTypeOrgUnit,
        kZStudyRefTypeOrganization,
        kZStudyRefTypePeriod,
        kZStudyRefTypePrincipal,
        kZStudyRefTypeProgram,
        kZStudyRefTypeSubject,
        kZStudyRefTypeTopic,
        kZStudyRefTypeWorkspace,
        kZStudyRoleAssistant,
        kZStudyRoleCoordinator,
        kZStudyRoleLearner,
        kZStudyRoleObserver,
        kZStudyRoleTeacher,
        kZStudyRoleTutor,
        kZStudyRoles,
        kZStudyScopableRefTypes,
        kZStudyStatusActive,
        kZStudyStatusArchived,
        kZStudyStatusClosed,
        kZStudyStatusDraft;

export 'src/data/z_flashcard_repository.dart';
export 'src/data/z_repetition_store.dart';
export 'src/domain/z_choice.dart';
// Stratégie d'ajustement du facteur de facilité (`ZEaseFactorAdjustment`,
// canonique par défaut + variante tabulée). Déclarée sur `ZSrsConfig`,
// consommée par `ZSm2Scheduler` ; le bornage aux bornes de facteur de
// facilité reste au planificateur.
export 'src/domain/z_ease_factor_adjustment.dart';
// `ZFlashcard` est `ZExtensible` et porte le canal hors schéma `source`. Son
// extension générée est masquée : le `copyWith` généré ne connaît que les
// champs annotés — il ignore `extra`, `extension` et `source`, et les
// remet aux défauts, silencieusement, si on l'appelle explicitement.
export 'src/domain/z_flashcard.dart' hide ZFlashcardZcrud;
// Port d'évaluation consultatif : il suggère une qualité, il ne note
// jamais et n'écrit jamais le SRS. Foyer imposé par le graphe de
// dépendances (invariant AD-1) : le paquet d'étude dépend de
// `zcrud_flashcard` ⇒ le loger à côté de son port de génération voisin
// créerait un cycle.
export 'src/domain/z_flashcard_answer_evaluation_port.dart';
export 'src/domain/z_flashcard_api.dart';
// « Dupliquer pour modifier » : copie éphémère (`id: null`, `isReadOnly:
// false`, `createdAt`/`updatedAt` null) — aucun état personnel (ni SRS ni
// ordre : entités séparées indexant des ids, inatteignables sans id).
// L'original n'est jamais muté. Constructeur nominal, jamais `copyWith` (qui
// ne peut pas remettre `id` à null, donc écraserait l'original).
export 'src/domain/z_flashcard_duplicate.dart';
// Filtres test/examen purs : `ZMasteryLevel`/`zMasteryLevelOf` (bornes
// toutes lues sur `ZSrsConfig`, `clampQuality` unique voie de clamp),
// `ZFlashcardTestFilters`, `zApplyTestFilters` (délègue dossier/tags/types à
// `ZStudySessionSelector`, jamais réécrits), `zDrawQuestions`/
// `zShuffleChoices` (aléa injecté).
//
// Filtres de consultation, dans le même fichier (ils partagent
// `zMatchesSourceKind`, l'implémentation unique du prédicat de provenance)
// mais fonction distincte : `ZFlashcardSearchField` (enum),
// `ZFlashcardBrowseFilters`, `zApplyBrowseFilters` — qui délègue
// dossier/tags/types à `ZStudySessionSelector.matches` et jamais à
// `selectFrom` (son plafond tronquerait la liste). Aucun `Random`, aucun
// `questionCount` : une liste de gestion ne tire pas.
export 'src/domain/z_flashcard_filters.dart';
// Port d'indices : appelé uniquement après épuisement de l'indice stocké
// (`ZFlashcard.hint`), avec les indices déjà montrés (anti-répétition).
// Résultat éphémère : jamais persisté sur la carte.
export 'src/domain/z_flashcard_hint_port.dart';
// Évaluation locale exacte QCM/vrai-faux (le port n'est jamais appelé pour
// ces deux types). `zIsLocallyEvaluatedType` est la voie de routage (par le
// type, jamais par un retour `null`, voir sa dartdoc) : c'est la seule table
// qui décide entre port et évaluation locale.
export 'src/domain/z_flashcard_local_evaluation.dart';
// Normalisation de recherche : strippe les marques combinantes U+0300–U+036F
// (comble une limite de forme décomposée de `zFoldDiacritics`) puis délègue
// à `zFoldDiacritics` (`zcrud_core`) — la table de repli reste unique,
// jamais recopiée ici — et replie les espaces (dont insécables).
export 'src/domain/z_flashcard_search_text.dart';
// Tri pur, stable et total : `ZFlashcardSortMode` (enum),
// `zSortFlashcards`. Le mode manuel ne trie pas (l'ordre manuel appartient
// à `ZFolderContentsOrder`/`applyOrder`, jamais une seconde voie).
export 'src/domain/z_flashcard_sort.dart';
export 'src/domain/z_flashcard_source.dart';
export 'src/domain/z_flashcard_type.dart';
// Propriétaire unique de la pénalité d'indices. Appliqué en dernier, sur la
// valeur rendue (y compris celle du port) : un port qui rend une note haute
// avec plusieurs indices consommés ne contourne pas le plafond. Plancher
// dérivé (`passThreshold - 1`).
export 'src/domain/z_hint_penalty.dart';
export 'src/domain/z_repetition_info.dart' hide ZRepetitionInfoZcrud;
// Transition de révélation question→réponse (enum, jamais un booléen ; le
// réglage d'accessibilité « réduire les animations » prime sur sa valeur).
export 'src/domain/z_reveal_transition.dart';
// Catégorisation pure O(1) par carte (lookup Map, jamais `firstWhere`) :
// `ZSessionCategories`/`zCategorize`/`zIndexSrsById`.
export 'src/domain/z_session_categorization.dart';
export 'src/domain/z_sm2_scheduler.dart';
export 'src/domain/z_srs_config.dart';
export 'src/domain/z_srs_scheduler.dart';
// Ergonomie typée `ZFlashcardType` restituée sur `ZStudySessionConfig` (le
// noyau neutralise `types` en `List<String>`).
export 'src/domain/z_study_session_config_flashcard_x.dart';
// Couche presentation/ (widgets d'édition additifs).
export 'src/presentation/z_flashcard_choices_field_widget.dart';
// Contrat de slot de rendu de contenu + défaut texte brut thématisé.
// L'adaptateur markdown/LaTeX injectable est un ajout séparé.
export 'src/presentation/z_flashcard_content_slot.dart';
export 'src/presentation/z_flashcard_editing_scope.dart';
export 'src/presentation/z_flashcard_edition_validator.dart';
export 'src/presentation/z_flashcard_editor_config.dart';
export 'src/presentation/z_flashcard_editors.dart';
// Adaptateur markdown/LaTeX opt-in, chez le consommateur (jamais dans
// `zcrud_markdown` : ce serait un cycle, invariant AD-1). Le défaut de
// `ZFlashcardReviewCard` reste le texte brut du slot de contenu ci-dessus.
export 'src/presentation/z_flashcard_markdown_content.dart';
// Carte de révision adaptative (six types plus la révélation).
export 'src/presentation/z_flashcard_review_card.dart';
export 'src/presentation/z_flashcard_true_false_field_widget.dart';
export 'src/presentation/z_flashcard_type_field_widget.dart';
// Primitive unique de « réduire les animations » (accessibilité).
export 'src/presentation/z_reduce_motion.dart';
