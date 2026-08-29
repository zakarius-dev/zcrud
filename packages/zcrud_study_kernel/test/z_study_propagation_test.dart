// Gardes de PROPAGATION et de FILTRAGE DE PORTÉE.
//
// La propagation est le seul endroit du noyau où une décision se calcule à
// partir de la forme de la structure. Elle est donc le seul endroit où une
// erreur ne se voit pas : un `descendants` qui attraperait les cousins, un
// `none` qui laisserait passer la cible exacte, un `members` qui répondrait
// vrai sans mandant — rien de tout cela ne casse un round-trip, rien ne rougit
// ailleurs. D'où une garde par MODE, et pour chaque mode les deux moitiés :
// ce qu'il doit atteindre, et ce qu'il ne doit PAS atteindre.
//
// L'arbre de groupes utilisé partout :
//
//   gRacine ── gA ── gA1
//          └── gB              (gB est le FRÈRE de gA, donc le COUSIN de gA1)
//   gAutre                     (racine séparée, hors de tout)

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

ZStudyRef _g(String id) => ZStudyRef(type: kZStudyRefTypeGroup, id: id);

ZStudyContext _ctx(List<ZStudyRef> groupes, {ZStudyRef? offering}) =>
    ZStudyContext(groupRefs: groupes, offeringRef: offering);

ZStudyBinding _lien(
  ZStudyRef cible,
  String propagation, {
  DateTime? validFrom,
  DateTime? validTo,
}) => ZStudyBinding(
  sourceRef: const ZStudyRef(type: kZStudyRefTypeFolder, id: 'f1'),
  targetRef: cible,
  propagation: propagation,
  validFrom: validFrom,
  validTo: validTo,
);

final ZStudyStructureSnapshot _arbre = ZStudyStructureSnapshot(
  groups: const <String, ZStudyGroup>{
    'gRacine': ZStudyGroup(id: 'gRacine', label: 'Racine'),
    'gA': ZStudyGroup(
      id: 'gA',
      parentGroupId: 'gRacine',
      ancestorIds: <String>['gRacine'],
    ),
    'gB': ZStudyGroup(
      id: 'gB',
      parentGroupId: 'gRacine',
      ancestorIds: <String>['gRacine'],
    ),
    'gA1': ZStudyGroup(
      id: 'gA1',
      parentGroupId: 'gA',
      ancestorIds: <String>['gRacine', 'gA'],
    ),
    'gAutre': ZStudyGroup(id: 'gAutre', label: 'Ailleurs'),
  },
  participations: const <String, ZStudyParticipation>{
    'p1': ZStudyParticipation(
      principalRef: ZStudyRef(type: kZStudyRefTypePrincipal, id: 'moi'),
      targetRef: ZStudyRef(type: kZStudyRefTypeGroup, id: 'gA'),
      role: kZStudyRoleLearner,
    ),
  },
  courses: const <String, ZStudyCourse>{'c1': ZStudyCourse(id: 'c1')},
  offerings: const <String, ZStudyOffering>{
    'off1': ZStudyOffering(id: 'off1', courseId: 'c1', periodId: 'per1'),
  },
  offeringAudiences: const <String, ZStudyOfferingAudience>{
    'a1': ZStudyOfferingAudience(id: 'a1', offeringId: 'off1', groupId: 'gA'),
  },
);

bool _visible(
  ZStudyBinding lien,
  ZStudyContext contexte, {
  ZStudyRef? principalRef,
  DateTime? at,
}) => zIsVisibleFrom(
  lien,
  contexte,
  snapshot: _arbre,
  principalRef: principalRef,
  at: at,
);

