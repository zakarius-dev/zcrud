/// Contrôleur de conversation IA — `ZChatController` (CHAT-2).
///
/// ## 🔴 Le défaut de STRUCTURE que ce fichier rend inexprimable
///
/// Une exploration de 36 agents sur l'assistant d'IFFD a établi une **cause
/// racine unique** derrière **neuf** défauts distincts :
///
/// > **un verbe = un seul site d'appel dans le contrôleur.**
///
/// IFFD porte **deux** implémentations parallèles de la même barre d'actions
/// dans `chatbot_conversation_screen.dart` (5153 lignes) : barre de bulle
/// (≈ l.1650-2170) et en-tête compact (≈ l.3600-4120). Elles divergent —
/// supprimer est confirmé l.2134 et **silencieux** l.3886 ; régénérer a
/// **trois** comportements (l.1979, l.2000, l.2026) ; annuler **supprime la
/// question tapée** (l.3618-3672) ; le `CancelToken` est un champ d'**instance**
/// partagé (`iffd_ai_repository_impl.dart:29`, `:375-377`), si bien qu'arrêter
/// une génération coupe *la dernière lancée*, pas celle qu'on désigne.
///
/// Ici, le contrôleur expose **UN SEUL** point d'entrée pour **TOUS** les
/// verbes — [ZChatController.runAction] — et c'est le **seul** site du package
/// qui invoque `ZChatActionDispatcher`. Une « surface B » ne peut pas exister :
/// il n'y a pas de `deleteMessage()`, pas de `regenerateAnswer()`, pas de
/// callback par verbe. Le verbe est une **donnée** (`ZChatAction`, famille
/// scellée de CHAT-0b), pas une méthode.
///
/// Gardes : `test/z_chat_single_call_site_test.dart` (surface publique en
/// ÉGALITÉ d'ensemble + unicité des appels au répartiteur) et **G-U1** du
/// kernel (`z_chat_action_contract_guard_test.dart`), qui balaie **tous** les
/// `packages/*/lib` et rougirait en nommant ce fichier s'il court-circuitait le
/// répartiteur.
///
/// ## 🔴 SM-1 — objectif produit n°1 du dépôt
///
/// La réactivité est **Flutter-native** (AD-2/AD-15) : aucun gestionnaire
/// d'état n'est importé, ni ici ni jamais (garde `z_chat_purity_test.dart`,
/// grep NÉGATIF outillé). L'état est découpé en **tranches
/// `ValueListenable` indépendantes**, dimensionnées sur leur **fréquence** :
///
/// | Tranche | Signale quand | Coût si on la fusionnait |
/// |---|---|---|
/// | [composer] (`TextEditingController`) | à chaque frappe | la liste des messages se reconstruirait à chaque touche — **le bug historique** |
/// | [attachmentIds] | ajout/retrait de pièce jointe | idem |
/// | [canSend] | passage vide ↔ non vide **seulement** | un `bool` égal ne notifie pas (`ValueNotifier`) |
/// | [messages] | message ajouté/retiré | reconstruction de toute la liste à chaque jeton |
/// | [activeRequests] | début/fin d'une requête | idem |
/// | [streamText] (**par requestId**) | **à chaque jeton** | le composer se reconstruirait sous les doigts de l'utilisateur |
/// | [progress] (**par requestId**) | réflexion, sources, quota | l'indicateur clignoterait à chaque jeton |
/// | [lastFailure] | échec typé | — |
/// | [liveAnnouncement] | **fin** d'un tour | une région live qui parle à chaque jeton est inutilisable |
///
/// Les tranches par requête sont **stables par identité** (même instance pour
/// un même `requestId`), sur le patron de `ZFormController.fieldListenable` :
/// un `ValueListenableBuilder` ne se ré-abonne jamais.
///
/// 🔴 `notifyListeners()` (le canal **global** de `ChangeNotifier`) est
/// **réservé aux changements STRUCTURELS** — le seul est [attach], qui change
/// de conversation. Ni une frappe, ni un jeton, ni un échec ne le déclenche :
/// c'est mesuré par `test/z_chat_sm1_test.dart` (compteur de notifications
/// globales à **zéro** sur 100 frappes puis 100 jetons).
///
/// ## 🔴 Un jeton par requête, et la reprise sous la MÊME identité
///
/// [send] fabrique **un** `ZChatRequestToken` par appel et l'indexe **par
/// `requestId`**. Il n'existe **aucun** champ « jeton courant » : deux flux
/// concurrents s'annulent indépendamment (garde
/// `test/z_chat_token_lifecycle_test.dart`, volets source *et* comportement).
///
/// Sur `ZChatStreamInterruptedFailure` **subie** (`cancelledByUser == false`),
/// le contrôleur reprend via `token.resumeFrom(lastSequenceId)` : **même**
/// `requestId`, **même** `ZChatGenerationRequest`, texte accumulé **conservé**,
/// message utilisateur **non ré-émis**. Le tour n'est pas rejoué — c'est la
/// seule obligation ACTIVE du client dans le protocole reprenable de lex.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
// 🔴 IMPORT CONFINÉ PAR `show`, et c'est structurel (garde
// `z_chat_purity_test.dart`). `TextEditingController` est la SEULE chose dont
// ce package ait besoin hors de `foundation` : c'est un objet d'ÉTAT, mais il
// vit dans `widgets` (`editable_text.dart`). L'importer sans `show` ouvrirait
// tout `flutter/widgets` — donc `StatefulWidget`, `setState`, `Padding`,
// `Alignment`… — dans un package qui ne doit RENDRE aucun pixel. Le `show`
// rend l'ouverture impossible sans modifier cette ligne, que la garde lit.
// ⛔ `flutter/material.dart` et `flutter/cupertino.dart` restent BANNIS (FR-26 :
// c'est par eux qu'entrent `Colors.*` et les `TextStyle` en dur).
import 'package:flutter/widgets.dart' show TextEditingController;
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_stream_progress.dart';

