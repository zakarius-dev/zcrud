/// Entité `ZStudyClassification` — affectation **historisable** d'une valeur
/// de vocabulaire à une cible.
///
/// C'est la voie unique par laquelle un élément de structure porte un axe
/// descriptif : le niveau d'un groupe, l'orientation d'un programme, le format
/// d'un cours. Elle remplace tout champ dédié — ajouter un axe se fait en
/// déclarant un vocabulaire, jamais en modifiant une entité.
///
/// **Historisable** : la même cible peut porter deux valeurs du même
/// vocabulaire sur deux [periodId] ou deux intervalles distincts, et les deux
/// enregistrements coexistent. Le noyau **ne déduplique rien** et ne déclare
/// aucun conflit : c'est à la lecture de choisir la classification pertinente
/// (par période, ou par [isActiveAt]).
///
/// [vocabularyKey] et [valueKey] sont des chaînes opaques : une valeur non
/// déclarée par le vocabulaire reste valide et round-trippe intacte.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

part 'z_study_classification.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyClassificationExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Contrainte de classification : un couple vocabulaire/valeur exigé.
///
/// Utilisée par `ZStudyProgramCourse` pour restreindre la prescription d'un
/// cours aux cibles portant une classification donnée. Une contrainte est une
/// **donnée**, jamais un prédicat compilé : le noyau la transporte, la compare
/// et la restitue.
class ZStudyClassificationConstraint {
  /// Construit une contrainte.
  const ZStudyClassificationConstraint({
    required this.vocabularyKey,
    required this.valueKey,
  });

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyClassificationConstraint.fromMap(Map<String, dynamic> map) =>
      ZStudyClassificationConstraint(
        vocabularyKey: zJsonString(map['vocabulary_key']),
        valueKey: zJsonString(map['value_key']),
      );

  /// Clé du vocabulaire — chaîne opaque, défaut `''`.
  final String vocabularyKey;

  /// Clé de la valeur exigée — chaîne opaque, défaut `''`.
  final String valueKey;

  /// Sérialise vers la map persistée.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'vocabulary_key': vocabularyKey,
    'value_key': valueKey,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyClassificationConstraint &&
          vocabularyKey == other.vocabularyKey &&
          valueKey == other.valueKey;

  @override
  int get hashCode => Object.hash(vocabularyKey, valueKey);
}

/// Décode une liste de contraintes (repli `const []`).
List<ZStudyClassificationConstraint> zStudyDecodeClassificationConstraints(
  Object? raw,
) => zStudyDecodeList<ZStudyClassificationConstraint>(
  raw,
  ZStudyClassificationConstraint.fromMap,
);

/// Classification immuable.
@ZcrudModel(kind: 'study_classification', fieldRename: ZFieldRename.snake)
class ZStudyClassification extends ZEntity with ZExtensible {
  /// Construit une classification.
  const ZStudyClassification({
    this.id,
    this.targetRef = const ZStudyRef(type: '', id: ''),
    this.vocabularyKey = '',
    this.valueKey = '',
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
  /// Une cible absente ou illisible retombe sur la référence vide
  /// (`type: ''`, `id: ''`) — jamais une levée.
  factory ZStudyClassification.fromMap(
    Map<String, dynamic> map, {
    ZStudyClassificationExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyClassificationFromMap(map);
    final target = zStudyAsJsonMap(map['target_ref']);
    return ZStudyClassification(
      id: base.id,
      targetRef: target == null
          ? const ZStudyRef(type: '', id: '')
          : ZStudyRef.fromMap(target),
      vocabularyKey: base.vocabularyKey,
      valueKey: base.valueKey,
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

  /// Élément classé. Canal manuel : la référence est un objet, toujours émise.
  @ZcrudIgnore()
  final ZStudyRef targetRef;

  /// Clé du vocabulaire — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String vocabularyKey;

  /// Clé de la valeur affectée — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String valueKey;

  /// Période sur laquelle vaut l'affectation, `null` si intemporelle.
  @ZcrudField()
  final String? periodId;

  /// Début de validité inclus, `null` si non borné.
  @ZcrudField()
  final DateTime? validFrom;

  /// Fin de validité exclue, `null` si non bornée.
  @ZcrudField()
  final DateTime? validTo;

  /// Identifiants de la classification dans des systèmes tiers, défaut
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

  /// La contrainte que cette classification satisfait, sous forme de donnée.
  ZStudyClassificationConstraint get constraint =>
      ZStudyClassificationConstraint(
        vocabularyKey: vocabularyKey,
        valueKey: valueKey,
      );

  /// `true` si l'affectation est valide à [instant] (intervalle semi-ouvert
  /// `[validFrom, validTo)`). [periodId] n'entre pas dans ce calcul : une
  /// période est un identifiant, pas un intervalle.
  bool isActiveAt(DateTime instant) {
    if (validFrom != null && instant.isBefore(validFrom!)) return false;
    if (validTo != null && !instant.isBefore(validTo!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyClassificationZcrud(this).toMap()),
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
  ZStudyClassification copyWith({
    Object? id = _$undefined,
    Object? targetRef = _$undefined,
    Object? vocabularyKey = _$undefined,
    Object? valueKey = _$undefined,
    Object? periodId = _$undefined,
    Object? validFrom = _$undefined,
    Object? validTo = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyClassification(
    id: identical(id, _$undefined) ? this.id : id as String?,
    targetRef: identical(targetRef, _$undefined)
        ? this.targetRef
        : targetRef as ZStudyRef,
    vocabularyKey: identical(vocabularyKey, _$undefined)
        ? this.vocabularyKey
        : vocabularyKey as String,
    valueKey: identical(valueKey, _$undefined)
        ? this.valueKey
        : valueKey as String,
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

  /// Clés persistées réservées (schéma généré + canaux manuels + `ZSyncMeta`).
  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ZStudyClassificationFieldSpecs) spec.name,
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
      other is ZStudyClassification &&
          id == other.id &&
          targetRef == other.targetRef &&
          vocabularyKey == other.vocabularyKey &&
          valueKey == other.valueKey &&
          periodId == other.periodId &&
          validFrom == other.validFrom &&
          validTo == other.validTo &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    targetRef,
    vocabularyKey,
    valueKey,
    periodId,
    validFrom,
    validTo,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
