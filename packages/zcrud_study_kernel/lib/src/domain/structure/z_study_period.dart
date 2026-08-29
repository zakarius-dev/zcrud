/// Entité `ZStudyPeriod` — nœud de l'arbre temporel d'un contexte d'étude.
///
/// Une période désigne n'importe quelle granularité de temps. [kind] est une
/// **chaîne opaque** : le noyau ne l'interprète pas et la conserve au
/// round-trip.
///
/// **Arbre à profondeur libre** : [parentId] est la vérité, [ancestorIds] la
/// projection recalculable (racine d'abord), [depth] en dérive et n'est jamais
/// persistée.
///
/// **Bornes** : [startsAt] et [endsAt] sont optionnelles et persistées en
/// ISO-8601. Le noyau ne vérifie **pas** que l'une précède l'autre et n'en
/// dérive aucune logique de calendrier : ce sont des données, pas des
/// invariants. [contains] les lit comme un intervalle semi-ouvert
/// `[startsAt, endsAt)`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_period.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyPeriodExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Nœud immuable de l'arbre temporel.
@ZcrudModel(kind: 'study_period', fieldRename: ZFieldRename.snake)
class ZStudyPeriod extends ZEntity with ZExtensible {
  /// Construit une période.
  const ZStudyPeriod({
    this.id,
    this.calendarId,
    this.parentId,
    this.kind = '',
    this.code,
    this.label = '',
    this.startsAt,
    this.endsAt,
    this.order,
    this.ancestorIds = const <String>[],
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyPeriod.fromMap(
    Map<String, dynamic> map, {
    ZStudyPeriodExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyPeriodFromMap(map);
    return ZStudyPeriod(
      id: base.id,
      calendarId: base.calendarId,
      parentId: base.parentId,
      kind: base.kind,
      code: base.code,
      label: base.label,
      startsAt: base.startsAt,
      endsAt: base.endsAt,
      order: base.order,
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

  /// Calendrier porteur, `null` si la période n'en dépend d'aucun.
  @ZcrudField()
  final String? calendarId;

  /// Période parente (`null` = racine) — vérité de l'arbre.
  @ZcrudField()
  final String? parentId;

  /// Type de période — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Code métier, `null` si absent. Jamais une identité.
  @ZcrudField()
  final String? code;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Borne de début incluse (ISO-8601), `null` si non bornée.
  @ZcrudField()
  final DateTime? startsAt;

  /// Borne de fin exclue (ISO-8601), `null` si non bornée.
  @ZcrudField()
  final DateTime? endsAt;

  /// Rang d'affichage, `null` si non ordonnée.
  @ZcrudField()
  final int? order;

  /// Chaîne des ancêtres, racine d'abord — projection recalculable.
  @ZcrudField()
  final List<String> ancestorIds;

  /// Identifiants de la période dans des systèmes tiers, défaut `const []`.
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

  /// `true` si [instant] tombe dans `[startsAt, endsAt)`. Une borne absente ne
  /// restreint rien de ce côté : une période sans bornes contient tout
  /// instant.
  bool contains(DateTime instant) {
    if (startsAt != null && instant.isBefore(startsAt!)) return false;
    if (endsAt != null && !instant.isBefore(endsAt!)) return false;
    return true;
  }

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudyPeriodZcrud(this).toMap()),
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
  ZStudyPeriod copyWith({
    Object? id = _$undefined,
    Object? calendarId = _$undefined,
    Object? parentId = _$undefined,
    Object? kind = _$undefined,
    Object? code = _$undefined,
    Object? label = _$undefined,
    Object? startsAt = _$undefined,
    Object? endsAt = _$undefined,
    Object? order = _$undefined,
    Object? ancestorIds = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyPeriod(
    id: identical(id, _$undefined) ? this.id : id as String?,
    calendarId: identical(calendarId, _$undefined)
        ? this.calendarId
        : calendarId as String?,
    parentId: identical(parentId, _$undefined)
        ? this.parentId
        : parentId as String?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    code: identical(code, _$undefined) ? this.code : code as String?,
    label: identical(label, _$undefined) ? this.label : label as String,
    startsAt: identical(startsAt, _$undefined)
        ? this.startsAt
        : startsAt as DateTime?,
    endsAt: identical(endsAt, _$undefined) ? this.endsAt : endsAt as DateTime?,
    order: identical(order, _$undefined) ? this.order : order as int?,
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
    for (final spec in $ZStudyPeriodFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyPeriod &&
          id == other.id &&
          calendarId == other.calendarId &&
          parentId == other.parentId &&
          kind == other.kind &&
          code == other.code &&
          label == other.label &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          order == other.order &&
          zStringListEquals(ancestorIds, other.ancestorIds) &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    calendarId,
    parentId,
    kind,
    code,
    label,
    startsAt,
    endsAt,
    order,
    Object.hashAll(ancestorIds),
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
