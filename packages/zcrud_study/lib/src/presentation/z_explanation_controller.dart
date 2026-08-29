/// `ZExplanationController` — orchestration d'une explication IA : génération
/// (progressive quand le transport le permet), traitements successifs et
/// **historique de versions**.
///
/// ## Réactivité Flutter-native PURE (AD-2/AD-15)
///
/// `ChangeNotifier` **pur-Flutter** : aucun gestionnaire d'état. Le statut est
/// une **enum** ([ZExplanationStatus]), jamais une grappe de booléens qui
/// pourrait exprimer un état impossible.
///
/// Le texte qui s'accumule pendant une génération progressive **ne passe pas**
/// par `notifyListeners` : il vit dans la tranche
/// [ZExplanationController.streamingText] (`ValueListenable<String>`). Une vue
/// qui n'écoute que cette tranche se reconstruit à chaque fragment ; le reste
/// de la surface, lui, ne bouge pas. C'est la différence entre un rendu
/// progressif utilisable et un formulaire qui repart de zéro à chaque paquet
/// reçu.
///
/// ## Un seul port, une intention par requête
///
/// Les traitements ([summarize], [regenerate], [elaborate], [restyle]) ne sont
/// **pas** des ports distincts : ils appellent le **même** port avec une
/// `operation` différente. Les clés d'opération, comme les clés de style, sont
/// du **vocabulaire de l'hôte** : elles sont injectées
/// ([ZExplanationOperationKeys]) et transmises verbatim. Ce paquet n'en
/// déclare aucune, et n'en interprète aucune.
///
/// ## Rien n'est écrit ici
///
/// Aucun dépôt, aucun store, aucune entité persistée n'est importé : le
/// contrôleur produit du texte et un historique en mémoire. La matérialisation
/// (par exemple en explication persistée) appartient à l'application, qui la
/// déclenche depuis la surface.
///
/// ## Port ASYNCHRONE et FAILLIBLE (AD-10)
///
/// Le port peut lever, rendre `Left(ZFailure)`, un texte vide, ou répondre
/// **tard**. Un **jeton de fraîcheur monotone**, capturé au lancement et
/// comparé à chaque événement, écarte toute réponse périmée : un flux
/// abandonné n'écrase **jamais** la version courante, et aucun
/// `notifyListeners` ne survient après `dispose`. Aucune exception ne remonte
/// des méthodes publiques.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;

import '../domain/z_ai_explanation_port.dart';
import '../domain/z_ai_explanation_stream_port.dart';

/// Statut du flux d'explication (AD-2 : une enum, jamais des booléens).
enum ZExplanationStatus {
  /// Aucune génération en cours et aucune version produite depuis la remise.
  idle,

  /// Requête en vol (flux ou `await`) — l'anti-double-soumission est actif.
  generating,

  /// Une version est disponible et sélectionnée.
  ready,

  /// Le port a rendu un texte vide : **aucune version n'est ajoutée**, et
  /// l'historique reste tel quel. Ce n'est pas un échec.
  empty,

  /// Échec (`Left`, exception captée, ou erreur du flux) : `lastFailure` est
  /// disponible s'il vient d'un `Left`, et **l'historique est intact**.
  failed,
}

/// Une version d'explication : le texte produit, et les clés opaques qui
/// disent d'où il vient.
@immutable
class ZExplanationVersion {
  /// Construit une version.
  const ZExplanationVersion({
    required this.text,
    this.style,
    this.operation,
  });

  /// Texte de la version, **verbatim** tel que rendu par le port.
  final String text;

  /// Clé de style opaque ayant produit cette version, ou `null`.
  final String? style;

  /// Clé d'opération opaque ayant produit cette version, ou `null` pour la
  /// génération initiale.
  final String? operation;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZExplanationVersion &&
          text == other.text &&
          style == other.style &&
          operation == other.operation;

  @override
  int get hashCode => Object.hash(text, style, operation);
}

/// Clés d'opération **injectées** — vocabulaire de l'hôte, transmis verbatim
/// au port dans `ZAiExplanationRequest.operation`.
///
/// Une clé `null` rend le traitement correspondant **indisponible** : la
/// méthode du contrôleur est alors sans effet, et la surface n'en montre
/// aucune commande. C'est ce qui permet à un hôte de n'offrir que les
/// traitements que son transport sait faire, sans bouton inerte.
@immutable
class ZExplanationOperationKeys {
  /// Construit les clés injectées (toutes optionnelles).
  const ZExplanationOperationKeys({
    this.summarize,
    this.regenerate,
    this.elaborate,
    this.restyle,
  });

