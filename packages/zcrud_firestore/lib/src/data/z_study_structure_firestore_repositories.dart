/// Fabrique des dépôts Firestore de la **structure d'étude**.
///
/// Les vingt-trois entités de structure du noyau d'étude sont servies par le
/// dépôt générique (`FirebaseZRepositoryImpl`) **sans une seule ligne de
/// (dé)sérialisation spécifique** : chaque dépôt est construit à partir du
/// registrar de codegen de son entité, et son `kind` est **résolu par le
/// registre** à partir du type. Ce fichier ne connaît donc ni un nom de champ,
/// ni une valeur de `kind` : ajouter un champ à une entité du noyau n'y change
/// rien.
///
/// Ce qui appartient à l'hôte — et à lui seul — est l'**emplacement** des
/// collections : il le déclare par une fonction `kind → chemin`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

import 'firebase_z_repository_impl.dart';

/// Résout le **chemin de collection** Firestore d'un `kind` de structure.
///
/// Reçoit le `kind` canonique de l'entité (celui sous lequel son registrar
/// l'enregistre) et rend le chemin de la collection qui la porte. Le nom des
/// collections appartient à l'hôte : aucun défaut n'est proposé.
///
/// La fonction est appelée **une fois par entité** au moment de la
/// construction, jamais à chaque lecture ; elle doit être pure et totale (un
/// `kind` inconnu ne lui est jamais soumis).
typedef ZStudyCollectionPathOf = String Function(String kind);

/// Construit un [ZcrudRegistry] portant les **vingt-trois** entités de
/// structure du noyau d'étude, et rien d'autre.
///
/// [decodeContext] câble les collaborateurs de décodage (résolveur
/// d'extensions typées, registre de provenance) ; sans lui, un slot
/// `extension` persisté reste sur son canal de survie non typé.
///
/// Le registre rendu est **neuf** à chaque appel : il ne peut jamais entrer en
/// collision avec un registre d'application déjà peuplé.
ZcrudRegistry buildStudyStructureRegistry({ZDecodeContext? decodeContext}) {
  final ZcrudRegistry registry = ZcrudRegistry(decodeContext: decodeContext);
  registerZStudyWorkspace(registry);
  registerZStudyPrincipal(registry);
  registerZStudyOrganization(registry);
  registerZStudyOrgUnit(registry);
  registerZStudyProgram(registry);
  registerZStudyGroup(registry);
  registerZStudyClassification(registry);
  registerZStudySubject(registry);
  registerZStudyCourse(registry);
  registerZStudyProgramCourse(registry);
  registerZStudyCalendar(registry);
  registerZStudyPeriod(registry);
  registerZStudySession(registry);
  registerZStudyOffering(registry);
  registerZStudyOfferingAudience(registry);
  registerZStudyParticipation(registry);
  registerZStudyCurriculum(registry);
  registerZStudyTopic(registry);
  registerZStudyCompetency(registry);
  registerZStudyCompetencyFramework(registry);
  registerZStudyExplanation(registry);
  registerZStudyRoleBinding(registry);
  registerZStudyShareGrant(registry);
  return registry;
}

/// Jeu **immuable** des dépôts de la structure d'étude, un par entité.
///
/// Chaque membre est un `ZRepository<T>` **nu** : aucune signature ne porte de
/// type `cloud_firestore`. Les dépôts partagent le registre, la sémantique de
/// suppression et le journal passés à la fabrique, mais chacun vit sur sa
/// propre collection.
class ZStudyStructureRepositories {
  /// Assemble le jeu ; réservé à [buildStudyStructureRepositories].
  const ZStudyStructureRepositories._({
    required this.registry,
    required this.workspaces,
    required this.principals,
    required this.organizations,
    required this.orgUnits,
    required this.programs,
    required this.groups,
    required this.classifications,
    required this.subjects,
    required this.courses,
    required this.programCourses,
    required this.calendars,
    required this.periods,
    required this.sessions,
    required this.offerings,
    required this.offeringAudiences,
    required this.participations,
    required this.curricula,
    required this.topics,
    required this.competencies,
    required this.competencyFrameworks,
    required this.explanations,
    required this.roleBindings,
    required this.shareGrants,
  });

