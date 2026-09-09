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
/// [start] (`setup → running`), l'enregistrement d'une réponse (reste
/// `running`), [submit] (`running → submitted`, fige l'examen et calcule le
/// score). Toute transition illégale (double soumission, réponse hors
/// `running`, `start` hors `setup`, retour arrière `submitted → running`…)
/// lève `StateError` — elle ne se tait jamais silencieusement.
///
/// Deux voies d'écriture, **exclusives** sur un même examen :
///
/// - le **parcours linéaire** (`answer`), pour une surface qui présente une
///   question à la fois : la note est enregistrée sous le curseur, qui
///   avance d'un cran. Aucune ré-insertion, aucun ré-ordonnancement ;
/// - la **saisie par index** (`answerAt`/`dontKnowAt`), pour une surface qui
///   présente toutes les questions à la fois : la note est rangée sous sa
///   question, dans n'importe quel ordre, et peut être remplacée tant que
///   l'examen n'est pas soumis. Le curseur n'y sert pas.
///
/// Les mêler sur un même examen ferait compter deux fois la même question :
/// `answer` le refuse et lève. Les deux voies alimentent en revanche **le
/// même** scoring — il n'existe qu'un producteur de résultat.
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

import 'z_exam_answer.dart';
import 'z_session_item.dart';
import 'z_white_exam_verdict.dart';

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
    this.answersByIndex = const <int, ZExamAnswer>{},
    this.marked = const <int>{},
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

  /// Réponses rangées sous l'index de leur question dans [queue].
  ///
  /// C'est la lecture **positionnellement interprétable** de l'examen :
  /// contrairement à [answers], `answersByIndex[i]` désigne bien `queue[i]`,
  /// quel que soit l'ordre dans lequel le candidat a répondu.
  ///
  /// Invariant tenu par les reducers : [answers] et cette table portent
  /// toujours le **même multi-ensemble de notes**, et donc la même longueur.
  /// C'est ce qui garantit qu'il n'existe pas deux comptages possibles — le
  /// scoring, commutatif, rend le même résultat quelle que soit la vue par
  /// laquelle les notes ont été enregistrées. Seul l'**ordre** diffère :
  /// [answers] est en ordre d'arrivée tant que le parcours est linéaire, et
  /// en ordre d'index dès qu'une réponse est rangée par index.
  final Map<int, ZExamAnswer> answersByIndex;

  /// Index des questions marquées par le candidat pour y revenir.
  ///
  /// Le marquage est une note de parcours : il n'entre dans aucun calcul de
  /// score et ne change aucune réponse.
  final Set<int> marked;

  /// Carte courante, ou `null` si le curseur a dépassé la fin de file.
  ZSessionItem? get current =>
      cursor >= 0 && cursor < queue.length ? queue[cursor] : null;

  /// Nombre de cartes déjà répondues (= longueur de [answers]).
  int get answered => answers.length;

  /// Nombre de questions **de la file** portant une réponse — donnée ou
  /// « je ne sais pas », jamais « sans réponse ».
  ///
  /// Ne compte que les index de `[0, queue.length)` : une clé hors bornes,
  /// qu'un appelant aurait laissée dans [answersByIndex], ne peut pas faire
  /// avancer la progression affichée au candidat.
  int get answeredCount {
    var count = 0;
    for (var i = 0; i < queue.length; i++) {
      if (answersByIndex[i]?.isAnswered ?? false) count += 1;
    }
    return count;
  }

  /// Nombre de questions de la file **sans réponse**
  /// (`queue.length - answeredCount`, donc jamais négatif).
  int get unansweredCount => queue.length - answeredCount;

  /// Réponse rangée sous [index], ou « sans réponse » s'il n'y en a aucune.
  ///
  /// Fonction totale : elle ne rend jamais `null` et ne lève jamais, y
  /// compris hors des bornes de la file.
  ZExamAnswer answerFor(int index) =>
      answersByIndex[index] ?? const ZExamAnswer.unanswered();

  /// La question [index] est-elle marquée ?
  bool isMarkedAt(int index) => marked.contains(index);

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
    Map<int, ZExamAnswer>? answersByIndex,
    Set<int>? marked,
  }) =>
      ZWhiteExamState(
        phase: phase ?? this.phase,
        queue: queue ?? this.queue,
        cursor: cursor ?? this.cursor,
        answers: answers ?? this.answers,
        result: result ?? this.result,
        answersByIndex: answersByIndex ?? this.answersByIndex,
        marked: marked ?? this.marked,
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
          mapEquals(answersByIndex, other.answersByIndex) &&
          setEquals(marked, other.marked) &&
          result == other.result;

  @override
  int get hashCode => Object.hash(
        phase,
        cursor,
        Object.hashAll(queue),
        Object.hashAll(answers),
        Object.hashAllUnordered(<Object>[
          for (final entry in answersByIndex.entries)
            Object.hash(entry.key, entry.value),
        ]),
        Object.hashAllUnordered(marked),
        result,
      );

  @override
  String toString() =>
      'ZWhiteExamState(phase: $phase, cursor: $cursor, answered: $answered, '
      'remaining: $remaining, marked: ${marked.length}, result: $result)';
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
/// Seule une fonction commutative de [qualities] est admissible : un
/// comptage, ou un agrégat insensible à la permutation. [scoreWhiteExam]
/// l'est.
///
/// La saisie par index ([ZWhiteExamSessionEngine.answerAt]) ne lève **pas**
/// cette contrainte. Elle ordonne bien [qualities] par index — mais une
/// question sans réponse n'y occupe aucune place : sur une file de quatre
/// questions dont la troisième est restée blanche, `qualities[2]` est la note
/// de la **quatrième** question. Un scorer positionnel noterait encore la
/// mauvaise. C'est l'état par index
/// ([ZWhiteExamState.answersByIndex]) qui porte la correspondance
/// question ↔ réponse, jamais cette liste.
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
      answersByIndex: <int, ZExamAnswer>{
        ...state.answersByIndex,
        state.cursor: ZExamAnswer.answered(quality),
      },
      cursor: state.cursor + 1,
    );

