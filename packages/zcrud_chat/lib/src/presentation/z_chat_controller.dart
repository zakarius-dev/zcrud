/// Contrôleur de conversation IA.
///
/// ## Le défaut de structure que ce fichier rend inexprimable
///
/// Deux implémentations parallèles d'une même barre d'actions (une pour une
/// vue compacte, une pour une vue détaillée, par exemple) divergent tôt ou
/// tard : supprimer se comporte différemment ici et là, régénérer a
/// plusieurs comportements distincts, annuler peut supprimer la saisie en
/// cours ailleurs que prévu, un jeton d'annulation partagé en champ
/// d'instance fait qu'arrêter une génération coupe la dernière lancée,
/// jamais celle qu'on désigne.
///
/// Ici, le contrôleur expose un seul point d'entrée pour tous les verbes —
/// [ZChatController.runAction] — et c'est le seul site du paquet qui invoque
/// `ZChatActionDispatcher`. Une seconde surface ne peut pas exister : il n'y
/// a pas de `deleteMessage()`, pas de `regenerateAnswer()`, pas de callback
/// par verbe. Le verbe est une donnée (`ZChatAction`, famille scellée du
/// kernel), pas une méthode.
///
/// ## Invariant AD-2 — objectif produit n°1 du dépôt
///
/// La réactivité est Flutter-native (invariants AD-2/AD-15) : aucun
/// gestionnaire d'état n'est importé, ni ici ni jamais. L'état est découpé
/// en tranches `ValueListenable` indépendantes, dimensionnées sur leur
/// fréquence :
///
/// | Tranche | Signale quand | Coût si on la fusionnait |
/// |---|---|---|
/// | [composer] (`TextEditingController`) | à chaque frappe | la liste des messages se reconstruirait à chaque touche — le bug historique que zcrud existe pour corriger |
/// | [attachmentIds] | ajout/retrait de pièce jointe | idem |
/// | [canSend] | passage vide ↔ non vide seulement | un `bool` égal ne notifie pas (`ValueNotifier`) |
/// | [messages] | message ajouté/retiré | reconstruction de toute la liste à chaque jeton |
/// | [activeRequests] | début/fin d'une requête | idem |
/// | [streamText] (par requestId) | à chaque jeton | le composer se reconstruirait sous les doigts de l'utilisateur |
/// | [progress] (par requestId) | réflexion, sources, quota | l'indicateur clignoterait à chaque jeton |
/// | [lastFailure] | échec typé | — |
/// | [liveAnnouncement] | jalons d'un tour (début, fin, arrêt, échec, édition) | une région live qui parle à chaque jeton est inutilisable |
///
/// Les tranches par requête sont stables par identité (même instance pour un
/// même `requestId`), sur le patron de `ZFormController.fieldListenable` :
/// un `ValueListenableBuilder` ne se ré-abonne jamais.
///
/// `notifyListeners()` (le canal global de `ChangeNotifier`) est réservé aux
/// changements structurels — le seul est [attach], qui change de
/// conversation. Ni une frappe, ni un jeton, ni un échec ne le déclenche.
///
/// ## Un jeton par requête, et la reprise sous la même identité
///
/// [send] fabrique un `ZChatRequestToken` par appel et l'indexe par
/// `requestId`. Il n'existe aucun champ « jeton courant » : deux flux
/// concurrents s'annulent indépendamment.
///
/// Sur `ZChatStreamInterruptedFailure` subie (`cancelledByUser == false`),
/// le contrôleur reprend via `token.resumeFrom(lastSequenceId)` : même
/// `requestId`, même `ZChatGenerationRequest`, texte accumulé conservé,
/// message utilisateur non ré-émis. Le tour n'est pas rejoué — c'est la
/// seule obligation active du client dans un protocole de reprise de flux.
///
/// ## Garantie d'annulation
///
/// Arrêter une génération (`runAction(ZChatCancelAction(requestId))`) est un
/// **contrat**, pas un effet de bord :
///
/// 1. le jeton désigné — et lui seul — est annulé ; son `whenCancelled`
///    se résout, et le port **doit** s'en servir pour fermer son transport ;
/// 2. le contenu déjà reçu est **conservé** comme message d'assistant et
///    **marqué interrompu** ([ZChatController.isInterrupted]) ; il n'est
///    jamais perdu ;
/// 3. la phase de la requête passe à `ZChatPhase.cancelled` ; aucune
///    reprise n'est tentée ;
/// 4. la saisie en cours n'est **pas** touchée ;
/// 5. le résultat de `send` est un `Left(ZChatStreamInterruptedFailure)` avec
///    `cancelledByUser == true` — un arrêt voulu n'est pas une panne.
///
/// ## Ports optionnels, à défaut inerte
///
/// Le contrôleur reste une classe **concrète** : une capacité s'ajoute par
/// un port optionnel du constructeur, jamais par héritage. Port absent ⇒
/// capacité absente, tout le reste fonctionne. Ainsi `lifecycle`
/// (`ZChatConversationLifecyclePort`) rend l'édition rejouée et la
/// régénération **natives** (consommées par le cycle de flux unique) ; sans
/// lui, ces verbes restent délégués à l'exécuteur de l'hôte, inchangés.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
// Import confiné par `show`, et c'est structurel. `TextEditingController`
// est la seule chose dont ce paquet ait besoin hors de `foundation` : c'est
// un objet d'état, mais il vit dans `widgets` (`editable_text.dart`).
// L'importer sans `show` ouvrirait tout `flutter/widgets` — donc
// `StatefulWidget`, `setState`, `Padding`, `Alignment`… — dans un paquet qui
// ne doit rendre aucun pixel.
// `flutter/material.dart` et `flutter/cupertino.dart` restent bannis : c'est
// par eux qu'entrent les couleurs et les styles de texte codés en dur.
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_live_labels.dart';
import 'z_chat_stream_progress.dart';

/// Demande de confirmation à l'utilisateur — seam d'hôte.
///
/// Le dialogue, ses libellés, ses icônes et ses couleurs appartiennent à
/// l'application (invariants AD-2/AD-13) : ce paquet ne connaît ni
/// `BuildContext`, ni widget, ni chaîne traduisible. Il impose seulement
/// que la question soit posée avant tout effet destructeur.
typedef ZChatConfirm = Future<bool> Function(ZChatActionPlan plan);

/// Fabrique d'identité de requête — fournie par l'hôte (typiquement un
/// UUID v4).
///
/// Le domaine ne génère aucune identité (aucune dépendance, invariant AD-1) :
/// il la transporte verbatim sans jamais l'interpréter.
typedef ZChatRequestIdFactory = String Function();

/// Construit la requête de génération à partir de la saisie soumise.
///
/// Les prompts, le modèle, le style et les instructions système restent
/// côté application (invariants AD-11/AD-12) : le contrôleur ne compose
/// aucun prompt.
typedef ZChatRequestBuilder =
    ZChatGenerationRequest Function(ZChatDraft draft);

/// **Route** la requête d'un tour avant son envoi — seam d'hôte, pur.
///
/// Reçoit la requête **après** le builder et les réglages, rend la requête
/// routée (fournisseur, modèle, budget de repli, paramètres) ou un refus
/// typé. Sur `Left`, le tour n'est **pas** ouvert : aucun message optimiste,
/// aucun appel de port, saisie intacte ; l'échec est publié sur
/// `ZChatController.lastFailure` et rendu à l'appelant. Un résolveur qui
/// lève vaut un refus. `ZChatRouteSession.resolve` en est l'implémentation
/// de référence.
typedef ZChatRouteResolver =
    ZResult<ZChatGenerationRequest> Function(ZChatGenerationRequest request);

/// Nombre de requêtes **terminées** dont les tranches restent vivantes.
///
/// Assez large pour couvrir la transition d'un tour vers son message établi (un
/// widget en cours de démontage peut encore lire sa tranche pendant une frame),
/// assez étroit pour que la mémoire ne suive pas la longueur de la
/// conversation. Ce n'est pas un réglage d'apparence : c'est une **borne**, et
/// elle n'est donc pas injectable.
const int _kRetainedSlices = 8;

/// État privé d'une requête en vol — sans canal réactif.
///
/// `lastSequenceId` et `eventsReceived` changent à chaque jeton. Les publier
/// en tranche ferait de `progress` un canal à haute fréquence : tout
/// écoutant de la progression se reconstruirait des centaines de fois par
/// tour.
class _ZRequestState {
  _ZRequestState(
    this.request, {
    this.emitsUserMessage = true,
    this.insertAt,
    this.rollback = const <ZChatMessage>[],
    this.rollbackAt = 0,
  });

  /// Requête d'origine — **réutilisée telle quelle** par une reprise (aucun
  /// rejeu, aucune reconstruction de prompt).
  final ZChatGenerationRequest request;

  /// `true` si un message utilisateur optimiste (id = `requestId`) a été
  /// ajouté au fil — c'est lui qu'un échec sans production retire.
  final bool emitsUserMessage;

  /// Position où la réponse doit être **insérée** (régénération : à la place
  /// de l'ancienne), ou `null` pour l'ajouter en fin de fil.
  final int? insertAt;

