/// Value-object de quota IA éducatif, à la politique délibérément
/// **fail-open**.
///
/// Value-object éphémère construit côté application à partir des en-têtes
/// HTTP du fournisseur IA : le domaine ne connaît ni endpoint, ni clé, ni nom
/// d'en-tête provider (invariant AD-12). Ce n'est pas une entité persistée
/// (`@ZcrudModel`) — sa (dé)sérialisation est manuelle et défensive
/// (invariant AD-10).
///
/// Politique fail-open : un quota indisponible (tous champs `null`) ne
/// bloque rien — [allowsRequest] vaut `true`. Le seul cas bloquant est un
/// `remaining` connu et inférieur ou égal à zéro. Ce value-object ne décide
/// jamais d'une politique réseau ou de nouvelle tentative : il expose
/// uniquement [allowsRequest].
library;

/// Quota IA éducatif transport-agnostique. Les trois champs sont
/// nullables : `null` signifie une information absente, qui ne bloque pas
/// (politique fail-open).
class ZEducationQuotaInfo {
  /// Construit un quota à partir de ses trois compteurs (tous optionnels).
  const ZEducationQuotaInfo({this.limit, this.remaining, this.resetSeconds});

  /// Quota indisponible : aucune information (tous champs `null`).
  ///
  /// Politique fail-open : [allowsRequest] vaut `true` (l'absence
  /// d'information n'interdit rien).
  const ZEducationQuotaInfo.unavailable()
      : limit = null,
        remaining = null,
        resetSeconds = null;

  /// Reconstruit défensivement depuis une valeur brute (invariant AD-10 :
  /// désérialisation qui ne jette jamais).
  ///
  /// - `raw` non-map ou `null` : repli sur [ZEducationQuotaInfo.unavailable] ;
  /// - valeurs non numériques (`"abc"`, `true`, listes) : champ `null` (repli
  ///   sûr via une coercion `int`/`num`/`int.tryParse`) ;
  /// - ne lève jamais.
  factory ZEducationQuotaInfo.fromJson(Object? raw) {
    if (raw is! Map) return const ZEducationQuotaInfo.unavailable();
    return ZEducationQuotaInfo(
      limit: _asIntOrNull(raw['limit']),
      remaining: _asIntOrNull(raw['remaining']),
      resetSeconds: _asIntOrNull(raw['reset_seconds']),
    );
  }

  /// Reconstruit depuis des en-têtes HTTP dont les noms sont injectés par
  /// l'appelant.
  ///
  /// Les noms d'en-tête ([limitKey], [remainingKey], [resetKey]) sont
  /// fournis par l'application (la source de données connaît son
  /// fournisseur) : ce value-object ne code aucun nom d'en-tête de
  /// fournisseur en dur — ce serait une fuite de détail de transport
  /// (invariant AD-12). Défensif : `headers` `null` ou clé absente ou
  /// illisible produit un champ `null` (fail-open), jamais un `throw`.
  factory ZEducationQuotaInfo.fromHeaders(
    Map<String, String>? headers, {
    required String limitKey,
    required String remainingKey,
    required String resetKey,
  }) {
    if (headers == null) return const ZEducationQuotaInfo.unavailable();
    return ZEducationQuotaInfo(
      limit: _asIntOrNull(headers[limitKey]),
      remaining: _asIntOrNull(headers[remainingKey]),
      resetSeconds: _asIntOrNull(headers[resetKey]),
    );
  }

  /// Plafond total de requêtes sur la fenêtre, ou `null` si inconnu.
  final int? limit;

  /// Requêtes restantes, ou `null` si inconnu. `remaining <= 0` = **épuisé**
  /// (seul cas bloquant).
  final int? remaining;

  /// Secondes avant réinitialisation de la fenêtre, ou `null` si inconnu.
  final int? resetSeconds;

  /// Politique fail-open : `true` sauf si le quota est connu épuisé
  /// (`remaining != null && remaining <= 0`).
  ///
  /// Un quota indisponible (tous champs `null`) vaut `true` : il ne bloque
  /// pas.
  bool get allowsRequest => !(remaining != null && remaining! <= 0);

  /// Sérialise vers une map (les trois champs, `null` inclus — round-trip exact).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'limit': limit,
        'remaining': remaining,
        'reset_seconds': resetSeconds,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZEducationQuotaInfo &&
          limit == other.limit &&
          remaining == other.remaining &&
          resetSeconds == other.resetSeconds;

  @override
  int get hashCode => Object.hash(limit, remaining, resetSeconds);

  @override
  String toString() =>
      'ZEducationQuotaInfo(limit: $limit, remaining: $remaining, '
      'resetSeconds: $resetSeconds)';
}

/// Coercion défensive vers `int?` (tolère `int`, `num`, `String`, repli
/// `null`).
///
/// Ne lève jamais (invariant AD-10) : `bool`, `List`, `Map` ou `null`
/// produisent `null`.
int? _asIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
