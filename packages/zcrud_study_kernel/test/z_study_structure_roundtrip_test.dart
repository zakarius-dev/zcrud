// Gardes de contrat de (dé)sérialisation des types de structure d'étude.
//
// Quatre propriétés, vérifiées pour CHAQUE entité principale :
//
// 1. ROUND-TRIP DE L'INCONNU — un `kind`, un rôle, un statut, une propagation
//    ou une clé de vocabulaire que le noyau ne connaît pas doit ressortir
//    INTACT. C'est la propriété qui rend le vocabulaire ouvert réel : si le
//    décodeur normalisait vers une valeur connue, tout contexte non prévu
//    perdrait ses données au premier aller-retour.
// 2. POINT FIXE — sérialiser deux fois donne la même map. Une entité relue du
//    store et réécrite ne doit pas dériver.
// 3. CLÉS RÉSERVÉES — `updated_at`/`is_deleted` (préoccupations de store) ne
//    tombent jamais dans `extra` et ne sont jamais réémis ; une clé inconnue,
//    elle, est préservée.
// 4. DÉRIVE SCHÉMA ↔ MAP — chaque nom de `$…FieldSpecs` est bien une clé de la
//    map d'une entité complète. Un champ ajouté au modèle sans émission (ou
//    l'inverse) est un défaut silencieux : le formulaire dérivé montrerait un
//    champ que le store ne verrait jamais.
//
// Et pour chaque type : `fromMap` d'une map CORROMPUE ne lève jamais et rend
// les défauts documentés (invariant AD-10).

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Valeurs de vocabulaire volontairement inconnues du noyau.
const String _kindInconnu = 'zzKindQueLeNoyauNeConnaitPas';
const String _statutInconnu = 'zzStatutQueLeNoyauNeConnaitPas';
const String _roleInconnu = 'zzRoleQueLeNoyauNeConnaitPas';
const String _propagationInconnue = 'zzPropagationQueLeNoyauNeConnaitPas';
const String _vocabulaireInconnu = 'zzVocabulaireInconnu';
const String _valeurInconnue = 'zzValeurInconnue';

/// Map corrompue : chaque valeur a le mauvais type.
const Map<String, dynamic> _corrompue = <String, dynamic>{
  'id': 42,
  'kind': <String>['pas une chaîne'],
  'label': 7,
  'code': <String, dynamic>{},
  'status': 3.14,
  'parent_id': true,
  'parent_group_id': true,
  'organization_id': <int>[1],
  'workspace_id': 1,
  'calendar_id': 1,
  'subject_id': 1,
  'offering_id': 1,
  'program_id': 1,
  'course_id': 1,
  'ancestor_ids': 'pas une liste',
  'external_refs': 'pas une liste',
  'topic_refs': 12,
  'location_ref': 'pas une map',
  'target_ref': 5,
  'classification_constraints': <String>['pas des maps'],
  'starts_at': 'pas une date',
  'ends_at': <String>[],
  'valid_from': 12,
  'valid_to': <int>[],
  'archived_at': 'nope',
  'order': 'pas un entier',
  'credits': 'pas un nombre',
  'coefficient': <String>[],
  'expected_hours': <String>[],
  'is_required': 'pas un booléen',
  'timezone': 5,
  'meeting_url': 9,
  'avatar_key': 9,
  'owner_principal_id': 9,
  'vocabulary_key': 9,
  'value_key': 9,
  'period_id': 9,
  'credential_kind': 9,
  'duration': 9,
  'curriculum_id': <int>[],
  'group_id': 3.5,
  'role': <String>['pas une chaîne'],
  'role_key': 4,
  'principal_ref': 'pas une map',
  'scope_ref': <String>['pas une map'],
  'artifact_ref': 7,
  'grantee_ref': false,
  'access_key': <int>[9],
  'inheritance': 2,
  'framework_id': <String, dynamic>{},
  'description': 6,
  'version': <int>[1],
  'effective_from': 'pas une date',
  'effective_to': <String>[],
  'expected_duration': 4,
  'weight': 'pas un nombre',
  'folder_id': 2,
  'content': <String>['pas une chaîne'],
  'style': 5,
  'operation': <int>[],
  'related_topics': 'pas une liste',
  'created_at': <String>[],
  'extension': 'pas une map',
};

