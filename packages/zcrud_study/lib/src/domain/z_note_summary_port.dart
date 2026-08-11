/// Seam IA neutre de résumé d'une note d'étude.
///
/// Contrat pur (`abstract interface class`, jamais `sealed`, invariant AD-4)
/// que l'application hôte implémente en le branchant sur son propre routeur
/// IA. Aucun prompt, endpoint, clé ni détail de transport ne fuit dans le
/// domaine (invariant AD-12) : ces éléments vivent uniquement dans
/// l'implémentation côté application.
library;

import 'package:zcrud_core/domain.dart';

/// Requête immuable de résumé (value-object, `==`/`hashCode` par valeur).
///
/// Porte un contenu neutre à résumer et une longueur cible optionnelle —
/// jamais un prompt ni un secret.
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
      other is ZNoteSummaryRequest &&
          content == other.content &&
          maxLength == other.maxLength &&
          languageTag == other.languageTag &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(content, maxLength, languageTag, zJsonHash(extra));
}

/// Port neutre de résumé de note (invariant AD-5 : domaine
/// backend-agnostique).
///
/// Retourne `ZResult<String>` (`Either<ZFailure, String>`) — jamais une
/// `String` nue. L'application hôte fournit l'implémentation.
abstract interface class ZNoteSummaryPort {
  /// Résume [request]. `Left` en cas d'échec, `Right` avec le résumé produit.
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request);
}
