/// Runtime de session LINÉAIRE (`ZLinearSessionState`) — ES-4.3.
///
/// **ZÉRO écriture SM-2 PAR CONSTRUCTION (AD-23, D2)** — c'est le CŒUR de cette
/// story. Contrairement à `ZStudySessionEngine` (ES-4.2) qui DÉTIENT un seam
/// d'écriture SRS (`ZSessionReviewer`, voie UNIQUE), `ZLinearSessionState` ne
/// détient **AUCUN** `ZSessionReviewer`/`ZSrsScheduler`/`ZRepetitionStore`, son
/// constructeur n'accepte **AUCUN** paramètre de review/scheduler, et son corps
/// ne mentionne **JAMAIS** `apply`/`initial`/`put`/`reviewCard`/`ZRepetitionInfo`.
/// ⇒ il n'existe **aucun point d'appel SRS atteignable** : l'invariant « zéro
/// écriture SM-2 » est garanti par la **STRUCTURE du type**, pas par une garde
/// runtime. (Prouvé par le scan de source `z_linear_no_srs_test.dart`, AC2a.)
///
/// **Classe PURE, zéro gestionnaire d'état (AD-2, objectif produit n°1)** : le
/// runtime `extends ChangeNotifier` (`package:flutter/foundation.dart` SEULE,
/// **aucun** widget), détient un [ZSessionState] **immuable** réutilisé d'ES-4.2
/// (composition, anti-inertie AD-4 — aucun clone), et mute via des **reducers
/// PURS top-level** ([advanceLinear]/[requeueCramming]) suivis d'un
/// `notifyListeners()` **granulaire** (uniquement si l'état change, AC7).
/// **Aucun** `flutter_riverpod`/`get`/`provider` — leur câblage vit dans les
/// bindings (ES-9/ES-10).
///
/// **Deux modes LINÉAIRES, TOUJOURS sans SRS (D3)** :
/// - [ZReviewMode.list] — parcours **strictement linéaire** : le curseur avance
///   `0 → N` sans jamais ré-ordonner ni ré-insérer ; chaque carte parcourue
///   incrémente `reviewed`. La `quality` éventuelle est **ignorée**.
/// - [ZReviewMode.cramming] — parcours linéaire **avec re-boucle des ratés** : à
///   la **réussite** (`quality ≥ passThreshold`) la carte est **consommée** ; au
///   **lapse** (`quality < passThreshold`) elle est retirée puis **réinsérée
///   parmi les cartes à venir** à l'offset **+2** (`quality ≤
///   kLapseSoftMaxQuality`) ou **+4** (au-delà), clampé en fin de file. Les
///   constantes d'offset (`kLapseOffsetSoft`/`kLapseOffsetHard`/
///   `kLapseSoftMaxQuality`) sont **RÉUTILISÉES** d'ES-4.2 (jamais recopiées).
///
/// Le seuil de lapse est le `passThreshold` **RÉUTILISÉ** de `ZSrsConfig` (jamais
/// un `3` littéral, D5). Le lire n'est **pas** une écriture SRS : c'est un simple
/// `int` de comparaison (aucun `apply`, aucun `ZRepetitionInfo`). Les reducers
/// sont **déterministes** (aucune horloge, aucune I/O, D6).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'z_session_item.dart';
import 'z_session_state.dart';
import 'z_study_session_engine.dart'
    show kLapseOffsetHard, kLapseOffsetSoft, kLapseSoftMaxQuality;

/// Reducer **PUR** du mode [ZReviewMode.list] : fait progresser le curseur d'un
/// cran et **retourne un nouvel état** (aucun effet de bord, aucune horloge,
/// aucune I/O, **aucun** symbole SRS).
///
/// La file n'est **jamais** ré-ordonnée ni tronquée : seul [ZSessionState.cursor]
/// avance (`0 → N`) et [ZSessionState.reviewed] s'incrémente à chaque carte
/// parcourue. Le parcours est **complet** quand le curseur atteint la fin de file
/// (`cursor ≥ queue.length`), état renvoyé **tel quel** en no-op défensif.
/// L'erreur éventuelle de l'état précédent est **effacée** (transition aboutie).
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

