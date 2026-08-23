/// Contrôleur de **fil de travail** (notebook) — `ZChatNotebookController`.
///
/// ## Ce qu'il tient, et ce qu'il ne tient pas
///
/// Un fil de travail est une conversation **plus** des artefacts par message
/// (une carte mentale, un paquet de flashcards, une reformulation). Ce
/// contrôleur **compose** un [ZChatController] — il le construit, le détient
/// et le libère — et y ajoute exactement ce que la conversation n'a pas :
///
/// * l'**occupation** des artefacts (quelle génération est en vol), connue de
///   lui seul ;
/// * une **tranche d'état par `(message, artefact)`** — `ValueListenable` de
///   [ZChatArtifactStatus] —, recalculée quand l'occupation change ou quand le
///   contenu a changé, **jamais** le fil entier ;
/// * les **verbes** offerts, dérivés du registre déclaré par l'hôte, de l'état
///   et du mode lecture seule ;
/// * la **persistance du fil** par le port de transcript : abonnement unique,
///   amorce sur le premier instantané, chaque tour écrit au fil de l'eau.
///
/// Il ne rend aucun pixel, n'importe aucun gestionnaire d'état (invariants
/// AD-2/AD-15) et ne réimplémente **aucun** cycle de flux : envoyer, arrêter,
/// éditer, régénérer restent les verbes du [ZChatController] composé.
///
/// ## Pourquoi il DÉTIENT le contrôleur de conversation
///
/// Le contrôleur de conversation est construit ici, à partir des mêmes ports,
/// parce que trois propriétés ne tiennent qu'à cette condition : les défauts
/// du kernel (exécuteur qui refuse nommément, confirmation sans dialogue,
/// identités séquentielles, requête copiant tout le brouillon) sont branchés
/// **une fois** ; le fil persisté et le fil affiché ont le **même** cycle
/// (amorce unique, écriture de chaque tour) ; et l'ordre de libération
/// (abonnement, tranches, puis conversation) est garanti. Un contrôleur reçu
/// de l'extérieur n'offrirait aucune de ces trois garanties. Le contrôleur
/// composé reste accessible par [chat] pour les vues.
///
/// ## Deux familles de verbes d'artefact, un seul point d'entrée chacune
///
/// * **Créer, régénérer, supprimer** sont les verbes que le socle sait
///   exécuter : génération par la séquence du kernel, suppression par le
///   stockage. Ils sont exécutés ici, après la confirmation que le registre
///   exige ([ZChatArtifactVerbConfirm]).
/// * **Tous les autres** (ouvrir, modifier, imprimer, partager, verbes
///   propres) appartiennent à l'hôte : ils sont transportés en
///   `ZChatCustomAction` ([ZChatArtifactVerbAction]) par
///   `ZChatController.runAction` — planification, confirmation et exécution
///   par l'exécuteur de l'hôte, comme tout autre verbe. Un exécuteur qui ne
///   sait pas faire répond `Left(ZUnsupportedOperationFailure)`.
///
/// Dans les deux cas, [runArtifactVerb] est l'unique entrée : il vérifie
/// d'abord que le verbe est **offert** (état, lecture seule, rôle du
/// message), et publie tout échec sur la tranche du couple — jamais levé,
/// jamais avalé.
///
/// ## Échecs : publiés, typés, par tranche
///
/// Chaque `(message, artefact)` porte aussi une tranche d'échec
/// ([failureOf]). Un refus de génération, une exception du port, un résultat
/// vide, un échec d'écriture ou de suppression, un verbe non supporté par
/// l'hôte y sont écrits. Les échecs du transcript vont dans [lastFailure].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import '../z_chat_controller.dart';
import '../z_chat_live_labels.dart';

/// Ajuste la requête de génération d'un artefact avant son envoi au port.
///
/// Le socle construit une requête complète (matière = contenu du message,
/// sujet = contenu de la question appariée, conversation) ; l'hôte peut la
/// remplacer par une requête dérivée (style, consigne, sujet exigé, modèle).
/// Un ajusteur qui lève est traité comme un refus de génération.
typedef ZChatArtifactRequestDecorator =
    ZChatArtifactGenerationRequest Function(
      ZChatArtifactGenerationRequest request,
      ZChatMessage message,
    );