  /// Clé du traitement « condenser le texte courant ».
  final String? summarize;

  /// Clé du traitement « refaire depuis la demande d'origine ».
  final String? regenerate;

  /// Clé du traitement « développer le texte courant ».
  final String? elaborate;

  /// Clé du traitement « rendre le texte courant dans un autre style ».
  final String? restyle;
}

/// Messages INJECTÉS des issues qui ne portent pas de message présentable.
///
/// Un `Left` porte déjà son message ; une **exception** n'en porte aucun, et
/// un texte vide n'est pas un échec du tout. Ces deux cas-là seulement ont
/// besoin d'un libellé, et il est injecté (aucun libellé en dur — FR-26).
@immutable
class ZExplanationMessages {
  /// Construit les messages injectés.
  const ZExplanationMessages({
    required this.unexpectedError,
    required this.emptyResult,
  });

  /// Affiché quand le port **lève** ou que le flux rend une erreur.
  final String unexpectedError;

  /// Affiché quand le port rend un texte vide (statut `empty`).
  final String emptyResult;
}

/// Contrôleur d'explication IA à historique de versions.
class ZExplanationController extends ChangeNotifier {
  /// Construit le contrôleur autour d'un port one-shot [port], éventuellement
  /// doublé d'un port progressif [streamPort].
  ///
  /// [streamPort] n'est utilisé que s'il est fourni **et** que son
  /// `isAvailable` vaut `true` au moment du lancement — sinon la voie one-shot
  /// est prise, inchangée. Le choix est fait à chaque génération, jamais figé
  /// à la construction : un hôte peut couper le progressif à chaud.
  ///
  /// [initialVersions] amorce l'historique (par exemple avec une explication
  /// déjà persistée). Non vide ⇒ le statut initial est `ready` et la dernière
  /// version est sélectionnée.
  ZExplanationController({
    required ZAiExplanationPort port,
    required this.messages,
    ZAiExplanationStreamPort? streamPort,
    this.operations = const ZExplanationOperationKeys(),
    List<ZExplanationVersion> initialVersions = const <ZExplanationVersion>[],
    // Les deux ports sont PRIVÉS pour qu'aucun appelant ne court-circuite le
    // contrôleur ; un paramètre nommé ne peut pas l'être, d'où l'affectation
    // par liste d'initialisation. Le lint propose un formel initialisant qui
    // serait ici illégal.
    // ignore: prefer_initializing_formals
  })  : _port = port,
        // ignore: prefer_initializing_formals
        _streamPort = streamPort,
        _versions = List<ZExplanationVersion>.of(initialVersions) {
    if (_versions.isNotEmpty) {
      _index = _versions.length - 1;
      _status = ZExplanationStatus.ready;
      _streamingText.value = _versions[_index].text;
    }
  }

  final ZAiExplanationPort _port;
  final ZAiExplanationStreamPort? _streamPort;

  /// Messages injectés (i18n).
  final ZExplanationMessages messages;

  /// Clés d'opération injectées (vocabulaire de l'hôte).
  final ZExplanationOperationKeys operations;

  final List<ZExplanationVersion> _versions;
  int _index = -1;

  final ValueNotifier<String> _streamingText = ValueNotifier<String>('');

  /// Texte **cumulé** de la génération en cours, exposé comme une tranche
  /// réactive isolée.
  ///
  /// Pendant une génération progressive, seule cette tranche est notifiée :
  /// les auditeurs du contrôleur lui-même (donc la surface hôte) ne sont
  /// **pas** réveillés à chaque fragment. Hors génération, elle porte le texte
  /// de la version sélectionnée.
  ValueListenable<String> get streamingText => _streamingText;

  ZExplanationStatus _status = ZExplanationStatus.idle;

  /// Statut courant (AD-2).
  ZExplanationStatus get status => _status;

  /// `true` pendant une génération (flux ou one-shot).
  bool get isGenerating => _status == ZExplanationStatus.generating;

  /// Historique des versions, de la plus ancienne à la plus récente.
  /// Liste **non modifiable** : l'historique ne se modifie que par le
  /// contrôleur.
  List<ZExplanationVersion> get versions =>
      List<ZExplanationVersion>.unmodifiable(_versions);

  /// Index de la version sélectionnée, ou `-1` si l'historique est vide.
  int get currentIndex => _index;

  /// Version sélectionnée, ou `null` si l'historique est vide.
  ZExplanationVersion? get current =>
      _index >= 0 && _index < _versions.length ? _versions[_index] : null;

