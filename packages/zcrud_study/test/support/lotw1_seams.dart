/// Jeu de SEAMS SENTINELLES du montage de session — partagé par la garde de
/// transfert et par les dumps d'inertie.
///
/// Chaque seam porte une valeur DISTINCTIVE et observable dans le rendu ou
/// dans le comportement : c'est ce qui permet d'assérer qu'un montage passé
/// par le wiring atteint réellement l'écran, et pas seulement le widget.
///
/// [LotW1Seams.omit] retire un seam NOMMÉMENT — c'est la contre-preuve de
/// non-vacuité de chaque observation : sans le seam, l'effet observé doit
/// disparaître.
library;

import 'package:dartz/dartz.dart' show Right;
import 'package:flutter/material.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;
import 'package:zcrud_core/zcrud_core.dart'
    show ZDisplayStateController, ZDisplayStateOwner, ZIndexController;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcard,
        ZFlashcardAnswerEvaluation,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardAnswerEvaluationRequest,
        ZFlashcardHintPort,
        ZFlashcardHintRequest,
        ZFlashcardType;
import 'package:zcrud_session/zcrud_session.dart'
    show ZFlashcardSubmission, ZSessionItem, ZSessionReviewer;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import 'z_study_session_harness.dart';

/// Marque commune de toutes les valeurs sentinelles.
const String kW1 = 'lotw1';

/// Port d'indices sentinelle — sa seule présence monte le bouton « Indice ».
class W1HintPort implements ZFlashcardHintPort {
  /// Nombre d'appels reçus.
  int calls = 0;

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    calls += 1;
    return Right<ZFailure, String>('$kW1:indice');
  }
}

/// Port d'évaluation sentinelle — son retour est rendu dans le bloc de
/// feedback de la surface de saisie.
class W1EvaluationPort implements ZFlashcardAnswerEvaluationPort {
  /// Nombre d'appels reçus.
  int calls = 0;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    calls += 1;
    return Right<ZFailure, ZFlashcardAnswerEvaluation>(
      const ZFlashcardAnswerEvaluation(
        feedback: '$kW1:bareme',
        suggestedQuality: 4,
      ),
    );
  }
}

/// Propriétaire minimal d'état d'affichage — le contrôleur d'index sentinelle
/// doit être POSSÉDÉ hors `build` (contrat `ZDisplayStateController`).
class W1Owner implements ZDisplayStateOwner {
  @override
  void zRegisterDisplayState(ZDisplayStateController<Object?> controller) {}
}

/// Scène de montage : la carte et la surface de saisie viennent du SOCLE, ou
/// de l'hôte (les trois seams qui les remplacent sont alors posés).
enum W1Scene {
  /// Carte et saisie du socle : les seams de la carte par défaut sont visibles.
  socle,

  /// Carte et saisie de l'hôte : `cardBuilder`, `cardSlotBuilder`,
  /// `gradingBuilder` sont posés et priment.
  hote,
}

/// Les 22 seams du montage, chacun à une valeur sentinelle observable.
class LotW1Seams {
  /// Construit le jeu de sentinelles de [scene], moins les seams de [omit].
  LotW1Seams({this.scene = W1Scene.socle, this.omit = const <String>{}});

  /// Scène de montage.
  final W1Scene scene;

  /// Seams retirés NOMMÉMENT (contre-preuve de non-vacuité).
  final Set<String> omit;

  /// Faux relecteur SRS — compte les écritures.
  final FakeSessionReviewer reviewerSpy = FakeSessionReviewer();

  /// Port d'indices sentinelle.
  final W1HintPort hintSpy = W1HintPort();

  /// Port d'évaluation sentinelle.
  final W1EvaluationPort evalSpy = W1EvaluationPort();

  /// Crans tapés, dans l'ordre.
  final List<int> qualityTaps = <int>[];

  /// Sorties demandées.
  final List<int> exits = <int>[];

  /// Fins de session notifiées.
  final List<ZStudySessionResult> ends = <ZStudySessionResult>[];

  /// Contrôleur d'index posé par l'hôte.
  final ZIndexController indexSpy =
      ZIndexController(owner: W1Owner(), debugLabel: 'lotw1.index');

  bool _on(String name) {
    if (omit.contains(name)) return false;
    if (scene == W1Scene.socle) {
      return name != 'cardBuilder' &&
          name != 'cardSlotBuilder' &&
          name != 'gradingBuilder';
    }
    return true;
  }

  /// Voie d'écriture SRS.
  ZSessionReviewer? get reviewer => _on('reviewer') ? reviewerSpy.call : null;

  /// Carte d'affichage de l'hôte.
  Widget Function(BuildContext, ZFlashcard)? get cardBuilder =>
      _on('cardBuilder')
          ? (BuildContext context, ZFlashcard card) =>
              Text('$kW1:carte:${card.id}')
          : null;

  /// Créneau de carte de l'hôte.
  ZStudySessionCardSlotBuilder? get cardSlotBuilder => _on('cardSlotBuilder')
      ? (BuildContext context, ZStudySessionCardSlot slot) =>
          Text('$kW1:creneau:${slot.card.id}')
      : null;

  /// Rendu de contenu injecté.
  Widget Function(BuildContext, String)? get contentBuilder =>
      _on('contentBuilder')
          ? (BuildContext context, String content) => Text('$kW1:contenu')
          : null;

