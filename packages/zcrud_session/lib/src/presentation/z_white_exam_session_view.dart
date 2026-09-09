/// Coquille composable d'une session d'examen blanc.
///
/// Le contenu des questions, les corrections et les textes appartiennent à
/// l'hôte. Cette vue consomme exclusivement l'état relayé par
/// [ZWhiteExamSessionController] et ne recalcule ni phase ni score.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show label;

import '../domain/z_exam_answer.dart';
import '../domain/z_session_item.dart';
import '../domain/z_white_exam_session_controller.dart';
import 'z_white_exam_format.dart';

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
    this.startAction,
    this.submitAction,
    this.timerSemanticsLabel,
    this.questionSemanticsLabel,
    this.navigationSemanticsLabel,
    this.elapsedSemanticsLabel,
    this.questionBadgeLabel,
    this.dontKnowAction,
    this.markAction,
    this.markSemanticsLabel,
    this.questionItemSemanticsLabel,
    this.incompleteSubmitLabel,
    this.confirmAction,
    this.cancelAction,
  });

  /// Enfant visible du bouton de démarrage.
  ///
  /// `null` : l'épreuve n'a **pas** de phase de réglage — elle commence à
  /// l'ouverture de la surface, l'hôte ayant fait naître son moteur déjà
  /// commencé. Aucune affordance de démarrage n'est alors rendue.
  final WidgetBuilder? startAction;

  /// Enfant visible du bouton de soumission. `null` : le libellé de
  /// l'application est rendu.
  final WidgetBuilder? submitAction;

  /// Annonce du minuteur ; les chiffres visibles ne contiennent aucun mot.
  /// `null` : l'annonce de l'application est rendue.
  final String Function(Duration remaining)? timerSemanticsLabel;

  /// Annonce de la question courante. `null` : l'annonce de l'application est
  /// rendue.
  final String Function(ZWhiteExamSessionViewState state)?
  questionSemanticsLabel;

  /// Annonce de la région de navigation/actions. `null` : l'annonce de
  /// l'application est rendue.
  final String Function(ZWhiteExamSessionViewState state)?
  navigationSemanticsLabel;

  /// Annonce du chronomètre écoulé ; les chiffres visibles ne contiennent
  /// aucun mot. `null` : aucun chronomètre écoulé n'est rendu.
  final String Function(Duration elapsed)? elapsedSemanticsLabel;

  /// Texte visible du badge d'une question, rang et total en entrée.
  ///
  /// Rend la formule **entière** — c'est ce qui permet à une langue de placer
  /// le rang où elle l'entend. `null` : le badge prend le libellé de
  /// l'application suivi du rang.
  final String Function(int index, int total)? questionBadgeLabel;

  /// Enfant visible du contrôle « je ne sais pas ».
  final WidgetBuilder? dontKnowAction;

  /// Enfant visible du contrôle de marquage, selon qu'il est posé ou non.
  final Widget Function(BuildContext context, bool marked)? markAction;

  /// Annonce du contrôle de marquage d'une question.
  final String Function(int index, bool marked)? markSemanticsLabel;

  /// Annonce d'une question de la liste — rang, réponse et marquage en
  /// entrée, pour que l'annonce dise l'état sans que rien d'autre ne le
  /// répète.
  final String Function(int index, ZExamAnswer answer, bool marked)?
  questionItemSemanticsLabel;

  /// Message de confirmation d'une soumission incomplète, nombre de questions
  /// sans réponse en entrée.
  final String Function(int unanswered)? incompleteSubmitLabel;

  /// Enfant visible du bouton qui confirme la soumission.
  final WidgetBuilder? confirmAction;

  /// Enfant visible du bouton qui annule la soumission.
  final WidgetBuilder? cancelAction;
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
    required this.labels,
    required this.questionBuilder,
    required this.resultBuilder,
    this.remaining,
    this.elapsed,
    this.correctionBuilder,
    super.key,
  });

  /// Contrôleur stable qui délègue au moteur réel.
  final ZWhiteExamSessionController controller;

  /// Temps restant, mesuré et mis à jour par l'hôte.
  ///
  /// `null` : l'épreuve n'a **pas** de minuteur à rebours. Le chronomètre
  /// écoulé ([elapsed]) prend alors sa place s'il est fourni, sinon aucune
  /// région de temps n'est rendue.
  final ValueListenable<Duration>? remaining;

  /// Temps écoulé depuis le début de l'épreuve, mesuré par l'hôte.
  ///
  /// Rendu à la place de [remaining] quand celui-ci est absent, et seulement
  /// si les libellés portent une annonce de chronomètre écoulé : une épreuve
  /// ne montre jamais deux temps à la fois.
  final ValueListenable<Duration>? elapsed;

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

  /// Clé du chronomètre écoulé.
  static const ValueKey<String> elapsedKey = ValueKey<String>(
    'zWhiteExamElapsed',
  );

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
      if (remaining case final countdown?)
        _TimerRegion(remaining: countdown, labels: labels)
      else if (elapsed case final chrono?)
        if (labels.elapsedSemanticsLabel case final announce?)
          _ElapsedRegion(elapsed: chrono, announce: announce),
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
      label:
          labels.timerSemanticsLabel?.call(value) ??
          label(context, 'zcrud.study.exam.timer', fallback: 'Temps restant'),
      liveRegion: true,
      child: Text(zWhiteExamDigits(value), textAlign: TextAlign.start),
    ),
  );
}

/// Chronomètre écoulé — même rendu que le rebours, sens inverse.
class _ElapsedRegion extends StatelessWidget {
  const _ElapsedRegion({required this.elapsed, required this.announce});

  final ValueListenable<Duration> elapsed;
  final String Function(Duration elapsed) announce;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: elapsed,
    builder: (context, value, _) => Semantics(
      key: ZWhiteExamSessionView.elapsedKey,
      label: announce(value),
      liveRegion: true,
      child: Text(zWhiteExamDigits(value), textAlign: TextAlign.start),
    ),
  );
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
    ZWhiteExamSessionViewPhase.setup => switch (labels.startAction) {
      final startAction? => _Navigation(
        state: state,
        labels: labels,
        child: _ActionButton(
          key: ZWhiteExamSessionView.startKey,
          onPressed: controller.start,
          child: startAction(context),
        ),
      ),
      // Sans libellé de démarrage, l'épreuve n'a pas de phase de réglage :
      // aucune affordance n'est rendue, plutôt qu'un bouton muet.
      _ => const SizedBox.shrink(),
    },
    ZWhiteExamSessionViewPhase.running => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (state.current case final item?)
          Semantics(
            key: ZWhiteExamSessionView.questionKey,
            label:
                labels.questionSemanticsLabel?.call(state) ??
                label(
                  context,
                  'zcrud.study.exam.question',
                  fallback: 'Question',
                ),
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
            child:
                labels.submitAction?.call(context) ??
                Text(
                  label(
                    context,
                    'zcrud.study.exam.submit',
                    fallback: 'Soumettre',
                  ),
                  textAlign: TextAlign.start,
                ),
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
    label:
        labels.navigationSemanticsLabel?.call(state) ??
        label(context, 'zcrud.study.exam.navigation', fallback: 'Actions'),
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
