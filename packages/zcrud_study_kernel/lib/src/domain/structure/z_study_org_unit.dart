/// Entité `ZStudyOrgUnit` — unité interne d'une organisation (département,
/// service, site…), nœud d'un arbre à profondeur libre.
///
/// Distincte de `ZStudyGroup` : une unité découpe l'**institution**, un groupe
/// rassemble des **personnes**. Les deux sont des arbres, aucun des deux n'est
/// l'autre.
///
/// [kind] est une chaîne opaque ; [parentId] est la vérité de l'arbre et
/// [ancestorIds] sa projection recalculable. [organizationId] vaut `''` quand
/// l'unité n'est rattachée à aucune organisation.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_org_unit.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyOrgUnitExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Unité d'organisation immuable.
@ZcrudModel(kind: 'study_org_unit', fieldRename: ZFieldRename.snake)
class ZStudyOrgUnit extends ZEntity with ZExtensible {
  /// Construit une unité d'organisation.
  const ZStudyOrgUnit({
    this.id,
    this.organizationId = '',
    this.parentId,
    this.kind = '',
    this.label = '',
    this.code,
    this.ancestorIds = const <String>[],
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyOrgUnit.fromMap(
    Map<String, dynamic> map, {
    ZStudyOrgUnitExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyOrgUnitFromMap(map);
    return ZStudyOrgUnit(
      id: base.id,
      organizationId: base.organizationId,
      parentId: base.parentId,
      kind: base.kind,
      label: base.label,
      code: base.code,
      ancestorIds: base.ancestorIds,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Organisation porteuse (identifiant opaque), défaut `''` = non rattachée.
  @ZcrudField()
  final String organizationId;

  /// Unité parente (`null` = racine de l'organisation) — vérité de l'arbre.
  @ZcrudField()
  final String? parentId;

  /// Type d'unité — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Chaîne des ancêtres, racine d'abord — projection recalculable.
  @ZcrudField()
  final List<String> ancestorIds;

  /// Identifiants de l'unité dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Profondeur **dérivée** (`ancestorIds.length`), jamais persistée.
  int get depth => ancestorIds.length;

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyOrgUnitZcrud(this).toMap()),
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
  ZStudyOrgUnit copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? parentId = _$undefined,
    Object? kind = _$undefined,
    Object? label = _$undefined,
    Object? code = _$undefined,
    Object? ancestorIds = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyOrgUnit(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String,
    parentId: identical(parentId, _$undefined)
        ? this.parentId
        : parentId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    label: identical(label, _$undefined) ? this.label : label as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    ancestorIds: identical(ancestorIds, _$undefined)
        ? this.ancestorIds
        : ancestorIds as List<String>,
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
    for (final spec in $ZStudyOrgUnitFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyOrgUnit &&
          id == other.id &&
          organizationId == other.organizationId &&
          parentId == other.parentId &&
          kind == other.kind &&
          label == other.label &&
          code == other.code &&
          zStringListEquals(ancestorIds, other.ancestorIds) &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    parentId,
    kind,
    label,
    code,
    Object.hashAll(ancestorIds),
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
