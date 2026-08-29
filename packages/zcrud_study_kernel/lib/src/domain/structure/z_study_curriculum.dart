/// Entité `ZStudyCurriculum` — la progression prévue, versionnée et datée.
///
/// Un curriculum dit **ce qui doit être traité et dans quel ordre**. Il ne dit
/// ni qui l'enseigne, ni quand la séance a lieu : cela relève de l'offre
/// (`ZStudyOffering`) et des séances. Une offre **suit** un curriculum ; deux
/// offres du même cours peuvent en suivre deux versions différentes, et c'est
/// exactement pourquoi le curriculum est une entité séparée du cours.
///
/// **[version] est une chaîne opaque**, jamais comparée ni ordonnée par le
/// noyau : les hôtes numérotent leurs référentiels de façons irréconciliables
/// (« 2024 », « v3.1 », « rév. B »). Ce qui ordonne, ce sont
/// [effectiveFrom] / [effectiveTo] — un intervalle **semi-ouvert**
/// `[effectiveFrom, effectiveTo)`, borne absente = non bornée de ce côté.
///
/// Les quatre rattachements ([organizationId], [subjectId], [courseId],
/// [programId]) sont **tous facultatifs et indépendants** : un référentiel
/// national n'a pas d'organisation, un référentiel maison n'a pas de
/// programme, et un curriculum peut porter sur une matière sans se limiter à
/// un cours.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_constants.dart';
import 'z_study_json.dart';

part 'z_study_curriculum.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyCurriculumExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Curriculum immuable.
@ZcrudModel(kind: 'study_curriculum', fieldRename: ZFieldRename.snake)
class ZStudyCurriculum extends ZEntity with ZExtensible {
  /// Construit un curriculum.
  const ZStudyCurriculum({
    this.id,
    this.organizationId,
    this.subjectId,
    this.courseId,
    this.programId,
    this.code,
    this.label = '',
    this.version = '',
    this.status = kZStudyStatusActive,
    this.effectiveFrom,
    this.effectiveTo,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Un `status` absent ou illisible retombe sur `active` ; une valeur inconnue
  /// est conservée telle quelle.
  factory ZStudyCurriculum.fromMap(
    Map<String, dynamic> map, {
    ZStudyCurriculumExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyCurriculumFromMap(map);
    return ZStudyCurriculum(
      id: base.id,
      organizationId: base.organizationId,
      subjectId: base.subjectId,
      courseId: base.courseId,
      programId: base.programId,
      code: base.code,
      label: base.label,
      version: base.version,
      status: zJsonString(map['status'], kZStudyStatusActive),
      effectiveFrom: base.effectiveFrom,
      effectiveTo: base.effectiveTo,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Organisation propriétaire, `null` pour un référentiel qui n'en a pas.
  @ZcrudField()
  final String? organizationId;

  /// Matière couverte, `null` si le référentiel n'en cible aucune.
  @ZcrudField()
  final String? subjectId;

  /// Cours couvert, `null` si le référentiel n'en cible aucun.
  @ZcrudField()
  final String? courseId;

  /// Programme d'appartenance, `null` si le référentiel n'en dépend d'aucun.
  @ZcrudField()
  final String? programId;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Version — chaîne opaque, défaut `''`. Ni comparée, ni ordonnée.
  @ZcrudField()
  final String version;

  /// Statut de cycle de vie — chaîne opaque, défaut `active`.
  @ZcrudField()
  final String status;

  /// Début d'applicabilité inclus, `null` si non borné.
  @ZcrudField()
  final DateTime? effectiveFrom;

  /// Fin d'applicabilité exclue, `null` si non bornée.
  @ZcrudField()
  final DateTime? effectiveTo;

  /// Identifiants du curriculum dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si [status] vaut `archived`. Sans effet sur ce qui s'y rattache.
  bool get isArchived => status == kZStudyStatusArchived;

  /// `true` si le curriculum s'applique à [instant], sur l'intervalle
  /// semi-ouvert `[effectiveFrom, effectiveTo)`.
  ///
  /// Ne consulte pas [status] : applicabilité et cycle de vie sont deux axes
  /// indépendants, et les mêler ferait disparaître un référentiel archivé de
  /// l'historique qu'il documente.
  bool isEffectiveAt(DateTime instant) {
    if (effectiveFrom != null && instant.isBefore(effectiveFrom!)) return false;
    if (effectiveTo != null && !instant.isBefore(effectiveTo!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyCurriculumZcrud(this).toMap()),
    };
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
  ZStudyCurriculum copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? subjectId = _$undefined,
    Object? courseId = _$undefined,
    Object? programId = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? version = _$undefined,
    Object? status = _$undefined,
    Object? effectiveFrom = _$undefined,
    Object? effectiveTo = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyCurriculum(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    subjectId: identical(subjectId, _$undefined)
        ? this.subjectId
        : subjectId as String?,
    courseId: identical(courseId, _$undefined)
        ? this.courseId
        : courseId as String?,
    programId: identical(programId, _$undefined)
        ? this.programId
        : programId as String?,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    version: identical(version, _$undefined) ? this.version : version as String,
    status: identical(status, _$undefined) ? this.status : status as String,
    effectiveFrom: identical(effectiveFrom, _$undefined)
        ? this.effectiveFrom
        : effectiveFrom as DateTime?,
    effectiveTo: identical(effectiveTo, _$undefined)
        ? this.effectiveTo
        : effectiveTo as DateTime?,
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
    for (final spec in $ZStudyCurriculumFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyCurriculum &&
          id == other.id &&
          organizationId == other.organizationId &&
          subjectId == other.subjectId &&
          courseId == other.courseId &&
          programId == other.programId &&
          code == other.code &&
          label == other.label &&
          version == other.version &&
          status == other.status &&
          effectiveFrom == other.effectiveFrom &&
          effectiveTo == other.effectiveTo &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    subjectId,
    courseId,
    programId,
    code,
    label,
    version,
    status,
    effectiveFrom,
    effectiveTo,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
