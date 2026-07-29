/// Coquille composable d'une session d'examen blanc.
///
/// Le contenu des questions, les corrections et les textes appartiennent à
/// l'hôte. Cette vue consomme exclusivement l'état relayé par
/// [ZWhiteExamSessionController] et ne recalcule ni phase ni score.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/z_session_item.dart';
import '../domain/z_white_exam_session_controller.dart';

/// Contexte réel remis au slot de question.
class ZWhiteExamQuestionContext {
  /// Construit le contexte d'une question courante.
  const ZWhiteExamQuestionContext({
    required this.state,
    required this.item,
    required this.onAnswer,
  });

  /// État immuable relayé par le moteur.
  final ZWhiteExamSessionViewState state;

  /// Identité de la question courante fournie par le moteur.
  final ZSessionItem item;

  /// Délégation de réponse vers le moteur.
  final ValueChanged<int> onAnswer;
}

/// Slot de contenu d'une question.
typedef ZWhiteExamQuestionBuilder =
    Widget Function(BuildContext context, ZWhiteExamQuestionContext question);

/// Slot de correction post-soumission.
typedef ZWhiteExamCorrectionBuilder =
    Widget Function(BuildContext context, ZWhiteExamSessionViewState state);

/// Slot de résultat produit par le moteur.
typedef ZWhiteExamResultBuilder =
    Widget Function(BuildContext context, ZWhiteExamSessionViewState state);

/// Libellés et annonces entièrement fournis par l'hôte.
class ZWhiteExamSessionLabels {
  /// Construit les libellés injectés.
  const ZWhiteExamSessionLabels({
    required this.startAction,
    required this.submitAction,
    required this.timerSemanticsLabel,
    required this.questionSemanticsLabel,
    required this.navigationSemanticsLabel,
  });

  /// Enfant visible du bouton de démarrage.
  final WidgetBuilder startAction;

  /// Enfant visible du bouton de soumission.
  final WidgetBuilder submitAction;

  /// Annonce du minuteur ; les chiffres visibles ne contiennent aucun mot.
  final String Function(Duration remaining) timerSemanticsLabel;

  /// Annonce de la question courante.
  final String Function(ZWhiteExamSessionViewState state)
  questionSemanticsLabel;

  /// Annonce de la région de navigation/actions.
  final String Function(ZWhiteExamSessionViewState state)
  navigationSemanticsLabel;
}

/// Surface d'examen blanc, branchée sur le contrôleur du moteur.
///
/// [controller] et [remaining] sont détenus par l'hôte et gardent donc leur
/// identité au travers des rebuilds parents. Le minuteur écoute seulement
/// [remaining] : son tic ne reconstruit jamais le slot [questionBuilder].
class ZWhiteExamSessionView extends StatelessWidget {
  /// Construit la coquille d'examen.
  const ZWhiteExamSessionView({
    required this.controller,
    required this.remaining,
    required this.labels,
    required this.questionBuilder,
    required this.resultBuilder,
    this.correctionBuilder,
    super.key,
  });

  /// Contrôleur stable qui délègue au moteur réel.
  final ZWhiteExamSessionController controller;

  /// Temps restant, mesuré et mis à jour par l'hôte.
  final ValueListenable<Duration> remaining;

  /// Libellés et annonces injectés.
  final ZWhiteExamSessionLabels labels;

  /// Rendu du contenu de la question courante.
  final ZWhiteExamQuestionBuilder questionBuilder;

  /// Rendu du résultat immuable du moteur après soumission.
  final ZWhiteExamResultBuilder resultBuilder;

  /// Rendu optionnel de correction post-soumission, détenu par l'hôte.
  final ZWhiteExamCorrectionBuilder? correctionBuilder;

  /// Clé du minuteur (testabilité et intégration hôte).
  static const ValueKey<String> timerKey = ValueKey<String>('zWhiteExamTimer');

  /// Clé de la région de question.
  static const ValueKey<String> questionKey = ValueKey<String>(
    'zWhiteExamQuestion',
  );

