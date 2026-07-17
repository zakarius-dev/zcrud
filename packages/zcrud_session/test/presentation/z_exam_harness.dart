/// Harnais PARTAGÉ des tests de `ZListSessionView` (SU-7).
///
/// ⚠️ Ce fichier ne contient **aucune assertion de règle métier** : ce sont des
/// **doublures**, des **fabriques de carte** et l'**hôte** de référence. Il ne
/// re-code AUCUNE logique de prod (défaut D5 : un test qui appelle sa propre
/// implémentation de la règle qu'il vérifie est tautologique).
///
/// 🔴 **L'hôte est ici parce que la vue est PURE** (D3) : `ZListSessionView` ne
/// connaît pas `ZWhiteExamSessionEngine` (la garde de pureté interdit l'import).
/// C'est donc l'hôte qui tient le moteur — et c'est **exactement** le point où
/// les **deux listes parallèles** (`items` du moteur / `cards` de la vue) peuvent
/// se désynchroniser. Les tests d'AC9 l'attaquent sur ce point précis.
///
/// # ⚠️ Ce que [ExamHost] est — et ce qu'il N'EST PAS
///
/// Il s'annonçait « l'hôte **le plus simple qui soit CORRECT** ». **C'était
/// faux**, et le mensonge était coûteux : c'est le **seul** exemple d'intégration
/// existant, donc **celui que su-10 recopiera**. Deux défauts, mesurés :
///
/// 1. `engine` était `late final`, construit une fois en `initState`, **sans
///    `didUpdateWidget`** ⇒ après un rétrécissement de file (le chemin qu'**AC6
///    exige**), `engine.queue` restait `[Q1,Q2,Q3]` pendant que `cards == [Q9]` :
///    **l'hôte de référence incarnait la désynchronisation qu'il prétendait
///    réfuter** ;
/// 2. `submissions` n'était **jamais purgée** ⇒ 3 clés périmées `{0,1,2}` contre
///    1 carte neuve **vierge** donnaient `1 - 3 = **-2**` ⇒ **« -2 questions sans
///    réponse »** affiché à l'apprenant (la vue s'en défend désormais, mais
///    l'hôte ne doit pas produire l'entrée absurde en premier lieu).
///
/// Les deux sont **corrigés** ci-dessous. Ce qui reste vrai et **assumé** :
/// [ExamHost] est **NON LINÉAIRE** (il laisse répondre dans le désordre / sauter,
/// comme la vue l'exige) ⇒ conformément au **contrat d'hôte** de
/// `ZWhiteExamSessionEngine.answer`, `engine.answers`/`current`/`cursor` sont
/// chez lui **positionnellement ININTERPRÉTABLES**, et **seul l'agrégat
/// commutatif** (`engine.result`) est exploitable. Ce n'est **pas** un défaut de
/// cet hôte : c'est une **limite du moteur**, documentée, gardée
/// (`z_white_exam_scoring_contract_test.dart`), et dont la levée
/// (`answer({index, quality})`) est **hors périmètre SU-7** (D10).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Convertit la phase du DOMAINE vers la phase de la VUE (miroir total).
///
/// 🔒 `switch` **exhaustif SANS `default`** : une 4ᵉ phase casserait la
/// compilation ici plutôt que de tomber silencieusement dans un repli.
ZExamViewPhase viewPhaseOf(ZWhiteExamPhase phase) => switch (phase) {
  ZWhiteExamPhase.setup => ZExamViewPhase.setup,
  ZWhiteExamPhase.running => ZExamViewPhase.running,
  ZWhiteExamPhase.submitted => ZExamViewPhase.submitted,
};

/// Hôte de référence : il **DÉRIVE** la file du moteur des cartes de la vue.
class ExamHost extends StatefulWidget {
  const ExamHost({
    required this.cards,
    this.scorer,
    this.config = const ZSrsConfig(),
    this.autoStart = true,
    this.contentBuilder,
    this.evaluationPort,
    this.onEngineReady,
    super.key,
  });

