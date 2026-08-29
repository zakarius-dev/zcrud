/// Préréglages d'ontologie livrés **comme données**.
///
/// Ce fichier est le **seul** du paquet à porter du vocabulaire de contexte.
/// Partout ailleurs, les `kind`, clés de vocabulaire, valeurs et rôles sont des
/// chaînes opaques que le noyau ne connaît pas : aucune primitive ne teste une
/// de ces valeurs, et une garde de source interdit qu'elles réapparaissent
/// ailleurs sous `lib/`.
///
/// Un préréglage est un **point de départ**, jamais une contrainte : une
/// application peut l'utiliser tel quel, le recomposer, ou déclarer sa propre
/// ontologie sans en reprendre une seule clé. Les libellés sont des chaînes
/// brutes destinées à être **remplacées** par la localisation de
/// l'application ; le socle ne traduit rien.
library;

import 'z_study_constants.dart';
import 'z_study_kind_spec.dart';
import 'z_study_ontology.dart';
import 'z_study_vocabulary.dart';

/// Capacités d'un type qui rassemble des personnes et peut porter des
/// ressources.
const Set<String> _audienceCapabilities = <String>{
  kZStudyCapabilityAcceptsParticipation,
  kZStudyCapabilityCanBeOfferingAudience,
  kZStudyCapabilityCanOwnResources,
  kZStudyCapabilityCanBeScoped,
};

/// Capacités d'un nœud institutionnel intermédiaire.
const Set<String> _branchCapabilities = <String>{
  kZStudyCapabilityCanOwnResources,
  kZStudyCapabilityCanBeScoped,
  kZStudyCapabilityHierarchical,
};

/// Capacités d'une racine institutionnelle (aucun parent admis).
const Set<String> _rootCapabilities = <String>{
  kZStudyCapabilityCanOwnResources,
  kZStudyCapabilityCanBeScoped,
};

