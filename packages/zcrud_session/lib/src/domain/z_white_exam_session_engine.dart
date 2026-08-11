/// Runtime d'examen blanc (`ZWhiteExamSessionEngine`).
///
/// Machine à états `setup → running → submitted` avec scoring différé, zéro
/// écriture SM-2 par construction. Comme le runtime linéaire
/// (`ZLinearSessionState`) et contrairement au cycle SRS
/// (`ZStudySessionEngine`, qui détient un seam d'écriture SRS),
/// `ZWhiteExamSessionEngine` ne détient aucun seam de review/scheduler/store
/// SRS, son constructeur n'accepte aucun paramètre de review/scheduler, et
/// son corps n'invoque jamais de symbole SRS. Il n'existe donc aucun point
/// d'écriture SRS atteignable : l'invariant « zéro écriture SM-2 » est
/// garanti par la structure du type, pas par une garde runtime.
///
/// Machine à états — trois phases, transitions autorisées uniquement :
/// [start] (`setup → running`), [answer] (reste `running`, parcours
/// strictement linéaire, aucune ré-insertion), [submit] (`running →
/// submitted`, fige l'examen et calcule le score). Toute transition illégale
/// (double soumission, `answer` hors `running`, `start` hors `setup`, retour
/// arrière `submitted → running`…) lève `StateError` — elle ne se tait
/// jamais silencieusement.
///
/// Classe pure, zéro gestionnaire d'état (invariant AD-2) : le runtime
/// `extends ChangeNotifier` (`package:flutter/foundation.dart` seule, aucun
/// widget), détient un [ZWhiteExamState] immuable dédié — un value-object
/// propre, jamais un clone de `ZSessionState`, dont la sémantique
/// file/lapse est inadaptée à une machine setup/running/submitted — et mute
/// via des reducers purs top-level ([startExam]/[recordAnswer]/
/// [scoreWhiteExam]) suivis d'un `notifyListeners()` granulaire, uniquement
/// si l'état change. Aucun `flutter_riverpod`/`get`/`provider` — leur
/// câblage vit dans les packages de binding.
///
/// Scoring différé à la soumission : à [submit], le reducer pur
/// [scoreWhiteExam] agrège les réponses en un [ZStudySessionResult] (forme
/// canonique `{mode, total, correct, byQuality}`, réutilisée, aucune
/// duplication). Le seuil correct/incorrect est le `passThreshold` réutilisé
/// de `ZSrsConfig` (jamais un littéral en dur). Produire un
/// [ZStudySessionResult] est un agrégat pur — jamais une écriture SRS
/// (aucun état de répétition espacée n'est produit). Le scoring est
/// composable via le seam pur [ZExamScoringPort] (défaut [scoreWhiteExam]) :
/// ses entrées sont des qualités et un seuil, sa sortie un résultat — sa
/// signature n'expose aucun store/scheduler SRS, donc il ne peut pas rouvrir
/// une voie d'écriture SM-2.
///
/// Déterminisme total : aucun `DateTime.now()`, aucune horloge. Le
/// qualificatif « minuté » d'un examen blanc est un artefact de
/// présentation piloté par le binding hôte, qui appelle [submit] à
/// l'échéance — le domaine reste pur et le résultat est reproductible
/// bit-à-bit.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import 'z_session_item.dart';

/// Phase de la machine à états d'un examen blanc.
///
/// Enum non persisté (état runtime — aucun `@ZcrudModel`, aucun codegen).
/// Progression strictement ordonnée [setup] → [running] → [submitted], sans
/// retour arrière (toute tentative lève `StateError`).
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

/// État immuable dédié d'un examen blanc (value-object).
///
/// Ne clone pas `ZSessionState` : la sémantique file/ré-insertion/lapse de
/// `ZSessionState` est inadaptée à une machine [setup]/[running]/[submitted].
/// Cet état porte une [phase] explicite, la file [queue] inchangée (parcours
/// strict, aucune ré-insertion), un [cursor] linéaire, la liste des
/// [answers] enregistrées, et le [result] de scoring (non-`null`
/// uniquement en phase [ZWhiteExamPhase.submitted]).
///
/// `==`/`hashCode` profonds (`listEquals`/`Object.hashAll`) : le
/// `notifyListeners()` granulaire ne se déclenche que sur un changement réel.
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

  /// Phase courante de la machine à états.
  final ZWhiteExamPhase phase;

  /// File des cartes à présenter — inchangée durant l'examen (parcours
  /// strictement linéaire, aucune ré-insertion, aucun ré-ordonnancement).
  final List<ZSessionItem> queue;

  /// Curseur linéaire `0 → N` : index de la carte courante (avance d'un cran
  /// à chaque réponse enregistrée).
  final int cursor;

  /// Réponses enregistrées dans l'ordre d'arrivée (qualité SM-2 `0..5`),
  /// c'est-à-dire l'ordre des appels à [ZWhiteExamSessionEngine.answer]. Sa
  /// longueur est le nombre de cartes déjà répondues.
  ///
  /// `answers[i]` ne désigne pas `queue[i]` — les deux ordres ne coïncident
  /// que sous un hôte strictement linéaire (qui répond dans l'ordre de la
  /// file, sans jamais sauter). Sous tout autre hôte — dont
  /// `ZListSessionView`, qui rend les cartes toutes saisissables
  /// simultanément — cette liste est le multi-ensemble des qualités des
  /// cartes répondues, positionnellement ininterprétable. Voir le contrat
  /// d'hôte détaillé sur [ZWhiteExamSessionEngine.answer] et la contrainte
  /// de commutativité sur [ZExamScoringPort].
  final List<int> answers;

  /// Résultat de scoring, non-`null` uniquement en phase
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

  /// `true` si et seulement si l'examen est soumis et figé (phase
  /// [ZWhiteExamPhase.submitted]).
  bool get isSubmitted => phase == ZWhiteExamPhase.submitted;

  /// Copie modifiée (les champs non fournis sont conservés). [result] ne peut
  /// être que posé, jamais effacé : l'examen ne calcule un score qu'à la
  /// soumission, et ne revient jamais à un état sans score.
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