  final List<ZFlashcard> cards;
  final ZExamScoringPort? scorer;
  final ZSrsConfig config;
  final bool autoStart;
  final ZFlashcardContentBuilder? contentBuilder;

  /// Port d'évaluation ADVISORY, relayé à la vue (chemin des cartes **rédigées**).
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  final ValueChanged<ZWhiteExamSessionEngine>? onEngineReady;

  @override
  State<ExamHost> createState() => ExamHostState();
}

/// État de l'hôte — public pour que les tests puissent l'inspecter
/// (`tester.state<ExamHostState>(…)`), patron `ScaffoldState`.
class ExamHostState extends State<ExamHost> {
  /// 🔴 **PAS `late final`** : la file peut changer (AC6 — « la file rétrécit »),
  /// et un moteur figé en `initState` porterait une `queue` **périmée**.
  late ZWhiteExamSessionEngine engine;

  /// Soumissions mémorisées **SOUS LA POSITION DE LEUR CARTE** (AC9) — jamais
  /// sous leur rang d'arrivée : une `Map` ainsi indexée ne peut pas « glisser »
  /// d'un cran, là où une liste `add()`-ée le peut.
  ///
  /// ⚠️ **Mais une clé est une POSITION, pas une identité de carte** : elle
  /// **périme** dès que `cards` change ⇒ [didUpdateWidget] la **purge**.
  final Map<int, ZFlashcardSubmission> submissions =
      <int, ZFlashcardSubmission>{};

  /// Index reçus via `onAnswered`, dans l'ordre d'arrivée (observabilité AC9).
  final List<int> answeredIndexes = <int>[];

  ZWhiteExamSessionEngine _buildEngine() => ZWhiteExamSessionEngine(
    // 🔴 **SOURCE UNIQUE** : `items` est DÉRIVÉ de `cards`, dans le MÊME
    // parcours et le MÊME ordre — jamais deux tris indépendants (AC9).
    queue: <ZSessionItem>[
      for (final card in widget.cards)
        ZSessionItem(
          flashcardId: card.id ?? card.question,
          folderId: card.folderId ?? 'f',
        ),
    ],
    config: widget.config,
    scorer: widget.scorer ?? scoreWhiteExam,
  );

  @override
  void initState() {
    super.initState();
    engine = _buildEngine();
    if (widget.autoStart) engine.start();
    widget.onEngineReady?.call(engine);
  }

  /// 🔴 Rebâtit le moteur et **PURGE** les soumissions quand la file change.
  ///
  /// Sans cela, l'hôte de référence **incarnait** la désynchronisation qu'il
  /// prétend réfuter : `engine.queue` restait sur l'ancienne file, et les clés
  /// périmées de [submissions] produisaient un **compte négatif** de questions
  /// sans réponse (« **-2** ») ainsi qu'une **correction de l'ANCIENNE carte 0
  /// peinte sur la NEUVE**.
  ///
  /// 🔒 La purge est **totale**, jamais un remappage : une position ne porte
  /// aucune identité, donc **rien ne permet** de savoir ce qu'une clé périmée
  /// désignait. Inventer une correspondance serait précisément le défaut
  /// « la qualité de A attribuée à B ».
  @override
  void didUpdateWidget(ExamHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.cards, widget.cards)) return;
    engine.dispose();
    submissions.clear();
    answeredIndexes.clear();
    engine = _buildEngine();
    if (widget.autoStart) engine.start();
    widget.onEngineReady?.call(engine);
  }

  @override
  void dispose() {
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: AnimatedBuilder(
        animation: engine,
        builder: (context, _) => ZListSessionView(
          cards: widget.cards,
          phase: viewPhaseOf(engine.phase),
          submissions: submissions,
          result: engine.result,
          config: widget.config,
          contentBuilder: widget.contentBuilder,
          evaluationPort: widget.evaluationPort,
          onAnswered: (index, submission) {
            answeredIndexes.add(index);
            submissions[index] = submission;
            // 🔒 La qualité transite IMMÉDIATEMENT vers le moteur — sans danger :
            // le moteur n'écrit AUCUN SRS (il n'a aucun seam). Seul l'AFFICHAGE
            // de la correction est différé (D2/D3) : le report est un fait de
            // PRÉSENTATION, jamais un second circuit de données.
            engine.answer(submission.quality);
          },
          onSubmit: engine.submit,
        ),
      ),
    ),
  );
}

