/// Entité `ZStudyRoleBinding` — l'attribution d'un rôle à un mandant sur une
/// portée.
///
/// 🔴 **Ceci décrit un FAIT, jamais un droit.** L'enregistrement dit « telle
/// personne a tel rôle sur telle portée, entre telles dates ». Il ne dit pas —
/// et le noyau n'en déduira jamais — qu'une action est permise.
/// L'autorisation est **calculée par l'hôte** (`ZActionKey`, ACL fail-closed) à
/// partir de ces faits et de tout ce qu'il sait par ailleurs. Un noyau qui
/// dériverait un droit d'un rôle imposerait sa politique à toutes les
/// applications qui l'utilisent, et la rendrait fausse pour la première d'entre
/// elles qui pense autrement.
///
/// [roleKey] est une chaîne **opaque** : le noyau ne l'ordonne pas, ne la
/// compare pas à une hiérarchie et n'en connaît aucune. Deux attributions ne
/// sont jamais « plus forte » l'une que l'autre.
///
/// [inheritance] dit jusqu'où l'attribution porte — `exact`, `descendants`,
/// `none` (`kZStudyInheritance…`), chaîne opaque elle aussi : une valeur
/// inconnue ne fait porter l'attribution que sur la portée désignée.
///
/// [validFrom] / [validTo] forment un intervalle **semi-ouvert**
/// `[validFrom, validTo)` ; une borne absente n'en restreint pas ce côté.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_constants.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

part 'z_study_role_binding.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyRoleBindingExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Attribution de rôle immuable.
@ZcrudModel(kind: 'study_role_binding', fieldRename: ZFieldRename.snake)
class ZStudyRoleBinding extends ZEntity with ZExtensible {
  /// Construit une attribution de rôle.
  const ZStudyRoleBinding({
    this.id,
    this.principalRef = const ZStudyRef(type: '', id: ''),
    this.scopeRef = const ZStudyRef(type: '', id: ''),
    this.roleKey = '',
    this.periodId,
    this.validFrom,
    this.validTo,
    this.inheritance = kZStudyInheritanceExact,
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Références absentes ⇒ référence vide ; [inheritance] absente ou illisible
  /// ⇒ `exact`, valeur inconnue conservée. Ne lève jamais.
  factory ZStudyRoleBinding.fromMap(
    Map<String, dynamic> map, {
    ZStudyRoleBindingExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyRoleBindingFromMap(map);
    return ZStudyRoleBinding(
      id: base.id,
      principalRef: _refOf(map['principal_ref']),
      scopeRef: _refOf(map['scope_ref']),
      roleKey: base.roleKey,
      periodId: base.periodId,
      validFrom: base.validFrom,
      validTo: base.validTo,
      inheritance: zJsonString(map['inheritance'], kZStudyInheritanceExact),
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Mandant qui reçoit le rôle — canal manuel (`principal_ref`).
  @ZcrudIgnore()
  final ZStudyRef principalRef;

  /// Portée sur laquelle le rôle est attribué — canal manuel (`scope_ref`).
  @ZcrudIgnore()
  final ZStudyRef scopeRef;

  /// Rôle attribué — chaîne opaque, défaut `''`. Jamais un droit.
  @ZcrudField()
  final String roleKey;

  /// Période de rattachement, `null` si l'attribution n'en dépend d'aucune.
  @ZcrudField()
  final String? periodId;

  /// Début de validité inclus, `null` si non borné.
  @ZcrudField()
  final DateTime? validFrom;

  /// Fin de validité exclue, `null` si non bornée.
  @ZcrudField()
  final DateTime? validTo;

  /// Étendue de l'attribution — chaîne opaque, défaut `exact`.
  @ZcrudField()
  final String inheritance;

  /// Identifiants de l'attribution dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// `true` si [inheritance] est un mode que le noyau nomme.
  bool get hasKnownInheritance => kZStudyInheritances.contains(inheritance);

  /// `true` si l'attribution est valide à [instant], sur l'intervalle
  /// semi-ouvert `[validFrom, validTo)`.
  ///
  /// Valide ne veut pas dire autorisant : c'est une question de dates, pas de
  /// permission.
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
      ...zStudyPrune(ZStudyRoleBindingZcrud(this).toMap()),
      'principal_ref': principalRef.toMap(),
      'scope_ref': scopeRef.toMap(),
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
  ZStudyRoleBinding copyWith({
    Object? id = _$undefined,
    Object? principalRef = _$undefined,
    Object? scopeRef = _$undefined,
    Object? roleKey = _$undefined,
    Object? periodId = _$undefined,
    Object? validFrom = _$undefined,
    Object? validTo = _$undefined,
    Object? inheritance = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyRoleBinding(
    id: identical(id, _$undefined) ? this.id : id as String?,
    principalRef: identical(principalRef, _$undefined)
        ? this.principalRef
        : principalRef as ZStudyRef,
    scopeRef: identical(scopeRef, _$undefined)
        ? this.scopeRef
        : scopeRef as ZStudyRef,
    roleKey: identical(roleKey, _$undefined) ? this.roleKey : roleKey as String,
    periodId: identical(periodId, _$undefined)
        ? this.periodId
        : periodId as String?,
    validFrom: identical(validFrom, _$undefined)
        ? this.validFrom
        : validFrom as DateTime?,
    validTo: identical(validTo, _$undefined)
        ? this.validTo
        : validTo as DateTime?,
    inheritance: identical(inheritance, _$undefined)
        ? this.inheritance
        : inheritance as String,
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
    for (final spec in $ZStudyRoleBindingFieldSpecs) spec.name,
    'principal_ref',
    'scope_ref',
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyRoleBinding &&
          id == other.id &&
          principalRef == other.principalRef &&
          scopeRef == other.scopeRef &&
          roleKey == other.roleKey &&
          periodId == other.periodId &&
          validFrom == other.validFrom &&
          validTo == other.validTo &&
          inheritance == other.inheritance &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    principalRef,
    scopeRef,
    roleKey,
    periodId,
    validFrom,
    validTo,
    inheritance,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
