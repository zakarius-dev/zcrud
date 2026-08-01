/// Identité d'une requête IA — annulation **ET reprise** (CHAT-1, D4).
///
/// ## 🔴 Le défaut que ce type ferme, mesuré sur disque
///
/// IFFD porte **un jeton d'INSTANCE unique** sur son dépôt IA :
///
/// ```dart
/// // iffd/lib/src/data/repositories/iffd_ai_repository_impl.dart:29
/// CancelToken cancel = CancelToken();          // champ de l'instance
/// …
/// void cancelAIGenerate() { cancel.cancel(); cancel = CancelToken(); }  // :375-377
/// ```
///
/// (même forme dans `openai_ai_repository_impl.dart:18` et `:204`). Le dépôt
/// étant un singleton partagé par TOUS les écrans, `cancelAIGenerate()` annule
/// « la requête courante » — c'est-à-dire **la dernière lancée**, pas celle que
/// l'utilisateur a désignée. Deux générations concurrentes (une explication de
/// dossier en cours + un message de chat) et le geste « stop » de l'une coupe
/// l'autre.
///
/// ## 🔴 Annulation et REPRISE sont le MÊME besoin : UNE identité, pas deux
///
/// Le backend de lex expose un protocole **reprenable** : chaque événement de
/// flux porte une **séquence monotone**, et le client **doit**, à la
/// reconnexion, renvoyer (a) la position du dernier événement reçu et (b) une
/// **identité de tour stable** pour que le serveur ne rejoue pas le tour. C'est
/// la **seule obligation ACTIVE du client** de tout ce contrat : partout
/// ailleurs le serveur a un défaut, ici non. Un port de streaming qui
/// l'ignorerait serait à refaire.
///
/// ⛔ Cette identité de tour n'est **PAS un second mécanisme** : c'est
/// exactement [requestId], celui que
/// `ZChatActionExecutor.cancelRequest(String requestId)` attend déjà
/// (CHAT-0b/D4). Une requête a **une** identité stable ; un champ parallèle
/// (clé d'idempotence, identifiant de tour, identifiant de corrélation…) ferait
/// diverger « ce que j'annule » de « ce que je reprends » — le défaut d'IFFD
/// réintroduit un cran plus haut. Garde **G-C9a** : aucun second identifiant
/// déclaré dans `lib/src/domain/ai/`, et `resumeFrom(...).requestId ==
/// requestId` (garde comportementale).
///
/// | Champ | Portée | Rôle |
/// |---|---|---|
/// | [requestId] | **le tour**, stable à travers les reprises | ce que `cancelRequest` annule ; ce que l'adaptateur transporte comme identité de tour |
/// | [lastSequenceId] | **une reprise** | position du dernier événement reçu (`ZChatStreamEvent.sequenceId`) |
///
/// ## ⚠️ Neutralité de transport (AD-11/AD-12)
///
/// Les en-têtes de reprise et d'idempotence sont des noms **HTTP** : ils
/// n'apparaissent dans **aucune ligne de code** de ce package — seulement dans
/// cette prose, pour dire d'où vient l'exigence. Le domaine modélise le
/// **besoin** (« dernier événement reçu », « identité de la requête ») ; c'est
/// l'adaptateur de l'hôte qui le traduit en en-têtes, et lui seul. Garde
/// **G-C9b** : aucun nom d'en-tête HTTP dans le code du domaine.
///
/// Le domaine ne **génère** aucune identité (aucune dépendance, AD-1) : l'hôte
/// fournit la valeur (un UUID v4 chez lex), zcrud la transporte **verbatim**
/// sans jamais l'interpréter.
///
/// ## La forme retenue pour l'annulation
///
/// Le jeton est un **paramètre requis de l'appel**, jamais un champ du port :
/// une implémentation ne peut pas « avoir un jeton », elle en **reçoit** un par
/// requête. Deux appels ⇒ deux jetons ⇒ deux annulations indépendantes.
///
/// - Garde **G-C1a** : aucun champ de type [ZChatRequestToken] dans
///   `lib/src/domain/ai/` (la forme exacte d'IFFD).
/// - Garde **G-C1b** : aucun champ **mutable** dans `lib/src/domain/ai/` (la
///   forme `String? currentRequestId;` — un identifiant de requête « courante »
///   stocké sur l'instance est le même défaut sous un autre type ; c'est
///   précisément la variante qu'une garde du lot précédent laissait passer).
///
/// ## Ce que ce type n'est PAS
///
/// Ce n'est **pas** un value object : deux jetons de même identité ne sont
/// **jamais** égaux (`==` d'identité, hérité d'`Object`). Les confondre
/// rétablirait le partage que ce type existe pour interdire.
library;

