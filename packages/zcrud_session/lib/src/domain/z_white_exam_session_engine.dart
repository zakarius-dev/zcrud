/// Runtime d'EXAMEN BLANC (`ZWhiteExamSessionEngine`) — ES-4.4.
///
/// **Machine à états `setup → running → submitted` + scoring différé, ZÉRO
/// écriture SM-2 PAR CONSTRUCTION (AD-23, D2/D3/D4)** — c'est le CŒUR de cette
/// story. Comme le runtime linéaire (`ZLinearSessionState`, ES-4.3) et
/// contrairement au cycle SRS (`ZStudySessionEngine`, ES-4.2) qui DÉTIENT un
/// seam d'écriture SRS (voie UNIQUE), `ZWhiteExamSessionEngine` ne détient
/// **AUCUN** seam de review/scheduler/store SRS, son constructeur n'accepte
/// **AUCUN** paramètre de review/scheduler, et son corps n'invoque **JAMAIS** de
/// symbole SRS ⇒ il n'existe **aucun point d'écriture SRS atteignable** :
/// l'invariant « zéro écriture SM-2 » est garanti par la **STRUCTURE du type**,
/// pas par une garde runtime (prouvé par le scan de source
/// `z_white_exam_no_srs_test.dart`, AC4a).
///
/// **Machine à états (D2/D3, R6)** — trois phases, transitions AUTORISÉES
/// uniquement : [start] (`setup → running`), [answer] (reste `running`, parcours
/// strictement linéaire, aucune ré-insertion), [submit] (`running →
/// submitted`, fige l'examen et calcule le score). Toute transition ILLÉGALE
/// (double-submit, `answer` hors `running`, `start` hors `setup`, retour arrière
/// `submitted → running`…) **LÈVE `StateError`** — elle ne se tait **JAMAIS**
/// (no-op muet interdit, R6).
///
/// **Classe PURE, zéro gestionnaire d'état (AD-2, objectif produit n°1)** : le
/// runtime `extends ChangeNotifier` (`package:flutter/foundation.dart` SEULE,
/// **aucun** widget), détient un [ZWhiteExamState] **immuable** dédié (value-object
/// propre — jamais un clone de `ZSessionState`, dont la sémantique file/lapse est
/// inadaptée à une machine setup/running/submitted, D8), et mute via des
/// **reducers PURS top-level** ([startExam]/[recordAnswer]/[scoreWhiteExam])
/// suivis d'un `notifyListeners()` **granulaire** (uniquement si l'état change,
/// AC7). **Aucun** `flutter_riverpod`/`get`/`provider` — leur câblage vit dans
/// les bindings (ES-9/ES-10).
///
/// **Scoring différé à la SOUMISSION (D5/D6)** : à [submit], le reducer PUR
/// [scoreWhiteExam] agrège les réponses en un [ZStudySessionResult] (ES-2.7,
/// forme canonique `{mode, total, correct, byQuality}`, RÉUTILISÉ — aucune
/// duplication, AD-4). Le seuil correct/incorrect est le `passThreshold`
/// **RÉUTILISÉ** de `ZSrsConfig` (jamais un `3` littéral, D5). Produire un
/// [ZStudySessionResult] est un **agrégat pur** — jamais une écriture SRS
/// (aucun état de répétition espacée n'est produit). Le scoring est **composable**
/// via le seam PUR [ZExamScoringPort] (défaut [scoreWhiteExam]) : ses entrées sont
/// des qualités + un seuil, sa sortie un résultat — sa signature n'expose AUCUN
/// store/scheduler SRS, donc il ne peut PAS rouvrir la voie SM-2 (D6/AC6).
///
/// **Déterminisme total (D7)** : aucun `DateTime.now()`, aucune horloge. Le
/// qualificatif « minuté » d'un examen blanc est un artefact de PRÉSENTATION
/// piloté par le binding (ES-9/ES-10), qui appelle [submit] à l'échéance — le
/// domaine reste pur et le golden est reproductible bit-à-bit.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import 'z_session_item.dart';