/// Demande de confirmation d'un verbe d'artefact **destructeur** — seam
/// d'hôte, sans `BuildContext` ni libellé : le dialogue appartient à
/// l'application, qui lit [ZChatArtifactVerbAction.confirmToken] pour
/// choisir son message. N'est appelé que si le registre exige une
/// confirmation ; un seam qui lève vaut un refus.
typedef ZChatArtifactVerbConfirm =
    Future<bool> Function(ZChatArtifactVerbAction verb);

/// **Route** la requête de génération d'un artefact avant son envoi — seam
/// d'hôte, pur. Pendant de `ZChatRouteResolver` pour les artefacts : sur
/// `Left`, la génération n'est **pas** lancée (port jamais appelé, couple
/// jamais occupé, aucune annonce) et l'échec est publié sur la tranche du
/// couple. Un résolveur qui lève vaut un refus.
/// `ZChatRouteSession.resolveArtifact` en est l'implémentation de référence.
typedef ZChatArtifactRouteResolver =
    ZResult<ZChatArtifactGenerationRequest> Function(
      ZChatArtifactGenerationRequest request,
    );

/// Confirmation d'artefact **sans dialogue** : refuse tout verbe qui exige
/// une question. Même règle que [zChatConfirmWithoutDialog] — un verbe
/// destructeur reste refusé tant qu'un vrai dialogue n'est pas branché,
/// jamais exécuté sans question.
Future<bool> zChatConfirmArtifactWithoutDialog(
  ZChatArtifactVerbAction verb,
) async =>
    false;

/// Préfixe des verbes d'artefact dans le vocabulaire des actions.
const String kZChatArtifactVerbPrefix = 'artifact:';

/// Clé de charge : identité du message porteur.
const String kZChatArtifactPayloadMessageId = 'message_id';

/// Clé de charge : clé de l'artefact.
const String kZChatArtifactPayloadArtifactKey = 'artifact_key';

/// Clé de charge : clé du verbe.
const String kZChatArtifactPayloadVerbKey = 'verb_key';

/// Clé de charge : jeton de confirmation du verbe, s'il en porte un.
const String kZChatArtifactPayloadConfirmToken = 'confirm_token';

/// Un verbe d'artefact, tel qu'il circule dans un `ZChatCustomAction`.
///
/// C'est la forme que le seam de confirmation de l'hôte reçoit dans
/// `plan.action` : [of] la décode pour lire le jeton de confirmation.
@immutable
class ZChatArtifactVerbAction {
  /// Construit la description d'un verbe d'artefact.
  const ZChatArtifactVerbAction({
    required this.messageId,
    required this.artifactKey,
    required this.verbKey,
    this.confirmToken,
  });

  /// Message porteur.
  final String messageId;

  /// Artefact visé.
  final String artifactKey;

  /// Verbe demandé.
  final String verbKey;

  /// Jeton de confirmation déclaré sur le verbe, ou `null`.
  final String? confirmToken;

  /// Le verbe d'action, `artifact:<artefact>:<verbe>`.
  String get verb => '$kZChatArtifactVerbPrefix$artifactKey:$verbKey';

  /// L'action de conversation qui transporte ce verbe. [destructive] vient
  /// du registre ([ZChatArtifactRegistry.requiresConfirmation]).
  ZChatCustomAction toAction({required bool destructive}) =>
      ZChatCustomAction(
        verb: verb,
        isDestructive: destructive,
        cascades: false,
        preservesDraft: true,
        payload: <String, dynamic>{
          kZChatArtifactPayloadMessageId: messageId,
          kZChatArtifactPayloadArtifactKey: artifactKey,
          kZChatArtifactPayloadVerbKey: verbKey,
          if (confirmToken != null)
            kZChatArtifactPayloadConfirmToken: confirmToken,
        },
      );

