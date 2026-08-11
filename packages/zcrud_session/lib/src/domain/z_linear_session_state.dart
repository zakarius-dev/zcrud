/// Runtime de session linéaire (`ZLinearSessionState`).
///
/// Zéro écriture SM-2 par construction. Contrairement à
/// `ZStudySessionEngine`, qui détient un seam d'écriture SRS
/// (`ZSessionReviewer`), `ZLinearSessionState` ne détient aucun
/// `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`, son constructeur
/// n'accepte aucun paramètre de review/scheduler, et son corps ne mentionne
/// jamais `apply`/`initial`/`put`/`reviewCard`/`ZRepetitionInfo`. Il n'existe
/// donc aucun point d'appel SRS atteignable : l'invariant « zéro écriture
/// SM-2 » est garanti par la structure du type, pas par une garde runtime.
///
/// Classe pure, zéro gestionnaire d'état (invariant AD-2) : le runtime
/// `extends ChangeNotifier` (`package:flutter/foundation.dart` seule, aucun
/// widget), détient un [ZSessionState] immuable réutilisé du moteur SRS par
/// composition (aucun clone), et mute via des reducers purs top-level
/// ([advanceLinear]/[requeueCramming]) suivis d'un `notifyListeners()`
/// granulaire, uniquement quand l'état change réellement. Aucun
/// `flutter_riverpod`/`get`/`provider` — leur câblage vit dans les packages
/// de binding.
///
/// Deux modes linéaires, toujours sans SRS :
/// - [ZReviewMode.list] — parcours strictement linéaire : le curseur avance
///   de 0 à N sans jamais ré-ordonner ni ré-insérer ; chaque carte parcourue
///   incrémente `reviewed`. La qualité éventuellement fournie est ignorée.
/// - [ZReviewMode.cramming] — parcours linéaire avec re-boucle des ratés : à
///   la réussite (qualité au moins égale au seuil de réussite) la carte est
///   consommée ; au lapse (qualité sous le seuil) elle est retirée puis
///   réinsérée parmi les cartes à venir à l'offset +2 (lapse léger) ou +4
///   (lapse sévère), clampé en fin de file. Les constantes d'offset
///   (`kLapseOffsetSoft`/`kLapseOffsetHard`/`kLapseSoftMaxQuality`) sont
///   réutilisées du moteur SRS, jamais recopiées.
///
/// Le seuil de lapse est le `passThreshold` réutilisé de `ZSrsConfig`,
/// jamais un littéral en dur. Le lire n'est pas une écriture SRS : c'est un
/// simple entier de comparaison. Les reducers sont déterministes (aucune
/// horloge, aucune I/O).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'z_session_item.dart';
import 'z_session_state.dart';
import 'z_study_session_engine.dart'
    show kLapseOffsetHard, kLapseOffsetSoft, kLapseSoftMaxQuality;

/// Reducer pur du mode [ZReviewMode.list] : fait progresser le curseur d'un
/// cran et retourne un nouvel état (aucun effet de bord, aucune horloge,
/// aucune I/O, aucun symbole SRS).
///
/// La file n'est jamais ré-ordonnée ni tronquée : seul [ZSessionState.cursor]
/// avance et [ZSessionState.reviewed] s'incrémente à chaque carte parcourue.
/// Le parcours est complet quand le curseur atteint la fin de file, état
/// renvoyé tel quel en no-op défensif. L'erreur éventuelle de l'état
/// précédent est effacée (transition aboutie).
ZSessionState advanceLinear(ZSessionState state) {
  if (state.cursor >= state.queue.length) {
    return state; // no-op défensif : parcours déjà complet.
  }
  return state.copyWith(
    cursor: state.cursor + 1,
    reviewed: state.reviewed + 1,
    clearError: true,
  );
}

/// Reducer pur du mode [ZReviewMode.cramming] : applique un grade de
/// [quality] à la carte courante de [state] et retourne un nouvel état
/// (aucun effet de bord, aucune horloge, aucune I/O, aucun symbole SRS).
///
/// Le [passThreshold] est injecté (lu de `ZSrsConfig`, jamais codé en dur) :
/// la carte re-boucle si et seulement si `quality < passThreshold`.
///
/// - Lapse (`quality < passThreshold`) : la carte courante est retirée de sa
///   position puis réinsérée parmi les cartes à venir à l'index
///   `cursor + offset - 1` (0-based dans la file post-retrait), clampé à la
///   fin de file — la carte réapparaît comme la Nᵉ carte à venir (N = 2 si
///   `quality ≤ kLapseSoftMaxQuality`, sinon 4). `lapses` est incrémenté (la
///   carte reste comptée dans `remaining`). Aucune écriture SRS.
/// - Réussite (`quality ≥ passThreshold`) : la carte est consommée (retirée,
///   jamais réinsérée). `reviewed` est incrémenté. Aucune écriture SRS.
///
/// Une file déjà complète (aucune carte courante) est renvoyée telle quelle
/// (no-op défensif). L'erreur éventuelle est effacée (transition aboutie).
ZSessionState requeueCramming(
  ZSessionState state,
  int quality, {
  required int passThreshold,
}) {
  if (state.isComplete || state.current == null) {
    return state; // no-op défensif : aucune carte courante.
  }

  final cursor = state.cursor;
  final queue = List<ZSessionItem>.of(state.queue);
  final current = queue.removeAt(cursor);

  final isLapse = quality < passThreshold;
  var reviewed = state.reviewed;
  var lapses = state.lapses;

  if (isLapse) {
    final offset =
        quality <= kLapseSoftMaxQuality ? kLapseOffsetSoft : kLapseOffsetHard;
    // Index de réinsertion parmi les cartes à venir (post-retrait), clampé à la
    // fin de file si moins de `offset` cartes restent à venir.
    final insertIndex = math.min(cursor + offset - 1, queue.length);
    queue.insert(insertIndex, current);
    lapses += 1;
  } else {
    reviewed += 1; // carte consommée (non réinsérée).
  }

  final complete = queue.isEmpty;
  final newCursor = complete ? 0 : math.min(cursor, queue.length - 1);

  return ZSessionState(
    queue: List<ZSessionItem>.unmodifiable(queue),
    cursor: newCursor,
    reviewed: reviewed,
    lapses: lapses,
    mode: state.mode,
    error: null,
  );
}

