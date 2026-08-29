/// `ZMindmapGenerationController` — orchestration du flux de génération de
/// carte mentale par IA, au-dessus de `ZMindmapGenerationPort`.
///
/// ## Réactivité Flutter-native PURE (AD-2/AD-15)
///
/// `ChangeNotifier` **pur-Flutter** : aucun gestionnaire d'état (ni Riverpod,
/// ni GetX, ni provider). Le statut est une **enum**
/// ([ZMindmapGenerationStatus]), jamais une grappe de booléens qui pourrait
/// exprimer un état impossible.
///
/// ## Rien n'est écrit avant validation (AD-43)
///
/// Le contrôleur n'importe **aucun** dépôt ni store : la frontière de commit
/// est le **handoff** [ZMindmapGeneratedCallback], remis à l'appelant au
/// moment de la validation — jamais une écriture de base. Un `Left` du port,
/// un résultat vide, une feuille abandonnée : **zéro** appel de handoff, donc
/// zéro écriture possible.
///
/// ## Port ASYNCHRONE et FAILLIBLE (AD-10)
///
/// Le port peut **lever**, renvoyer `Left(ZFailure)`, `Right([])` (aucun
/// nœud), ou répondre **tard** (surface déjà fermée). Un **jeton de fraîcheur
/// monotone**, capturé avant l'`await` et comparé après, écarte toute réponse
/// périmée : jamais un lot obsolète appliqué, jamais un `notifyListeners`
/// après `dispose`. Aucune exception ne remonte de [generate].
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;
import 'package:zcrud_mindmap/zcrud_mindmap.dart' show ZMindmap, ZMindmapNode;

import '../domain/z_mindmap_generation_port.dart';

/// Statut du flux de génération de carte mentale (AD-2 : une enum, jamais des
/// booléens — deux états ne peuvent pas être vrais en même temps).
enum ZMindmapGenerationStatus {
  /// Aucune génération en cours (état initial, et après validation/abandon).
  idle,

  /// Requête en vol (`await` du port) — l'anti-double-soumission est actif.
  generating,

  /// Le port a répondu une forêt NON vide : elle est proposée à la revue,
  /// éditable, et n'est encore écrite nulle part.
  reviewing,

  /// Le port a répondu `Right(<vide>)` : rien à revoir, **rien n'est écrit**.
  /// Distinct de [failed] — ce n'est pas un échec, c'est un résultat vide.
  empty,

  /// Le port a échoué (`Left`, ou exception captée) : [ZFailure] disponible
  /// dans `lastFailure`, saisie préservée, surface utilisable.
  failed,
}

/// Libellés INJECTÉS des messages d'échec NON portés par un `ZFailure`.
///
/// Un `Left` porte déjà son message ; une **exception** n'en porte aucun qui
/// soit présentable, et un résultat vide n'est pas un échec du tout. Ces deux
/// cas-là seulement ont besoin d'un libellé, et il est injecté (aucun libellé
/// en dur dans ce paquet — FR-26).
@immutable
class ZMindmapGenerationMessages {
  /// Construit les messages injectés.
  const ZMindmapGenerationMessages({
    required this.unexpectedError,
    required this.emptyResult,
  });

  /// Affiché quand le port **lève** (exception captée, convertie en `failed`).
  final String unexpectedError;

  /// Affiché quand le port répond une forêt vide (statut `empty`).
  final String emptyResult;
}

/// Callback de **handoff** : remet la carte matérialisée à l'appelant, qui
/// décide de l'écrire (dépôt, store local…). C'est l'UNIQUE canal de sortie du
/// résultat — le contrôleur n'écrit rien lui-même.
typedef ZMindmapGeneratedCallback = void Function(ZMindmap mindmap);

/// Contrôleur du flux de génération de carte mentale.
///
/// Cycle complet : `idle` → `generating` → (`reviewing` | `empty` | `failed`).
/// Depuis `reviewing`, [confirm] matérialise un [ZMindmap] **éphémère**
/// (`id` vide — l'identité est posée par la couche de persistance de l'hôte)
/// dans le dossier [folderId], et le remet au handoff. Depuis n'importe quel
/// état, [abandon] revient à `idle` sans rien écrire.
class ZMindmapGenerationController extends ChangeNotifier {
  /// Construit le contrôleur autour d'un [port] faillible.
  ///
  /// [folderId] est le dossier dans lequel la carte validée sera matérialisée
  /// (clé opaque). [routeId] est apposé **verbatim** à chaque requête soumise
  /// si celle-ci n'en porte pas déjà une.
  ZMindmapGenerationController({
    required ZMindmapGenerationPort port,
    required this.folderId,
    required this.messages,
    this.onGenerated,
    this.title = '',
    this.routeId,
  }) : _port = port;

  final ZMindmapGenerationPort _port;

  /// Dossier porteur de la carte validée (clé opaque, jamais interprétée).
  final String folderId;

  /// Messages d'échec injectés (i18n).
  final ZMindmapGenerationMessages messages;

  /// Handoff de la carte matérialisée. `null` ⇒ le résultat n'est remis nulle
  /// part (la validation reste alors sans effet observable — aucune écriture
  /// fantôme).
  final ZMindmapGeneratedCallback? onGenerated;

  /// Titre de la carte matérialisée (vide ⇒ défaut d'affichage de `ZMindmap`).
  final String title;

