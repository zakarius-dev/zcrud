/// Entité `ZStudySession` — **séance** : une occurrence datée d'une offre.
///
/// À ne pas confondre avec la session de révision (`ZStudySessionConfig` et
/// ses satellites), qui décrit un travail personnel sans date ni lieu. Une
/// séance ici est un rendez-vous : elle a un début, éventuellement une fin, un
/// lieu et un lien de visioconférence.
///
/// [offeringId] est un identifiant **opaque** : l'offre elle-même n'appartient
/// pas à ce périmètre, et la séance ne dépend d'aucun type d'offre.
///
/// [topicRefs] déclare ce qui est traité pendant la séance. Rien n'oblige ces
/// thèmes à appartenir au programme de l'offre : le noyau ne recoupe pas les
/// deux et ne signale aucune incohérence.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

import 'z_external_ref.dart';
import 'z_study_json.dart';
import 'z_study_ref.dart';

part 'z_study_session.g.dart';

/// Reconstruit une [ZExtension] concrète depuis sa map JSON, ou `null`.
typedef ZStudySessionExtensionParser =
    ZExtension? Function(Map<String, dynamic> json);

/// Séance immuable.
@ZcrudModel(kind: 'study_session', fieldRename: ZFieldRename.snake)
class ZStudySession extends ZEntity with ZExtensible {
  /// Construit une séance.
  const ZStudySession({
    this.id,
    this.offeringId = '',
    this.startsAt,
    this.endsAt,
    this.kind = '',
    this.locationRef,
    this.meetingUrl,
    this.topicRefs = const <ZStudyRef>[],
    this.externalRefs = const <ZExternalRef>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
    // ignore: prefer_initializing_formals
  }) : _extra = extra;

  /// Reconstruit défensivement depuis une map persistée (invariant AD-10).
  ///
  /// Une date illisible retombe sur `null` — une séance sans début reste une
  /// séance, elle n'est simplement pas placée dans le temps.
  factory ZStudySession.fromMap(
    Map<String, dynamic> map, {
    ZStudySessionExtensionParser? extensionParser,
  }) {
    final base = _$ZStudySessionFromMap(map);
    final location = zStudyAsJsonMap(map['location_ref']);
    return ZStudySession(
      id: base.id,
      offeringId: base.offeringId,
      startsAt: base.startsAt,
      endsAt: base.endsAt,
      kind: base.kind,
      locationRef: location == null ? null : ZStudyRef.fromMap(location),
      meetingUrl: base.meetingUrl,
      topicRefs: zStudyDecodeRefs(map['topic_refs']),
      externalRefs: zStudyDecodeExternalRefs(map['external_refs']),
      extension: zDecodeExtension(map['extension'], extensionParser),
      extra: _sanitizeExtra(map),
    );
  }

  /// Identité opaque (nullable pour l'éphémère).
  @override
  @ZcrudId()
  final String? id;

  /// Offre dont la séance est une occurrence (identifiant opaque), défaut
  /// `''`.
  @ZcrudField()
  final String offeringId;

  /// Début de la séance (ISO-8601), `null` si non placée dans le temps.
  @ZcrudField()
  final DateTime? startsAt;

  /// Fin de la séance (ISO-8601), `null` si non bornée.
  @ZcrudField()
  final DateTime? endsAt;

  /// Type de séance — chaîne opaque, défaut `''`.
  @ZcrudField()
  final String kind;

  /// Lieu de la séance, `null` si non déclaré. Canal manuel (objet).
  @ZcrudIgnore()
  final ZStudyRef? locationRef;

  /// Lien de visioconférence, `null` si absent. Jamais interprété.
  @ZcrudField()
  final String? meetingUrl;

  /// Thèmes traités pendant la séance, défaut `const []`. Canal manuel.
  @ZcrudIgnore()
  final List<ZStudyRef> topicRefs;

  /// Identifiants de la séance dans des systèmes tiers, défaut `const []`.
  @ZcrudIgnore()
  final List<ZExternalRef> externalRefs;

  /// Slot type additif versionné (invariant AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (invariant AD-4), défaut `const {}`.
  @override
  Map<String, dynamic> get extra => zNormalizeExtra(_extra, _reservedKeys);

  /// Durée de la séance, `null` si l'une des deux bornes manque. Peut être
  /// négative : le noyau ne valide pas l'ordre des bornes.
  Duration? get duration =>
      (startsAt == null || endsAt == null) ? null : endsAt!.difference(startsAt!);

  /// Sérialise vers la map persistée (snake_case) ; aucune valeur absente
  /// n'écrit de clé, et une liste vide n'écrit pas de clé.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      ...extra,
      ...zStudyPrune(ZStudySessionZcrud(this).toMap()),
    };
    if (locationRef != null) map['location_ref'] = locationRef!.toMap();
    if (topicRefs.isNotEmpty) {
      map['topic_refs'] = zStudyEncodeList(
        topicRefs,
        (ZStudyRef ref) => ref.toMap(),
      );
    }
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
  ZStudySession copyWith({
    Object? id = _$undefined,
    Object? offeringId = _$undefined,
    Object? startsAt = _$undefined,
    Object? endsAt = _$undefined,
    Object? kind = _$undefined,
    Object? locationRef = _$undefined,
    Object? meetingUrl = _$undefined,
    Object? topicRefs = _$undefined,
    Object? externalRefs = _$undefined,
    Object? extension = _$undefined,
    Object? extra = _$undefined,
  }) => ZStudySession(
    id: identical(id, _$undefined) ? this.id : id as String?,
    offeringId: identical(offeringId, _$undefined)
        ? this.offeringId
        : offeringId as String,
    startsAt: identical(startsAt, _$undefined)
        ? this.startsAt
        : startsAt as DateTime?,
    endsAt: identical(endsAt, _$undefined) ? this.endsAt : endsAt as DateTime?,
    kind: identical(kind, _$undefined) ? this.kind : kind as String,
    locationRef: identical(locationRef, _$undefined)
        ? this.locationRef
        : locationRef as ZStudyRef?,
    meetingUrl: identical(meetingUrl, _$undefined)
        ? this.meetingUrl
        : meetingUrl as String?,
    topicRefs: identical(topicRefs, _$undefined)
        ? this.topicRefs
        : topicRefs as List<ZStudyRef>,
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
    for (final spec in $ZStudySessionFieldSpecs) spec.name,
    'location_ref',
    'topic_refs',
    'external_refs',
    'extension',
    ...ZSyncMeta.reservedKeys,
  };

  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStudySession &&
          id == other.id &&
          offeringId == other.offeringId &&
          startsAt == other.startsAt &&
          endsAt == other.endsAt &&
          kind == other.kind &&
          locationRef == other.locationRef &&
          meetingUrl == other.meetingUrl &&
          zStudyListEquals(topicRefs, other.topicRefs) &&
          zStudyListEquals(externalRefs, other.externalRefs) &&
          extension == other.extension &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    offeringId,
    startsAt,
    endsAt,
    kind,
    locationRef,
    meetingUrl,
    Object.hashAll(topicRefs),
    Object.hashAll(externalRefs),
    extension,
    zJsonHash(extra),
  ]);
}
