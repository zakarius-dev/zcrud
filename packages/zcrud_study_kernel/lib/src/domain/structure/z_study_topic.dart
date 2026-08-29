/// Entité `ZStudyTopic` — nœud de l'arbre de contenu d'un curriculum.
///
/// Un thème est **la même chose à toutes les granularités** : un grand domaine,
/// une unité, un chapitre, une séquence, un objectif isolé. C'est [kind] —
/// chaîne **opaque** — qui dit à quelle granularité on se trouve, et une
/// ontologie qui dit, pour un contexte donné, lesquelles s'emboîtent. Le noyau
/// n'en connaît aucune : il transporte l'arbre.
///
/// **[parentId] est la vérité, [ancestorIds] la projection** recalculable
/// (racine d'abord, le nœud lui-même exclu) ; [depth] en dérive et n'est jamais
/// persistée. Un arbre à profondeur libre est ce qui permet à un référentiel de
/// deux niveaux et à un référentiel de cinq de partager le même type.
///
/// [expectedDuration] est une chaîne **opaque**, jamais parsée : le noyau n'a
/// pas à choisir entre des heures, des séances et des semaines. [weight] est un
/// poids relatif libre, sans échelle imposée et sans somme garantie.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_topic.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyTopicExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Thème immuable.
@ZcrudModel(kind: 'study_topic', fieldRename: ZFieldRename.snake)
class ZStudyTopic extends ZEntity with ZExtensible {
  /// Construit un thème.
  const ZStudyTopic({
    this.id,
    this.curriculumId = '',
    this.parentId,
    this.kind = '',
    this.code,
    this.label = '',
    this.order,
    this.expectedDuration,
    this.weight,
    this.ancestorIds = const <String>[],
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyTopic.fromMap(
    Map<String, dynamic> map, {
    ZStudyTopicExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyTopicFromMap(map);
    return ZStudyTopic(
      id: base.id,
      curriculumId: base.curriculumId,
      parentId: base.parentId,
      kind: base.kind,
      code: base.code,
      label: base.label,
      order: base.order,
      expectedDuration: base.expectedDuration,
      weight: base.weight,
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

  /// Curriculum porteur, défaut `''`.
  @ZcrudField()
  final String curriculumId;

  /// Thème contenant (`null` = racine) — vérité de l'arbre.
  @ZcrudField()
  final String? parentId;

  /// Granularité du thème — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Rang d'affichage parmi les frères, `null` si non ordonné.
  @ZcrudField()
  final int? order;

  /// Durée attendue — chaîne opaque, jamais parsée, `null` si non déclarée.
  @ZcrudField()
  final String? expectedDuration;

  /// Poids relatif libre, `null` si non pondéré. Sans échelle imposée.
  @ZcrudField()
  final double? weight;

  /// Chaîne des thèmes contenants, racine d'abord — projection recalculable.
  @ZcrudField()
  final List<String> ancestorIds;

  /// Identifiants du thème dans des systèmes tiers, défaut `const []`.
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
      ...zStudyPrune(ZStudyTopicZcrud(this).toMap()),
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
  ZStudyTopic copyWith({
    Object? id = _$undefined,
    Object? curriculumId = _$undefined,
    Object? parentId = _$undefined,
    Object? kind = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? order = _$undefined,
    Object? expectedDuration = _$undefined,
    Object? weight = _$undefined,
    Object? ancestorIds = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyTopic(
    id: identical(id, _$undefined) ? this.id : id as String?,
    curriculumId: identical(curriculumId, _$undefined)
        ? this.curriculumId
        : curriculumId as String,
    parentId: identical(parentId, _$undefined)
        ? this.parentId
        : parentId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    order: identical(order, _$undefined) ? this.order : order as int?,
    expectedDuration: identical(expectedDuration, _$undefined)
        ? this.expectedDuration
        : expectedDuration as String?,
    weight: identical(weight, _$undefined) ? this.weight : weight as double?,
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
    for (final spec in $ZStudyTopicFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyTopic &&
          id == other.id &&
          curriculumId == other.curriculumId &&
          parentId == other.parentId &&
          kind == other.kind &&
          code == other.code &&
          label == other.label &&
          order == other.order &&
          expectedDuration == other.expectedDuration &&
          weight == other.weight &&
          zStringListEquals(ancestorIds, other.ancestorIds) &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    curriculumId,
    parentId,
    kind,
    code,
    label,
    order,
    expectedDuration,
    weight,
    Object.hashAll(ancestorIds),
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