  /// Clé de la région d'actions/navigation.
  static const ValueKey<String> navigationKey = ValueKey<String>(
    'zWhiteExamNavigation',
  );

  /// Clé de l'alignement directionnel des actions.
  static const ValueKey<String> navigationAlignmentKey = ValueKey<String>(
    'zWhiteExamNavigationAlignment',
  );

  /// Clé de l'action de démarrage.
  static const ValueKey<String> startKey = ValueKey<String>('zWhiteExamStart');

  /// Clé de l'action de soumission.
  static const ValueKey<String> submitKey = ValueKey<String>(
    'zWhiteExamSubmit',
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      _TimerRegion(remaining: remaining, labels: labels),
      ValueListenableBuilder<ZWhiteExamSessionViewState>(
        valueListenable: controller.state,
        builder: (context, state, _) => _ExamStateRegion(
          state: state,
          controller: controller,
          labels: labels,
          questionBuilder: questionBuilder,
          correctionBuilder: correctionBuilder,
          resultBuilder: resultBuilder,
        ),
      ),
    ],
  );
}

class _TimerRegion extends StatelessWidget {
  const _TimerRegion({required this.remaining, required this.labels});

  final ValueListenable<Duration> remaining;
  final ZWhiteExamSessionLabels labels;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: remaining,
    builder: (context, value, _) => Semantics(
      key: ZWhiteExamSessionView.timerKey,
      label: labels.timerSemanticsLabel(value),
      liveRegion: true,
      child: Text(_digits(value), textAlign: TextAlign.start),
    ),
  );

  String _digits(Duration value) {
    final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
    final minutes = totalSeconds ~/ Duration.secondsPerMinute;
    final seconds = totalSeconds.remainder(Duration.secondsPerMinute);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ExamStateRegion extends StatelessWidget {
  const _ExamStateRegion({
    required this.state,
    required this.controller,
    required this.labels,
    required this.questionBuilder,
    required this.correctionBuilder,
    required this.resultBuilder,
  });

  final ZWhiteExamSessionViewState state;
  final ZWhiteExamSessionController controller;
  final ZWhiteExamSessionLabels labels;
  final ZWhiteExamQuestionBuilder questionBuilder;
  final ZWhiteExamCorrectionBuilder? correctionBuilder;
  final ZWhiteExamResultBuilder resultBuilder;

  @override
  Widget build(BuildContext context) => switch (state.phase) {
    ZWhiteExamSessionViewPhase.setup => _Navigation(
      state: state,
      labels: labels,
      child: _ActionButton(
        key: ZWhiteExamSessionView.startKey,
        onPressed: controller.start,
        child: labels.startAction(context),
      ),
    ),
    ZWhiteExamSessionViewPhase.running => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.current case final item?)
          Semantics(
            key: ZWhiteExamSessionView.questionKey,
            label: labels.questionSemanticsLabel(state),
            child: questionBuilder(
              context,
              ZWhiteExamQuestionContext(
                state: state,
                item: item,
                onAnswer: controller.answer,
              ),
            ),
          ),
        _Navigation(
          state: state,
          labels: labels,
          child: _ActionButton(
            key: ZWhiteExamSessionView.submitKey,
            onPressed: controller.submit,
            child: labels.submitAction(context),
          ),
        ),
      ],
    ),
    ZWhiteExamSessionViewPhase.submitted => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (correctionBuilder case final builder?) builder(context, state),
        resultBuilder(context, state),
      ],
    ),
  };
}

class _Navigation extends StatelessWidget {
  const _Navigation({
    required this.state,
    required this.labels,
    required this.child,
  });

  final ZWhiteExamSessionViewState state;
  final ZWhiteExamSessionLabels labels;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ZWhiteExamSessionView.navigationKey,
    label: labels.navigationSemanticsLabel(state),
    child: Align(
      key: ZWhiteExamSessionView.navigationAlignmentKey,
      alignment: AlignmentDirectional.centerEnd,
      child: child,
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    child: TextButton(onPressed: onPressed, child: child),
  );
}