  /// Messages retirés localement **avant** le tour (régénération, édition
  /// rejouée) — restitués si le tour n'a rien produit.
  final List<ZChatMessage> rollback;

  /// Index du premier message de [rollback] dans le fil d'origine.
  final int rollbackAt;

  /// Position du dernier événement **effectivement reçu**, ou `null`.
  String? lastSequenceId;

  /// Nombre d'événements reçus, toutes tentatives confondues.
  int eventsReceived = 0;

  /// Blocs de contenu structurés reçus hors jetons de texte.
  final List<ZContentBlock> blocks = <ZContentBlock>[];

  /// Identité du message d'assistant annoncée par l'événement terminal.
  String? messageId;

  /// Identité de conversation annoncée par l'événement terminal.
  String? conversationId;
}

/// Session d'édition d'un message déjà envoyé.
///
/// Le mode édition n'est pas un booléen éparpillé sur plusieurs champs :
/// c'est une valeur immuable d'une tranche, qu'on lit d'un coup ou pas du
/// tout.
@immutable
class ZChatEditingSession {
  /// Construit une session d'édition.
  const ZChatEditingSession({
    required this.messageId,
    required this.originalText,
  });

  /// Identité **opaque** du message utilisateur en cours d'édition.
  final String messageId;

  /// Texte d'origine du message — celui que [ZChatController.startEditing]
  /// pré-remplit dans la saisie.
  final String originalText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatEditingSession &&
          messageId == other.messageId &&
          originalText == other.originalText;

  @override
  int get hashCode => Object.hash(messageId, originalText);
}

/// Le contrôleur de conversation : **un** point d'entrée par geste, des
/// tranches réactives **granulaires**, un jeton **par requête**.
class ZChatController extends ChangeNotifier {
  /// Construit un contrôleur.
  ///
  /// [streamPort] et [actionExecutor] sont les ports de l'hôte ; [confirm] est
  /// le seam de confirmation ; [newRequestId] fabrique les identités ;
  /// [buildRequest] traduit une saisie en requête de génération.
  ///
  /// [maxResumeAttempts] borne la **reprise** d'un flux subi (jamais d'une
  /// annulation volontaire). `0` la désactive.
  ///
  /// [lifecycle] est **optionnel** : présent, l'édition rejouée
  /// (`ZChatEditAction`) et la régénération (`ZChatRegenerateAction`) sont
  /// exécutées **nativement** — élagage par `trimAfter`, troncature locale,
  /// puis nouveau tour consommé par le même cycle de flux que [send] ; absent,
  /// ces deux verbes restent délégués à [actionExecutor].
  ///
  /// [liveLabels] porte les libellés des annonces de région live ; omis,
  /// les jalons sans contenu sont silencieux (cf. [ZChatLiveLabels]).
  ///
  /// [draftStore] est **optionnel** : présent, la saisie en cours est confiée
  /// au port quand la conversation change (et par [saveDraft] à la demande),
  /// puis restituée au retour dans la conversation ; absent, la saisie ne
  /// survit pas à la session — sans qu'aucun appel n'échoue.
  ///
  /// [routeResolver] est **optionnel** : présent, chaque requête — envoi,
  /// édition rejouée, régénération — lui est soumise après les réglages et
  /// avant toute trace dans le fil ; absent, la requête envoyée est celle du
  /// builder, inchangée (cf. [ZChatRouteResolver]).
  ZChatController({
    required ZChatStreamPort streamPort,
    required ZChatActionExecutor actionExecutor,
    required ZChatConfirm confirm,
    required ZChatRequestIdFactory newRequestId,
    required ZChatRequestBuilder buildRequest,
    ZChatConversationLifecyclePort? lifecycle,
    ZChatRouteResolver? routeResolver,
    ZChatDraftStore? draftStore,
    ZChatLiveLabels liveLabels = ZChatLiveLabels.none,
    this.maxResumeAttempts = 2,
    String conversationId = '',
    List<ZChatMessage> initialMessages = const <ZChatMessage>[],
    // `prefer_initializing_formals` est inapplicable ici : un paramètre
    // nommé ne peut pas s'appeler `_streamPort` (les formels privés sont
    // interdits en Dart). Rendre ces champs publics pour satisfaire le lint
    // élargirait la surface publique du contrôleur — l'inverse de
    // l'invariant « un seul point d'entrée ».
    // ignore: prefer_initializing_formals
  }) : _streamPort = streamPort,
       _dispatcher = ZChatActionDispatcher(actionExecutor),
       // ignore: prefer_initializing_formals
       _confirm = confirm,
       // ignore: prefer_initializing_formals
       _newRequestId = newRequestId,
       // ignore: prefer_initializing_formals
       _buildRequest = buildRequest,
       // ignore: prefer_initializing_formals
       _lifecycle = lifecycle,
       // ignore: prefer_initializing_formals
       _routeResolver = routeResolver,
       _draftStore = draftStore ?? const ZChatNullDraftStore(),
       // ignore: prefer_initializing_formals
       _labels = liveLabels,
       // ignore: prefer_initializing_formals
       _conversationId = conversationId,
       _messages = ValueNotifier<List<ZChatMessage>>(
         List<ZChatMessage>.unmodifiable(initialMessages),
       ) {
    composer.addListener(_onComposerChanged);
  }

  final ZChatStreamPort _streamPort;

  /// Le répartiteur **unique** des verbes de conversation : aucun membre de
  /// `ZChatActionExecutor` n'est joignable autrement que par lui.
  final ZChatActionDispatcher _dispatcher;

  final ZChatConfirm _confirm;
  final ZChatRequestIdFactory _newRequestId;
  final ZChatRequestBuilder _buildRequest;

  /// Port de cycle de vie — **optionnel, à défaut inerte** : `null` laisse
  /// l'édition rejouée et la régénération à l'exécuteur de l'hôte.
  final ZChatConversationLifecyclePort? _lifecycle;

  /// Résolveur de route — **optionnel, à défaut inerte** : `null` envoie la
  /// requête du builder telle quelle.
  final ZChatRouteResolver? _routeResolver;

  /// Conservation du brouillon — **jamais `null`, à défaut inerte**.
  ///
  /// Le contrôleur n'écrit sur aucun support : il délègue. Sans store
  /// déclaré, l'inerte rend « rien d'enregistré » et réussit toute écriture ;
  /// aucun chemin d'exception n'existe donc pour ce défaut (invariant AD-10).
  final ZChatDraftStore _draftStore;

  /// Libellés d'annonce fournis par l'hôte (aucune phrase n'est écrite ici).
  final ZChatLiveLabels _labels;

  /// Nombre maximal de **reprises** d'un flux interrompu subi.
  final int maxResumeAttempts;

  String _conversationId;

  /// Identités des messages d'assistant **interrompus** (arrêt volontaire ou
  /// panne) dont le contenu partiel a été conservé.
  final Set<String> _interrupted = <String>{};

  /// Requête d'origine de chaque message d'assistant produit **dans cette
  /// session** — c'est elle qu'une régénération rejoue telle quelle.
  final Map<String, ZChatGenerationRequest> _requestByMessageId =
      <String, ZChatGenerationRequest>{};

  // ── Tranches réactives ────────────────────────────────────────────────────

  /// Saisie en cours — **instance STABLE**, créée une fois, jamais recréée.
  ///
  /// Un `TextEditingController` reconstruit dans un `build()` fait perdre le
  /// curseur et la sélection à chaque frappe (invariant AD-2). Ici il
  /// appartient au contrôleur et vit aussi longtemps que lui ([dispose] s'en
  /// charge).
  final TextEditingController composer = TextEditingController();

  final ValueNotifier<List<String>> _attachmentIds =
      ValueNotifier<List<String>>(const <String>[]);
  final ValueNotifier<bool> _canSend = ValueNotifier<bool>(false);
  final ValueNotifier<List<ZChatMessage>> _messages;
  final ValueNotifier<List<String>> _activeRequests =
      ValueNotifier<List<String>>(const <String>[]);
  final ValueNotifier<ZFailure?> _lastFailure = ValueNotifier<ZFailure?>(null);
  final ValueNotifier<String> _liveAnnouncement = ValueNotifier<String>('');
  final ValueNotifier<ZChatEditingSession?> _editing =
      ValueNotifier<ZChatEditingSession?>(null);
  final ValueNotifier<int> _draftSeeds = ValueNotifier<int>(0);

  /// Propositions de la conversation COURANTE — l'agrégat de [suggestions].
  ///
  /// Vidé par [attach] : c'est ce qui rend l'agrégat cloisonné plutôt que
  /// cumulatif.
  final ValueNotifier<List<ZChatSuggestion>> _suggestions =
      ValueNotifier<List<ZChatSuggestion>>(const <ZChatSuggestion>[]);

  final ValueNotifier<bool> _draftRestored = ValueNotifier<bool>(false);

  /// Saisie en cours AVANT l'entrée en mode édition — restituée à la sortie.
  ///
  /// Sans cette sauvegarde, entrer en édition écraserait le brouillon en
  /// cours et l'annuler viderait le champ : le texte que l'utilisateur
  /// composait serait perdu deux fois. Ici il est restitué, dans les deux
  /// cas.
  ZChatDraft? _preEditingDraft;