/// Demande de **confirmation** à l'utilisateur — seam d'HÔTE.
///
/// 🔴 Le dialogue, ses libellés, ses icônes et ses couleurs appartiennent à
/// l'app (AD-2/AD-13/FR-26) : ce package ne connaît ni `BuildContext`, ni
/// widget, ni chaîne traduisible. Il impose seulement que la question **soit
/// posée** avant tout effet destructeur.
typedef ZChatConfirm = Future<bool> Function(ZChatActionPlan plan);

/// Fabrique d'identité de requête — fournie par l'hôte (un UUID v4 chez lex).
///
/// Le domaine ne **génère** aucune identité (aucune dépendance, AD-1) : il la
/// transporte **verbatim** sans jamais l'interpréter.
typedef ZChatRequestIdFactory = String Function();

/// Construit la requête de génération à partir de la saisie soumise.
///
/// 🔴 Les prompts, le modèle, le style et les instructions système restent
/// **côté app** (AD-11/AD-12) : le contrôleur ne compose aucun prompt.
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

/// État PRIVÉ d'une requête en vol — **sans canal réactif**.
///
/// 🔴 `lastSequenceId` et `eventsReceived` changent à **chaque jeton**. Les
/// publier en tranche ferait de `progress` un canal à haute fréquence : tout
/// écoutant de la progression se reconstruirait des centaines de fois par tour.
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
    // 🔴 `prefer_initializing_formals` est INAPPLICABLE ici : un paramètre
    // NOMMÉ ne peut pas s'appeler `_streamPort` (les formels privés sont
    // interdits en Dart). Rendre ces champs publics pour satisfaire le lint
    // élargirait la surface publique du contrôleur — l'inverse de l'invariant
    // « un seul point d'entrée » que la garde d'égalité d'ensemble asserte.
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

  /// 🔴 Le **répartiteur UNIQUE** de CHAT-0b. Aucun membre de
  /// `ZChatActionExecutor` n'est joignable autrement (garde **G-U1**).
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
  /// 🔴 C'est l'interdit AD-2 le plus coûteux : un `TextEditingController`
  /// reconstruit dans un `build()` fait perdre le curseur et la sélection à
  /// chaque frappe. Ici il appartient au contrôleur et vit aussi longtemps que
  /// lui ([dispose] s'en charge).
  final TextEditingController composer = TextEditingController();

  final ValueNotifier<List<String>> _attachmentIds =
      ValueNotifier<List<String>>(const <String>[]);
  final ValueNotifier<bool> _canSend = ValueNotifier<bool>(false);
  final ValueNotifier<List<ZChatMessage>> _messages;
  final ValueNotifier<List<String>> _activeRequests =
      ValueNotifier<List<String>>(const <String>[]);
  final ValueNotifier<ZFailure?> _lastFailure = ValueNotifier<ZFailure?>(null);
  final ValueNotifier<String> _liveAnnouncement = ValueNotifier<String>('');

  /// 🔴 Jetons indexés **PAR `requestId`** — jamais un champ « jeton courant ».
  ///
  /// C'est la forme exacte du défaut IFFD (`CancelToken cancel = CancelToken();`
  /// en champ d'instance d'un dépôt singleton) : arrêter une génération y coupe
  /// la **dernière lancée**. Ici, annuler s'adresse à une identité.
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
  /// ⚠️ Cette tranche est une **liste**, pas un widget : rien ici n'empêche la
  /// virtualisation. Le rendu doit rester un `ListView.builder` — les 5153
  /// lignes du chat d'IFFD n'en contiennent **aucun** (0 occurrence).
  ValueListenable<List<ZChatMessage>> get messages => _messages;

  /// Identités des requêtes **en vol**, dans l'ordre de lancement.
  ValueListenable<List<String>> get activeRequests => _activeRequests;

  /// Dernier échec **typé** rencontré, ou `null`.
  ///
  /// 🔴 Un échec n'est **jamais** un message : le défaut IFFD n°4 est le texte
  /// brut d'une exception poussé dans le corps d'une bulle et affiché comme la
  /// réponse de l'assistant. Ici il vit dans sa propre tranche, hors de
  /// [messages], et porte un type — jamais une chaîne à parser.
  ValueListenable<ZFailure?> get lastFailure => _lastFailure;

  /// Texte à annoncer dans une **région live** (a11y, AD-13).
  ///
  /// ⚠️ IFFD n'a **aucun** `Semantics` sur son chat (0 occurrence, vérifié) :
  /// une réponse qui arrive en streaming y est muette pour un lecteur d'écran.
  /// Cette tranche est la contribution du contrôleur à la dette : elle ne
  /// change qu'aux **jalons** (fin de tour, interruption), jamais à chaque
  /// jeton — une région live qui parle 300 fois par tour est inutilisable. Le
  /// `Semantics(liveRegion: true)` qui la consomme appartient au rendu (C3).
  ///
  /// Son contenu est **celui de l'assistant**, jamais une phrase écrite par le
  /// socle : aucune chaîne traduisible n'est codée en dur ici (FR-26).
  ValueListenable<String> get liveAnnouncement => _liveAnnouncement;

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

  /// 🔴 **L'UNIQUE écrivain de la saisie de l'utilisateur.**
  ///
  /// Le défaut IFFD `chatbot_conversation_screen.dart:3618-3672` — la poubelle
  /// de « Réflexion en cours » appelle l'arrêt **puis** supprime la question
  /// tapée — n'est pas une erreur d'inattention : c'est ce qui arrive quand
  /// cinq chemins peuvent écrire dans le champ de saisie. Ici il y en a **un**,
  /// et la garde `z_chat_composer_write_site_test.dart` en fait une propriété
  /// **structurelle** : le chemin d'annulation ne peut pas l'appeler sans faire
  /// rougir la garde.
  void _setComposer(ZChatDraft draft) {
    if (composer.text != draft.text) composer.text = draft.text;
    _attachmentIds.value = List<String>.unmodifiable(draft.attachmentIds);
    // 🔴 DÉFAUT TROUVÉ PAR CHAT-5, et corrigé ici. `_canSend` n'était recalculé
    // que par le listener du `TextEditingController` : joindre un fichier SANS
    // rien taper ne changeait pas `composer.text`, donc ne notifiait rien, donc
    // laissait `canSend` à `false`. [send] acceptait pourtant ce cas
    // (`draft.text.trim().isEmpty && draft.attachmentIds.isEmpty` est le SEUL
    // refus) : la garde de l'UI et celle du domaine se contredisaient, et le
    // bouton d'envoi restait éteint sur une pièce jointe seule.
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
  Future<ZResult<ZChatRequestToken>> send() async {
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

    final ZChatGenerationRequest request;
    try {
      request = _buildRequest(draft);
    } catch (e) {
      return _abort(requestId, 'chat request builder threw ${e.runtimeType}');
    }
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
      // 🔴 MÊME identité, position de reprise, requête d'origine INCHANGÉE :
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
                // 🔴 Un `Left` est un ÉCHEC, jamais un contenu : il ne rejoint
                // aucune bulle (défaut IFFD n°4).
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

    // 🔴 L'arrêt vise CE jeton : un autre flux en vol n'est pas concerné.
    unawaited(token.whenCancelled.then((_) => finish(interrupted(byUser: true))));

    return settled.future;
  }

  /// Applique **un** événement. 🔴 Un `ZChatTokenEvent` ne touche **que** la
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

  /// Termine un tour échoué. 🔴 **Ne touche JAMAIS la saisie** quand l'arrêt est
  /// volontaire : c'est la garantie que le défaut IFFD (annuler = supprimer la
  /// question tapée) ne peut pas revenir.
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

  /// 🔴 **Correction de fin d'epic (MAJEUR).** L'annonce valait auparavant le
  /// **texte streamé seul** : une réponse faite uniquement de blocs — un
  /// tableau de taxation, un bloc de sources, ce que produit exactement la
  /// chaîne de lex — donnait `ANNONCES=[]`. C'est la dette d'IFFD (0 `Semantics`
  /// sur 5153 lignes de son chat) reproduite sur notre rendu neutre, alors même
  /// que `zChatAccessibleTextOf` existait déjà et qu'il est **exhaustif par
  /// construction** (`switch` sur l'union scellée).
  ///
  /// Aucun résolveur d'hôte ici : le contrôleur n'a ni `BuildContext` ni
  /// vocabulaire de rendu (AD-2). La localisation d'un bloc ouvert appartient à
  /// `ZChatAccessibleTextScope`, côté vue — et la vue **remplace** ce texte par
  /// le sien quand elle le résout. Cette annonce-ci est le plancher : elle ne
  /// doit jamais être **vide** quand du contenu a été produit.
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

  /// Retire une requête des tables **sans** disposer immédiatement ses tranches :
  /// un widget peut encore les écouter le temps d'une transition.
  ///
  /// 🔴 **Correction de fin d'epic (MEDIUM — fuite bornée).** L'intention
  /// ci-dessus est légitime ; son **absence de borne** ne l'était pas. Les
  /// tranches n'étaient libérées que par [attach] ou [dispose] : sur une
  /// conversation longue de 200 tours, le contrôleur retenait **400
  /// `ValueNotifier`**, dont chacun garde le **texte intégral** d'une réponse
  /// déjà recopiée dans [messages] — la même donnée payée deux fois, sans
  /// plafond. La rétention est désormais une **fenêtre glissante** de
  /// [_kRetainedSlices] requêtes terminées : la transition reste couverte, la
  /// mémoire est bornée par construction. Garde : au-delà de la fenêtre, la
  /// tranche d'une requête ancienne est **disposée** (un `addListener` y lève)
  /// et [streamText] rend une **nouvelle** instance.
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
  /// 🔴 **C'est l'UNIQUE point d'entrée des actions**, et le seul site du
  /// package qui invoque `ZChatActionDispatcher`. Éditer, régénérer, retirer,
  /// arrêter, copier et les verbes d'hôte passent **tous** ici — donc par le
  /// même protocole : impact **chiffré avant** l'effet, confirmation
  /// **systématique** dès que le plan l'exige, jeton infalsifiable, échec typé.
  ///
  /// Un raccourci de confort (`delete(id)`, `stop()`, …) serait un **second
  /// site d'appel**, donc la possibilité d'une divergence entre deux surfaces
  /// d'UI : c'est exactement ce qu'IFFD a produit. La garde
  /// `z_chat_single_call_site_test.dart` asserte l'**égalité d'ensemble** de la
  /// surface publique — « contient runAction » ne mordrait pas.
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
      // 🔴 La question EST posée. IFFD confirmait sur une surface (l.2134) et
      // pas sur l'autre (l.3886) ; ici il n'existe pas d'autre surface.
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
      _applyOutcome,
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

  /// Applique l'issue d'une action. 🔴 **Aucune écriture de la saisie ici** :
  /// `preservedDraft` est une *restitution* — la saisie n'a jamais été touchée,
  /// il n'y a donc rien à restaurer.
  void _applyOutcome(ZChatActionOutcome outcome) {
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