/// Carte Vrai/Faux **identifiable** — évaluée LOCALEMENT et exactement
/// (`zEvaluateLocally`) : répondre juste ⇒ `config.maxQuality`, répondre faux ⇒
/// `config.minQuality`. 🔒 Les qualités attendues des tests sont donc **dérivées
/// de la config**, jamais des littéraux `5`/`0` d'une seconde échelle (AD-46).
ZFlashcard examCard(String tag, {bool isTrue = true}) => ZFlashcard(
  id: tag,
  folderId: 'f',
  question: tag,
  type: ZFlashcardType.trueOrFalse,
  isTrue: isTrue,
);

/// QCM **identifiable** à UN correct (index 1) — chemin `_ChoiceRow`.
///
/// 🔴 **Pourquoi cette fabrique existe** : [examCard] ne produit que du
/// **Vrai/Faux**. C'est la **cause racine mesurée** de deux gates D2 non gardés —
/// tous les tests d'examen ne tapaient qu'**UN des trois canaux de rendu**, si
/// bien que contourner le gate du QCM (`_ChoiceRow.showCorrection`) laissait la
/// suite **entièrement verte** pendant que les ✓/✗ de vérité se peignaient sur
/// chaque choix **en plein examen**.
ZFlashcard examQcmCard(String tag) => ZFlashcard(
  id: tag,
  folderId: 'f',
  question: tag,
  type: ZFlashcardType.multipleChoice,
  choices: const <ZChoice>[
    ZChoice(content: 'Accra'),
    ZChoice(content: 'Lomé', isCorrect: true),
    ZChoice(content: 'Cotonou'),
  ],
);

/// Carte **RÉDIGÉE** identifiable (type non-local ⇒ chemin `_CorrectionSection`).
///
/// 🔴 Second canal que [examCard] ne pouvait pas atteindre : sans elle,
/// supprimer le gate de `_CorrectionSection` laissait la suite verte pendant que
/// le **feedback du barème** s'affichait sous la question, en plein examen.
ZFlashcard examWrittenCard(String tag) => ZFlashcard(
  id: tag,
  folderId: 'f',
  question: tag,
  type: ZFlashcardType.openQuestion,
  answer: 'réponse attendue',
  explanation: 'explication',
);

/// Clés de test (miroir des `static const` publiques de la vue).
abstract final class EK {
  static ValueKey<String> question(int i) =>
      ValueKey<String>('zExamQuestion_$i');
  static const ValueKey<String> answerTrue = ValueKey<String>('zAnswerTrue');
  static const ValueKey<String> answerFalse = ValueKey<String>('zAnswerFalse');

  /// Champ de rédaction (miroir de `_WrittenInput.fieldKey`).
  static const ValueKey<String> answerField = ValueKey<String>('zAnswerField');

  /// Bouton de soumission d'une carte (miroir de `_SubmitButton.submitKey`).
  static const ValueKey<String> submitAnswer = ValueKey<String>('zSubmit');

  /// Feedback du barème (miroir de `_CorrectionSection`).
  static const ValueKey<String> feedback = ValueKey<String>('zFeedback');

  /// Choix `i` d'un QCM (miroir de `_ChoiceRow`).
  static ValueKey<String> choice(int i) => ValueKey<String>('zAnswerChoice_$i');
}
