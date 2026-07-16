/// Seam IA neutre d'**explication** `ZAiExplanationPort` (Story ES-9.1, AC1/AC2).
///
/// origine: seam IA neutre du domaine `zcrud_study` (AD-5/AD-11/AD-12). Contrat
/// pur (`abstract interface class`, AD-4 — **jamais `sealed`**) : l'app hôte
/// l'*implements* avec son routeur IA. Aucun prompt / endpoint / clé / transport
/// ne fuit dans le domaine (impls CÔTÉ APP).
library;

import 'package:zcrud_core/domain.dart';

/// Requête **immuable** d'explication (value-object, `==`/`hashCode` par valeur).
///
/// Contenu neutre à expliquer + contexte neutre optionnel. Aucun prompt/secret
/// (AC2).
class ZAiExplanationRequest {
  /// Construit une requête d'explication du [content].
  const ZAiExplanationRequest({
    required this.content,
    this.context,
    this.languageTag,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu neutre à expliquer.
  final String content;

  /// Contexte neutre optionnel (ex. matière, niveau) — jamais un prompt.
  final String? context;

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
      other is ZAiExplanationRequest &&
          content == other.content &&
          context == other.context &&
          languageTag == other.languageTag &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(content, context, languageTag, zJsonHash(extra));
}

/// Port neutre d'**explication** (AD-5 : `Either<ZFailure,·>`).
///
/// Retourne `ZResult<String>` (`Either<ZFailure, String>`) — jamais une `String`
/// nue, jamais un `Stream` enveloppé (AD-5). L'app hôte fournit l'impl.
abstract interface class ZAiExplanationPort {
  /// Explique [request]. `Left` en cas d'échec, `Right` avec le texte produit.
  Future<ZResult<String>> explain(ZAiExplanationRequest request);
}

