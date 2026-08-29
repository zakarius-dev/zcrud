/// Runtime de session SRS en cycle (`ZStudySessionEngine`).
///
/// Classe pure, zéro gestionnaire d'état (invariant AD-2) : le moteur
/// `extends ChangeNotifier` (`package:flutter/foundation.dart` seule, aucun
/// widget), détient un [ZSessionState] immuable, et mute via un reducer pur
/// ([reduceGrade]) suivi d'un `notifyListeners()` granulaire, uniquement si
/// l'état change réellement. Aucun `flutter_riverpod`/`get`/`provider` —
/// leur câblage vit dans les packages de binding.
///
/// Écriture SRS = seam injecté, jamais un scheduler/store détenu en champ
/// (invariant AD-9) : le moteur reçoit un [ZSessionReviewer] (= `reviewCard`
/// en production) ; il n'a aucun `ZSrsScheduler`/`ZRepetitionStore` et
/// n'appelle jamais `apply`/`initial`/`put` directement. À chaque [grade],
/// le seam est invoqué exactement une fois, ce qui rend la voie d'écriture
/// SRS unique par construction.
///
/// Cycle et offsets : sur lapse (`quality < passThreshold`, le seuil
/// réutilisé de `ZSrsConfig` — jamais un littéral en dur), la carte ratée
/// est retirée puis réinsérée parmi les cartes à venir à l'offset +2
/// (`quality` 0 ou 1) ou +4 (`quality` 2 ou plus), clampé en fin de file.
/// Sur réussite, la carte est consommée. Le reducer est déterministe
/// (aucune horloge : `now` est simplement relayé au seam).
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zcrud_core/domain.dart'
    show ZDomainFailure, Left, Right, ZFailure, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZRepetitionInfo, ZSrsConfig;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'z_session_item.dart';
import 'z_session_reviewer.dart';
import 'z_session_state.dart';

/// Offset de réinsertion **court** (+2) : la carte ratée réapparaît comme la
/// 2ᵉ carte à venir. Propre à la file de session — jamais une constante SM-2
/// recopiée.
///
/// ⚠️ « Soft » qualifie la **longueur de l'offset**, pas la sévérité de
/// l'échec. Cet offset court sert le lapse le plus **SÉVÈRE**
/// (`quality ≤ [kLapseSoftMaxQuality]`) : une carte totalement ratée doit
/// revenir **plus tôt**, pas plus tard. Le nom est conservé pour la
/// compatibilité de l'API ; la propriété correspondante de
/// [ZLapseRequeuePolicy] s'appelle, elle, `offsetSevere`.
const int kLapseOffsetSoft = 2;

/// Offset de réinsertion **long** (+4) : la carte ratée réapparaît comme la
/// 4ᵉ carte à venir.
///
/// ⚠️ « Hard » qualifie la **longueur de l'offset**, pas la sévérité de
/// l'échec. Cet offset long sert le lapse le plus **LÉGER**
/// (`quality > [kLapseSoftMaxQuality]`, mais sous le seuil de réussite) :
/// une carte presque sue peut attendre davantage. Propriété correspondante
/// de [ZLapseRequeuePolicy] : `offsetLight`.
const int kLapseOffsetHard = 4;

/// Frontière de sévérité : un lapse de `quality ≤ kLapseSoftMaxQuality` est
/// **sévère** et prend l'offset court [kLapseOffsetSoft] ; au-delà, il est
/// **léger** et prend l'offset long [kLapseOffsetHard]. Garantit que `q=0` et
/// `q=1` produisent le même offset (+2) et que `q=2` bascule sur +4.
///
/// Propriété correspondante de [ZLapseRequeuePolicy] : `severeMaxQuality`.
const int kLapseSoftMaxQuality = 1;

/// Politique de réinsertion d'une carte ratée dans la file de session
/// (value-object pur, `const`).
///
/// Deux offsets et une frontière de sévérité, injectables :
///
/// | Propriété | Défaut | Rôle |
/// |---|---|---|
/// | [offsetSevere] | `2` | offset **court** — lapse **sévère** (`quality ≤ [severeMaxQuality]`) |
/// | [offsetLight] | `4` | offset **long** — lapse **léger** (`quality > [severeMaxQuality]`, sous le seuil de réussite) |
/// | [severeMaxQuality] | `1` | dernière qualité considérée comme sévère |
///
/// La sémantique est délibérée et ne doit pas être « corrigée » : **plus
/// l'échec est sévère, plus tôt la carte revient**. Une carte sur laquelle
/// l'apprenant a fait un blanc complet réapparaît au bout de 2 cartes ; une
/// carte presque sue attend 4 cartes.
///
/// Le défaut reproduit exactement le comportement historique : construire un
/// moteur sans politique donne les mêmes positions de réinsertion qu'avant
/// l'existence de ce type.
///
/// Pure et totale (invariant AD-10) : [offsetFor] ne lève jamais, quelle que
/// soit la qualité reçue.
@immutable
class ZLapseRequeuePolicy {
  /// Construit une politique de réinsertion.
  ///
  /// Les défauts sont les constantes historiques du paquet
  /// ([kLapseOffsetSoft] / [kLapseOffsetHard] / [kLapseSoftMaxQuality]) — pas
  /// des littéraux recopiés : une seule source de vérité.
  const ZLapseRequeuePolicy({
    this.offsetSevere = kLapseOffsetSoft,
    this.offsetLight = kLapseOffsetHard,
    this.severeMaxQuality = kLapseSoftMaxQuality,
  });

