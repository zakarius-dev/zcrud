import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
// `ZStudySessionResult` / `ZStudyStreak` sont MASQUÉS par le barrel
// `zcrud_flashcard` (symboles study-niveau) : on les importe depuis leur foyer
// canonique, le barrel PUBLIC `zcrud_study_kernel` (jamais un import `/src/`).
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult, ZStudyStreak;

import '../support/rebuild_indicator.dart';
import 'fakes/fake_answer_evaluation_port.dart';
import 'fakes/fake_flashcard_hint_port.dart';
import 'fakes/in_memory_study_store.dart';

/// Point de démarrage d'une session (mode + file) — permet aux tests de
/// **court-circuiter le sélecteur** et d'entrer directement dans une session
/// contrôlée (file vide / 1 carte / échec de port / file qui rétrécit).
@immutable
class StudyAutoStart {
  /// Construit un point de démarrage direct.
  const StudyAutoStart({required this.mode, required this.queue});

  /// Mode de session (détermine le runtime, AD-34).
  final ZReviewMode mode;

  /// File de flashcards **déjà sélectionnée**.
  final List<ZFlashcard> queue;
}

/// Traduit un [ZSessionModeKind] (sortie du sélecteur) en [ZReviewMode]
/// (entrée du runtime). Voie UNIQUE — jamais dupliquée.
ZReviewMode zReviewModeForKind(ZSessionModeKind kind) {
  switch (kind) {
    case ZSessionModeKind.learnNew:
      return ZReviewMode.learn;
    case ZSessionModeKind.review:
      return ZReviewMode.spaced;
    case ZSessionModeKind.test:
      return ZReviewMode.whiteExam;
  }
}

/// Écran de démonstration du **PARCOURS D'ÉTUDE ASSEMBLÉ** (su-10, critère de
/// succès n°2) : `ZSessionModeSelector` → `ZSessionCardSwiper` → carte
/// interactive (`ZFlashcardReviewCard` + `ZFlashcardAnswerInput`) →
/// `ZSessionSummaryView`, à partir de **widgets PUBLICS** (barrels) seuls +
/// **adaptateurs fakes** app-side.
///
/// ## Documentation vivante de migration (AC9)
///
/// C'est l'HÔTE que IFFD / lex_douane écrira. Ce qu'un migrateur substitue :
///
/// - **Runtime par mode (AD-34)** — [_makeRuntime] : `spaced`/`learn` →
///   `ZStudySessionEngine` (seul à recevoir un `ZSessionReviewer`, voie
///   d'écriture SRS UNIQUE) ; `list`/`cramming` → `ZLinearSessionState` (aucune
///   écriture SRS) ; `test`/`whiteExam` → `ZWhiteExamSessionEngine` (scoring, zéro
///   SRS). AUCUN 4ᵉ runtime, AUCUN `ZSessionReviewer` no-op pour un mode non-SRS.
/// - **Store** ([InMemoryStudyStore]) → `ZFlashcardRepository` offline-first réel.
/// - **Port d'évaluation** ([FakeAnswerEvaluationPort]) → routeur IA advisory.
/// - **Port d'indices** ([FakeFlashcardHintPort]) → routeur IA d'indices.
/// - **Port de GÉNÉRATION** (`ZFlashcardGenerationPort`, foyer `zcrud_study`) →
///   routeur IA de création de cartes. **Hors du flux assemblé** (la génération
///   précède la session — su-9) ; son fake est reporté ici car `zcrud_study` tire
///   `zcrud_mindmap` (interdit par AC10). L'app réelle le branche AMONT du
///   parcours, là où elle peuple son store.
/// - **Thème + l10n** → fournis par le `ZcrudScope` RACINE de l'app (réutilisé,
///   jamais redupliqué).
///
/// ## Hôte CORRECT — les pièges d'intégration su-4 / su-7 / su-8
///
/// - **Une seule source de séquence (su-10 D1)** : en mode SRS (`spaced`/`learn`)
///   le moteur `ZStudySessionEngine` est CYCLIQUE (il réinsère les lapses dans sa
///   file) ; le swiper, lui, a une file. Les faire piloter par DEUX curseurs
///   indépendants les fait diverger dès le 1ᵉʳ lapse — et une note tombe alors
///   silencieusement à côté (perte SRS). Ici la file du swiper **suit** la file
///   dynamique du moteur (`engine.state.queue`, cf. [_gradeAndAdvance]) et la
///   carte affichée/notée est **toujours** `engine.current` : les deux ne
///   divergent jamais, donc **chaque** soumission atteint le SRS.
/// - **Deux listes parallèles** : la file est une `List<ZSessionItem>` (IDs
///   seuls) ; les cartes vivent dans un `Map<String, ZFlashcard>`. Le
///   `cardBuilder` **résout par `flashcardId`**, jamais par index/géométrie.
/// - **`key` de la pile dérivée de l'identité de la file** : la file est
///   **stable** en state (régénérée au seul changement réel) — l'`Element` du
///   swiper n'est jamais réutilisé sur une file qu'il n'indexe plus (RangeError
///   su-4 D1).
/// - **`didUpdateWidget` resync** : si la file d'entrée rétrécit/change, l'hôte
///   resynchronise `_queue`/`_currentIndex` (clampé) — pas de queue périmée
///   (su-8).
/// - **`onStackEnd` latch one-shot** : l'écran de célébration est poussé
///   **exactement une fois**, même si l'événement est ré-émis.
/// - **Association réponse↔carte par `flashcardId`** : la soumission est
///   enregistrée par identité de carte (jamais par index) — un port en vol est
///   rattaché à la carte qui l'a demandée.
class StudySessionDemoScreen extends StatefulWidget {
  /// Construit l'écran de parcours.
  const StudySessionDemoScreen({
    this.store,
    this.hintPort,
    this.evaluationPort,
    this.rebuildLog,
    this.autoStart,
    this.onSummaryShown,
    this.celebration = ZSummaryCelebration.confetti,
    this.now,
    super.key,
  });

