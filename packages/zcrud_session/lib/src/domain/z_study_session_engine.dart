/// Runtime de session SRS en CYCLE (`ZStudySessionEngine`) — ES-4.2.
///
/// **Classe PURE, zéro gestionnaire d'état (AD-2, objectif produit n°1)** : le
/// moteur `extends ChangeNotifier` (`package:flutter/foundation.dart` SEULE,
/// **aucun** widget), détient un [ZSessionState] **immuable**, et mute via un
/// **reducer PUR** ([reduceGrade]) suivi d'un `notifyListeners()` **granulaire**
/// (uniquement si l'état change réellement, AC8). **Aucun** `flutter_riverpod`/
/// `get`/`provider` — leur câblage vit dans les bindings (ES-9).
///
/// **Écriture SRS = SEAM injecté, JAMAIS un scheduler/store en champ (AD-9/
/// AD-23, D4)** : le moteur reçoit un [ZSessionReviewer] (= `reviewCard` en
/// prod) ; il n'a **aucun** `ZSrsScheduler`/`ZRepetitionStore` et n'appelle
/// **jamais** `apply`/`initial`/`put`. À chaque `grade`, le seam est invoqué
/// **exactement une fois** ⇒ voie d'écriture SRS **unique par construction**.
///
/// **Cycle + offsets (D2/D3)** : sur lapse (`quality < passThreshold`, le SEUIL
/// RÉUTILISÉ de `ZSrsConfig` — jamais un `3` littéral), la carte ratée est
/// retirée puis **réinsérée parmi les cartes à venir** à l'offset **+2** (q ∈
/// {0,1}) ou **+4** (q ≥ 2), clampé en fin de file. Sur réussite, la carte est
/// **consommée**. Le reducer est **déterministe** (aucune horloge : `now` est
/// relayé au seam, D6).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart'
    show DomainFailure, Left, Right, ZFailure, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZRepetitionInfo, ZSrsConfig;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'z_session_item.dart';
import 'z_session_reviewer.dart';
import 'z_session_state.dart';

/// Offset de réinsertion d'un lapse **léger** (`quality ∈ {0, 1}`) : la carte
/// ratée réapparaît comme la **2ᵉ** carte à venir (offset utilisateur **+2**,
/// D2). Propre à la file de SESSION — **jamais** une constante SM-2 recopiée.
const int kLapseOffsetSoft = 2;

/// Offset de réinsertion d'un lapse **dur** (`quality ≥ 2`, en-deçà du seuil) :
/// la carte ratée réapparaît comme la **4ᵉ** carte à venir (offset utilisateur
/// **+4**, D2).
const int kLapseOffsetHard = 4;

/// Frontière léger/dur : un lapse de `quality ≤ kLapseSoftMaxQuality` utilise
/// [kLapseOffsetSoft], au-delà [kLapseOffsetHard]. Garantit que `q=0` et `q=1`
/// produisent **le même** offset (+2) et que `q=2` bascule sur +4 (AC5).
const int kLapseSoftMaxQuality = 1;

/// Reducer **PUR** de la file de session : applique un grade de [quality] à
/// [state] et **retourne un nouvel état** (aucun effet de bord, aucune horloge,
/// aucune I/O). Le [passThreshold] est **injecté** (lu de `ZSrsConfig`, jamais
/// codé en dur — D3/AC4) : re-queue ssi `quality < passThreshold`.
///
/// - **Lapse** (`quality < passThreshold`) : la carte courante est retirée de sa
///   position puis réinsérée **parmi les cartes à venir** à l'index
///   `cursor + offset - 1` (0-based dans la file post-retrait), **clampé** à la
///   fin de file ⇒ la carte réapparaît comme la Nᵉ carte à venir (N = 2 si
///   `quality ≤ kLapseSoftMaxQuality`, sinon 4). `lapses += 1`.
/// - **Réussite** (`quality ≥ passThreshold`) : la carte est **consommée**
///   (retirée, jamais réinsérée). `reviewed += 1`.
///
/// Une file déjà complète (aucune carte courante) est renvoyée **telle quelle**
/// (no-op défensif). L'erreur éventuelle de l'état précédent est **effacée** (la
/// transition a abouti).
ZSessionState reduceGrade(
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
    // fin de file si moins de `offset` cartes restent à venir (D2).
    final insertIndex = math.min(cursor + offset - 1, queue.length);
    queue.insert(insertIndex, current);
    lapses += 1;
  } else {
    reviewed += 1; // carte consommée (non réinsérée).
  }

  final complete = queue.isEmpty;
  // Le curseur reste sur la carte à venir (front de la file) ; clampé au dernier
  // index valide, ou 0 si la file est vide.
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

