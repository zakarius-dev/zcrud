/// `ZStudyContext` — position résolue dans la structure d'étude.
///
/// 🔴 **Ceci est un READ MODEL. Ce n'est jamais une source de vérité.**
/// Chaque champ est **dérivé** d'enregistrements qui, eux, font foi : les
/// offres, les cours, les périodes, les audiences, les classifications. Un
/// contexte se recalcule intégralement à partir d'un instantané ; il ne se
/// modifie pas, et le modifier ne changerait rien à la structure.
///
/// [toMap] existe pour la **matérialisation** — l'écrire à côté d'un document
/// pour le rendre requêtable sans jointure, ou le transporter d'un écran à
/// l'autre. Un contexte matérialisé est un **cache** : il peut être périmé, il
/// se réécrit sans migration, et rien ne doit jamais être décidé sur sa seule
/// foi quand la source est disponible.
///
/// Les chemins ([organizationPath], [orgUnitPath], [periodPath]) vont de la
/// **racine vers la cible**, cible incluse — c'est l'ordre d'un fil
/// d'Ariane. Les listes non hiérarchiques ([programRefs], [groupRefs]) sont
/// dans l'ordre de l'instantané qui les a produites.
///
/// [classifications] projette les valeurs de vocabulaire portées par les
/// éléments du contexte : `vocabularyKey → valeurs`, dédoublonnées et triées.
/// C'est une projection, pas l'historique — les enregistrements
/// `ZStudyClassification` gardent les dates, celle-ci ne garde que ce qui vaut
/// pour le contexte demandé.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';
import 'z_study_ref.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Position résolue et immuable dans la structure d'étude.
class ZStudyContext {
  /// Construit un contexte. Tous les axes sont facultatifs — un contexte
  /// entièrement vide est valide (mode personnel, sans organisation).
  const ZStudyContext({
    this.organizationPath = const <ZStudyRef>[],
    this.orgUnitPath = const <ZStudyRef>[],
    this.programRefs = const <ZStudyRef>[],
    this.groupRefs = const <ZStudyRef>[],
    this.periodPath = const <ZStudyRef>[],
    this.subjectRef,
    this.courseRef,
    this.offeringRef,
    this.curriculumRef,
    this.classifications = const <String, List<String>>{},
  });

  /// Reconstruit défensivement depuis une map matérialisée (invariant AD-10).
  ///
  /// Toute valeur illisible retombe sur l'absence : un contexte matérialisé
  /// corrompu se relit en contexte partiel, jamais en levée.
  factory ZStudyContext.fromMap(Map<String, dynamic> map) => ZStudyContext(
    organizationPath: zStudyDecodeRefs(map['organization_path']),
    orgUnitPath: zStudyDecodeRefs(map['org_unit_path']),
    programRefs: zStudyDecodeRefs(map['program_refs']),
    groupRefs: zStudyDecodeRefs(map['group_refs']),
    periodPath: zStudyDecodeRefs(map['period_path']),
    subjectRef: _refOrNull(map['subject_ref']),
    courseRef: _refOrNull(map['course_ref']),
    offeringRef: _refOrNull(map['offering_ref']),
    curriculumRef: _refOrNull(map['curriculum_ref']),
    classifications: _decodeClassifications(map['classifications']),
  );

  /// Chaîne des organisations, racine d'abord, cible incluse.
  final List<ZStudyRef> organizationPath;

  /// Chaîne des unités d'organisation, racine d'abord, cible incluse.
  ///
  /// Vide quand le porteur résolu est une organisation et non une unité —
  /// l'absence est une réponse, pas un manque.
  final List<ZStudyRef> orgUnitPath;

  /// Programmes atteints par le contexte, dans l'ordre de l'instantané.
  final List<ZStudyRef> programRefs;

  /// Groupes atteints par le contexte, dans l'ordre de l'instantané.
  final List<ZStudyRef> groupRefs;

  /// Chaîne des périodes, racine d'abord, cible incluse.
  final List<ZStudyRef> periodPath;

  /// Matière du contexte, `null` si aucune n'est prouvable.
  final ZStudyRef? subjectRef;

  /// Cours du contexte, `null` si aucun n'est prouvable.
  final ZStudyRef? courseRef;

  /// Offre à l'origine du contexte, `null` si le contexte n'en vient pas.
  final ZStudyRef? offeringRef;

  /// Curriculum suivi, `null` si aucun n'est déclaré.
  final ZStudyRef? curriculumRef;

  /// Valeurs de vocabulaire portées par le contexte, dédoublonnées et triées.
  final Map<String, List<String>> classifications;

  /// Toutes les références du contexte, dédoublonnées, dans un ordre stable :
  /// organisations, unités, programmes, groupes, périodes, puis matière,
  /// cours, offre et curriculum.
  ///
  /// C'est la liste que consultent les primitives de visibilité : y figurer,
  /// c'est être « dans » le contexte.
  List<ZStudyRef> get refs {
    final out = <ZStudyRef>[];
    final seen = <String>{};
    void add(ZStudyRef? ref) {
      if (ref == null) return;
      // Préfixe de longueur : encodage injectif, donc aucune collision
      // possible entre un type et un identifiant contenant le séparateur.
      if (seen.add('${ref.type.length}:${ref.type}:${ref.id}')) out.add(ref);
    }

    organizationPath.forEach(add);
    orgUnitPath.forEach(add);
    programRefs.forEach(add);
    groupRefs.forEach(add);
    periodPath.forEach(add);
    add(subjectRef);
    add(courseRef);
    add(offeringRef);
    add(curriculumRef);
    return List<ZStudyRef>.unmodifiable(out);
  }

