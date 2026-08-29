/// Entité `ZStudyProgram` — programme : ce qu'on suit sur une durée, et qui
/// prescrit des cours.
///
/// Un programme peut en contenir d'autres ([parentId]) : un tronc commun et
/// ses spécialisations, un diplôme et ses options. [ancestorIds] est la
/// projection recalculable de cet arbre.
///
/// [credentialKind] et [duration] sont des **chaînes opaques** : le noyau ne
/// sait pas ce qu'est un diplôme ni combien de temps dure une année. [duration]
/// accepte aussi bien une durée ISO-8601 (`P3Y`) qu'un jeton propre à
/// l'application ; rien n'est parsé.
///
/// Ce que le programme prescrit vit dans `ZStudyProgramCourse`, jamais ici :
/// un programme ne liste pas ses cours.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_program.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyProgramExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Programme immuable.
@ZcrudModel(kind: 'study_program', fieldRename: ZFieldRename.snake)
class ZStudyProgram extends ZEntity with ZExtensible {
  /// Construit un programme.
  const ZStudyProgram({
    this.id,
    this.organizationId,
    this.parentId,
    this.kind = '',
    this.code,
    this.label = '',
    this.credentialKind,
    this.duration,
    this.ancestorIds = const <String>[],
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyProgram.fromMap(
    Map<String, dynamic> map, {
    ZStudyProgramExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyProgramFromMap(map);
    return ZStudyProgram(
      id: base.id,
      organizationId: base.organizationId,
      parentId: base.parentId,
      kind: base.kind,
      code: base.code,
      label: base.label,
      credentialKind: base.credentialKind,
      duration: base.duration,
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

  /// Organisation porteuse, `null` si le programme n'en dépend d'aucune.
  @ZcrudField()
  final String? organizationId;

  /// Programme parent (`null` = racine) — vérité de l'arbre.
  @ZcrudField()
  final String? parentId;

  /// Type de programme — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Nature de la certification délivrée — chaîne opaque, `null` si aucune.
  @ZcrudField()
  final String? credentialKind;

  /// Durée nominale — chaîne opaque, jamais parsée, `null` si non déclarée.
  @ZcrudField()
  final String? duration;

  /// Chaîne des ancêtres, racine d'abord — projection recalculable.
  @ZcrudField()
  final List<String> ancestorIds;

  /// Identifiants du programme dans des systèmes tiers, défaut `const []`.
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
      ...zStudyPrune(ZStudyProgramZcrud(this).toMap()),
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
  ZStudyProgram copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? parentId = _$undefined,
    Object? kind = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? credentialKind = _$undefined,
    Object? duration = _$undefined,
    Object? ancestorIds = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyProgram(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    parentId: identical(parentId, _$undefined)
        ? this.parentId
        : parentId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    credentialKind: identical(credentialKind, _$undefined)
        ? this.credentialKind
        : credentialKind as String?,
    duration: identical(duration, _$undefined)
        ? this.duration
        : duration as String?,
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
    for (final spec in $ZStudyProgramFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyProgram &&
          id == other.id &&
          organizationId == other.organizationId &&
          parentId == other.parentId &&
          kind == other.kind &&
          code == other.code &&
          label == other.label &&
          credentialKind == other.credentialKind &&
          duration == other.duration &&
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
    code,
    label,
    credentialKind,
    duration,
    Object.hashAll(ancestorIds),
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
