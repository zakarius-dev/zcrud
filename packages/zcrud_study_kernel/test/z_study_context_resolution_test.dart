// Garde de RÉSOLUTION DE CONTEXTE — cinq contextes d'étude irréconciliables,
// résolus par la MÊME primitive, avec la sortie attendue FIGÉE EN LITTÉRAL.
//
// C'est la garde qui rend la doctrine vérifiable. Le noyau prétend qu'un seul
// jeu d'entités décrit des organisations pédagogiques qui n'ont rien en commun.
// La seule preuve honnête est de le faire tourner sur cinq d'entre elles et
// d'exiger, à chaque fois, une sortie EXACTE — pas « contient », pas « au
// moins » : l'égalité stricte d'une map complète. Une assertion relative
// laisserait passer exactement le défaut qu'on surveille (un axe résolu en
// trop, ou un axe silencieusement vide).
//
// Les cinq :
//   1. secondaire      — porteur = UNITÉ d'organisation, arbre de périodes
//   2. supérieur       — porteur = ORGANISATION imbriquée, programme par
//                        curriculum, matière héritée du curriculum
//   3. formation courte — aucun porteur sur l'offre, deux groupes, période
//                        inconnue de l'instantané
//   4. primaire        — sous-groupe, arbre de périodes à trois niveaux,
//                        classifications agrégées et triées
//   5. mode personnel  — aucune organisation, instantané minimal
//
// La trace comparée est volontairement COMPACTE (`type:id`) pour rester
// lisible : un littéral figé illisible se fait tamponner sans être lu. Les
// instantanés d'affichage (libellés) sont assertés à part, dans leur propre
// test.

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const ZStudyContextResolver _resolveur = ZStudyContextResolver();

/// Projection compacte et TOTALE d'un contexte : chaque axe y figure, y compris
/// vide. Un axe omis ne pourrait pas être surveillé.
Map<String, Object> _trace(ZStudyContext c) => <String, Object>{
  'organizationPath': _ids(c.organizationPath),
  'orgUnitPath': _ids(c.orgUnitPath),
  'programRefs': _ids(c.programRefs),
  'groupRefs': _ids(c.groupRefs),
  'periodPath': _ids(c.periodPath),
  'subjectRef': _id(c.subjectRef),
  'courseRef': _id(c.courseRef),
  'offeringRef': _id(c.offeringRef),
  'curriculumRef': _id(c.curriculumRef),
  'classifications': c.classifications,
};

List<String> _ids(List<ZStudyRef> refs) => <String>[
  for (final ref in refs) '${ref.type}:${ref.id}',
];

String _id(ZStudyRef? ref) => ref == null ? '' : '${ref.type}:${ref.id}';

/// Résout, ou fait échouer le test en nommant la raison — jamais de `!` muet.
ZStudyContext _resoudre(
  ZStudyStructureSnapshot snapshot,
  String offeringId, {
  DateTime? at,
}) => _resolveur
    .resolve(
      ZStudyRef(type: kZStudyRefTypeOffering, id: offeringId),
      snapshot,
      at: at,
    )
    .fold<ZStudyContext>((ZFailure f) {
      fail('résolution refusée : ${f.message}');
    }, (ZStudyContext c) => c);

// ---------------------------------------------------------------------------
// 1. Secondaire — le porteur de l'offre est une UNITÉ d'organisation
// ---------------------------------------------------------------------------

