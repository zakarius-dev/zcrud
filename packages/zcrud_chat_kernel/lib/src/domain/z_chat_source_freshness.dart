/// Fraîcheur/versionnage d'un jeu de données cité — `ZChatSourceFreshness`.
///
/// Un vocabulaire législatif (« amendements en attente ») devient ici
/// [ZChatSourceFreshness.pendingUpdates], persisté `pending_updates` — un nom
/// neutre pour un socle qui n'est pas propre au droit. L'ancienne clé
/// `pending_amendments` reste **lue en alias** (interop directe avec des
/// documents existants), jamais réémise.
library;

import 'package:zcrud_core/domain.dart';

import 'z_chat_enums.dart';

/// Fiche de fraîcheur d'un dataset cité par une réponse, immuable.
class ZChatSourceFreshness {
  /// Construit une fiche (immuable, `const`).
  const ZChatSourceFreshness({
    this.datasetId = '',
    this.domain,
    this.title,
    this.version,
    this.lastIndexedAt,
    this.checksum,
    this.freshness = ZChatDatasetFreshness.unknown,
    this.pendingUpdates = false,
  });

  /// Identifiant logique du dataset.
  final String datasetId;

  /// Domaine de catalogue, si connu.
  final String? domain;

  /// Titre lisible du dataset, si connu.
  final String? title;

  /// Version éditoriale, si connue.
  final String? version;

  /// Date de dernière indexation (ISO-8601), ou `null`.
  final DateTime? lastIndexedAt;

  /// Empreinte de fraîcheur, si exposée.
  final String? checksum;

  /// Statut de fraîcheur brut (défaut [ZChatDatasetFreshness.unknown]).
  final ZChatDatasetFreshness freshness;

  /// `true` si des mises à jour candidates non ingérées sont signalées.
  final bool pendingUpdates;

  /// **Fail-safe** : `true` **uniquement** sur [ZChatDatasetFreshness.stale]
  /// **ou** [pendingUpdates].
  ///
  /// [ZChatDatasetFreshness.unknown] reste **neutre** : un checksum non
  /// comparable n'est pas une preuve de péremption, et marquer « périmé » ce
  /// qu'on ne sait pas évaluer est une sur-affirmation.
  bool get isPotentiallyOutdated =>
      freshness == ZChatDatasetFreshness.stale || pendingUpdates;

  /// Décode **défensivement** (invariant AD-10) — `raw` non-`Map` ⇒ `null`.
  ///
  /// [pendingUpdates] tolère les trois formes rencontrées : un `bool`, une
  /// **liste** non vide (une forme rencontrée en pratique) sous
  /// `pending_updates` **ou** sous l'alias legacy `pending_amendments`.
  /// [lastIndexedAt] tolère l'alias `generated_at`.
  static ZChatSourceFreshness? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final Object? pending =
        map.containsKey('pending_updates')
            ? map['pending_updates']
            : map['pending_amendments'];
    return ZChatSourceFreshness(
      datasetId: zJsonString(map['dataset_id']),
      domain: zJsonStringOrNull(map['domain']),
      title: zJsonStringOrNull(map['title']),
      version: zJsonStringOrNull(map['version']),
      lastIndexedAt: zJsonDate(map['last_indexed_at']) ??
          zJsonDate(map['generated_at']),
      checksum: zJsonStringOrNull(map['checksum']),
      freshness: ZChatDatasetFreshness.fromJson(map['freshness']),
      pendingUpdates:
          pending is List ? pending.isNotEmpty : zJsonBool(pending, false),
    );
  }

  /// Sérialise en clés snake_case.
  ///
  /// Un drapeau **dérivé** `is_potentially_outdated` n'est **pas** réémis :
  /// une valeur dérivée persistée peut diverger de la règle qui la calcule —
  /// la source de vérité reste la règle métier locale, jamais une valeur
  /// figée.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'dataset_id': datasetId,
        if (domain != null) 'domain': domain,
        if (title != null) 'title': title,
        if (version != null) 'version': version,
        if (lastIndexedAt != null)
          'last_indexed_at': lastIndexedAt!.toIso8601String(),
        if (checksum != null) 'checksum': checksum,
        'freshness': freshness.jsonValue,
        'pending_updates': pendingUpdates,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatSourceFreshness &&
          datasetId == other.datasetId &&
          domain == other.domain &&
          title == other.title &&
          version == other.version &&
          lastIndexedAt == other.lastIndexedAt &&
          checksum == other.checksum &&
          freshness == other.freshness &&
          pendingUpdates == other.pendingUpdates;

  @override
  int get hashCode => Object.hash(
        datasetId,
        domain,
        title,
        version,
        lastIndexedAt,
        checksum,
        freshness,
        pendingUpdates,
      );

  @override
  String toString() =>
      'ZChatSourceFreshness(datasetId: $datasetId, freshness: $freshness)';
}
