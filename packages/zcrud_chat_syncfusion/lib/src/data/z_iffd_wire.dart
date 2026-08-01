/// Vocabulaire du **fil textuel d'IFFD** — CHAT-6.
///
/// 🔴 **Tout ce fichier est une COMPENSATION, et c'est pour cela qu'il vit dans
/// un satellite.** IFFD n'expose aucun contrat d'événements : il expose un flux
/// de texte dans lequel le serveur insère des marqueurs. Constaté dans
/// `smart_learn_cloudfunctions` :
///
/// | Fait mesuré | Fichier |
/// |---|---|
/// | tous les `\n` deviennent `###LINE###` | `tools.py:42`, `iffd/v1/router.py:352/422/641/834`, `iffd/v2/router.py:740/868` |
/// | sentinelles pseudo-XML dans le CORPS du message | `shared/layers/orchestrator/retriever_executor.py:224..393`, `coordinator.py:791..1367` |
/// | `<ROUND n>` … `</ROUND n>` (balise **paramétrée**) | `coordinator.py:1196/1246/1261/1265` |
/// | erreurs écrites EN CLAIR, avec emoji, dans le même canal | `synthesizer_executor.py:225/276`, `evaluator_executor.py:151`, `supervisor_executor.py:118` |
/// | préfixe `$` collé devant la balise | `shared/services/vector_store_service.py:394` (`f"${event} ###LINE###"`) |
/// | payload structuré laissé BALISÉ dans le flux | `tools.py:34-39` (retire le contenu, **pas** les balises) |
///
/// ## Pourquoi une famille OUVERTE et non une énumération fermée
///
/// Un relevé exhaustif des balises émises par `shared/layers/orchestrator/` en
/// donne **au moins douze** — `RAG_THINKING`, `RAG_ITERATION_n`, `RAG_ERROR_n`,
/// `RAG_REQUESTS_n`, `AI_MODEL_REASONING_n`, `CACHE_HIT`, `CACHE_MISS`,
/// `REASONING`, `RESPONSE`, `OUTIL`, `ERREUR`, `TOOL_ERROR`, `ROUND n` — et le
/// backend en ajoute au fil de ses agents. Une table fermée serait périmée au
/// premier déploiement, et une balise inconnue retomberait dans la réponse
/// affichée (le défaut exact d'IFFD, dont les cinq nettoyages par expression
/// régulière divergent déjà). Le lexeur reconnaît donc une **FORME**
/// (`<SCREAMING_SNAKE[ arg]>`), pas une liste ; le classement en canal est
/// dérivé, avec un **repli explicite** pour l'inconnu (AD-10).
library;

/// Encodage serveur du saut de ligne (`tools.py:42`).
///
/// ⚠️ Ce marqueur peut être **coupé entre deux fragments SSE** : un décodeur
/// qui ferait un simple `replaceAll` sur chaque fragment laisserait passer
/// `###LI` + `NE###` en clair. Le lexeur retient donc une queue de sécurité.
const String kZIffdLineMarker = '###LINE###';

/// Préfixe d'erreur écrit **en clair dans le canal de réponse** par les
/// exécuteurs d'agents (`⚠️ Erreur AnalysisAgent : …`).
///
/// 🔴 C'est le **défaut n°4** d'IFFD : ce texte est affiché comme s'il était la
/// réponse de l'assistant. AD-5 impose qu'il devienne un `Left` typé.
const String kZIffdPlainErrorPrefix = '⚠️ Erreur';

/// Canal logique auquel appartient le texte courant.
enum ZIffdChannel {
  /// La réponse destinée à l'utilisateur.
  answer,

  /// Le raisonnement / la trace d'outillage — jamais la réponse.
  thinking,

  /// Un diagnostic d'échec — devient un `Left` typé, **jamais** un message.
  failure,

  /// Une charge utile structurée (`<FINAL_ANSWER_PAYLOAD>`).
  payload,
}

/// Classement d'une balise IFFD en canal, **total** : aucune balise ne peut
/// être « non classée ».
///
/// Règles, dans l'ordre :
/// 1. une balise dont le nom contient `ERROR` ou vaut `ERREUR` ⇒
///    [ZIffdChannel.failure] ;
/// 2. `FINAL_ANSWER_PAYLOAD` ⇒ [ZIffdChannel.payload] ;
/// 3. `RESPONSE` ⇒ [ZIffdChannel.answer] (le serveur re-balise parfois la
///    réponse elle-même) ;
/// 4. **toute autre balise, connue ou non** ⇒ [ZIffdChannel.thinking].
///
/// 🔴 Le repli de la règle 4 est le choix structurant : une balise que zcrud ne
/// connaît pas envoie son contenu dans la **trace**, jamais dans la réponse.
/// L'inverse (repli « réponse ») ferait ré-apparaître du raisonnement dans le
/// corps affiché dès la prochaine balise ajoutée par le backend — c'est
/// littéralement la régression d'IFFD. Le contenu n'est jamais **perdu** : il
/// change de canal, il ne disparaît pas.
ZIffdChannel zIffdChannelOfTag(String tagName) {
  final String name = tagName.toUpperCase();
  if (name.contains('ERROR') || name == 'ERREUR') return ZIffdChannel.failure;
  if (name == 'FINAL_ANSWER_PAYLOAD') return ZIffdChannel.payload;
  if (name == 'RESPONSE') return ZIffdChannel.answer;
  return ZIffdChannel.thinking;
}

/// Nom d'agent **neutre** dérivé d'une balise (`RAG_ITERATION_2` →
/// `ragIteration2`), pour alimenter `ZChatThinkingStep.agent`.
///
/// Ce n'est **pas** un libellé d'interface : il n'est jamais affiché tel quel
/// (FR-26). C'est une donnée opaque, en camelCase — la convention de toute
/// valeur d'enum persistée du dépôt.
String zIffdAgentOfTag(String tagName) {
  final List<String> parts = tagName
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((String p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'iffd';
  final StringBuffer out = StringBuffer(parts.first);
  for (final String p in parts.skip(1)) {
    out
      ..write(p[0].toUpperCase())
      ..write(p.substring(1));
  }
  return out.toString();
}

/// Codes d'échec **verbatim** du fil IFFD, conservés dans
/// `ZChatProviderFailure.code` (aucun catalogue fermé, aucun `switch` d'hôte).
abstract final class ZIffdFailureCodes {
  /// Erreur d'agent écrite en clair dans le canal de réponse.
  static const String plainAgentError = 'iffdPlainAgentError';

  /// Contenu d'une balise d'erreur (`<RAG_ERROR_n>`, `<TOOL_ERROR>`, `<ERREUR>`).
  static const String taggedError = 'iffdTaggedError';
}

/// Discriminant du variant ouvert portant `<FINAL_ANSWER_PAYLOAD>` (AD-4).
const String kZIffdFinalAnswerPayloadKind = 'iffdFinalAnswerPayload';