/// Décrit un type principal : comment le construire complet, le sérialiser, le
/// relire, et quel schéma généré il déclare.
class _Cas<T> {
  const _Cas(this.nom, this.complet, this.toMap, this.fromMap, this.specs);

  final String nom;
  final T complet;
  final Map<String, dynamic> Function(T value) toMap;
  final T Function(Map<String, dynamic> map) fromMap;
  final List<ZFieldSpec> specs;

  // Chaque propriété est un test SÉPARÉ : groupées, la première assertion
  // rouge masquerait les suivantes, et on ne saurait plus laquelle mord.

  /// 1. round-trip : l'entité relue est égale à l'entité écrite.
  void verifierRoundTrip() {
    expect(
      fromMap(toMap(complet)),
      equals(complet),
      reason: '$nom : round-trip perdu',
    );
  }

  /// 2. point fixe : réécrire la relecture donne exactement la même map.
  void verifierPointFixe() {
    final map = toMap(complet);
    expect(
      toMap(fromMap(map)),
      equals(map),
      reason: '$nom : la sérialisation dérive au second tour',
    );
  }

  /// 4. dérive schéma ↔ map : tout champ déclaré est émis par une entité
  /// complète.
  void verifierSchema() {
    final map = toMap(complet);
    for (final spec in specs) {
      expect(
        map.keys,
        contains(spec.name),
        reason: '$nom : le champ « ${spec.name} » est déclaré mais non émis',
      );
    }
  }

  void verifierClesReservees() {
    final pollue = <String, dynamic>{
      ...toMap(complet),
      'updated_at': '2026-01-01T00:00:00.000Z',
      'is_deleted': true,
      'zz_cle_inconnue': 'préservée',
    };
    final relu = fromMap(pollue);
    final remis = toMap(relu);

    expect(
      remis.keys,
      isNot(contains('is_deleted')),
      reason: '$nom : une clé de suppression logique a fui dans le domaine',
    );
    expect(
      remis['zz_cle_inconnue'],
      equals('préservée'),
      reason: '$nom : une clé inconnue a été détruite au round-trip',
    );
  }

  void verifierCorruption() {
    // Ne lève jamais (AD-10) : c'est la seule assertion possible ici, et elle
    // est vérifiée par le fait qu'aucune exception ne remonte.
    final relu = fromMap(Map<String, dynamic>.of(_corrompue));
    // Et la valeur obtenue est réécrivable : le repli produit un état complet,
    // pas un objet à moitié construit.
    expect(() => toMap(relu), returnsNormally, reason: '$nom : repli bancal');
  }
}

