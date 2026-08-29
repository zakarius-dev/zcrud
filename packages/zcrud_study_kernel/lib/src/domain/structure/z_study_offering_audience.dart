/// Entité `ZStudyOfferingAudience` — un groupe convoqué par une offre.
///
/// Une offre peut réunir plusieurs groupes, et un groupe peut suivre plusieurs
/// offres : c'est une relation **plusieurs-à-plusieurs**, donc un
/// enregistrement à part entière. Aucune des deux extrémités ne liste l'autre —
/// ajouter un groupe à une offre n'a jamais à réécrire ni l'offre ni le groupe.
///
/// [role] qualifie ce que le groupe fait dans cette offre (chaîne opaque,
/// `null` si non qualifié). Il ne dit rien des personnes : une personne est
/// reliée par une `ZStudyParticipation`, avec son propre rôle et ses propres
/// dates.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_offering_audience.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyOfferingAudienceExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Audience immuable d'une offre.
@ZcrudModel(kind: 'study_offering_audience', fieldRename: ZFieldRename.snake)
class ZStudyOfferingAudience extends ZEntity with ZExtensible {
  /// Construit une audience.
  const ZStudyOfferingAudience({
    this.id,
    this.offeringId = '',
    this.groupId = '',
    this.role,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyOfferingAudience.fromMap(
    Map<String, dynamic> map, {
    ZStudyOfferingAudienceExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyOfferingAudienceFromMap(map);
    return ZStudyOfferingAudience(
      id: base.id,
      offeringId: base.offeringId,
      groupId: base.groupId,
      role: base.role,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Offre qui convoque, défaut `''`.
  @ZcrudField()
  final String offeringId;

  /// Groupe convoqué, défaut `''`.
  @ZcrudField()
  final String groupId;

  /// Rôle du groupe dans cette offre — chaîne opaque, `null` si non qualifié.
  @ZcrudField()
  final String? role;

  /// Identifiants de l'audience dans des systèmes tiers, défaut `const []`.
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
      ...zStudyPrune(ZStudyOfferingAudienceZcrud(this).toMap()),
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
  ZStudyOfferingAudience copyWith({
    Object? id = _$undefined,
    Object? offeringId = _$undefined,
    Object? groupId = _$undefined,
    Object? role = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyOfferingAudience(
    id: identical(id, _$undefined) ? this.id : id as String?,
    offeringId: identical(offeringId, _$undefined)
        ? this.offeringId
        : offeringId as String,
    groupId: identical(groupId, _$undefined)
        ? this.groupId
        : groupId as String,
    role: identical(role, _$undefined) ? this.role : role as String?,
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
    for (final spec in $ZStudyOfferingAudienceFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyOfferingAudience &&
          id == other.id &&
          offeringId == other.offeringId &&
          groupId == other.groupId &&
          role == other.role &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    offeringId,
    groupId,
    role,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
