/// Montages de PAGE du lot W2 — la même scène, énoncée à plat puis énumérée.
///
/// Le jeu de sentinelles est celui du montage de porteur (`lotw1_seams.dart`) :
/// une page et un porteur montés sur les mêmes valeurs doivent rendre le même
/// écran, et c'est exactement ce que les gardes comparent.
library;

import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZReviewMode;

import 'lotw1_seams.dart';
import 'z_study_session_harness.dart';

/// Titre de page des montages du lot (jamais rendu par les sondes).
const String kW2Title = 'lotw2:page';

/// Le wiring bâti depuis le jeu de sentinelles.
///
/// Chaque champ de `ZStudySessionWiring` étant `required`, un seam ajouté
/// demain casse **ici** la compilation : cette fabrique ne peut pas dériver en
/// silence de l'ensemble réel des seams.
ZStudySessionWiring lotW2Wiring(LotW1Seams s) => ZStudySessionWiring(
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

/// Monte la PAGE par le constructeur par défaut, seam par seam à plat.
ZStudySessionScaffold lotW2FlatPage(
  LotW1Seams s, {
  ZReviewMode mode = ZReviewMode.learn,
  int cards = 2,
}) =>
    ZStudySessionScaffold(
      title: kW2Title,
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

/// Monte la PAGE par le constructeur ÉNUMÉRÉ — le montage passe entier.
ZStudySessionScaffold lotW2WiredPage(
  LotW1Seams s, {
  ZReviewMode mode = ZReviewMode.learn,
  int cards = 2,
}) =>
    ZStudySessionScaffold.wired(
      wiring: lotW2Wiring(s),
      title: kW2Title,
      mode: mode,
      queue: writtenCards(cards),
    );
