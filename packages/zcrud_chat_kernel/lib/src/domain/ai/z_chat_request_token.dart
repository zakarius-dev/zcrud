/// Identité d'une requête IA — annulation **et** reprise.
///
/// ## Le défaut que ce type ferme
///
/// Un dépôt IA qui porte **un jeton d'instance unique** (un champ
/// `CancelToken` réassigné à chaque appel) confond, dès que deux écrans
/// utilisent le même dépôt, « annuler » avec « annuler la dernière requête
/// lancée » — pas nécessairement celle que l'utilisateur a désignée. Deux
/// générations concurrentes et le geste « stop » de l'une coupe l'autre.
///
/// ## Annulation et reprise sont le même besoin : une identité, pas deux
///
/// Un backend de streaming reprenable expose un protocole où chaque
/// événement de flux porte une **séquence monotone**, et où le client doit, à
/// la reconnexion, renvoyer (a) la position du dernier événement reçu et (b)
/// une **identité de tour stable** pour que le serveur ne rejoue pas le tour.
///
/// Cette identité de tour n'est **pas un second mécanisme** : c'est
/// exactement [requestId], celui que
/// `ZChatActionExecutor.cancelRequest(String requestId)` attend déjà. Une
/// requête a **une** identité stable ; un champ parallèle (clé d'idempotence,
/// identifiant de tour, identifiant de corrélation…) ferait diverger « ce que
/// j'annule » de « ce que je reprends ».
///
/// | Champ | Portée | Rôle |
/// |---|---|---|
/// | [requestId] | **le tour**, stable à travers les reprises | ce que `cancelRequest` annule ; ce que l'adaptateur transporte comme identité de tour |
/// | [lastSequenceId] | **une reprise** | position du dernier événement reçu (`ZChatStreamEvent.sequenceId`) |
///
/// ## Neutralité de transport (invariants AD-11, AD-12)
///
/// Les en-têtes de reprise et d'idempotence sont des noms **HTTP** : ils
/// n'apparaissent dans **aucune ligne de code** de ce package. Le domaine
/// modélise le **besoin** (« dernier événement reçu », « identité de la
/// requête ») ; c'est l'adaptateur de l'hôte qui le traduit en en-têtes, et
/// lui seul.
///
/// Le domaine ne **génère** aucune identité (aucune dépendance, invariant
/// AD-1) : l'hôte fournit la valeur (par exemple un UUID v4), zcrud la
/// transporte **verbatim** sans jamais l'interpréter.
///
/// ## La forme retenue pour l'annulation
///
/// Le jeton est un **paramètre requis de l'appel**, jamais un champ du port :
/// une implémentation ne peut pas « avoir un jeton », elle en **reçoit** un par
/// requête. Deux appels ⇒ deux jetons ⇒ deux annulations indépendantes.
///
/// Aucun champ de type [ZChatRequestToken], et aucun champ **mutable**, ne
/// devrait apparaître dans les ports de `lib/src/domain/ai/` : un identifiant
/// de requête « courante » stocké sur l'instance est le même défaut
/// d'instance partagée sous un autre type.
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

  /// Annule **cette** requête, et elle seule. Idempotent (invariant AD-10 :
  /// un second appel ne lève pas).
  ///
  /// L'annulation est **au mieux** du côté du serveur : le port est notifié
  /// par [whenCancelled] et doit fermer son transport, mais rien ne garantit
  /// que la génération distante s'arrête ni qu'elle cesse d'être facturée —
  /// cela dépend du backend. Ce qui est garanti vit côté client : le partiel
  /// reçu est conservé et marqué interrompu, et aucun événement ultérieur
  /// n'est appliqué.
  void cancel() {
    if (_cancelled.isCompleted) return;
    _cancelled.complete();
  }

  /// Jeton d'une **NOUVELLE tentative** du **MÊME** tour, reprenant après
  /// [lastSequenceId].
  ///
  /// Rend un **nouveau** jeton — jamais une mutation de celui-ci : la
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