void main() {
  group('none — n\'atteint RIEN, pas même la cible exacte', () {
    test('la cible exacte n\'est pas atteinte', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationNone),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isFalse,
      );
    });

    test('aucun descendant n\'est atteint non plus', () {
      expect(
        _visible(
          _lien(_g('gRacine'), kZStudyPropagationNone),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isFalse,
      );
    });
  });

  group('exact — la cible, et elle seule', () {
    test('atteint la cible', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationExact),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isTrue,
      );
    });

    test('n\'atteint PAS un descendant', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationExact),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isFalse,
      );
    });

    test('n\'atteint PAS un ancêtre', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationExact),
          _ctx(<ZStudyRef>[_g('gRacine')]),
        ),
        isFalse,
      );
    });
  });

  group('descendants — inclut les sous-groupes, EXCLUT les cousins', () {
    test('atteint la cible elle-même', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationDescendants),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isTrue,
      );
    });

    test('atteint un enfant direct', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationDescendants),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isTrue,
      );
    });

    test('atteint un petit-enfant (chaîne complète, pas seulement le parent)',
        () {
      expect(
        _visible(
          _lien(_g('gRacine'), kZStudyPropagationDescendants),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isTrue,
      );
    });

    test('N\'ATTEINT PAS un cousin', () {
      // gB est frère de gA : il n'est pas sous gA. C'est l'assertion centrale.
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationDescendants),
          _ctx(<ZStudyRef>[_g('gB')]),
        ),
        isFalse,
      );
    });

    test('n\'atteint pas un arbre séparé', () {
      expect(
        _visible(
          _lien(_g('gRacine'), kZStudyPropagationDescendants),
          _ctx(<ZStudyRef>[_g('gAutre')]),
        ),
        isFalse,
      );
    });

    test('n\'atteint pas un ancêtre (la propagation est ORIENTÉE)', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationDescendants),
          _ctx(<ZStudyRef>[_g('gRacine')]),
        ),
        isFalse,
      );
    });

    test('une collision d\'identifiant entre TYPES ne propage pas', () {
      // Cible de type organisation portant l'identifiant d'un groupe : aucune
      // parenté ne doit être déduite d'un identifiant seul.
      expect(
        _visible(
          _lien(
            const ZStudyRef(type: kZStudyRefTypeOrganization, id: 'gA'),
            kZStudyPropagationDescendants,
          ),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isFalse,
      );
    });
  });

  group('ancestors — remonte l\'arbre', () {
    test('atteint la cible elle-même', () {
      expect(
        _visible(
          _lien(_g('gA1'), kZStudyPropagationAncestors),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isTrue,
      );
    });

    test('atteint le parent', () {
      expect(
        _visible(
          _lien(_g('gA1'), kZStudyPropagationAncestors),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isTrue,
      );
    });

    test('atteint la racine', () {
      expect(
        _visible(
          _lien(_g('gA1'), kZStudyPropagationAncestors),
          _ctx(<ZStudyRef>[_g('gRacine')]),
        ),
        isTrue,
      );
    });

    test('N\'ATTEINT PAS un cousin', () {
      expect(
        _visible(
          _lien(_g('gA1'), kZStudyPropagationAncestors),
          _ctx(<ZStudyRef>[_g('gB')]),
        ),
        isFalse,
      );
    });

    test('n\'atteint pas un descendant (la propagation est ORIENTÉE)', () {
      expect(
        _visible(
          _lien(_g('gRacine'), kZStudyPropagationAncestors),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isFalse,
      );
    });
  });

  group('members — atteint les participants', () {
    final principal = const ZStudyRef(
      type: kZStudyRefTypePrincipal,
      id: 'moi',
    );
    final autre = const ZStudyRef(
      type: kZStudyRefTypePrincipal,
      id: 'quelqu\'un',
    );

    test('atteint un mandant qui participe à la cible', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationMembers),
          _ctx(const <ZStudyRef>[]),
          principalRef: principal,
        ),
        isTrue,
      );
    });

    test('N\'ATTEINT PAS un mandant qui ne participe pas', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationMembers),
          _ctx(const <ZStudyRef>[]),
          principalRef: autre,
        ),
        isFalse,
      );
    });

    test('n\'atteint pas un groupe auquel le mandant ne participe pas', () {
      expect(
        _visible(
          _lien(_g('gB'), kZStudyPropagationMembers),
          _ctx(const <ZStudyRef>[]),
          principalRef: principal,
        ),
        isFalse,
      );
    });

    test('sans mandant fourni, seule la cible exacte est atteinte', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationMembers),
          _ctx(const <ZStudyRef>[]),
        ),
        isFalse,
      );
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationMembers),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isTrue,
      );
    });
  });

  group('offerings — suit les offres portées par la cible', () {
    final contexte = _ctx(
      const <ZStudyRef>[],
      offering: const ZStudyRef(type: kZStudyRefTypeOffering, id: 'off1'),
    );

    test('atteint via le cours de l\'offre', () {
      expect(
        _visible(
          _lien(
            const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c1'),
            kZStudyPropagationOfferings,
          ),
          contexte,
        ),
        isTrue,
      );
    });

    test('atteint via un groupe d\'audience de l\'offre', () {
      expect(
        _visible(
          _lien(_g('gA'), kZStudyPropagationOfferings),
          contexte,
        ),
        isTrue,
      );
    });

    test('n\'atteint pas via un autre cours', () {
      expect(
        _visible(
          _lien(
            const ZStudyRef(type: kZStudyRefTypeCourse, id: 'cAutre'),
            kZStudyPropagationOfferings,
          ),
          contexte,
        ),
        isFalse,
      );
    });

    test('sans offre dans le contexte, seule la cible exacte est atteinte', () {
      expect(
        _visible(
          _lien(
            const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c1'),
            kZStudyPropagationOfferings,
          ),
          _ctx(const <ZStudyRef>[]),
        ),
        isFalse,
      );
    });
  });

  group('propagation INCONNUE — comme `exact`, jamais comme `none`', () {
    test('atteint la cible exacte', () {
      expect(
        _visible(
          _lien(_g('gA'), 'zzPropagationInconnue'),
          _ctx(<ZStudyRef>[_g('gA')]),
        ),
        isTrue,
      );
    });

    test('n\'étend rien', () {
      expect(
        _visible(
          _lien(_g('gA'), 'zzPropagationInconnue'),
          _ctx(<ZStudyRef>[_g('gA1')]),
        ),
        isFalse,
      );
    });
  });

  group('validité — axe indépendant de la propagation', () {
    final lien = _lien(
      _g('gA'),
      kZStudyPropagationDescendants,
      validFrom: DateTime.utc(2026),
      validTo: DateTime.utc(2027),
    );
    final contexte = _ctx(<ZStudyRef>[_g('gA1')]);

    test('dans la fenêtre : atteint', () {
      expect(_visible(lien, contexte, at: DateTime.utc(2026, 6)), isTrue);
    });

    test('avant la fenêtre : n\'atteint pas', () {
      expect(_visible(lien, contexte, at: DateTime.utc(2025)), isFalse);
    });

    test('la borne haute est EXCLUE', () {
      expect(_visible(lien, contexte, at: DateTime.utc(2027)), isFalse);
    });

    test('sans instant, la validité n\'est pas consultée', () {
      expect(_visible(lien, contexte), isTrue);
    });
  });

  group('zArtifactIsVisibleFrom — assemblage, sans logique propre', () {
    test('la portée principale suffit', () {
      final dossier = ZStudyFolder(title: 'D', primaryScopeRef: _g('gA'));
      expect(
        zArtifactIsVisibleFrom(dossier, _ctx(<ZStudyRef>[_g('gA')]),
            snapshot: _arbre),
        isTrue,
      );
    });

    test('la portée principale ne PROPAGE pas (elle n\'est pas datée '
        'ni graduée)', () {
      final dossier = ZStudyFolder(title: 'D', primaryScopeRef: _g('gA'));
      expect(
        zArtifactIsVisibleFrom(dossier, _ctx(<ZStudyRef>[_g('gA1')]),
            snapshot: _arbre),
        isFalse,
      );
    });

    test('un rattachement `descendants` propage, lui', () {
      final dossier = ZStudyFolder(
        title: 'D',
        bindings: <ZStudyBinding>[
          _lien(_g('gA'), kZStudyPropagationDescendants),
        ],
      );
      expect(
        zArtifactIsVisibleFrom(dossier, _ctx(<ZStudyRef>[_g('gA1')]),
            snapshot: _arbre),
        isTrue,
      );
    });

    test('un artefact sans aucun rattachement n\'est visible de nulle part',
        () {
      const dossier = ZStudyFolder(title: 'D');
      expect(
        zArtifactIsVisibleFrom(dossier, _ctx(<ZStudyRef>[_g('gA')]),
            snapshot: _arbre),
        isFalse,
      );
    });
  });

  group('zMatchesScopeFilter — axes en ET, valeurs en OU', () {
    final dossier = ZStudyFolder(
      title: 'D',
      primaryScopeRef: _g('gA1'),
      bindings: <ZStudyBinding>[
        ZStudyBinding(
          sourceRef: const ZStudyRef(type: kZStudyRefTypeFolder, id: 'f1'),
          targetRef: const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c1'),
        ),
        ZStudyBinding(
          sourceRef: const ZStudyRef(type: kZStudyRefTypeFolder, id: 'f1'),
          targetRef: const ZStudyRef(type: kZStudyRefTypePeriod, id: 'per1'),
        ),
      ],
    );

    bool filtre(ZStudyScopeFilter f, {DateTime? at}) =>
        zMatchesScopeFilter(dossier, f, snapshot: _arbre, at: at);

    test('un filtre VIDE accepte tout', () {
      expect(filtre(const ZStudyScopeFilter()), isTrue);
    });

    test('un axe satisfait accepte', () {
      expect(
        filtre(const ZStudyScopeFilter(courseIds: <String>['c1'])),
        isTrue,
      );
    });

    test('un axe non satisfait refuse', () {
      expect(
        filtre(const ZStudyScopeFilter(courseIds: <String>['cAutre'])),
        isFalse,
      );
    });

    test('les valeurs d\'un axe se combinent en OU', () {
      expect(
        filtre(
          const ZStudyScopeFilter(courseIds: <String>['cAutre', 'c1']),
        ),
        isTrue,
      );
    });

    test('les axes se combinent en ET : un seul axe faux refuse tout', () {
      expect(
        filtre(
          const ZStudyScopeFilter(
            courseIds: <String>['c1'],
            periodIds: <String>['perAutre'],
          ),
        ),
        isFalse,
      );
      expect(
        filtre(
          const ZStudyScopeFilter(
            courseIds: <String>['c1'],
            periodIds: <String>['per1'],
          ),
        ),
        isTrue,
      );
    });

    test('includeDescendants étend la portée aux sous-groupes', () {
      // Le dossier est sur gA1 ; le filtre porte sur gA.
      expect(
        filtre(ZStudyScopeFilter(scopes: <ZStudyRef>[_g('gA')])),
        isTrue,
      );
    });

    test('includeDescendants: false REFUSE le sous-groupe', () {
      expect(
        filtre(
          ZStudyScopeFilter(
            scopes: <ZStudyRef>[_g('gA')],
            includeDescendants: false,
          ),
        ),
        isFalse,
      );
    });

    test('la portée exacte passe même sans extension', () {
      expect(
        filtre(
          ZStudyScopeFilter(
            scopes: <ZStudyRef>[_g('gA1')],
            includeDescendants: false,
          ),
        ),
        isTrue,
      );
    });

    test('un cousin ne satisfait pas le filtre, même avec extension', () {
      expect(
        filtre(ZStudyScopeFilter(scopes: <ZStudyRef>[_g('gB')])),
        isFalse,
      );
    });

    test('un rattachement `none` ne fait PAS entrer dans un filtre', () {
      final neutralise = ZStudyFolder(
        title: 'D',
        bindings: <ZStudyBinding>[
          _lien(
            const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c1'),
            kZStudyPropagationNone,
          ),
        ],
      );
      expect(
        zMatchesScopeFilter(
          neutralise,
          const ZStudyScopeFilter(courseIds: <String>['c1']),
          snapshot: _arbre,
        ),
        isFalse,
      );
    });

    test('un rattachement EXPIRÉ ne fait pas entrer dans un filtre', () {
      final expire = ZStudyFolder(
        title: 'D',
        bindings: <ZStudyBinding>[
          _lien(
            const ZStudyRef(type: kZStudyRefTypeCourse, id: 'c1'),
            kZStudyPropagationExact,
            validTo: DateTime.utc(2026),
          ),
        ],
      );
      expect(
        zMatchesScopeFilter(
          expire,
          const ZStudyScopeFilter(courseIds: <String>['c1']),
          snapshot: _arbre,
          at: DateTime.utc(2027),
        ),
        isFalse,
      );
      expect(
        zMatchesScopeFilter(
          expire,
          const ZStudyScopeFilter(courseIds: <String>['c1']),
          snapshot: _arbre,
          at: DateTime.utc(2025),
        ),
        isTrue,
      );
    });
  });
}