import 'dart:async';

/// Identité **et** état d'annulation d'**UNE** requête IA. Créée par
/// l'appelant, transmise à l'appel, jamais stockée par le port.
class ZChatRequestToken {
  /// Construit le jeton d'une requête.
  ///
  /// [requestId] est l'**unique** identité : celle que `cancelRequest` annule
  /// **et** celle que l'adaptateur transporte pour que le serveur ne rejoue pas
  /// le tour à la reconnexion. [lastSequenceId] n'est renseigné que sur une
  /// **reprise** (cf. [resumeFrom]) — un premier essai le laisse `null`.
  ZChatRequestToken(this.requestId, {this.lastSequenceId});

  /// Identité opaque de la requête — celle que
  /// `ZChatActionExecutor.cancelRequest` reçoit, **inchangée** à travers les
  /// reprises.
  final String requestId;

  /// Position de reprise : valeur de `ZChatStreamEvent.sequenceId` du dernier
  /// événement **effectivement reçu**, ou `null` pour un premier essai.
  ///
  /// `null` signifie **« depuis le début »**, jamais « depuis 0 » : un backend
  /// sans protocole reprenable n'émet aucune séquence, et confondre les deux
  /// ferait reprendre un flux au début en croyant le reprendre à sa position.
  final String? lastSequenceId;

  /// `true` si ce jeton **reprend** un flux interrompu (l'appelant attend la
  /// suite, pas un nouveau tour).
  bool get isResumption => lastSequenceId != null;

  final Completer<void> _cancelled = Completer<void>();

  /// `true` dès que [cancel] a été appelé sur **ce** jeton.
  bool get isCancelled => _cancelled.isCompleted;

  /// Se complète (sans valeur, **jamais en erreur**) à l'annulation de **ce**
  /// jeton. Ne se complète jamais si la requête va au bout — l'appelant
  /// n'attend ce futur qu'en concurrence de son flux.
  Future<void> get whenCancelled => _cancelled.future;

  /// Annule **cette** requête, et elle seule. Idempotent (AD-10 : un second
  /// appel ne lève pas).
  void cancel() {
    if (_cancelled.isCompleted) return;
    _cancelled.complete();
  }

  /// Jeton d'une **NOUVELLE tentative** du **MÊME** tour, reprenant après
  /// [lastSequenceId].
  ///
  /// 🔴 Rend un **nouveau** jeton — jamais une mutation de celui-ci : la
  /// tentative interrompue reste annulée/terminée, et la reprise est annulable
  /// indépendamment (règle « un appel, un jeton »). [requestId] est **conservé
  /// à l'identique** : c'est tout l'intérêt — le serveur reconnaît le tour et
  /// ne le rejoue pas, et le geste « stop » de l'utilisateur continue de viser
  /// la même identité qu'avant la coupure.
  ZChatRequestToken resumeFrom(String lastSequenceId) =>
      ZChatRequestToken(requestId, lastSequenceId: lastSequenceId);

  @override
  String toString() =>
      'ZChatRequestToken(requestId: $requestId, '
      'lastSequenceId: $lastSequenceId, cancelled: $isCancelled)';
}