  /// Store d'étude (défaut : jeu de démo en mémoire).
  final InMemoryStudyStore? store;

  /// Port d'indices (défaut : fake déterministe).
  final ZFlashcardHintPort? hintPort;

  /// Port d'évaluation advisory (défaut : fake déterministe).
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Journal de rebuild injectable (les tests lisent les compteurs granulaires).
  final RebuildLog? rebuildLog;

  /// Démarrage direct (court-circuite le sélecteur) — réservé aux tests.
  final StudyAutoStart? autoStart;

  /// Notifié **une seule fois** quand la célébration est poussée (latch — les
  /// tests assèrent l'unicité).
  final VoidCallback? onSummaryShown;

  /// Variante de célébration (défaut confetti ; les tests passent `none` pour
  /// éviter les animations).
  final ZSummaryCelebration celebration;

  /// Instant de référence INJECTÉ (AD-14) — défaut `DateTime.now()`.
  final DateTime? now;

  @override
  State<StudySessionDemoScreen> createState() => _StudySessionDemoScreenState();
}

enum _StudyPhase { selecting, studying, celebrating }

class _StudySessionDemoScreenState extends State<StudySessionDemoScreen> {
  static const ZSrsConfig _config = ZSrsConfig();

  late final InMemoryStudyStore _store =
      widget.store ?? InMemoryStudyStore.demo();
  late final ZFlashcardHintPort _hintPort =
      widget.hintPort ?? FakeFlashcardHintPort();
  late final ZFlashcardAnswerEvaluationPort _evaluationPort =
      widget.evaluationPort ?? FakeAnswerEvaluationPort();
  late final RebuildLog _log = widget.rebuildLog ?? RebuildLog();
  late final DateTime _now = widget.now ?? DateTime.now();

