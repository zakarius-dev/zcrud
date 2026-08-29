/// `ZStudyStructureSnapshot` — une vue immuable de la structure, fournie par
/// l'appelant.
///
/// La résolution de contexte est **pure** : elle ne lit aucun dépôt, n'ouvre
/// aucun flux et n'attend rien. Tout ce dont elle a besoin arrive dans cet
/// instantané, sous forme de maps `id → entité`. C'est ce qui la rend
/// testable au littéral près, exécutable hors ligne, et réutilisable côté
/// serveur comme côté écran.
///
/// **Toutes les maps sont facultatives.** Un instantané partiel est légitime :
/// la résolution rend ce qu'elle peut prouver et laisse le reste vide, sans
/// jamais échouer pour cause d'absence. C'est la même règle que pour un parent
/// hors ensemble dans la projection des ancêtres — une vue partielle reste
/// exploitable.
///
/// **L'ordre d'itération des maps est celui que l'appelant a construit** (ordre
/// d'insertion). La résolution s'en sert pour ordonner ce qu'elle rend :
/// deux appels sur le même instantané rendent donc exactement le même contexte.
library;

import 'z_study_classification.dart';
import 'z_study_competency.dart';
import 'z_study_competency_framework.dart';
import 'z_study_constants.dart';
import 'z_study_course.dart';
import 'z_study_curriculum.dart';
import 'z_study_group.dart';
import 'z_study_offering.dart';
import 'z_study_offering_audience.dart';
import 'z_study_org_unit.dart';
import 'z_study_organization.dart';
import 'z_study_participation.dart';
import 'z_study_period.dart';
import 'z_study_program.dart';
import 'z_study_program_course.dart';
import 'z_study_ref.dart';
import 'z_study_subject.dart';
import 'z_study_topic.dart';

/// Vue immuable de la structure, indexée par identifiant.
class ZStudyStructureSnapshot {
  /// Construit un instantané. Toutes les maps sont facultatives.
  const ZStudyStructureSnapshot({
    this.organizations = const <String, ZStudyOrganization>{},
    this.orgUnits = const <String, ZStudyOrgUnit>{},
    this.groups = const <String, ZStudyGroup>{},
    this.programs = const <String, ZStudyProgram>{},
    this.programCourses = const <String, ZStudyProgramCourse>{},
    this.subjects = const <String, ZStudySubject>{},
    this.courses = const <String, ZStudyCourse>{},
    this.periods = const <String, ZStudyPeriod>{},
    this.offerings = const <String, ZStudyOffering>{},
    this.offeringAudiences = const <String, ZStudyOfferingAudience>{},
    this.participations = const <String, ZStudyParticipation>{},
    this.curricula = const <String, ZStudyCurriculum>{},
    this.topics = const <String, ZStudyTopic>{},
    this.competencyFrameworks =
        const <String, ZStudyCompetencyFramework>{},
    this.competencies = const <String, ZStudyCompetency>{},
    this.classifications = const <String, ZStudyClassification>{},
  });

  /// Instantané vide — une résolution menée dessus ne prouve rien et ne
  /// rend rien, sans jamais échouer.
  static const ZStudyStructureSnapshot empty = ZStudyStructureSnapshot();

  /// Organisations, indexées par identifiant.
  final Map<String, ZStudyOrganization> organizations;

  /// Unités d'organisation, indexées par identifiant.
  final Map<String, ZStudyOrgUnit> orgUnits;

  /// Groupes, indexés par identifiant.
  final Map<String, ZStudyGroup> groups;

  /// Programmes, indexés par identifiant.
  final Map<String, ZStudyProgram> programs;

  /// Liaisons programme ↔ cours, indexées par identifiant.
  final Map<String, ZStudyProgramCourse> programCourses;

  /// Matières, indexées par identifiant.
  final Map<String, ZStudySubject> subjects;

  /// Cours, indexés par identifiant.
  final Map<String, ZStudyCourse> courses;

  /// Périodes, indexées par identifiant.
  final Map<String, ZStudyPeriod> periods;

  /// Offres, indexées par identifiant.
  final Map<String, ZStudyOffering> offerings;

  /// Audiences d'offres, indexées par identifiant.
  final Map<String, ZStudyOfferingAudience> offeringAudiences;

  /// Participations, indexées par identifiant.
  final Map<String, ZStudyParticipation> participations;

  /// Curriculums, indexés par identifiant.
  final Map<String, ZStudyCurriculum> curricula;