List<_Cas<Object?>> _cas() => <_Cas<Object?>>[
  _Cas<ZStudyWorkspace>(
    'ZStudyWorkspace',
    const ZStudyWorkspace(
      id: 'w1',
      kind: _kindInconnu,
      label: 'Espace',
      ownerPrincipalId: 'p1',
      externalRefs: <ZExternalRef>[
        ZExternalRef(system: 'sis', type: 'guid', value: 'X-1'),
      ],
      extra: <String, dynamic>{'zz_libre': 1},
    ),
    (ZStudyWorkspace v) => v.toMap(),
    ZStudyWorkspace.fromMap,
    $ZStudyWorkspaceFieldSpecs,
  ),
  _Cas<ZStudyPrincipal>(
    'ZStudyPrincipal',
    const ZStudyPrincipal(
      id: 'p1',
      kind: _kindInconnu,
      label: 'Personne',
      avatarKey: 'av',
      externalRefs: <ZExternalRef>[
        ZExternalRef(system: 'annuaire', value: 'A-1'),
      ],
    ),
    (ZStudyPrincipal v) => v.toMap(),
    ZStudyPrincipal.fromMap,
    $ZStudyPrincipalFieldSpecs,
  ),
  _Cas<ZStudyOrganization>(
    'ZStudyOrganization',
    const ZStudyOrganization(
      id: 'o1',
      workspaceId: 'w1',
      parentId: 'o0',
      kind: _kindInconnu,
      label: 'Org',
      code: 'ORG',
      ancestorIds: <String>['root', 'o0'],
    ),
    (ZStudyOrganization v) => v.toMap(),
    ZStudyOrganization.fromMap,
    $ZStudyOrganizationFieldSpecs,
  ),
  _Cas<ZStudyOrgUnit>(
    'ZStudyOrgUnit',
    const ZStudyOrgUnit(
      id: 'u1',
      organizationId: 'o1',
      parentId: 'u0',
      kind: _kindInconnu,
      label: 'Unité',
      code: 'U',
      ancestorIds: <String>['u0'],
    ),
    (ZStudyOrgUnit v) => v.toMap(),
    ZStudyOrgUnit.fromMap,
    $ZStudyOrgUnitFieldSpecs,
  ),
  _Cas<ZStudyProgram>(
    'ZStudyProgram',
    const ZStudyProgram(
      id: 'pr1',
      organizationId: 'o1',
      parentId: 'pr0',
      kind: _kindInconnu,
      code: 'PR',
      label: 'Programme',
      credentialKind: 'zzCertificationInconnue',
      duration: 'P3Y',
      ancestorIds: <String>['pr0'],
    ),
    (ZStudyProgram v) => v.toMap(),
    ZStudyProgram.fromMap,
    $ZStudyProgramFieldSpecs,
  ),
  _Cas<ZStudyGroup>(
    'ZStudyGroup',
    const ZStudyGroup(
      id: 'g1',
      organizationId: 'o1',
      parentGroupId: 'g0',
      kind: _kindInconnu,
      label: 'Groupe',
      code: 'G',
      status: _statutInconnu,
      ancestorIds: <String>['g0'],
    ),
    (ZStudyGroup v) => v.toMap(),
    ZStudyGroup.fromMap,
    $ZStudyGroupFieldSpecs,
  ),
  _Cas<ZStudyClassification>(
    'ZStudyClassification',
    ZStudyClassification(
      id: 'c1',
      targetRef: const ZStudyRef(
        type: kZStudyRefTypeGroup,
        id: 'g1',
        label: 'Groupe',
        code: 'G',
        kind: _kindInconnu,
      ),
      vocabularyKey: _vocabulaireInconnu,
      valueKey: _valeurInconnue,
      periodId: 'per1',
      validFrom: DateTime.utc(2026, 9),
      validTo: DateTime.utc(2027, 6),
    ),
    (ZStudyClassification v) => v.toMap(),
    ZStudyClassification.fromMap,
    $ZStudyClassificationFieldSpecs,
  ),
  _Cas<ZStudySubject>(
    'ZStudySubject',
    const ZStudySubject(
      id: 's1',
      organizationId: 'o1',
      kind: _kindInconnu,
      code: 'S',
      label: 'Matière',
      colorKey: 'blue',
    ),
    (ZStudySubject v) => v.toMap(),
    ZStudySubject.fromMap,
    $ZStudySubjectFieldSpecs,
  ),
  _Cas<ZStudyCourse>(
    'ZStudyCourse',
    const ZStudyCourse(
      id: 'co1',
      organizationId: 'o1',
      subjectId: 's1',
      kind: _kindInconnu,
      code: 'CO',
      label: 'Cours',
      credits: 3,
      expectedHours: 24,
    ),
    (ZStudyCourse v) => v.toMap(),
    ZStudyCourse.fromMap,
    $ZStudyCourseFieldSpecs,
  ),
  _Cas<ZStudyProgramCourse>(
    'ZStudyProgramCourse',
    const ZStudyProgramCourse(
      id: 'pc1',
      programId: 'pr1',
      courseId: 'co1',
      periodPattern: 'zzMotifInconnu',
      classificationConstraints: <ZStudyClassificationConstraint>[
        ZStudyClassificationConstraint(
          vocabularyKey: _vocabulaireInconnu,
          valueKey: _valeurInconnue,
        ),
      ],
      isRequired: true,
      credits: 6,
      coefficient: 2,
      order: 3,
    ),
    (ZStudyProgramCourse v) => v.toMap(),
    ZStudyProgramCourse.fromMap,
    $ZStudyProgramCourseFieldSpecs,
  ),
  _Cas<ZStudyCalendar>(
    'ZStudyCalendar',
    const ZStudyCalendar(
      id: 'cal1',
      organizationId: 'o1',
      timezone: 'Europe/Paris',
      label: 'Calendrier',
      kind: _kindInconnu,
    ),
    (ZStudyCalendar v) => v.toMap(),
    ZStudyCalendar.fromMap,
    $ZStudyCalendarFieldSpecs,
  ),
  _Cas<ZStudyPeriod>(
    'ZStudyPeriod',
    ZStudyPeriod(
      id: 'per1',
      calendarId: 'cal1',
      parentId: 'per0',
      kind: _kindInconnu,
      code: 'P',
      label: 'Période',
      startsAt: DateTime.utc(2026, 9),
      endsAt: DateTime.utc(2027, 6),
      order: 1,
      ancestorIds: const <String>['per0'],
    ),
    (ZStudyPeriod v) => v.toMap(),
    ZStudyPeriod.fromMap,
    $ZStudyPeriodFieldSpecs,
  ),
  _Cas<ZStudySession>(
    'ZStudySession',
    ZStudySession(
      id: 'se1',
      offeringId: 'off1',
      startsAt: DateTime.utc(2026, 9, 1, 8),
      endsAt: DateTime.utc(2026, 9, 1, 10),
      kind: _kindInconnu,
      locationRef: const ZStudyRef(type: 'zzTypeInconnu', id: 'salle-1'),
      meetingUrl: 'https://example.invalid/x',
      topicRefs: const <ZStudyRef>[
        ZStudyRef(type: kZStudyRefTypeTopic, id: 't1'),
      ],
    ),
    (ZStudySession v) => v.toMap(),
    ZStudySession.fromMap,
    $ZStudySessionFieldSpecs,
  ),
  // ------------------------------------------------------------------ A2
  _Cas<ZStudyOffering>(
    'ZStudyOffering',
    const ZStudyOffering(
      id: 'off1',
      organizationId: 'u1',
      courseId: 'c1',
      periodId: 'per1',
      curriculumId: 'cur1',
      label: 'Offre',
      code: 'OFF',
      status: _statutInconnu,
      externalRefs: <ZExternalRef>[
        ZExternalRef(system: 'sis', type: 'guid', value: 'O-1'),
      ],
      extra: <String, dynamic>{'zz_libre': true},
    ),
    (ZStudyOffering v) => v.toMap(),
    ZStudyOffering.fromMap,
    $ZStudyOfferingFieldSpecs,
  ),
  _Cas<ZStudyOfferingAudience>(
    'ZStudyOfferingAudience',
    const ZStudyOfferingAudience(
      id: 'aud1',
      offeringId: 'off1',
      groupId: 'g1',
      role: _roleInconnu,
      externalRefs: <ZExternalRef>[ZExternalRef(system: 'sis', value: 'A-1')],
    ),
    (ZStudyOfferingAudience v) => v.toMap(),
    ZStudyOfferingAudience.fromMap,
    $ZStudyOfferingAudienceFieldSpecs,
  ),
  _Cas<ZStudyParticipation>(
    'ZStudyParticipation',
    ZStudyParticipation(
      id: 'part1',
      principalRef: const ZStudyRef(
        type: kZStudyRefTypePrincipal,
        id: 'p1',
        label: 'Mandant',
      ),
      targetRef: const ZStudyRef(type: 'zzTypeInconnu', id: 'x1'),
      role: _roleInconnu,
      periodId: 'per1',
      validFrom: DateTime.utc(2026, 9),
      validTo: DateTime.utc(2027),
      externalRefs: const <ZExternalRef>[
        ZExternalRef(system: 'annuaire', value: 'P-1'),
      ],
      extra: const <String, dynamic>{'zz_libre': 'x'},
    ),
    (ZStudyParticipation v) => v.toMap(),
    ZStudyParticipation.fromMap,
    $ZStudyParticipationFieldSpecs,
  ),
  _Cas<ZStudyCurriculum>(
    'ZStudyCurriculum',
    ZStudyCurriculum(
      id: 'cur1',
      organizationId: 'o1',
      subjectId: 's1',
      courseId: 'c1',
      programId: 'pr1',
      code: 'CUR',
      label: 'Référentiel',
      version: 'zzVersionOpaque',
      status: _statutInconnu,
      effectiveFrom: DateTime.utc(2026, 9),
      effectiveTo: DateTime.utc(2027, 7),
      externalRefs: const <ZExternalRef>[
        ZExternalRef(system: 'export', value: 'C-1'),
      ],
    ),
    (ZStudyCurriculum v) => v.toMap(),
    ZStudyCurriculum.fromMap,
    $ZStudyCurriculumFieldSpecs,
  ),
  _Cas<ZStudyTopic>(
    'ZStudyTopic',
    const ZStudyTopic(
      id: 't1',
      curriculumId: 'cur1',
      parentId: 't0',
      kind: _kindInconnu,
      code: 'T1',
      label: 'Thème',
      order: 2,
      expectedDuration: 'zzDureeOpaque',
      weight: 1.5,
      ancestorIds: <String>['t0'],
      externalRefs: <ZExternalRef>[ZExternalRef(system: 'sis', value: 'T-1')],
      extra: <String, dynamic>{'zz_libre': 3},
    ),
    (ZStudyTopic v) => v.toMap(),
    ZStudyTopic.fromMap,
    $ZStudyTopicFieldSpecs,
  ),
  _Cas<ZStudyCompetencyFramework>(
    'ZStudyCompetencyFramework',
    const ZStudyCompetencyFramework(
      id: 'fr1',
      organizationId: 'o1',
      code: 'FR',
      label: 'Cadre',
      version: 'zzVersionOpaque',
      status: _statutInconnu,
      externalRefs: <ZExternalRef>[ZExternalRef(system: 'sis', value: 'F-1')],
    ),
    (ZStudyCompetencyFramework v) => v.toMap(),
    ZStudyCompetencyFramework.fromMap,
    $ZStudyCompetencyFrameworkFieldSpecs,
  ),
  _Cas<ZStudyCompetency>(
    'ZStudyCompetency',
    const ZStudyCompetency(
      id: 'cp1',
      frameworkId: 'fr1',
      code: 'C2.3',
      label: 'Compétence',
      description: 'Énoncé complet',
      externalRefs: <ZExternalRef>[ZExternalRef(system: 'sis', value: 'K-1')],
      extra: <String, dynamic>{'zz_libre': <String>['a']},
    ),
    (ZStudyCompetency v) => v.toMap(),
    ZStudyCompetency.fromMap,
    $ZStudyCompetencyFieldSpecs,
  ),
  _Cas<ZStudyExplanation>(
    'ZStudyExplanation',
    ZStudyExplanation(
      id: 'ex1',
      folderId: 'f1',
      content: 'Texte',
      style: 'zzStyleInconnu',
      operation: 'zzOperationInconnue',
      relatedTopics: const <String>['t1', 't2'],
      createdAt: DateTime.utc(2026, 3, 4),
      extra: const <String, dynamic>{'zz_libre': 1},
    ),
    (ZStudyExplanation v) => v.toMap(),
    ZStudyExplanation.fromMap,
    $ZStudyExplanationFieldSpecs,
  ),
  _Cas<ZStudyRoleBinding>(
    'ZStudyRoleBinding',
    ZStudyRoleBinding(
      id: 'rb1',
      principalRef: const ZStudyRef(
        type: kZStudyRefTypePrincipal,
        id: 'p1',
      ),
      scopeRef: const ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1'),
      roleKey: _roleInconnu,
      periodId: 'per1',
      validFrom: DateTime.utc(2026),
      validTo: DateTime.utc(2027),
      inheritance: 'zzHeritageInconnu',
      externalRefs: const <ZExternalRef>[
        ZExternalRef(system: 'iam', value: 'R-1'),
      ],
    ),
    (ZStudyRoleBinding v) => v.toMap(),
    ZStudyRoleBinding.fromMap,
    $ZStudyRoleBindingFieldSpecs,
  ),
  _Cas<ZStudyShareGrant>(
    'ZStudyShareGrant',
    ZStudyShareGrant(
      id: 'sg1',
      artifactRef: const ZStudyRef(type: kZStudyRefTypeFolder, id: 'f1'),
      granteeRef: const ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1'),
      accessKey: 'zzAccesInconnu',
      validFrom: DateTime.utc(2026),
      validTo: DateTime.utc(2027),
      externalRefs: const <ZExternalRef>[
        ZExternalRef(system: 'drive', value: 'S-1'),
      ],
      extra: const <String, dynamic>{'zz_libre': 'y'},
    ),
    (ZStudyShareGrant v) => v.toMap(),
    ZStudyShareGrant.fromMap,
    $ZStudyShareGrantFieldSpecs,
  ),
];

