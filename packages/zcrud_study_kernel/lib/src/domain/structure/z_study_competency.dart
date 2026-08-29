/// Entité `ZStudyCompetency` — une compétence d'un cadre.
///
/// La compétence est **plate** : elle n'a pas de parent. Ce qui la structure
/// vit à côté, dans `ZStudyCompetencyRelation` — un **graphe**, pas un arbre.
/// C'est la différence qui compte : une compétence peut être contenue par deux
/// compétences à la fois, requise par trois autres, et équivalente à une
/// quatrième dans un autre cadre. Un champ `parentId` rendrait tout cela
/// inexprimable.
///
/// [code] est un code de cadre (« C2.3 ») : lisible, stable dans son cadre,
/// mais **jamais une identité** — deux cadres réutilisent les mêmes codes.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_competency.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyCompetencyExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Compétence immuable.
@ZcrudModel(kind: 'study_competency', fieldRename: ZFieldRename.snake)
class ZStudyCompetency extends ZEntity with ZExtensible {
  /// Construit une compétence.
  const ZStudyCompetency({
    this.id,
    this.frameworkId = '',
    this.code,
    this.label = '',
    this.description,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyCompetency.fromMap(
    Map<String, dynamic> map, {
    ZStudyCompetencyExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyCompetencyFromMap(map);
    return ZStudyCompetency(
      id: base.id,
      frameworkId: base.frameworkId,
      code: base.code,
      label: base.label,
      description: base.description,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Cadre porteur, défaut `''`.
  @ZcrudField()
  final String frameworkId;

  /// Code du cadre, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Énoncé complet, `null` si le libellé se suffit.
  @ZcrudField()
  final String? description;

  /// Identifiants de la compétence dans des systèmes tiers, défaut `const []`.
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
      ...zStudyPrune(ZStudyCompetencyZcrud(this).toMap()),
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
  ZStudyCompetency copyWith({
    Object? id = _$undefined,
    Object? frameworkId = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? description = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyCompetency(
    id: identical(id, _$undefined) ? this.id : id as String?,
    frameworkId: identical(frameworkId, _$undefined)
        ? this.frameworkId
        : frameworkId as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    description: identical(description, _$undefined)
        ? this.description
        : description as String?,
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
    for (final spec in $ZStudyCompetencyFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyCompetency &&
          id == other.id &&
          frameworkId == other.frameworkId &&
          code == other.code &&
          label == other.label &&
          description == other.description &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    frameworkId,
    code,
    label,
    description,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
