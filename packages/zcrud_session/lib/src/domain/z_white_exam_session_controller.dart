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

import 'z_session_item.dart';
import 'z_white_exam_session_engine.dart';

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
}

/// Contrôleur stable consommable par une surface d'examen.
class ZWhiteExamSessionController {
  /// Relie [engine] à une surface de présentation.
  ZWhiteExamSessionController({required ZWhiteExamSessionEngine engine})
    : _engine = engine,
      state = ValueNotifier<ZWhiteExamSessionViewState>(
        _project(engine.state),
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

  /// Soumet l'examen en déléguant au moteur.
  void submit() => _engine.submit();

  void _syncState() => state.value = _project(_engine.state);

  static ZWhiteExamSessionViewState _project(ZWhiteExamState state) =>
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
      );

  /// Libère l'écoute locale ; le moteur reste la propriété de l'hôte.
  void dispose() {
    _engine.removeListener(_syncState);
    state.dispose();
  }
}
