/// Résolution de contexte, visibilité et application des filtres de portée.
///
/// Trois primitives **pures**, sans dépôt, sans flux, sans horloge implicite :
/// tout ce qu'elles savent arrive par un `ZStudyStructureSnapshot` et, pour ce
/// qui est daté, par un instant explicite.
///
/// La propagation d'un rattachement (`exact`, `descendants`, `ancestors`,
/// `members`, `offerings`, `none`) est **calculée en un seul endroit** —
/// [zIsVisibleFrom]. Aucune autre primitive n'en réimplémente le moindre cas :
/// c'est ce qui garantit qu'un dossier, une note et une carte répondent
/// exactement la même chose à la même question de portée.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_artifact.dart';
import 'z_study_binding.dart';
import 'z_study_constants.dart';
import 'z_study_context.dart';
import 'z_study_ref.dart';
import 'z_study_scope_filter.dart';
import 'z_study_structure_snapshot.dart';

/// Résout la position d'une offre dans la structure, sans effet de bord.
///
/// La résolution est **totale sur ce qu'elle sait** : elle ne rend que ce que
/// l'instantané prouve, laisse le reste vide, et n'échoue que dans un seul cas
/// — l'offre demandée est absente de l'instantané. Une matière inconnue, un
/// programme absent, une période manquante ne sont pas des erreurs : ce sont
/// des vides, et un vide est une réponse valide.
class ZStudyContextResolver {
  /// Construit un résolveur. Il n'a pas d'état : une instance `const` suffit.
  const ZStudyContextResolver();