/// Phase de la machine à états d'un examen blanc (D2).
///
/// Enum **NEUF, non persisté** (état runtime — aucun `@ZcrudModel`, aucun
/// codegen). Progression **strictement** ordonnée [setup] → [running] →
/// [submitted], sans retour arrière (toute tentative lève `StateError`, D3).
enum ZWhiteExamPhase {
  /// Examen préparé, non commencé : la file est chargée, aucune réponse encore
  /// enregistrée. Seul [ZWhiteExamSessionEngine.start] est autorisé.
  setup,

  /// Examen en cours : le candidat répond aux cartes une à une
  /// ([ZWhiteExamSessionEngine.answer]) jusqu'à [ZWhiteExamSessionEngine.submit].
  running,

  /// Examen soumis et figé : le score ([ZWhiteExamState.result]) est calculé et
  /// non-`null`. Aucune transition sortante (pas de retour à [running]).
  submitted,
}

/// État **immuable** dédié d'un examen blanc (value-object, D8).
///
/// **NE clone PAS `ZSessionState`** : la sémantique file/ré-insertion/lapse de
/// `ZSessionState` est inadaptée à une machine [setup]/[running]/[submitted]. Cet
/// état porte une [phase] explicite, la file [queue] **inchangée** (parcours
/// strict, aucune ré-insertion), un [cursor] linéaire, la liste des [answers]
/// enregistrées, et le [result] de scoring (non-`null` **uniquement** en phase
/// [ZWhiteExamPhase.submitted]).
///
/// `==`/`hashCode` **profonds** (`listEquals`/`Object.hashAll`) ⇒ le
/// `notifyListeners()` granulaire (AC7) ne se déclenche que sur un changement
/// réel.
@immutable
class ZWhiteExamState {
  /// Construit un état d'examen blanc immuable.
  const ZWhiteExamState({
    required this.phase,
    required this.queue,
    required this.cursor,
    required this.answers,
    this.result,
  });

  /// Phase courante de la machine à états (D2).
  final ZWhiteExamPhase phase;

  /// File des cartes à présenter — **inchangée** durant l'examen (parcours
  /// strictement linéaire, aucune ré-insertion, aucun ré-ordonnancement).
  final List<ZSessionItem> queue;

  /// Curseur linéaire `0 → N` : index de la carte courante (avance d'un cran à
  /// chaque réponse enregistrée).
  final int cursor;

  /// Réponses enregistrées **dans l'ordre de présentation** (qualité SM-2
  /// `0..5`). Sa longueur = nombre de cartes déjà répondues.
  final List<int> answers;

  /// Résultat de scoring, **non-`null` uniquement** en phase
  /// [ZWhiteExamPhase.submitted] (agrégat pur `{mode, total, correct,
  /// byQuality}`, jamais une écriture SRS).
  final ZStudySessionResult? result;

  /// Carte courante, ou `null` si le curseur a dépassé la fin de file.
  ZSessionItem? get current =>
      cursor >= 0 && cursor < queue.length ? queue[cursor] : null;

  /// Nombre de cartes déjà répondues (= longueur de [answers]).
  int get answered => answers.length;

  /// Nombre de cartes restant à présenter (`N − cursor`, borné à `≥ 0`).
  int get remaining => math.max(0, queue.length - cursor);

  /// `true` ssi l'examen est soumis et figé (phase [ZWhiteExamPhase.submitted]).
  bool get isSubmitted => phase == ZWhiteExamPhase.submitted;