  _StudyPhase _phase = _StudyPhase.selecting;

  /// File (IDs seuls) — **stable**, régénérée au seul changement réel (su-4 D1).
  List<ZSessionItem> _queue = const <ZSessionItem>[];

  /// Cartes indexées par identité (2ᵉ liste parallèle, su-7).
  Map<String, ZFlashcard> _cardsById = const <String, ZFlashcard>{};

  ZReviewMode _mode = ZReviewMode.learn;
  int _currentIndex = 0;

  /// Soumissions enregistrées par **identité de carte** (jamais par index).
  final Map<String, ZFlashcardSubmission> _submissionsById =
      <String, ZFlashcardSubmission>{};

  /// Runtime choisi par le mode (AD-34) — possédé (dispose au remplacement).
  ChangeNotifier? _runtime;

  final Stopwatch _stopwatch = Stopwatch();

  /// Compteur de poussées de célébration (latch — doit rester **1** par session).
  int summaryShownCount = 0;

  @override
  void initState() {
    super.initState();
    final auto = widget.autoStart;
    if (auto != null) {
      _seedSession(mode: auto.mode, queue: auto.queue);
      _phase = _StudyPhase.studying;
    }
  }

  @override
  void didUpdateWidget(StudySessionDemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // su-8 — resync : si la file d'entrée change (rétrécit/grandit), l'hôte
    // resynchronise sa file et CLAMPE l'index courant (jamais un index survivant
    // à la file qu'il n'indexe plus → RangeError su-4 D1).
    final auto = widget.autoStart;
    if (auto != null && !identical(auto, oldWidget.autoStart)) {
      setState(() {
        _seedSession(mode: auto.mode, queue: auto.queue);
        _phase = _StudyPhase.studying;
      });
    }
  }

