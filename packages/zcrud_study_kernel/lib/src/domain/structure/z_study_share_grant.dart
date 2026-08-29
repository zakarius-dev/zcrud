/// Entité `ZStudyShareGrant` — le fait qu'un artefact ait été partagé.
///
/// 🔴 **Ceci décrit un FAIT, jamais un droit.** L'enregistrement dit « tel
/// artefact a été partagé avec tel destinataire sous telle étiquette d'accès,
/// entre telles dates ». Il ne dit pas qu'une action est permise :
/// l'autorisation est **calculée par l'hôte** (`ZActionKey`, ACL fail-closed).
/// Le noyau ne compare pas les étiquettes d'accès entre elles, ne les ordonne
/// pas, et n'en déduit jamais qu'un partage en couvre un autre.
///
/// [accessKey] est une chaîne **opaque** (voir `kZStudyAccess…`) : c'est une
/// étiquette de fait, pas un niveau. Un hôte qui a besoin d'un ordre le définit
/// chez lui, avec sa propre politique.
///
/// [granteeRef] peut désigner une personne, un groupe ou toute autre cible :
/// partager avec une cohorte est le même fait que partager avec une personne,
/// et forcer l'un ou l'autre obligerait à écrire deux fois la même mécanique.
///
/// [validFrom] / [validTo] forment un intervalle **semi-ouvert**
/// `[validFrom, validTo)` — c'est ce qui permet de laisser expirer un partage
/// sans le supprimer, et donc sans perdre la trace qu'il a existé.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_constants.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

part 'z_study_share_grant.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyShareGrantExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Fait de partage immuable.
@ZcrudModel(kind: 'study_share_grant', fieldRename: ZFieldRename.snake)
class ZStudyShareGrant extends ZEntity with ZExtensible {
  /// Construit un fait de partage.
  const ZStudyShareGrant({
    this.id,
    this.artifactRef = const ZStudyRef(type: '', id: ''),
    this.granteeRef = const ZStudyRef(type: '', id: ''),
    this.accessKey = kZStudyAccessRead,
    this.validFrom,
    this.validTo,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Références absentes ⇒ référence vide ; [accessKey] absente ou illisible ⇒
  /// `read`, valeur inconnue conservée. Ne lève jamais.
  factory ZStudyShareGrant.fromMap(
    Map<String, dynamic> map, {
    ZStudyShareGrantExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyShareGrantFromMap(map);
    return ZStudyShareGrant(
      id: base.id,
      artifactRef: _refOf(map['artifact_ref']),
      granteeRef: _refOf(map['grantee_ref']),
      accessKey: zJsonString(map['access_key'], kZStudyAccessRead),
      validFrom: base.validFrom,
      validTo: base.validTo,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Artefact partagé — canal manuel (`artifact_ref`).
  @ZcrudIgnore()
  final ZStudyRef artifactRef;

  /// Destinataire du partage — canal manuel (`grantee_ref`).
  @ZcrudIgnore()
  final ZStudyRef granteeRef;

  /// Étiquette d'accès — chaîne opaque, défaut `read`. Jamais un niveau.
  @ZcrudField()
  final String accessKey;

  /// Début de validité inclus, `null` si non borné.
  @ZcrudField()
  final DateTime? validFrom;

  /// Fin de validité exclue, `null` si non bornée.
  @ZcrudField()
  final DateTime? validTo;

  /// Identifiants du partage dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si [accessKey] est une étiquette que le noyau nomme.
  ///
  /// Faux ne signifie pas invalide : une étiquette maison traverse le
  /// round-trip intacte.
  bool get hasKnownAccessKey => kZStudyAccessKeys.contains(accessKey);

  /// `true` si le partage est valide à [instant], sur l'intervalle semi-ouvert
  /// `[validFrom, validTo)`.
  ///
  /// Valide ne veut pas dire autorisant : c'est une question de dates.
  bool isActiveAt(DateTime instant) {
    if (validFrom != null && instant.isBefore(validFrom!)) return false;
    if (validTo != null && !instant.isBefore(validTo!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé. Les deux références sont toujours émises.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyShareGrantZcrud(this).toMap()),
      'artifact_ref': artifactRef.toMap(),
      'grantee_ref': granteeRef.toMap(),
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
  ZStudyShareGrant copyWith({
    Object? id = _$undefined,
    Object? artifactRef = _$undefined,
    Object? granteeRef = _$undefined,
    Object? accessKey = _$undefined,
    Object? validFrom = _$undefined,
    Object? validTo = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyShareGrant(
    id: identical(id, _$undefined) ? this.id : id as String?,
    artifactRef: identical(artifactRef, _$undefined)
        ? this.artifactRef
        : artifactRef as ZStudyRef,
    granteeRef: identical(granteeRef, _$undefined)
        ? this.granteeRef
        : granteeRef as ZStudyRef,
    accessKey: identical(accessKey, _$undefined)
        ? this.accessKey
        : accessKey as String,
    validFrom: identical(validFrom, _$undefined)
        ? this.validFrom
        : validFrom as DateTime?,
    validTo: identical(validTo, _$undefined)
        ? this.validTo
        : validTo as DateTime?,
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

  static ZStudyRef _refOf(Object? raw) {
    final map = zStudyAsJsonMap(raw);
    return map == null
        ? const ZStudyRef(type: '', id: '')
        : ZStudyRef.fromMap(map);
  }

  /// Clés persistées réservées (schéma généré + canaux manuels + `ZSyncMeta`).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyShareGrantFieldSpecs) spec.name,
    'artifact_ref',
    'grantee_ref',
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyShareGrant &&
          id == other.id &&
          artifactRef == other.artifactRef &&
          granteeRef == other.granteeRef &&
          accessKey == other.accessKey &&
          validFrom == other.validFrom &&
          validTo == other.validTo &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    artifactRef,
    granteeRef,
    accessKey,
    validFrom,
    validTo,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