  /// Copie modifiée (les champs non fournis sont conservés). [result] ne peut
  /// être que **posé** (jamais effacé) : l'examen ne calcule un score qu'à la
  /// soumission, et ne revient jamais à un état sans score (D3).
  ZWhiteExamState copyWith({
    ZWhiteExamPhase? phase,
    List<ZSessionItem>? queue,
    int? cursor,
    List<int>? answers,
    ZStudySessionResult? result,
  }) =>
      ZWhiteExamState(
        phase: phase ?? this.phase,
        queue: queue ?? this.queue,
        cursor: cursor ?? this.cursor,
        answers: answers ?? this.answers,
        result: result ?? this.result,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZWhiteExamState &&
          runtimeType == other.runtimeType &&
          phase == other.phase &&
          cursor == other.cursor &&
          listEquals(queue, other.queue) &&
          listEquals(answers, other.answers) &&
          result == other.result;

  @override
  int get hashCode => Object.hash(
        phase,
        cursor,
        Object.hashAll(queue),
        Object.hashAll(answers),
        result,
      );

  @override
  String toString() =>
      'ZWhiteExamState(phase: $phase, cursor: $cursor, answered: $answered, '
      'remaining: $remaining, result: $result)';
}

/// Seam de scoring **PUR** d'un examen blanc (D6/AC6).
///
/// Entrées = liste des qualités enregistrées + le seuil `passThreshold` ; sortie
/// = un [ZStudySessionResult]. La signature **n'expose AUCUN** store/scheduler
/// SRS ⇒ un scorer alternatif ne peut PAS écrire d'état de répétition espacée
/// (cohérent AD-23/AC4). Le défaut fourni est [scoreWhiteExam].
typedef ZExamScoringPort = ZStudySessionResult Function(
  List<int> qualities, {
  required int passThreshold,
});

/// Reducer **PUR** : `setup → running` (amorce le parcours). Aucun effet de
/// bord, aucune horloge, aucun symbole SRS.
ZWhiteExamState startExam(ZWhiteExamState state) =>
    state.copyWith(phase: ZWhiteExamPhase.running);

/// Reducer **PUR** : enregistre [quality] pour la carte courante et avance le
/// curseur d'un cran (parcours **strictement linéaire**, aucune ré-insertion,
/// aucun ré-ordonnancement — comme le mode `list`). Aucun effet de bord, aucune
/// horloge, aucun symbole SRS.
ZWhiteExamState recordAnswer(ZWhiteExamState state, int quality) =>
    state.copyWith(
      answers: <int>[...state.answers, quality],
      cursor: state.cursor + 1,
    );

/// Reducer **PUR** de scoring, calculé à la SOUMISSION (D5) — défaut de
/// [ZExamScoringPort].
///
/// - `total` = nombre de réponses présentées (`qualities.length`) ;
/// - `correct` = nombre de réponses `quality >= passThreshold` (frontière
///   **RÉUTILISÉE** de `ZSrsConfig`, jamais un `3` littéral — D5/AC5) ;
/// - `byQuality` = distribution `qualité → compte` (clé = `quality.toString()`).
///
/// Produire un [ZStudySessionResult] est un **agrégat pur** (mode
/// [ZReviewMode.whiteExam]) — jamais une écriture SRS. Déterministe (aucune
/// horloge) ⇒ golden reproductible bit-à-bit.
ZStudySessionResult scoreWhiteExam(
  List<int> qualities, {
  required int passThreshold,
}) {
  final byQuality = <String, int>{};
  var correct = 0;
  for (final quality in qualities) {
    final key = quality.toString();
    byQuality[key] = (byQuality[key] ?? 0) + 1;
    if (quality >= passThreshold) {
      correct += 1;
    }
  }
  return ZStudySessionResult(
    mode: ZReviewMode.whiteExam,
    total: qualities.length,
    correct: correct,
    byQuality: byQuality,
  );
}

/// Runtime d'EXAMEN BLANC : machine à états `setup → running → submitted` avec
/// scoring différé, **sans jamais** écrire d'état SRS (aucun seam/scheduler/store
/// à appeler — AD-23, par construction). Consomme une file **déjà sélectionnée**
/// et produit un [ZStudySessionResult] à la soumission.
class ZWhiteExamSessionEngine extends ChangeNotifier {
  /// Construit le moteur à partir d'une file **déjà sélectionnée** [queue].
  ///
  /// **AUCUN** paramètre de review/scheduler : ce runtime ne sait PAS écrire du
  /// SRS (par construction, AD-23 — contraste voulu avec `ZStudySessionEngine`,
  /// qui DÉTIENT un seam). [config] fournit le **seuil** correct/incorrect
  /// `passThreshold` (RÉUTILISÉ, jamais recopié — D5). [scorer] est le seam de
  /// scoring PUR (défaut [scoreWhiteExam], D6/AC6). L'état initial est en phase
  /// [ZWhiteExamPhase.setup] (curseur 0, aucune réponse, aucun résultat).
  ZWhiteExamSessionEngine({
    required List<ZSessionItem> queue,
    ZSrsConfig config = const ZSrsConfig(),
    ZExamScoringPort scorer = scoreWhiteExam,
  })  :
        // `prefer_initializing_formals` : FAUX POSITIF — les champs sont PRIVÉS
        // (`_config`/`_scorer`) et les paramètres PUBLICS ; `this._config` en
        // paramètre nommé est ILLÉGAL en Dart (PRIVATE_OPTIONAL_PARAMETER).
        // Même cas que `z_study_session_engine.dart` / `z_linear_session_state.dart`.
        // ignore: prefer_initializing_formals
        _config = config,
        // ignore: prefer_initializing_formals
        _scorer = scorer,
        _state = ZWhiteExamState(
          phase: ZWhiteExamPhase.setup,
          queue: List<ZSessionItem>.unmodifiable(queue),
          cursor: 0,
          answers: const <int>[],
          result: null,
        );