/// Reducer **PUR** du mode [ZReviewMode.cramming] : applique un grade de
/// [quality] à la carte courante de [state] et **retourne un nouvel état**
/// (aucun effet de bord, aucune horloge, aucune I/O, **aucun** symbole SRS).
///
/// Le [passThreshold] est **injecté** (lu de `ZSrsConfig`, jamais codé en dur —
/// D5/AC5) : re-boucle ssi `quality < passThreshold`.
///
/// - **Lapse** (`quality < passThreshold`) : la carte courante est retirée de sa
///   position puis réinsérée **parmi les cartes à venir** à l'index
///   `cursor + offset - 1` (0-based dans la file post-retrait), **clampé** à la
///   fin de file ⇒ la carte réapparaît comme la Nᵉ carte à venir (N = 2 si
///   `quality ≤ kLapseSoftMaxQuality`, sinon 4). `lapses += 1` (la carte reste
///   `remaining`). **Aucune** écriture SRS.
/// - **Réussite** (`quality ≥ passThreshold`) : la carte est **consommée**
///   (retirée, jamais réinsérée). `reviewed += 1`. **Aucune** écriture SRS.
///
/// Une file déjà complète (aucune carte courante) est renvoyée **telle quelle**
/// (no-op défensif). L'erreur éventuelle est **effacée** (transition aboutie).
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
    // fin de file si moins de `offset` cartes restent à venir (D3/AC4).
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

/// Runtime de session LINÉAIRE (list/cramming). Consomme une file **déjà
/// sélectionnée** et la parcourt **sans jamais** écrire d'état SRS — il n'existe
/// aucun seam/scheduler/store SRS à appeler (AD-23, par construction).
class ZLinearSessionState extends ChangeNotifier {
  /// Construit le runtime à partir d'une file **déjà sélectionnée** [queue] et
  /// d'un [mode] **linéaire** (défaut [ZReviewMode.list]). Le [config] fournit le
  /// **seuil de lapse** `passThreshold` (RÉUTILISÉ, jamais recopié — D5), utilisé
  /// uniquement en mode cramming.
  ///
  /// **AUCUN** paramètre de review/scheduler : ce runtime ne sait PAS écrire du
  /// SRS (par construction, AD-23). Un [mode] SRS (`spaced`/`learn`) ou examen
  /// (`whiteExam`/`test` → ES-4.4) est **refusé** par l'[assert] (D4/AC6).
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
        // Amorçage direct via le constructeur public de `ZSessionState` (et NON
        // la factory `.initial`) : le runtime linéaire n'emprunte AUCUN symbole
        // de la famille SRS — la garde de source `z_linear_no_srs_test.dart`
        // interdit `.initial(` (= `ZRepetitionInfo.initial`, écriture SM-2) et
        // reste ainsi verte PAR CONSTRUCTION (AD-23, AC2a).
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
  /// - **list** : le curseur a dépassé la dernière carte (`cursor ≥ N`) — la file
  ///   n'est jamais tronquée, donc `queue.isEmpty` ne s'applique pas.
  /// - **cramming** : la file est vide (toutes les cartes consommées).
  bool get isComplete => _state.mode == ZReviewMode.list
      ? _state.cursor >= _state.queue.length
      : _state.isComplete;

  /// Nombre de cartes restant à parcourir.
  ///
  /// - **list** : cartes après le curseur (`N − cursor`, borné à `≥ 0`).
  /// - **cramming** : cartes encore en file (réinsertions comprises).
  int get remaining => _state.mode == ZReviewMode.list
      ? math.max(0, _state.queue.length - _state.cursor)
      : _state.remaining;

  /// Fait progresser le parcours **linéaire** (mode list) d'une carte : le
  /// curseur avance, `reviewed += 1`, la file reste inchangée. No-op (aucune
  /// notification) quand le parcours est complet (AC7).
  void advance() {
    _setState(advanceLinear(_state));
  }

  /// Applique un grade de [quality] à la carte courante.
  ///
  /// - **cramming** : re-boucle les ratés (offset +2/+4) via [requeueCramming] ;
  ///   la réussite consomme la carte. **Aucune** écriture SRS.
  /// - **list** : la [quality] est **ignorée** (parcours pur) — délègue à
  ///   [advanceLinear], comportement identique à [advance].
  ///
  /// No-op (aucune notification) sur un parcours complet (AC7).
  void answer(int quality) {
    final next = _state.mode == ZReviewMode.cramming
        ? requeueCramming(_state, quality, passThreshold: _passThreshold)
        : advanceLinear(_state);
    _setState(next);
  }

  /// Seuil de lapse **RÉUTILISÉ** depuis la config SRS (jamais un `3` littéral,
  /// D5/AC5) : en cramming, un grade est un lapse ssi `quality < _passThreshold`.
  int get _passThreshold => _config.passThreshold;

  /// Remplace l'état et notifie **uniquement** si l'état a réellement changé
  /// (value-object `==` profond) ⇒ zéro notification fantôme sur no-op (AC7).
  void _setState(ZSessionState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