  @override
  void dispose() {
    _runtime?.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  /// Runtime par mode (AD-34) — **table UNIQUE**, aucun 4ᵉ runtime, aucun
  /// `ZSessionReviewer` no-op fabriqué pour un mode non-SRS.
  ChangeNotifier _makeRuntime(ZReviewMode mode, List<ZSessionItem> queue) {
    switch (mode) {
      case ZReviewMode.spaced:
      case ZReviewMode.learn:
        // Seul runtime à RECEVOIR un `ZSessionReviewer` (voie d'écriture SRS
        // unique) — le seam est le `review` du store (= `repo.reviewCard` en
        // prod).
        return ZStudySessionEngine(
          queue: queue,
          reviewer: _store.review,
          config: _config,
          mode: mode,
        );
      case ZReviewMode.list:
      case ZReviewMode.cramming:
        return ZLinearSessionState(queue: queue, mode: mode, config: _config);
      case ZReviewMode.test:
      case ZReviewMode.whiteExam:
        return ZWhiteExamSessionEngine(queue: queue, config: _config);
    }
  }

  void _seedSession({required ZReviewMode mode, required List<ZFlashcard> queue}) {
    _runtime?.dispose();
    _mode = mode;
    _currentIndex = 0;
    _submissionsById.clear();
    summaryShownCount = 0;
    // 2 listes parallèles construites depuis la file produite (identité).
    final items = <ZSessionItem>[];
    final byId = <String, ZFlashcard>{};
    for (final card in queue) {
      final id = card.id;
      if (id == null) continue; // défensif : une carte éphémère est ignorée.
      final folderId = card.folderId ?? 'demoStudyFolder';
      items.add(ZSessionItem(flashcardId: id, folderId: folderId));
      byId[id] = card;
    }
    _queue = List<ZSessionItem>.unmodifiable(items);
    _cardsById = Map<String, ZFlashcard>.unmodifiable(byId);
    final runtime = _makeRuntime(mode, _queue);
    _runtime = runtime;
    // Machine d'examen : `setup → running` doit être amorcé avant toute réponse.
    if (runtime is ZWhiteExamSessionEngine && _queue.isNotEmpty) {
      runtime.start();
    }
    _stopwatch
      ..reset()
      ..start();
  }

  /// Étape sélecteur → on entre en session avec le runtime choisi par le mode.
  void _onStart(ZSessionModeKind kind, List<ZFlashcard> queue) {
    setState(() {
      _seedSession(mode: zReviewModeForKind(kind), queue: queue);
      _phase = _StudyPhase.studying;
    });
  }

  /// Soumission d'une réponse — enregistrée par **identité** puis routée vers le
  /// runtime selon le régime d'écriture du mode (AD-34).
  void _onSubmitted(String cardId, ZFlashcardSubmission sub) {
    // Association réponse↔carte par `flashcardId` (su-4 D2 / su-7) — jamais index.
    _submissionsById[cardId] = sub;
    final rt = _runtime;
    switch (_mode) {
      case ZReviewMode.spaced:
      case ZReviewMode.learn:
        final engine = rt as ZStudySessionEngine?;
        // 🔴 su-10 D1 — UNE SEULE SOURCE DE SÉQUENCE : la carte affichée/notée EST
        // toujours le front du moteur (`_currentStudyItem` rend `engine.current`
        // en SRS). La garde d'identité `engine.current == cardId` tient donc PAR
        // CONSTRUCTION — elle protège encore contre une note sur la mauvaise carte
        // (su-8) SANS jamais diverger du swiper : chaque soumission atteint le SRS.
        // (Avant su-10 : le swiper — file FIXE — et le moteur — file CYCLIQUE qui
        // réinsère les lapses — divergeaient dès le 1ᵉʳ lapse, et cette garde
        // sautait alors SILENCIEUSEMENT toutes les notes suivantes.)
        if (engine != null && engine.current?.flashcardId == cardId) {
          // Voie d'écriture SRS UNIQUE (seam `reviewCard`) — spaced/learn seuls.
          unawaited(_gradeAndAdvance(engine, sub.quality));
        }
      case ZReviewMode.list:
        (rt as ZLinearSessionState?)?.advance();
      case ZReviewMode.cramming:
        (rt as ZLinearSessionState?)?.answer(sub.quality);
      case ZReviewMode.test:
      case ZReviewMode.whiteExam:
        final engine = rt as ZWhiteExamSessionEngine?;
        if (engine != null && engine.state.phase == ZWhiteExamPhase.running) {
          engine.answer(sub.quality);
        }
    }
  }

  /// Note la carte courante du moteur SRS, puis fait **suivre** le swiper à la
  /// file DYNAMIQUE du moteur (su-10 D1 — voie (b) « une seule séquence »).
  ///
  /// Sur réussite/lapse, `engine.state.queue` devient la nouvelle file de la pile
  /// (un lapse y réapparaît en aval, une réussite consomme la carte) et le
  /// **front** — donc la carte affichée/notée suivante — reste `engine.current`.
  /// À l'épuisement du moteur, la célébration est poussée (latch). C'est la voie
  /// d'écriture SRS UNIQUE (seam `reviewCard`) : **chaque** soumission l'emprunte.
  Future<void> _gradeAndAdvance(ZStudySessionEngine engine, int quality) async {
    final res = await engine.grade(quality);
    if (!mounted) return;
    res.fold(
      (failure) {
        // Échec typé (AD-10) : file du moteur INCHANGÉE, saisie conservée, la
        // carte reste affichée (l'apprenant relit) — l'échec vit dans l'état du
        // moteur, jamais avalé. Le swiper reste une issue de sortie (onStackEnd).
      },
      (_) {
        if (engine.isComplete) {
          _onStackEnd(); // latch → célébration (fin de la séquence SRS).
        } else {
          // Le swiper SUIT la file du moteur : nouvelle file (identité changée) ⇒
          // il remonte sur son nouveau front (= `engine.current`), la carte notée
          // suivante. Une seule source de séquence, jamais deux curseurs.
          setState(() {
            _queue = engine.state.queue;
            _currentIndex = 0;
          });
        }
      },
    );
  }

  /// `onStackEnd` — **latch one-shot** : la célébration est poussée exactement
  /// une fois, même si l'événement est ré-émis (re-boucle cramming incluse).
  void _onStackEnd() {
    if (_phase == _StudyPhase.celebrating) return; // latch consommé.
    _stopwatch.stop();
    // Examen : figer le score à la soumission (transition légale unique).
    final rt = _runtime;
    if (rt is ZWhiteExamSessionEngine &&
        rt.state.phase == ZWhiteExamPhase.running) {
      rt.submit();
    }
    setState(() {
      _phase = _StudyPhase.celebrating;
      summaryShownCount += 1;
    });
    widget.onSummaryShown?.call();
  }

  /// Résultat de session, construit depuis la **tally d'identité** (association
  /// par `flashcardId`, jamais par index — su-7). Pour l'examen, le moteur est le
  /// scoreur légitime : on préfère son résultat figé.
  ZStudySessionResult _result() {
    final rt = _runtime;
    if (rt is ZWhiteExamSessionEngine) {
      final engineResult = rt.state.result;
      if (engineResult != null) return engineResult;
    }
    final byQuality = <String, int>{};
    var correct = 0;
    for (final sub in _submissionsById.values) {
      final key = '${sub.quality}';
      byQuality[key] = (byQuality[key] ?? 0) + 1;
      if (sub.quality >= _config.passThreshold) correct += 1;
    }
    return ZStudySessionResult(
      mode: _mode,
      total: _submissionsById.length,
      correct: correct,
      byQuality: byQuality,
    );
  }

  void _finish() {
    setState(() {
      _phase = _StudyPhase.selecting;
      _runtime?.dispose();
      _runtime = null;
      _queue = const <ZSessionItem>[];
      _cardsById = const <String, ZFlashcard>{};
      _submissionsById.clear();
      _currentIndex = 0;
    });
  }

  // Slot AD-40 : contenu rendu en MARKDOWN (chemin RÉEL, leçon su-2). Tear-off
  // STABLE (jamais une closure recréée au build) — n'exerce aucune churn du cache
  // de cartes du swiper.
  static final ZFlashcardContentBuilder _markdownContent =
      ZFlashcardMarkdownContent.builder();

  /// Carte d'AFFICHAGE — résolue par **identité** dans le `Map` (su-7), jamais
  /// par index. Instrumentée par [RebuildLog] (`card_<id>`) pour AC7/SM-1.
  Widget _buildCard(BuildContext context, ZSessionItem item) {
    final card = _cardsById[item.flashcardId];
    if (card == null) {
      // Repli AD-10 : désynchronisation des deux listes ⇒ jamais d'exception.
      return Center(
        key: ValueKey<String>('card_missing_${item.flashcardId}'),
        child: const Text('Carte introuvable'),
      );
    }
    return _RebuildProbe(
      name: 'card_${item.flashcardId}',
      log: _log,
      child: ZFlashcardReviewCard(
        key: ValueKey<String>('reviewCard_${item.flashcardId}'),
        card: card,
        contentBuilder: _markdownContent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parcours d\'étude')),
      body: SafeArea(child: _buildPhase(context)),
    );
  }