  /// Résout le contexte de [offeringRef] dans [snapshot].
  ///
  /// `Left(ZNotFoundFailure)` si l'offre est absente de l'instantané —
  /// le seul échec possible, et il désigne bien un manque de l'appelant.
  ///
  /// Règles de résolution :
  /// - **le porteur est cherché dans les deux registres.**
  ///   `ZStudyOffering.organizationId` est un identifiant opaque : le résolveur
  ///   le cherche d'abord parmi les unités d'organisation, puis parmi les
  ///   organisations. Trouvé comme unité, il remplit [ZStudyContext.orgUnitPath]
  ///   **et** le chemin de l'organisation qui la porte ; trouvé comme
  ///   organisation, il ne remplit que [ZStudyContext.organizationPath]. Le
  ///   noyau ne décide donc jamais au nom du champ, toujours par la donnée.
  ///   À défaut d'identifiant sur l'offre, le porteur est cherché sur le cours,
  ///   puis sur le curriculum, puis sur la matière — le premier trouvé fait
  ///   foi ;
  /// - les **chemins** vont de la racine à la cible, cible incluse ;
  /// - les **groupes** viennent des audiences de l'offre, dans l'ordre de
  ///   l'instantané ;
  /// - les **programmes** viennent des liaisons programme ↔ cours portant le
  ///   cours de l'offre, dans l'ordre de l'instantané, suivis du programme du
  ///   curriculum s'il n'y figure pas déjà ;
  /// - la **matière** vient du cours, à défaut du curriculum ;
  /// - les **classifications** sont celles qui visent une référence du
  ///   contexte, dédoublonnées et triées. [at] les restreint à celles qui sont
  ///   actives à cet instant ; omis, aucune restriction de date n'est
  ///   appliquée.
  ZResult<ZStudyContext> resolve(
    ZStudyRef offeringRef,
    ZStudyStructureSnapshot snapshot, {
    DateTime? at,
  }) {
    final offering = snapshot.offerings[offeringRef.id];
    if (offering == null) {
      return Left<ZFailure, ZStudyContext>(
        ZNotFoundFailure(
          'Offre « ${offeringRef.id} » absente de l\'instantané.',
        ),
      );
    }

    final course = snapshot.courses[offering.courseId];
    final curriculum = offering.curriculumId == null
        ? null
        : snapshot.curricula[offering.curriculumId!];
    final subjectId = course?.subjectId ?? curriculum?.subjectId;
    final subject = subjectId == null ? null : snapshot.subjects[subjectId];

    // Porteur : le premier identifiant déclaré en remontant offre → cours →
    // curriculum → matière. Aucun n'est privilégié par son type, seulement par
    // sa proximité avec l'offre.
    final holderId =
        offering.organizationId ??
        course?.organizationId ??
        curriculum?.organizationId ??
        subject?.organizationId;

    var organizationPath = const <ZStudyRef>[];
    var orgUnitPath = const <ZStudyRef>[];
    if (holderId != null && holderId.isNotEmpty) {
      final unit = snapshot.orgUnits[holderId];
      if (unit != null) {
        orgUnitPath = _pathOf(
          snapshot,
          kZStudyRefTypeOrgUnit,
          holderId,
          unit.ancestorIds,
        );
        final ownerId = unit.organizationId;
        if (ownerId.isNotEmpty) {
          organizationPath = _pathOf(
            snapshot,
            kZStudyRefTypeOrganization,
            ownerId,
            snapshot.organizations[ownerId]?.ancestorIds ?? const <String>[],
          );
        }
      } else {
        final organization = snapshot.organizations[holderId];
        if (organization != null) {
          organizationPath = _pathOf(
            snapshot,
            kZStudyRefTypeOrganization,
            holderId,
            organization.ancestorIds,
          );
        }
      }
    }

    final period = snapshot.periods[offering.periodId];
    final periodPath = period == null
        ? const <ZStudyRef>[]
        : _pathOf(
            snapshot,
            kZStudyRefTypePeriod,
            offering.periodId,
            period.ancestorIds,
          );

    final groupRefs = <ZStudyRef>[];
    final vusGroupes = <String>{};
    for (final audience in snapshot.offeringAudiences.values) {
      if (audience.offeringId != offering.id) continue;
      if (audience.groupId.isEmpty) continue;
      if (!vusGroupes.add(audience.groupId)) continue;
      groupRefs.add(snapshot.refFor(kZStudyRefTypeGroup, audience.groupId));
    }

    final programRefs = <ZStudyRef>[];
    final vusProgrammes = <String>{};
    for (final link in snapshot.programCourses.values) {
      if (link.courseId != offering.courseId) continue;
      if (link.programId.isEmpty) continue;
      if (!vusProgrammes.add(link.programId)) continue;
      programRefs.add(snapshot.refFor(kZStudyRefTypeProgram, link.programId));
    }
    final programmeDuCurriculum = curriculum?.programId;
    if (programmeDuCurriculum != null &&
        programmeDuCurriculum.isNotEmpty &&
        vusProgrammes.add(programmeDuCurriculum)) {
      programRefs.add(
        snapshot.refFor(kZStudyRefTypeProgram, programmeDuCurriculum),
      );
    }

    final contexteSansClassification = ZStudyContext(
      organizationPath: organizationPath,
      orgUnitPath: orgUnitPath,
      programRefs: List<ZStudyRef>.unmodifiable(programRefs),
      groupRefs: List<ZStudyRef>.unmodifiable(groupRefs),
      periodPath: periodPath,
      subjectRef: subject == null
          ? null
          : snapshot.refFor(kZStudyRefTypeSubject, subjectId!),
      courseRef: course == null
          ? null
          : snapshot.refFor(kZStudyRefTypeCourse, offering.courseId),
      offeringRef: snapshot.refFor(kZStudyRefTypeOffering, offeringRef.id),
      curriculumRef: curriculum == null
          ? null
          : snapshot.refFor(kZStudyRefTypeCurriculum, offering.curriculumId!),
    );

    return Right<ZFailure, ZStudyContext>(
      contexteSansClassification.copyWith(
        classifications: _classificationsOf(
          contexteSansClassification,
          snapshot,
          at,
        ),
      ),
    );
  }

  /// Chemin racine → cible, cible incluse, chaque maillon porté en référence
  /// avec son instantané d'affichage quand la structure le connaît.
  static List<ZStudyRef> _pathOf(
    ZStudyStructureSnapshot snapshot,
    String type,
    String id,
    List<String> ancestorIds,
  ) => List<ZStudyRef>.unmodifiable(<ZStudyRef>[
    for (final ancestorId in ancestorIds) snapshot.refFor(type, ancestorId),
    snapshot.refFor(type, id),
  ]);