  /// Route de génération apposée aux requêtes soumises, ou `null`.
  ///
  /// Transportée **telle quelle** : ce paquet ne la lit pas, ne la valide pas
  /// et n'en dérive aucun transport (invariant AD-12). Une requête qui porte
  /// déjà `routeId` n'est jamais réécrite.
  final String? routeId;

  ZMindmapGenerationStatus _status = ZMindmapGenerationStatus.idle;

  /// Statut courant (AD-2).
  ZMindmapGenerationStatus get status => _status;

  List<ZMindmapNode> _nodes = const <ZMindmapNode>[];

  /// Forêt en cours de revue (vue non modifiable). Vide hors `reviewing`.
  List<ZMindmapNode> get nodes => List<ZMindmapNode>.unmodifiable(_nodes);

  ZFailure? _lastFailure;

  /// Dernier échec TYPÉ du port (`Left`), ou `null`.
  ///
  /// `null` en `failed` signifie que l'échec vient d'une **exception** captée,
  /// pas d'un `Left` : il n'existe alors aucun `ZFailure` à exposer, et le
  /// message affiché est celui injecté. Ne jamais en fabriquer un.
  ZFailure? get lastFailure => _lastFailure;

  String? _errorMessage;

  /// Message lisible du dernier échec (issu du `ZFailure` ou injecté), ou
  /// `null`. En statut `empty`, porte `messages.emptyResult`.
  String? get errorMessage => _errorMessage;

  ZMindmapGenerationRequest? _lastRequest;

  /// Dernière requête EFFECTIVEMENT soumise au port (route apposée incluse) —
  /// préservée après un échec, pour relancer sans re-saisir.
  ZMindmapGenerationRequest? get lastRequest => _lastRequest;

  /// Jeton de fraîcheur MONOTONE. Capturé avant l'`await`, comparé après :
  /// toute réponse dont le jeton ne correspond plus au courant est écartée.
  int _generation = 0;

  bool _disposed = false;

  /// Lance une génération. Anti-double-soumission : ignorée si déjà
  /// `generating`.
  ///
  /// Ne **lève jamais** : un `Left` devient `failed` (avec `lastFailure`), une
  /// exception devient `failed` (sans `lastFailure`), une forêt vide devient
  /// `empty`. Dans les trois cas, **aucune** écriture n'est déclenchée.
  Future<void> generate(ZMindmapGenerationRequest request) async {
    if (_status == ZMindmapGenerationStatus.generating) {
      return; // une seule requête en vol à la fois.
    }
    final token = ++_generation;
    // Route apposée VERBATIM, et seulement si la requête n'en porte pas déjà
    // une : la valeur de l'appelant prime toujours sur celle du contrôleur.
    final effective =
        (routeId != null && request.routeId == null) ? request.withRouteId(routeId) : request;
    _lastRequest = effective;
    _lastFailure = null;
    _errorMessage = null;
    _nodes = const <ZMindmapNode>[];
    _setStatus(ZMindmapGenerationStatus.generating);

    ZResult<List<ZMindmapNode>> result;
    try {
      result = await _port.generateMindmap(effective);
    } catch (_) {
      // Le port a LEVÉ : capté ici, converti en `failed` (AD-10). Aucune
      // exception ne remonte à l'appelant, aucune réponse périmée appliquée.
      if (_isStale(token)) return;
      _fail(messages.unexpectedError, null);
      return;
    }

    if (_isStale(token)) return; // réponse tardive/abandonnée ⇒ écartée.

    result.fold(
      (failure) => _fail(failure.message, failure),
      (nodes) {
        if (nodes.isEmpty) {
          _errorMessage = messages.emptyResult;
          _setStatus(ZMindmapGenerationStatus.empty);
          return;
        }
        _nodes = List<ZMindmapNode>.unmodifiable(nodes);
        _setStatus(ZMindmapGenerationStatus.reviewing);
      },
    );
  }

  /// Valide la revue : matérialise la forêt [reviewed] en [ZMindmap] éphémère
  /// et la remet au handoff. No-op hors `reviewing`.
  ///
  /// C'est **[reviewed]** qui est matérialisée, jamais la forêt d'origine : ce
  /// que l'utilisateur a édité pendant la revue est exactement ce qui part à
  /// l'écriture. La carte remise porte un `id` **vide** (entité éphémère) et
  /// le [folderId] du contrôleur.
  void confirm(List<ZMindmapNode> reviewed) {
    if (_status != ZMindmapGenerationStatus.reviewing) return;
    final mindmap = ZMindmap(
      id: '', // aucune identité fabriquée ici : la persistance la pose.
      folderId: folderId,
      title: title,
      nodes: reviewed,
    );
    onGenerated?.call(mindmap);
    _reset();
  }

  /// Abandonne le flux (fermeture de la surface) : retour à `idle`, sans
  /// exception et sans écriture. Le jeton est incrémenté ⇒ toute réponse en
  /// vol devient périmée et sera écartée.
  void abandon() {
    _generation++;
    _reset();
  }

  void _reset() {
    _nodes = const <ZMindmapNode>[];
    _errorMessage = null;
    _lastFailure = null;
    _setStatus(ZMindmapGenerationStatus.idle);
  }

  void _fail(String message, ZFailure? failure) {
    _errorMessage = message;
    _lastFailure = failure;
    _setStatus(ZMindmapGenerationStatus.failed);
  }

  bool _isStale(int token) => _disposed || token != _generation;

  void _setStatus(ZMindmapGenerationStatus status) {
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