  Widget _buildPhase(BuildContext context) {
    switch (_phase) {
      case _StudyPhase.selecting:
        return _RebuildProbe(
          name: 'selector',
          log: _log,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(12),
            child: ZSessionModeSelector(
              cards: _store.cards,
              srsById: _store.srsIndex,
              at: _now,
              streak: const ZStudyStreak(),
              onStart: _onStart,
            ),
          ),
        );
      case _StudyPhase.studying:
        return _buildStudying(context);
      case _StudyPhase.celebrating:
        return ZSessionSummaryView(
          result: _result(),
          duration: _stopwatch.elapsed,
          config: _config,
          celebration: widget.celebration,
          onFinish: _finish,
        );
    }
  }

  Widget _buildStudying(BuildContext context) {
    if (_queue.isEmpty) {
      // Robustesse AD-10 — session vide : jamais un cul-de-sac, une issue existe.
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Aucune carte à étudier.'),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey<String>('studyEmptyFinish'),
              onPressed: _finish,
              child: const Text('Retour'),
            ),
          ],
        ),
      );
    }
    final currentItem = _currentStudyItem();
    final currentCard =
        currentItem == null ? null : _cardsById[currentItem.flashcardId];
    return Column(
      children: <Widget>[
        Expanded(
          flex: 3,
          child: _RebuildProbe(
            name: 'swiper',
            log: _log,
            // `key` dérivée de l'IDENTITÉ de la file (su-4 D1) : un changement
            // réel de file remonte l'`Element`, jamais un index survivant.
            child: ZSessionCardSwiper(
              key: ValueKey<String>('swiper_${_queueIdentity()}'),
              queue: _queue,
              cardBuilder: _buildCard,
              passThreshold: _config.passThreshold,
              onIndexChanged: _onIndexChanged,
              onStackEnd: _onStackEnd,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.all(12),
            child: currentCard == null || currentItem == null
                ? const Text('Carte introuvable')
                : ZFlashcardAnswerInput(
                    // Clé d'IDENTITÉ : un nouveau `State` par carte courante
                    // (jamais une saisie qui fuit d'une carte à l'autre).
                    key: ValueKey<String>('answer_${currentItem.flashcardId}'),
                    card: currentCard,
                    mode: _mode,
                    srsConfig: _config,
                    contentBuilder: _markdownContent,
                    evaluationPort: _evaluationPort,
                    hintPort: _hintPort,
                    onSubmitted: (sub) =>
                        _onSubmitted(currentItem.flashcardId, sub),
                  ),
          ),
        ),
      ],
    );
  }

  void _onIndexChanged(int index) {
    setState(() => _currentIndex = index);
  }

  /// Carte courante du parcours — **la carte affichée ET notée**.
  ///
  /// 🔴 su-10 D1 — pour un runtime SRS (`spaced`/`learn`) c'est **toujours** le
  /// front du moteur (`engine.current`) : le swiper suit la file DYNAMIQUE du
  /// moteur (`_gradeAndAdvance`), donc la carte affichée = la carte notée = une
  /// **seule source de séquence** (jamais deux curseurs qui divergent au 1ᵉʳ
  /// lapse). Pour les runtimes non-SRS (linéaire / examen — file FIXE, pas de
  /// réinsertion), on suit l'index du swiper.
  ZSessionItem? _currentStudyItem() {
    final rt = _runtime;
    if (rt is ZStudySessionEngine) return rt.current;
    if (_queue.isEmpty) return null;
    return _queue[_currentIndex.clamp(0, _queue.length - 1)];
  }

  /// Empreinte d'identité de la file (ordre des `flashcardId`) — sert de `key`
  /// de sous-arbre au swiper (su-4 D1).
  String _queueIdentity() =>
      _queue.map((ZSessionItem i) => i.flashcardId).join('|');
}

/// Sonde de rebuild GRANULAIRE : incrémente le compteur [name] à CHAQUE build de
/// ce nœud, puis rend [child]. Placée aux points d'intégration (pile, carte,
/// sélecteur) : si l'hôte reconstruit globalement (violation SM-1), le compteur
/// bouge ; sinon il reste à son plancher.
class _RebuildProbe extends StatelessWidget {
  const _RebuildProbe({
    required this.name,
    required this.log,
    required this.child,
  });

  final String name;
  final RebuildLog log;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    log.bump(name);
    return child;
  }
}
