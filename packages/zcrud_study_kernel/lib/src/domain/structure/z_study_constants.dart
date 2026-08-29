/// Constantes des **seules** valeurs de vocabulaire que le noyau interprète
/// lui-même.
///
/// Tout le reste du vocabulaire pédagogique (`kind`, `role`, `vocabularyKey`,
/// `valueKey`…) est une **chaîne opaque** : le noyau la transporte, la compare
/// et la restitue au round-trip sans jamais la tester. Les constantes de ce
/// fichier existent parce qu'une primitive du noyau en dépend :
///
/// - les modes de propagation d'un `ZStudyBinding` — lus par la résolution de
///   portée ;
/// - les capacités d'un `ZStudyKindSpec` — lues par la validation de
///   placement, qui raisonne sur la capacité et jamais sur le type concret ;
/// - les familles de `kind` — l'axe qui dit dans quel registre d'une ontologie
///   une spécification est déclarée ;
/// - les statuts de cycle de vie — la valeur de repli d'un enregistrement dont
///   le statut est absent.
///
/// Aucune de ces listes n'est fermée : une valeur inconnue reste valide,
/// traverse la (dé)sérialisation intacte et n'est simplement interprétée par
/// aucune primitive.
library;

// ---------------------------------------------------------------------------
// Propagation d'un rattachement (ZStudyBinding.propagation)
// ---------------------------------------------------------------------------

/// Propagation par défaut : le rattachement ne vaut que pour la cible exacte.
const String kZStudyPropagationExact = 'exact';

/// Le rattachement vaut aussi pour les descendants de la cible.
const String kZStudyPropagationDescendants = 'descendants';

/// Le rattachement vaut aussi pour les ancêtres de la cible.
const String kZStudyPropagationAncestors = 'ancestors';

/// Le rattachement vaut aussi pour les membres (participants) de la cible.
const String kZStudyPropagationMembers = 'members';

/// Le rattachement vaut aussi pour les offres portées par la cible.
const String kZStudyPropagationOfferings = 'offerings';

/// Le rattachement ne propage rien, pas même vers la cible exacte.
const String kZStudyPropagationNone = 'none';

/// Modes de propagation interprétés par le noyau, dans un ordre stable.
///
/// Une valeur hors de cet ensemble est conservée telle quelle : elle n'est
/// jamais réécrite ni rejetée, aucune primitive ne lui associe de sémantique.
const Set<String> kZStudyPropagations = <String>{
  kZStudyPropagationExact,
  kZStudyPropagationDescendants,
  kZStudyPropagationAncestors,
  kZStudyPropagationMembers,
  kZStudyPropagationOfferings,
  kZStudyPropagationNone,
};

// ---------------------------------------------------------------------------
// Capacités d'un ZStudyKindSpec
// ---------------------------------------------------------------------------

/// Le type peut recevoir des participations (des personnes s'y rattachent).
const String kZStudyCapabilityAcceptsParticipation = 'acceptsParticipation';

/// Le type peut être l'audience d'une offre.
const String kZStudyCapabilityCanBeOfferingAudience = 'canBeOfferingAudience';

/// Le type peut posséder des ressources (dossiers, notes, cartes…).
const String kZStudyCapabilityCanOwnResources = 'canOwnResources';

/// Le type peut servir de portée dans un filtre.
const String kZStudyCapabilityCanBeScoped = 'canBeScoped';

/// Le type admet un parent de son propre registre (arbre de contenance).
///
/// C'est la capacité que lit la validation de placement : un type qui ne la
/// porte pas ne peut pas être placé sous un parent.
const String kZStudyCapabilityHierarchical = 'hierarchical';

// ---------------------------------------------------------------------------
// Familles de `kind` (registres d'une ontologie)
// ---------------------------------------------------------------------------

/// Famille des types d'organisation.
const String kZStudyFamilyOrganization = 'organization';

/// Famille des types d'unité d'organisation.
const String kZStudyFamilyOrgUnit = 'orgUnit';

/// Famille des types de groupe.
const String kZStudyFamilyGroup = 'group';

/// Famille des types de programme.
const String kZStudyFamilyProgram = 'program';

/// Famille des types de période.
const String kZStudyFamilyPeriod = 'period';

/// Famille des types de cours.
const String kZStudyFamilyCourse = 'course';

/// Famille des types de thème.
const String kZStudyFamilyTopic = 'topic';

// ---------------------------------------------------------------------------
// Statuts de cycle de vie
// ---------------------------------------------------------------------------

/// Statut de repli d'un enregistrement dont le statut est absent ou illisible.
const String kZStudyStatusActive = 'active';

/// Enregistrement en préparation, non encore ouvert.
const String kZStudyStatusDraft = 'draft';