  /// Pastille de type de question.
  Widget Function(BuildContext, ZFlashcardType)? get questionTypeBadgeBuilder =>
      _on('questionTypeBadgeBuilder')
          ? (BuildContext context, ZFlashcardType type) =>
              Text('$kW1:pastille')
          : null;

  /// Bandeau de consigne.
  Widget? get instructionBanner =>
      _on('instructionBanner') ? const Text('$kW1:consigne') : null;

  /// Port d'évaluation.
  ZFlashcardAnswerEvaluationPort? get evaluationPort =>
      _on('evaluationPort') ? evalSpy : null;

  /// Port d'indices.
  ZFlashcardHintPort? get hintPort => _on('hintPort') ? hintSpy : null;

  /// Voie de notation manuelle.
  ValueChanged<int>? get onQualitySelected =>
      _on('onQualitySelected') ? qualityTaps.add : null;

  /// Clé de couleur d'un cran — CONSTANTE : tous les crans se peignent pareil.
  String Function(int)? get qualityColorKeyFor =>
      _on('qualityColorKeyFor') ? (int q) => 'error' : null;

  /// Aperçu d'intervalle sous un cran.
  String Function(int)? get qualityPreviewLabelFor =>
      _on('qualityPreviewLabelFor') ? (int q) => '$kW1:J+$q' : null;

  /// En-tête de session.
  ZStudySessionHeaderBuilder? get headerBuilder => _on('headerBuilder')
      ? (BuildContext context, ZStudySessionProgress p) =>
          const Text('$kW1:entete')
      : null;

  /// Bloc de compteurs.
  ZStudySessionCounterBuilder? get counterBuilder => _on('counterBuilder')
      ? (BuildContext context, ZStudySessionProgress p) =>
          const Text('$kW1:compteur')
      : null;

  /// Surface de saisie/notation de l'hôte.
  ZStudySessionGradingSlotBuilder? get gradingBuilder => _on('gradingBuilder')
      ? (
          BuildContext context,
          ZSessionItem item,
          ValueChanged<ZFlashcardSubmission> submit,
        ) =>
            const Text('$kW1:notation')
      : null;

  /// Résumé de fin.
  ZStudySessionResultBuilder? get summaryBuilder => _on('summaryBuilder')
      ? (BuildContext context, ZStudySessionResult r, Duration d) =>
          const Text('$kW1:resume')
      : null;

  /// Repli « session vide ».
  WidgetBuilder? get emptyBuilder => _on('emptyBuilder')
      ? (BuildContext context) => const Text('$kW1:vide')
      : null;

  /// Couche de célébration.
  ZStudySessionCelebrationBuilder? get celebrationBuilder =>
      _on('celebrationBuilder')
          ? (BuildContext context) => const Text('$kW1:bravo')
          : null;

  /// Libellés injectés.
  ZStudySessionLabels? get labels => _on('labels')
      ? const ZStudySessionLabels(
          emptyMessage: '$kW1:message-vide',
          exitAction: '$kW1:sortir',
        )
      : null;

  /// Notification de fin de session.
  void Function(ZStudySessionResult, Duration)? get onSessionEnd =>
      _on('onSessionEnd')
          ? (ZStudySessionResult r, Duration d) => ends.add(r)
          : null;

  /// Issue de sortie.
  VoidCallback? get onExit => _on('onExit') ? () => exits.add(1) : null;

  /// Contrôleur d'index de la pile.
  ZIndexController? get indexController =>
      _on('indexController') ? indexSpy : null;

  /// Formes de référence.
  ZStudySessionPreset? get preset => _on('preset')
      ? ZStudySessionPreset.classic(title: '$kW1:preset')
      : null;
}

/// Monte le porteur par le constructeur PAR DÉFAUT, seam par seam à plat.
///
/// C'est la référence de comparaison du constructeur de transfert : le même
/// jeu de sentinelles, énoncé à l'ancienne.
ZStudySessionHost lotW1FlatHost(
  LotW1Seams s, {
  ZReviewMode mode = ZReviewMode.learn,
  int cards = 2,
}) =>
    ZStudySessionHost(
      mode: mode,
      queue: writtenCards(cards),
      reviewer: s.reviewer,
      cardBuilder: s.cardBuilder,
      cardSlotBuilder: s.cardSlotBuilder,
      contentBuilder: s.contentBuilder,
      questionTypeBadgeBuilder: s.questionTypeBadgeBuilder,
      instructionBanner: s.instructionBanner,
      evaluationPort: s.evaluationPort,
      hintPort: s.hintPort,
      onQualitySelected: s.onQualitySelected,
      qualityColorKeyFor: s.qualityColorKeyFor,
      qualityPreviewLabelFor: s.qualityPreviewLabelFor,
      headerBuilder: s.headerBuilder,
      counterBuilder: s.counterBuilder,
      gradingBuilder: s.gradingBuilder,
      summaryBuilder: s.summaryBuilder,
      emptyBuilder: s.emptyBuilder,
      celebrationBuilder: s.celebrationBuilder,
      labels: s.labels,
      onSessionEnd: s.onSessionEnd,
      onExit: s.onExit,
      indexController: s.indexController,
      preset: s.preset,
    );