final ZStudyStructureSnapshot _secondaire = ZStudyStructureSnapshot(
  organizations: const <String, ZStudyOrganization>{
    'o1': ZStudyOrganization(id: 'o1', kind: 'zzKindLocal', label: 'Siège'),
  },
  orgUnits: const <String, ZStudyOrgUnit>{
    'u1': ZStudyOrgUnit(
      id: 'u1',
      organizationId: 'o1',
      kind: 'zzUniteLocale',
      label: 'Pôle sciences',
    ),
  },
  groups: const <String, ZStudyGroup>{
    'g1': ZStudyGroup(id: 'g1', organizationId: 'o1', label: 'Cohorte A'),
  },
  programs: const <String, ZStudyProgram>{
    'pr1': ZStudyProgram(id: 'pr1', organizationId: 'o1', label: 'Cursus S'),
  },
  programCourses: const <String, ZStudyProgramCourse>{
    'pc1': ZStudyProgramCourse(id: 'pc1', programId: 'pr1', courseId: 'c1'),
  },
  subjects: const <String, ZStudySubject>{
    's1': ZStudySubject(id: 's1', label: 'Mathématiques'),
  },
  courses: const <String, ZStudyCourse>{
    'c1': ZStudyCourse(id: 'c1', subjectId: 's1', label: 'Maths — noyau'),
  },
  periods: const <String, ZStudyPeriod>{
    'pAn': ZStudyPeriod(id: 'pAn', label: 'Cycle 2026'),
    'pT2': ZStudyPeriod(
      id: 'pT2',
      parentId: 'pAn',
      label: 'Bloc 2',
      ancestorIds: <String>['pAn'],
    ),
  },
  offerings: const <String, ZStudyOffering>{
    'off1': ZStudyOffering(
      id: 'off1',
      organizationId: 'u1',
      courseId: 'c1',
      periodId: 'pT2',
    ),
  },
  offeringAudiences: const <String, ZStudyOfferingAudience>{
    'a1': ZStudyOfferingAudience(id: 'a1', offeringId: 'off1', groupId: 'g1'),
  },
  classifications: const <String, ZStudyClassification>{
    'cl1': ZStudyClassification(
      id: 'cl1',
      targetRef: ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1'),
      vocabularyKey: 'zzNiveauLocal',
      valueKey: 'n3',
    ),
  },
);

const Map<String, Object> _attenduSecondaire = <String, Object>{
  'organizationPath': <String>['organization:o1'],
  'orgUnitPath': <String>['orgUnit:u1'],
  'programRefs': <String>['program:pr1'],
  'groupRefs': <String>['group:g1'],
  'periodPath': <String>['period:pAn', 'period:pT2'],
  'subjectRef': 'subject:s1',
  'courseRef': 'course:c1',
  'offeringRef': 'offering:off1',
  'curriculumRef': '',
  'classifications': <String, List<String>>{
    'zzNiveauLocal': <String>['n3'],
  },
};

// ---------------------------------------------------------------------------
// 2. Supérieur — porteur = ORGANISATION imbriquée ; programme et matière
//    viennent du curriculum, pas du cours
// ---------------------------------------------------------------------------

final ZStudyStructureSnapshot _superieur = ZStudyStructureSnapshot(
  organizations: const <String, ZStudyOrganization>{
    'oRac': ZStudyOrganization(id: 'oRac', label: 'Ensemble'),
    'oSub': ZStudyOrganization(
      id: 'oSub',
      parentId: 'oRac',
      label: 'Composante',
      ancestorIds: <String>['oRac'],
    ),
  },
  programs: const <String, ZStudyProgram>{
    'pr2': ZStudyProgram(id: 'pr2', label: 'Cursus L'),
  },
  subjects: const <String, ZStudySubject>{
    's2': ZStudySubject(id: 's2', label: 'Droit'),
  },
  // Le cours ne déclare AUCUNE matière : elle doit venir du curriculum.
  courses: const <String, ZStudyCourse>{
    'c2': ZStudyCourse(id: 'c2', label: 'Introduction'),
  },
  periods: const <String, ZStudyPeriod>{
    'pS1': ZStudyPeriod(id: 'pS1', label: 'Bloc initial'),
  },
  offerings: const <String, ZStudyOffering>{
    'off2': ZStudyOffering(
      id: 'off2',
      organizationId: 'oSub',
      courseId: 'c2',
      periodId: 'pS1',
      curriculumId: 'cur2',
    ),
  },
  curricula: const <String, ZStudyCurriculum>{
    'cur2': ZStudyCurriculum(
      id: 'cur2',
      subjectId: 's2',
      programId: 'pr2',
      label: 'Progression 2026',
      version: 'zzVersionOpaque',
    ),
  },
);

const Map<String, Object> _attenduSuperieur = <String, Object>{
  'organizationPath': <String>['organization:oRac', 'organization:oSub'],
  'orgUnitPath': <String>[],
  'programRefs': <String>['program:pr2'],
  'groupRefs': <String>[],
  'periodPath': <String>['period:pS1'],
  'subjectRef': 'subject:s2',
  'courseRef': 'course:c2',
  'offeringRef': 'offering:off2',
  'curriculumRef': 'curriculum:cur2',
  'classifications': <String, List<String>>{},
};

// ---------------------------------------------------------------------------
// 3. Formation courte — aucun porteur sur l'offre (il remonte du cours),
//    deux groupes, période ABSENTE de l'instantané
// ---------------------------------------------------------------------------