/// Notes d'une table de réponses, lues par **index croissant**.
///
/// C'est la projection unique de `{index → réponse}` vers la liste de notes
/// que consomme le scoring : « je ne sais pas » et « sans réponse » y entrent
/// à [incorrectQuality] (voir [ZExamAnswer.scoredQuality]).
List<int> zWhiteExamRecordedQualities(
  Map<int, ZExamAnswer> answersByIndex, {
  required int incorrectQuality,
}) {
  final entries = answersByIndex.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  return <int>[
    for (final entry in entries)
      entry.value.scoredQuality(incorrectQuality: incorrectQuality),
  ];
}

/// Reducer pur : range [answer] sous la question [index], en **remplaçant**
/// toute réponse déjà enregistrée à cet index. Le curseur linéaire n'avance
/// pas — cette écriture n'est pas un parcours.
///
/// La liste `answers` est **reconstruite** depuis la table, par index
/// croissant : les deux vues de l'état restent donc le même multi-ensemble de
/// notes, et le scoring n'a jamais deux entrées possibles. Aucun effet de
/// bord, aucune horloge, aucun symbole SRS.
ZWhiteExamState recordAnswerAt(
  ZWhiteExamState state,
  int index,
  ZExamAnswer answer, {
  required int incorrectQuality,
}) {
  final byIndex = <int, ZExamAnswer>{...state.answersByIndex, index: answer};
  return state.copyWith(
    answers: zWhiteExamRecordedQualities(
      byIndex,
      incorrectQuality: incorrectQuality,
    ),
    answersByIndex: byIndex,
  );
}

/// Reducer pur : bascule le marquage de la question [index], sans toucher à
/// sa réponse. Aucun effet de bord, aucune horloge, aucun symbole SRS.
ZWhiteExamState toggleExamMark(ZWhiteExamState state, int index) {
  final marked = <int>{...state.marked};
  if (!marked.remove(index)) marked.add(index);
  return state.copyWith(marked: marked);
}

