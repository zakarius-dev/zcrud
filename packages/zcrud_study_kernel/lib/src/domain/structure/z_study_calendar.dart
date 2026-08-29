/// Entité `ZStudyCalendar` — référentiel temporel auquel des périodes se
/// rattachent.
///
/// Deux organisations peuvent découper le temps différemment ; un calendrier
/// rend ce découpage nommable et comparable. [timezone] est une **chaîne
/// opaque** (identifiant IANA attendu, mais rien n'est parsé ni validé) : le
/// noyau ne convertit aucune date et n'embarque aucune base de fuseaux.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';

part 'z_study_calendar.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudyCalendarExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Calendrier immuable.
@ZcrudModel(kind: 'study_calendar', fieldRename: ZFieldRename.snake)
class ZStudyCalendar extends ZEntity with ZExtensible {
  /// Construit un calendrier.
  const ZStudyCalendar({
    this.id,
    this.organizationId,
    this.timezone = '',
    this.label = '',
    this.kind = '',
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  factory ZStudyCalendar.fromMap(
    Map<String, dynamic> map, {
    ZStudyCalendarExtensionParser? extensionParser,
  }) {
    final base = _$ZStudyCalendarFromMap(map);
    return ZStudyCalendar(
      id: base.id,
      organizationId: base.organizationId,
      timezone: base.timezone,
      label: base.label,
      kind: base.kind,
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Organisation porteuse, `null` si le calendrier n'en dépend d'aucune.
  @ZcrudField()
  final String? organizationId;

  /// Fuseau du calendrier — chaîne opaque jamais parsée, défaut `''`.
  @ZcrudField()
  final String timezone;

  /// Libellé affichable, défaut `''`.
  @ZcrudField()
  final String label;

  /// Type de calendrier — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Identifiants du calendrier dans des systèmes tiers, défaut `const []`.
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
      ...zStudyPrune(ZStudyCalendarZcrud(this).toMap()),
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
  ZStudyCalendar copyWith({
    Object? id = _$undefined,
    Object? organizationId = _$undefined,
    Object? timezone = _$undefined,
    Object? label = _$undefined,
    Object? kind = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudyCalendar(
    id: identical(id, _$undefined) ? this.id : id as String?,
    organizationId: identical(organizationId, _$undefined)
        ? this.organizationId
        : organizationId as String?,
    timezone: identical(timezone, _$undefined)
        ? this.timezone
        : timezone as String,
    label: identical(label, _$undefined) ? this.label : label as String,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
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
    for (final spec in $ZStudyCalendarFieldSpecs) spec.name,
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudyCalendar &&
          id == other.id &&
          organizationId == other.organizationId &&
          timezone == other.timezone &&
          label == other.label &&
          kind == other.kind &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    organizationId,
    timezone,
    label,
    kind,
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