  static Map<String, List<String>> _classificationsOf(
    ZStudyContext context,
    ZStudyStructureSnapshot snapshot,
    DateTime? at,
  ) {
    final brut = <String, Set<String>>{};
    for (final classification in snapshot.classifications.values) {
      if (classification.vocabularyKey.isEmpty) continue;
      if (!context.contains(classification.targetRef)) continue;
      if (at != null && !classification.isActiveAt(at)) continue;
      (brut[classification.vocabularyKey] ??= <String>{})
          .add(classification.valueKey);
    }
    // Tri des valeurs : deux instantanés portant les mêmes classifications
    // dans un ordre différent doivent rendre le MÊME contexte, sans quoi une
    // matérialisation ne serait pas comparable d'une écriture à l'autre.
    final trie = <String, List<String>>{};
    for (final cle in brut.keys.toList()..sort()) {
      trie[cle] = List<String>.unmodifiable(brut[cle]!.toList()..sort());
    }
    return Map<String, List<String>>.unmodifiable(trie);
  }
}

/// `true` si [binding] atteint [context], propagation **calculée**.
///
/// C'est l'unique implémentation de la sémantique de propagation du noyau :
/// - `none` — n'atteint **rien**, pas même la cible exacte ;
/// - `exact` — atteint le contexte qui contient la cible ;
/// - `descendants` — atteint la cible **et** tout contexte dont une référence
///   de **même type** compte la cible parmi ses ancêtres. Un sous-groupe est
///   donc atteint, un cousin ne l'est pas ;
/// - `ancestors` — atteint la cible **et** tout contexte dont une référence de
///   même type figure parmi les ancêtres de la cible ;
/// - `members` — atteint la cible **et** [principalRef] s'il participe à la
///   cible. Sans mandant fourni, ce mode n'atteint que la cible ;
/// - `offerings` — atteint la cible **et** le contexte dont l'offre est portée
///   par la cible (son cours, sa période, son curriculum, son porteur ou l'un
///   de ses groupes d'audience) ;
/// - **valeur inconnue** — se comporte comme `exact` : elle n'ouvre aucune
///   propagation, mais ne renie pas la cible désignée. C'est ce qui distingue
///   « je ne sais pas étendre » de `none`, qui dit « n'étends pas ».
///
/// [at] restreint aux rattachements valides à cet instant ; omis, la validité
/// n'est pas consultée.
bool zIsVisibleFrom(
  ZStudyBinding binding,
  ZStudyContext context, {
  ZStudyStructureSnapshot snapshot = ZStudyStructureSnapshot.empty,
  ZStudyRef? principalRef,
  DateTime? at,
}) {
  if (binding.propagation == kZStudyPropagationNone) return false;
  if (at != null && !binding.isActiveAt(at)) return false;
  return _atteint(
    binding.targetRef,
    binding.propagation,
    context,
    snapshot,
    principalRef,
    at,
  );
}

/// `true` si [artifact] est visible depuis [context].
///
/// Vrai si la portée principale de l'artefact est dans le contexte, ou si un
/// de ses rattachements l'atteint au sens de [zIsVisibleFrom] — dont cette
/// fonction est un simple assembleur : elle ne réimplémente aucun cas de
/// propagation.
bool zArtifactIsVisibleFrom(
  ZStudyArtifact artifact,
  ZStudyContext context, {
  ZStudyStructureSnapshot snapshot = ZStudyStructureSnapshot.empty,
  ZStudyRef? principalRef,
  DateTime? at,
}) {
  final primary = artifact.primaryScopeRef;
  if (primary != null && context.contains(primary)) return true;
  for (final binding in artifact.bindings) {
    if (zIsVisibleFrom(
      binding,
      context,
      snapshot: snapshot,
      principalRef: principalRef,
      at: at,
    )) {
      return true;
    }
  }
  return false;
}

