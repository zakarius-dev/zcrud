/// Lecture du quota depuis une **carte de métadonnées neutre au transport**
/// (CHAT-1).
///
/// ## 🔴 Le quota n'arrive PAS dans le corps de la réponse
///
/// Vérifié sur le backend de lex : le quota voyage dans les **en-têtes de
/// réponse HTTP** (famille `X-Chat-Quota-*`, solde prépayé, délai de réessai) et
/// **jamais** dans le corps SSE — le client de lex synthétise lui-même son
/// `ChatQuotaEvent` à partir de ces en-têtes. Un `fromJson` qui supposerait un
/// corps JSON serait donc **structurellement incapable** de lire le quota réel.
///
/// ⇒ Ce fichier n'assume **aucun emplacement** : il lit une
/// `Map<String, Object?>` que l'adaptateur de l'hôte remplit depuis là où le
/// quota se trouve **chez lui** (en-têtes HTTP, métadonnées gRPC, champ de
/// corps, en-tête SSE). Le socle ne connaît pas HTTP (AD-12) ; il connaît une
/// carte clé→valeur.
///
/// ## 🔴 Absence POSSIBLE, jamais garantie (AD-10)
///
/// Une douzaine de kill-switches sont à `False` par défaut chez lex
/// (`CHAT_QUOTA_ENABLED`, `TRIAL_ENABLED`, `PREPAID_ENABLED`, `ENABLE_WEB_SEARCH`,
/// `ENABLE_RERANKING`…). Le code de quota y est **intégralement écrit et
/// inerte** : quand le drapeau est faux, **les en-têtes ne sortent pas du
/// tout**. C'est le piège « une mesure exacte et sans objet ».
///
/// ⇒ [zChatQuotaFromMetadata] rend **`null`** quand aucune clé de quota n'est
/// présente — jamais un instantané à zéro, qui se lirait comme « quota épuisé »
/// (`ZChatQuotaSnapshot.isExhausted`) et **bloquerait l'utilisateur d'un
/// déploiement où le quota est simplement désactivé**. Chaque champ manquant
/// reste à son défaut neutre.
///
/// Aucun type nouveau : `ZChatQuotaSnapshot` (CHAT-0) est **réutilisé tel
/// quel**, il porte déjà exactement `limit`/`remaining`/`resetEpoch`/
/// `prepaidBalance`.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_quota_snapshot.dart';

/// Noms de clés de quota — **injectables**, jamais figés.
///
/// ## 🔴 Aucun nom d'en-tête HTTP dans le domaine (AD-11/AD-12, garde G-C9b)
///
/// Les défauts sont des clés **logiques neutres** (`limit`, `remaining`, …),
/// pas les en-têtes d'un transport particulier : `zcrud_chat_kernel` ne connaît
/// ni HTTP ni SSE. L'adaptateur de l'hôte **projette** ses en-têtes sur ces
/// clés — ou, s'il préfère les garder tels quels, passe les siens ici. Écrire
/// `'x-chat-quota-limit'` dans le domaine ferait entrer un détail de transport
/// dans le socle et le rendrait faux pour tout hôte qui n'est pas lex.
///
/// La comparaison est **insensible à la casse** : les en-têtes le sont, et une
/// carte recopiée à la main ne l'est jamais tout à fait.
class ZChatQuotaKeys {
  /// Construit un jeu de clés (les défauts couvrent le transport de lex).
  const ZChatQuotaKeys({
    this.limit = 'limit',
    this.remaining = 'remaining',
    this.reset = 'reset_epoch',
    this.prepaidBalance = 'prepaid_balance',
    this.retryAfter = 'retry_after_seconds',
  });

  /// Clé du plafond de la période.
  final String limit;

  /// Clé du reste disponible.
  final String remaining;

  /// Clé de l'instant de réinitialisation (epoch secondes).
  final String reset;

  /// Clé du solde prépayé.
  final String prepaidBalance;

  /// Clé du délai avant réessai (**secondes**) — alimente
  /// `ZQuotaExceededFailure.retryAfter`. Même nom que celui lu par
  /// `zChatFailureFromWire` : une seule convention dans tout le lot.
  final String retryAfter;

  /// Toutes les clés, en minuscules.
  Set<String> get all => <String>{
    limit.toLowerCase(),
    remaining.toLowerCase(),
    reset.toLowerCase(),
    prepaidBalance.toLowerCase(),
    retryAfter.toLowerCase(),
  };
}

/// Jeu de clés par défaut.
const ZChatQuotaKeys kZChatQuotaKeys = ZChatQuotaKeys();

/// Lit un instantané de quota depuis [metadata], **quelle qu'en soit la
/// provenance**.
///
/// Rend `null` si **aucune** clé de quota n'est présente — cas normal quand le
/// backend a le quota désactivé (kill-switch). Ne lève jamais (AD-10) : une
/// valeur non numérique est traitée comme absente.
ZChatQuotaSnapshot? zChatQuotaFromMetadata(
  Map<String, Object?>? metadata, {
  ZChatQuotaKeys keys = kZChatQuotaKeys,
}) {
  if (metadata == null || metadata.isEmpty) return null;
  final Map<String, Object?> lower = <String, Object?>{
    for (final MapEntry<String, Object?> e in metadata.entries)
      e.key.toLowerCase(): e.value,
  };
  final Set<String> present = lower.keys.toSet().intersection(keys.all)
    ..remove(keys.retryAfter.toLowerCase());
  if (present.isEmpty) return null;
  return ZChatQuotaSnapshot(
    limit: _int(lower[keys.limit.toLowerCase()]) ?? 0,
    remaining: _int(lower[keys.remaining.toLowerCase()]) ?? 0,
    resetEpoch: _int(lower[keys.reset.toLowerCase()]) ?? 0,
    prepaidBalance: _int(lower[keys.prepaidBalance.toLowerCase()]),
  );
}

/// Lit le délai `Retry-After` (secondes) de [metadata] — `null` si absent.
///
/// C'est ce qui alimente `ZQuotaExceededFailure.retryAfter` (type EXISTANT du
/// cœur). `null` ne veut **jamais** dire « réessayable tout de suite ».
Duration? zChatRetryAfterFromMetadata(
  Map<String, Object?>? metadata, {
  ZChatQuotaKeys keys = kZChatQuotaKeys,
}) {
  if (metadata == null) return null;
  for (final MapEntry<String, Object?> e in metadata.entries) {
    if (e.key.toLowerCase() != keys.retryAfter.toLowerCase()) continue;
    final int? seconds = _int(e.value);
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }
  return null;
}

/// Lecture entière **tolérante** : `int`, `num`, ou `String` numérique
/// (les en-têtes sont toujours du texte). Tout le reste ⇒ `null`.
int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return zJsonIntOrNull(value);
}
