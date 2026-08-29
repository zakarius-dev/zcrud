/// Entité `ZStudySubject` — matière : l'axe **disciplinaire** du catalogue.
///
/// Une matière n'est pas un cours : elle dit de quoi on parle
/// (« mathématiques »), le cours dit ce qui est enseigné et à quel niveau. Un
/// cours référence au plus une matière ; une matière ne liste jamais ses cours.
///
/// [kind] est une chaîne opaque. [colorKey] est une clé de thème résolue côté
/// hôte (jamais une couleur), cohérente avec le reste du noyau d'étude.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_subject.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudySubjectExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Matière immuable.
@ZcrudModel(kind: 'study_subject', fieldRename: ZFieldRename.snake)
class ZStudySubject extends ZEntity with ZExtensible {
  /// Construit une matière.
  const ZStudySubject({
    this.id,
    this.organizationId,
    this.kind = '',
    this.code,
    this.label = '',
    this.colorKey = '',
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudySubject.fromMap(
    Map<String, dynamic> map, {
    ZStudySubjectExtensionParser? extensionParser,
  }) {
    final base = _$ZStudySubjectFromMap(map);
    return ZStudySubject(
      id: base.id,
      organizationId: base.organizationId,
      kind: base.kind,
      code: base.code,
      label: base.label,
      colorKey: base.colorKey,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Organisation porteuse, `null` si la matière n'en dépend d'aucune.
  @ZcrudField()
  final String? organizationId;

  /// Type de matière — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField(label: 'Matière')
  final String label;

  /// Clé de thème libre (résolue côté hôte, jamais une couleur), défaut `''`.
  @ZcrudField()
  final String colorKey;

  /// Identifiants de la matière dans des systèmes tiers, défaut `const []`.
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
      ...zStudyPrune(ZStudySubjectZcrud(this).toMap()),
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
  ZStudySubject copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? kind = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? colorKey = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudySubject(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    colorKey: identical(colorKey, _$undefined)
        ? this.colorKey
        : colorKey as String,
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
    for (final spec in $ZStudySubjectFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySubject &&
          id == other.id &&
          organizationId == other.organizationId &&
          kind == other.kind &&
          code == other.code &&
          label == other.label &&
          colorKey == other.colorKey &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    kind,
    code,
    label,
    colorKey,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
