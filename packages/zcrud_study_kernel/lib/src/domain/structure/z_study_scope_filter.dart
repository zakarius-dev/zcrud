/// `ZStudyScopeFilter` — description **pure et persistable** d'une sélection
/// de portée.
///
/// Un filtre est une donnée : il se sérialise, se compare, se transporte d'un
/// écran à l'autre et se stocke comme une vue enregistrée. Son application aux
/// artefacts n'appartient pas à ce type.
///
/// **Sémantique déclarée** : les axes se combinent en **et** (un artefact doit
/// satisfaire chaque axe non vide) ; à l'intérieur d'un axe, les valeurs se
/// combinent en **ou**. Un axe vide ne restreint rien — un filtre entièrement
/// vide sélectionne tout ([isEmpty] est alors `true`).
///
/// [includeDescendants] étend les portées de [scopes] à leurs descendants ;
/// il n'a d'effet que sur des portées hiérarchiques.
library;

import 'package:zcrud_core/domain.dart';

import 'z_study_json.dart';
import 'z_study_ref.dart';

/// Sentinelle de copie : distingue « argument omis » de `null` explicite.
const Object _undefined = Object();

/// Filtre de portée immuable.
class ZStudyScopeFilter {
  /// Construit un filtre. Tous les axes sont facultatifs.
  const ZStudyScopeFilter({
    this.scopes = const <ZStudyRef>[],
    this.includeDescendants = true,
    this.periodIds = const <String>[],
    this.subjectIds = const <String>[],
    this.courseIds = const <String>[],
    this.topicIds = const <String>[],
    this.offeringIds = const <String>[],
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyScopeFilter.fromMap(Map<String, dynamic> map) =>
      ZStudyScopeFilter(
        scopes: zStudyDecodeRefs(map['scopes']),
        includeDescendants: zJsonBool(map['include_descendants'], true),
        periodIds: zJsonStringList(map['period_ids']) ?? const <String>[],
        subjectIds: zJsonStringList(map['subject_ids']) ?? const <String>[],
        courseIds: zJsonStringList(map['course_ids']) ?? const <String>[],
        topicIds: zJsonStringList(map['topic_ids']) ?? const <String>[],
        offeringIds: zJsonStringList(map['offering_ids']) ?? const <String>[],
      );

  /// Portées retenues (`ZStudyScopeRef` : des références dont le type est
  /// scopable), défaut `const []`.
  final List<ZStudyRef> scopes;

  /// Étendre les portées à leurs descendants, défaut `true`.
  final bool includeDescendants;

  /// Périodes retenues (identifiants opaques), défaut `const []`.
  final List<String> periodIds;

  /// Matières retenues (identifiants opaques), défaut `const []`.
  final List<String> subjectIds;

  /// Cours retenus (identifiants opaques), défaut `const []`.
  final List<String> courseIds;

  /// Thèmes retenus (identifiants opaques), défaut `const []`.
  final List<String> topicIds;

  /// Offres retenues (identifiants opaques), défaut `const []`.
  final List<String> offeringIds;

  /// `true` si aucun axe ne restreint quoi que ce soit.
  ///
  /// [includeDescendants] n'entre pas dans ce calcul : il module les portées,
  /// il n'en est pas une.
  bool get isEmpty =>
      scopes.isEmpty &&
      periodIds.isEmpty &&
      subjectIds.isEmpty &&
      courseIds.isEmpty &&
      topicIds.isEmpty &&
      offeringIds.isEmpty;

  /// `true` si [ref] figure parmi les portées retenues (identité seule :
  /// l'instantané d'affichage n'entre jamais dans la décision).
  bool hasScope(ZStudyRef ref) {
    for (final scope in scopes) {
      if (scope.sameTarget(ref)) return true;
    }
    return false;
  }

  /// Sérialise vers la map persistée ; un axe vide n'écrit pas de clé.
  Map<String, dynamic> toMap() => <String, dynamic>{
    if (scopes.isNotEmpty)
      'scopes': zStudyEncodeList(scopes, (ZStudyRef ref) => ref.toMap()),
    'include_descendants': includeDescendants,
    if (periodIds.isNotEmpty) 'period_ids': List<String>.of(periodIds),
    if (subjectIds.isNotEmpty) 'subject_ids': List<String>.of(subjectIds),
    if (courseIds.isNotEmpty) 'course_ids': List<String>.of(courseIds),
    if (topicIds.isNotEmpty) 'topic_ids': List<String>.of(topicIds),
    if (offeringIds.isNotEmpty) 'offering_ids': List<String>.of(offeringIds),
  };

  /// Copie à sentinelle (un argument omis préserve la valeur).
  ZStudyScopeFilter copyWith({
    Object? scopes = _undefined,
    Object? includeDescendants = _undefined,
    Object? periodIds = _undefined,
    Object? subjectIds = _undefined,
    Object? courseIds = _undefined,
    Object? topicIds = _undefined,
    Object? offeringIds = _undefined,
  }) => ZStudyScopeFilter(
    scopes: identical(scopes, _undefined)
        ? this.scopes
        : scopes as List<ZStudyRef>,
    includeDescendants: identical(includeDescendants, _undefined)
        ? this.includeDescendants
        : includeDescendants as bool,
    periodIds: identical(periodIds, _undefined)
        ? this.periodIds
        : periodIds as List<String>,
    subjectIds: identical(subjectIds, _undefined)
        ? this.subjectIds
        : subjectIds as List<String>,
    courseIds: identical(courseIds, _undefined)
        ? this.courseIds
        : courseIds as List<String>,
    topicIds: identical(topicIds, _undefined)
        ? this.topicIds
        : topicIds as List<String>,
    offeringIds: identical(offeringIds, _undefined)
        ? this.offeringIds
        : offeringIds as List<String>,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyScopeFilter &&
          zStudyListEquals(scopes, other.scopes) &&
          includeDescendants == other.includeDescendants &&
          zStringListEquals(periodIds, other.periodIds) &&
          zStringListEquals(subjectIds, other.subjectIds) &&
          zStringListEquals(courseIds, other.courseIds) &&
          zStringListEquals(topicIds, other.topicIds) &&
          zStringListEquals(offeringIds, other.offeringIds);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    Object.hashAll(scopes),
    includeDescendants,
    Object.hashAll(periodIds),
    Object.hashAll(subjectIds),
    Object.hashAll(courseIds),
    Object.hashAll(topicIds),
    Object.hashAll(offeringIds),
  ]);
}
