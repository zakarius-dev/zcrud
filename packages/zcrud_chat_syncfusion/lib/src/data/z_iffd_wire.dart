/// Vocabulaire du fil textuel encodé selon la convention IFFD.
///
/// Tout ce fichier est une compensation, et c'est pour cela qu'il vit dans un
/// satellite plutôt que dans le kernel : ce backend n'expose aucun contrat
/// d'événements typés, seulement un flux de texte dans lequel le serveur
/// insère des marqueurs — un encodage du saut de ligne, des sentinelles
/// pseudo-XML dans le corps même du message (dont au moins une forme
/// paramétrée), et des erreurs d'agent écrites en clair dans le même canal
/// que la réponse plutôt que signalées séparément.
///
/// ## Pourquoi une famille ouverte de balises, et non une énumération fermée
///
/// Le nombre de sentinelles observées dépasse la douzaine, et le backend en
/// ajoute au fil de ses agents. Une table fermée serait périmée au premier
/// déploiement, et une balise inconnue retomberait dans la réponse affichée
/// — précisément le défaut que ce satellite corrige. Le lexeur reconnaît
/// donc une forme (`<SCREAMING_SNAKE[ arg]>`), pas une liste ; le classement
/// en canal est dérivé, avec un repli explicite pour l'inconnu (invariant
/// AD-10).
library;

/// Encodage du saut de ligne dans le fil.
///
/// Ce marqueur peut être coupé entre deux fragments de flux : un décodeur
/// qui ferait un simple remplacement de motif sur chaque fragment
/// laisserait passer la moitié du marqueur en clair. Le lexeur retient donc
/// une queue de sécurité (voir `ZIffdLexer`).
const String kZIffdLineMarker = '###LINE###';

/// Préfixe d'erreur écrit en clair dans le canal de réponse par les
/// exécuteurs d'agents de ce backend, au lieu d'un canal d'échec séparé.
///
/// Ce texte serait sinon affiché comme s'il était la réponse de l'assistant.
/// L'invariant AD-5 impose qu'il devienne un échec typé.
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

/// Classement d'une balise en canal, total : aucune balise ne peut être
/// « non classée ».
///
/// Règles, dans l'ordre :
/// 1. une balise dont le nom contient `ERROR` ou vaut `ERREUR` ⇒
///    [ZIffdChannel.failure] ;
/// 2. `FINAL_ANSWER_PAYLOAD` ⇒ [ZIffdChannel.payload] ;
/// 3. `RESPONSE` ⇒ [ZIffdChannel.answer] (le serveur re-balise parfois la
///    réponse elle-même) ;
/// 4. toute autre balise, connue ou non, ⇒ [ZIffdChannel.thinking].
///
/// Le repli de la règle 4 est le choix structurant : une balise inconnue
/// envoie son contenu dans la trace, jamais dans la réponse. Le repli
/// inverse (vers la réponse) ferait réapparaître du raisonnement dans le
/// corps affiché dès la prochaine balise ajoutée par le backend. Le contenu
/// n'est jamais perdu : il change de canal, il ne disparaît pas.
ZIffdChannel zIffdChannelOfTag(String tagName) {
  final String name = tagName.toUpperCase();
  if (name.contains('ERROR') || name == 'ERREUR') return ZIffdChannel.failure;
  if (name == 'FINAL_ANSWER_PAYLOAD') return ZIffdChannel.payload;
  if (name == 'RESPONSE') return ZIffdChannel.answer;
  return ZIffdChannel.thinking;
}

/// Nom d'agent neutre dérivé d'une balise (`RAG_ITERATION_2` →
/// `ragIteration2`), pour alimenter `ZChatThinkingStep.agent`.
///
/// Ce n'est pas un libellé d'interface : il n'est jamais affiché tel quel.
/// C'est une donnée opaque, en camelCase — la convention des valeurs d'enum
/// persistées de ce monorepo.
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

/// Codes d'échec verbatim du fil, conservés dans
/// `ZChatProviderFailure.code` (aucun catalogue fermé, aucun `switch` d'hôte).
abstract final class ZIffdFailureCodes {
  /// Erreur d'agent écrite en clair dans le canal de réponse.
  static const String plainAgentError = 'iffdPlainAgentError';

  /// Contenu d'une balise d'erreur (`<RAG_ERROR_n>`, `<TOOL_ERROR>`, `<ERREUR>`).
  static const String taggedError = 'iffdTaggedError';
}

/// Discriminant du variant ouvert portant `<FINAL_ANSWER_PAYLOAD>` (invariant
/// AD-4).
const String kZIffdFinalAnswerPayloadKind = 'iffdFinalAnswerPayload';
