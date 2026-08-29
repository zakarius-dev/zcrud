/// `ZNoteSummaryController` — orchestration du flux de résumé d'une note par
/// IA, au-dessus de `ZNoteSummaryPort`.
///
/// ## Réactivité Flutter-native PURE (AD-2/AD-15)
///
/// `ChangeNotifier` **pur-Flutter** : aucun gestionnaire d'état (ni Riverpod,
/// ni GetX, ni provider). Le statut est une **enum**
/// ([ZNoteSummaryStatus]), jamais une grappe de booléens qui pourrait exprimer
/// un état impossible.
///
/// ## Rien n'est écrit ici (AD-43)
///
/// Le contrôleur n'importe **aucun** dépôt ni store. Le résumé produit sort par
/// **deux handoffs** et par eux seuls : [ZNoteSummaryController.onInsertAtTop]
/// (insertion en tête de la note d'origine) et
/// [ZNoteSummaryController.onCreateNote] (création d'une note nouvelle). C'est
/// l'application qui écrit, par la voie de persistance de son choix. Un `Left`,
/// un résumé vide ou un abandon : **zéro** appel de handoff, donc zéro écriture
/// possible.
///
/// ## Port ASYNCHRONE et FAILLIBLE (AD-10)
///
/// Le port peut **lever**, renvoyer `Left(ZFailure)`, `Right('')` (résumé
/// vide), ou répondre **tard** (surface déjà fermée). Un **jeton de fraîcheur
/// monotone**, capturé avant l'`await` et comparé après, écarte toute réponse
/// périmée : jamais un résumé obsolète appliqué, jamais un `notifyListeners`
/// après `dispose`. Aucune exception ne remonte de [ZNoteSummaryController.generate].
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;

import '../domain/z_note_summary_port.dart';

/// Statut du flux de résumé de note (AD-2 : une enum, jamais des booléens —
/// deux états ne peuvent pas être vrais en même temps).
enum ZNoteSummaryStatus {
  /// Aucun résumé en cours (état initial, et après remise/abandon).
  idle,

  /// Requête en vol (`await` du port) — l'anti-double-soumission est actif.
  summarizing,

  /// Le port a répondu un texte NON vide : il est proposé à la revue, et n'est
  /// encore écrit nulle part.
  reviewing,

  /// Le port a répondu un texte vide : rien à revoir, **rien n'est écrit**.
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
class ZNoteSummaryMessages {
  /// Construit les messages injectés.
  const ZNoteSummaryMessages({
    required this.unexpectedError,
    required this.emptyResult,
  });

  /// Affiché quand le port **lève** (exception captée, convertie en `failed`).
  final String unexpectedError;

  /// Affiché quand le port répond un texte vide (statut `empty`).
  final String emptyResult;
}

/// Callback de **handoff** du résumé : remet le texte à l'appelant, qui décide
/// de l'écrire (insertion dans la note, création d'une note…). C'est l'UNIQUE
/// famille de canaux de sortie — le contrôleur n'écrit rien lui-même.
typedef ZNoteSummaryCallback = void Function(String summary);

/// Contrôleur du flux de résumé de note.
///
/// Cycle complet : `idle` → `summarizing` → (`reviewing` | `empty` | `failed`).
/// Depuis `reviewing`, [insertAtTop] et [createNote] remettent le résumé
/// **verbatim** au handoff correspondant, puis reviennent à `idle`. Depuis
/// n'importe quel état, [abandon] revient à `idle` sans rien remettre.
///
/// Les deux issues sont **exclusives par geste** : chacune ne peut être servie
/// qu'en `reviewing`, et le retour à `idle` qui suit rend un second appel
/// inopérant. Un geste ⇒ au plus un handoff.
class ZNoteSummaryController extends ChangeNotifier {
  /// Construit le contrôleur autour d'un [port] faillible.
  ZNoteSummaryController({
    required ZNoteSummaryPort port,
    required this.messages,
    this.onInsertAtTop,
    this.onCreateNote,
    // Le champ est privé pour qu'aucun appelant ne puisse court-circuiter le
    // contrôleur ; un paramètre nommé ne peut pas l'être, d'où l'affectation
    // par liste d'initialisation. Le lint propose un formel initialisant qui
    // serait ici illégal.
    // ignore: prefer_initializing_formals
  }) : _port = port;

