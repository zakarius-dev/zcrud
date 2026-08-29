/// `ZPodcastGenerationController` — orchestration du flux de génération de
/// podcast, au-dessus de `ZPodcastGenerationPort`.
///
/// ## Réactivité Flutter-native PURE (AD-2/AD-15)
///
/// `ChangeNotifier` **pur-Flutter** : aucun gestionnaire d'état. Le statut est
/// une **enum** ([ZPodcastGenerationStatus]), jamais une grappe de booléens
/// qui pourrait exprimer un état impossible (« en cours » et « échoué » en
/// même temps).
///
/// ## Rien n'est écrit ici (AD-43)
///
/// Le contrôleur n'importe aucun dépôt ni store : le podcast produit est remis
/// à l'appelant par le **handoff** [ZPodcastGeneratedCallback], qui décide
/// seul de le persister. Un `Left` du port, une exception, une surface
/// abandonnée : **zéro** appel de handoff, donc zéro écriture possible.
///
/// ## Port ASYNCHRONE et FAILLIBLE (AD-10)
///
/// Le port peut **lever**, renvoyer `Left(ZFailure)`, ou répondre **tard**
/// (surface déjà fermée). Un **jeton de fraîcheur monotone**, capturé avant
/// l'`await` et comparé après, écarte toute réponse périmée : jamais un
/// résultat obsolète appliqué, jamais un `notifyListeners` après `dispose`.
/// Aucune exception ne remonte de [generate].
///
/// ## Fraîcheur adressée par contenu
///
/// [freshnessFor] compare l'empreinte du podcast détenu à l'empreinte courante
/// de la source, en déléguant à la fonction pure du kernel — aucun hachage
/// n'est calculé ici, aucune horloge n'est lue.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZPodcastFreshness, ZStudyPodcast, podcastFreshness;

import '../domain/z_podcast_generation_port.dart';

/// Statut du flux de génération de podcast (AD-2 : une enum, jamais des
/// booléens — deux états ne peuvent pas être vrais en même temps).
enum ZPodcastGenerationStatus {
  /// Aucune génération en cours (état initial, et après [abandon]).
  idle,

  /// Requête en vol (`await` du port) — l'anti-double-soumission est actif.
  generating,

  /// Le port a répondu `Right` : le podcast est disponible dans [podcast] et
  /// a été remis au handoff. Rien n'a été écrit par le contrôleur.
  ready,

  /// Le port a échoué (`Left`, ou exception captée) : `lastFailure` porte le
  /// `ZFailure` quand il y en a un, `errorMessage` le message affichable.
  failed,
}

/// Libellés INJECTÉS des messages d'échec NON portés par un `ZFailure`.
///
/// Un `Left` porte déjà son message ; une **exception** n'en porte aucun qui
/// soit présentable. Ce cas-là seulement a besoin d'un libellé, et il est
/// injecté (aucun libellé en dur dans ce paquet — FR-26).
@immutable
class ZPodcastGenerationMessages {
  /// Construit les messages injectés.
  const ZPodcastGenerationMessages({required this.unexpectedError});

  /// Affiché quand le port **lève** (exception captée, convertie en `failed`).
  final String unexpectedError;
}

/// Callback de **handoff** : remet le podcast produit à l'appelant, qui décide
/// de l'écrire (dépôt, store local…). C'est l'UNIQUE canal de sortie du
/// résultat — le contrôleur n'écrit rien lui-même.
typedef ZPodcastGeneratedCallback = void Function(ZStudyPodcast podcast);

/// Contrôleur du flux de génération de podcast.
///
/// Cycle complet : `idle` → `generating` → (`ready` | `failed`). Depuis
/// n'importe quel état, [abandon] revient à `idle` sans rien écrire et périme
/// toute réponse encore en vol.
class ZPodcastGenerationController extends ChangeNotifier {
  /// Construit le contrôleur autour d'un [port] faillible.
  ///
  /// [routeId] est apposé **verbatim** à chaque requête soumise si celle-ci
  /// n'en porte pas déjà une.
  ZPodcastGenerationController({
    required ZPodcastGenerationPort port,
    required this.messages,
    this.onGenerated,
    this.routeId,
  }) : _port = port;

  final ZPodcastGenerationPort _port;

  /// Messages d'échec injectés (i18n).
  final ZPodcastGenerationMessages messages;

  /// Handoff du podcast produit. `null` ⇒ le résultat n'est remis nulle part
  /// (le statut passe quand même à `ready` — aucune écriture fantôme).
  final ZPodcastGeneratedCallback? onGenerated;

  /// Route de génération apposée aux requêtes soumises, ou `null`.
  ///
  /// Transportée **telle quelle** : ce paquet ne la lit pas, ne la valide pas
  /// et n'en dérive aucun transport (invariant AD-12). Une requête qui porte
  /// déjà `routeId` n'est jamais réécrite.
  final String? routeId;