  /// Décode [action] si c'est un verbe d'artefact, `null` sinon. Ne lève
  /// jamais.
  static ZChatArtifactVerbAction? of(ZChatAction action) {
    if (action is! ZChatCustomAction) return null;
    if (!action.verb.startsWith(kZChatArtifactVerbPrefix)) return null;
    final String? messageId =
        zJsonStringOrNull(action.payload[kZChatArtifactPayloadMessageId]);
    final String? artifactKey =
        zJsonStringOrNull(action.payload[kZChatArtifactPayloadArtifactKey]);
    final String? verbKey =
        zJsonStringOrNull(action.payload[kZChatArtifactPayloadVerbKey]);
    if (messageId == null || artifactKey == null || verbKey == null) {
      return null;
    }
    return ZChatArtifactVerbAction(
      messageId: messageId,
      artifactKey: artifactKey,
      verbKey: verbKey,
      confirmToken:
          zJsonStringOrNull(action.payload[kZChatArtifactPayloadConfirmToken]),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatArtifactVerbAction &&
          messageId == other.messageId &&
          artifactKey == other.artifactKey &&
          verbKey == other.verbKey &&
          confirmToken == other.confirmToken;

  @override
  int get hashCode => Object.hash(messageId, artifactKey, verbKey, confirmToken);
}

/// Le contrôleur de fil de travail : une conversation composée, des artefacts
/// à tranches granulaires, un fil persisté.
class ZChatNotebookController extends ChangeNotifier {
  /// Construit un contrôleur de fil de travail pour [conversationId].
  ///
  /// Ports **requis** : [streamPort] (génération des réponses) et
  /// [transcript] (lecture et écriture du fil).
  ///
  /// Ports **optionnels, à défaut inerte** :
  /// * [registry] — les artefacts déclarés ; vide, aucun artefact ;
  /// * [generationPort] — absent, « créer » et « régénérer » sont refusés
  ///   par `ZUnsupportedOperationFailure` ;
  /// * [store] — stockage des artefacts ; défaut en mémoire ;
  /// * [statePort] — existence des artefacts ; absent, l'existence est lue
  ///   dans [store] (présent si un contenu existe, sans compte) ;
  /// * [actionExecutor] — défaut [ZChatUnsupportedActionExecutor] ;
  /// * [confirm] — défaut [zChatConfirmWithoutDialog] : un verbe destructeur
  ///   de conversation est **refusé** tant qu'un dialogue n'est pas branché ;
  /// * [confirmArtifactVerb] — défaut [zChatConfirmArtifactWithoutDialog],
  ///   même règle pour « supprimer » (et tout verbe d'artefact déclaré
  ///   destructeur) ;
  /// * [newRequestId] — défaut [ZChatSequentialRequestIds] ;
  /// * [buildRequest] — défaut [ZChatDraftRequestBuilder] sur le style
  ///   `converse`, copiant tout le brouillon ;
  /// * [decorateRequest] — ajuste la requête de génération d'un artefact ;
  /// * [lifecycle], [liveLabels], [maxResumeAttempts], [routeResolver] —
  ///   relayés au contrôleur de conversation ;
  /// * [artifactRouteResolver] — route la requête de chaque artefact avant
  ///   son envoi (cf. [ZChatArtifactRouteResolver]) ;
  /// * [readOnly] — mode initial de lecture seule ([setReadOnly] le change).
  ZChatNotebookController({
    required ZChatStreamPort streamPort,
    required ZChatTranscriptPort transcript,
    required String conversationId,
    ZChatArtifactRegistry? registry,
    ZChatArtifactGenerationPort? generationPort,
    ZChatArtifactStorePort? store,
    ZChatArtifactStatePort? statePort,
    ZChatActionExecutor actionExecutor = const ZChatUnsupportedActionExecutor(),
    ZChatConfirm confirm = zChatConfirmWithoutDialog,
    ZChatArtifactVerbConfirm confirmArtifactVerb =
        zChatConfirmArtifactWithoutDialog,
    ZChatRequestIdFactory? newRequestId,
    ZChatRequestBuilder? buildRequest,
    ZChatArtifactRequestDecorator? decorateRequest,
    ZChatConversationLifecyclePort? lifecycle,
    ZChatRouteResolver? routeResolver,
    ZChatArtifactRouteResolver? artifactRouteResolver,
    ZChatLiveLabels liveLabels = ZChatLiveLabels.none,
    int maxResumeAttempts = 2,
    bool readOnly = false,
    // Un paramètre nommé ne peut pas s'appeler `_x` : les formels privés
    // sont interdits en Dart, et rendre ces champs publics élargirait la
    // surface du contrôleur. Même arbitrage que `ZChatController`.
    // ignore: prefer_initializing_formals
  })  : _transcript = transcript,
        // ignore: prefer_initializing_formals
        _artifactRouteResolver = artifactRouteResolver,
        _conversationId = conversationId,
        _registry = registry ?? ZChatArtifactRegistry.empty,
        // ignore: prefer_initializing_formals
        _generationPort = generationPort,
        _store = store ?? ZChatInMemoryArtifactStore(),
        // ignore: prefer_initializing_formals
        _statePort = statePort,
        // ignore: prefer_initializing_formals
        _confirmArtifactVerb = confirmArtifactVerb,
        // ignore: prefer_initializing_formals
        _decorateRequest = decorateRequest,
        _labels = liveLabels,
        _readOnly = ValueNotifier<bool>(readOnly) {
    final ZChatRequestIdFactory ids =
        newRequestId ?? ZChatSequentialRequestIds(conversationId).call;
    _newRequestId = ids;
    chat = ZChatController(
      streamPort: streamPort,
      actionExecutor: actionExecutor,
      confirm: confirm,
      newRequestId: ids,
      buildRequest: buildRequest ??
          ZChatDraftRequestBuilder(
            style: ZChatGenerationStyle.converse,
            conversationId: conversationId,
          ).call,
      lifecycle: lifecycle,
      routeResolver: routeResolver,
      liveLabels: liveLabels,
      maxResumeAttempts: maxResumeAttempts,
      conversationId: conversationId,
    );
    chat.messages.addListener(_onThreadChanged);
    // UN abonnement, tenu jusqu'à `dispose`. Le premier instantané amorce le
    // fil (`attach`) ; les suivants ne rafraîchissent que les tranches des
    // messages qui ont changé — `attach` annulerait toute requête en vol.
    //
    // L'abonnement est pris sur le flux de l'hôte LUI-MÊME, avec la règle du
    // fil vierge appliquée au listener (`onError`), plutôt qu'à travers
    // `zChatTranscriptOrEmpty` : un générateur `async*` suspendu dans son
    // `await for` ne propage un `cancel` à sa source qu'à l'ÉVÉNEMENT
    // SUIVANT — l'écouteur de l'hôte (un snapshot distant) survivrait au
    // `dispose` jusqu'à la prochaine écriture. Ici, `cancel` atteint la
    // source immédiatement.
    _subscription = _listen(() => transcript.messages(conversationId));
  }

  /// Le contrôleur de conversation composé — celui que les vues reçoivent.
  late final ZChatController chat;

  final ZChatTranscriptPort _transcript;
  final String _conversationId;
  final ZChatArtifactRegistry _registry;
  final ZChatArtifactGenerationPort? _generationPort;
  final ZChatArtifactStorePort _store;
  final ZChatArtifactStatePort? _statePort;
  final ZChatArtifactVerbConfirm _confirmArtifactVerb;
  final ZChatArtifactRequestDecorator? _decorateRequest;
  final ZChatArtifactRouteResolver? _artifactRouteResolver;
  final ZChatLiveLabels _labels;
  late final ZChatRequestIdFactory _newRequestId;

  StreamSubscription<List<ZChatMessage>>? _subscription;
  bool _attached = false;
  bool _disposed = false;

  /// Dernier instantané reçu du transcript.
  List<ZChatMessage> _latest = const <ZChatMessage>[];

  /// Messages déjà écrits au transcript, par identité, tels qu'écrits.
  final Map<String, ZChatMessage> _written = <String, ZChatMessage>{};

  /// L'occupation : les couples `(message, artefact)` dont une génération
  /// est en vol. Écrite **uniquement** par le marqueur passé à la séquence.
  final Set<(String, String)> _occupied = <(String, String)>{};

  /// Existence connue, par couple ; absente tant qu'aucune lecture n'a abouti.
  final Map<(String, String), ZChatArtifactExistence?> _existence =
      <(String, String), ZChatArtifactExistence?>{};

  final Map<(String, String), ValueNotifier<ZChatArtifactStatus>> _statuses =
      <(String, String), ValueNotifier<ZChatArtifactStatus>>{};
  final Map<(String, String), ValueNotifier<ZFailure?>> _failures =
      <(String, String), ValueNotifier<ZFailure?>>{};

  /// Jetons des générations d'artefact en vol, **par couple** — jamais un
  /// jeton d'instance.
  final Map<(String, String), ZChatRequestToken> _artifactTokens =
      <(String, String), ZChatRequestToken>{};

  final ValueNotifier<bool> _readOnly;
  final ValueNotifier<ZFailure?> _lastFailure = ValueNotifier<ZFailure?>(null);
  final ValueNotifier<String> _liveAnnouncement = ValueNotifier<String>('');

  // ── Surface de LECTURE ────────────────────────────────────────────────────

  /// Identité de la conversation.
  String get conversationId => _conversationId;

  /// Les artefacts déclarés.
  ZChatArtifactRegistry get registry => _registry;

  /// Mode lecture seule : retire « créer », « régénérer », « modifier »,
  /// « supprimer » ; conserve « ouvrir », « imprimer », « partager ».
  ValueListenable<bool> get readOnly => _readOnly;

  /// Dernier échec du **transcript** (écriture d'un tour), ou `null`.
  ValueListenable<ZFailure?> get lastFailure => _lastFailure;

  /// Texte à annoncer dans une région live pour les jalons d'artefact
  /// (génération lancée, terminée, échouée ; suppression). Silencieux sans
  /// libellé fourni dans [ZChatLiveLabels].
  ValueListenable<String> get liveAnnouncement => _liveAnnouncement;

  /// Le marqueur d'occupation, au type attendu par la séquence de
  /// génération du kernel — pour brancher un générateur **structuré** (une
  /// liste de cartes) sur `zChatRunArtifactGeneration` avec l'occupation de
  /// ce contrôleur.
  ZChatArtifactOccupancyMarker get markArtifact => _mark;

  /// L'état de l'artefact [artifactKey] sur [messageId] — **instance stable**
  /// par couple. La première demande déclenche une lecture d'existence ; la
  /// valeur initiale est « absent » (ou « en cours » si une génération est
  /// en vol).
  ValueListenable<ZChatArtifactStatus> statusOf(
    String messageId,
    String artifactKey,
  ) {
    final (String, String) pair = (messageId, artifactKey);
    final ValueNotifier<ZChatArtifactStatus>? existing = _statuses[pair];
    if (existing != null) return existing;
    final ValueNotifier<ZChatArtifactStatus> created =
        ValueNotifier<ZChatArtifactStatus>(_resolve(pair));
    _statuses[pair] = created;
    unawaited(_refresh(pair));
    return created;
  }

  /// Le dernier échec de l'artefact [artifactKey] sur [messageId], ou
  /// `null` — instance stable par couple.
  ValueListenable<ZFailure?> failureOf(String messageId, String artifactKey) =>
      _failureOf((messageId, artifactKey));

  /// Les verbes offerts sur [artifactKey] pour [messageId], dans l'ordre
  /// déclaré : ceux du registre pour l'état courant et le mode lecture seule,
  /// **aucun** pour un message de l'utilisateur ou absent du fil.
  List<ZChatArtifactVerb> verbsFor(String messageId, String artifactKey) {
    final ZChatMessage? message = chat.messageById(messageId);
    if (message == null || message.role == ZChatRole.user) {
      return const <ZChatArtifactVerb>[];
    }
    return _registry.verbsFor(
      artifactKey,
      statusOf(messageId, artifactKey).value,
      readOnly: _readOnly.value,
    );
  }

  /// Le message [messageId] du fil, ou `null`.
  ZChatMessage? messageById(String messageId) => chat.messageById(messageId);

  /// Le message apparié à [messageId], ou `null` (cf.
  /// [ZChatController.replyToOf]).
  ZChatMessage? replyToOf(String messageId) => chat.replyToOf(messageId);

  /// Le texte brut de [messageId], ou `null`.
  String? contentOf(String messageId) => chat.contentOf(messageId);

  // ── Surface d'ÉCRITURE ────────────────────────────────────────────────────

  /// Change le mode lecture seule. Les verbes se recalculent à la demande ;
  /// la tranche [readOnly] signale le changement.
  void setReadOnly(bool value) => _readOnly.value = value;

  /// Exécute le verbe [verbKey] de l'artefact [artifactKey] sur [messageId].
  ///
  /// Un verbe qui n'est pas **offert** à cet instant (état, lecture seule,
  /// message utilisateur) est refusé. « Créer », « régénérer » et
  /// « supprimer » sont exécutés ici, après la confirmation exigée par le
  /// registre ; tout autre verbe est transporté par `chat.runAction` vers
  /// l'exécuteur de l'hôte. Chaque échec est publié sur la tranche d'échec
  /// du couple.
  Future<ZResult<ZChatActionOutcome>> runArtifactVerb({
    required String messageId,
    required String artifactKey,
    required String verbKey,
  }) async {
    final (String, String) pair = (messageId, artifactKey);
    final List<ZChatArtifactVerb> offered = verbsFor(messageId, artifactKey);
    ZChatArtifactVerb? verb;
    for (final ZChatArtifactVerb v in offered) {
      if (v.key == verbKey) verb = v;
    }
    if (verb == null) {
      final ZFailure failure = ZDomainFailure(
        'artifact verb $verbKey is not offered on $artifactKey/$messageId',
      );
      _failureOf(pair).value = failure;
      return Left<ZFailure, ZChatActionOutcome>(failure);
    }
    final bool destructive =
        _registry.requiresConfirmation(artifactKey, verbKey);
    final ZChatArtifactVerbAction described = ZChatArtifactVerbAction(
      messageId: messageId,
      artifactKey: artifactKey,
      verbKey: verbKey,
      confirmToken: verb.confirmToken,
    );
    final ZResult<ZChatActionOutcome> outcome = switch (verbKey) {
      kZChatArtifactVerbCreate ||
      kZChatArtifactVerbRegenerate ||
      kZChatArtifactVerbDelete =>
        await _runNatively(pair, described, destructive: destructive),
      _ => await chat.runAction(described.toAction(destructive: destructive)),
    };
    outcome.fold(
      (ZFailure f) => _failureOf(pair).value = f,
      (ZChatActionOutcome _) => _failureOf(pair).value = null,
    );
    return outcome;
  }

  /// Les trois verbes du socle : confirmation si exigée, puis génération ou
  /// suppression. Ne lève jamais.
  Future<ZResult<ZChatActionOutcome>> _runNatively(
    (String, String) pair,
    ZChatArtifactVerbAction verb, {
    required bool destructive,
  }) async {
    if (destructive && !await _askArtifact(verb)) {
      return Left<ZFailure, ZChatActionOutcome>(
        ZChatActionNotConfirmedFailure(verb: verb.verb),
      );
    }
    final ZResult<Unit> done = verb.verbKey == kZChatArtifactVerbDelete
        ? await _delete(pair)
        : await _generate(pair, verb);
    return done.map(
      (Unit _) => ZChatActionOutcome(
        verb: verb.verb,
        affectedMessageIds: <String>[verb.messageId],
      ),
    );
  }

  /// Pose la question. Un seam qui lève vaut un refus (AD-10).
  Future<bool> _askArtifact(ZChatArtifactVerbAction verb) async {
    try {
      return await _confirmArtifactVerb(verb);
    } catch (error) {
      return false;
    }
  }

  /// Annule la génération d'artefact en vol sur [artifactKey]/[messageId],
  /// s'il y en a une. Sans effet sinon.
  void cancelArtifact({required String messageId, required String artifactKey}) {
    _artifactTokens[(messageId, artifactKey)]?.cancel();
  }

  /// Relit l'existence de [artifactKey] sur [messageId] et recalcule sa
  /// tranche — à appeler quand l'hôte a modifié le contenu hors du
  /// contrôleur (éditeur externe).
  Future<void> refreshArtifact({
    required String messageId,
    required String artifactKey,
  }) =>
      _refresh((messageId, artifactKey));

  // ── Génération et suppression ─────────────────────────────────────────────

  Future<ZResult<Unit>> _generate(
    (String, String) pair,
    ZChatArtifactVerbAction verb,
  ) async {
    final ZChatArtifactGenerationPort? port = _generationPort;
    if (port == null) {
      return const Left<ZFailure, Unit>(
        ZUnsupportedOperationFailure(
          'no artifact generation port is wired',
          operation: 'generateArtifact',
        ),
      );
    }
    final ZChatMessage? message = chat.messageById(verb.messageId);
    if (message == null) {
      return Left<ZFailure, Unit>(
        ZNotFoundFailure('chat message ${verb.messageId} is not in the thread'),
      );
    }
    final ZChatArtifactGenerationRequest built;
    try {
      built = _requestFor(message, verb);
    } catch (error) {
      return Left<ZFailure, Unit>(ZChatArtifactGenerationFailure(
        'artifact request decorator threw: $error',
        messageId: verb.messageId,
        artifactKey: verb.artifactKey,
        cause: error,
      ));
    }
    // Le ROUTAGE vient ici : après l'ajusteur, AVANT le jeton, l'annonce et
    // la séquence (donc avant `mark(busy)` et tout appel de port). Sans
    // résolveur, `request` EST `built`.
    final ZChatArtifactGenerationRequest request;
    final ZChatArtifactRouteResolver? route = _artifactRouteResolver;
    if (route == null) {
      request = built;
    } else {
      ZResult<ZChatArtifactGenerationRequest> routed;
      try {
        routed = route(built);
      } catch (error) {
        routed = Left<ZFailure, ZChatArtifactGenerationRequest>(
          ZChatArtifactGenerationFailure(
            'artifact route resolver threw: $error',
            messageId: verb.messageId,
            artifactKey: verb.artifactKey,
            cause: error,
          ),
        );
      }
      final ZFailure? refused = routed.fold(
        (ZFailure f) => f,
        (ZChatArtifactGenerationRequest _) => null,
      );
      if (refused != null) return Left<ZFailure, Unit>(refused);
      request = routed.getOrElse(() => built);
    }
    final ZChatRequestToken token = ZChatRequestToken(_newRequestId());
    _artifactTokens[pair] = token;
    _say(_labels.artifactGenerationStarted?.call(verb.artifactKey));
    final ZResult<ZChatArtifactContent> produced =
        await ZChatArtifactGenerationRunner(port: port, store: _store)
            .run(request, token: token, mark: _mark);
    _artifactTokens.remove(pair);
    if (_disposed) return const Right<ZFailure, Unit>(unit);
    return produced.fold(
      (ZFailure f) {
        _say(_labels.artifactGenerationFailed?.call(verb.artifactKey));
        return Left<ZFailure, Unit>(f);
      },
      (ZChatArtifactContent _) {
        _say(_labels.artifactGenerationCompleted?.call(verb.artifactKey));
        // L'existence a changé : la tranche est relue, pas le fil.
        unawaited(_refresh(pair));
        return const Right<ZFailure, Unit>(unit);
      },
    );
  }

  ZChatArtifactGenerationRequest _requestFor(
    ZChatMessage message,
    ZChatArtifactVerbAction verb,
  ) {
    final ZChatMessage? question = chat.replyToOf(verb.messageId);
    final String? questionId = question?.id;
    final ZChatArtifactGenerationRequest base = ZChatArtifactGenerationRequest(
      messageId: verb.messageId,
      artifactKey: verb.artifactKey,
      notes: message.content,
      subject: questionId == null ? '' : (chat.contentOf(questionId) ?? ''),
      conversationId: _conversationId,
    );
    final ZChatArtifactRequestDecorator? decorate = _decorateRequest;
    return decorate == null ? base : decorate(base, message);
  }

  Future<ZResult<Unit>> _delete((String, String) pair) async {
    final ZResult<Unit> deleted;
    try {
      // `delete` seul porte l'anti-résurrection : jamais un `write('')`.
      deleted = await _store.delete(messageId: pair.$1, artifactKey: pair.$2);
    } catch (error) {
      return Left<ZFailure, Unit>(
        ZDomainFailure('artifact store threw ${error.runtimeType} on delete'),
      );
    }
    return deleted.fold(
      (ZFailure f) => Left<ZFailure, Unit>(f),
      (Unit _) {
        _say(_labels.artifactDeleted?.call(pair.$2));
        unawaited(_refresh(pair));
        return const Right<ZFailure, Unit>(unit);
      },
    );
  }

  // ── Occupation & tranches ─────────────────────────────────────────────────

  void _mark(String messageId, String artifactKey, {required bool busy}) {
    final (String, String) pair = (messageId, artifactKey);
    final bool changed = busy ? _occupied.add(pair) : _occupied.remove(pair);
    if (!changed || _disposed) return;
    // La tranche du couple, et elle seule.
    _statuses[pair]?.value = _resolve(pair);
  }

  ZChatArtifactStatus _resolve((String, String) pair) =>
      ZChatArtifactStatus.resolve(
        busy: _occupied.contains(pair),
        existence: _existence[pair],
      );

  ValueNotifier<ZFailure?> _failureOf((String, String) pair) =>
      _failures[pair] ??= ValueNotifier<ZFailure?>(null);

  Future<void> _refresh((String, String) pair) async {
    final ZResult<ZChatArtifactExistence> read = await _readExistence(pair);
    if (_disposed) return;
    _existence[pair] = read.fold(
      (ZFailure _) => null,
      (ZChatArtifactExistence e) => e,
    );
    _statuses[pair]?.value = _resolve(pair);
  }

  /// Lecture d'existence : le port d'état s'il est câblé, sinon le stockage
  /// (présent si un contenu existe). Un port qui lève vaut un `Left` —
  /// l'artefact est rendu absent, rien ne remonte.
  Future<ZResult<ZChatArtifactExistence>> _readExistence(
    (String, String) pair,
  ) async {
    final ZChatArtifactStatePort? port = _statePort;
    try {
      if (port != null) {
        return await port.existenceOf(
          messageId: pair.$1,
          artifactKey: pair.$2,
        );
      }
      final ZResult<String?> stored =
          await _store.read(messageId: pair.$1, artifactKey: pair.$2);
      return stored.map(
        (String? content) => content == null
            ? ZChatArtifactExistence.absent
            : const ZChatArtifactExistence.found(),
      );
    } catch (error) {
      return Left<ZFailure, ZChatArtifactExistence>(
        ZDomainFailure(
          'artifact state read threw ${error.runtimeType} on '
          '${pair.$2}/${pair.$1}',
        ),
      );
    }
  }

  // ── Le fil : lecture (instantanés) et écriture (tours) ───────────────────

  /// La règle du fil vierge, au listener : une erreur avant tout instantané
  /// ouvre un fil vide ; après, le dernier instantané reste. Un port dont
  /// `messages` lève à l'appel vaut une erreur immédiate.
  StreamSubscription<List<ZChatMessage>> _listen(
    Stream<List<ZChatMessage>> Function() open,
  ) {
    Stream<List<ZChatMessage>> source;
    try {
      source = open();
    } catch (error) {
      source = Stream<List<ZChatMessage>>.error(error);
    }
    return source.listen(
      _onSnapshot,
      onError: (Object _, StackTrace _) {
        if (!_attached) _onSnapshot(const <ZChatMessage>[]);
      },
      cancelOnError: false,
    );
  }

  void _onSnapshot(List<ZChatMessage> snapshot) {
    if (_disposed) return;
    if (!_attached) {
      _attached = true;
      _latest = snapshot;
      // Base d'écriture : ce qui vient du transcript n'y retourne pas.
      for (final ZChatMessage m in snapshot) {
        final String? id = m.id;
        if (id != null) _written[id] = m;
      }
      chat.attach(conversationId: _conversationId, messages: snapshot);
      return;
    }
    // Instantanés suivants : SEULES les tranches des messages qui ont changé
    // sont relues. Le fil du contrôleur de conversation n'est pas rebranché.
    final Map<String, ZChatMessage> before = <String, ZChatMessage>{
      for (final ZChatMessage m in _latest)
        if (m.id != null) m.id!: m,
    };
    _latest = snapshot;
    for (final ZChatMessage m in snapshot) {
      final String? id = m.id;
      if (id == null) continue;
      if (before[id] == m) continue;
      for (final (String, String) pair in _statuses.keys) {
        if (pair.$1 == id) unawaited(_refresh(pair));
      }
    }
  }

  /// Écrit au transcript ce que le fil du contrôleur de conversation a de
  /// neuf : un message inconnu est ajouté, un message connu qui a changé est
  /// mis à jour. Chaque `Left` est publié dans [lastFailure].
  void _onThreadChanged() {
    if (_disposed) return;
    for (final ZChatMessage m in chat.messages.value) {
      final String? id = m.id;
      if (id == null) continue;
      final ZChatMessage? known = _written[id];
      if (known == m) continue;
      _written[id] = m;
      unawaited(_write(known == null ? _transcript.append(m) : _transcript.update(m)));
    }
  }

  Future<void> _write(Future<ZResult<ZChatMessage>> pending) async {
    ZResult<ZChatMessage> result;
    try {
      result = await pending;
    } catch (error) {
      result = Left<ZFailure, ZChatMessage>(
        ZDomainFailure('chat transcript port threw ${error.runtimeType}'),
      );
    }
    if (_disposed) return;
    result.fold(
      (ZFailure f) => _lastFailure.value = f,
      (ZChatMessage _) {},
    );
  }

  void _say(String? text) {
    if (text == null || text.isEmpty || _disposed) return;
    if (_liveAnnouncement.value == text) _liveAnnouncement.value = '';
    _liveAnnouncement.value = text;
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    for (final ZChatRequestToken token in _artifactTokens.values) {
      token.cancel();
    }
    _artifactTokens.clear();
    chat.messages.removeListener(_onThreadChanged);
    for (final ValueNotifier<ZChatArtifactStatus> n in _statuses.values) {
      n.dispose();
    }
    _statuses.clear();
    for (final ValueNotifier<ZFailure?> n in _failures.values) {
      n.dispose();
    }
    _failures.clear();
    _readOnly.dispose();
    _lastFailure.dispose();
    _liveAnnouncement.dispose();
    chat.dispose();
    super.dispose();
  }
}