final ZStudyStructureSnapshot _formationCourte = ZStudyStructureSnapshot(
  organizations: const <String, ZStudyOrganization>{
    'oBc': ZStudyOrganization(id: 'oBc', label: 'Atelier'),
  },
  groups: const <String, ZStudyGroup>{
    'gA': ZStudyGroup(id: 'gA', label: 'Vague A'),
    'gB': ZStudyGroup(id: 'gB', label: 'Vague B'),
  },
  courses: const <String, ZStudyCourse>{
    'c3': ZStudyCourse(id: 'c3', organizationId: 'oBc', label: 'Intensif'),
  },
  offerings: const <String, ZStudyOffering>{
    // Ni porteur, ni curriculum ; la période désignée n'existe pas.
    'off3': ZStudyOffering(id: 'off3', courseId: 'c3', periodId: 'pInconnue'),
  },
  offeringAudiences: const <String, ZStudyOfferingAudience>{
    'a2': ZStudyOfferingAudience(id: 'a2', offeringId: 'off3', groupId: 'gA'),
    'a3': ZStudyOfferingAudience(id: 'a3', offeringId: 'off3', groupId: 'gB'),
    // Audience d'une AUTRE offre : ne doit pas entrer dans ce contexte.
    'a4': ZStudyOfferingAudience(id: 'a4', offeringId: 'off9', groupId: 'gZ'),
  },
);

const Map<String, Object> _attenduFormationCourte = <String, Object>{
  'organizationPath': <String>['organization:oBc'],
  'orgUnitPath': <String>[],
  'programRefs': <String>[],
  'groupRefs': <String>['group:gA', 'group:gB'],
  'periodPath': <String>[],
  'subjectRef': '',
  'courseRef': 'course:c3',
  'offeringRef': 'offering:off3',
  'curriculumRef': '',
  'classifications': <String, List<String>>{},
};

// ---------------------------------------------------------------------------
// 4. Primaire — sous-groupe, arbre de périodes à trois niveaux,
//    classifications agrégées, dédoublonnées et triées
// ---------------------------------------------------------------------------

final ZStudyStructureSnapshot _primaire = ZStudyStructureSnapshot(
  organizations: const <String, ZStudyOrganization>{
    'oP': ZStudyOrganization(id: 'oP', label: 'Structure'),
  },
  groups: const <String, ZStudyGroup>{
    'gPar': ZStudyGroup(id: 'gPar', label: 'Ensemble'),
    'gEnf': ZStudyGroup(
      id: 'gEnf',
      parentGroupId: 'gPar',
      label: 'Sous-ensemble',
      ancestorIds: <String>['gPar'],
    ),
    'gAutre': ZStudyGroup(id: 'gAutre', label: 'Hors contexte'),
  },
  subjects: const <String, ZStudySubject>{
    's4': ZStudySubject(id: 's4', label: 'Langue'),
  },
  courses: const <String, ZStudyCourse>{
    'c4': ZStudyCourse(id: 'c4', organizationId: 'oP', subjectId: 's4'),
  },
  periods: const <String, ZStudyPeriod>{
    'pY': ZStudyPeriod(id: 'pY', label: 'Haut'),
    'pT': ZStudyPeriod(
      id: 'pT',
      parentId: 'pY',
      label: 'Milieu',
      ancestorIds: <String>['pY'],
    ),
    'pW': ZStudyPeriod(
      id: 'pW',
      parentId: 'pT',
      label: 'Bas',
      ancestorIds: <String>['pY', 'pT'],
    ),
  },
  offerings: const <String, ZStudyOffering>{
    'off4': ZStudyOffering(id: 'off4', courseId: 'c4', periodId: 'pW'),
  },
  offeringAudiences: const <String, ZStudyOfferingAudience>{
    'a5': ZStudyOfferingAudience(id: 'a5', offeringId: 'off4', groupId: 'gEnf'),
  },
  classifications: const <String, ZStudyClassification>{
    // Deux valeurs du MÊME vocabulaire, déclarées dans le désordre.
    'k1': ZStudyClassification(
      id: 'k1',
      targetRef: ZStudyRef(type: kZStudyRefTypeCourse, id: 'c4'),
      vocabularyKey: 'zzCycle',
      valueKey: 'c2',
    ),
    'k2': ZStudyClassification(
      id: 'k2',
      targetRef: ZStudyRef(type: kZStudyRefTypeCourse, id: 'c4'),
      vocabularyKey: 'zzCycle',
      valueKey: 'c1',
    ),
    'k3': ZStudyClassification(
      id: 'k3',
      targetRef: ZStudyRef(type: kZStudyRefTypeGroup, id: 'gEnf'),
      vocabularyKey: 'zzAptitude',
      valueKey: 'a1',
    ),
    // Cible HORS contexte : ne doit jamais remonter.
    'k4': ZStudyClassification(
      id: 'k4',
      targetRef: ZStudyRef(type: kZStudyRefTypeGroup, id: 'gAutre'),
      vocabularyKey: 'zzAptitude',
      valueKey: 'zzJamaisVisible',
    ),
  },
);