  /// Jetons indexés **par `requestId`** — jamais un champ « jeton courant ».
  ///
  /// Un champ d'instance unique partagé par toutes les requêtes ferait
  /// qu'arrêter une génération couperait la **dernière lancée**, jamais
  /// celle qu'on désigne. Ici, annuler s'adresse toujours à une identité.
  final Map<String, ZChatRequestToken> _tokens = <String, ZChatRequestToken>{};

  final Map<String, ValueNotifier<String>> _streamTexts =
      <String, ValueNotifier<String>>{};
  final Map<String, ValueNotifier<ZChatStreamProgress>> _progress =
      <String, ValueNotifier<ZChatStreamProgress>>{};
  final Map<String, _ZRequestState> _states = <String, _ZRequestState>{};

  /// Identités des requêtes **terminées** dont les tranches sont encore
  /// retenues, de la plus ancienne à la plus récente (cf. [_release]).
  final List<String> _retained = <String>[];

  bool _disposed = false;

  // ── Surface publique de LECTURE ───────────────────────────────────────────

  /// Pièces jointes attachées à la saisie en cours.
  ValueListenable<List<String>> get attachmentIds => _attachmentIds;

  /// `true` si la saisie est envoyable. Ne signale qu'aux **transitions**
  /// vide ↔ non vide : un `ValueNotifier<bool>` ignore une valeur égale, donc
  /// taper le 2ᵉ caractère ne reconstruit pas le bouton d'envoi.
  ValueListenable<bool> get canSend => _canSend;

  /// Messages **établis** de la conversation (jamais le texte en cours de
  /// rédaction — il vit dans [streamText]).
  ///
  /// Identités : le message utilisateur optimiste d'un tour porte son
  /// `requestId` ; la réponse porte l'identité annoncée par l'événement
  /// terminal, ou, à défaut (tour interrompu), `<requestId>/reply`. Deux
  /// messages du fil ne partagent jamais une identité.
  ///
  /// Cette tranche est une **liste**, pas un widget : rien ici n'empêche la
  /// virtualisation. Le rendu doit rester un `ListView.builder`.
  ValueListenable<List<ZChatMessage>> get messages => _messages;

  /// Identités des requêtes **en vol**, dans l'ordre de lancement.
  ValueListenable<List<String>> get activeRequests => _activeRequests;

  /// Dernier échec **typé** rencontré, ou `null`.
  ///
  /// Un échec n'est **jamais** un message : pousser le texte brut d'une
  /// exception dans le corps d'une bulle, affiché comme si c'était la
  /// réponse de l'assistant, est le piège que cette séparation évite. Ici il
  /// vit dans sa propre tranche, hors de [messages], et porte un type —
  /// jamais une chaîne à parser.
  ValueListenable<ZFailure?> get lastFailure => _lastFailure;

  /// Texte à annoncer dans une **région live** (invariant AD-13).
  ///
  /// Une réponse qui arrive en streaming resterait muette pour un lecteur
  /// d'écran sans cette tranche : elle ne change qu'aux **jalons** (fin de
  /// tour, interruption), jamais à chaque jeton — une région live qui parle
  /// des centaines de fois par tour est inutilisable. Le
  /// `Semantics(liveRegion: true)` qui la consomme appartient au rendu.
  ///
  /// Son contenu est **celui de l'assistant**, jamais une phrase écrite par
  /// le socle : aucune chaîne traduisible n'est codée en dur ici.
  ValueListenable<String> get liveAnnouncement => _liveAnnouncement;

  /// Session d'ÉDITION en cours, ou `null`.
  ///
  /// Tranche **granulaire** (invariants AD-2/AD-13) : elle ne signale qu'à
  /// l'entrée et à la sortie du mode — jamais à la frappe. C'est elle que
  /// l'hôte lit dans son créneau `trailing` pour troquer l'icône d'envoi
  /// contre l'icône de validation et monter son bandeau (les valeurs de
  /// rendu sont dans `ZChatComposerReference`).
  ValueListenable<ZChatEditingSession?> get editing => _editing;

  /// Compteur **monotone** des brouillons acceptés par [seedDraft].
  ///
  /// Re-semer un texte **identique** ne change pas la valeur du
  /// `TextEditingController`, donc ne notifie personne. Un hôte qui veut
  /// réagir au geste (donner le focus, dérouler la vue) écoute cette
  /// tranche — elle signale chaque semis, même à texte égal.
  ValueListenable<int> get draftSeeds => _draftSeeds;

  /// Les propositions de relance de la conversation courante.
  ///
  /// Vue **agrégée par conversation** : `progress(requestId).suggestions` est
  /// la même donnée indexée par requête, illisible pour un rendu qui n'a pas
  /// de `requestId` en main — un composer, typiquement. Ici, la dernière
  /// livraison reçue **dans la conversation courante** ; jamais celle d'une
  /// autre, et jamais un cumul entre conversations.
  ///
  /// Instance **stable** : un `ValueListenableBuilder` ne se ré-abonne jamais.
  /// Vide tant qu'aucun `ZChatSuggestionsEvent` n'est arrivé.
  ValueListenable<List<ZChatSuggestion>> get suggestions => _suggestions;

  /// `true` quand la saisie courante provient d'un brouillon **restitué** par
  /// [ZChatDraftStore], et non de la frappe de l'utilisateur.
  ///
  /// C'est le canal d'un indicateur : sans lui, un texte réapparu à
  /// l'ouverture d'une conversation est indiscernable d'un texte tapé.
  /// Retombe à `false` dès que la saisie est soumise, que la conversation
  /// change, ou que [dismissRestoredDraft] est appelé.
  ValueListenable<bool> get draftRestored => _draftRestored;

  /// `true` si un [ZChatDraftStore] **effectif** est déclaré.
  ///
  /// Un assemblage s'en sert pour ne monter l'indicateur de restitution que
  /// là où quelque chose peut être restitué : sans store, le rang resterait
  /// muet à vie.
  bool get persistsDraft => _draftStore is! ZChatNullDraftStore;

  /// Saisie courante, telle qu'un verbe la transporte (`ZChatDraft`).
  ZChatDraft get currentDraft => ZChatDraft(
    text: composer.text,
    attachmentIds: List<String>.unmodifiable(_attachmentIds.value),
  );

  /// Identité de conversation courante.
  String get conversationId => _conversationId;

  /// Texte **accumulé** de la requête [requestId] — la tranche à **haute
  /// fréquence** (un signal par `ZChatTokenEvent`).
  ///
  /// Renvoie **toujours la même instance** pour un `requestId` donné : un
  /// `ValueListenableBuilder` ne se ré-abonne jamais (patron
  /// `ZFormController.fieldListenable`).
  ValueListenable<String> streamText(String requestId) => _textOf(requestId);

  /// Progression **grossière** de la requête [requestId] — jamais son texte.
  ///
  /// Instance stable par identité, comme [streamText].
  ValueListenable<ZChatStreamProgress> progress(String requestId) =>
      _progressOf(requestId);

  // ── Requêtes PURES sur le fil (jamais d'exception, `null` si absent) ──────