  final ZSrsConfig _config;
  final ZExamScoringPort _scorer;
  ZWhiteExamState _state;

  /// État immuable courant (lecture seule).
  ZWhiteExamState get state => _state;

  /// Phase courante de la machine à états.
  ZWhiteExamPhase get phase => _state.phase;

  /// Carte courante, ou `null` si le parcours est terminé.
  ZSessionItem? get current => _state.current;

  /// Nombre de cartes déjà répondues.
  int get answered => _state.answered;

  /// Nombre de cartes restant à présenter.
  int get remaining => _state.remaining;

  /// Résultat de scoring — non-`null` **uniquement** en phase
  /// [ZWhiteExamPhase.submitted].
  ZStudySessionResult? get result => _state.result;

  /// `true` ssi l'examen est soumis et figé.
  bool get isSubmitted => _state.isSubmitted;

  /// Démarre l'examen : `setup → running` (D2).
  ///
  /// **Transition ILLÉGALE hors [ZWhiteExamPhase.setup]** (déjà `running` ou
  /// `submitted`, ce qui interdit le retour arrière `submitted → running`) ⇒
  /// **lève `StateError`** (jamais un no-op muet, R6/AC2).
  void start() {
    if (_state.phase != ZWhiteExamPhase.setup) {
      throw StateError(
        'start() illégal en phase ${_state.phase} : l\'examen ne peut démarrer '
        'que depuis ZWhiteExamPhase.setup (aucun retour arrière possible).',
      );
    }
    _setState(startExam(_state));
  }

  /// Enregistre une réponse de [quality] pour la carte courante et avance
  /// linéairement (D2).
  ///
  /// **Transition ILLÉGALE hors [ZWhiteExamPhase.running]** (avant [start], ou
  /// après [submit]) ⇒ **lève `StateError`** (jamais un no-op muet, R6/AC2).
  void answer(int quality) {
    if (_state.phase != ZWhiteExamPhase.running) {
      throw StateError(
        'answer() illégal en phase ${_state.phase} : on ne peut répondre que '
        'pendant ZWhiteExamPhase.running (après start(), avant submit()).',
      );
    }
    _setState(recordAnswer(_state, quality));
  }

  /// Soumet l'examen : `running → submitted`, fige l'état et **calcule le score**
  /// via le seam [ZExamScoringPort] (D5).
  ///
  /// **Transition ILLÉGALE hors [ZWhiteExamPhase.running]** (avant [start], ou
  /// **double** `submit`) ⇒ **lève `StateError`** (jamais un no-op muet, R6/AC2).
  /// Le seuil correct/incorrect est le `passThreshold` **RÉUTILISÉ** de la config
  /// (jamais un `3` littéral, D5/AC5).
  void submit() {
    if (_state.phase != ZWhiteExamPhase.running) {
      throw StateError(
        'submit() illégal en phase ${_state.phase} : on ne peut soumettre '
        'qu\'un examen en cours (ZWhiteExamPhase.running). Double soumission et '
        'soumission avant start() sont interdites.',
      );
    }
    final result = _scorer(_state.answers, passThreshold: _config.passThreshold);
    _setState(
      _state.copyWith(phase: ZWhiteExamPhase.submitted, result: result),
    );
  }

  /// Remplace l'état et notifie **uniquement** si l'état a réellement changé
  /// (value-object `==` profond) ⇒ zéro notification fantôme (AC7).
  void _setState(ZWhiteExamState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
