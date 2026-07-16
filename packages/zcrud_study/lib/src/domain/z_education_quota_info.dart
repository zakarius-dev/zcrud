/// Value-object de quota IA éducatif `ZEducationQuotaInfo` — **fail-open**
/// (Story ES-9.1, AC3/AC4).
///
/// origine: seam IA neutre du domaine `zcrud_study` (AD-11/AD-4, quota fail-open
/// — architecture-zcrud-study §280). VO **éphémère** construit CÔTÉ APP à partir
/// des en-têtes HTTP du fournisseur IA : le domaine ne connaît **ni** endpoint,
/// **ni** clé, **ni** nom d'en-tête provider (AD-12). Ce n'est **pas** une entité
/// persistée (`@ZcrudModel`) — aucun `*.g.dart` : (dé)sérialisation **manuelle**
/// défensive (AD-10).
///
/// **Politique fail-open (règle centrale, l'inverse du réflexe)** : un quota
/// **indisponible** (tous champs `null`) NE BLOQUE PAS — [allowsRequest] vaut
/// `true`. Le SEUL cas bloquant est un `remaining` **connu** et ≤ 0. Le VO ne
/// décide **jamais** de politique réseau/retry : il expose seulement
/// [allowsRequest].
library;

/// Quota IA éducatif transport-agnostique. Les trois champs sont **nullables** :
/// `null` = information absente ⇒ **ne bloque pas** (fail-open, AC3).
class ZEducationQuotaInfo {
  /// Construit un quota à partir de ses trois compteurs (tous optionnels).
  const ZEducationQuotaInfo({this.limit, this.remaining, this.resetSeconds});

  /// Quota **indisponible** : aucune information (tous champs `null`).
  ///
  /// Fail-open : [allowsRequest] vaut `true` (l'absence d'info n'interdit rien).
  const ZEducationQuotaInfo.unavailable()
      : limit = null,
        remaining = null,
        resetSeconds = null;

  /// Reconstruit **défensivement** depuis une valeur brute (AD-10).
  ///
  /// - `raw` non-map / `null` ⇒ [ZEducationQuotaInfo.unavailable] ;
  /// - valeurs non numériques (`"abc"`, `true`, listes) ⇒ champ `null` (repli
  ///   sûr via [_asIntOrNull] : coercion `int`/`num`/`int.tryParse`) ;
  /// - **jamais** de `throw`.
  factory ZEducationQuotaInfo.fromJson(Object? raw) {
    if (raw is! Map) return const ZEducationQuotaInfo.unavailable();
    return ZEducationQuotaInfo(
      limit: _asIntOrNull(raw['limit']),
      remaining: _asIntOrNull(raw['remaining']),
      resetSeconds: _asIntOrNull(raw['reset_seconds']),
    );
  }

  /// Reconstruit depuis des en-têtes HTTP **avec noms de header INJECTÉS**.
  ///
  /// Les noms d'en-tête ([limitKey]/[remainingKey]/[resetKey]) sont **fournis
  /// par l'app** (le datasource connaît son fournisseur) : le VO ne code **aucun**
  /// nom de header provider en dur, sinon ce serait une fuite transport (viole
  /// AD-11/AD-12). Défensif : `headers` `null` ou clé
  /// absente / illisible ⇒ champ `null` (fail-open), **jamais** de `throw`.
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

  /// **Fail-open** : `true` sauf si le quota est **connu épuisé**
  /// (`remaining != null && remaining <= 0`).
  ///
  /// Quota indisponible (tous champs `null`) ⇒ `true` (ne bloque pas).
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

/// Coercion défensive vers `int?` (tolère `int`/`num`/`String`, repli `null`).
///
/// Ne lève **jamais** (AD-10) : `bool`, `List`, `Map`, `null` ⇒ `null`.
int? _asIntOrNull(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}