const Map<String, Object> _attenduPrimaire = <String, Object>{
  'organizationPath': <String>['organization:oP'],
  'orgUnitPath': <String>[],
  'programRefs': <String>[],
  'groupRefs': <String>['group:gEnf'],
  'periodPath': <String>['period:pY', 'period:pT', 'period:pW'],
  'subjectRef': 'subject:s4',
  'courseRef': 'course:c4',
  'offeringRef': 'offering:off4',
  'curriculumRef': '',
  'classifications': <String, List<String>>{
    'zzAptitude': <String>['a1'],
    'zzCycle': <String>['c1', 'c2'],
  },
};

// ---------------------------------------------------------------------------
// 5. Mode personnel — aucune organisation, instantané minimal
// ---------------------------------------------------------------------------

const ZStudyStructureSnapshot _personnel = ZStudyStructureSnapshot(
  offerings: <String, ZStudyOffering>{
    'off5': ZStudyOffering(id: 'off5'),
  },
);

const Map<String, Object> _attenduPersonnel = <String, Object>{
  'organizationPath': <String>[],
  'orgUnitPath': <String>[],
  'programRefs': <String>[],
  'groupRefs': <String>[],
  'periodPath': <String>[],
  'subjectRef': '',
  'courseRef': '',
  'offeringRef': 'offering:off5',
  'curriculumRef': '',
  'classifications': <String, List<String>>{},
};