/// Notes portées au scoring d'un [state] au moment de la soumission.
///
/// - `includeUnanswered: false` — les notes enregistrées, telles quelles : une
///   question sans réponse ne pèse ni sur `total` ni sur `correct` ;
/// - `includeUnanswered: true` — chaque question de la file sans réponse entre
///   au scoring à [incorrectQuality], donc **comptée fausse** : `total` vaut
///   alors le nombre de questions de la file.
List<int> whiteExamQualities(
  ZWhiteExamState state, {
  required int incorrectQuality,
  required bool includeUnanswered,
}) {
  if (!includeUnanswered) return state.answers;
  final byIndex = <int, ZExamAnswer>{
    for (var i = 0; i < state.queue.length; i++)
      i: const ZExamAnswer.unanswered(),
    ...state.answersByIndex,
  };
  return zWhiteExamRecordedQualities(
    byIndex,
    incorrectQuality: incorrectQuality,
  );
}

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
  ///
  /// [successRatio] est le **taux de réussite exigé par l'application**, dans
  /// `[0, 1]` — la part des réponses correctes à partir de laquelle l'examen
  /// est réussi. C'est une donnée de l'application : le socle n'en porte
  /// aucune valeur. Son défaut `null` signifie « aucun verdict » — [verdict]
  /// reste alors `null` même après [submit], et rien d'autre ne change.
  /// Une valeur hors bornes est ramenée dans `[0, 1]` et `NaN` vaut `null`
  /// (invariant AD-10 : jamais d'exception, jamais un échec inventé).
  ///
  /// [startImmediately] fait naître l'examen en phase
  /// [ZWhiteExamPhase.running] : il n'y a alors **pas de phase de réglage**,
  /// l'épreuve commence à l'ouverture de la surface. C'est le régime d'une
  /// épreuve à chronomètre libre, sans écran de démarrage. La phase [setup]
  /// n'existant plus, [start] devient une transition illégale et lève —
  /// exactement comme un second [start] sur un examen déjà commencé.
  ZWhiteExamSessionEngine({
    required List<ZSessionItem> queue,
    ZSrsConfig config = const ZSrsConfig(),
    ZExamScoringPort scorer = scoreWhiteExam,
    double? successRatio,
    bool startImmediately = false,
  })  : _successRatio = zClampSuccessRatio(successRatio),
        // `prefer_initializing_formals` : faux positif — les champs sont
        // privés (`_config`/`_scorer`) et les paramètres publics ;
        // `this._config` en paramètre nommé est illégal en Dart
        // (PRIVATE_OPTIONAL_PARAMETER).
        // ignore: prefer_initializing_formals
        _config = config,
        // ignore: prefer_initializing_formals
        _scorer = scorer,
        _state = ZWhiteExamState(
          phase: startImmediately
              ? ZWhiteExamPhase.running
              : ZWhiteExamPhase.setup,
          queue: List<ZSessionItem>.unmodifiable(queue),
          cursor: 0,
          answers: const <int>[],
          result: null,
        );

  final ZSrsConfig _config;
  final ZExamScoringPort _scorer;
  final double? _successRatio;
  ZWhiteExamState _state;

  /// État immuable courant (lecture seule).
  ZWhiteExamState get state => _state;

  /// Phase courante de la machine à états.
  ZWhiteExamPhase get phase => _state.phase;

  /// Carte courante, ou `null` si le parcours est terminé.
  ZSessionItem? get current => _state.current;

  /// Nombre de cartes déjà répondues.
  int get answered => _state.answered;

  /// Réponses rangées sous l'index de leur question (lecture seule).
  Map<int, ZExamAnswer> get answersByIndex => _state.answersByIndex;

  /// Index des questions marquées par le candidat (lecture seule).
  Set<int> get marked => _state.marked;

  /// Nombre de questions de la file portant une réponse — donnée ou « je ne
  /// sais pas ».
  int get answeredCount => _state.answeredCount;

  /// Nombre de questions de la file sans réponse.
  int get unansweredCount => _state.unansweredCount;

  /// Nombre de cartes restant à présenter.
  int get remaining => _state.remaining;

  /// Résultat de scoring — non-`null` uniquement en phase
  /// [ZWhiteExamPhase.submitted].
  ZStudySessionResult? get result => _state.result;

  /// `true` si et seulement si l'examen est soumis et figé.
  bool get isSubmitted => _state.isSubmitted;

  /// Taux de réussite exigé, borné à `[0, 1]`, ou `null` si l'application
  /// n'en a déclaré aucun (ou en a déclaré un inexploitable).
  double? get successRatio => _successRatio;

  /// Verdict de réussite, ou `null` tant qu'il n'y a rien à juger.
  ///
  /// `null` sans [successRatio] déclaré, et `null` avant [submit] (aucun
  /// résultat). Le verdict est **dérivé** du résultat par la fonction pure
  /// [zWhiteExamVerdictFor] : le moteur ne le stocke pas et ne le recalcule
  /// selon aucune autre règle.
  ZWhiteExamVerdict? get verdict =>
      zWhiteExamVerdictFor(_state.result, successRatio: _successRatio);

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
  /// Une surface qui présente les questions simultanément est non linéaire
  /// par conception : elle n'emprunte pas cette voie. Elle enregistre par
  /// [answerAt]/[dontKnowAt], qui rangent la note sous sa question et
  /// rendent [ZWhiteExamState.answersByIndex] positionnellement lisible.
  /// `current`/`cursor` n'ont alors pas de sens et ne sont pas consultés.
  void answer(int quality) {
    if (_state.phase != ZWhiteExamPhase.running) {
      throw StateError(
        'answer() illégal en phase ${_state.phase} : on ne peut répondre que '
        'pendant ZWhiteExamPhase.running (après start(), avant submit()).',
      );
    }
    // Les deux voies d'écriture sont EXCLUSIVES sur un même examen : le
    // parcours linéaire enregistre sous le curseur, la saisie par index
    // enregistre sous l'index désigné. Les mêler ferait compter deux fois la
    // question déjà répondue par l'autre voie — une note fausse, sans
    // exception. On refuse, plutôt que de la produire.
    if (_state.answersByIndex.containsKey(_state.cursor)) {
      throw StateError(
        'answer() illégal : la question ${_state.cursor} porte déjà une '
        'réponse rangée par index (answerAt/dontKnowAt). Un même examen '
        'emprunte une seule voie d\'écriture — le parcours linéaire OU la '
        'saisie par index.',
      );
    }
    _setState(recordAnswer(_state, quality));
  }

  /// Enregistre une réponse de [quality] pour la question [index], quel que
  /// soit l'ordre de saisie.
  ///
  /// C'est la voie d'écriture d'une surface qui présente **toutes** les
  /// questions à la fois : la réponse est rangée sous sa question, jamais
  /// sous un rang d'arrivée, donc aucune note ne peut glisser d'une question
  /// à l'autre. Le curseur linéaire n'avance pas.
  ///
  /// Une question déjà répondue est **remplacée** : tant que l'examen n'est
  /// pas soumis, le candidat peut revenir sur sa réponse, et c'est la
  /// dernière enregistrée qui est notée.
  ///
  /// Lève `StateError` hors [ZWhiteExamPhase.running] et `RangeError` si
  /// [index] ne désigne aucune question de la file — jamais un enregistrement
  /// silencieusement perdu.
  void answerAt(int index, int quality) =>
      _recordAt(index, ZExamAnswer.answered(quality), 'answerAt');

  /// Enregistre « je ne sais pas » pour la question [index].
  ///
  /// La question compte **répondue** et **fausse** : elle entre au scoring à
  /// la borne basse de l'échelle déclarée (`ZSrsConfig.minQuality`), qui est
  /// par construction strictement inférieure au seuil de réussite. Mêmes
  /// levées que [answerAt].
  void dontKnowAt(int index) =>
      _recordAt(index, const ZExamAnswer.dontKnow(), 'dontKnowAt');

  /// Bascule le marquage de la question [index] — sans toucher à sa réponse.
  ///
  /// Le marquage est une note de parcours (« y revenir ») : il n'entre dans
  /// aucun calcul de score. Mêmes levées que [answerAt].
  void toggleMarkAt(int index) {
    _requireRunning('toggleMarkAt');
    _requireIndex(index, 'toggleMarkAt');
    _setState(toggleExamMark(_state, index));
  }

  void _recordAt(int index, ZExamAnswer answer, String caller) {
    _requireRunning(caller);
    _requireIndex(index, caller);
    _setState(
      recordAnswerAt(
        _state,
        index,
        answer,
        incorrectQuality: _config.minQuality,
      ),
    );
  }

  void _requireRunning(String caller) {
    if (_state.phase != ZWhiteExamPhase.running) {
      throw StateError(
        '$caller() illégal en phase ${_state.phase} : on ne peut saisir que '
        'pendant ZWhiteExamPhase.running (après start(), avant submit()).',
      );
    }
  }

  void _requireIndex(int index, String caller) {
    if (index < 0 || index >= _state.queue.length) {
      throw RangeError.index(index, _state.queue, '$caller.index');
    }
  }

  /// Soumet l'examen : `running → submitted`, fige l'état et calcule le
  /// score via le seam [ZExamScoringPort].
  ///
  /// Transition illégale hors [ZWhiteExamPhase.running] (avant [start], ou
  /// double soumission) : lève `StateError`, jamais un no-op silencieux.
  /// Le seuil correct/incorrect est le `passThreshold` réutilisé de la
  /// config (jamais un littéral en dur).
  ///
  /// ## Ce que compte la soumission
  ///
  /// Par défaut ([countUnansweredAsIncorrect] à `false`), seules les réponses
  /// enregistrées sont notées : une question sans réponse ne pèse ni sur
  /// `total` ni sur `correct`.
  ///
  /// Avec [countUnansweredAsIncorrect], **toute question de la file sans
  /// réponse compte fausse** — elle entre au scoring à la borne basse de
  /// l'échelle, exactement comme « je ne sais pas » — et `total` vaut alors
  /// le nombre de questions de la file. C'est le régime d'une soumission
  /// incomplète assumée : une copie rendue blanche sur trois questions est
  /// notée sur toutes.
  ///
  /// Le scoring lui-même est le même dans les deux cas : une seule fonction,
  /// une seule frontière correct/incorrect. Seule change la liste de notes
  /// qu'on lui présente.
  void submit({bool countUnansweredAsIncorrect = false}) {
    if (_state.phase != ZWhiteExamPhase.running) {
      throw StateError(
        'submit() illégal en phase ${_state.phase} : on ne peut soumettre '
        'qu\'un examen en cours (ZWhiteExamPhase.running). Double soumission et '
        'soumission avant start() sont interdites.',
      );
    }
    final qualities = whiteExamQualities(
      _state,
      incorrectQuality: _config.minQuality,
      includeUnanswered: countUnansweredAsIncorrect,
    );
    final result = _scorer(qualities, passThreshold: _config.passThreshold);
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