/// Moteur de session SRS en cycle. Consomme une file **déjà sélectionnée** et la
/// fait progresser via [grade], en écrivant l'état SRS **uniquement** par le
/// seam [ZSessionReviewer] injecté (voie unique, AD-9/AD-23).
class ZStudySessionEngine extends ChangeNotifier {
  /// Construit le moteur à partir d'une file **déjà sélectionnée** [queue] et
  /// d'un seam de review [reviewer] (= `reviewCard` en prod). Le [config]
  /// fournit le **seuil de lapse** `passThreshold` (RÉUTILISÉ, jamais recopié —
  /// D3) ; [mode] est le mode de session (défaut `spaced`).
  ///
  /// Le moteur **NE détient AUCUN** `ZSrsScheduler`/`ZRepetitionStore` : seul le
  /// [reviewer] écrit du SRS (par construction, AD-23).
  ///
  /// **Garde de mode (SU-1, AD-34)** — ce moteur **écrit** du SRS via son
  /// [reviewer] : n'accepter que les modes dont c'est le régime légitime,
  /// `spaced` et `learn`. Un mode non-SRS (`cramming`/`list`/`test`/`whiteExam`)
  /// combiné à un vrai [reviewer] était **constructible** avant SU-1 et aurait
  /// écrit du SRS là où le régime l'interdit — **seul trou résiduel** identifié
  /// par le spine, désormais fermé. Le régime d'écriture est une propriété **du
  /// TYPE** (`ZStudySessionEngine` = SRS, `ZLinearSessionState` = linéaire,
  /// `ZWhiteExamSessionEngine` = examen), jamais du [mode] passé en paramètre.
  /// Garde **strictement symétrique** à celle de `ZLinearSessionState`.
  ///
  /// ⚠️ **Aucun `ZSessionReviewer` no-op n'est fourni** pour contourner cette
  /// garde : ce serait la **porte dérobée** qu'AD-34 interdit explicitement
  /// (un mode non-SRS servi par ce moteur, sous couvert d'un reviewer inerte).
  ZStudySessionEngine({
    required List<ZSessionItem> queue,
    required ZSessionReviewer reviewer,
    ZSrsConfig config = const ZSrsConfig(),
    ZReviewMode mode = ZReviewMode.spaced,
  })  : assert(
          mode == ZReviewMode.spaced || mode == ZReviewMode.learn,
          'ZStudySessionEngine ne supporte que les modes SRS (spaced/learn) : '
          'il DÉTIENT un ZSessionReviewer (voie d\'écriture SRS unique) et '
          'écrirait donc de la répétition espacée pour un mode qui l\'interdit '
          '(cramming/list → ZLinearSessionState ; test/whiteExam → '
          'ZWhiteExamSessionEngine). Mode reçu : $mode.',
        ),
        _review = reviewer,
        // `prefer_initializing_formals` : FAUX POSITIF — le champ est PRIVÉ
        // (`_config`) et le paramètre PUBLIC (`config`) ; `this._config` en
        // paramètre nommé est ILLÉGAL en Dart (PRIVATE_OPTIONAL_PARAMETER).
        // Même cas que `z_flashcard_repository.dart`.
        // ignore: prefer_initializing_formals
        _config = config,
        _state = ZSessionState.initial(queue, mode: mode);

  final ZSessionReviewer _review;
  final ZSrsConfig _config;
  ZSessionState _state;

  /// État immuable courant (lecture seule).
  ZSessionState get state => _state;

  /// Carte courante, ou `null` si la session est complète.
  ZSessionItem? get current => _state.current;

