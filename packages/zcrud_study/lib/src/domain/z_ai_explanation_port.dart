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
    this.style,
    this.operation,
    this.routeId,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) : _extra = extra;

  /// Contenu neutre à expliquer.
  final String content;

  /// Contexte neutre optionnel (ex. matière, niveau) — jamais un prompt.
  final String? context;

  /// Étiquette de langue BCP-47 souhaitée, ou `null`.
  final String? languageTag;

  /// Forme de rendu demandée — **clé opaque du vocabulaire de l'hôte**,
  /// transmise verbatim au port et jamais interprétée ici.
  ///
  /// Ce paquet ne déclare aucune liste de styles : les valeurs admises, leur
  /// libellé et leur effet appartiennent entièrement à l'application. `null`
  /// signifie « pas de style demandé », jamais un style par défaut implicite.
  final String? style;

  /// Traitement demandé (reformulation, condensation, développement…) —
  /// **clé opaque du vocabulaire de l'hôte**, transmise verbatim et jamais
  /// interprétée ici.
  ///
  /// Une seule signature couvre tous les traitements : l'intention est une
  /// **donnée**, pas une méthode par variante. `null` signifie « explication
  /// initiale ».
  final String? operation;

  /// Identifiant de ROUTE opaque, transporté verbatim.
  ///
  /// Un transport « une route par intention de génération » associe une route
  /// à un modèle par défaut et à ses accès ; ce champ est l'endroit où
  /// l'intention de route voyage avec la requête. Sa résolution en transport
  /// réel appartient entièrement à l'implémentation du port. `null` signifie
  /// que l'application décide.
  final String? routeId;

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

  /// Copie portant [operation], et éventuellement un [style] ou un [content]
  /// différents ; tout autre champ est **inchangé** (l'`extra` d'origine est
  /// reconduit tel quel).
  ///
  /// Permet d'enchaîner un traitement sur le texte déjà obtenu sans
  /// reconstruire la requête champ par champ. Un argument omis (ou `null`)
  /// **préserve** la valeur courante : ce raccourci ne peut donc pas remettre
  /// un champ à `null` — reconstruire la requête pour cela.
  ZAiExplanationRequest withOperation(
    String operation, {
    String? style,
    String? content,
  }) =>
      ZAiExplanationRequest(
        content: content ?? this.content,
        context: context,
        languageTag: languageTag,
        style: style ?? this.style,
        operation: operation,
        routeId: routeId,
        extra: _extra,
      );

  /// Copie de cette requête portant [routeId], tous les autres champs
  /// **inchangés** (l'`extra` d'origine est reconduit tel quel).
  ///
  /// Contrairement à [withOperation], `null` est ici une valeur explicite :
  /// il remet la route à « l'application décide ».
  ZAiExplanationRequest withRouteId(String? routeId) => ZAiExplanationRequest(
        content: content,
        context: context,
        languageTag: languageTag,
        style: style,
        operation: operation,
        routeId: routeId,
        extra: _extra,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAiExplanationRequest &&
          content == other.content &&
          context == other.context &&
          languageTag == other.languageTag &&
          style == other.style &&
          operation == other.operation &&
          routeId == other.routeId &&
          zJsonEquals(extra, other.extra);

  @override
  int get hashCode => Object.hash(
        content,
        context,
        languageTag,
        style,
        operation,
        routeId,
        zJsonHash(extra),
      );
}

/// Port neutre d'explication (invariant AD-5 : domaine backend-agnostique).
///
/// Retourne `ZResult<String>` (`Either<ZFailure, String>`) — jamais une
/// `String` nue. L'application hôte fournit l'implémentation.
abstract interface class ZAiExplanationPort {
  /// Explique [request]. `Left` en cas d'échec, `Right` avec le texte produit.
  Future<ZResult<String>> explain(ZAiExplanationRequest request);
}
