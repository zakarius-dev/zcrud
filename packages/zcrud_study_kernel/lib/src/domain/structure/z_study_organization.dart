/// Entité `ZStudyOrganization` — organisation, nœud d'un arbre institutionnel
/// à profondeur libre.
///
/// [kind] est une chaîne opaque (registre ouvert, invariant AD-4) : le noyau
/// ne teste jamais un type concret, il raisonne sur les **capacités** déclarées
/// par l'ontologie (`ZStudyOntology`).
///
/// **Arbre** : [parentId] est la vérité ; [ancestorIds] est une **projection
/// recalculable** (racine d'abord), persistée pour permettre les requêtes de
/// sous-arbre, et jamais autoritaire. `zRecomputeAncestorIds` la reconstruit ;
/// [depth] en dérive et n'est jamais persistée.
///
/// **[workspaceId] nullable** : un usage personnel ne déclare aucun espace de
/// travail — l'absence est un état valide.
///
/// **[code] n'est jamais une identité** : deux organisations peuvent porter le
/// même code, et un code peut changer. Seul [id] identifie.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_organization.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyOrganizationExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Organisation immuable.
@ZcrudModel(kind: 'study_organization', fieldRename: ZFieldRename.snake)
class ZStudyOrganization extends ZEntity with ZExtensible {
  /// Construit une organisation.
  const ZStudyOrganization({
    this.id,
    this.workspaceId,
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
  factory ZStudyOrganization.fromMap(
    Map<String, dynamic> map, {
    ZStudyOrganizationExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyOrganizationFromMap(map);
    return ZStudyOrganization(
      id: base.id,
      workspaceId: base.workspaceId,
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

  /// Espace de travail porteur, `null` en usage personnel.
  @ZcrudField()
  final String? workspaceId;

  /// Organisation parente (`null` = racine) — **vérité** de l'arbre.
  @ZcrudField()
  final String? parentId;

  /// Type d'organisation — chaîne opaque, défaut `''`.
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

  /// Identifiants de l'organisation dans des systèmes tiers, défaut
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

  /// Profondeur **dérivée** (`ancestorIds.length`), jamais persistée.
  int get depth => ancestorIds.length;

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyOrganizationZcrud(this).toMap()),
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
  ZStudyOrganization copyWith({
    Object? id = _$undefined,
    Object? workspaceId = _$undefined,
    Object? parentId = _$undefined,
    Object? kind = _$undefined,
    Object? label = _$undefined,
    Object? code = _$undefined,
    Object? ancestorIds = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyOrganization(
    id: identical(id, _$undefined) ? this.id : id as String?,
    workspaceId: identical(workspaceId, _$undefined)
        ? this.workspaceId
        : workspaceId as String?,
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
    for (final spec in $ZStudyOrganizationFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyOrganization &&
          id == other.id &&
          workspaceId == other.workspaceId &&
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
    workspaceId,
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