/// Runtime de session linéaire (list/cramming). Consomme une file déjà
/// sélectionnée et la parcourt sans jamais écrire d'état SRS — il n'existe
/// aucun seam/scheduler/store SRS à appeler, par construction.
class ZLinearSessionState extends ChangeNotifier {
  /// Construit le runtime à partir d'une file déjà sélectionnée [queue] et
  /// d'un [mode] linéaire (défaut [ZReviewMode.list]). Le [config] fournit le
  /// seuil de lapse `passThreshold` (réutilisé, jamais recopié), utilisé
  /// uniquement en mode cramming.
  ///
  /// Aucun paramètre de review/scheduler : ce runtime ne sait pas écrire du
  /// SRS, par construction. Un [mode] SRS (`spaced`/`learn`) ou examen
  /// (`whiteExam`/`test`) est refusé par l'[assert].
  ZLinearSessionState({
    required List<ZSessionItem> queue,
    ZReviewMode mode = ZReviewMode.list,
    ZSrsConfig config = const ZSrsConfig(),
  })  : assert(
          mode == ZReviewMode.list || mode == ZReviewMode.cramming,
          'ZLinearSessionState ne supporte que les modes linéaires '
          '(list/cramming) : il ne détient AUCUN seam SRS et ne peut donc pas '
          'servir un mode qui écrirait de la répétition espacée '
          '(spaced/learn/whiteExam/test). Mode reçu : $mode.',
        ),
        // `prefer_initializing_formals` : FAUX POSITIF — le champ est PRIVÉ
        // (`_config`) et le paramètre PUBLIC (`config`) ; `this._config` en
        // paramètre nommé est ILLÉGAL en Dart (PRIVATE_OPTIONAL_PARAMETER).
        // Même cas que `z_study_session_engine.dart`.
        // ignore: prefer_initializing_formals
        _config = config,
        // Amorçage direct via le constructeur public de `ZSessionState` (et
        // non la factory `.initial`) : le runtime linéaire n'emprunte aucun
        // symbole de la famille SRS.
        _state = ZSessionState(
          queue: List<ZSessionItem>.unmodifiable(queue),
          cursor: 0,
          reviewed: 0,
          lapses: 0,
          mode: mode,
          error: null,
        );

  final ZSrsConfig _config;
  ZSessionState _state;

  /// État immuable courant (lecture seule).
  ZSessionState get state => _state;

  /// Carte courante, ou `null` si le parcours est complet.
  ZSessionItem? get current => _state.current;

  /// Nombre de cartes déjà parcourues/consommées.
  int get reviewed => _state.reviewed;

  /// Nombre d'événements de re-boucle (cramming) ; toujours `0` en mode list.
  int get lapses => _state.lapses;

  /// `true` quand le parcours est terminé.
  ///
  /// - list : le curseur a dépassé la dernière carte — la file n'est jamais
  ///   tronquée, donc `queue.isEmpty` ne s'applique pas.
  /// - cramming : la file est vide (toutes les cartes consommées).
  bool get isComplete => _state.mode == ZReviewMode.list
      ? _state.cursor >= _state.queue.length
      : _state.isComplete;

  /// Nombre de cartes restant à parcourir.
  ///
  /// - list : cartes après le curseur (`N − cursor`, borné à `≥ 0`).
  /// - cramming : cartes encore en file (réinsertions comprises).
  int get remaining => _state.mode == ZReviewMode.list
      ? math.max(0, _state.queue.length - _state.cursor)
      : _state.remaining;

  /// Fait progresser le parcours linéaire (mode list) d'une carte : le
  /// curseur avance, `reviewed` est incrémenté, la file reste inchangée.
  /// No-op (aucune notification) quand le parcours est complet.
  void advance() {
    _setState(advanceLinear(_state));
  }

  /// Applique un grade de [quality] à la carte courante.
  ///
  /// - cramming : re-boucle les ratés (offset +2/+4) via [requeueCramming] ;
  ///   la réussite consomme la carte. Aucune écriture SRS.
  /// - list : la [quality] est ignorée (parcours pur) — délègue à
  ///   [advanceLinear], comportement identique à [advance].
  ///
  /// No-op (aucune notification) sur un parcours complet.
  void answer(int quality) {
    final next = _state.mode == ZReviewMode.cramming
        ? requeueCramming(_state, quality, passThreshold: _passThreshold)
        : advanceLinear(_state);
    _setState(next);
  }

  /// Seuil de lapse réutilisé depuis la config SRS (jamais un littéral en
  /// dur) : en cramming, un grade est un lapse si et seulement si
  /// `quality < _passThreshold`.
  int get _passThreshold => _config.passThreshold;

  /// Remplace l'état et notifie uniquement si l'état a réellement changé
  /// (value-object `==` profond) — zéro notification fantôme sur no-op.
  void _setState(ZSessionState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