bool _atteint(
  ZStudyRef target,
  String propagation,
  ZStudyContext context,
  ZStudyStructureSnapshot snapshot,
  ZStudyRef? principalRef,
  DateTime? at,
) {
  if (context.contains(target)) return true;
  switch (propagation) {
    case kZStudyPropagationDescendants:
      for (final ref in context.refs) {
        if (ref.type != target.type) continue;
        if (snapshot.ancestorIdsOf(ref).contains(target.id)) return true;
      }
      return false;
    case kZStudyPropagationAncestors:
      final chaine = snapshot.ancestorIdsOf(target);
      for (final ref in context.refs) {
        if (ref.type != target.type) continue;
        if (chaine.contains(ref.id)) return true;
      }
      return false;
    case kZStudyPropagationMembers:
      if (principalRef == null) return false;
      for (final participation in snapshot.participations.values) {
        if (!participation.principalRef.sameTarget(principalRef)) continue;
        if (!participation.targetRef.sameTarget(target)) continue;
        if (at != null && !participation.isActiveAt(at)) continue;
        return true;
      }
      return false;
    case kZStudyPropagationOfferings:
      final offeringRef = context.offeringRef;
      if (offeringRef == null) return false;
      final offering = snapshot.offerings[offeringRef.id];
      if (offering == null) return false;
      return switch (target.type) {
        kZStudyRefTypeCourse => offering.courseId == target.id,
        kZStudyRefTypePeriod => offering.periodId == target.id,
        kZStudyRefTypeCurriculum => offering.curriculumId == target.id,
        kZStudyRefTypeOrganization ||
        kZStudyRefTypeOrgUnit => offering.organizationId == target.id,
        kZStudyRefTypeGroup => snapshot.offeringAudiences.values.any(
          (audience) =>
              audience.offeringId == offering.id &&
              audience.groupId == target.id,
        ),
        _ => false,
      };
    default:
      // `exact` et toute valeur inconnue : la cible seule, déjà éprouvée.
      return false;
  }
}

/// `true` si [artifact] satisfait [filter].
///
/// Sémantique, celle que `ZStudyScopeFilter` déclare : les axes se combinent en
/// **et**, les valeurs d'un axe en **ou**, un axe vide ne restreint rien. Un
/// filtre entièrement vide accepte tout.
///
/// Ne comptent que les rattachements **effectifs** : la portée principale, plus
/// les rattachements dont la propagation n'est pas `none` — et, si [at] est
/// fourni, valides à cet instant. Un rattachement neutralisé ne fait donc
/// jamais entrer un artefact dans un filtre.
///
/// [ZStudyScopeFilter.includeDescendants] étend chaque portée à ses
/// descendants : un artefact rattaché à un sous-groupe satisfait un filtre
/// portant sur le groupe parent. L'extension se lit dans [snapshot] et n'a
/// d'effet que sur les portées dont l'instantané connaît l'arbre.
bool zMatchesScopeFilter(
  ZStudyArtifact artifact,
  ZStudyScopeFilter filter, {
  ZStudyStructureSnapshot snapshot = ZStudyStructureSnapshot.empty,
  DateTime? at,
}) {
  if (filter.isEmpty) return true;
  final effectives = _porteesEffectives(artifact, at);

  if (filter.scopes.isNotEmpty) {
    var trouve = false;
    for (final scope in filter.scopes) {
      if (_toucheLaPortee(
        effectives,
        scope,
        snapshot,
        filter.includeDescendants,
      )) {
        trouve = true;
        break;
      }
    }
    if (!trouve) return false;
  }

  return _axe(effectives, kZStudyRefTypePeriod, filter.periodIds) &&
      _axe(effectives, kZStudyRefTypeSubject, filter.subjectIds) &&
      _axe(effectives, kZStudyRefTypeCourse, filter.courseIds) &&
      _axe(effectives, kZStudyRefTypeTopic, filter.topicIds) &&
      _axe(effectives, kZStudyRefTypeOffering, filter.offeringIds);
}

List<ZStudyRef> _porteesEffectives(ZStudyArtifact artifact, DateTime? at) {
  final out = <ZStudyRef>[];
  final primary = artifact.primaryScopeRef;
  if (primary != null) out.add(primary);
  for (final binding in artifact.bindings) {
    if (binding.propagation == kZStudyPropagationNone) continue;
    if (at != null && !binding.isActiveAt(at)) continue;
    out.add(binding.targetRef);
  }
  return out;
}

bool _toucheLaPortee(
  List<ZStudyRef> effectives,
  ZStudyRef scope,
  ZStudyStructureSnapshot snapshot,
  bool includeDescendants,
) {
  for (final ref in effectives) {
    if (ref.sameTarget(scope)) return true;
    if (!includeDescendants) continue;
    if (ref.type != scope.type) continue;
    if (snapshot.ancestorIdsOf(ref).contains(scope.id)) return true;
  }
  return false;
}

bool _axe(List<ZStudyRef> effectives, String type, List<String> ids) {
  if (ids.isEmpty) return true;
  for (final ref in effectives) {
    if (ref.type == type && ids.contains(ref.id)) return true;
  }
  return false;
}