  final ZNoteSummaryPort _port;

  /// Messages d'échec injectés (i18n).
  final ZNoteSummaryMessages messages;

  /// Handoff « insérer en tête de la note ». `null` ⇒ l'issue n'est remise
  /// nulle part (le geste reste alors sans effet observable — aucune écriture
  /// fantôme).
  final ZNoteSummaryCallback? onInsertAtTop;

  /// Handoff « créer une note à partir du résumé ». `null` ⇒ non remise.
  final ZNoteSummaryCallback? onCreateNote;

  ZNoteSummaryStatus _status = ZNoteSummaryStatus.idle;

  /// Statut courant (AD-2).
  ZNoteSummaryStatus get status => _status;

  String _summary = '';

  /// Résumé en cours de revue, **verbatim** tel que rendu par le port (ni
  /// rogné, ni reformaté). Vide hors `reviewing`.
  String get summary => _summary;

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

  ZNoteSummaryRequest? _lastRequest;

  /// Dernière requête EFFECTIVEMENT soumise au port — préservée après un
  /// échec, pour relancer sans re-saisir.
  ZNoteSummaryRequest? get lastRequest => _lastRequest;

  /// Jeton de fraîcheur MONOTONE. Capturé avant l'`await`, comparé après :
  /// toute réponse dont le jeton ne correspond plus au courant est écartée.
  int _generation = 0;

  bool _disposed = false;

  /// Lance un résumé. Anti-double-soumission : ignorée si déjà `summarizing`.
  ///
  /// Ne **lève jamais** : un `Left` devient `failed` (avec `lastFailure`), une
  /// exception devient `failed` (sans `lastFailure`), un texte vide devient
  /// `empty`. Dans les trois cas, **aucun** handoff n'est appelé.
  ///
  /// La vacuité est mesurée sur le texte **débarrassé de ses blancs** : un
  /// résumé fait uniquement d'espaces n'a rien à revoir. Le texte remis aux
  /// handoffs, lui, reste celui du port, **sans rognage**.
  Future<void> generate(ZNoteSummaryRequest request) async {
    if (_status == ZNoteSummaryStatus.summarizing) {
      return; // une seule requête en vol à la fois.
    }
    final token = ++_generation;
    _lastRequest = request;
    _lastFailure = null;
    _errorMessage = null;
    _summary = '';
    _setStatus(ZNoteSummaryStatus.summarizing);

    ZResult<String> result;
    try {
      result = await _port.summarize(request);
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
      (text) {
        if (text.trim().isEmpty) {
          _errorMessage = messages.emptyResult;
          _setStatus(ZNoteSummaryStatus.empty);
          return;
        }
        _summary = text;
        _setStatus(ZNoteSummaryStatus.reviewing);
      },
    );
  }

  /// Issue « insérer en tête » : remet le résumé à [onInsertAtTop], puis
  /// revient à `idle`. No-op hors `reviewing`.
  void insertAtTop() => _hand(onInsertAtTop);

  /// Issue « nouvelle note » : remet le résumé à [onCreateNote], puis revient
  /// à `idle`. No-op hors `reviewing`.
  void createNote() => _hand(onCreateNote);

  /// Abandonne le flux (fermeture de la surface) : retour à `idle`, sans
  /// exception et sans handoff. Le jeton est incrémenté ⇒ toute réponse en vol
  /// devient périmée et sera écartée.
  void abandon() {
    _generation++;
    _reset();
  }

  void _hand(ZNoteSummaryCallback? callback) {
    if (_status != ZNoteSummaryStatus.reviewing) return;
    // Le texte est lu AVANT la remise à zéro : le handoff reçoit le résumé
    // exact, jamais la chaîne vide de l'état au repos.
    final text = _summary;
    callback?.call(text);
    _reset();
  }

  void _reset() {
    _summary = '';
    _errorMessage = null;
    _lastFailure = null;
    _setStatus(ZNoteSummaryStatus.idle);
  }

  void _fail(String message, ZFailure? failure) {
    _errorMessage = message;
    _lastFailure = failure;
    _setStatus(ZNoteSummaryStatus.failed);
  }

  bool _isStale(int token) => _disposed || token != _generation;

  void _setStatus(ZNoteSummaryStatus status) {
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
