/// Adaptateur de présentation de [ZWhiteExamSessionEngine].
///
/// Le contrôleur ne possède aucune règle d'examen : ses commandes délèguent au
/// moteur et son [state] relaie son état immuable. Son propriétaire est l'hôte,
/// qui le crée une fois avec le moteur et le dispose sans jamais disposer le
/// moteur lui-même.
library;

import 'package:flutter/foundation.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

import 'z_exam_answer.dart';
import 'z_session_item.dart';
import 'z_white_exam_session_engine.dart';
import 'z_white_exam_verdict.dart';

/// Phase de vue, projection totale de la phase du moteur : [setup] avant le
/// démarrage, [running] tant que des questions restent à répondre,
/// [submitted] une fois l'examen soumis et son résultat disponible.
enum ZWhiteExamSessionViewPhase { setup, running, submitted }

/// Projection de lecture de l'état réel du moteur pour la présentation.
///
/// Elle ne calcule aucune règle : les compteurs, la question et le résultat
/// sont lus tels quels depuis [ZWhiteExamState].
@immutable
class ZWhiteExamSessionViewState {
  /// Construit une projection pour la présentation.
  const ZWhiteExamSessionViewState({
    required this.phase,
    required this.current,
    required this.answered,
    required this.remaining,
    required this.result,
    this.verdict,
    this.answers = const <int, ZExamAnswer>{},
    this.marked = const <int>{},
    this.total = 0,
    this.answeredCount = 0,
    this.unansweredCount = 0,
  });

  /// Phase projetée du moteur.
  final ZWhiteExamSessionViewPhase phase;

  /// Question courante du moteur, si le parcours n'est pas terminé.
  final ZSessionItem? current;

  /// Nombre de réponses enregistré par le moteur.
  final int answered;

  /// Nombre de questions restantes calculé par le moteur.
  final int remaining;

  /// Résultat produit à la soumission par le moteur.
  final ZStudySessionResult? result;

  /// Verdict de réussite relayé du moteur, ou `null` s'il n'y en a aucun.
  ///
  /// `null` tant que l'application n'a déclaré aucun taux de réussite, et
  /// `null` avant la soumission. Comme le reste de cette projection, il est
  /// **lu** du moteur : rien n'est recalculé ici.
  final ZWhiteExamVerdict? verdict;

  /// Réponses rangées sous l'index de leur question.
  ///
  /// Projection de l'état par index du moteur : `answers[i]` désigne bien la
  /// question de rang `i`, quel que soit l'ordre de saisie. Vide tant que
  /// l'examen n'a reçu aucune réponse.
  final Map<int, ZExamAnswer> answers;

  /// Index des questions marquées par le candidat, relayés tels quels.
  final Set<int> marked;

  /// Nombre de questions de l'examen, relayé du moteur.
  final int total;

  /// Nombre de questions portant une réponse — donnée ou « je ne sais pas ».
  final int answeredCount;

  /// Nombre de questions sans réponse (`total - answeredCount`).
  final int unansweredCount;

  /// Réponse de la question [index], ou « sans réponse » s'il n'y en a
  /// aucune. Fonction totale : elle ne rend jamais `null`.
  ZExamAnswer answerFor(int index) =>
      answers[index] ?? const ZExamAnswer.unanswered();

  /// La question [index] est-elle marquée ?
  bool isMarkedAt(int index) => marked.contains(index);
}

/// Contrôleur stable consommable par une surface d'examen.
class ZWhiteExamSessionController {
  /// Relie [engine] à une surface de présentation.
  ZWhiteExamSessionController({required ZWhiteExamSessionEngine engine})
    : _engine = engine,
      state = ValueNotifier<ZWhiteExamSessionViewState>(
        _project(engine.state, engine.verdict),
      ) {
    _engine.addListener(_syncState);
  }

  final ZWhiteExamSessionEngine _engine;

  /// Projection de l'état réel du moteur, sans règle métier supplémentaire.
  final ValueNotifier<ZWhiteExamSessionViewState> state;

  /// Démarre l'examen en déléguant au moteur.
  void start() => _engine.start();

  /// Enregistre [quality] en déléguant au moteur.
  void answer(int quality) => _engine.answer(quality);

  /// Enregistre [quality] pour la question [index] en déléguant au moteur.
  void answerAt(int index, int quality) => _engine.answerAt(index, quality);

  /// Enregistre « je ne sais pas » pour la question [index] en déléguant au
  /// moteur : la question compte répondue et fausse.
  void dontKnowAt(int index) => _engine.dontKnowAt(index);

  /// Bascule le marquage de la question [index] en déléguant au moteur ; la
  /// réponse n'est pas touchée.
  void toggleMarkAt(int index) => _engine.toggleMarkAt(index);

  /// Soumet l'examen en déléguant au moteur.
  ///
  /// Avec [countUnansweredAsIncorrect], les questions restées sans réponse
  /// sont comptées fausses (voir `ZWhiteExamSessionEngine.submit`).
  void submit({bool countUnansweredAsIncorrect = false}) =>
      _engine.submit(countUnansweredAsIncorrect: countUnansweredAsIncorrect);

  void _syncState() =>
      state.value = _project(_engine.state, _engine.verdict);

  static ZWhiteExamSessionViewState _project(
    ZWhiteExamState state,
    ZWhiteExamVerdict? verdict,
  ) =>
      ZWhiteExamSessionViewState(
        phase: switch (state.phase) {
          ZWhiteExamPhase.setup => ZWhiteExamSessionViewPhase.setup,
          ZWhiteExamPhase.running => ZWhiteExamSessionViewPhase.running,
          ZWhiteExamPhase.submitted => ZWhiteExamSessionViewPhase.submitted,
        },
        current: state.current,
        answered: state.answered,
        remaining: state.remaining,
        result: state.result,
        verdict: verdict,
        answers: state.answersByIndex,
        marked: state.marked,
        total: state.queue.length,
        answeredCount: state.answeredCount,
        unansweredCount: state.unansweredCount,
      );

  /// Libère l'écoute locale ; le moteur reste la propriété de l'hôte.
  void dispose() {
    _engine.removeListener(_syncState);
    state.dispose();
  }
}
