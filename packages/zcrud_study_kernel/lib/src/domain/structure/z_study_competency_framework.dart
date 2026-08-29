/// Entité `ZStudyCompetencyFramework` — un référentiel de compétences.
///
/// Un cadre regroupe des compétences et leur donne un espace de nommage : deux
/// cadres peuvent porter le même code sans se contredire. C'est ce qui rend
/// possible la coexistence d'un référentiel officiel et d'un référentiel maison
/// sur les mêmes contenus — reliés, s'il y a lieu, par des relations
/// `equivalent`.
///
/// [organizationId] est `null` pour un cadre qui n'appartient à personne (un
/// référentiel public). **[version] est une chaîne opaque**, jamais comparée ni
/// ordonnée : deux cadres de versions différentes sont deux cadres.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_constants.dart';
import 'z_study_json.dart';

part 'z_study_competency_framework.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyCompetencyFrameworkExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Cadre de compétences immuable.
@ZcrudModel(
  kind: 'study_competency_framework',
  fieldRename: ZFieldRename.snake,
)
class ZStudyCompetencyFramework extends ZEntity with ZExtensible {
  /// Construit un cadre de compétences.
  const ZStudyCompetencyFramework({
    this.id,
    this.organizationId,
    this.code,
    this.label = '',
    this.version = '',
    this.status = kZStudyStatusActive,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Un `status` absent ou illisible retombe sur `active` ; une valeur inconnue
  /// est conservée telle quelle.
  factory ZStudyCompetencyFramework.fromMap(
    Map<String, dynamic> map, {
    ZStudyCompetencyFrameworkExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyCompetencyFrameworkFromMap(map);
    return ZStudyCompetencyFramework(
      id: base.id,
      organizationId: base.organizationId,
      code: base.code,
      label: base.label,
      version: base.version,
      status: zJsonString(map['status'], kZStudyStatusActive),
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Organisation propriétaire, `null` pour un cadre qui n'en a pas.
  @ZcrudField()
  final String? organizationId;

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

  /// Identifiants du cadre dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si [status] vaut `archived`. Sans effet sur ses compétences.
  bool get isArchived => status == kZStudyStatusArchived;

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyCompetencyFrameworkZcrud(this).toMap()),
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
  ZStudyCompetencyFramework copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? version = _$undefined,
    Object? status = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyCompetencyFramework(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    version: identical(version, _$undefined) ? this.version : version as String,
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

  /// Clés persistées réservées (schéma généré + canaux manuels + `ZSyncMeta`).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyCompetencyFrameworkFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyCompetencyFramework &&
          id == other.id &&
          organizationId == other.organizationId &&
          code == other.code &&
          label == other.label &&
          version == other.version &&
          status == other.status &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    code,
    label,
    version,
    status,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