  /// Le message d'identité [messageId], ou `null` s'il n'est pas dans
  /// [messages]. Balayage linéaire — O(n) sur la longueur du fil.
  ZChatMessage? messageById(String messageId) {
    for (final ZChatMessage m in _messages.value) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  /// Le message **apparié** à [messageId] dans l'échange, ou `null`.
  ///
  /// Pour un message **utilisateur** : la première réponse d'assistant qui le
  /// suit, avant tout autre message utilisateur. Pour un message
  /// **assistant** : le dernier message utilisateur qui le précède. Tout
  /// autre rôle, ou une identité absente, rend `null`. O(n).
  ZChatMessage? replyToOf(String messageId) {
    final List<ZChatMessage> thread = _messages.value;
    final int at = thread.indexWhere((ZChatMessage m) => m.id == messageId);
    if (at < 0) return null;
    switch (thread[at].role) {
      case ZChatRole.user:
        for (int i = at + 1; i < thread.length; i++) {
          final ZChatMessage m = thread[i];
          if (m.role == ZChatRole.assistant) return m;
          if (m.role == ZChatRole.user) return null;
        }
        return null;
      case ZChatRole.assistant:
        for (int i = at - 1; i >= 0; i--) {
          if (thread[i].role == ZChatRole.user) return thread[i];
        }
        return null;
      case ZChatRole.system:
      case ZChatRole.unknown:
        return null;
    }
  }

  /// Texte **brut** du message [messageId] — ses blocs de texte concaténés
  /// par un saut de ligne, sans les blocs structurés — ou `null` s'il est
  /// absent. O(n).
  String? contentOf(String messageId) {
    final ZChatMessage? m = messageById(messageId);
    if (m == null) return null;
    return <String>[
      for (final ZContentBlock b in m.contentBlocks)
        if (b is ZTextBlock) b.text,
    ].join('\n');
  }

  /// Nombre de messages **postérieurs** à [messageId] — ceux qu'une édition
  /// rejouée retire. `0` si l'identité est absente. Calcul pur, O(n).
  int previewEditImpact(String messageId) {
    final List<ZChatMessage> thread = _messages.value;
    final int at = thread.indexWhere((ZChatMessage m) => m.id == messageId);
    return at < 0 ? 0 : thread.length - at - 1;
  }

  /// `true` si le message d'assistant [messageId] est un contenu **partiel**
  /// conservé après un arrêt volontaire ou une panne du flux.
  bool isInterrupted(String messageId) => _interrupted.contains(messageId);

  // ── Écriture de la saisie — UN SEUL site ──────────────────────────────────

  /// Remplace les pièces jointes de la saisie.
  ///
  /// Passe par [_setComposer], **seul** écrivain de la saisie (cf. son
  /// dartdoc) : aucun chemin d'action ne peut la toucher par mégarde.
  void setAttachments(List<String> ids) =>
      _setComposer(ZChatDraft(text: composer.text, attachmentIds: ids));

  /// Entre en mode ÉDITION du message [messageId].
  ///
  /// La saisie est pré-remplie avec [originalText] (via [_setComposer], le
  /// seul écrivain), et le brouillon que l'utilisateur composait est
  /// **sauvegardé** pour être restitué à la sortie (cf. [_preEditingDraft]).
  /// Ré-appeler pendant une édition change de cible sans écraser cette
  /// sauvegarde.
  ///
  /// La **soumission** de l'édition reste [runAction] avec `ZChatEditAction`
  /// (impact chiffré, confirmation, exécution par l'hôte) : ce verbe-ci ne
  /// fait qu'installer l'état. [send] est **refusé** tant que le mode est
  /// actif — cela évite qu'une frappe sur Entrée poste un nouveau message
  /// pendant une édition en cours.
  void startEditing({required String messageId, required String originalText}) {
    _preEditingDraft ??= currentDraft;
    _editing.value = ZChatEditingSession(
      messageId: messageId,
      originalText: originalText,
    );
    _setComposer(
      ZChatDraft(text: originalText, attachmentIds: _attachmentIds.value),
    );
    _say(_labels.editingStarted);
  }

  /// Sort du mode édition **sans soumettre**.
  ///
  /// La saisie d'avant l'édition est **restituée**, jamais simplement
  /// vidée : le geste d'annuler ne coûte aucun texte (invariant AD-10). Sans
  /// session active, l'appel est sans effet.
  void cancelEditing() {
    if (_editing.value == null) return;
    final ZChatDraft restored = _preEditingDraft ?? const ZChatDraft();
    _preEditingDraft = null;
    _editing.value = null;
    _setComposer(restored);
  }

  /// Sème un BROUILLON dans la saisie, sans envoyer.
  ///
  /// Passe par [_setComposer] — un widget qui poserait `composer.text`
  /// lui-même contournerait l'écrivain unique de la saisie. **Refusé pendant
  /// une édition** — on ne touche pas au champ pendant un mode édition actif
  /// — et le compteur [draftSeeds] n'est alors **pas** incrémenté : il ne
  /// compte que les semis appliqués.
  void seedDraft(String text) {
    if (_editing.value != null) return;
    _setComposer(
      ZChatDraft(text: text, attachmentIds: _attachmentIds.value),
    );
    _draftSeeds.value = _draftSeeds.value + 1;
  }

  // ── Brouillon PERSISTÉ — le port, et rien d'autre ────────────────────────
  //
  // Deux choses portent le mot « brouillon », et elles ne se confondent
  // jamais ici :
  //
  //   * le brouillon TRANSPORTÉ : `ZChatDraft`, la valeur qu'un verbe passe
  //     (`currentDraft`, `seedDraft`, `_preEditingDraft`). Il vit en mémoire,
  //     le temps d'un geste, et n'a aucun support.
  //   * le brouillon PERSISTÉ : la MÊME valeur, confiée à `ZChatDraftStore`
  //     sous une identité de conversation, pour survivre au changement de
  //     conversation ou à la session.
  //
  // Le pont entre les deux tient en deux points : `currentDraft` est ce qu'on
  // écrit, `_setComposer` est ce qui applique un brouillon relu. Aucun autre
  // site ne franchit la frontière.

  /// Confie la saisie courante au [ZChatDraftStore] de la conversation
  /// courante.
  ///
  /// À appeler quand l'application passe en arrière-plan ou se ferme : le
  /// contrôleur, lui, ne sauvegarde spontanément qu'au changement de
  /// conversation. Sans store déclaré, l'appel réussit sans effet.
  Future<void> saveDraft() => _saveDraftFor(_conversationId, currentDraft);

  /// Restitue le brouillon enregistré de la conversation courante, s'il y en
  /// a un **et** si le champ est libre.
  ///
  /// Rend `true` si un brouillon a effectivement été appliqué.
  ///
  /// **Une saisie en cours l'emporte toujours** : si l'utilisateur a déjà
  /// tapé du texte ou joint une pièce, rien n'est restitué. Une édition
  /// active bloque de même — le champ y porte le message qu'on modifie.
  Future<bool> restoreDraft() async {
    if (!_draftFieldIsFree) return false;
    final String at = _conversationId;
    final ZChatDraft? read = await _readDraftFor(at);
    // Tout a pu bouger PENDANT la lecture : le port est asynchrone. Trois
    // choses se revérifient donc après l'attente, et pas avant :
    //   * le contrôleur est-il encore vivant ;
    //   * est-on encore dans la conversation dont on vient de lire le
    //     brouillon (sinon on le poserait dans une autre) ;
    //   * le champ est-il encore libre — c'est ICI que se joue « ne pas
    //     écraser une saisie en cours » : l'utilisateur a pu taper pendant
    //     que le stockage répondait, et un contrôle fait seulement à
    //     l'entrée l'aurait manqué.
    if (_disposed || _conversationId != at || !_draftFieldIsFree) return false;
    if (read == null) return false;
    if (read.text.isEmpty && read.attachmentIds.isEmpty) return false;
    _setComposer(read);
    _draftRestored.value = true;
    return true;
  }

  /// Éteint l'indicateur de restitution **sans toucher à la saisie**.
  ///
  /// Le geste dit « j'ai vu », pas « efface » : un indicateur qui viderait le
  /// champ ferait perdre le texte qu'il venait de rendre.
  void dismissRestoredDraft() => _draftRestored.value = false;

  /// `true` si le champ n'appartient à personne — ni à une frappe, ni à une
  /// pièce jointe, ni à une session d'édition.
  bool get _draftFieldIsFree =>
      composer.text.isEmpty &&
      _attachmentIds.value.isEmpty &&
      _editing.value == null;

  /// Écrit — **sans jamais lever** (invariant AD-10).
  Future<void> _saveDraftFor(String conversationId, ZChatDraft draft) async {
    // Le port est contractuellement sans exception (`ZResult`, invariant
    // AD-5). Mais la sauvegarde est déclenchée sans être attendue au
    // changement de conversation : un store d'hôte fautif produirait alors
    // une erreur asynchrone NON RATTRAPÉE — un plantage à distance du site
    // fautif. Le repli garde la faute là où elle a lieu.
    try {
      await _draftStore.write(conversationId, draft);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Un brouillon non enregistré ne coûte rien à la saisie en cours.
    }
  }

  /// Efface — **sans jamais lever** (invariant AD-10), même raison que
  /// [_saveDraftFor] : l'appel n'est pas attendu.
  Future<void> _clearDraftFor(String conversationId) async {
    try {
      await _draftStore.clear(conversationId);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      // Un brouillon qui survit à son envoi est un défaut d'hôte, pas une
      // raison de faire échouer l'envoi.
    }
  }

  /// Lit — **sans jamais lever**. Rend `null` pour « rien d'enregistré »
  /// comme pour « le stockage est en panne » : ni l'un ni l'autre ne
  /// justifie de vider le champ ou d'alarmer l'utilisateur (invariant AD-10).
  Future<ZChatDraft?> _readDraftFor(String conversationId) async {
    try {
      final ZResult<ZChatDraft?> read = await _draftStore.read(conversationId);
      return read.fold((ZFailure _) => null, (ZChatDraft? draft) => draft);
      // ignore: avoid_catches_without_on_clauses
    } catch (_) {
      return null;
    }
  }

  /// **L'unique écrivain de la saisie de l'utilisateur.**
  ///
  /// Si plusieurs chemins pouvaient écrire dans le champ de saisie, un
  /// verbe déclenché pendant un état transitoire (par exemple arrêter une
  /// génération) pourrait accidentellement effacer le texte que
  /// l'utilisateur vient de taper. Ici il n'y a qu'un seul point d'écriture,
  /// et des tests de garde vérifient cette propriété structurellement :
  /// aucun autre site de `lib/` n'écrit `composer.text` en dehors de cette
  /// méthode et de `ZChatCaptureController.acceptInto`.
  void _setComposer(ZChatDraft draft) {
    if (composer.text != draft.text) composer.text = draft.text;
    _attachmentIds.value = List<String>.unmodifiable(draft.attachmentIds);
    // Sans cet appel explicite, `_canSend` ne serait recalculé que par le
    // listener du `TextEditingController` : joindre un fichier sans rien
    // taper ne changerait pas `composer.text`, donc ne notifierait rien, et
    // laisserait `canSend` à `false` alors même que [send] accepte une pièce
    // jointe seule (`draft.text.trim().isEmpty && draft.attachmentIds.isEmpty`
    // est le seul refus).
    _onComposerChanged();
  }

  void _onComposerChanged() {
    _canSend.value =
        composer.text.trim().isNotEmpty || _attachmentIds.value.isNotEmpty;
  }

  // ── Changement STRUCTUREL ─────────────────────────────────────────────────

  /// Change de conversation — **le seul** déclencheur de `notifyListeners()`.
  ///
  /// Toutes les requêtes en vol sont annulées (chacune par **son** jeton), les
  /// tranches par requête sont libérées, la saisie est remise à zéro.
  void attach({required String conversationId, List<ZChatMessage> messages = const <ZChatMessage>[]}) {
    // La saisie de la conversation QUITTÉE est confiée au port AVANT toute
    // remise à zéro : lue après `_setComposer(const ZChatDraft())`, elle
    // serait déjà vide, et le changement de conversation effacerait le
    // brouillon au lieu de le conserver.
    final String leaving = _conversationId;
    final ZChatDraft outgoing = currentDraft;
    for (final ZChatRequestToken token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _states.clear();
    for (final ValueNotifier<String> n in _streamTexts.values) {
      n.dispose();
    }
    _streamTexts.clear();
    for (final ValueNotifier<ZChatStreamProgress> n in _progress.values) {
      n.dispose();
    }
    _progress.clear();
    _retained.clear();
    _interrupted.clear();
    _requestByMessageId.clear();
    _conversationId = conversationId;
    _messages.value = List<ZChatMessage>.unmodifiable(messages);
    _activeRequests.value = const <String>[];
    _lastFailure.value = null;
    _liveAnnouncement.value = '';
    // Lot K2 : une session d'édition appartient à SA conversation — elle ne
    // survit pas au changement. Le compteur de brouillons, lui, reste monotone
    // (c'est un signal de geste, pas un état de conversation).
    _editing.value = null;
    _preEditingDraft = null;
    // L'agrégat appartient à SA conversation : gardé, il ferait apparaître
    // les propositions de la précédente sous le champ de la suivante.
    _suggestions.value = const <ZChatSuggestion>[];
    _draftRestored.value = false;
    _setComposer(const ZChatDraft());
    // Ni la sauvegarde ni la restitution ne retiennent le changement de
    // conversation : le fil s'affiche tout de suite, le brouillon rejoint le
    // champ quand le port a répondu — et seulement s'il est encore libre.
    unawaited(_saveDraftFor(leaving, outgoing));
    unawaited(restoreDraft());
    notifyListeners();
  }

  // ── Envoi & flux ──────────────────────────────────────────────────────────

  /// Soumet la saisie courante et **consomme le flux** jusqu'à son terme.
  ///
  /// Rend le jeton de la requête (identité stable, y compris à travers les
  /// reprises) ou l'échec **typé**. Aucun appel concurrent n'est interdit :
  /// deux `send()` produisent deux jetons **indépendants**.
  ///
  /// La saisie est vidée à la soumission ; si le tour échoue **sans avoir rien
  /// produit**, elle est **restituée** et le message optimiste est retiré
  /// (AD-10 : une panne ne coûte jamais la frappe de l'utilisateur).
  ///
  /// ## Les réglages sont appliqués APRÈS le builder, et c'est le point
  ///
  /// [settings] et [corpusScope] sont les porteurs neutres du kernel
  /// (`ZChatGenerationSettings`, `ZChatCorpusScope`). Ils sont
  /// **optionnels** : omis, ils laissent le chemin d'exécution *strictement*
  /// inchangé — `withSettings(null)` rend `identical(this)`, si bien que le
  /// port reçoit **l'objet même** que le builder de l'hôte a construit.
  ///
  /// Ils sont appliqués **après** [_buildRequest], jamais passés dedans. Ce
  /// n'est pas un détail d'ordre : un hôte qui recevrait les réglages
  /// directement dans son builder pourrait les transmettre en amont puis les
  /// laisser être ignorés plus loin dans sa propre chaîne, sans que rien ne
  /// détrompe l'utilisateur qui croit avoir restreint sa recherche. Ici
  /// l'application n'a pas la main sur ce site : le socle écrit les réglages
  /// sur la requête, et le port les lit sur les champs du contrat.
  ///
  /// [settings] est un **remplacement**, pas une fusion (règle du kernel) :
  /// un porteur *vide* remet les quatre réglages à « l'hôte décide », y
  /// compris ceux que le builder avait posés. C'est délibéré — une feuille
  /// de réglages qui **retire** un réglage doit pouvoir le retirer.
  /// [corpusScope] `null`, lui, ne retire **rien** : la portée éventuellement
  /// posée par le builder est conservée (l'absence d'argument n'est pas une
  /// demande d'élargissement).
  Future<ZResult<ZChatRequestToken>> send({
    ZChatGenerationSettings? settings,
    ZChatCorpusScope? corpusScope,
  }) async {
    // Pendant une ÉDITION, l'envoi « nouveau message » est REFUSÉ, par un
    // échec typé. La soumission d'une édition passe par
    // `runAction(ZChatEditAction(...))` — le point d'entrée unique des
    // verbes, avec son impact chiffré et sa confirmation. Laisser `send()`
    // passer ouvrirait une seconde voie : le même texte tantôt nouveau
    // message, tantôt ré-exécution, selon la surface qui l'a déclenché.
    if (_editing.value != null) {
      const ZFailure failure = ZDomainFailure(
        'chat send is unavailable while editing a message: submit the edit '
        'via runAction(ZChatEditAction) or cancelEditing() first',
      );
      _lastFailure.value = failure;
      return const Left<ZFailure, ZChatRequestToken>(failure);
    }
    final ZChatDraft draft = currentDraft;
    if (draft.text.trim().isEmpty && draft.attachmentIds.isEmpty) {
      const ZFailure failure = ZDomainFailure(
        'chat send requires a non-empty draft',
      );
      _lastFailure.value = failure;
      return const Left<ZFailure, ZChatRequestToken>(failure);
    }

    return _launch(draft: draft, settings: settings, corpusScope: corpusScope);
  }

  /// Ouvre **un** tour — le seul site qui fabrique un jeton, construit la
  /// requête et entre dans le cycle [_consume]. [send], l'édition rejouée et
  /// la régénération passent tous ici : il n'existe pas de second cycle.
  ///
  /// [request] est la requête **d'origine** à rejouer (régénération) ; sans
  /// elle, la requête est construite par le builder de l'hôte à partir de
  /// [draft]. [emitsUserMessage] ajoute le message utilisateur optimiste ;
  /// [insertAt] place la réponse dans le fil ; [rollback]/[rollbackAt]
  /// décrivent les messages retirés localement avant le tour, restitués si
  /// rien n'est produit.
  Future<ZResult<ZChatRequestToken>> _launch({
    required ZChatDraft draft,
    ZChatGenerationRequest? request,
    ZChatGenerationSettings? settings,
    ZChatCorpusScope? corpusScope,
    bool emitsUserMessage = true,
    int? insertAt,
    List<ZChatMessage> rollback = const <ZChatMessage>[],
    int rollbackAt = 0,
  }) {
    final String requestId = _newRequestId();
    final ZChatRequestToken token = ZChatRequestToken(requestId);
    _tokens[requestId] = token;

    ZChatGenerationRequest built;
    if (request != null) {
      built = request;
    } else {
      try {
        built = _buildRequest(draft);
      } catch (e) {
        return _abort(requestId, 'chat request builder threw ${e.runtimeType}');
      }
    }
    // UN SEUL site d'application des réglages, hors d'atteinte de l'hôte.
    // `withSettings(null)` rend `identical(built)` : sans argument, la
    // requête envoyée est l'objet même du builder — aucun défaut n'a bougé.
    final ZChatGenerationRequest settled = corpusScope == null
        ? built.withSettings(settings)
        : built.withSettings(settings).withCorpusScope(corpusScope);
    // Le ROUTAGE vient ici : après les réglages, AVANT l'état, le message
    // optimiste et tout appel de port. Un refus ne laisse aucune trace dans
    // le fil — et les messages retirés localement pour ce tour (édition,
    // régénération) sont restitués. Sans résolveur, `sent` EST `settled`.
    final ZChatGenerationRequest sent;
    final ZChatRouteResolver? route = _routeResolver;
    if (route == null) {
      sent = settled;
    } else {
      ZResult<ZChatGenerationRequest> routed;
      try {
        routed = route(settled);
      } catch (e) {
        routed = Left<ZFailure, ZChatGenerationRequest>(
          ZDomainFailure('chat route resolver threw ${e.runtimeType}'),
        );
      }
      final ZFailure? refused = routed.fold(
        (ZFailure f) => f,
        (ZChatGenerationRequest _) => null,
      );
      if (refused != null) {
        _restoreRollback(
          _ZRequestState(settled, rollback: rollback, rollbackAt: rollbackAt),
        );
        return _refuse(requestId, refused);
      }
      sent = routed.getOrElse(() => settled);
    }
    _states[requestId] = _ZRequestState(
      sent,
      emitsUserMessage: emitsUserMessage,
      insertAt: insertAt,
      rollback: rollback,
      rollbackAt: rollbackAt,
    );

    if (emitsUserMessage) {
      _setComposer(const ZChatDraft());
      // Le brouillon conservé a été SOUMIS : le garder le ferait
      // réapparaître à la prochaine ouverture, sous le message qu'il vient
      // de produire. Effacer ce qui n'existe pas réussit (contrat du port).
      _draftRestored.value = false;
      unawaited(_clearDraftFor(_conversationId));
      _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
        ..._messages.value,
        ZChatMessage(
          id: requestId,
          conversationId: _conversationId,
          role: ZChatRole.user,
          contentBlocks: <ZContentBlock>[ZTextBlock(text: draft.text)],
        ),
      ]);
    }
    _activeRequests.value = List<String>.unmodifiable(<String>[
      ..._activeRequests.value,
      requestId,
    ]);
    _publish(requestId, (ZChatStreamProgress p) => p.copyWith(phase: ZChatPhase.streaming));
    _say(_labels.generationStarted);

    return _consume(requestId: requestId, first: token, draft: draft);
  }