  /// Registre partagé par les vingt-trois dépôts (codecs + schémas du noyau).
  ///
  /// Exposé pour que l'hôte puisse en dériver un `kind` ou un schéma sans
  /// reconstruire un second registre.
  final ZcrudRegistry registry;

  /// Espaces de travail.
  final ZRepository<ZStudyWorkspace> workspaces;

  /// Personnes et entités agissantes.
  final ZRepository<ZStudyPrincipal> principals;

  /// Organisations.
  final ZRepository<ZStudyOrganization> organizations;

  /// Unités d'organisation (arbre à profondeur libre).
  final ZRepository<ZStudyOrgUnit> orgUnits;

  /// Programmes.
  final ZRepository<ZStudyProgram> programs;

  /// Groupes d'apprenants.
  final ZRepository<ZStudyGroup> groups;

  /// Classifications.
  final ZRepository<ZStudyClassification> classifications;

  /// Matières.
  final ZRepository<ZStudySubject> subjects;

  /// Cours.
  final ZRepository<ZStudyCourse> courses;

  /// Rattachements cours ↔ programme.
  final ZRepository<ZStudyProgramCourse> programCourses;

  /// Calendriers.
  final ZRepository<ZStudyCalendar> calendars;

  /// Périodes (arbre à profondeur libre).
  final ZRepository<ZStudyPeriod> periods;

  /// Séances.
  final ZRepository<ZStudySession> sessions;

  /// Offres de formation.
  final ZRepository<ZStudyOffering> offerings;

  /// Audiences d'une offre.
  final ZRepository<ZStudyOfferingAudience> offeringAudiences;

  /// Participations.
  final ZRepository<ZStudyParticipation> participations;

  /// Cursus.
  final ZRepository<ZStudyCurriculum> curricula;

  /// Thèmes (arbre à profondeur libre).
  final ZRepository<ZStudyTopic> topics;

  /// Compétences.
  final ZRepository<ZStudyCompetency> competencies;

  /// Référentiels de compétences.
  final ZRepository<ZStudyCompetencyFramework> competencyFrameworks;

  /// Explications.
  final ZRepository<ZStudyExplanation> explanations;

  /// Attributions de rôle.
  final ZRepository<ZStudyRoleBinding> roleBindings;

  /// Partages.
  final ZRepository<ZStudyShareGrant> shareGrants;

  /// Libère les vingt-trois dépôts (flux temps réel compris).
  ///
  /// À appeler quand l'hôte démonte la portée qui les détenait ; un dépôt
  /// libéré n'émet plus rien.
  void dispose() {
    for (final ZRepository<ZEntity> repository in all) {
      repository.dispose();
    }
  }

  /// Les vingt-trois dépôts, dans un ordre stable.
  ///
  /// Destiné aux traitements uniformes (libération, instrumentation) ; le type
  /// d'élément y est effacé vers `ZRepository<ZEntity>`.
  List<ZRepository<ZEntity>> get all => <ZRepository<ZEntity>>[
        workspaces,
        principals,
        organizations,
        orgUnits,
        programs,
        groups,
        classifications,
        subjects,
        courses,
        programCourses,
        calendars,
        periods,
        sessions,
        offerings,
        offeringAudiences,
        participations,
        curricula,
        topics,
        competencies,
        competencyFrameworks,
        explanations,
        roleBindings,
        shareGrants,
      ];
}

