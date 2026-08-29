/// Entité `ZStudyProgramCourse` — prescription d'un cours par un programme.
///
/// C'est l'arête du catalogue : elle dit *qu'un* programme prescrit *un* cours,
/// et sous quelles conditions. Elle porte ce qui varie d'un programme à
/// l'autre — obligation, crédits, coefficient, rang — sans jamais modifier le
/// cours lui-même, qui reste partageable entre programmes.
///
/// **[classificationConstraints] restreint la portée de la prescription** :
/// une prescription contrainte ne vaut que pour les cibles portant **toutes**
/// les classifications listées. Une liste vide ne contraint rien. Le noyau
/// transporte ces contraintes comme des données ; il ne les évalue pas ici —
/// l'évaluation appartient à la résolution de contexte.
///
/// [periodPattern] est une chaîne opaque désignant le motif temporel de la
/// prescription. Le noyau ne le parse pas et n'en déduit aucune période.
///
/// La clé persistée de [isRequired] est `is_required` (`required` est un mot
/// réservé du langage).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_classification.dart';
import 'z_study_json.dart';

part 'z_study_program_course.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyProgramCourseExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Prescription immuable d'un cours par un programme.
@ZcrudModel(kind: 'study_program_course', fieldRename: ZFieldRename.snake)
class ZStudyProgramCourse extends ZEntity with ZExtensible {
  /// Construit une prescription.
  const ZStudyProgramCourse({
    this.id,
    this.programId = '',
    this.courseId = '',
    this.periodPattern,
    this.classificationConstraints =
        const <ZStudyClassificationConstraint>[],
    this.isRequired = false,
    this.credits,
    this.coefficient,
    this.order,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyProgramCourse.fromMap(
    Map<String, dynamic> map, {
    ZStudyProgramCourseExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyProgramCourseFromMap(map);
    return ZStudyProgramCourse(
      id: base.id,
      programId: base.programId,
      courseId: base.courseId,
      periodPattern: base.periodPattern,
      classificationConstraints: zStudyDecodeClassificationConstraints(
        map['classification_constraints'],
      ),
      isRequired: base.isRequired,
      credits: base.credits,
      coefficient: base.coefficient,
      order: base.order,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Programme prescripteur (identifiant opaque), défaut `''`.
  @ZcrudField()
  final String programId;

  /// Cours prescrit (identifiant opaque), défaut `''`.
  @ZcrudField()
  final String courseId;

  /// Motif temporel de la prescription — chaîne opaque, `null` si aucun.
  @ZcrudField()
  final String? periodPattern;

  /// Conditions de classification, **toutes** exigées, défaut `const []`.
  @ZcrudIgnore()
  final List<ZStudyClassificationConstraint> classificationConstraints;

  /// Prescription obligatoire, défaut `false` (clé persistée `is_required`).
  @ZcrudField()
  final bool isRequired;

  /// Crédits propres à cette prescription, `null` si ceux du cours valent.
  @ZcrudField()
  final double? credits;

  /// Coefficient de pondération, `null` si non déclaré.
  @ZcrudField()
  final double? coefficient;

  /// Rang d'affichage, `null` si non ordonnée.
  @ZcrudField()
  final int? order;

  /// Identifiants de la prescription dans des systèmes tiers, défaut
  /// `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé, et une liste vide n'écrit pas de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyProgramCourseZcrud(this).toMap()),
    };
    if (classificationConstraints.isNotEmpty) {
      map['classification_constraints'] = zStudyEncodeList(
        classificationConstraints,
        (ZStudyClassificationConstraint c) => c.toMap(),
      );
    }
    if (externalRefs.isNotEmpty) {
      map['external_refs'] = zStudyEncodeList(
        externalRefs,
        (ZExternalRef ref) => ref.toMap(),
      );
    }
    if (extension != null) map['extension'] = extension!.toJson();
    return map;
  }

  /// Copie à sentinelle (un argument omis préserve la valeur, `null` explicite
  /// remet à `null`).
  ZStudyProgramCourse copyWith({
    Object? id = _$undefined,
    Object? programId = _$undefined,
    Object? courseId = _$undefined,
    Object? periodPattern = _$undefined,
    Object? classificationConstraints = _$undefined,
    Object? isRequired = _$undefined,
    Object? credits = _$undefined,
    Object? coefficient = _$undefined,
    Object? order = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyProgramCourse(
    id: identical(id, _$undefined) ? this.id : id as String?,
    programId: identical(programId, _$undefined)
        ? this.programId
        : programId as String,
    courseId: identical(courseId, _$undefined)
        ? this.courseId
        : courseId as String,
    periodPattern: identical(periodPattern, _$undefined)
        ? this.periodPattern
        : periodPattern as String?,
    classificationConstraints: identical(classificationConstraints, _$undefined)
        ? this.classificationConstraints
        : classificationConstraints as List<ZStudyClassificationConstraint>,
    isRequired: identical(isRequired, _$undefined)
        ? this.isRequired
        : isRequired as bool,
    credits: identical(credits, _$undefined)
        ? this.credits
        : credits as double?,
    coefficient: identical(coefficient, _$undefined)
        ? this.coefficient
        : coefficient as double?,
    order: identical(order, _$undefined) ? this.order : order as int?,
    externalRefs: identical(externalRefs, _$undefined)
        ? this.externalRefs
        : externalRefs as List<ZExternalRef>,
    extension: identical(extension, _$undefined)
        ? this.extension
        : extension as ZExtension?,
    extra: identical(extra, _$undefined)
        ? this.extra
        : _sanitizeExtra(extra as Map<String, dynamic>),
  );

  /// Clés persistées réservées (schéma généré + canaux manuels + `ZSyncMeta`).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyProgramCourseFieldSpecs) spec.name,
    'classification_constraints',
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyProgramCourse &&
          id == other.id &&
          programId == other.programId &&
          courseId == other.courseId &&
          periodPattern == other.periodPattern &&
          zStudyListEquals(
            classificationConstraints,
            other.classificationConstraints,
          ) &&
          isRequired == other.isRequired &&
          credits == other.credits &&
          coefficient == other.coefficient &&
          order == other.order &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    programId,
    courseId,
    periodPattern,
    Object.hashAll(classificationConstraints),
    isRequired,
    credits,
    coefficient,
    order,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