/// Seam de scoring pur d'un examen blanc.
///
/// Entrées : la liste des qualités enregistrées et le seuil `passThreshold` ;
/// sortie : un [ZStudySessionResult]. La signature n'expose aucun
/// store/scheduler SRS, donc un scorer alternatif ne peut pas écrire d'état
/// de répétition espacée. Le défaut fourni est [scoreWhiteExam].
///
/// ## Contrat : un scorer doit être commutatif
///
/// [qualities] est `ZWhiteExamState.answers`, dont l'ordre est celui des
/// appels à [ZWhiteExamSessionEngine.answer] — c'est-à-dire le rang
/// d'arrivée des réponses, pas l'ordre de [ZWhiteExamSessionEngine.queue].
/// Ces deux ordres ne coïncident que si l'hôte répond dans l'ordre de la
/// file sans jamais sauter (voir le contrat d'hôte sur
/// [ZWhiteExamSessionEngine.answer]).
///
/// `qualities[i]` ne désigne donc pas `queue[i]`. Un scorer positionnel —
/// par exemple « la question 1 vaut double », qui lirait `qualities[0]` en
/// croyant tenir `queue[0]` — noterait la mauvaise question sous saisie
/// désordonnée ou avec sauts : une note fausse pour l'apprenant, sans aucune
/// exception. Ce seam est public : la contrainte doit être lue comme une
/// précondition d'implémentation, pas comme un détail.
///
/// Seule une fonction commutative de [qualities] est admissible (un
/// comptage ou un agrégat insensible à la permutation), tant que le moteur
/// reste strictement linéaire. [scoreWhiteExam] l'est.
///
/// Rendre `qualities[i]` interprétable positionnellement exigerait de faire
/// porter l'index de la carte au moteur (`answer({index, quality})`) : ce
/// serait un changement de contrat du domaine, hors périmètre de ce port.
typedef ZExamScoringPort = ZStudySessionResult Function(
  List<int> qualities, {
  required int passThreshold,
});

/// Reducer pur : `setup → running` (amorce le parcours). Aucun effet de
/// bord, aucune horloge, aucun symbole SRS.
ZWhiteExamState startExam(ZWhiteExamState state) =>
    state.copyWith(phase: ZWhiteExamPhase.running);

/// Reducer pur : enregistre [quality] pour la carte courante et avance le
/// curseur d'un cran (parcours strictement linéaire, aucune ré-insertion,
/// aucun ré-ordonnancement — comme le mode `list`). Aucun effet de bord,
/// aucune horloge, aucun symbole SRS.
ZWhiteExamState recordAnswer(ZWhiteExamState state, int quality) =>
    state.copyWith(
      answers: <int>[...state.answers, quality],
      cursor: state.cursor + 1,
    );

/// Reducer pur de scoring, calculé à la soumission — défaut de
/// [ZExamScoringPort].
///
/// - `total` = nombre de réponses présentées (`qualities.length`) ;
/// - `correct` = nombre de réponses `quality >= passThreshold` (frontière
///   réutilisée de `ZSrsConfig`, jamais un littéral en dur) ;
/// - `byQuality` = distribution `qualité → compte` (clé = `quality.toString()`).
///
/// Produire un [ZStudySessionResult] est un agrégat pur (mode
/// [ZReviewMode.whiteExam]) — jamais une écriture SRS. Déterministe (aucune
/// horloge), donc reproductible bit-à-bit.
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