  /// Offset **court**, appliqué au lapse **sévère** (`quality ≤
  /// [severeMaxQuality]`). La carte réapparaît comme la `offsetSevere`ᵉ carte
  /// à venir.
  final int offsetSevere;

  /// Offset **long**, appliqué au lapse **léger** (`quality >
  /// [severeMaxQuality]`, mais sous le seuil de réussite).
  final int offsetLight;

  /// Dernière qualité considérée comme un échec **sévère**.
  final int severeMaxQuality;

  /// Offset de réinsertion pour une [quality] déjà reconnue comme un lapse.
  ///
  /// Ne juge pas de la réussite : le seuil de réussite (`passThreshold`)
  /// appartient à `ZSrsConfig` et reste évalué par l'appelant.
  int offsetFor(int quality) =>
      quality <= severeMaxQuality ? offsetSevere : offsetLight;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZLapseRequeuePolicy &&
          offsetSevere == other.offsetSevere &&
          offsetLight == other.offsetLight &&
          severeMaxQuality == other.severeMaxQuality;

  @override
  int get hashCode => Object.hash(offsetSevere, offsetLight, severeMaxQuality);

  @override
  String toString() => 'ZLapseRequeuePolicy(offsetSevere: $offsetSevere, '
      'offsetLight: $offsetLight, severeMaxQuality: $severeMaxQuality)';
}