/// Enregistrement clos : plus d'entrée, lecture toujours possible.
const String kZStudyStatusClosed = 'closed';

/// Enregistrement archivé — soft-archive réversible, jamais une suppression
/// et jamais une cascade sur ce qui s'y rattache.
const String kZStudyStatusArchived = 'archived';

// ---------------------------------------------------------------------------
// Types de référence (ZStudyRef.type)
// ---------------------------------------------------------------------------

/// Type de référence vers un espace de travail.
const String kZStudyRefTypeWorkspace = 'workspace';

/// Type de référence vers un mandant (personne, groupe de sécurité, service).
const String kZStudyRefTypePrincipal = 'principal';

/// Type de référence vers une organisation.
const String kZStudyRefTypeOrganization = 'organization';

/// Type de référence vers une unité d'organisation.
const String kZStudyRefTypeOrgUnit = 'orgUnit';

/// Type de référence vers un groupe.
const String kZStudyRefTypeGroup = 'group';

/// Type de référence vers un programme.
const String kZStudyRefTypeProgram = 'program';

/// Type de référence vers un cours.
const String kZStudyRefTypeCourse = 'course';

/// Type de référence vers une matière.
const String kZStudyRefTypeSubject = 'subject';

/// Type de référence vers une période.
const String kZStudyRefTypePeriod = 'period';

/// Type de référence vers une offre (concrétisation d'un cours).
const String kZStudyRefTypeOffering = 'offering';

/// Type de référence vers un thème de programme.
const String kZStudyRefTypeTopic = 'topic';

/// Types de référence utilisables comme **portée** d'un filtre.
///
/// C'est la restriction documentaire que désigne `ZStudyScopeRef` : une portée
/// est une `ZStudyRef` dont le [ZStudyRef.type] appartient à cet ensemble.
/// L'ensemble est **indicatif** — un filtre portant une portée d'un autre type
/// reste valide et n'est jamais rejeté ; il ne bénéficie simplement d'aucune
/// résolution fournie par le noyau.
const Set<String> kZStudyScopableRefTypes = <String>{
  kZStudyRefTypeWorkspace,
  kZStudyRefTypeOrganization,
  kZStudyRefTypeOrgUnit,
  kZStudyRefTypeGroup,
  kZStudyRefTypeProgram,
  kZStudyRefTypeCourse,
  kZStudyRefTypeSubject,
  kZStudyRefTypePeriod,
  kZStudyRefTypeOffering,
  kZStudyRefTypeTopic,
  kZStudyRefTypeCurriculum,
};

/// Type de référence vers un référentiel de progression (curriculum).
const String kZStudyRefTypeCurriculum = 'curriculum';

/// Type de référence vers un cadre de compétences.
const String kZStudyRefTypeCompetencyFramework = 'competencyFramework';

/// Type de référence vers une compétence.
const String kZStudyRefTypeCompetency = 'competency';

/// Type de référence vers un dossier d'organisation.
const String kZStudyRefTypeFolder = 'folder';

/// Type de référence vers une explication attachée à un dossier.
const String kZStudyRefTypeExplanation = 'explanation';

// ---------------------------------------------------------------------------
// Statuts d'une offre (ZStudyOffering.status)
// ---------------------------------------------------------------------------

/// Offre en préparation, pas encore datée ni ouverte.
const String kZStudyOfferingStatusDraft = kZStudyStatusDraft;

/// Offre datée mais pas encore commencée.
const String kZStudyOfferingStatusScheduled = 'scheduled';

/// Offre en cours — valeur de repli d'une offre au statut absent.
const String kZStudyOfferingStatusActive = kZStudyStatusActive;

/// Offre menée à son terme.
const String kZStudyOfferingStatusCompleted = 'completed';

/// Offre archivée — soft-archive réversible, jamais une cascade.
const String kZStudyOfferingStatusArchived = kZStudyStatusArchived;

/// Offre annulée avant son terme (distincte d'une offre archivée : elle n'a
/// pas eu lieu).
const String kZStudyOfferingStatusCancelled = 'cancelled';

/// Statuts d'offre que le noyau nomme, dans un ordre stable.
///
/// Comme toutes les listes de ce fichier, elle n'est pas fermée : un statut
/// hors de cet ensemble traverse la (dé)sérialisation intact.
const Set<String> kZStudyOfferingStatuses = <String>{
  kZStudyOfferingStatusDraft,
  kZStudyOfferingStatusScheduled,
  kZStudyOfferingStatusActive,
  kZStudyOfferingStatusCompleted,
  kZStudyOfferingStatusArchived,
  kZStudyOfferingStatusCancelled,
};

