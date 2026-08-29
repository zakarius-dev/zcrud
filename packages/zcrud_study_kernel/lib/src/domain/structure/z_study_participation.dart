/// Entité `ZStudyParticipation` — le fait qu'un mandant prenne part à quelque
/// chose.
///
/// **Un seul enregistrement pour trois notions** que les modèles séparent
/// d'ordinaire : l'appartenance à un groupe, l'inscription à une offre, et le
/// rattachement d'un intervenant à ce qu'il conduit. Les trois disent
/// exactement la même chose — *qui*, *où*, *à quel titre*, *quand* — et les
/// séparer obligerait à écrire trois fois la même mécanique de dates, de rôles
/// et de fin de validité.
///
/// [targetRef] est une référence libre : un groupe, une organisation, une
/// offre, un programme, une unité. Le noyau ne restreint pas les types ; une
/// ontologie peut le faire pour un contexte donné, par la capacité
/// `acceptsParticipation`.
///
/// **Participer n'est pas être autorisé.** [role] est une étiquette de fait,
/// opaque, jamais une permission. L'autorisation se calcule chez l'hôte, sur
/// une ACL fail-closed, à partir de ces faits et d'autres — le noyau n'en
/// déduit jamais un droit.
///
/// [validFrom] / [validTo] forment un intervalle **semi-ouvert**
/// `[validFrom, validTo)` : une borne absente signifie « non bornée de ce
/// côté ». C'est ce qui permet à deux participations de la même personne au
/// même endroit de se succéder sans se recouvrir, et à un historique de rester
/// lisible sans suppression.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

part 'z_study_participation.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyParticipationExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Participation immuable.
@ZcrudModel(kind: 'study_participation', fieldRename: ZFieldRename.snake)
class ZStudyParticipation extends ZEntity with ZExtensible {
  /// Construit une participation.
  const ZStudyParticipation({
    this.id,
    this.principalRef = const ZStudyRef(type: '', id: ''),
    this.targetRef = const ZStudyRef(type: '', id: ''),
    this.role = '',
    this.periodId,
    this.validFrom,
    this.validTo,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Une référence absente ou illisible retombe sur la référence vide
  /// (`type: ''`, `id: ''`) ; un rôle illisible sur `''`. Ne lève jamais.
  factory ZStudyParticipation.fromMap(
    Map<String, dynamic> map, {
    ZStudyParticipationExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyParticipationFromMap(map);
    return ZStudyParticipation(
      id: base.id,
      principalRef: _refOf(map['principal_ref']),
      targetRef: _refOf(map['target_ref']),
      role: base.role,
      periodId: base.periodId,
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

  /// Qui prend part — canal manuel (`principal_ref`), hors codegen.
  @ZcrudIgnore()
  final ZStudyRef principalRef;

  /// Ce à quoi il prend part — canal manuel (`target_ref`), hors codegen.
  @ZcrudIgnore()
  final ZStudyRef targetRef;

  /// À quel titre — chaîne opaque, défaut `''`. Voir `kZStudyRole…`.
  @ZcrudField()
  final String role;

  /// Période de rattachement, `null` si la participation n'en dépend d'aucune.
  ///
  /// Distinct de [validFrom]/[validTo] : la période nomme un découpage
  /// existant, les bornes datent l'enregistrement lui-même. Une participation
  /// peut être bornée sans période, et l'inverse.
  @ZcrudField()
  final String? periodId;

  /// Début de validité inclus, `null` si non borné.
  @ZcrudField()
  final DateTime? validFrom;

  /// Fin de validité exclue, `null` si non bornée.
  @ZcrudField()
  final DateTime? validTo;

  /// Identifiants de la participation dans des systèmes tiers, défaut
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

  /// `true` si la participation est valide à [instant], sur l'intervalle
  /// semi-ouvert `[validFrom, validTo)`.
  ///
  /// Une borne absente ne restreint rien de ce côté.
  bool isActiveAt(DateTime instant) {
    if (validFrom != null && instant.isBefore(validFrom!)) return false;
    if (validTo != null && !instant.isBefore(validTo!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé. Les deux références sont toujours émises — elles portent
  /// l'identité de l'enregistrement.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyParticipationZcrud(this).toMap()),
      'principal_ref': principalRef.toMap(),
      'target_ref': targetRef.toMap(),
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
  ZStudyParticipation copyWith({
    Object? id = _$undefined,
    Object? principalRef = _$undefined,
    Object? targetRef = _$undefined,
    Object? role = _$undefined,
    Object? periodId = _$undefined,
    Object? validFrom = _$undefined,
    Object? validTo = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyParticipation(
    id: identical(id, _$undefined) ? this.id : id as String?,
    principalRef: identical(principalRef, _$undefined)
        ? this.principalRef
        : principalRef as ZStudyRef,
    targetRef: identical(targetRef, _$undefined)
        ? this.targetRef
        : targetRef as ZStudyRef,
    role: identical(role, _$undefined) ? this.role : role as String,
    periodId: identical(periodId, _$undefined)
        ? this.periodId
        : periodId as String?,
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
    for (final spec in $ZStudyParticipationFieldSpecs) spec.name,
    'principal_ref',
    'target_ref',
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyParticipation &&
          id == other.id &&
          principalRef == other.principalRef &&
          targetRef == other.targetRef &&
          role == other.role &&
          periodId == other.periodId &&
          validFrom == other.validFrom &&
          validTo == other.validTo &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    principalRef,
    targetRef,
    role,
    periodId,
    validFrom,
    validTo,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
