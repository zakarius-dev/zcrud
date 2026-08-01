/// Fraîcheur/versionnage d'un jeu de données cité — `ZChatSourceFreshness`.
///
/// origine: lex_core (module « Assistant ») — `source_freshness.dart:38-117`.
///
/// **Dé-juridicisation** : `pendingAmendments` (« amendements » — vocabulaire
/// législatif) devient [ZChatSourceFreshness.pendingUpdates], persisté
/// `pending_updates`. L'ancienne clé `pending_amendments` reste **lue en alias**
/// (interop directe avec les documents lex existants), jamais réémise.
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

  /// 🔴 **Fail-safe** : `true` **uniquement** sur [ZChatDatasetFreshness.stale]
  /// **ou** [pendingUpdates].
  ///
  /// [ZChatDatasetFreshness.unknown] reste **NEUTRE** : un checksum non
  /// comparable n'est pas une preuve de péremption, et marquer « périmé » ce
  /// qu'on ne sait pas évaluer est une sur-affirmation (porté de
  /// `source_freshness.dart:77-78`). Garde **G9**.
  bool get isPotentiallyOutdated =>
      freshness == ZChatDatasetFreshness.stale || pendingUpdates;

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null`.
  ///
  /// [pendingUpdates] tolère les trois formes rencontrées : un `bool`, une
  /// **liste** non vide (forme de lex, `source_freshness.dart:88-89`) sous
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
  /// ⚠️ Le drapeau **dérivé** `is_potentially_outdated` de lex
  /// (`source_freshness.dart:115`) n'est **pas** réémis : une valeur dérivée
  /// persistée peut diverger de la règle qui la calcule, et lex lui-même déclare
  /// se fier « à la règle métier locale (source de vérité) ».
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