// ---------------------------------------------------------------------------
// Rôles d'une participation (ZStudyParticipation.role)
// ---------------------------------------------------------------------------

/// Rôle de celui qui suit le contenu.
const String kZStudyRoleLearner = 'learner';

/// Rôle de celui qui conduit le contenu.
const String kZStudyRoleTeacher = 'teacher';

/// Rôle de celui qui seconde la conduite du contenu.
const String kZStudyRoleAssistant = 'assistant';

/// Rôle d'accompagnement individuel, hors conduite du contenu.
const String kZStudyRoleTutor = 'tutor';

/// Rôle de présence sans participation active.
const String kZStudyRoleObserver = 'observer';

/// Rôle d'encadrement administratif.
const String kZStudyRoleCoordinator = 'coordinator';

/// Rôles de participation que le noyau nomme, dans un ordre stable.
///
/// **Un rôle n'est pas une permission** : cette liste sert à nommer des faits
/// courants, jamais à décider d'un droit. L'autorisation est calculée par
/// l'hôte.
const Set<String> kZStudyRoles = <String>{
  kZStudyRoleLearner,
  kZStudyRoleTeacher,
  kZStudyRoleAssistant,
  kZStudyRoleTutor,
  kZStudyRoleObserver,
  kZStudyRoleCoordinator,
};

// ---------------------------------------------------------------------------
// Relations entre compétences (ZStudyCompetencyRelation.kind)
// ---------------------------------------------------------------------------

/// La compétence d'origine doit être acquise avant celle d'arrivée.
const String kZStudyCompetencyRelationPrerequisite = 'prerequisite';

/// La compétence d'origine contient celle d'arrivée (décomposition).
const String kZStudyCompetencyRelationContains = 'contains';

/// Lien libre, sans ordre ni décomposition.
const String kZStudyCompetencyRelationRelated = 'related';

/// Les deux compétences se valent d'un cadre à l'autre.
const String kZStudyCompetencyRelationEquivalent = 'equivalent';

/// Natures de relation que le noyau nomme, dans un ordre stable.
const Set<String> kZStudyCompetencyRelations = <String>{
  kZStudyCompetencyRelationPrerequisite,
  kZStudyCompetencyRelationContains,
  kZStudyCompetencyRelationRelated,
  kZStudyCompetencyRelationEquivalent,
};

/// Natures de relation dont le sous-graphe doit rester **acyclique**.
///
/// Un cycle de prérequis ou de décomposition est une contradiction (rien ne
/// peut se précéder ni se contenir soi-même) ; un cycle de `related` ou
/// d'`equivalent` est au contraire attendu — ce sont des liens symétriques.
/// C'est la seule liste de ce fichier dont l'appartenance change un verdict :
/// une nature hors de cet ensemble n'est jamais contrôlée.
const Set<String> kZStudyAcyclicCompetencyRelations = <String>{
  kZStudyCompetencyRelationPrerequisite,
  kZStudyCompetencyRelationContains,
};

// ---------------------------------------------------------------------------
// Héritage d'une attribution de rôle (ZStudyRoleBinding.inheritance)
// ---------------------------------------------------------------------------

/// L'attribution ne vaut que pour la portée désignée.
const String kZStudyInheritanceExact = 'exact';

/// L'attribution vaut aussi pour les descendants de la portée.
const String kZStudyInheritanceDescendants = 'descendants';

/// L'attribution ne vaut pour rien — désactivée sans être supprimée.
const String kZStudyInheritanceNone = 'none';

/// Modes d'héritage que le noyau nomme, dans un ordre stable.
const Set<String> kZStudyInheritances = <String>{
  kZStudyInheritanceExact,
  kZStudyInheritanceDescendants,
  kZStudyInheritanceNone,
};

// ---------------------------------------------------------------------------
// Clés d'accès d'un partage (ZStudyShareGrant.accessKey)
// ---------------------------------------------------------------------------

/// Accès en lecture.
const String kZStudyAccessRead = 'read';

/// Accès en lecture et commentaire.
const String kZStudyAccessComment = 'comment';

/// Accès en écriture.
const String kZStudyAccessWrite = 'write';

/// Accès permettant de repartager.
const String kZStudyAccessManage = 'manage';

/// Clés d'accès que le noyau nomme, dans un ordre stable.
///
/// **Aucune n'est un droit** : ce sont des étiquettes de faits de partage.
/// Le noyau ne les ordonne pas, ne les compare pas et n'en déduit jamais
/// qu'une action est permise.
const Set<String> kZStudyAccessKeys = <String>{
  kZStudyAccessRead,
  kZStudyAccessComment,
  kZStudyAccessWrite,
  kZStudyAccessManage,
};
