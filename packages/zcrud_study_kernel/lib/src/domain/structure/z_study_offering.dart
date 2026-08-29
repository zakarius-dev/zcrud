/// Entité `ZStudyOffering` — concrétisation datée d'un cours.
///
/// Un cours est un catalogue ; une offre est ce cours **effectivement donné**,
/// une fois, sur une période. C'est la charnière entre ce qui est prévu et ce
/// qui a lieu.
///
/// **Ce que l'offre ne porte pas** : ni l'unité qui la porte, ni la personne
/// qui la conduit, ni les personnes qui la suivent. Ces trois liens sont des
/// **participations** (`ZStudyParticipation`) et des **audiences**
/// (`ZStudyOfferingAudience`), enregistrées à part. Les inscrire ici forcerait
/// une cardinalité que la réalité contredit : deux intervenants, trois
/// cohortes, un remplacement en cours de période — tout cela se dit en
/// ajoutant un enregistrement, jamais en réécrivant l'offre.
///
/// [organizationId] est un **identifiant opaque** : il peut désigner une
/// organisation comme une unité d'organisation. Le noyau ne le devine pas au
/// nom du champ — c'est la résolution de contexte qui le cherche dans les deux
/// registres d'un instantané et rend le chemin correspondant.
///
/// [status] est une chaîne opaque, de repli `active` ; voir les constantes
/// `kZStudyOfferingStatus…`. Aucune n'entraîne de cascade.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_constants.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

part 'z_study_offering.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyOfferingExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Offre immuable.
@ZcrudModel(kind: 'study_offering', fieldRename: ZFieldRename.snake)
class ZStudyOffering extends ZEntity with ZExtensible {
  /// Construit une offre.
  const ZStudyOffering({
    this.id,
    this.organizationId,
    this.courseId = '',
    this.periodId = '',
    this.curriculumId,
    this.label,
    this.code,
    this.status = kZStudyOfferingStatusActive,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Un `status` absent ou illisible retombe sur `active` ; une valeur inconnue
  /// est conservée telle quelle.
  factory ZStudyOffering.fromMap(
    Map<String, dynamic> map, {
    ZStudyOfferingExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyOfferingFromMap(map);
    return ZStudyOffering(
      id: base.id,
      organizationId: base.organizationId,
      courseId: base.courseId,
      periodId: base.periodId,
      curriculumId: base.curriculumId,
      label: base.label,
      code: base.code,
      status: zJsonString(map['status'], kZStudyOfferingStatusActive),
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Porteur de l'offre — identifiant opaque d'une organisation **ou** d'une
  /// unité d'organisation, `null` si l'offre n'en dépend d'aucun.
  @ZcrudField()
  final String? organizationId;

  /// Cours dont l'offre est la concrétisation, défaut `''`.
  @ZcrudField()
  final String courseId;

  /// Période sur laquelle l'offre a lieu, défaut `''`.
  @ZcrudField()
  final String periodId;

  /// Référentiel de progression suivi, `null` si aucun n'est déclaré.
  @ZcrudField()
  final String? curriculumId;

  /// Libellé propre à l'offre, `null` si elle emprunte celui du cours.
  @ZcrudField()
  final String? label;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Statut de l'offre — chaîne opaque, défaut `active`.
  @ZcrudField()
  final String status;

  /// Identifiants de l'offre dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si [status] vaut `archived`. Sans effet sur les rattachements.
  bool get isArchived => status == kZStudyOfferingStatusArchived;

  /// `true` si [status] vaut `cancelled` — l'offre n'a pas eu lieu, ce qui
  /// n'est pas la même chose qu'archivée.
  bool get isCancelled => status == kZStudyOfferingStatusCancelled;

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyOfferingZcrud(this).toMap()),
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
  ZStudyOffering copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? courseId = _$undefined,
    Object? periodId = _$undefined,
    Object? curriculumId = _$undefined,
    Object? label = _$undefined,
    Object? code = _$undefined,
    Object? status = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyOffering(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    courseId: identical(courseId, _$undefined)
        ? this.courseId
        : courseId as String,
    periodId: identical(periodId, _$undefined)
        ? this.periodId
        : periodId as String,
    curriculumId: identical(curriculumId, _$undefined)
        ? this.curriculumId
        : curriculumId as String?,
    label: identical(label, _$undefined) ? this.label : label as String?,
    code: identical(code, _$undefined) ? this.code : code as String?,
    status: identical(status, _$undefined) ? this.status : status as String,
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

  /// Référence vers cette offre, instantané d'affichage compris.
  ///
  /// Une offre éphémère (sans [id]) rend une référence d'identifiant vide :
  /// c'est un état transitoire, pas une erreur.
  ZStudyRef get ref => ZStudyRef(
    type: kZStudyRefTypeOffering,
    id: id ?? '',
    label: label,
    code: code,
  );

  /// Clés persistées réservées (schéma généré + canaux manuels + `ZSyncMeta`).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyOfferingFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyOffering &&
          id == other.id &&
          organizationId == other.organizationId &&
          courseId == other.courseId &&
          periodId == other.periodId &&
          curriculumId == other.curriculumId &&
          label == other.label &&
          code == other.code &&
          status == other.status &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    courseId,
    periodId,
    curriculumId,
    label,
    code,
    status,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
