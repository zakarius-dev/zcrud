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
    this.routeId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu neutre à résumer.
  final String content;

  /// Longueur cible indicative (nombre de caractères/mots — l'app interprète),
  /// ou `null`.
  final int? maxLength;

  /// Étiquette de langue BCP-47 souhaitée, ou `null`.
  final String? languageTag;

  /// Identifiant de **route** opaque, transporté tel quel et jamais interprété
  /// par ce paquet : aucun `enum`, aucun `switch`, aucun catalogue, et
  /// **jamais une URL** — le contrat reste sans transport (invariant AD-12).
  ///
  /// Deux modes de transport coexistent chez les applications hôtes : un
  /// endpoint unique à corps riche, et **une route par intention de
  /// génération** — mode qui porte la gouvernance (une route et ses accès
  /// associés à un plan d'abonnement) et permet de déclarer par tâche le
  /// modèle par défaut. Ce champ est l'endroit où l'intention de route voyage
  /// avec la requête ; sa résolution en transport réel appartient entièrement
  /// à l'implémentation du port. `null` signifie que l'application décide.
  final String? routeId;

  /// Copie de cette requête portant [routeId], tous les autres champs
  /// **inchangés** (l'`extra` d'origine est reconduit tel quel).
  ///
  /// Permet à une surface d'assemblage d'apposer la route juste avant l'appel
  /// du port, sans que l'appelant ait à reconstruire la requête champ par
  /// champ — et sans qu'aucune valeur saisie ne soit réécrite au passage.
  ZNoteSummaryRequest withRouteId(String? routeId) => ZNoteSummaryRequest(
        content: content,
        maxLength: maxLength,
        languageTag: languageTag,
        routeId: routeId,
        extra: _extra,
      );

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
          routeId == other.routeId &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode =>
      Object.hash(content, maxLength, languageTag, routeId, zJsonHash(extra));
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