/// Reducer pur de la file de session : applique un grade de [quality] à
/// [state] et retourne un nouvel état (aucun effet de bord, aucune horloge,
/// aucune I/O). Le [passThreshold] est injecté (lu de `ZSrsConfig`, jamais
/// codé en dur) : la carte re-boucle si et seulement si
/// `quality < passThreshold`.
///
/// - Lapse (`quality < passThreshold`) : la carte courante est retirée de sa
///   position puis réinsérée parmi les cartes à venir à l'index
///   `cursor + offset - 1` (0-based dans la file post-retrait), clampé à la
///   fin de file — la carte réapparaît comme la Nᵉ carte à venir, N étant
///   donné par [ZLapseRequeuePolicy.offsetFor] (par défaut 2 sur un échec
///   sévère, 4 sur un échec léger). `lapses` est incrémenté.
/// - Réussite (`quality ≥ passThreshold`) : la carte est consommée (retirée,
///   jamais réinsérée). `reviewed` est incrémenté.
///
/// [policy] est la politique de réinsertion. Son défaut reproduit exactement
/// les positions historiques : l'omettre laisse la file inchangée par rapport
/// au comportement d'avant son existence.
///
/// Une file déjà complète (aucune carte courante) est renvoyée telle quelle
/// (no-op défensif). L'erreur éventuelle de l'état précédent est effacée (la
/// transition a abouti).
ZSessionState reduceGrade(
  ZSessionState state,
  int quality, {
  required int passThreshold,
  ZLapseRequeuePolicy policy = const ZLapseRequeuePolicy(),
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
    // Voie unique de choix d'offset : la politique décide, ce reducer ne
    // recopie plus la comparaison. Le défaut de la politique reprend les
    // constantes historiques, donc l'appelant qui n'injecte rien obtient les
    // mêmes positions qu'avant.
    final offset = policy.offsetFor(quality);
    // Index de réinsertion parmi les cartes à venir (post-retrait), clampé à la
    // fin de file si moins de `offset` cartes restent à venir.
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

/// Moteur de session SRS en cycle. Consomme une file déjà sélectionnée et la
/// fait progresser via [grade], en écrivant l'état SRS uniquement par le
/// seam [ZSessionReviewer] injecté (voie unique, invariant AD-9).
class ZStudySessionEngine extends ChangeNotifier {
  /// Construit le moteur à partir d'une file déjà sélectionnée [queue] et
  /// d'un seam de review [reviewer] (= `reviewCard` en production). Le
  /// [config] fournit le seuil de lapse `passThreshold` (réutilisé, jamais
  /// recopié) ; [mode] est le mode de session (défaut `spaced`) ;
  /// [lapsePolicy] règle les offsets de réinsertion d'une carte ratée (défaut
  /// = comportement historique, positions inchangées).
  ///
  /// Le moteur ne détient aucun `ZSrsScheduler`/`ZRepetitionStore` : seul le
  /// [reviewer] écrit du SRS, par construction.
  ///
  /// Garde de mode — ce moteur écrit du SRS via son [reviewer] : il n'accepte
  /// que les modes dont c'est le régime légitime, `spaced` et `learn`. Un
  /// mode non-SRS (`cramming`/`list`/`test`/`whiteExam`) combiné à un vrai
  /// [reviewer] écrirait du SRS là où le régime l'interdit. Le régime
  /// d'écriture est une propriété du type (`ZStudySessionEngine` = SRS,
  /// `ZLinearSessionState` = linéaire, `ZWhiteExamSessionEngine` = examen),
  /// jamais du [mode] passé en paramètre. Garde strictement symétrique à
  /// celle de `ZLinearSessionState`.
  ///
  /// Aucun `ZSessionReviewer` no-op n'est fourni pour contourner cette
  /// garde : ce serait la porte dérobée qu'elle interdit explicitement — un
  /// mode non-SRS servi par ce moteur, sous couvert d'un reviewer inerte.
  ZStudySessionEngine({
    required List<ZSessionItem> queue,
    required ZSessionReviewer reviewer,
    ZSrsConfig config = const ZSrsConfig(),
    ZReviewMode mode = ZReviewMode.spaced,
    ZLapseRequeuePolicy lapsePolicy = const ZLapseRequeuePolicy(),
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
        // Même faux positif `prefer_initializing_formals` : champ privé,
        // paramètre public.
        // ignore: prefer_initializing_formals
        _lapsePolicy = lapsePolicy,
        _state = ZSessionState.initial(queue, mode: mode);

  final ZSessionReviewer _review;
  final ZSrsConfig _config;
  final ZLapseRequeuePolicy _lapsePolicy;
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
  /// courante, de façon atomique et ordonnée :
  ///
  /// 1. invoque le seam [ZSessionReviewer] exactement une fois (écrit la
  ///    lapse/réussite via la voie unique `reviewCard`) ;
  /// 2. sur succès : mute la file via le reducer pur [reduceGrade] puis
  ///    notifie une seule fois si l'état change ;
  /// 3. sur échec : la file n'est pas mutée, l'échec est exposé (état
  ///    `error` et valeur de retour), jamais avalé silencieusement.
  ///
  /// Sur une session complète (aucune carte courante) : no-op — le seam
  /// n'est pas invoqué, aucune notification n'est émise, un échec de type
  /// domaine signale l'absence de carte.
  ///
  /// `clampQuality` est l'unique voie de clamp. La [quality] est ramenée
  /// dans l'échelle possédée par `ZSrsConfig` avant d'atteindre le seam et
  /// avant le reducer : c'est ici, et nulle part ailleurs, que passe la
  /// notation d'une session SRS. Jamais un `.clamp(0, 5)` littéral : une
  /// application qui tronque son échelle (`ZSrsConfig(minQuality: 1)`)
  /// verrait sinon une note hors de son échelle écrite par la voie légitime.
  /// Défensif (invariant AD-10) : une note aberrante venue d'un port
  /// d'évaluation est clampée, jamais rejetée.
  Future<ZResult<ZRepetitionInfo>> grade(int quality, {DateTime? now}) async {
    final card = _state.current;
    if (card == null) {
      // No-op : aucune carte courante, donc pas de seam, pas de notification.
      return const Left<ZDomainFailure, ZRepetitionInfo>(
        ZDomainFailure('ZStudySessionEngine.grade: aucune carte courante '
            '(session complète)'),
      );
    }

    // Clamp par le propriétaire de l'échelle, avant toute écriture.
    final clamped = _config.clampQuality(quality);

    // Seam d'abord — voie d'écriture SRS unique, exactement une fois par
    // appel à `grade`.
    final result = await _review(
      flashcardId: card.flashcardId,
      folderId: card.folderId,
      quality: clamped,
      now: now,
    );

    return result.fold(
      (failure) {
        // Échec exposé, file inchangée (jamais de réinsertion fantôme).
        _setState(_state.withError(failure));
        return Left<ZFailure, ZRepetitionInfo>(failure);
      },
      (info) {
        // File mutée par le reducer pur, puis notification granulaire. La
        // même valeur clampée que celle écrite par le seam : sinon la file
        // pourrait juger « lapse » une note que le SRS a, lui, reçue en
        // réussite.
        _setState(
          reduceGrade(
            _state,
            clamped,
            passThreshold: _passThreshold,
            policy: _lapsePolicy,
          ),
        );
        return Right<ZFailure, ZRepetitionInfo>(info);
      },
    );
  }

  /// Seuil de lapse réutilisé depuis la config SRS (jamais un littéral en
  /// dur) : un grade est un lapse si et seulement si
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
