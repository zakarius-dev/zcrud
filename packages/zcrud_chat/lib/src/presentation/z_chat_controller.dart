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
/// | [liveAnnouncement] | fin d'un tour | une région live qui parle à chaque jeton est inutilisable |
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
  _ZRequestState(this.request);

  /// Requête d'origine — **réutilisée telle quelle** par une reprise (aucun
  /// rejeu, aucune reconstruction de prompt).
  final ZChatGenerationRequest request;

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
  ZChatController({
    required ZChatStreamPort streamPort,
    required ZChatActionExecutor actionExecutor,
    required ZChatConfirm confirm,
    required ZChatRequestIdFactory newRequestId,
    required ZChatRequestBuilder buildRequest,
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

  /// Nombre maximal de **reprises** d'un flux interrompu subi.
  final int maxResumeAttempts;

  String _conversationId;

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
    _setComposer(const ZChatDraft());
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

    final String requestId = _newRequestId();
    final ZChatRequestToken token = ZChatRequestToken(requestId);
    _tokens[requestId] = token;

    final ZChatGenerationRequest built;
    try {
      built = _buildRequest(draft);
    } catch (e) {
      return _abort(requestId, 'chat request builder threw ${e.runtimeType}');
    }
    // UN SEUL site d'application des réglages, hors d'atteinte de l'hôte.
    // `withSettings(null)` rend `identical(built)` : sans argument, la
    // requête envoyée est l'objet même du builder — aucun défaut n'a bougé.
    final ZChatGenerationRequest request = corpusScope == null
        ? built.withSettings(settings)
        : built.withSettings(settings).withCorpusScope(corpusScope);
    _states[requestId] = _ZRequestState(request);

    _setComposer(const ZChatDraft());
    _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
      ..._messages.value,
      ZChatMessage(
        id: requestId,
        conversationId: _conversationId,
        role: ZChatRole.user,
        contentBlocks: <ZContentBlock>[ZTextBlock(text: draft.text)],
      ),
    ]);
    _activeRequests.value = List<String>.unmodifiable(<String>[
      ..._activeRequests.value,
      requestId,
    ]);
    _publish(requestId, (ZChatStreamProgress p) => p.copyWith(phase: ZChatPhase.streaming));

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
      _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
        ..._messages.value,
        ZChatMessage(
          id: state.messageId ?? requestId,
          conversationId: state.conversationId ?? _conversationId,
          role: ZChatRole.assistant,
          contentBlocks: blocks,
        ),
      ]);
    }
    _liveAnnouncement.value = _announce(blocks);
    _publish(requestId, (ZChatStreamProgress p) => p.copyWith(phase: ZChatPhase.done));
    _release(requestId);
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
    if (blocks.isNotEmpty) {
      // Contenu partiel déjà rendu : il est CONSERVÉ (AD-10). L'utilisateur a
      // lu ce texte ; le faire disparaître serait une perte silencieuse.
      _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
        ..._messages.value,
        ZChatMessage(
          id: state?.messageId ?? requestId,
          conversationId: state?.conversationId ?? _conversationId,
          role: ZChatRole.assistant,
          contentBlocks: blocks,
        ),
      ]);
      _liveAnnouncement.value = _announce(blocks);
    } else if (!byUser) {
      // Rien n'a été produit : le tour n'a pas eu lieu. Le message optimiste
      // est retiré et la saisie RESTITUÉE — une panne ne coûte pas la frappe.
      _messages.value = List<ZChatMessage>.unmodifiable(<ZChatMessage>[
        for (final ZChatMessage m in _messages.value)
          if (m.id != requestId) m,
      ]);
      if (composer.text.isEmpty) _setComposer(draft);
    }

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

  Future<ZResult<ZChatRequestToken>> _abort(String requestId, String message) {
    final ZFailure failure = ZDomainFailure(message);
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