/// Construit les vingt-trois dépôts Firestore de la structure d'étude.
///
/// [collectionPathOf] reçoit le `kind` canonique de chaque entité et rend le
/// chemin de sa collection. C'est le **seul** point où l'hôte nomme quoi que
/// ce soit : la (dé)sérialisation, le schéma et le `kind` viennent du noyau.
///
/// ## Collection préexistante
///
/// Sur une collection écrite avant l'adoption de ces dépôts — documents sans
/// `is_deleted` ni `updated_at` — déclarer
/// `deletionSemantics: ZDeletionSemantics.absentMeansAlive`, sinon **aucun
/// document n'est lu** : la sémantique [ZDeletionSemantics.strict] exige la
/// présence du drapeau de suppression sur chaque document (filtre serveur).
/// Chaque `save` pose les métadonnées de synchronisation : la collection
/// converge vers la forme stricte au fil des écritures, et l'hôte peut
/// basculer une fois tous les documents réécrits. [legacyDeletedKey] n'est
/// honorée qu'en [ZDeletionSemantics.absentMeansAlive] : c'est le drapeau de
/// suppression historique de l'hôte, lu **en plus** du drapeau canonique.
///
/// [decodeContext] câble le résolveur d'extensions typées et le registre de
/// provenance de l'hôte. [logger] reçoit un message par document écarté.
///
/// ## Document abîmé
///
/// Une lecture ne devient **jamais** un échec à cause d'un document abîmé.
/// La (dé)sérialisation du noyau est elle-même défensive : un champ dont le
/// type persisté n'est pas celui du schéma retombe sur le **défaut du
/// schéma** — jamais une exception, jamais la valeur brute traversant la
/// frontière, jamais les autres documents perdus. Si un décodage venait
/// malgré tout à lever, le document serait écarté et journalisé sur [logger],
/// et `getById` le rendrait `Left(ZNotFoundFailure)`.
///
/// ## Portée
///
/// Les entités hiérarchiques persistent la chaîne de leurs ancêtres ; la
/// requête de portée correspondante se construit avec
/// [zStudyAncestorFilter] / [zStudyAncestorRequest].
ZStudyStructureRepositories buildStudyStructureRepositories({
  required FirebaseFirestore firestore,
  required ZStudyCollectionPathOf collectionPathOf,
  ZDeletionSemantics deletionSemantics = ZDeletionSemantics.strict,
  String? legacyDeletedKey,
  ZDecodeContext? decodeContext,
  ZFirestoreLog? logger,
}) {
  final ZcrudRegistry registry = buildStudyStructureRegistry(
    decodeContext: decodeContext,
  );

  // Le `kind` est LU dans le registre (association posée par le registrar du
  // noyau) : c'est ce qui permet à ce fichier de ne porter aucun littéral de
  // kind ni de champ. Un `null` ici signifierait un registrar manquant —
  // erreur de programmation de cette fabrique, pas une donnée de l'hôte.
  ZRepository<T> build<T extends ZEntity>() {
    final String? kind = registry.kindOf<T>();
    if (kind == null) {
      throw StateError(
        'buildStudyStructureRepositories : aucun kind enregistré pour $T — '
        'le registrar correspondant manque à buildStudyStructureRegistry().',
      );
    }
    return FirebaseZRepositoryImpl<T>.fromRegistry(
      firestore: firestore,
      collectionPath: collectionPathOf(kind),
      kind: kind,
      registry: registry,
      logger: logger,
      deletionSemantics: deletionSemantics,
      legacyDeletedKey: legacyDeletedKey,
    );
  }

  return ZStudyStructureRepositories._(
    registry: registry,
    workspaces: build<ZStudyWorkspace>(),
    principals: build<ZStudyPrincipal>(),
    organizations: build<ZStudyOrganization>(),
    orgUnits: build<ZStudyOrgUnit>(),
    programs: build<ZStudyProgram>(),
    groups: build<ZStudyGroup>(),
    classifications: build<ZStudyClassification>(),
    subjects: build<ZStudySubject>(),
    courses: build<ZStudyCourse>(),
    programCourses: build<ZStudyProgramCourse>(),
    calendars: build<ZStudyCalendar>(),
    periods: build<ZStudyPeriod>(),
    sessions: build<ZStudySession>(),
    offerings: build<ZStudyOffering>(),
    offeringAudiences: build<ZStudyOfferingAudience>(),
    participations: build<ZStudyParticipation>(),
    curricula: build<ZStudyCurriculum>(),
    topics: build<ZStudyTopic>(),
    competencies: build<ZStudyCompetency>(),
    competencyFrameworks: build<ZStudyCompetencyFramework>(),
    explanations: build<ZStudyExplanation>(),
    roleBindings: build<ZStudyRoleBinding>(),
    shareGrants: build<ZStudyShareGrant>(),
  );
}