void main() {
  group('Résolution de contexte — cinq contextes, une seule primitive', () {
    test('1. secondaire : le porteur est une UNITÉ, résolue comme telle', () {
      expect(_trace(_resoudre(_secondaire, 'off1')), equals(_attenduSecondaire));
    });

    test('2. supérieur : porteur ORGANISATION, matière et programme hérités '
        'du curriculum', () {
      expect(_trace(_resoudre(_superieur, 'off2')), equals(_attenduSuperieur));
    });

    test('3. formation courte : porteur remonté du cours, période absente '
        'de l\'instantané', () {
      expect(
        _trace(_resoudre(_formationCourte, 'off3')),
        equals(_attenduFormationCourte),
      );
    });

    test('4. primaire : sous-groupe, arbre à trois niveaux, classifications '
        'triées', () {
      expect(_trace(_resoudre(_primaire, 'off4')), equals(_attenduPrimaire));
    });

    test('5. mode personnel : aucune organisation, et c\'est une réponse', () {
      expect(_trace(_resoudre(_personnel, 'off5')), equals(_attenduPersonnel));
    });
  });

  group('Contrat de la résolution', () {
    test('une offre absente de l\'instantané est le SEUL échec possible', () {
      final resultat = _resolveur.resolve(
        const ZStudyRef(type: kZStudyRefTypeOffering, id: 'introuvable'),
        _secondaire,
      );
      expect(
        resultat.fold<bool>((ZFailure f) => f is ZNotFoundFailure, (_) => false),
        isTrue,
      );
    });

    test('un instantané VIDE ne fait pas échouer une offre connue', () {
      // Contre-épreuve de l'axiome « absence valide » : tout ce qui manque
      // devient vide, rien ne lève, rien ne refuse.
      final contexte = _resoudre(_personnel, 'off5');
      expect(contexte.isEmpty, isFalse); // l'offre elle-même reste prouvée
      expect(contexte.organizationPath, isEmpty);
      expect(contexte.classifications, isEmpty);
    });

    test('la résolution est DÉTERMINISTE : deux appels rendent le même '
        'contexte', () {
      expect(_resoudre(_primaire, 'off4'), equals(_resoudre(_primaire, 'off4')));
    });

    test('le contexte porte les instantanés d\'affichage de la structure', () {
      final contexte = _resoudre(_secondaire, 'off1');
      expect(contexte.orgUnitPath.single.label, equals('Pôle sciences'));
      expect(contexte.periodPath.first.label, equals('Cycle 2026'));
      expect(contexte.periodPath.last.label, equals('Bloc 2'));
      expect(contexte.subjectRef?.label, equals('Mathématiques'));
    });

    test('une référence dont l\'instantané ignore la cible garde son identité '
        'et n\'invente aucun libellé', () {
      // `gZ` n'existe dans aucune map : la résolution ne doit pas le fabriquer.
      final contexte = _resoudre(_formationCourte, 'off3');
      expect(contexte.groupRefs.map((ZStudyRef r) => r.id), <String>['gA', 'gB']);
      expect(
        _resoudre(_formationCourte, 'off3').courseRef?.label,
        equals('Intensif'),
      );
    });

    test('`at` restreint les classifications aux seules actives', () {
      final snapshot = ZStudyStructureSnapshot(
        courses: const <String, ZStudyCourse>{'c': ZStudyCourse(id: 'c')},
        offerings: const <String, ZStudyOffering>{
          'o': ZStudyOffering(id: 'o', courseId: 'c'),
        },
        classifications: <String, ZStudyClassification>{
          'expiree': ZStudyClassification(
            id: 'expiree',
            targetRef: const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c'),
            vocabularyKey: 'v',
            valueKey: 'ancienne',
            validTo: DateTime.utc(2026),
          ),
          'courante': ZStudyClassification(
            id: 'courante',
            targetRef: const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c'),
            vocabularyKey: 'v',
            valueKey: 'nouvelle',
            validFrom: DateTime.utc(2026),
          ),
        },
      );
      // Sans instant : aucune restriction de date, les deux remontent.
      expect(_resoudre(snapshot, 'o').classifications['v'], <String>[
        'ancienne',
        'nouvelle',
      ]);
      // Avec un instant : la borne haute est EXCLUE, la bascule est nette.
      expect(
        _resoudre(snapshot, 'o', at: DateTime.utc(2026)).classifications['v'],
        <String>['nouvelle'],
      );
    });
  });

  group('ZStudyContext — read model matérialisable', () {
    test('round-trip par toMap/fromMap, axes vides compris', () {
      final contexte = _resoudre(_primaire, 'off4');
      expect(ZStudyContext.fromMap(contexte.toMap()), equals(contexte));
    });

    test('un axe vide n\'écrit AUCUNE clé', () {
      final map = _resoudre(_personnel, 'off5').toMap();
      expect(map.keys, contains('offering_ref'));
      for (final absente in <String>[
        'organization_path',
        'org_unit_path',
        'program_refs',
        'group_refs',
        'period_path',
        'subject_ref',
        'course_ref',
        'curriculum_ref',
        'classifications',
      ]) {
        expect(map.keys, isNot(contains(absente)));
      }
    });

    test('fromMap d\'une map corrompue ne lève pas et rend un contexte vide',
        () {
      final relu = ZStudyContext.fromMap(<String, dynamic>{
        'organization_path': 'pas une liste',
        'group_refs': 42,
        'subject_ref': <String>['pas une map'],
        'classifications': 'pas une map',
      });
      expect(relu.isEmpty, isTrue);
    });

    test('`refs` dédoublonne et garde un ordre stable', () {
      const doublon = ZStudyRef(type: kZStudyRefTypeGroup, id: 'g');
      const contexte = ZStudyContext(
        groupRefs: <ZStudyRef>[doublon, doublon],
        organizationPath: <ZStudyRef>[
          ZStudyRef(type: kZStudyRefTypeOrganization, id: 'o'),
        ],
      );
      expect(_ids(contexte.refs), <String>['organization:o', 'group:g']);
    });

    test('`contains` compare l\'identité SEULE, pas l\'instantané', () {
      const contexte = ZStudyContext(
        groupRefs: <ZStudyRef>[
          ZStudyRef(type: kZStudyRefTypeGroup, id: 'g', label: 'Un libellé'),
        ],
      );
      expect(
        contexte.contains(
          const ZStudyRef(type: kZStudyRefTypeGroup, id: 'g', label: 'Un autre'),
        ),
        isTrue,
      );
    });
  });
}
