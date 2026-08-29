/// Entité `ZStudyGroup` — groupe : un rassemblement de personnes.
///
/// Le groupe **ne liste pas ses membres** : l'appartenance est portée par des
/// enregistrements de participation distincts, ce qui permet à une même
/// personne d'appartenir à plusieurs groupes, avec des rôles et des dates
/// différents, sans jamais réécrire le groupe.
///
/// [parentGroupId] déclare un arbre de **contenance facultatif** (une cohorte
/// et ses sous-groupes). Il n'implique aucune appartenance transitive : ce
/// qu'un sous-groupe contient reste ce que ses participations disent.
/// [ancestorIds] en est la projection recalculable.
///
/// [status] est une chaîne opaque ; le noyau ne lit que la valeur de repli
/// `active` quand le champ est absent, et n'attache aucun comportement aux
/// autres. Archiver un groupe n'archive jamais ce qui s'y rattache.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_constants.dart';
import 'z_study_json.dart';

part 'z_study_group.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyGroupExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Groupe immuable.
@ZcrudModel(kind: 'study_group', fieldRename: ZFieldRename.snake)
class ZStudyGroup extends ZEntity with ZExtensible {
  /// Construit un groupe.
  const ZStudyGroup({
    this.id,
    this.organizationId,
    this.parentGroupId,
    this.kind = '',
    this.label = '',
    this.code,
    this.status = kZStudyStatusActive,
    this.ancestorIds = const <String>[],
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Un `status` absent ou illisible retombe sur `active` ; une valeur inconnue
  /// est conservée telle quelle.
  factory ZStudyGroup.fromMap(
    Map<String, dynamic> map, {
    ZStudyGroupExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyGroupFromMap(map);
    return ZStudyGroup(
      id: base.id,
      organizationId: base.organizationId,
      parentGroupId: base.parentGroupId,
      kind: base.kind,
      label: base.label,
      code: base.code,
      status: zJsonString(map['status'], kZStudyStatusActive),
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

  /// Organisation porteuse, `null` si le groupe n'en dépend d'aucune.
  @ZcrudField()
  final String? organizationId;

  /// Groupe contenant (`null` = racine) — vérité de l'arbre de contenance.
  @ZcrudField()
  final String? parentGroupId;

  /// Type de groupe — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Statut de cycle de vie — chaîne opaque, défaut `active`.
  @ZcrudField()
  final String status;

  /// Chaîne des groupes contenants, racine d'abord — projection
  /// recalculable.
  @ZcrudField()
  final List<String> ancestorIds;

  /// Identifiants du groupe dans des systèmes tiers, défaut `const []`.
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

  /// `true` si [status] vaut `archived`. Sans effet sur les rattachements.
  bool get isArchived => status == kZStudyStatusArchived;

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyGroupZcrud(this).toMap()),
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
  ZStudyGroup copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? parentGroupId = _$undefined,
    Object? kind = _$undefined,
    Object? label = _$undefined,
    Object? code = _$undefined,
    Object? status = _$undefined,
    Object? ancestorIds = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyGroup(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    parentGroupId: identical(parentGroupId, _$undefined)
        ? this.parentGroupId
        : parentGroupId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    label: identical(label, _$undefined) ? this.label : label as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    status: identical(status, _$undefined) ? this.status : status as String,
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
    for (final spec in $ZStudyGroupFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyGroup &&
          id == other.id &&
          organizationId == other.organizationId &&
          parentGroupId == other.parentGroupId &&
          kind == other.kind &&
          label == other.label &&
          code == other.code &&
          status == other.status &&
          zStringListEquals(ancestorIds, other.ancestorIds) &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    parentGroupId,
    kind,
    label,
    code,
    status,
    Object.hashAll(ancestorIds),
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