  /// Texte de la version sélectionnée (`''` si aucune).
  String get currentText => current?.text ?? '';

  ZFailure? _lastFailure;

  /// Dernier échec TYPÉ (`Left`), ou `null`.
  ///
  /// `null` en `failed` signifie que l'échec vient d'une **exception** ou
  /// d'une erreur de flux : il n'existe alors aucun `ZFailure` à exposer, et
  /// le message affiché est celui injecté. Ne jamais en fabriquer un.
  ZFailure? get lastFailure => _lastFailure;

  String? _errorMessage;

  /// Message lisible de la dernière issue non nominale, ou `null`.
  String? get errorMessage => _errorMessage;

  ZAiExplanationRequest? _seedRequest;

  /// Requête d'ORIGINE, celle passée à [explain] — jamais réécrite par un
  /// traitement. C'est elle qui sert de base à [regenerate].
  ZAiExplanationRequest? get seedRequest => _seedRequest;

  ZAiExplanationRequest? _lastRequest;

  /// Dernière requête EFFECTIVEMENT soumise à un port (traitements inclus).
  ZAiExplanationRequest? get lastRequest => _lastRequest;

  /// Jeton de fraîcheur MONOTONE : capturé au lancement, comparé à chaque
  /// événement. Toute réponse dont le jeton ne correspond plus est écartée.
  int _generation = 0;

  StreamSubscription<ZResult<ZGenerationProgress>>? _subscription;

  bool _disposed = false;

  /// `true` si un traitement est offert par les clés injectées.
  bool get canSummarize => operations.summarize != null;

  /// `true` si la régénération est offerte par les clés injectées.
  bool get canRegenerate => operations.regenerate != null;

  /// `true` si le développement est offert par les clés injectées.
  bool get canElaborate => operations.elaborate != null;

  /// `true` si le changement de style est offert par les clés injectées.
  bool get canRestyle => operations.restyle != null;

  /// `true` s'il existe une version antérieure à la version sélectionnée.
  bool get canUndo => _index > 0;

  /// `true` s'il existe une version postérieure à la version sélectionnée.
  bool get canRedo => _index >= 0 && _index < _versions.length - 1;

  /// Lance l'explication de [request] et **mémorise** cette requête comme
  /// requête d'origine.
  ///
  /// Ne lève jamais : un `Left` devient `failed` (avec `lastFailure`), une
  /// exception devient `failed` (sans `lastFailure`), un texte vide devient
  /// `empty` sans toucher à l'historique. Ignorée si une génération est déjà
  /// en vol.
  void explain(ZAiExplanationRequest request) {
    _seedRequest = request;
    _run(request);
  }

  /// Condense le texte courant. Sans clé `summarize` injectée, sans version
  /// courante, ou pendant une génération : **sans effet**.
  void summarize() => _operate(operations.summarize, fromCurrentText: true);

  /// Refait l'explication depuis la requête d'origine (pas depuis le texte
  /// courant). Sans clé `regenerate` injectée : **sans effet**.
  void regenerate() => _operate(operations.regenerate, fromCurrentText: false);

  /// Développe le texte courant. Sans clé `elaborate` injectée : **sans
  /// effet**.
  void elaborate() => _operate(operations.elaborate, fromCurrentText: true);

  /// Rend le texte courant dans le style [styleKey] — clé **opaque** de
  /// l'hôte, transmise verbatim avec la clé d'opération `restyle`. Sans clé
  /// `restyle` injectée : **sans effet**.
  void restyle(String styleKey) =>
      _operate(operations.restyle, fromCurrentText: true, style: styleKey);

  /// Sélectionne la version d'index [index]. Hors bornes : **sans effet**.
  void select(int index) {
    if (index < 0 || index >= _versions.length || index == _index) return;
    _index = index;
    _streamingText.value = _versions[index].text;
    _status = ZExplanationStatus.ready;
    _errorMessage = null;
    _notify();
  }

  /// Sélectionne la version précédente, s'il y en a une.
  void undo() {
    if (canUndo) select(_index - 1);
  }

  /// Sélectionne la version suivante, s'il y en a une.
  void redo() {
    if (canRedo) select(_index + 1);
  }

  /// Abandonne la génération en cours : le flux est fermé, son jeton périmé,
  /// et **l'historique reste intact** — la version sélectionnée n'est jamais
  /// écrasée par un flux abandonné. Sans génération en cours : remet
  /// simplement le message d'issue à zéro.
  void abandon() {
    _generation++;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _errorMessage = null;
    _lastFailure = null;
    _streamingText.value = currentText;
    _status = _versions.isEmpty
        ? ZExplanationStatus.idle
        : ZExplanationStatus.ready;
    _notify();
  }