  /// Thèmes, indexés par identifiant.
  final Map<String, ZStudyTopic> topics;

  /// Cadres de compétences, indexés par identifiant.
  final Map<String, ZStudyCompetencyFramework> competencyFrameworks;

  /// Compétences, indexées par identifiant.
  final Map<String, ZStudyCompetency> competencies;

  /// Classifications, indexées par identifiant.
  final Map<String, ZStudyClassification> classifications;

  /// Chaîne des ancêtres de [ref], racine d'abord, `const []` si l'instantané
  /// ne connaît pas la cible ou si son type n'a pas d'arbre.
  ///
  /// L'absence n'est **jamais** un échec : une cible inconnue est une racine
  /// locale, exactement comme un parent hors ensemble.
  List<String> ancestorIdsOf(ZStudyRef ref) => switch (ref.type) {
    kZStudyRefTypeOrganization =>
      organizations[ref.id]?.ancestorIds ?? const <String>[],
    kZStudyRefTypeOrgUnit => orgUnits[ref.id]?.ancestorIds ?? const <String>[],
    kZStudyRefTypeGroup => groups[ref.id]?.ancestorIds ?? const <String>[],
    kZStudyRefTypeProgram => programs[ref.id]?.ancestorIds ?? const <String>[],
    kZStudyRefTypePeriod => periods[ref.id]?.ancestorIds ?? const <String>[],
    kZStudyRefTypeTopic => topics[ref.id]?.ancestorIds ?? const <String>[],
    _ => const <String>[],
  };

  /// Référence vers l'élément `(type, id)`, **instantané d'affichage inclus**
  /// quand l'instantané le connaît ; sinon une référence d'identité seule.
  ///
  /// Une identité toujours rendue, un libellé rendu quand il est prouvable :
  /// c'est ce qui permet à un contexte résolu sur une vue partielle de rester
  /// affichable sans mentir sur ce qu'il sait.
  ZStudyRef refFor(String type, String id) => switch (type) {
    kZStudyRefTypeOrganization when organizations.containsKey(id) =>
      ZStudyRef(
        type: type,
        id: id,
        label: organizations[id]!.label,
        code: organizations[id]!.code,
        kind: organizations[id]!.kind,
      ),
    kZStudyRefTypeOrgUnit when orgUnits.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: orgUnits[id]!.label,
      code: orgUnits[id]!.code,
      kind: orgUnits[id]!.kind,
    ),
    kZStudyRefTypeGroup when groups.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: groups[id]!.label,
      code: groups[id]!.code,
      kind: groups[id]!.kind,
    ),
    kZStudyRefTypeProgram when programs.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: programs[id]!.label,
      code: programs[id]!.code,
      kind: programs[id]!.kind,
    ),
    kZStudyRefTypePeriod when periods.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: periods[id]!.label,
      code: periods[id]!.code,
      kind: periods[id]!.kind,
    ),
    kZStudyRefTypeSubject when subjects.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: subjects[id]!.label,
      code: subjects[id]!.code,
      kind: subjects[id]!.kind,
    ),
    kZStudyRefTypeCourse when courses.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: courses[id]!.label,
      code: courses[id]!.code,
      kind: courses[id]!.kind,
    ),
    kZStudyRefTypeOffering when offerings.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: offerings[id]!.label,
      code: offerings[id]!.code,
    ),
    kZStudyRefTypeCurriculum when curricula.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: curricula[id]!.label,
      code: curricula[id]!.code,
    ),
    kZStudyRefTypeTopic when topics.containsKey(id) => ZStudyRef(
      type: type,
      id: id,
      label: topics[id]!.label,
      code: topics[id]!.code,
      kind: topics[id]!.kind,
    ),
    _ => ZStudyRef(type: type, id: id),
  };

  /// `true` si l'instantané ne contient rien du tout.
  bool get isEmpty =>
      organizations.isEmpty &&
      orgUnits.isEmpty &&
      groups.isEmpty &&
      programs.isEmpty &&
      programCourses.isEmpty &&
      subjects.isEmpty &&
      courses.isEmpty &&
      periods.isEmpty &&
      offerings.isEmpty &&
      offeringAudiences.isEmpty &&
      participations.isEmpty &&
      curricula.isEmpty &&
      topics.isEmpty &&
      competencyFrameworks.isEmpty &&
      competencies.isEmpty &&
      classifications.isEmpty;
}
