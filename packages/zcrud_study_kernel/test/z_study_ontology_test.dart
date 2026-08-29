// Gardes de l'ontologie : le noyau décide par CAPACITÉ, jamais par type.
//
// Ce que ces gardes défendent réellement :
// - une ontologie absente n'est pas une ontologie vide : elle ne restreint
//   RIEN. Un socle qui refuserait par défaut rendrait le mode personnel
//   inutilisable ;
// - un type non déclaré n'est pas un type interdit ;
// - le refus, quand il tombe, vient d'une capacité ou d'une autorisation
//   déclarée — jamais d'un littéral de type écrit dans le socle.

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Type arborescent sans restriction de parent.
const ZStudyKindSpec _enfantHierarchique = ZStudyKindSpec(
  key: 'zzEnfant',
  family: 'zzFamille',
  capabilities: <String>{kZStudyCapabilityHierarchical},
);

/// Même type, mais sans la capacité d'admettre un parent.
const ZStudyKindSpec _enfantPlat = ZStudyKindSpec(
  key: 'zzEnfantPlat',
  family: 'zzFamille',
  capabilities: <String>{kZStudyCapabilityCanBeScoped},
);

const ZStudyKindSpec _parent = ZStudyKindSpec(
  key: 'zzParent',
  family: 'zzFamille',
  capabilities: <String>{kZStudyCapabilityCanOwnResources},
);

const ZStudyKindSpec _autreParent = ZStudyKindSpec(
  key: 'zzAutreParent',
  family: 'zzFamille',
);

bool _estRefus(ZResult<Unit> result) => result.isLeft();