  /// Boucle **essai → reprise**. Chaque tentative porte son propre jeton, tous
  /// partagent le **même** `requestId`.
  Future<ZResult<ZChatRequestToken>> _consume({
    required String requestId,
    required ZChatRequestToken first,
    required ZChatDraft draft,
  }) async {
    final _ZRequestState state = _states[requestId]!;
    ZChatRequestToken attempt = first;
    int resumes = 0;

    while (true) {
      _tokens[requestId] = attempt;
      final ZFailure? failure = await _drain(state, attempt);
      if (_disposed) return Right<ZFailure, ZChatRequestToken>(attempt);
      if (failure == null) {
        _settle(requestId);
        return Right<ZFailure, ZChatRequestToken>(attempt);
      }

      final String? resumePoint = state.lastSequenceId;
      final bool resumable =
          failure is ZChatStreamInterruptedFailure &&
          !failure.cancelledByUser &&
          !attempt.isCancelled &&
          resumePoint != null &&
          resumes < maxResumeAttempts;

      if (!resumable) {
        _fail(requestId, failure, draft);
        return Left<ZFailure, ZChatRequestToken>(failure);
      }

      resumes++;
      // MÊME identité, position de reprise, requête d'origine INCHANGÉE :
      // le serveur reconnaît le tour et ne le rejoue pas. Le texte déjà
      // accumulé n'est PAS remis à zéro, le message utilisateur n'est PAS
      // ré-émis — sans quoi la reprise serait un second tour déguisé.
      attempt = attempt.resumeFrom(resumePoint);
      _publish(
        requestId,
        (ZChatStreamProgress p) =>
            p.copyWith(phase: ZChatPhase.resuming, resumeAttempts: resumes),
      );
    }
  }

