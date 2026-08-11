/// Seam IA neutre d'explication d'un contenu d'étude.
///
/// Contrat pur (`abstract interface class`, jamais `sealed`, invariant AD-4)
/// que l'application hôte implémente en le branchant sur son propre routeur
/// IA. Aucun prompt, endpoint, clé ni détail de transport ne fuit dans le
/// domaine (invariant AD-12) : ces éléments vivent uniquement dans
/// l'implémentation côté application.
library;

import 'package:zcrud_core/domain.dart';

/// Requête immuable d'explication (value-object, `==`/`hashCode` par
/// valeur).
///
/// Porte un contenu neutre à expliquer et un contexte neutre optionnel —
/// jamais un prompt ni un secret.
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

  /// Échappatoire non typée pour des paramètres spécifiques à l'application,
  /// normalisée à la lecture : les clés de synchronisation réservées
  /// (`updated_at`, `is_deleted`) sont toujours écartées, même si elles ont
  /// été fournies au constructeur. Ce DTO n'est pas persisté, mais cette
  /// normalisation garde un comportement uniforme sur tout porteur d'`extra`
  /// du domaine. Défaut `const {}`.
  Map<String, dynamic> get extra => zSanitizeExtra(_extra, _reservedKeys);

  /// Clés réservées écartées de [extra] à la lecture.
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

/// Port neutre d'explication (invariant AD-5 : domaine backend-agnostique).
///
/// Retourne `ZResult<String>` (`Either<ZFailure, String>`) — jamais une
/// `String` nue. L'application hôte fournit l'implémentation.
abstract interface class ZAiExplanationPort {
  /// Explique [request]. `Left` en cas d'échec, `Right` avec le texte produit.
  Future<ZResult<String>> explain(ZAiExplanationRequest request);
}

