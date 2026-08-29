/// `ZStudyOntology` — description **en données** d'un contexte pédagogique,
/// et les deux primitives pures qui la lisent.
///
/// Une ontologie déclare les types disponibles par famille, les vocabulaires,
/// et les règles de contenance. Elle n'est **jamais obligatoire** : partout où
/// une primitive en accepte une, `null` signifie « aucune contrainte » et rend
/// systématiquement un succès. C'est la même règle que pour `workspaceId` ou
/// `organizationId` : l'absence est un état valide, jamais une donnée
/// manquante à combler.
///
/// Le noyau ne teste jamais un type concret. `zValidatePlacement` raisonne sur
/// les **capacités** et sur les listes d'autorisation déclarées ;
/// `zHasCapability` répond sur un type nommé. Une ontologie qui décrit un
/// contexte que personne n'avait prévu fonctionne donc sans modification du
/// socle.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_constants.dart';
import 'z_study_json.dart';
import 'z_study_kind_spec.dart';
import 'z_study_vocabulary.dart';

/// Nom que porte un vocabulaire lorsqu'il est **déclaré dans une ontologie**.
///
/// C'est exactement une [ZStudyVocabulary] : une ontologie n'ajoute rien à un
/// vocabulaire, elle le rend disponible. L'alias existe pour que la lecture
/// d'une ontologie nomme ce qu'elle contient.
typedef ZStudyVocabularySpec = ZStudyVocabulary;

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Description immuable d'un contexte pédagogique.
class ZStudyOntology {
  /// Construit une ontologie.
  const ZStudyOntology({
    this.version = '',
    this.organizationKinds = const <ZStudyKindSpec>[],
    this.orgUnitKinds = const <ZStudyKindSpec>[],
    this.groupKinds = const <ZStudyKindSpec>[],
    this.programKinds = const <ZStudyKindSpec>[],
    this.periodKinds = const <ZStudyKindSpec>[],
    this.courseKinds = const <ZStudyKindSpec>[],
    this.topicKinds = const <ZStudyKindSpec>[],
    this.vocabularies = const <ZStudyVocabularySpec>[],
    this.containmentRules = const <ZStudyContainmentRule>[],
    this.displayRules,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyOntology.fromMap(Map<String, dynamic> map) {
    List<ZStudyKindSpec> kinds(String key) =>
        zStudyDecodeList<ZStudyKindSpec>(map[key], ZStudyKindSpec.fromMap);
    final display = zStudyAsJsonMap(map['display_rules']);
    return ZStudyOntology(
      version: zJsonString(map['version']),
      organizationKinds: kinds('organization_kinds'),
      orgUnitKinds: kinds('org_unit_kinds'),
      groupKinds: kinds('group_kinds'),
      programKinds: kinds('program_kinds'),
      periodKinds: kinds('period_kinds'),
      courseKinds: kinds('course_kinds'),
      topicKinds: kinds('topic_kinds'),
      vocabularies: zStudyDecodeList<ZStudyVocabularySpec>(
        map['vocabularies'],
        ZStudyVocabulary.fromMap,
      ),
      containmentRules: zStudyDecodeList<ZStudyContainmentRule>(
        map['containment_rules'],
        ZStudyContainmentRule.fromMap,
      ),
      displayRules: display == null
          ? null
          : ZStudyDisplayRules.fromMap(display),
    );
  }

  /// Version de l'ontologie — chaîne opaque, défaut `''`.
  final String version;

  /// Types d'organisation déclarés.
  final List<ZStudyKindSpec> organizationKinds;

  /// Types d'unité d'organisation déclarés.
  final List<ZStudyKindSpec> orgUnitKinds;

  /// Types de groupe déclarés.
  final List<ZStudyKindSpec> groupKinds;

  /// Types de programme déclarés.
  final List<ZStudyKindSpec> programKinds;

  /// Types de période déclarés.
  final List<ZStudyKindSpec> periodKinds;

  /// Types de cours déclarés.
  final List<ZStudyKindSpec> courseKinds;

  /// Types de thème déclarés.
  final List<ZStudyKindSpec> topicKinds;

  /// Vocabulaires déclarés.
  final List<ZStudyVocabularySpec> vocabularies;

  /// Règles de contenance inter-registres.
  final List<ZStudyContainmentRule> containmentRules;

  /// Préférences d'affichage, `null` si aucune.
  final ZStudyDisplayRules? displayRules;

  /// Tous les types déclarés, registres concaténés dans un ordre stable.
  List<ZStudyKindSpec> get allKinds => <ZStudyKindSpec>[
    ...organizationKinds,
    ...orgUnitKinds,
    ...groupKinds,
    ...programKinds,
    ...periodKinds,
    ...courseKinds,
    ...topicKinds,
  ];

  /// Spécification du type [kind], ou `null` si l'ontologie ne le déclare pas.
  ///
  /// Rendre `null` ne rend pas le type invalide : un type non déclaré traverse
  /// toute la (dé)sérialisation et n'est simplement soumis à aucune règle.
  ZStudyKindSpec? kindSpec(String kind) {
    for (final spec in allKinds) {
      if (spec.key == kind) return spec;
    }
    return null;
  }

  /// Vocabulaire de clé [key], ou `null` si non déclaré.
  ZStudyVocabularySpec? vocabulary(String key) {
    for (final spec in vocabularies) {
      if (spec.key == key) return spec;
    }
    return null;
  }

  /// Sérialise vers la map persistée ; une collection vide n'écrit pas de clé.
  Map<String, dynamic> toMap() {
    Map<String, dynamic> map = <String, dynamic>{'version': version};
    void put(String key, List<ZStudyKindSpec> kinds) {
      if (kinds.isNotEmpty) {
        map[key] = zStudyEncodeList(kinds, (ZStudyKindSpec s) => s.toMap());
      }
    }

    put('organization_kinds', organizationKinds);
    put('org_unit_kinds', orgUnitKinds);
    put('group_kinds', groupKinds);
    put('program_kinds', programKinds);
    put('period_kinds', periodKinds);
    put('course_kinds', courseKinds);
    put('topic_kinds', topicKinds);
    if (vocabularies.isNotEmpty) {
      map['vocabularies'] = zStudyEncodeList(
        vocabularies,
        (ZStudyVocabularySpec v) => v.toMap(),
      );
    }
    if (containmentRules.isNotEmpty) {
      map['containment_rules'] = zStudyEncodeList(
        containmentRules,
        (ZStudyContainmentRule r) => r.toMap(),
      );
    }
    if (displayRules != null) map['display_rules'] = displayRules!.toMap();
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyOntology copyWith({
    Object? version = _undefined,
    Object? organizationKinds = _undefined,
    Object? orgUnitKinds = _undefined,
    Object? groupKinds = _undefined,
    Object? programKinds = _undefined,
    Object? periodKinds = _undefined,
    Object? courseKinds = _undefined,
    Object? topicKinds = _undefined,
    Object? vocabularies = _undefined,
    Object? containmentRules = _undefined,
    Object? displayRules = _undefined,
  }) => ZStudyOntology(
    version: identical(version, _undefined) ? this.version : version as String,
    organizationKinds: identical(organizationKinds, _undefined)
        ? this.organizationKinds
        : organizationKinds as List<ZStudyKindSpec>,
    orgUnitKinds: identical(orgUnitKinds, _undefined)
        ? this.orgUnitKinds
        : orgUnitKinds as List<ZStudyKindSpec>,
    groupKinds: identical(groupKinds, _undefined)
        ? this.groupKinds
        : groupKinds as List<ZStudyKindSpec>,
    programKinds: identical(programKinds, _undefined)
        ? this.programKinds
        : programKinds as List<ZStudyKindSpec>,
    periodKinds: identical(periodKinds, _undefined)
        ? this.periodKinds
        : periodKinds as List<ZStudyKindSpec>,
    courseKinds: identical(courseKinds, _undefined)
        ? this.courseKinds
        : courseKinds as List<ZStudyKindSpec>,
    topicKinds: identical(topicKinds, _undefined)
        ? this.topicKinds
        : topicKinds as List<ZStudyKindSpec>,
    vocabularies: identical(vocabularies, _undefined)
        ? this.vocabularies
        : vocabularies as List<ZStudyVocabularySpec>,
    containmentRules: identical(containmentRules, _undefined)
        ? this.containmentRules
        : containmentRules as List<ZStudyContainmentRule>,
    displayRules: identical(displayRules, _undefined)
        ? this.displayRules
        : displayRules as ZStudyDisplayRules?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyOntology &&
          version == other.version &&
          zStudyListEquals(organizationKinds, other.organizationKinds) &&
          zStudyListEquals(orgUnitKinds, other.orgUnitKinds) &&
          zStudyListEquals(groupKinds, other.groupKinds) &&
          zStudyListEquals(programKinds, other.programKinds) &&
          zStudyListEquals(periodKinds, other.periodKinds) &&
          zStudyListEquals(courseKinds, other.courseKinds) &&
          zStudyListEquals(topicKinds, other.topicKinds) &&
          zStudyListEquals(vocabularies, other.vocabularies) &&
          zStudyListEquals(containmentRules, other.containmentRules) &&
          displayRules == other.displayRules;

  @override
  int get hashCode => Object.hashAll(<Object?>[
    version,
    Object.hashAll(organizationKinds),
    Object.hashAll(orgUnitKinds),
    Object.hashAll(groupKinds),
    Object.hashAll(programKinds),
    Object.hashAll(periodKinds),
    Object.hashAll(courseKinds),
    Object.hashAll(topicKinds),
    Object.hashAll(vocabularies),
    Object.hashAll(containmentRules),
    displayRules,
  ]);
}

/// `true` si le type [kind] porte [capability] selon [ontology].
///
/// **Ontologie `null`, ou type non déclaré ⇒ `true`.** Une capacité que
/// personne n'a déclarée n'est pas une capacité refusée : sans ontologie, le
/// socle ne restreint rien.
bool zHasCapability(ZStudyOntology? ontology, String kind, String capability) {
  if (ontology == null) return true;
  final spec = ontology.kindSpec(kind);
  if (spec == null) return true;
  return spec.hasCapability(capability);
}

/// Valide le placement de [child] sous [parentKindSpec].
///
/// Rend `Right(unit)` si le placement est permis, `Left(ZDomainFailure)`
/// sinon. Pure : ni horloge, ni entrée/sortie.
///
/// Ordre exact des décisions, au premier échec :
/// 1. [ontology] `null` ⇒ `Right` — aucune contrainte déclarée ;
/// 2. [parentKindSpec] `null` (placement à la racine) ⇒ `Right` ;
/// 3. [child] sans la capacité `hierarchical` ⇒ `Left` — un type qui n'admet
///    pas de parent ne peut pas en recevoir un ;
/// 4. [ZStudyKindSpec.allowedParentKinds] de [child] non vide et ne contenant
///    pas le parent ⇒ `Left` ;
/// 5. [ZStudyKindSpec.allowedChildKinds] du parent non vide et ne contenant
///    pas [child] ⇒ `Left` ;
/// 6. si au moins une règle de contenance couvre le type de [child] et
///    qu'aucune de ces règles n'autorise ce parent ⇒ `Left` ;
/// 7. si une règle applicable borne la profondeur et que [depth] la dépasse
///    ⇒ `Left`.
///
/// [depth] est la profondeur visée de l'enfant (racine = `0`) ; omise, aucune
/// borne de profondeur n'est évaluée.
ZResult<Unit> zValidatePlacement(
  ZStudyOntology? ontology,
  ZStudyKindSpec? parentKindSpec,
  ZStudyKindSpec child, {
  int? depth,
}) {
  if (ontology == null) return const Right<ZFailure, Unit>(unit);
  if (parentKindSpec == null) return const Right<ZFailure, Unit>(unit);

  if (!child.hasCapability(kZStudyCapabilityHierarchical)) {
    return Left<ZFailure, Unit>(
      ZDomainFailure(
        'Le type « ${child.key} » ne déclare pas la capacité '
        '« $kZStudyCapabilityHierarchical » : il ne peut pas recevoir de '
        'parent.',
      ),
    );
  }
  if (child.allowedParentKinds.isNotEmpty &&
      !child.allowedParentKinds.contains(parentKindSpec.key)) {
    return Left<ZFailure, Unit>(
      ZDomainFailure(
        'Le type « ${child.key} » n\'autorise pas le parent '
        '« ${parentKindSpec.key} ».',
      ),
    );
  }
  if (parentKindSpec.allowedChildKinds.isNotEmpty &&
      !parentKindSpec.allowedChildKinds.contains(child.key)) {
    return Left<ZFailure, Unit>(
      ZDomainFailure(
        'Le type « ${parentKindSpec.key} » n\'accepte pas l\'enfant '
        '« ${child.key} ».',
      ),
    );
  }

  final covering = <ZStudyContainmentRule>[
    for (final rule in ontology.containmentRules)
      if (rule.coversChild(child.key)) rule,
  ];
  if (covering.isNotEmpty) {
    final allowing = <ZStudyContainmentRule>[
      for (final rule in covering)
        if (rule.allowsParent(parentKindSpec.key)) rule,
    ];
    if (allowing.isEmpty) {
      return Left<ZFailure, Unit>(
        ZDomainFailure(
          'Aucune règle de contenance n\'autorise « ${child.key} » sous '
          '« ${parentKindSpec.key} ».',
        ),
      );
    }
    if (depth != null) {
      // Les règles sont des permissions : il suffit qu'UNE règle applicable
      // tolère la profondeur visée pour que le placement passe.
      final tolerated = allowing.any(
        (ZStudyContainmentRule rule) =>
            rule.maxDepth == null || depth <= rule.maxDepth!,
      );
      if (!tolerated) {
        return Left<ZFailure, Unit>(
          ZDomainFailure(
            'La profondeur $depth dépasse la borne déclarée pour '
            '« ${child.key} ».',
          ),
        );
      }
    }
  }
  return const Right<ZFailure, Unit>(unit);
}

/// Valide qu'un type peut porter une classification du vocabulaire
/// [vocabularyKey].
///
/// Rend `Right(unit)` si l'usage est permis, `Left(ZDomainFailure)` sinon :
/// - [ontology] `null`, ou type non déclaré ⇒ `Right` ;
/// - [ZStudyKindSpec.allowedVocabularyKeys] vide ⇒ `Right` (aucune
///   restriction) ;
/// - vocabulaire absent de cette liste ⇒ `Left`.
///
/// La **valeur** affectée n'est jamais validée : un `valueKey` non déclaré par
/// le vocabulaire reste valide et round-trippe intact.
ZResult<Unit> zValidateVocabularyUse(
  ZStudyOntology? ontology,
  String kind,
  String vocabularyKey,
) {
  if (ontology == null) return const Right<ZFailure, Unit>(unit);
  final spec = ontology.kindSpec(kind);
  if (spec == null) return const Right<ZFailure, Unit>(unit);
  if (spec.allowedVocabularyKeys.isEmpty) {
    return const Right<ZFailure, Unit>(unit);
  }
  if (spec.allowedVocabularyKeys.contains(vocabularyKey)) {
    return const Right<ZFailure, Unit>(unit);
  }
  return Left<ZFailure, Unit>(
    ZDomainFailure(
      'Le type « $kind » n\'autorise pas le vocabulaire « $vocabularyKey ».',
    ),
  );
}
