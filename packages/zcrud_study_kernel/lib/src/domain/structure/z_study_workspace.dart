/// Entité `ZStudyWorkspace` — espace de travail, racine facultative de
/// tenancy.
///
/// Un espace de travail regroupe tout ce qui appartient à un même contexte
/// d'usage. Il est **facultatif partout** : un usage personnel n'en déclare
/// aucun, et chaque entité qui le référence porte un `workspaceId` nullable.
/// L'absence est un état valide, jamais une donnée manquante à combler.
///
/// [kind] est une chaîne opaque (registre ouvert, invariant AD-4) : le noyau
/// ne l'interprète pas et la conserve au round-trip.
///
/// **Slots d'extension (invariant AD-4)** : `ZExtensible` → `extra` +
/// `extension`. **Décodage défensif (invariant AD-10)** : `fromMap` ne lève
/// jamais.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_workspace.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyWorkspaceExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Espace de travail immuable.
@ZcrudModel(kind: 'study_workspace', fieldRename: ZFieldRename.snake)
class ZStudyWorkspace extends ZEntity with ZExtensible {
  /// Construit un espace de travail.
  const ZStudyWorkspace({
    this.id,
    this.kind = '',
    this.label = '',
    this.ownerPrincipalId,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyWorkspace.fromMap(
    Map<String, dynamic> map, {
    ZStudyWorkspaceExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyWorkspaceFromMap(map);
    return ZStudyWorkspace(
      id: base.id,
      kind: base.kind,
      label: base.label,
      ownerPrincipalId: base.ownerPrincipalId,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Type d'espace — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Mandant propriétaire (identifiant opaque), `null` si non déclaré.
  @ZcrudField()
  final String? ownerPrincipalId;

  /// Identifiants de l'espace dans des systèmes tiers, défaut `const []`.
  ///
  /// Canal manuel : rien n'est émis tant que la liste est vide.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}` ; l'accesseur
  /// normalise et ne rend jamais une clé réservée.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyWorkspaceZcrud(this).toMap()),
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
  ZStudyWorkspace copyWith({
    Object? id = _$undefined,
    Object? kind = _$undefined,
    Object? label = _$undefined,
    Object? ownerPrincipalId = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyWorkspace(
    id: identical(id, _$undefined) ? this.id : id as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    label: identical(label, _$undefined) ? this.label : label as String,
    ownerPrincipalId: identical(ownerPrincipalId, _$undefined)
        ? this.ownerPrincipalId
        : ownerPrincipalId as String?,
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
    for (final spec in $ZStudyWorkspaceFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyWorkspace &&
          id == other.id &&
          kind == other.kind &&
          label == other.label &&
          ownerPrincipalId == other.ownerPrincipalId &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    label,
    ownerPrincipalId,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  );
}