/// Préréglages d'ontologie prêts à l'emploi.
///
/// Chaque membre est une constante : l'utiliser n'alloue rien et ne fige aucun
/// état global.
abstract final class ZStudyOntologyPresets {
  /// Enseignement secondaire général : établissement → niveau → classe.
  static const ZStudyOntology lyceeFr = ZStudyOntology(
    version: 'lyceeFr/1',
    organizationKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'etablissement',
        family: kZStudyFamilyOrganization,
        label: 'Établissement',
        iconKey: 'school',
        capabilities: _rootCapabilities,
        allowedChildKinds: <String>{'niveau'},
      ),
      ZStudyKindSpec(
        key: 'niveau',
        family: kZStudyFamilyOrganization,
        label: 'Niveau',
        capabilities: _branchCapabilities,
        allowedParentKinds: <String>{'etablissement'},
        allowedVocabularyKeys: <String>{'niveau', 'filiere'},
      ),
    ],
    groupKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'classe',
        family: kZStudyFamilyGroup,
        label: 'Classe',
        capabilities: _audienceCapabilities,
        allowedVocabularyKeys: <String>{'niveau', 'filiere'},
      ),
    ],
    periodKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'anneeScolaire',
        family: kZStudyFamilyPeriod,
        label: 'Année scolaire',
        capabilities: <String>{kZStudyCapabilityCanBeScoped},
        allowedChildKinds: <String>{'trimestre'},
      ),
      ZStudyKindSpec(
        key: 'trimestre',
        family: kZStudyFamilyPeriod,
        label: 'Trimestre',
        capabilities: <String>{
          kZStudyCapabilityCanBeScoped,
          kZStudyCapabilityHierarchical,
        },
        allowedParentKinds: <String>{'anneeScolaire'},
      ),
    ],
    vocabularies: <ZStudyVocabularySpec>[
      ZStudyVocabulary(
        key: 'niveau',
        label: 'Niveau',
        values: <ZStudyVocabularyValue>[
          ZStudyVocabularyValue(value: 'seconde', label: 'Seconde'),
          ZStudyVocabularyValue(value: 'premiere', label: 'Première', order: 1),
          ZStudyVocabularyValue(value: 'terminale', label: 'Terminale', order: 2),
        ],
      ),
      ZStudyVocabulary(
        key: 'filiere',
        label: 'Filière',
        values: <ZStudyVocabularyValue>[
          ZStudyVocabularyValue(value: 'generale', label: 'Générale'),
          ZStudyVocabularyValue(
            value: 'technologique',
            label: 'Technologique',
            order: 1,
          ),
          ZStudyVocabularyValue(
            value: 'professionnelle',
            label: 'Professionnelle',
            order: 2,
          ),
        ],
      ),
    ],
    containmentRules: <ZStudyContainmentRule>[
      ZStudyContainmentRule(parentKind: 'etablissement', childKind: 'niveau'),
      ZStudyContainmentRule(parentKind: 'niveau', childKind: 'classe'),
    ],
  );

  /// Enseignement supérieur en cycles : université → faculté → département,
  /// promotions comme groupes.
  static const ZStudyOntology universiteLmd = ZStudyOntology(
    version: 'universiteLmd/1',
    organizationKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'universite',
        family: kZStudyFamilyOrganization,
        label: 'Université',
        iconKey: 'school',
        capabilities: _rootCapabilities,
        allowedChildKinds: <String>{'faculte'},
      ),
      ZStudyKindSpec(
        key: 'faculte',
        family: kZStudyFamilyOrganization,
        label: 'Faculté',
        capabilities: _branchCapabilities,
        allowedParentKinds: <String>{'universite'},
        allowedChildKinds: <String>{'departement'},
      ),
      ZStudyKindSpec(
        key: 'departement',
        family: kZStudyFamilyOrganization,
        label: 'Département',
        capabilities: _branchCapabilities,
        allowedParentKinds: <String>{'faculte'},
      ),
    ],
    groupKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'promotion',
        family: kZStudyFamilyGroup,
        label: 'Promotion',
        capabilities: _audienceCapabilities,
        allowedVocabularyKeys: <String>{'cycle'},
      ),
    ],
    programKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'diplome',
        family: kZStudyFamilyProgram,
        label: 'Diplôme',
        capabilities: <String>{
          kZStudyCapabilityCanBeScoped,
          kZStudyCapabilityHierarchical,
        },
        allowedVocabularyKeys: <String>{'cycle'},
      ),
    ],
    periodKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'anneeUniversitaire',
        family: kZStudyFamilyPeriod,
        label: 'Année universitaire',
        capabilities: <String>{kZStudyCapabilityCanBeScoped},
        allowedChildKinds: <String>{'semestre'},
      ),
      ZStudyKindSpec(
        key: 'semestre',
        family: kZStudyFamilyPeriod,
        label: 'Semestre',
        capabilities: <String>{
          kZStudyCapabilityCanBeScoped,
          kZStudyCapabilityHierarchical,
        },
        allowedParentKinds: <String>{'anneeUniversitaire'},
      ),
    ],
    vocabularies: <ZStudyVocabularySpec>[
      ZStudyVocabulary(
        key: 'cycle',
        label: 'Cycle',
        values: <ZStudyVocabularyValue>[
          ZStudyVocabularyValue(value: 'licence', label: 'Licence'),
          ZStudyVocabularyValue(value: 'master', label: 'Master', order: 1),
          ZStudyVocabularyValue(value: 'doctorat', label: 'Doctorat', order: 2),
        ],
      ),
    ],
    containmentRules: <ZStudyContainmentRule>[
      ZStudyContainmentRule(parentKind: 'universite', childKind: 'faculte'),
      ZStudyContainmentRule(parentKind: 'faculte', childKind: 'departement'),
      ZStudyContainmentRule(parentKind: 'departement', childKind: 'promotion'),
    ],
  );

  /// Formation continue : organisme → parcours de formation, groupes
  /// d'apprenants.
  static const ZStudyOntology formationPro = ZStudyOntology(
    version: 'formationPro/1',
    organizationKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'organisme',
        family: kZStudyFamilyOrganization,
        label: 'Organisme',
        iconKey: 'business',
        capabilities: _rootCapabilities,
      ),
    ],
    groupKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'groupe',
        family: kZStudyFamilyGroup,
        label: 'Groupe',
        capabilities: _audienceCapabilities,
        allowedVocabularyKeys: <String>{'modalite'},
      ),
    ],
    programKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'formation',
        family: kZStudyFamilyProgram,
        label: 'Formation',
        capabilities: <String>{
          kZStudyCapabilityCanBeScoped,
          kZStudyCapabilityHierarchical,
        },
        allowedVocabularyKeys: <String>{'modalite'},
      ),
    ],
    periodKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'promotionDatee',
        family: kZStudyFamilyPeriod,
        label: 'Session datée',
        capabilities: <String>{kZStudyCapabilityCanBeScoped},
      ),
    ],
    vocabularies: <ZStudyVocabularySpec>[
      ZStudyVocabulary(
        key: 'modalite',
        label: 'Modalité',
        values: <ZStudyVocabularyValue>[
          ZStudyVocabularyValue(value: 'presentiel', label: 'Présentiel'),
          ZStudyVocabularyValue(
            value: 'distanciel',
            label: 'Distanciel',
            order: 1,
          ),
          ZStudyVocabularyValue(
            value: 'alternance',
            label: 'Alternance',
            order: 2,
          ),
        ],
      ),
    ],
    containmentRules: <ZStudyContainmentRule>[
      ZStudyContainmentRule(parentKind: 'organisme', childKind: 'groupe'),
    ],
  );

  /// Enseignement élémentaire : école → niveau, classes comme groupes.
  static const ZStudyOntology primaire = ZStudyOntology(
    version: 'primaire/1',
    organizationKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'ecole',
        family: kZStudyFamilyOrganization,
        label: 'École',
        iconKey: 'school',
        capabilities: _rootCapabilities,
        allowedChildKinds: <String>{'niveau'},
      ),
      ZStudyKindSpec(
        key: 'niveau',
        family: kZStudyFamilyOrganization,
        label: 'Niveau',
        capabilities: _branchCapabilities,
        allowedParentKinds: <String>{'ecole'},
        allowedVocabularyKeys: <String>{'niveau'},
      ),
    ],
    groupKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'classe',
        family: kZStudyFamilyGroup,
        label: 'Classe',
        capabilities: _audienceCapabilities,
        allowedVocabularyKeys: <String>{'niveau'},
      ),
    ],
    periodKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'anneeScolaire',
        family: kZStudyFamilyPeriod,
        label: 'Année scolaire',
        capabilities: <String>{kZStudyCapabilityCanBeScoped},
      ),
    ],
    vocabularies: <ZStudyVocabularySpec>[
      ZStudyVocabulary(
        key: 'niveau',
        label: 'Niveau',
        values: <ZStudyVocabularyValue>[
          ZStudyVocabularyValue(value: 'cp', label: 'CP'),
          ZStudyVocabularyValue(value: 'ce1', label: 'CE1', order: 1),
          ZStudyVocabularyValue(value: 'ce2', label: 'CE2', order: 2),
          ZStudyVocabularyValue(value: 'cm1', label: 'CM1', order: 3),
          ZStudyVocabularyValue(value: 'cm2', label: 'CM2', order: 4),
        ],
      ),
    ],
    containmentRules: <ZStudyContainmentRule>[
      ZStudyContainmentRule(parentKind: 'ecole', childKind: 'niveau'),
      ZStudyContainmentRule(parentKind: 'niveau', childKind: 'classe'),
    ],
  );

  /// Usage personnel : aucune institution, aucun vocabulaire imposé.
  ///
  /// C'est le préréglage qui montre que l'absence est un état complet : ni
  /// organisation, ni groupe, ni règle de contenance. Tout ce que l'apprenant
  /// crée est à lui, et rien n'exige un espace de travail.
  static const ZStudyOntology personnel = ZStudyOntology(
    version: 'personnel/1',
    periodKinds: <ZStudyKindSpec>[
      ZStudyKindSpec(
        key: 'periodeLibre',
        family: kZStudyFamilyPeriod,
        label: 'Période',
        capabilities: <String>{
          kZStudyCapabilityCanBeScoped,
          kZStudyCapabilityHierarchical,
        },
      ),
    ],
  );

  /// Tous les préréglages livrés, dans un ordre stable.
  static const List<ZStudyOntology> all = <ZStudyOntology>[
    lyceeFr,
    universiteLmd,
    formationPro,
    primaire,
    personnel,
  ];
}