/// Runtime d'examen blanc : machine à états `setup → running → submitted`
/// avec scoring différé, sans jamais écrire d'état SRS (aucun
/// seam/scheduler/store à appeler, par construction). Consomme une file
/// déjà sélectionnée et produit un [ZStudySessionResult] à la soumission.
class ZWhiteExamSessionEngine extends ChangeNotifier {
  /// Construit le moteur à partir d'une file déjà sélectionnée [queue].
  ///
  /// Aucun paramètre de review/scheduler : ce runtime ne sait pas écrire du
  /// SRS, par construction — contraste voulu avec `ZStudySessionEngine`, qui
  /// détient un seam. [config] fournit le seuil correct/incorrect
  /// `passThreshold` (réutilisé, jamais recopié). [scorer] est le seam de
  /// scoring pur (défaut [scoreWhiteExam]). L'état initial est en phase
  /// [ZWhiteExamPhase.setup] (curseur 0, aucune réponse, aucun résultat).
  ZWhiteExamSessionEngine({
    required List<ZSessionItem> queue,
    ZSrsConfig config = const ZSrsConfig(),
    ZExamScoringPort scorer = scoreWhiteExam,
  })  :
        // `prefer_initializing_formals` : faux positif — les champs sont
        // privés (`_config`/`_scorer`) et les paramètres publics ;
        // `this._config` en paramètre nommé est illégal en Dart
        // (PRIVATE_OPTIONAL_PARAMETER).
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

  /// Résultat de scoring — non-`null` uniquement en phase
  /// [ZWhiteExamPhase.submitted].
  ZStudySessionResult? get result => _state.result;

  /// `true` si et seulement si l'examen est soumis et figé.
  bool get isSubmitted => _state.isSubmitted;

  /// Démarre l'examen : `setup → running`.
  ///
  /// Transition illégale hors [ZWhiteExamPhase.setup] (déjà `running` ou
  /// `submitted`, ce qui interdit le retour arrière `submitted → running`) :
  /// lève `StateError`, jamais un no-op silencieux.
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
  /// linéairement.
  ///
  /// Transition illégale hors [ZWhiteExamPhase.running] (avant [start], ou
  /// après [submit]) : lève `StateError`, jamais un no-op silencieux.
  ///
  /// ## Contrat d'hôte — cette API est positionnelle
  ///
  /// Elle n'a aucun moyen de représenter un saut ou une réponse hors-ordre.
  /// [quality] est enregistrée pour `queue[cursor]` — la carte courante — et
  /// le curseur avance d'un cran. La signature ne porte pas d'index : un
  /// hôte ne peut pas dire « cette qualité appartient à la carte #2 ».
  ///
  /// Un hôte qui laisse l'apprenant répondre dans le désordre ou sauter une
  /// question corrompt [ZWhiteExamState.answers], [ZWhiteExamState.cursor]
  /// et [current] — silencieusement, sans aucune exception. Exemple : Q3
  /// répondue juste (5), puis Q1 fausse (0), Q2 sautée. Le résultat est
  /// `answers == [5, 0]`, `cursor == 2`, `current == Q3` — le moteur croit
  /// alors que `queue[0]` (Q1) vaut 5 (c'est la note de Q3), que `queue[1]`
  /// (Q2) vaut 0 (elle n'a jamais été répondue), et Q3 n'apparaît nulle
  /// part. Les trois attributions sont fausses.
  ///
  /// Ce que `answers` est réellement, dès qu'un hôte autorise le saut ou le
  /// désordre : le multi-ensemble des qualités des cartes répondues,
  /// positionnellement ininterprétable. Deux conséquences :
  ///
  /// 1. seul un scorer commutatif est admissible (voir [ZExamScoringPort]) ;
  /// 2. [current]/[remaining]/[cursor] ne sont fiables que sous un hôte
  ///    strictement linéaire.
  ///
  /// `ZListSessionView` rend les cartes simultanément et toutes
  /// saisissables : son hôte est donc non linéaire par conception. Il
  /// n'exploite en conséquence que l'agrégat commutatif ([result]) et sa
  /// propre correspondance indexée par position — jamais
  /// `answers`/`current`/`cursor`. Aligner ces derniers exigerait
  /// `answer({index, quality})`, un changement de contrat du domaine hors
  /// périmètre de ce port.
  void answer(int quality) {
    if (_state.phase != ZWhiteExamPhase.running) {
      throw StateError(
        'answer() illégal en phase ${_state.phase} : on ne peut répondre que '
        'pendant ZWhiteExamPhase.running (après start(), avant submit()).',
      );
    }
    _setState(recordAnswer(_state, quality));
  }

  /// Soumet l'examen : `running → submitted`, fige l'état et calcule le
  /// score via le seam [ZExamScoringPort].
  ///
  /// Transition illégale hors [ZWhiteExamPhase.running] (avant [start], ou
  /// double soumission) : lève `StateError`, jamais un no-op silencieux.
  /// Le seuil correct/incorrect est le `passThreshold` réutilisé de la
  /// config (jamais un littéral en dur).
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

  /// Remplace l'état et notifie uniquement si l'état a réellement changé
  /// (value-object `==` profond) — zéro notification fantôme.
  void _setState(ZWhiteExamState next) {
    if (next == _state) return;
    _state = next;
    notifyListeners();
  }
}