  /// `true` quand la file est vide (toutes cartes consommées).
  bool get isComplete => _state.isComplete;

  /// Nombre de cartes réussies.
  int get reviewed => _state.reviewed;

  /// Nombre d'événements de lapse.
  int get lapses => _state.lapses;

  /// Nombre de cartes restant à réviser.
  int get remaining => _state.remaining;

  /// Applique un grade de [quality] (échelle SuperMemo-2 `0..5`) à la carte
  /// **courante**, de façon **atomique et ordonnée** (D5, AC6) :
  ///
  /// 1. invoque le seam [ZSessionReviewer] **exactement une fois** (écrit la
  ///    lapse/réussite via la voie unique `reviewCard`, AD-9) ;
  /// 2. **sur `Right`** : mute la file via le reducer PUR [reduceGrade] puis
  ///    `notifyListeners()` (une seule fois si l'état change, AC8) ;
  /// 3. **sur `Left`** : la file **n'est PAS** mutée, l'échec est **exposé**
  ///    (état `error` + valeur de retour `Left`), **jamais avalé** (AD-5/R6).
  ///
  /// Sur une session **complète** (aucune carte courante) : **no-op** — le seam
  /// n'est **pas** invoqué, aucune notification n'est émise, un
  /// `Left(DomainFailure)` signale l'absence de carte.
  ///
  /// 🔒 **SU-4 (AC5, AD-46) — `clampQuality` est l'UNIQUE voie de clamp.** La
  /// [quality] est ramenée dans l'échelle **possédée par `ZSrsConfig`** AVANT
  /// d'atteindre le seam ET avant le reducer : c'est ici, et nulle part ailleurs,
  /// que passe la notation d'une session SRS (`ZSrsQualityButtons` → hôte →
  /// `grade`). Jamais un `.clamp(0, 5)` littéral : une app qui tronque son
  /// échelle (`ZSrsConfig(minQuality: 1)`) verrait sinon une note `0` — hors de
  /// SON échelle — écrite par la voie légitime. **Défensif** (AD-10) : une note
  /// aberrante venue d'un port d'évaluation est clampée, jamais rejetée.
  Future<ZResult<ZRepetitionInfo>> grade(int quality, {DateTime? now}) async {
    final card = _state.current;
    if (card == null) {
      // No-op : aucune carte courante ⇒ pas de seam, pas de notification (AC8).
      return const Left<DomainFailure, ZRepetitionInfo>(
        DomainFailure('ZStudySessionEngine.grade: aucune carte courante '
            '(session complète)'),
      );
    }

    // 🔒 AD-46 — clamp par le propriétaire de l'échelle, AVANT toute écriture.
    final clamped = _config.clampQuality(quality);

    // (1) SEAM D'ABORD — voie d'écriture SRS unique, exactement 1× par grade.
    final result = await _review(
      flashcardId: card.flashcardId,
      folderId: card.folderId,
      quality: clamped,
      now: now,
    );

    return result.fold(
      (failure) {
        // (3) Échec exposé, file INCHANGÉE (jamais de réinsertion « fantôme »).
        _setState(_state.withError(failure));
        return Left<ZFailure, ZRepetitionInfo>(failure);
      },
      (info) {
        // (2) File mutée par le reducer PUR, puis notification granulaire.
        // 🔒 La MÊME valeur clampée que celle écrite par le seam : sinon la file
        // pourrait juger « lapse » une note que le SRS a, lui, reçue en réussite.
        _setState(reduceGrade(_state, clamped, passThreshold: _passThreshold));
        return Right<ZFailure, ZRepetitionInfo>(info);
      },
    );
  }

  /// Seuil de lapse **RÉUTILISÉ** depuis la config SRS (jamais un `3` littéral,
  /// D3/AC4) : un grade est un lapse ssi `quality < _passThreshold`.
  int get _passThreshold => _config.passThreshold;

  /// Remplace l'état et notifie **uniquement** si l'état a réellement changé
  /// (value-object `==` profond) ⇒ zéro notification fantôme sur no-op (AC8).
  void _setState(ZSessionState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