void main() {
  group('Structure d\'étude — contrat de (dé)sérialisation', () {
    for (final cas in _cas()) {
      test('${cas.nom} : round-trip complet', cas.verifierRoundTrip);
      test('${cas.nom} : point fixe de la sérialisation', cas.verifierPointFixe);
      test('${cas.nom} : tout champ déclaré est émis', cas.verifierSchema);
      test('${cas.nom} : clés réservées filtrées, inconnues préservées',
          cas.verifierClesReservees);
      test('${cas.nom} : une map corrompue ne lève jamais',
          cas.verifierCorruption);
    }
  });

  group('Le vocabulaire inconnu survit — valeurs, pas seulement structure', () {
    test('un `kind` inconnu ressort intact d\'un groupe', () {
      final relu = ZStudyGroup.fromMap(
        const ZStudyGroup(
          id: 'g1',
          kind: _kindInconnu,
          status: _statutInconnu,
        ).toMap(),
      );
      expect(relu.kind, equals(_kindInconnu));
      expect(relu.status, equals(_statutInconnu));
      // Et le noyau ne prétend pas le comprendre.
      expect(relu.isArchived, isFalse);
    });

    test('un rôle et une propagation inconnus survivent à un rattachement', () {
      const binding = ZStudyBinding(
        sourceRef: ZStudyRef(type: 'folder', id: 'f1'),
        targetRef: ZStudyRef(type: kZStudyRefTypeCourse, id: 'co1'),
        role: _roleInconnu,
        propagation: _propagationInconnue,
      );
      final relu = ZStudyBinding.fromMap(binding.toMap());

      expect(relu, equals(binding));
      expect(relu.role, equals(_roleInconnu));
      expect(relu.propagation, equals(_propagationInconnue));
      // Le noyau la conserve SANS lui prêter de sémantique.
      expect(relu.hasKnownPropagation, isFalse);
    });

    test('une propagation absente vaut `exact`, jamais `none`', () {
      final relu = ZStudyBinding.fromMap(const <String, dynamic>{
        'source_ref': <String, dynamic>{'type': 'folder', 'id': 'f1'},
        'target_ref': <String, dynamic>{'type': 'course', 'id': 'co1'},
      });
      expect(relu.propagation, equals(kZStudyPropagationExact));
    });

    test('un vocabulaire inconnu traverse une classification', () {
      const classification = ZStudyClassification(
        id: 'c1',
        targetRef: ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1'),
        vocabularyKey: _vocabulaireInconnu,
        valueKey: _valeurInconnue,
      );
      final relu = ZStudyClassification.fromMap(classification.toMap());
      expect(relu.vocabularyKey, equals(_vocabulaireInconnu));
      expect(relu.valueKey, equals(_valeurInconnue));
      expect(
        relu.constraint,
        equals(
          const ZStudyClassificationConstraint(
            vocabularyKey: _vocabulaireInconnu,
            valueKey: _valeurInconnue,
          ),
        ),
      );
    });

    test('une ontologie complète round-trippe, kinds inconnus compris', () {
      const ontology = ZStudyOntology(
        version: 'zz/1',
        groupKinds: <ZStudyKindSpec>[
          ZStudyKindSpec(
            key: _kindInconnu,
            family: 'zzFamilleInconnue',
            label: 'Inconnu',
            iconKey: 'zz',
            capabilities: <String>{'zzCapaciteInconnue'},
            allowedParentKinds: <String>{'zzParent'},
            allowedChildKinds: <String>{'zzEnfant'},
            allowedVocabularyKeys: <String>{_vocabulaireInconnu},
          ),
        ],
        vocabularies: <ZStudyVocabularySpec>[
          ZStudyVocabulary(
            key: _vocabulaireInconnu,
            values: <ZStudyVocabularyValue>[
              ZStudyVocabularyValue(value: _valeurInconnue, order: 2),
            ],
          ),
        ],
        containmentRules: <ZStudyContainmentRule>[
          ZStudyContainmentRule(
            parentKind: 'zzParent',
            childKind: _kindInconnu,
            maxDepth: 2,
          ),
        ],
        displayRules: ZStudyDisplayRules(
          kindOrder: <String>[_kindInconnu],
          hiddenKinds: <String>{'zzMasque'},
        ),
      );
      final relu = ZStudyOntology.fromMap(ontology.toMap());
      expect(relu, equals(ontology));
      expect(relu.toMap(), equals(ontology.toMap()));
    });

    test('un filtre de portée round-trippe avec des portées inconnues', () {
      const filtre = ZStudyScopeFilter(
        scopes: <ZStudyRef>[ZStudyRef(type: 'zzTypeInconnu', id: 'x1')],
        includeDescendants: false,
        periodIds: <String>['p1'],
        subjectIds: <String>['s1'],
        courseIds: <String>['c1'],
        topicIds: <String>['t1'],
        offeringIds: <String>['o1'],
      );
      final relu = ZStudyScopeFilter.fromMap(filtre.toMap());
      expect(relu, equals(filtre));
      expect(relu.isEmpty, isFalse);
      expect(const ZStudyScopeFilter().isEmpty, isTrue);
    });
  });

  group('Références — identité, instantané, absence', () {
    test('deux références de même cible mais d\'instantanés différents ne '
        'sont pas égales, et désignent pourtant la même cible', () {
      const a = ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1', label: 'Avant');
      const b = ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1', label: 'Après');
      expect(a, isNot(equals(b)));
      expect(a.sameTarget(b), isTrue);
    });

    test('une référence vide ne lève pas et reste identifiable', () {
      final relu = ZStudyRef.fromMap(const <String, dynamic>{});
      expect(relu.type, isEmpty);
      expect(relu.id, isEmpty);
      expect(relu.isScopable, isFalse);
    });

    test('un rattachement sans instantané n\'en invente pas au round-trip', () {
      const binding = ZStudyBinding(
        sourceRef: ZStudyRef(type: 'folder', id: 'f1'),
        targetRef: ZStudyRef(type: kZStudyRefTypeCourse, id: 'co1'),
      );
      expect(binding.toMap().keys, isNot(contains('snapshot')));
      expect(binding.snapshot, equals(binding.targetRef));
      expect(ZStudyBinding.fromMap(binding.toMap()), equals(binding));
    });

    test('la validité est un axe indépendant de la propagation', () {
      final binding = ZStudyBinding(
        sourceRef: const ZStudyRef(type: 'folder', id: 'f1'),
        targetRef: const ZStudyRef(type: kZStudyRefTypeCourse, id: 'co1'),
        propagation: kZStudyPropagationNone,
        validFrom: DateTime.utc(2026),
        validTo: DateTime.utc(2027),
      );
      expect(binding.isActiveAt(DateTime.utc(2026, 6)), isTrue);
      expect(binding.isActiveAt(DateTime.utc(2025)), isFalse);
      // Borne haute EXCLUE.
      expect(binding.isActiveAt(DateTime.utc(2027)), isFalse);
    });
  });
}