  /// Consomme **une** tentative. Rend `null` si le tour s'est terminé sur son
  /// événement terminal, sinon l'échec typé. **Ne lève jamais** (AD-10).
  Future<ZFailure?> _drain(_ZRequestState state, ZChatRequestToken token) {
    final Completer<ZFailure?> settled = Completer<ZFailure?>();
    final String requestId = token.requestId;
    StreamSubscription<ZResult<ZChatStreamEvent>>? sub;
    bool finished = false;

    void finish(ZFailure? failure) {
      if (finished) return;
      finished = true;
      final StreamSubscription<ZResult<ZChatStreamEvent>>? s = sub;
      if (s != null) unawaited(s.cancel());
      settled.complete(failure);
    }

    ZFailure interrupted({required bool byUser}) =>
        ZChatStreamInterruptedFailure(
          byUser
              ? 'chat stream stopped by the user'
              : 'chat stream ended before its terminal event',
          requestId: requestId,
          eventsReceived: state.eventsReceived,
          cancelledByUser: byUser,
        );

    try {
      sub = _streamPort
          .stream(state.request, token: token)
          .listen(
            (ZResult<ZChatStreamEvent> event) {
              if (finished) return;
              event.fold(
                // Un `Left` est un ÉCHEC, jamais un contenu : il ne rejoint
                // jamais une bulle de message.
                (ZFailure failure) => finish(failure),
                (ZChatStreamEvent e) {
                  _apply(requestId, state, e);
                  if (e is ZChatDoneEvent) finish(null);
                },
              );
            },
            onError: (Object error, StackTrace _) =>
                finish(ZDomainFailure('chat stream threw ${error.runtimeType}')),
            onDone: () => finish(interrupted(byUser: false)),
            cancelOnError: true,
          );
    } catch (e) {
      return Future<ZFailure?>.value(
        ZDomainFailure('chat stream port threw ${e.runtimeType}'),
      );
    }
    if (finished) unawaited(sub.cancel());

    // L'arrêt vise CE jeton : un autre flux en vol n'est pas concerné.
    unawaited(token.whenCancelled.then((_) => finish(interrupted(byUser: true))));

    return settled.future;
  }

  /// Applique **un** événement. Un `ZChatTokenEvent` ne touche **que** la
  /// tranche de texte : ni `progress`, ni `messages`, ni le composer.
  void _apply(String key, _ZRequestState state, ZChatStreamEvent event) {
    state.eventsReceived++;
    final String? seq = event.sequenceId;
    if (seq != null) state.lastSequenceId = seq;

    switch (event) {
      case final ZChatTokenEvent e:
        final ValueNotifier<String> text = _textOf(key);
        text.value = '${text.value}${e.content}';
      case final ZChatThinkingEvent e:
        _publish(
          key,
          (ZChatStreamProgress p) => p.copyWith(
            thinking: <ZChatThinkingStep>[...p.thinking, e.step],
          ),
        );
      case final ZChatSourcesPreviewEvent e:
        _publish(key, (ZChatStreamProgress p) => p.copyWith(sources: e.sources));
      case final ZChatSuggestionsEvent e:
        _publish(
          key,
          (ZChatStreamProgress p) => p.copyWith(suggestions: e.suggestions),
        );
        // La tranche par REQUÊTE ci-dessus n'est lisible qu'avec un
        // `requestId` en main ; le composer n'en a pas. D'où l'agrégat par
        // CONVERSATION ci-dessous — la seule vue qu'un rang du cadre peut
        // consommer.
        //
        // `identical(_states[key], state)` est le cloisonnement : `attach`
        // vide `_states`, donc un événement en retard d'une requête lancée
        // dans une AUTRE conversation ne retrouve plus son état et ne
        // rejoint pas l'agrégat. Sans ce test, la proposition de la
        // conversation quittée s'afficherait sous le champ de la suivante.
        if (identical(_states[key], state)) {
          _suggestions.value = List<ZChatSuggestion>.unmodifiable(
            e.suggestions,
          );
        }
      case final ZChatQuotaEvent e:
        _publish(key, (ZChatStreamProgress p) => p.copyWith(quota: e.snapshot));
      case final ZChatRetrievalProgressEvent e:
        _publish(
          key,
          (ZChatStreamProgress p) => p.copyWith(
            retrievalAgent: e.agent,
            sourcesFound: e.sourcesFound,
          ),
        );
      case final ZChatContentBlockEvent e:
        state.blocks.add(e.block);
      case final ZChatDoneEvent e:
        state.messageId = e.messageId;
        state.conversationId = e.conversationId;
      case ZChatCustomStreamEvent():
        break;
    }
  }

  /// Termine un tour réussi : le texte accumulé devient un message établi.
  void _settle(String requestId) {
    final _ZRequestState? state = _states[requestId];
    final String text = _textOf(requestId).value;
    final List<ZContentBlock> blocks = <ZContentBlock>[
      if (text.isNotEmpty) ZTextBlock(text: text),
      ...?state?.blocks,
    ];
    if (state != null && blocks.isNotEmpty) {
      final String id = state.messageId ?? _replyIdFor(requestId);
      _insertReply(
        state,
        ZChatMessage(
          id: id,
          conversationId: state.conversationId ?? _conversationId,
          role: ZChatRole.assistant,
          contentBlocks: blocks,
        ),
      );
      _requestByMessageId[id] = state.request;
    }
    final String content = _announce(blocks);
    _say(_labels.generationCompleted?.call(content) ?? content);
    _publish(requestId, (ZChatStreamProgress p) => p.copyWith(phase: ZChatPhase.done));
    _release(requestId);
  }

  /// Identité locale d'une réponse que l'événement terminal n'a pas nommée
  /// (tour interrompu, ou port muet). Distincte de `requestId`, qui est
  /// l'identité du message utilisateur optimiste : deux messages du fil ne
  /// partagent jamais une identité.
  static String _replyIdFor(String requestId) => '$requestId/reply';