  void _operate(
    String? operation, {
    required bool fromCurrentText,
    String? style,
  }) {
    if (operation == null) return;
    final seed = _seedRequest;
    if (seed == null) return;
    if (fromCurrentText && current == null) return;
    _run(
      seed.withOperation(
        operation,
        style: style,
        // Le texte courant devient la MATIÈRE du traitement : condenser,
        // développer ou restyler porte sur ce qui a déjà été produit, pas sur
        // la demande d'origine. `regenerate`, lui, repart de la demande — d'où
        // le drapeau plutôt qu'un contenu toujours substitué.
        content: fromCurrentText ? currentText : null,
      ),
    );
  }

  void _run(ZAiExplanationRequest request) {
    if (_status == ZExplanationStatus.generating) return;
    final token = ++_generation;
    unawaited(_subscription?.cancel());
    _subscription = null;
    _lastRequest = request;
    _lastFailure = null;
    _errorMessage = null;
    _streamingText.value = '';
    _setStatus(ZExplanationStatus.generating);

    final stream = _streamPort;
    if (stream != null && stream.isAvailable) {
      _runStream(stream, request, token);
    } else {
      unawaited(_runOneShot(request, token));
    }
  }

  void _runStream(
    ZAiExplanationStreamPort port,
    ZAiExplanationRequest request,
    int token,
  ) {
    Stream<ZResult<ZGenerationProgress>> events;
    try {
      events = port.explainStream(request);
    } catch (_) {
      // Le port a levé AVANT d'avoir produit le moindre flux (AD-10).
      _fail(messages.unexpectedError, null);
      return;
    }
    var committed = false;
    _subscription = events.listen(
      (result) {
        if (_isStale(token)) return;
        result.fold(
          (failure) {
            committed = true; // l'échec fait office de fin de course.
            unawaited(_subscription?.cancel());
            _subscription = null;
            // L'historique n'est PAS touché : la version précédente reste
            // sélectionnée et intacte.
            _fail(failure.message, failure);
          },
          (progress) {
            // Seule la tranche est notifiée : la surface hôte ne se
            // reconstruit pas à chaque fragment.
            _streamingText.value = progress.text;
            if (progress.isDone) {
              committed = true;
              _commit(progress.text, request);
            }
          },
        );
      },
      onError: (Object _) {
        if (_isStale(token)) return;
        committed = true;
        _fail(messages.unexpectedError, null);
      },
      onDone: () {
        if (_isStale(token) || committed) return;
        // Flux terminé sans `isDone` : le dernier texte reçu fait foi.
        _commit(_streamingText.value, request);
      },
      cancelOnError: true,
    );
  }

  Future<void> _runOneShot(ZAiExplanationRequest request, int token) async {
    ZResult<String> result;
    try {
      result = await _port.explain(request);
    } catch (_) {
      if (_isStale(token)) return;
      _fail(messages.unexpectedError, null);
      return;
    }
    if (_isStale(token)) return;
    result.fold(
      (failure) => _fail(failure.message, failure),
      (text) => _commit(text, request),
    );
  }

  /// Ajoute une version à l'historique et la sélectionne.
  ///
  /// La vacuité est mesurée sur le texte **débarrassé de ses blancs** : un
  /// résultat fait uniquement d'espaces n'est pas une version. Le texte
  /// conservé, lui, est celui du port, **sans rognage**.
  void _commit(String text, ZAiExplanationRequest request) {
    if (text.trim().isEmpty) {
      _errorMessage = messages.emptyResult;
      _streamingText.value = currentText;
      _setStatus(ZExplanationStatus.empty);
      return;
    }
    _versions.add(
      ZExplanationVersion(
        text: text,
        style: request.style,
        operation: request.operation,
      ),
    );
    _index = _versions.length - 1;
    _streamingText.value = text;
    _setStatus(ZExplanationStatus.ready);
  }

  void _fail(String message, ZFailure? failure) {
    _errorMessage = message;
    _lastFailure = failure;
    _streamingText.value = currentText;
    _setStatus(ZExplanationStatus.failed);
  }

  bool _isStale(int token) => _disposed || token != _generation;

  void _setStatus(ZExplanationStatus status) {
    _status = status;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++; // toute réponse en vol devient périmée.
    unawaited(_subscription?.cancel());
    _subscription = null;
    _streamingText.dispose();
    super.dispose();
  }
}