void main() {
  group('zHasCapability — l\'absence ne restreint rien', () {
    test('ontologie `null` ⇒ toute capacité est accordée', () {
      expect(
        zHasCapability(null, 'zzKind', kZStudyCapabilityAcceptsParticipation),
        isTrue,
      );
    });

    test('type NON DÉCLARÉ ⇒ toute capacité est accordée', () {
      const ontology = ZStudyOntology(
        groupKinds: <ZStudyKindSpec>[_parent],
      );
      expect(
        zHasCapability(ontology, 'zzInconnu', kZStudyCapabilityCanOwnResources),
        isTrue,
      );
    });

    test('type déclaré ⇒ la réponse suit EXACTEMENT ses capacités', () {
      const ontology = ZStudyOntology(groupKinds: <ZStudyKindSpec>[_parent]);
      expect(
        zHasCapability(
          ontology,
          'zzParent',
          kZStudyCapabilityCanOwnResources,
        ),
        isTrue,
      );
      expect(
        zHasCapability(
          ontology,
          'zzParent',
          kZStudyCapabilityAcceptsParticipation,
        ),
        isFalse,
      );
    });

    test('une capacité inconnue du noyau reste interrogeable', () {
      const ontology = ZStudyOntology(
        groupKinds: <ZStudyKindSpec>[
          ZStudyKindSpec(key: 'k', capabilities: <String>{'zzCapaciteMaison'}),
        ],
      );
      expect(zHasCapability(ontology, 'k', 'zzCapaciteMaison'), isTrue);
      expect(zHasCapability(ontology, 'k', 'zzAutreCapacite'), isFalse);
    });
  });

  group('zValidatePlacement — décision par capacité', () {
    test('ontologie `null` ⇒ TOUJOURS accepté, même sans capacité', () {
      expect(
        zValidatePlacement(null, _parent, _enfantPlat).isRight(),
        isTrue,
      );
    });

    test('placement à la racine ⇒ accepté même sans `hierarchical`', () {
      const ontology = ZStudyOntology();
      expect(
        zValidatePlacement(ontology, null, _enfantPlat).isRight(),
        isTrue,
      );
    });

    test('type SANS `hierarchical` sous un parent ⇒ refus', () {
      const ontology = ZStudyOntology();
      final result = zValidatePlacement(ontology, _parent, _enfantPlat);
      expect(_estRefus(result), isTrue);
    });

    test('type AVEC `hierarchical` sous un parent ⇒ accepté', () {
      const ontology = ZStudyOntology();
      expect(
        zValidatePlacement(ontology, _parent, _enfantHierarchique).isRight(),
        isTrue,
      );
    });

    test('parent hors de `allowedParentKinds` de l\'enfant ⇒ refus', () {
      const enfant = ZStudyKindSpec(
        key: 'zzEnfant',
        capabilities: <String>{kZStudyCapabilityHierarchical},
        allowedParentKinds: <String>{'zzParent'},
      );
      const ontology = ZStudyOntology();
      expect(zValidatePlacement(ontology, _parent, enfant).isRight(), isTrue);
      expect(
        _estRefus(zValidatePlacement(ontology, _autreParent, enfant)),
        isTrue,
      );
    });

    test('enfant hors de `allowedChildKinds` du parent ⇒ refus', () {
      const parent = ZStudyKindSpec(
        key: 'zzParent',
        allowedChildKinds: <String>{'zzAutreEnfant'},
      );
      const ontology = ZStudyOntology();
      expect(
        _estRefus(zValidatePlacement(ontology, parent, _enfantHierarchique)),
        isTrue,
      );
    });

    test('une liste d\'autorisation VIDE n\'interdit rien', () {
      // C'est le point qui rend une ontologie partielle utilisable : vide
      // signifie « aucune restriction », jamais « rien n'est permis ».
      const ontology = ZStudyOntology();
      expect(
        zValidatePlacement(ontology, _parent, _enfantHierarchique).isRight(),
        isTrue,
      );
    });

    test('règle de contenance : couverte mais non autorisée ⇒ refus', () {
      const ontology = ZStudyOntology(
        containmentRules: <ZStudyContainmentRule>[
          ZStudyContainmentRule(parentKind: 'zzParent', childKind: 'zzEnfant'),
        ],
      );
      expect(
        zValidatePlacement(ontology, _parent, _enfantHierarchique).isRight(),
        isTrue,
      );
      expect(
        _estRefus(
          zValidatePlacement(ontology, _autreParent, _enfantHierarchique),
        ),
        isTrue,
      );
    });

    test('un type qu\'aucune règle ne mentionne n\'est pas contraint', () {
      const ontology = ZStudyOntology(
        containmentRules: <ZStudyContainmentRule>[
          ZStudyContainmentRule(parentKind: 'zzParent', childKind: 'zzAutre'),
        ],
      );
      expect(
        zValidatePlacement(ontology, _autreParent, _enfantHierarchique)
            .isRight(),
        isTrue,
      );
    });

    test('borne de profondeur : respectée puis dépassée', () {
      const ontology = ZStudyOntology(
        containmentRules: <ZStudyContainmentRule>[
          ZStudyContainmentRule(
            parentKind: 'zzParent',
            childKind: 'zzEnfant',
            maxDepth: 1,
          ),
        ],
      );
      expect(
        zValidatePlacement(
          ontology,
          _parent,
          _enfantHierarchique,
          depth: 1,
        ).isRight(),
        isTrue,
      );
      expect(
        _estRefus(
          zValidatePlacement(ontology, _parent, _enfantHierarchique, depth: 2),
        ),
        isTrue,
      );
    });
  });

  group('zValidateVocabularyUse — vocabulaire autorisé', () {
    const ontology = ZStudyOntology(
      groupKinds: <ZStudyKindSpec>[
        ZStudyKindSpec(
          key: 'zzGroupe',
          allowedVocabularyKeys: <String>{'zzVocabAutorise'},
        ),
        ZStudyKindSpec(key: 'zzLibre'),
      ],
    );

    test('ontologie `null` ⇒ accepté', () {
      expect(
        zValidateVocabularyUse(null, 'zzGroupe', 'zzQuoiQueCeSoit').isRight(),
        isTrue,
      );
    });

    test('type non déclaré ⇒ accepté', () {
      expect(
        zValidateVocabularyUse(ontology, 'zzInconnu', 'zzVocab').isRight(),
        isTrue,
      );
    });

    test('liste vide ⇒ accepté (aucune restriction)', () {
      expect(
        zValidateVocabularyUse(ontology, 'zzLibre', 'zzVocab').isRight(),
        isTrue,
      );
    });

    test('vocabulaire autorisé ⇒ accepté', () {
      expect(
        zValidateVocabularyUse(
          ontology,
          'zzGroupe',
          'zzVocabAutorise',
        ).isRight(),
        isTrue,
      );
    });

    test('vocabulaire NON autorisé ⇒ refus', () {
      expect(
        _estRefus(
          zValidateVocabularyUse(ontology, 'zzGroupe', 'zzVocabInterdit'),
        ),
        isTrue,
      );
    });

    test('la VALEUR n\'est jamais validée, seule la clé l\'est', () {
      // Une valeur non déclarée reste valide : c'est ce qui permet à un hôte
      // de saisir une valeur avant de l'ajouter au vocabulaire.
      const vocab = ZStudyVocabulary(
        key: 'zzVocabAutorise',
        values: <ZStudyVocabularyValue>[ZStudyVocabularyValue(value: 'a')],
      );
      expect(vocab.valueOf('zzValeurJamaisDeclaree'), isNull);
      expect(
        zValidateVocabularyUse(
          ontology,
          'zzGroupe',
          'zzVocabAutorise',
        ).isRight(),
        isTrue,
      );
    });
  });

  group('Préréglages — des données, et rien de plus', () {
    test('les cinq préréglages sont livrés et round-trippent', () {
      expect(ZStudyOntologyPresets.all, hasLength(5));
      for (final preset in ZStudyOntologyPresets.all) {
        expect(
          ZStudyOntology.fromMap(preset.toMap()),
          equals(preset),
          reason: 'préréglage ${preset.version}',
        );
      }
    });

    test('le préréglage personnel ne déclare AUCUNE institution', () {
      const preset = ZStudyOntologyPresets.personnel;
      expect(preset.organizationKinds, isEmpty);
      expect(preset.groupKinds, isEmpty);
      expect(preset.containmentRules, isEmpty);
      // Et il n'interdit rien : tout placement racine passe.
      expect(
        zValidatePlacement(
          preset,
          null,
          const ZStudyKindSpec(key: 'zzQuelconque'),
        ).isRight(),
        isTrue,
      );
    });

    test('un préréglage refuse un placement que ses règles ne couvrent pas',
        () {
      const preset = ZStudyOntologyPresets.lyceeFr;
      final etablissement = preset.kindSpec('etablissement')!;
      final niveau = preset.kindSpec('niveau')!;
      final classe = preset.kindSpec('classe')!;

      expect(
        zValidatePlacement(preset, etablissement, niveau).isRight(),
        isTrue,
      );
      // Une classe n'admet pas de parent (pas de `hierarchical`) : elle se
      // rattache par participation, pas par contenance.
      expect(_estRefus(zValidatePlacement(preset, niveau, classe)), isTrue);
    });

    test('les capacités du préréglage portent la sémantique d\'audience', () {
      const preset = ZStudyOntologyPresets.universiteLmd;
      expect(
        zHasCapability(
          preset,
          'promotion',
          kZStudyCapabilityAcceptsParticipation,
        ),
        isTrue,
      );
      expect(
        zHasCapability(
          preset,
          'universite',
          kZStudyCapabilityAcceptsParticipation,
        ),
        isFalse,
      );
    });
  });
}
