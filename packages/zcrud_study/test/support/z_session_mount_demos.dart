/// Démonstrations de MONTAGE de la session d'étude — le socle monté comme il
/// recommande de le monter.
///
/// Le README décrit trois régimes de montage ; ce fichier porte celui qui est
/// recommandé pour un écran d'application : le **montage énuméré**
/// (`ZStudySessionHost.wired` / `ZStudySessionScaffold.wired`), où chaque seam
/// est nommé, `null` compris.
///
/// 🔴 **Aucun montage à plat ici, et c'est gardé.** Un fichier qui montre à la
/// fois le montage recommandé et celui qu'il remplace ne montre plus rien : le
/// lecteur ne sait pas lequel copier. Les deux autres régimes (à plat avec
/// `seamAudit`, à plat sans rien) se démontrent donc ailleurs — dans les
/// harnais qui les exercent, et dans le README.
///
/// Les seams posés ci-dessous sont ceux qu'un écran réel pose (voie d'écriture
/// SRS, rendu de contenu, ports d'aide, libellés, issue de sortie, fin de
/// session, formes de référence) ; les autres sont **écrits `null`** — c'est la
/// trace de la renonciation, pas un oubli.
library;

import 'package:dartz/dartz.dart' show Right;
import 'package:flutter/material.dart';
import 'package:zcrud_core/domain.dart' show ZFailure, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcard,
        ZFlashcardAnswerEvaluation,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardAnswerEvaluationRequest,
        ZFlashcardHintPort,
        ZFlashcardHintRequest,
        ZFlashcardType,
        ZRepetitionInfo;
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

/// Port d'évaluation de l'application — ici une doublure constante.
class ZDemoEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  /// Construit la doublure.
  const ZDemoEvaluationPort();

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async =>
      const Right<ZFailure, ZFlashcardAnswerEvaluation>(
        ZFlashcardAnswerEvaluation(feedback: 'demo:bareme', suggestedQuality: 4),
      );
}

/// Port d'indices de l'application — ici une doublure constante.
class ZDemoHintPort implements ZFlashcardHintPort {
  /// Construit la doublure.
  const ZDemoHintPort();

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async =>
      const Right<ZFailure, String>('demo:indice');
}

/// Dossier de la démonstration — identité **opaque**, jamais rendue.
const String kDemoMountFolderId = 'demoStudyFolder';

/// Titre de page de la démonstration (déjà localisé côté application).
const String kDemoMountTitle = 'Révision';

/// Libellé de l'issue de sortie (déjà localisé côté application).
const String kDemoMountExitLabel = 'Fermer';

/// Marqueur du rendu de contenu injecté — ce qu'une application branche sur
/// son propre moteur de rendu riche.
const String kDemoMountContentTag = 'demo:contenu';

/// La file de la démonstration : [n] cartes rédigées.
List<ZFlashcard> zDemoMountQueue([int n = 2]) => <ZFlashcard>[
      for (int i = 0; i < n; i++)
        ZFlashcard(
          id: 'demoCard$i',
          folderId: kDemoMountFolderId,
          type: ZFlashcardType.openQuestion,
          question: 'Question $i.',
          answer: 'Réponse $i.',
        ),
    ];

/// Ce que l'application branche derrière la session — un objet par écran,
/// possédé par l'écran, jamais reconstruit dans un `build`.
///
/// Dans une application réelle ce sont un dépôt, un port d'IA et un routeur ;
/// ici ce sont des doublures qui **enregistrent** ce qu'elles reçoivent, pour
/// que la démonstration reste observable.
class ZDemoMountSeams {
  /// Notes écrites par la voie SRS, dans l'ordre.
  final List<int> srsWrites = <int>[];

  /// Sorties demandées.
  final List<int> exits = <int>[];

  /// Fins de session notifiées.
  final List<ZStudySessionResult> ends = <ZStudySessionResult>[];

  /// Port d'évaluation branché par l'application.
  final ZFlashcardAnswerEvaluationPort evaluationPort =
      const ZDemoEvaluationPort();

  /// Port d'indices branché par l'application.
  final ZFlashcardHintPort hintPort = const ZDemoHintPort();

  /// Voie d'écriture SRS **unique** — dans une application, l'appel au dépôt.
  Future<ZResult<ZRepetitionInfo>> reviewer({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    srsWrites.add(quality);
    return Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(
        flashcardId: flashcardId,
        folderId: folderId,
        repetitions: 1,
        lastQuality: quality,
      ),
    );
  }

  /// Rendu de contenu de l'application (markdown, LaTeX…) — ici un texte
  /// marqué, pour que la démonstration reste observable.
  Widget content(BuildContext context, String content) =>
      Text('$kDemoMountContentTag:$content');

  /// Issue de sortie — dans une application, `Navigator.of(context).pop`.
  void exit() => exits.add(1);

  /// Persistance de fin de session.
  void end(ZStudySessionResult result, Duration duration) => ends.add(result);
}

/// Le montage, énuméré : **les vingt-deux seams**, `null` compris.
///
/// Chaque champ étant `required`, un seam ajouté demain casse la compilation
/// **ici** — cette démonstration ne peut pas dériver en silence de l'ensemble
/// réel des seams de l'écran.
ZStudySessionWiring zDemoMountWiring(ZDemoMountSeams seams) =>
    ZStudySessionWiring(
      // ── Ce que l'écran pose ────────────────────────────────────────────
      reviewer: seams.reviewer,
      contentBuilder: seams.content,
      evaluationPort: seams.evaluationPort,
      hintPort: seams.hintPort,
      labels: const ZStudySessionLabels(exitAction: kDemoMountExitLabel),
      onSessionEnd: seams.end,
      onExit: seams.exit,
      preset: ZStudySessionPreset.classic(title: kDemoMountTitle),
      // ── Ce à quoi l'écran renonce, nommément ───────────────────────────
      cardBuilder: null,
      cardSlotBuilder: null,
      questionTypeBadgeBuilder: null,
      instructionBanner: null,
      onQualitySelected: null,
      qualityColorKeyFor: null,
      qualityPreviewLabelFor: null,
      headerBuilder: null,
      counterBuilder: null,
      gradingBuilder: null,
      summaryBuilder: null,
      emptyBuilder: null,
      celebrationBuilder: null,
      indexController: null,
    );

/// L'écran de session, monté par le constructeur ÉNUMÉRÉ.
///
/// Les cosmétiques restent à plat, sur le constructeur : ils ne peuvent pas
/// disparaître en silence — un scalaire absent se voit à l'écran.
ZStudySessionHost zDemoMountWiredHost(
  ZDemoMountSeams seams, {
  ZReviewMode mode = ZReviewMode.spaced,
  int cards = 2,
}) =>
    ZStudySessionHost.wired(
      wiring: zDemoMountWiring(seams),
      mode: mode,
      queue: zDemoMountQueue(cards),
      cardAccentHeight: 4,
      progressStyle: ZSessionProgressStyle.pill,
    );

/// La **page** de session, montée par le constructeur ÉNUMÉRÉ.
///
/// Le même wiring que l'écran ; l'enveloppe n'en lit aucun champ et le remet
/// entier au porteur.
ZStudySessionScaffold zDemoMountWiredPage(
  ZDemoMountSeams seams, {
  ZReviewMode mode = ZReviewMode.spaced,
  int cards = 2,
}) =>
    ZStudySessionScaffold.wired(
      wiring: zDemoMountWiring(seams),
      title: kDemoMountTitle,
      mode: mode,
      queue: zDemoMountQueue(cards),
      cardAccentHeight: 4,
      progressStyle: ZSessionProgressStyle.pill,
    );