  /// `true` si [ref] fait partie du contexte — comparaison sur l'identité
  /// seule (`type` + `id`), l'instantané d'affichage n'entre jamais en compte.
  bool contains(ZStudyRef ref) {
    for (final candidate in refs) {
      if (candidate.sameTarget(ref)) return true;
    }
    return false;
  }

  /// `true` si le contexte ne prouve rien du tout (mode personnel).
  bool get isEmpty => refs.isEmpty && classifications.isEmpty;

  /// Sérialise vers une map matérialisable ; un axe vide n'écrit pas de clé.
  ///
  /// Rappel de contrat : ce que produit cette méthode est un **cache**
  /// reconstructible, jamais une source de vérité.
  Map<String, dynamic> toMap() => <String, dynamic>{
    if (organizationPath.isNotEmpty)
      'organization_path': _encode(organizationPath),
    if (orgUnitPath.isNotEmpty) 'org_unit_path': _encode(orgUnitPath),
    if (programRefs.isNotEmpty) 'program_refs': _encode(programRefs),
    if (groupRefs.isNotEmpty) 'group_refs': _encode(groupRefs),
    if (periodPath.isNotEmpty) 'period_path': _encode(periodPath),
    if (subjectRef != null) 'subject_ref': subjectRef!.toMap(),
    if (courseRef != null) 'course_ref': courseRef!.toMap(),
    if (offeringRef != null) 'offering_ref': offeringRef!.toMap(),
    if (curriculumRef != null) 'curriculum_ref': curriculumRef!.toMap(),
    if (classifications.isNotEmpty)
      'classifications': <String, dynamic>{
        for (final entry in classifications.entries)
          entry.key: List<String>.of(entry.value),
      },
  };

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyContext copyWith({
    Object? organizationPath = _undefined,
    Object? orgUnitPath = _undefined,
    Object? programRefs = _undefined,
    Object? groupRefs = _undefined,
    Object? periodPath = _undefined,
    Object? subjectRef = _undefined,
    Object? courseRef = _undefined,
    Object? offeringRef = _undefined,
    Object? curriculumRef = _undefined,
    Object? classifications = _undefined,
  }) => ZStudyContext(
    organizationPath: identical(organizationPath, _undefined)
        ? this.organizationPath
        : organizationPath as List<ZStudyRef>,
    orgUnitPath: identical(orgUnitPath, _undefined)
        ? this.orgUnitPath
        : orgUnitPath as List<ZStudyRef>,
    programRefs: identical(programRefs, _undefined)
        ? this.programRefs
        : programRefs as List<ZStudyRef>,
    groupRefs: identical(groupRefs, _undefined)
        ? this.groupRefs
        : groupRefs as List<ZStudyRef>,
    periodPath: identical(periodPath, _undefined)
        ? this.periodPath
        : periodPath as List<ZStudyRef>,
    subjectRef: identical(subjectRef, _undefined)
        ? this.subjectRef
        : subjectRef as ZStudyRef?,
    courseRef: identical(courseRef, _undefined)
        ? this.courseRef
        : courseRef as ZStudyRef?,
    offeringRef: identical(offeringRef, _undefined)
        ? this.offeringRef
        : offeringRef as ZStudyRef?,
    curriculumRef: identical(curriculumRef, _undefined)
        ? this.curriculumRef
        : curriculumRef as ZStudyRef?,
    classifications: identical(classifications, _undefined)
        ? this.classifications
        : classifications as Map<String, List<String>>,
  );

  static List<Map<String, dynamic>> _encode(List<ZStudyRef> refs) =>
      zStudyEncodeList(refs, (ZStudyRef ref) => ref.toMap());

  static ZStudyRef? _refOrNull(Object? raw) {
    final map = zStudyAsJsonMap(raw);
    return map == null ? null : ZStudyRef.fromMap(map);
  }

  static Map<String, List<String>> _decodeClassifications(Object? raw) {
    final map = zStudyAsJsonMap(raw);
    if (map == null) return const <String, List<String>>{};
    final out = <String, List<String>>{};
    for (final entry in map.entries) {
      final values = zJsonStringList(entry.value);
      if (values == null) continue;
      out[entry.key] = List<String>.unmodifiable(values);
    }
    return Map<String, List<String>>.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyContext &&
          zStudyListEquals(organizationPath, other.organizationPath) &&
          zStudyListEquals(orgUnitPath, other.orgUnitPath) &&
          zStudyListEquals(programRefs, other.programRefs) &&
          zStudyListEquals(groupRefs, other.groupRefs) &&
          zStudyListEquals(periodPath, other.periodPath) &&
          subjectRef == other.subjectRef &&
          courseRef == other.courseRef &&
          offeringRef == other.offeringRef &&
          curriculumRef == other.curriculumRef &&
          _classificationsEqual(classifications, other.classifications);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    Object.hashAll(organizationPath),
    Object.hashAll(orgUnitPath),
    Object.hashAll(programRefs),
    Object.hashAll(groupRefs),
    Object.hashAll(periodPath),
    subjectRef,
    courseRef,
    offeringRef,
    curriculumRef,
    Object.hashAll(<Object?>[
      for (final key in classifications.keys.toList()..sort())
        Object.hash(key, Object.hashAll(classifications[key]!)),
    ]),
  ]);

  static bool _classificationsEqual(
    Map<String, List<String>> a,
    Map<String, List<String>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null) return false;
      if (!zStringListEquals(entry.value, other)) return false;
    }
    return true;
  }
}
