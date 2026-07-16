/// Seam IA neutre de **résumé de note** `ZNoteSummaryPort` (Story ES-9.1,
/// AC1/AC2).
///
/// origine: seam IA neutre du domaine `zcrud_study` (AD-5/AD-11/AD-12). Contrat
/// pur (`abstract interface class`, AD-4 — **jamais `sealed`**) : l'app hôte
/// l'*implements* avec son routeur IA. Aucun prompt / endpoint / clé / transport
/// ne fuit dans le domaine (impls CÔTÉ APP).
library;

import 'package:zcrud_core/domain.dart';

/// Requête **immuable** de résumé (value-object, `==`/`hashCode` par valeur).
///
/// Contenu neutre à résumer + longueur cible optionnelle. Aucun prompt/secret
/// (AC2).
class ZNoteSummaryRequest {
  /// Construit une requête de résumé du [content].
  const ZNoteSummaryRequest({
    required this.content,
    this.maxLength,
    this.languageTag,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu neutre à résumer.
  final String content;

  /// Longueur cible indicative (nombre de caractères/mots — l'app interprète),
  /// ou `null`.
  final int? maxLength;

  /// Étiquette de langue BCP-47 souhaitée, ou `null`.
  final String? languageTag;

  /// Slot brut de l'échappatoire (normalisé à la LECTURE via [extra]).
  final Map<String, dynamic> _extra;

  /// Échappatoire non typée (paramètres app-specific neutres). Défaut `const {}`.
  /// **Normalisée à la LECTURE (AD-19.1)** : les clés de sync réservées
  /// (`updated_at`/`is_deleted`) sont écartées — jamais réémises. Ce DTO n'est
  /// pas persisté, mais la garde machine reste uniforme sur tout porteur d'`extra`.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] (AD-19.1, `...ZSyncMeta.reservedKeys`).
  static final Set<String> _reservedKeys = <String>{...ZSyncMeta.reservedKeys};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNoteSummaryRequest &&
          content == other.content &&
          maxLength == other.maxLength &&
          languageTag == other.languageTag &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(content, maxLength, languageTag, zJsonHash(extra));
}

/// Port neutre de **résumé de note** (AD-5 : `Either<ZFailure,·>`).
///
/// Retourne `ZResult<String>` (`Either<ZFailure, String>`) — jamais une `String`
/// nue, jamais un `Stream` enveloppé (AD-5). L'app hôte fournit l'impl.
abstract interface class ZNoteSummaryPort {
  /// Résume [request]. `Left` en cas d'échec, `Right` avec le résumé produit.
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request);
}