  /// Place une réponse dans le fil : à la position demandée par la requête
  /// (régénération — **remplacement**, jamais ajout), sinon en fin.
  void _insertReply(_ZRequestState state, ZChatMessage reply) {
    final List<ZChatMessage> thread = _messages.value;
    final int? at = state.insertAt;
    final int index = at == null ? thread.length : at.clamp(0, thread.length);
    _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
      ...thread.take(index),
      reply,
      ...thread.skip(index),
    ]);
  }

  /// Restitue les messages retirés localement avant un tour qui n'a rien
  /// produit — la régénération ou l'édition rejouée ne coûte jamais la
  /// réponse qu'elle voulait remplacer.
  void _restoreRollback(_ZRequestState? state) {
    if (state == null || state.rollback.isEmpty) return;
    final List<ZChatMessage> thread = _messages.value;
    final int index = state.rollbackAt.clamp(0, thread.length);
    _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
      ...thread.take(index),
      ...state.rollback,
      ...thread.skip(index),
    ]);
  }

  /// Écrit une annonce de région live. `null` ou vide ⇒ **silence**, rien
  /// n'est écrit. Un texte identique au précédent est d'abord effacé pour
  /// que chaque jalon notifie (un `ValueNotifier` ignore une valeur égale).
  void _say(String? text) {
    if (text == null || text.isEmpty) return;
    if (_liveAnnouncement.value == text) _liveAnnouncement.value = '';
    _liveAnnouncement.value = text;
  }

  /// Termine un tour échoué. **Ne touche jamais la saisie** quand l'arrêt est
  /// volontaire : annuler une génération ne doit jamais supprimer la question
  /// que l'utilisateur a tapée.
  void _fail(String requestId, ZFailure failure, ZChatDraft draft) {
    final _ZRequestState? state = _states[requestId];
    final String text = _textOf(requestId).value;
    final bool byUser =
        failure is ZChatStreamInterruptedFailure && failure.cancelledByUser;

    final List<ZContentBlock> blocks = <ZContentBlock>[
      if (text.isNotEmpty) ZTextBlock(text: text),
      ...?state?.blocks,
    ];
    final String partial = blocks.isEmpty ? '' : _announce(blocks);
    if (blocks.isNotEmpty) {
      // Contenu partiel déjà rendu : il est CONSERVÉ (AD-10) et MARQUÉ
      // interrompu. L'utilisateur a lu ce texte ; le faire disparaître serait
      // une perte silencieuse.
      final String id = state?.messageId ?? _replyIdFor(requestId);
      final ZChatMessage reply = ZChatMessage(
        id: id,
        conversationId: state?.conversationId ?? _conversationId,
        role: ZChatRole.assistant,
        contentBlocks: blocks,
      );
      if (state == null) {
        _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
          ..._messages.value,
          reply,
        ]);
      } else {
        _insertReply(state, reply);
        _requestByMessageId[id] = state.request;
      }
      _interrupted.add(id);
    } else {
      // Rien n'a été produit : ce que le tour avait retiré localement
      // (régénération, édition rejouée) est RESTITUÉ.
      _restoreRollback(state);
      if (!byUser && (state?.emitsUserMessage ?? true)) {
        // Le tour n'a pas eu lieu. Le message optimiste est retiré et la
        // saisie RESTITUÉE — une panne ne coûte pas la frappe.
        _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
          for (final ZChatMessage m in _messages.value)
            if (m.id != requestId) m,
        ]);
        if (composer.text.isEmpty) _setComposer(draft);
      }
    }
    _say(
      byUser
          ? (_labels.generationCancelled?.call(partial) ?? partial)
          : (_labels.generationFailed ?? partial),
    );

    _lastFailure.value = failure;
    _publish(
      requestId,
      (ZChatStreamProgress p) =>
          p.copyWith(phase: byUser ? ZChatPhase.cancelled : ZChatPhase.failed),
    );
    _release(requestId);
  }

  /// Sans cette annonce, une réponse faite uniquement de blocs structurés
  /// (un tableau de taxation, un bloc de sources) laisserait un lecteur
  /// d'écran sans rien à annoncer : le texte streamé n'est pas la seule
  /// forme que peut prendre une réponse. `zChatAccessibleTextOf` est
  /// **exhaustif par construction** (`switch` sur l'union scellée des blocs).
  ///
  /// Aucun résolveur d'hôte ici : le contrôleur n'a ni `BuildContext` ni
  /// vocabulaire de rendu (invariant AD-2). La localisation d'un bloc ouvert
  /// appartient à `ZChatAccessibleTextScope`, côté vue — et la vue
  /// **remplace** ce texte par le sien quand elle le résout. Cette
  /// annonce-ci est le plancher : elle ne doit jamais être **vide** quand du
  /// contenu a été produit.
  static String _announce(List<ZContentBlock> blocks) =>
      zChatAccessibleTextOf(blocks);

  Future<ZResult<ZChatRequestToken>> _abort(String requestId, String message) =>
      _refuse(requestId, ZDomainFailure(message));

  /// Refuse un tour **avant** son ouverture : l'échec typé est publié, le
  /// jeton retiré, et rien d'autre n'a bougé — ni message optimiste, ni
  /// saisie, ni annonce.
  Future<ZResult<ZChatRequestToken>> _refuse(String requestId, ZFailure failure) {
    _lastFailure.value = failure;
    _tokens.remove(requestId);
    _states.remove(requestId);
    return Future<ZResult<ZChatRequestToken>>.value(
      Left<ZFailure, ZChatRequestToken>(failure),
    );
  }

  /// Retire une requête des tables **sans** disposer immédiatement ses
  /// tranches : un widget peut encore les écouter le temps d'une transition.
  ///
  /// Cette rétention doit rester **bornée** : sans plafond, une conversation
  /// longue accumulerait un `ValueNotifier` par requête terminée, chacun
  /// gardant le **texte intégral** d'une réponse déjà recopiée dans
  /// [messages] — la même donnée payée deux fois, sans limite. La rétention
  /// est donc une **fenêtre glissante** de [_kRetainedSlices] requêtes
  /// terminées : la transition reste couverte, la mémoire est bornée par
  /// construction. Au-delà de la fenêtre, la tranche d'une requête ancienne
  /// est **disposée** (un `addListener` y lève) et [streamText] rend une
  /// **nouvelle** instance.
  void _release(String requestId) {
    _tokens.remove(requestId);
    _states.remove(requestId);
    _activeRequests.value = List<String>.unmodifiable(<String>[
      for (final String id in _activeRequests.value)
        if (id != requestId) id,
    ]);
    _retained.remove(requestId);
    _retained.add(requestId);
    while (_retained.length > _kRetainedSlices) {
      _disposeSlices(_retained.removeAt(0));
    }
  }

  /// Libère les tranches d'une requête **sortie de la fenêtre de rétention**.
  void _disposeSlices(String requestId) {
    _streamTexts.remove(requestId)?.dispose();
    _progress.remove(requestId)?.dispose();
  }

  // ── Verbes — UN SEUL point d'entrée ───────────────────────────────────────

  /// Exécute **n'importe quel** verbe de conversation.
  ///
  /// **L'unique point d'entrée des actions**, et le seul site du paquet qui
  /// invoque `ZChatActionDispatcher`. Éditer, régénérer, retirer, arrêter,
  /// copier et les verbes d'hôte passent **tous** ici — donc par le même
  /// protocole : impact **chiffré avant** l'effet, confirmation
  /// **systématique** dès que le plan l'exige, jeton infalsifiable, échec
  /// typé.
  ///
  /// Un raccourci de confort (`delete(id)`, `stop()`, …) serait un **second
  /// site d'appel**, donc la possibilité d'une divergence de comportement
  /// entre deux surfaces d'UI. Un test de garde asserte l'**égalité
  /// d'ensemble** de la surface publique — « contient `runAction` » ne
  /// mordrait pas.
  Future<ZResult<ZChatActionOutcome>> runAction(ZChatAction action) async {
    final ZResult<ZChatActionPlan> planned = await _dispatcher.prepare(action);
    final ZChatActionPlan? plan = planned.fold(
      (ZFailure _) => null,
      (ZChatActionPlan p) => p,
    );
    if (plan == null) {
      final ZFailure failure = planned.fold(
        (ZFailure f) => f,
        (ZChatActionPlan _) =>
            const ZDomainFailure('chat action planning failed'),
      );
      _lastFailure.value = failure;
      return Left<ZFailure, ZChatActionOutcome>(failure);
    }

    final ZChatConfirmedAction? ticket;
    if (plan.requiresConfirmation) {
      // La question EST posée : il n'existe qu'un seul point d'entrée pour
      // les verbes, donc pas de seconde surface où la confirmation pourrait
      // manquer.
      if (!await _ask(plan)) {
        final ZFailure failure = ZChatActionNotConfirmedFailure(
          verb: action.verb,
        );
        _lastFailure.value = failure;
        return Left<ZFailure, ZChatActionOutcome>(failure);
      }
      ticket = plan.confirmedByUser();
    } else {
      ticket = plan.proceedWithoutConfirmation();
    }
    if (ticket == null) {
      final ZFailure failure = ZChatActionNotConfirmedFailure(
        verb: action.verb,
      );
      _lastFailure.value = failure;
      return Left<ZFailure, ZChatActionOutcome>(failure);
    }

    // Arrêt LOCAL du transport : le jeton DÉSIGNÉ par son identité, et lui
    // seul. Aucune autre requête en vol n'est touchée.
    if (action is ZChatCancelAction) _tokens[action.requestId]?.cancel();

    // Avec le port de cycle de vie, l'édition rejouée et la régénération
    // sont NATIVES : élagage, troncature locale, nouveau tour par le cycle
    // unique. La planification et la confirmation ci-dessus ont déjà eu
    // lieu — le protocole est le même que pour tout autre verbe.
    final ZChatConversationLifecyclePort? lifecycle = _lifecycle;
    if (lifecycle != null && action is ZChatEditAction) {
      return _editNatively(lifecycle, action);
    }
    if (lifecycle != null && action is ZChatRegenerateAction) {
      return _regenerateNatively(lifecycle, action);
    }

    final ZResult<ZChatActionOutcome> outcome = await _dispatcher.execute(
      ticket,
    );
    outcome.fold(
      (ZFailure failure) => _lastFailure.value = failure,
      (ZChatActionOutcome o) => _applyOutcome(action, o),
    );
    return outcome;
  }

  /// Pose la question de confirmation. Un seam d'hôte qui **lève** vaut un
  /// refus (AD-10) : jamais une destruction par défaut.
  Future<bool> _ask(ZChatActionPlan plan) async {
    try {
      return await _confirm(plan);
    } catch (_) {
      return false;
    }
  }

  /// Applique l'issue d'une action. **La saisie n'y est écrite que pour être
  /// restituée** : la sortie d'édition ci-dessous rend le brouillon
  /// sauvegardé — elle ne détruit jamais un texte tapé. Le chemin
  /// d'annulation, lui, ne touche jamais la saisie.
  void _applyOutcome(ZChatAction action, ZChatActionOutcome outcome) {
    // Une ÉDITION exécutée avec succès clôt sa session : l'exécuteur de
    // l'hôte a consommé le texte édité et régénère côté hôte, le socle ne
    // double-stream pas. La saisie d'AVANT l'édition est restituée, comme à
    // `cancelEditing`.
    final ZChatEditingSession? session = _editing.value;
    if (action is ZChatEditAction &&
        session != null &&
        action.messageId == session.messageId) {
      final ZChatDraft restored = _preEditingDraft ?? const ZChatDraft();
      _preEditingDraft = null;
      _editing.value = null;
      _setComposer(restored);
    }
    if (!outcome.softDeleted || outcome.affectedMessageIds.isEmpty) return;
    final Set<String> removed = outcome.affectedMessageIds.toSet();
    _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
      for (final ZChatMessage m in _messages.value)
        if (m.id == null || !removed.contains(m.id)) m,
    ]);
  }

  // ── Édition rejouée et régénération NATIVES ───────────────────────────────

  /// Élague le fil côté hôte — **avant** toute destruction locale. Un port
  /// qui lève rend un `Left` (AD-10).
  Future<ZResult<int>> _trim(
    ZChatConversationLifecyclePort lifecycle,
    String messageId,
  ) async {
    try {
      return await lifecycle.trimAfter(
        conversationId: _conversationId,
        messageId: messageId,
      );
    } catch (e) {
      return Left<ZFailure, int>(
        ZDomainFailure(
          'chat lifecycle port threw ${e.runtimeType} during trimAfter',
        ),
      );
    }
  }

  /// Édition rejouée, en trois temps et dans cet ordre strict :
  /// `trimAfter` (hôte) → troncature locale → nouveau tour. Un échec du
  /// premier temps ne détruit **rien** localement et laisse la session
  /// d'édition ouverte.
  Future<ZResult<ZChatActionOutcome>> _editNatively(
    ZChatConversationLifecyclePort lifecycle,
    ZChatEditAction action,
  ) async {
    final List<ZChatMessage> thread = _messages.value;
    final int at = thread.indexWhere(
      (ZChatMessage m) => m.id == action.messageId,
    );
    if (at < 0) {
      final ZFailure failure = ZNotFoundFailure(
        'chat message ${action.messageId} is not in the thread',
      );
      _lastFailure.value = failure;
      return Left<ZFailure, ZChatActionOutcome>(failure);
    }
    final ZResult<int> trimmed = await _trim(lifecycle, action.messageId);
    final ZFailure? refused = trimmed.fold((ZFailure f) => f, (int _) => null);
    if (refused != null) {
      _lastFailure.value = refused;
      return Left<ZFailure, ZChatActionOutcome>(refused);
    }

    // Troncature locale : le message édité ET ses postérieurs quittent le fil
    // (le nouveau tour ré-émet la question, avec son nouveau texte).
    final List<ZChatMessage> removed = thread.sublist(at);
    _messages.value = List<ZChatMessage>.unmodifiable(thread.take(at));
    // La session d'édition se clôt ici, par le même chemin que l'issue
    // déléguée : la saisie d'AVANT l'édition est restituée.
    final ZChatActionOutcome outcome = ZChatActionOutcome(
      verb: action.verb,
      affectedMessageIds: <String>[
        for (final ZChatMessage m in removed)
          if (m.id != null) m.id!,
      ],
      preservedDraft: action.draft,
    );
    _applyOutcome(action, outcome);

    final ZResult<ZChatRequestToken> sent = await _launch(
      draft: ZChatDraft(
        text: action.newText,
        attachmentIds: action.draft.attachmentIds,
      ),
      rollback: removed,
      rollbackAt: at,
    );
    return sent.map((ZChatRequestToken _) => outcome);
  }

  /// Régénération : la réponse [ZChatRegenerateAction.messageId] est
  /// **remplacée** (jamais ajoutée) par un nouveau tour rejouant la requête
  /// d'origine — celle de la session si elle est connue, sinon reconstruite
  /// par le builder de l'hôte à partir de la question appariée. Les réglages
  /// de l'action s'appliquent par-dessus, comme pour [send]. Si le tour ne
  /// produit rien, l'ancienne réponse est restituée.
  Future<ZResult<ZChatActionOutcome>> _regenerateNatively(
    ZChatConversationLifecyclePort lifecycle,
    ZChatRegenerateAction action,
  ) async {
    final ZChatMessage? reply = messageById(action.messageId);
    final ZChatMessage? question = reply == null
        ? null
        : replyToOf(action.messageId);
    final String? questionId = question?.id;
    if (reply == null || question == null || questionId == null) {
      final ZFailure failure = ZNotFoundFailure(
        'chat message ${action.messageId} has no paired question in the thread',
      );
      _lastFailure.value = failure;
      return Left<ZFailure, ZChatActionOutcome>(failure);
    }
    final ZResult<int> trimmed = await _trim(lifecycle, questionId);
    final ZFailure? refused = trimmed.fold((ZFailure f) => f, (int _) => null);
    if (refused != null) {
      _lastFailure.value = refused;
      return Left<ZFailure, ZChatActionOutcome>(refused);
    }

    final List<ZChatMessage> thread = _messages.value;
    final int at = thread.indexWhere((ZChatMessage m) => m.id == questionId) + 1;
    final List<ZChatMessage> removed = thread.sublist(at);
    _messages.value = List<ZChatMessage>.unmodifiable(thread.take(at));

    final ZChatDraft draft = ZChatDraft(
      text: contentOf(questionId) ?? '',
      attachmentIds: <String>[
        for (final ZChatAttachment a in question.attachments ?? const <ZChatAttachment>[])
          if (a.id.isNotEmpty) a.id,
      ],
    );
    final ZResult<ZChatRequestToken> sent = await _launch(
      draft: draft,
      request: _requestByMessageId[action.messageId],
      settings: action.settings,
      corpusScope: action.corpusScope,
      emitsUserMessage: false,
      insertAt: at,
      rollback: removed,
      rollbackAt: at,
    );
    return sent.map(
      (ZChatRequestToken _) => ZChatActionOutcome(
        verb: action.verb,
        affectedMessageIds: <String>[action.messageId],
      ),
    );
  }

  // ── Tranches par requête (instances STABLES) ──────────────────────────────

  ValueNotifier<String> _textOf(String requestId) =>
      _streamTexts[requestId] ??= ValueNotifier<String>('');

  ValueNotifier<ZChatStreamProgress> _progressOf(String requestId) =>
      _progress[requestId] ??=
          ValueNotifier<ZChatStreamProgress>(const ZChatStreamProgress());

  void _publish(
    String requestId,
    ZChatStreamProgress Function(ZChatStreamProgress) update,
  ) {
    final ValueNotifier<ZChatStreamProgress> slice = _progressOf(requestId);
    slice.value = update(slice.value);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final ZChatRequestToken token in _tokens.values) {
      token.cancel();
    }
    _tokens.clear();
    _states.clear();
    _interrupted.clear();
    _requestByMessageId.clear();
    composer.removeListener(_onComposerChanged);
    composer.dispose();
    _attachmentIds.dispose();
    _canSend.dispose();
    _messages.dispose();
    _activeRequests.dispose();
    _lastFailure.dispose();
    _liveAnnouncement.dispose();
    _editing.dispose();
    _draftSeeds.dispose();
    _suggestions.dispose();
    _draftRestored.dispose();
    for (final ValueNotifier<String> n in _streamTexts.values) {
      n.dispose();
    }
    _streamTexts.clear();
    for (final ValueNotifier<ZChatStreamProgress> n in _progress.values) {
      n.dispose();
    }
    _progress.clear();
    _retained.clear();
    super.dispose();
  }
}
