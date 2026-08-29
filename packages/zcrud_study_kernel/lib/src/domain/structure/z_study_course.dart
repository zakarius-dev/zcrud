/// Entité `ZStudyCourse` — cours du catalogue : ce qui est enseignable,
/// indépendamment de toute occurrence concrète.
///
/// Un cours n'a ni horaire, ni public, ni intervenant : ces données
/// appartiennent à l'offre qui le concrétise. C'est ce qui permet de décrire
/// une fois un cours et de l'ouvrir dix fois.
///
/// [credits] et [expectedHours] sont des nombres **indicatifs** : le noyau ne
/// les additionne pas et n'en dérive aucune règle de validation de parcours.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_course.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyCourseExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Cours immuable du catalogue.
@ZcrudModel(kind: 'study_course', fieldRename: ZFieldRename.snake)
class ZStudyCourse extends ZEntity with ZExtensible {
  /// Construit un cours.
  const ZStudyCourse({
    this.id,
    this.organizationId,
    this.subjectId,
    this.kind = '',
    this.code,
    this.label = '',
    this.credits,
    this.expectedHours,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyCourse.fromMap(
    Map<String, dynamic> map, {
    ZStudyCourseExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyCourseFromMap(map);
    return ZStudyCourse(
      id: base.id,
      organizationId: base.organizationId,
      subjectId: base.subjectId,
      kind: base.kind,
      code: base.code,
      label: base.label,
      credits: base.credits,
      expectedHours: base.expectedHours,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Organisation porteuse, `null` si le cours n'en dépend d'aucune.
  @ZcrudField()
  final String? organizationId;

  /// Matière du cours (identifiant opaque), `null` si non rattaché.
  @ZcrudField()
  final String? subjectId;

  /// Type de cours — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Crédits indicatifs, `null` si non déclarés.
  @ZcrudField()
  final double? credits;

  /// Volume horaire indicatif, `null` si non déclaré.
  @ZcrudField()
  final double? expectedHours;

  /// Identifiants du cours dans des systèmes tiers, défaut `const []`.
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
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyCourseZcrud(this).toMap()),
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
  ZStudyCourse copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? subjectId = _$undefined,
    Object? kind = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? credits = _$undefined,
    Object? expectedHours = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyCourse(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    subjectId: identical(subjectId, _$undefined)
        ? this.subjectId
        : subjectId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    credits: identical(credits, _$undefined)
        ? this.credits
        : credits as double?,
    expectedHours: identical(expectedHours, _$undefined)
        ? this.expectedHours
        : expectedHours as double?,
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
    for (final spec in $ZStudyCourseFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyCourse &&
          id == other.id &&
          organizationId == other.organizationId &&
          subjectId == other.subjectId &&
          kind == other.kind &&
          code == other.code &&
          label == other.label &&
          credits == other.credits &&
          expectedHours == other.expectedHours &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    subjectId,
    kind,
    code,
    label,
    credits,
    expectedHours,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