  ZPodcastGenerationStatus _status = ZPodcastGenerationStatus.idle;

  /// Statut courant (AD-2).
  ZPodcastGenerationStatus get status => _status;

  ZStudyPodcast? _podcast;

  /// Podcast produit par la dernière génération réussie, ou `null`.
  ///
  /// Remis à `null` au départ d'une nouvelle génération et par [abandon] :
  /// un résultat ne survit jamais à la demande qui le remplace.
  ZStudyPodcast? get podcast => _podcast;

  ZFailure? _lastFailure;

  /// Dernier échec TYPÉ du port (`Left`), ou `null`.
  ///
  /// `null` en `failed` signifie que l'échec vient d'une **exception** captée,
  /// pas d'un `Left` : il n'existe alors aucun `ZFailure` à exposer, et le
  /// message affiché est celui injecté. Ne jamais en fabriquer un.
  ZFailure? get lastFailure => _lastFailure;

  String? _errorMessage;

  /// Message lisible du dernier échec (issu du `ZFailure` ou injecté), ou
  /// `null`.
  String? get errorMessage => _errorMessage;

  ZPodcastGenerationRequest? _lastRequest;

  /// Dernière requête EFFECTIVEMENT soumise au port (route apposée incluse) —
  /// préservée après un échec, pour relancer sans re-saisir.
  ZPodcastGenerationRequest? get lastRequest => _lastRequest;

  /// Jeton de fraîcheur MONOTONE. Capturé avant l'`await`, comparé après :
  /// toute réponse dont le jeton ne correspond plus au courant est écartée.
  int _generation = 0;

  bool _disposed = false;

  /// Fraîcheur du podcast détenu au regard de [currentSourceHash].
  ///
  /// Délègue à la fonction pure du kernel : aucun hachage, aucune horloge.
  /// Sans podcast détenu, la réponse est [ZPodcastFreshness.absent].
  ZPodcastFreshness freshnessFor(String? currentSourceHash) => podcastFreshness(
        storedHash: _podcast?.sourceHash,
        currentSourceHash: currentSourceHash,
      );

  /// Lance une génération. Anti-double-soumission : ignorée si déjà
  /// `generating`.
  ///
  /// Ne **lève jamais** : un `Left` devient `failed` (avec `lastFailure`), une
  /// exception devient `failed` (sans `lastFailure`). Dans les deux cas,
  /// **aucun** handoff n'est appelé, donc aucune écriture n'est déclenchée.
  Future<void> generate(ZPodcastGenerationRequest request) async {
    if (_status == ZPodcastGenerationStatus.generating) {
      return; // une seule requête en vol à la fois.
    }
    final int token = ++_generation;
    // Route apposée VERBATIM, et seulement si la requête n'en porte pas déjà
    // une : la valeur de l'appelant prime toujours sur celle du contrôleur.
    final ZPodcastGenerationRequest effective =
        (routeId != null && request.routeId == null)
            ? request.withRouteId(routeId)
            : request;
    _lastRequest = effective;
    _lastFailure = null;
    _errorMessage = null;
    _podcast = null;
    _setStatus(ZPodcastGenerationStatus.generating);

    ZResult<ZStudyPodcast> result;
    try {
      result = await _port.generatePodcast(effective);
    } catch (_) {
      // Le port a LEVÉ : capté ici, converti en `failed` (AD-10). Aucune
      // exception ne remonte à l'appelant, aucune réponse périmée appliquée.
      if (_isStale(token)) return;
      _fail(messages.unexpectedError, null);
      return;
    }

    if (_isStale(token)) return; // réponse tardive/abandonnée ⇒ écartée.

    result.fold(
      (ZFailure failure) => _fail(failure.message, failure),
      (ZStudyPodcast podcast) {
        _podcast = podcast;
        _setStatus(ZPodcastGenerationStatus.ready);
        // Handoff APRÈS la transition : un écouteur réveillé par le `notify`
        // lit déjà `ready` et `podcast`.
        onGenerated?.call(podcast);
      },
    );
  }

  /// Abandonne le flux : retour à `idle`, sans exception et sans écriture. Le
  /// jeton est incrémenté ⇒ toute réponse en vol devient périmée et sera
  /// écartée.
  void abandon() {
    _generation++;
    _podcast = null;
    _errorMessage = null;
    _lastFailure = null;
    _setStatus(ZPodcastGenerationStatus.idle);
  }

  void _fail(String message, ZFailure? failure) {
    _errorMessage = message;
    _lastFailure = failure;
    _setStatus(ZPodcastGenerationStatus.failed);
  }

  bool _isStale(int token) => _disposed || token != _generation;

  void _setStatus(ZPodcastGenerationStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++; // toute réponse en vol devient périmée (aucun notify après).
    super.dispose();
  }
}
