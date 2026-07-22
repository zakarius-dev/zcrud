/// Surface de **SAISIE notée** `ZFlashcardAnswerInput`
/// (Story SU-3 — FR-SU2/3/4/5, AD-33/AD-35/AD-36/AD-46).
///
/// ═══ 🎯 L'ARÈNE DES GESTES — le point de conception n°1 (AC9) ═══════════════
///
/// Le code-review de su-2 a démasqué un **HIGH réel** (D1) : sur le chemin
/// d'usage documenté (`contentBuilder: ZFlashcardMarkdownContent.builder()`), le
/// `QuillEditor` **gagnait l'arène des gestes** contre l'`InkWell` de la carte —
/// `onRevealChanged` ne recevait rien, **la réponse n'apparaissait jamais**, et
/// ce sous **328/328 tests verts**. Le correctif fut un [IgnorePointer] sur le
/// sous-arbre du slot (`z_flashcard_review_card.dart`), légitime **parce que
/// « su-2 AFFICHE »**.
///
/// su-3 introduit la **saisie** : le contenu doit redevenir interactif — mais
/// **PAS n'importe où**. Le conflit n'est ni arbitré par priorité de geste, ni
/// « réglé » en retirant le correctif de su-2 : il est **DISSOUS par
/// construction** —
///
/// | Zone | Régime | Pourquoi |
/// |---|---|---|
/// | Contenu (slot AD-40) | **[IgnorePointer] MAINTENU** | c'est de l'**affichage**, même ici : sans cela un `QuillEditor` volerait le geste aux contrôles de saisie (rejeu exact de D1) |
/// | Contrôles de saisie | **SEULS interactifs** | ce sont les **seuls** capteurs de geste de la surface |
/// | Révélation par tap | **ABSENTE** | 🔒 la correction est causée par la **SOUMISSION**, jamais par un tap |
///
/// 🔒 **« Répondre » et « dévoiler » sont MUTUELLEMENT EXCLUSIFS.** Un apprenant
/// **noté** ne peut pas dévoiler la réponse d'un tap — ce serait **tricher** ET
/// voler le geste au contrôle de saisie. `ZFlashcardReviewCard` (su-2) reste la
/// surface d'**AFFICHAGE** avec sa révélation par tap ; celle-ci est la surface
/// de **SAISIE**, sans tap-to-reveal. Un hôte qui compose les deux les compose
/// en **FRÈRES** (sous-arbres **disjoints**) ⇒ **aucune arène commune**.
///
/// 🚫 **INTERDIT** : retirer/affaiblir l'`IgnorePointer` de su-2 (correctif d'un
/// HIGH réel, gardé par `z_flashcard_gesture_arena_test.dart`) · poser un
/// `Dismissible`/`onHorizontalDrag` (le swipe appartient à **su-4**).
///
/// ═══ 🔒 CE QUE CETTE SURFACE N'ÉCRIT PAS (AD-33) ═════════════════════════════
///
/// **RIEN.** Elle **ÉMET** un fait ([ZFlashcardSubmission]) via `onSubmitted` ;
/// **su-4** branchera `onQualitySelected` sur `ZSessionReviewer.reviewCard` —
/// **unique** voie d'écriture SRS du repo. Le danger est **LOCAL** :
/// `zcrud_flashcard` (dont ce package dépend) contient `ZSm2Scheduler`,
/// `ZSrsScheduler` et `ZRepetitionStore` — tous atteignables d'ici. La garde
/// `test/presentation/z_widgets_purity_test.dart` interdit de les **mentionner**.
///
/// ═══ 🔒 L'ORDRE D'ATTRIBUTION DE LA QUALITÉ (AC2/AC6) ════════════════════════
///
/// ```text
/// QCM/VF     → zEvaluateLocally (max/minQuality)  ─┐
/// rédigée    → clampQuality(port.suggestedQuality) ─┤
/// repli AD-10→ passThreshold                       ─┼→ zApplyHintCeiling(...) → quality
/// « Je ne sais pas » → minQuality                  ─┘   ▲ UNE SEULE VOIE, EN DERNIER
/// ```
///
/// 🔒 **Aucune borne en dur** (AD-46) : tout vient de [ZSrsConfig]. 🔒 Le plafond
/// est appliqué **EN DERNIER, sur la valeur rendue** — « un port qui rend 10
/// indices ne contourne pas le plafond » (AD-36).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
// `ZReviewMode` (kernel) est RÉEXPORTÉ par le barrel `zcrud_flashcard` : un
// import direct de `zcrud_study_kernel` serait redondant (et l'analyseur le
// signale). Aucune arête nouvelle dans les deux cas.
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

import '../domain/z_flashcard_submission.dart';
import 'z_card_advance_behavior.dart';
import 'z_correction_visibility.dart';
import 'z_srs_quality_buttons.dart';
import 'z_timer_display.dart';

/// Résultat **local** d'une soumission (état de correction affiché).
@immutable
class _Correction {
  const _Correction({
    required this.quality,
    this.isCorrect,
    this.feedback,
    this.answeredTrue,
  });

  final int quality;
  final bool? isCorrect;
  final String? feedback;

  /// Réponse **DONNÉE** par l'utilisateur sur un Vrai/Faux (`null` hors V/F).
  ///
  /// 🔒 Nécessaire au **canal de correction** d'AD-13 : sans elle, la surface ne
  /// pouvait pas distinguer « le bouton que vous avez tapé » de « l'autre » —
  /// les deux se **grisaient** à l'identique et l'apprenant n'apprenait **jamais**
  /// qu'il s'était trompé.
  final bool? answeredTrue;
}

/// Surface de saisie notée d'une flashcard (FR-SU2/3/4/5).
///
/// 🔒 **Ne pose AUCUN tap-to-reveal** (AC9) : la correction est causée par la
/// **soumission**.
class ZFlashcardAnswerInput extends StatefulWidget {
  /// Construit la surface de saisie.
  const ZFlashcardAnswerInput({
    required this.card,
    required this.mode,
    this.srsConfig = const ZSrsConfig(),
    this.contentBuilder,
    this.evaluationPort,
    this.allowSkipEvaluation = false,
    this.hintPort,
    this.revealStoredHint = false,
    this.hintPolicy = const ZHintPenaltyPolicy(),
    this.timerDisplay = ZTimerDisplay.hidden,
    this.timeLimit,
    this.advanceBehavior,
    this.autoAdvanceDelay = const Duration(milliseconds: 200),
    this.correctionVisibility = ZCorrectionVisibility.immediate,
    this.onSubmitted,
    this.onQualitySelected,
    this.onAdvance,
    super.key,
  });

  /// Carte à répondre — 🔒 **JAMAIS mutée** (AC5 : les indices générés sont
  /// **éphémères**, jamais persistés sur la carte).
  final ZFlashcard card;

  /// Mode de session — alimente la **table unique** [zDefaultAdvanceBehavior].
  final ZReviewMode mode;

  /// Configuration SRS — 🔒 **propriétaire de l'échelle** (AD-46).
  final ZSrsConfig srsConfig;

  /// Slot AD-40 de rendu du contenu (`null` ⇒ défaut texte brut thématisé).
  final ZFlashcardContentBuilder? contentBuilder;

  /// Port d'évaluation ADVISORY (`null` ⇒ repli **qualité neutre**, AC3).
  ///
  /// 🔒 **Jamais appelé** pour un QCM/Vrai-Faux (AD-35 / AC1).
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Offre, **à chaque soumission**, une voie « évaluer sans IA » qui n'appelle
  /// PAS [evaluationPort] (CR-LEX-13). `false` par défaut.
  ///
  /// zcrud modélisait le choix avec/sans IA comme une propriété de
  /// **construction** (port fourni ou non) ; un hôte qui l'offre comme
  /// **affordance d'interaction** — bouton d'auto-évaluation à côté du bouton
  /// IA — devait remonter le widget entier à chaque bascule. Les deux modèles
  /// sont cohérents ; ils n'étaient simplement pas superposables.
  ///
  /// Sans effet si [evaluationPort] est `null` (il n'y a alors rien à esquiver).
  final bool allowSkipEvaluation;

  /// Clé du bouton « évaluer sans IA » (CR-LEX-13, testabilité).
  static const ValueKey<String> skipEvaluationKey =
      ValueKey<String>('zSkipEvaluation');

  /// Port d'indices (`null` ⇒ bouton « Indice » **ABSENT** après épuisement du
  /// stocké — patron `ZItemActionsMenu` : **absent si non fourni**, jamais grisé).
  final ZFlashcardHintPort? hintPort;

  /// Sert l'indice **stocké** de la carte d'emblée, sans geste (CR-LEX-13/18).
  /// `false` par défaut — le bouton « Indice » reste l'unique voie.
  ///
  /// AD-36 fait de l'indice une ressource **consommée et pénalisée**, ce qui est
  /// un choix produit cohérent — mais sa **visibilité** n'était pas
  /// paramétrable : le modèle « aide toujours offerte », courant dans les jeux
  /// de cartes, n'était pas exprimable. Adopter la surface faisait donc
  /// **disparaître de l'écran** un contenu que l'hôte affichait.
  ///
  /// ⚠️ **La pénalité reste gouvernée par [hintPolicy]**, indépendamment de ce
  /// drapeau : un indice révélé d'emblée est **compté** (`hintsUsed`) et plafonne
  /// la qualité comme tout autre. Pour l'offrir sans coût, neutralisez le plafond
  /// (`ZHintPenaltyPolicy(floor: config.maxQuality)`) — visibilité et pénalité
  /// restent deux décisions distinctes, jamais couplées en douce.
  final bool revealStoredHint;

  /// Politique de plafond d'indices (plancher **dérivé** par défaut, AD-36).
  final ZHintPenaltyPolicy hintPolicy;

  /// Mode d'affichage du minuteur (défaut `hidden` — FR-SU4).
  ///
  /// 🔒 Le temps est **TOUJOURS mesuré**, même en `hidden` (AC7).
  final ZTimerDisplay timerDisplay;

  /// Limite de temps — requise par `countdown` ; `null` ⇒ **dégrade en
  /// `elapsed`** (AD-10 : jamais de rebours depuis `null`).
  final Duration? timeLimit;

  /// Comportement d'avance — `null` ⇒ **table unique** [zDefaultAdvanceBehavior].
  final ZCardAdvanceBehavior? advanceBehavior;

  /// Délai d'auto-passage (défaut `200 ms` — parité IFFD F13).
  final Duration autoAdvanceDelay;

  /// Régime d'apparition de la correction (SU-7/D2) — défaut
  /// [ZCorrectionVisibility.immediate] ⇒ **su-3 strictement inchangé**.
  ///
  /// 🔒 **Gate de RENDU UNIQUEMENT** : en [ZCorrectionVisibility.deferred], la
  /// correction est **posée** (donc la saisie est **verrouillée** : `onTap`/
  /// `onPressed` à `null`, bouton de soumission retiré, `_submitLocked` armé)
  /// mais **jamais peinte**. Voir le dartdoc de [ZCorrectionVisibility] : mêler
  /// ce gate au verrou rouvrirait la double soumission.
  final ZCorrectionVisibility correctionVisibility;

  /// Émis à la soumission (**advisory** : su-3 n'écrit rien — AD-33).
  final ValueChanged<ZFlashcardSubmission>? onSubmitted;

  /// Voie **UNIQUE** de notation — 🔒 `null` ⇒ rangée SRS **ABSENTE** (patron
  /// `ZItemActionsMenu`/AD-44, jamais un booléen `showQualityButtons`).
  final ValueChanged<int>? onQualitySelected;

  /// Demande d'avance à la carte suivante (su-4 navigue — su-3 ne navigue pas).
  final VoidCallback? onAdvance;

  /// 🔒 **VOIE UNIQUE** de résolution du builder du slot AD-40 (AC10/SM-1).
  ///
  /// **Tear-off statique**, jamais `?? (c, s) => …` : une closure serait
  /// **réallouée à chaque build**, changerait d'identité et casserait la
  /// stabilité des rebuilds (patron `z_mindmap_view.dart`).
  ///
  /// ⚠️ **Pourquoi cette fonction est PUBLIQUE (`@visibleForTesting`)** : l'AC10
  /// prescrit le discriminant « `identical()` du **builder RÉSOLU** entre deux
  /// builds ⇒ `true` ». Le builder résolu vivait dans un accesseur **privé** d'un
  /// `State` **privé** : aucun test ne pouvait le lire, et le test qui prétendait
  /// le garder comparait en réalité **deux `const` tear-offs déclarés dans le
  /// test lui-même** — il testait la canonicalisation de **Dart**, pas la prod, et
  /// **restait vert** sous l'injection R3-I10c (mesuré). Extraire la résolution
  /// ici lui donne un **siège testable** : `z_flashcard_answer_input_sm1_test.dart`
  /// ROUGIT désormais si le `??` redevient une closure.
  @visibleForTesting
  static ZFlashcardContentBuilder resolveContentBuilder(
    ZFlashcardContentBuilder? injected,
  ) => injected ?? ZFlashcardDefaultContent.builder;

  @override
  State<ZFlashcardAnswerInput> createState() => _ZFlashcardAnswerInputState();
}

class _ZFlashcardAnswerInputState extends State<ZFlashcardAnswerInput> {
  /// 🔒 **PREMIER `Stopwatch` du repo** (AC7). **Toujours** armé — y compris en
  /// `ZTimerDisplay.hidden` : l'affichage est un réglage d'UI, pas une condition
  /// de mesure. `timeTaken` est lu ici à la soumission.
  final Stopwatch _stopwatch = Stopwatch();

  /// Ticker d'AFFICHAGE — armé **uniquement** si le minuteur est visible (SM-1 :
  /// en `hidden`, un tick réveillerait l'arbre pour rien). `cancel()` au dispose.
  ///
  /// 🔒 **Ré-examiné à CHAQUE `didUpdateWidget`** ([_syncTicker]) : `timerDisplay`
  /// est une **prop mutable**, pas une constante de montage. Sans ce ré-examen
  /// (défaut réel de su-3, mesuré) une bascule `hidden → elapsed` à chaud figeait
  /// l'affichage à `00:00` **pour toujours** pendant que [_stopwatch] comptait et
  /// que `timeTaken` partait au barème — l'apprenant **chronométré sans le voir**.
  Timer? _ticker;

  /// Période du ticker d'affichage (granularité de la seconde).
  static const Duration _tickPeriod = Duration(seconds: 1);

  /// Timer d'auto-passage (AC8) — `cancel()` au dispose + garde `mounted`.
  Timer? _advanceTimer;

  /// Temps **AFFICHÉ**, cumulé par le ticker — 🔒 tranche du MINUTEUR (SM-1) :
  /// un tick ne reconstruit QUE le `ValueListenableBuilder` abonné — **jamais**
  /// la carte, **jamais** le champ.
  ///
  /// ⚠️ **Pourquoi l'AFFICHAGE cumule les ticks au lieu de lire [_stopwatch] à
  /// chaque tick** : ce sont deux besoins distincts. La **mesure** (`timeTaken`,
  /// envoyée au barème) doit être **exacte** ⇒ [_stopwatch], qui lit l'horloge
  /// réelle. L'**affichage**, lui, n'a besoin que de progresser à la seconde, et
  /// il est **piloté par le ticker** : le lier à l'horloge réelle à chaque tick
  /// le rendrait **invérifiable** (le temps virtuel d'un test — `tester.pump(1s)`
  /// — fait avancer les `Timer`, mais **pas** un `Stopwatch`, qui n'est pas
  /// *fakeable* ⇒ l'affichage resterait figé à `00:00` et aucun test ne pourrait
  /// prouver qu'`elapsed` croît et que `countdown` décroît).
  ///
  /// 🔒 **[_stopwatch] reste néanmoins la SOURCE DE MESURE UNIQUE** : l'affichage
  /// en **dérive à chaque (RÉ)ARMEMENT** du ticker ([_syncTicker] : `_elapsed =
  /// _stopwatch.elapsed`). Sans cette resynchronisation, un ticker annulé pendant
  /// un masquage puis ré-armé reprendrait là où il s'était arrêté et **mentirait**
  /// sur le temps écoulé — deux horloges qui divergent. Entre deux armements, la
  /// dérive est bornée par les ticks manqués (jank, arrière-plan).
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// Sélection QCM — **positions** (`ZChoice` ne porte aucun `id` : deux choix
  /// peuvent avoir le même `content`, la position est la seule identité fiable).
  final ValueNotifier<Set<int>> _selected = ValueNotifier<Set<int>>(<int>{});

  /// Indices **déjà montrés** (stocké inclus) — cumulatif, anti-répétition.
  final ValueNotifier<List<String>> _shownHints = ValueNotifier<List<String>>(
    const <String>[],
  );

  /// Message d'erreur d'indice (l10n) — 🔒 un échec n'est **jamais silencieux**,
  /// et **n'incrémente pas** [_shownHints] (un indice non obtenu ne pénalise pas).
  final ValueNotifier<String?> _hintError = ValueNotifier<String?>(null);

  /// Correction affichée après soumission (`null` ⇒ pas encore soumis).
  final ValueNotifier<_Correction?> _correction = ValueNotifier<_Correction?>(
    null,
  );

  /// 🔒 **Controller STABLE** (AC10/SM-1 — objectif produit n°1) : créé **une
  /// fois** ici, `dispose`é ci-dessous. **JAMAIS** recréé dans `build()` — ce
  /// serait le bug historique que zcrud existe pour corriger (perte de focus et
  /// de curseur à chaque frappe).
  final TextEditingController _answerController = TextEditingController();

  /// `FocusNode` stable — même raison.
  final FocusNode _answerFocus = FocusNode();

  /// 🔒 **Jeton de FRAÎCHEUR** — incrémenté à **chaque changement de carte**.
  ///
  /// Capturé **avant** tout `await` de port et **re-comparé au retour** : un
  /// résultat qui revient après un changement de carte est **PÉRIMÉ** et
  /// **ignoré**.
  ///
  /// ⚠️ **`mounted` seul NE SUFFIT PAS** (défaut réel de su-3, mesuré) : quand la
  /// carte change, seul le **widget** est remplacé — l'`Element` et le `State`
  /// **survivent**, `mounted` reste `true`. Sans ce jeton, le feedback et la
  /// **note** de la carte A atterrissaient **silencieusement** sur la carte B ; en
  /// su-4 (`onSubmitted` branché sur `ZSessionReviewer.reviewCard`), c'est un
  /// **SRS faux écrit sur la mauvaise carte**, par la voie légitime.
  int _generation = 0;

  /// 🔒 **Verrou de soumission ONE-SHOT** — une carte, **au plus une**
  /// soumission.
  ///
  /// Posé **à l'entrée** de chacun des **TROIS** chemins (rédigée, QCM/VF
  /// auto-soumis, « Je ne sais pas »), il couvre la fenêtre `await` que le seul
  /// gating par `_correction` **ne ferme pas** (la correction n'arrive qu'**après**
  /// la réponse du port). Sans lui (défaut réel, mesuré) : un double-tap
  /// facturait **deux appels IA** et émettait **deux `onSubmitted`** — et un tap
  /// sur « Je ne sais pas » **après** une bonne réponse ré-émettait `[5, 0]`,
  /// fabriquant un `lapse` sur une réponse exacte.
  bool _submitLocked = false;

  /// 🔒 **Verrou d'indice ONE-SHOT** (même discipline) — une demande en vol
  /// interdit la suivante.
  ///
  /// Sans lui (défaut réel, mesuré) : deux demandes concurrentes capturaient le
  /// **même** `shownHints`, la seconde réponse **écrasait** la première ⇒ un
  /// indice **payé puis jeté**, `hintsUsed` sous-comptant les appels réels ⇒ le
  /// **plafond d'AD-36 faussé**, et l'anti-répétition aveugle.
  bool _hintInFlight = false;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    // 🔒 Ticker armé UNIQUEMENT si le minuteur est affiché (SM-1) — la MESURE,
    // elle, tourne toujours (`_stopwatch` ci-dessus). Pas de resynchronisation au
    // montage : `_stopwatch` vient de démarrer, `_elapsed` est déjà exact (zéro).
    _syncTicker(resync: false);
    _maybeRevealStoredHint();
  }

  /// CR-LEX-18 — sert l'indice STOCKÉ d'emblée quand l'hôte le demande.
  ///
  /// Passe par la MÊME voie que le bouton (`_shownHints`) : l'indice est donc
  /// **compté** (`hintsUsed`) et plafonne la qualité exactement comme s'il avait
  /// été demandé. Un chemin parallèle qui l'afficherait sans le compter ferait
  /// diverger la pénalité de ce que l'utilisateur a réellement vu — c'est
  /// précisément le défaut du contournement app-side.
  void _maybeRevealStoredHint() {
    if (!widget.revealStoredHint) return;
    if (!_hasUnservedStoredHint) return;
    _shownHints.value = <String>[widget.card.hint!];
  }

  @override
  void didUpdateWidget(covariant ZFlashcardAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 🔒 La carte est une prop MUTABLE : sans réinitialisation, `_selected`,
    // `_shownHints`, `_correction`, `_answerController` et `_stopwatch` fuyaient
    // sur la carte suivante (défaut réel, mesuré). Deux dégâts AD-36 : l'indice
    // stocké de B n'était JAMAIS servi (`_hasUnservedStoredHint` court-circuité
    // à jamais) et le port recevait le contenu de A dans le prompt de B.
    if (oldWidget.card != widget.card) _resetForNewCard();
    // 🔒 `timerDisplay`/`timeLimit` sont eux aussi des props mutables.
    _syncTicker(resync: true);
  }

  /// Réinitialise **tout** l'état de réponse pour une **nouvelle carte**.
  void _resetForNewCard() {
    // 🔒 Périme tout appel de port EN VOL (cf. [_generation]).
    _generation++;
    _submitLocked = false;
    _hintInFlight = false;
    _selected.value = <int>{};
    _shownHints.value = const <String>[];
    // CR-LEX-18 — la nouvelle carte doit servir SON indice stocké d'emblée.
    _maybeRevealStoredHint();
    _hintError.value = null;
    _correction.value = null;
    _answerController.clear();
    // L'auto-passage de la carte PRÉCÉDENTE ne doit pas faire avancer la
    // nouvelle (AC8).
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _stopwatch
      ..reset()
      ..start();
    _elapsed.value = Duration.zero;
    _ticker?.cancel();
    _ticker = null;
  }

  /// Le rebours est-il **épuisé** ? (Le ticker n'a alors plus rien à afficher.)
  bool get _countdownExhausted {
    if (_effectiveTimerDisplay != ZTimerDisplay.countdown) return false;
    final limit = widget.timeLimit;
    return limit != null && _elapsed.value >= limit;
  }

  /// 🔒 **VOIE UNIQUE** d'(dés)armement du ticker d'AFFICHAGE — appelée au
  /// montage **et** à chaque `didUpdateWidget`.
  ///
  /// - `hidden` ⇒ ticker **annulé** (SM-1 : l'invariant « armé uniquement si
  ///   visible » n'était vrai qu'au **premier** build ; mesuré, un ticker
  ///   survivait au masquage et tirait 60 fois en 60 s **sans aucun abonné**) ;
  /// - `countdown` **épuisé** ⇒ ticker annulé (il reconstruisait indéfiniment un
  ///   `00:00` immuable et faisait croître `_elapsed` sans borne) ;
  /// - (ré)armement ⇒ l'affichage est **resynchronisé sur [_stopwatch]**, la
  ///   source de mesure unique. Sans ce `resync`, corriger le ré-armement seul
  ///   rendrait l'affichage **faux** : il repartirait de la valeur d'avant le
  ///   masquage, en ignorant le temps réellement écoulé.
  void _syncTicker({required bool resync}) {
    if (_effectiveTimerDisplay == ZTimerDisplay.hidden || _countdownExhausted) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    // Déjà armé : ne PAS ré-armer (ce serait resynchroniser à chaque rebuild de
    // l'hôte, pour rien).
    if (_ticker != null) return;
    if (resync) _elapsed.value = _stopwatch.elapsed;
    _ticker = Timer.periodic(_tickPeriod, (_) {
      _elapsed.value += _tickPeriod;
      if (_countdownExhausted) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  @override
  void dispose() {
    // 🔒 AC7/AC8 : aucun tick, aucune avance après démontage (classe de bug
    // réelle : un `Timer` survivant appelle `onAdvance` sur un arbre mort).
    _ticker?.cancel();
    _advanceTimer?.cancel();
    _stopwatch.stop();
    _elapsed.dispose();
    _selected.dispose();
    _shownHints.dispose();
    _hintError.dispose();
    _correction.dispose();
    _answerController.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  /// 🔒 Slot AD-40 — délègue à [ZFlashcardAnswerInput.resolveContentBuilder], la
  /// **voie unique** de résolution (et le **seul** siège testable de l'invariant
  /// AC10 « le builder résolu est STABLE entre deux builds »).
  ZFlashcardContentBuilder get _contentBuilder =>
      ZFlashcardAnswerInput.resolveContentBuilder(widget.contentBuilder);

  /// AD-10 — `countdown` **sans** `timeLimit` ⇒ dégradation en `elapsed`
  /// (jamais d'exception, jamais un rebours depuis `null`).
  ZTimerDisplay get _effectiveTimerDisplay =>
      widget.timerDisplay == ZTimerDisplay.countdown && widget.timeLimit == null
      ? ZTimerDisplay.elapsed
      : widget.timerDisplay;

  /// 🔒 Table **UNIQUE** (AC8) — une valeur explicite de l'hôte **prime**.
  ZCardAdvanceBehavior get _advanceBehavior =>
      widget.advanceBehavior ?? zDefaultAdvanceBehavior(widget.mode);

  int get _hintsUsed => _shownHints.value.length;

  /// La carte porte-t-elle un indice **STOCKÉ** exploitable ?
  bool get _hasStoredHint {
    final stored = widget.card.hint;
    return stored != null && stored.isNotEmpty;
  }

  /// L'indice **STOCKÉ** est-il encore à servir ? (AD-36 : **stocké D'ABORD**.)
  ///
  /// ⚠️ Dépend de `_shownHints.value` ⇒ **ne doit JAMAIS être lu depuis
  /// `build()`** : le `build()` de la surface ne se rejoue pas quand un indice
  /// s'ajoute (c'est tout l'objet de SM-1). Il est lu dans les callbacks, et la
  /// **disponibilité affichée** est recalculée DANS le
  /// `ValueListenableBuilder` de `_HintSection` — sinon le bouton « Indice »
  /// resterait visible après épuisement (bug réel, démasqué par le test AC5).
  bool get _hasUnservedStoredHint =>
      _hasStoredHint && _shownHints.value.isEmpty;

  /// 🔒 **VOIE UNIQUE** d'attribution : le plafond d'indices est appliqué **EN
  /// DERNIER, sur la valeur rendue** (AD-36) — sur **TOUS** les chemins.
  int _finalQuality(int rawQuality) => zApplyHintCeiling(
    rawQuality: rawQuality,
    hintsUsed: _hintsUsed,
    config: widget.srsConfig,
    policy: widget.hintPolicy,
  );

  /// Émet la soumission **advisory** et arme l'auto-passage éventuel.
  ///
  /// 🔒 **N'écrit RIEN** (AD-33) et **n'appelle PAS** `onQualitySelected` :
  /// soumettre **≠** noter. Le port *suggère*, la rangée SRS *montre*, et seul le
  /// **tap** de l'utilisateur note.
  void _emit(_Correction correction) {
    _correction.value = correction;
    widget.onSubmitted?.call(
      ZFlashcardSubmission(
        quality: correction.quality,
        timeTaken: _stopwatch.elapsed,
        hintsUsed: _hintsUsed,
        isCorrect: correction.isCorrect,
        feedback: correction.feedback,
      ),
    );
    if (_advanceBehavior == ZCardAdvanceBehavior.auto) {
      _advanceTimer?.cancel();
      _advanceTimer = Timer(widget.autoAdvanceDelay, () {
        // 🔒 `mounted` : ne jamais tirer sur un arbre démonté (AC8).
        if (mounted) widget.onAdvance?.call();
      });
    }
  }

  /// Soumission d'un QCM / Vrai-Faux — 🔒 **LOCALE**, le port n'est **JAMAIS**
  /// appelé (AD-35 : « écart assumé avec IFFD, qui les fait passer par l'IA »).
  void _submitLocal({bool? answeredTrue}) {
    // 🔒 ONE-SHOT (cf. [_submitLocked]) — le V/F s'auto-soumet au tap : rien
    // n'empêchait deux taps d'émettre deux soumissions.
    if (_submitLocked) return;
    final raw = zEvaluateLocally(
      card: widget.card,
      selectedChoiceIndexes: _selected.value,
      answeredTrue: answeredTrue,
      config: widget.srsConfig,
    );
    // AD-10 : carte malformée ⇒ aucune saisie n'était offerte ⇒ rien à soumettre.
    // (Le verrou n'est posé qu'APRÈS : ne rien soumettre ne « consomme » pas la
    // soumission unique de la carte.)
    if (raw == null) return;
    _submitLocked = true;
    _emit(
      _Correction(
        quality: _finalQuality(raw),
        isCorrect: raw >= widget.srsConfig.passThreshold,
        answeredTrue: answeredTrue,
      ),
    );
  }

  /// Soumission d'une réponse **rédigée** — port ADVISORY + replis AD-10 (AC3).
  Future<void> _submitWritten({bool skipEvaluation = false}) async {
    // 🔒 AD-35 — **PROPRIÉTAIRE UNIQUE de la décision de routage**, et le SEUL
    // point du code d'où le port est atteignable. `zIsLocallyEvaluatedType` était
    // documentée (barrel + dartdoc) comme « la voie de ROUTAGE » alors qu'elle
    // n'avait **AUCUN site d'appel** : la décision était en réalité prise par le
    // `switch` d'affordance de `_buildInput`. Deux tables décidaient la même
    // chose sans rien qui les lie ⇒ une 7ᵉ valeur (`cloze`) déclarée LOCALE dans
    // l'une mais tombant dans la chaîne `||` de l'autre aurait envoyé à l'IA un
    // type déclaré local — compilation verte, aucun test rouge. La seconde source
    // est supprimée : la fonction du domaine décide, et elle seule (AD-46).
    if (zIsLocallyEvaluatedType(widget.card.type)) {
      _submitLocal();
      return;
    }
    // 🔒 ONE-SHOT (cf. [_submitLocked]) : posé AVANT l'`await`, il ferme la
    // fenêtre que le gating par `_correction` ne ferme pas (la correction n'arrive
    // qu'APRÈS la réponse du port, et le bouton n'a aucun indicateur de charge).
    if (_submitLocked) return;
    _submitLocked = true;
    // 🔒 Jeton de FRAÎCHEUR capturé AVANT l'`await` (cf. [_generation]).
    final generation = _generation;

    // CR-LEX-13 — `skipEvaluation` est une décision de SOUMISSION (affordance),
    // pas de construction : l'hôte peut offrir « évaluer sans IA » à côté du
    // bouton IA sans remonter le widget.
    final port = skipEvaluation ? null : widget.evaluationPort;
    ZFlashcardAnswerEvaluation? evaluation;

    if (port != null) {
      try {
        final result = await port.evaluateAnswer(
          ZFlashcardAnswerEvaluationRequest(
            question: widget.card.question,
            userAnswer: _answerController.text,
            cardType: widget.card.type,
            expectedAnswer: widget.card.answer,
            explanation: widget.card.explanation,
            timeTaken: _stopwatch.elapsed,
            // 🔒 INFORMATIF (AD-36) : le port n'en tire AUCUNE pénalité — le
            // plafond local est l'unique propriétaire.
            hintsUsed: _hintsUsed,
          ),
        );
        evaluation = result.fold(
          // 🔒 L'`errorKind` typé d'AD-35 EST le `ZFailure` (AD-5) : aucun
          // nouveau canal d'erreur. Un échec ⇒ repli neutre.
          (_) => null,
          (value) => value,
        );
      } on Object {
        // 🔒 AD-10 — « jamais d'exception ». Le repli couvre AUSSI le `throw`
        // d'une implémentation app hostile, pas seulement le `Left` : une
        // session ne doit JAMAIS mourir parce qu'un routeur IA a paniqué.
        // (Ce n'est pas un `try-catch` nu de repository : c'est la frontière
        // défensive d'une surface face à du code tiers injecté.)
        evaluation = null;
      }
    }

    // 🔒 `mounted` NE SUFFIT PAS : la carte a pu changer sous le `State` (qui,
    // lui, survit). Un résultat périmé est **ignoré** — jamais écrit sur la
    // carte suivante.
    if (!mounted || generation != _generation) return;

    final int raw;
    final String feedback;
    if (evaluation == null) {
      // 🔒 Qualité **NEUTRE** = `passThreshold` — jamais `3` en dur. Le PRD dit
      // « repli qualité neutre 3 », le spine dit « seuil de passage » : les deux
      // coïncident PARCE QUE `passThreshold == 3` est le défaut, et c'est
      // `passThreshold` qui fait autorité (AD-46).
      raw = widget.srsConfig.passThreshold;
      // 🔒 L'échec n'est **jamais silencieux** (AC3) : jamais un blanc.
      feedback = label(
        context,
        'zcrud.flashcard.evaluationUnavailable',
        fallback: 'Évaluation indisponible — note neutre proposée.',
      );
    } else {
      // 🔒 `clampQuality` = **UNIQUE** voie de clamp (AD-46) : jamais un
      // `.clamp(0, 5)` en dur, jamais une seconde échelle.
      raw = widget.srsConfig.clampQuality(evaluation.suggestedQuality);
      feedback = evaluation.feedback;
    }

    _emit(
      _Correction(
        // 🔒 clamp PUIS plafond — l'ordre imposé (AD-36).
        quality: _finalQuality(raw),
        isCorrect: evaluation?.isCorrect,
        feedback: feedback,
      ),
    );
  }

  /// « Je ne sais pas » — 🔒 **borne basse**, **sans appel** au port (AD-35).
  ///
  /// ⚠️ **Écart PRD assumé** (arbitrage n°1 de la story) : le PRD (FR-SU2) dit
  /// « qualité **1** » ; le **spine (AD-35) et l'epic disent « borne basse »** ⇒
  /// le spine prime (précédent AD-46, qui assume déjà l'écart d'échelle
  /// PRD 1-5 → 0..5). `minQuality` **EST** la borne basse : `0` par défaut, `1`
  /// si l'app configure `ZSrsConfig(minQuality: 1)` — **les deux lectures se
  /// rejoignent** sans valeur en dur.
  void _submitDontKnow() {
    // 🔒 ONE-SHOT (cf. [_submitLocked]) : le bouton restait actif APRÈS la
    // correction ⇒ une bonne réponse déjà notée `5` pouvait être ré-émise à `0`
    // (mesuré : `[5, 0]` pour une seule carte répondue juste). Aucun AC ne prévoit
    // que « Je ne sais pas » reste offert une fois la réponse révélée.
    if (_submitLocked) return;
    _submitLocked = true;
    _emit(
      _Correction(
        quality: _finalQuality(widget.srsConfig.minQuality),
        isCorrect: false,
      ),
    );
  }

  /// Demande d'indice — 🔒 **stocké D'ABORD**, port **APRÈS ÉPUISEMENT** (AD-36).
  Future<void> _requestHint() async {
    // 🔒 ONE-SHOT (cf. [_hintInFlight]) — une demande en vol interdit la suivante.
    if (_hintInFlight) return;
    _hintError.value = null;

    // 🔒 1) L'indice STOCKÉ d'abord — le port n'est PAS appelé (AD-36 :
    // « Prevents : un appel IA superflu »). La carte PORTE déjà son indice.
    if (_hasUnservedStoredHint) {
      _shownHints.value = <String>[widget.card.hint!];
      return;
    }

    // 🔒 2) Le port, seulement APRÈS épuisement, AVEC les indices déjà montrés
    // (anti-répétition : sans eux, le barème paraphraserait le même indice).
    final port = widget.hintPort;
    if (port == null) return; // bouton absent — défensif (AD-10).

    _hintInFlight = true;
    // 🔒 Jeton de FRAÎCHEUR capturé AVANT l'`await` (cf. [_generation]) : un
    // indice qui revient après un changement de carte est PÉRIMÉ — l'afficher
    // fuirait le contenu de la carte A sur la carte B et la plafonnerait à tort.
    final generation = _generation;
    final shown = List<String>.unmodifiable(_shownHints.value);
    try {
      final result = await port.generateHint(
        ZFlashcardHintRequest(
          question: widget.card.question,
          cardType: widget.card.type,
          expectedAnswer: widget.card.answer,
          shownHints: shown,
        ),
      );
      if (!mounted || generation != _generation) return;
      result.fold(
        (_) => _hintError.value = label(
          context,
          'zcrud.flashcard.hintUnavailable',
          fallback: 'Indice indisponible.',
        ),
        (hint) {
          // 🔒 ÉPHÉMÈRE : ajouté à l'état de SESSION, jamais persisté sur la
          // carte — `widget.card` n'est pas mutée, aucune écriture n'a lieu.
          // 🔒 Cumul lu au DERNIER moment (jamais depuis la copie pré-`await`) :
          // une accumulation depuis `shown` écraserait tout indice arrivé entre
          // temps.
          _shownHints.value = <String>[..._shownHints.value, hint];
        },
      );
    } on Object {
      // 🔒 AD-10 : aucune exception ne franchit la surface. Le compteur
      // d'indices reste **inchangé** — un indice NON OBTENU ne pénalise pas.
      if (!mounted || generation != _generation) return;
      _hintError.value = label(
        context,
        'zcrud.flashcard.hintUnavailable',
        fallback: 'Indice indisponible.',
      );
    } finally {
      // Le verrou est libéré même sur échec : un indice NON OBTENU doit pouvoir
      // être redemandé (le compteur, lui, reste inchangé).
      if (mounted && generation == _generation) _hintInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 🔒 SLOT AD-40 SOUS `IgnorePointer` (AC9) — le contenu est de
        // l'AFFICHAGE : un `QuillEditor` injecté ne peut PAS voler le tap d'une
        // case QCM (rejeu exact du HIGH D1 de su-2). Les `Semantics` du
        // sous-arbre restent lisibles : c'est l'INTERACTIVITÉ qui est
        // neutralisée, pas l'accessibilité.
        IgnorePointer(child: _contentBuilder(context, widget.card.question)),
        SizedBox(height: theme.gapM),
        if (_effectiveTimerDisplay != ZTimerDisplay.hidden) ...<Widget>[
          _TimerSlot(
            elapsed: _elapsed,
            display: _effectiveTimerDisplay,
            timeLimit: widget.timeLimit,
          ),
          SizedBox(height: theme.gapM),
        ],
        _buildInput(context),
        SizedBox(height: theme.gapM),
        _HintSection(
          shownHints: _shownHints,
          hintError: _hintError,
          hasStoredHint: _hasStoredHint,
          hasPort: widget.hintPort != null,
          // 🔒 Gaté sur la correction, comme les trois autres contrôles : après
          // soumission, un indice n'a plus d'effet sur la note déjà émise — et
          // déclencherait un appel IA FACTURÉ pour une carte déjà corrigée.
          correction: _correction,
          onRequestHint: _requestHint,
        ),
        SizedBox(height: theme.gapM),
        _DontKnowButton(correction: _correction, onPressed: _submitDontKnow),
        SizedBox(height: theme.gapM),
        _CorrectionSection(
          correction: _correction,
          visibility: widget.correctionVisibility,
          onQualitySelected: widget.onQualitySelected,
          srsConfig: widget.srsConfig,
        ),
      ],
    );
  }

  /// 🔒 Table d'**affordance de SAISIE** par type — `switch` **exhaustif SANS
  /// `default`** sur les **6** `ZFlashcardType` (une 7ᵉ valeur casse la
  /// compilation).
  ///
  /// ⚠️ **Un propriétaire chacun** : cette table ne redécide **PAS** la table
  /// d'**AFFICHAGE** de su-2 (`ZFlashcardReviewCard`). Deux tables, deux objets.
  Widget _buildInput(BuildContext context) => switch (widget.card.type) {
    ZFlashcardType.multipleChoice => _ChoicesInput(
      card: widget.card,
      selected: _selected,
      correction: _correction,
      visibility: widget.correctionVisibility,
      onSubmit: _submitLocal,
    ),
    ZFlashcardType.trueOrFalse => _TrueFalseInput(
      card: widget.card,
      correction: _correction,
      visibility: widget.correctionVisibility,
      // 🔒 FR-SU2 : le tap **VAUT** la soumission (auto-soumission,
      // aucun second geste).
      onAnswer: (value) => _submitLocal(answeredTrue: value),
    ),
    ZFlashcardType.openQuestion ||
    ZFlashcardType.exercise ||
    ZFlashcardType.fillBlank ||
    ZFlashcardType.shortAnswer => _WrittenInput(
      controller: _answerController,
      focusNode: _answerFocus,
      correction: _correction,
      validator: _requiredValidator(context),
      onSubmit: _submitWritten,
      onSubmitWithoutEvaluation:
          (widget.allowSkipEvaluation && widget.evaluationPort != null)
              ? () => _submitWritten(skipEvaluation: true)
              : null,
    ),
  };

  /// 🔒 Validateur **MÉMOÏSÉ** du champ de rédaction (AC10 : identité stable
  /// entre builds — une closure recréée à chaque build ferait retravailler le
  /// `FormField`).
  ///
  /// ⚠️ **Pourquoi il vit ICI et non en `static` sur `_WrittenInput`** : le
  /// message d'erreur est **AFFICHÉ à l'utilisateur** (`errorText` sous le champ,
  /// `autovalidateMode: onUserInteraction`) — il doit donc être **localisé**, ce
  /// qui exige un `BuildContext`. La version `static` rendait le littéral
  /// **`'required'`** : un apprenant francophone qui tapait une lettre puis
  /// l'effaçait voyait « required » en anglais. C'était **exactement** la dette
  /// su-1 (`'ok'`/`'lapse'`) que su-3 venait de solder dix lignes plus haut.
  /// La mémoïsation est **préservée** : la closure n'est reconstruite que si le
  /// libellé résolu change (changement de locale).
  FormFieldValidator<String> _requiredValidator(BuildContext context) {
    final text = label(
      context,
      'zcrud.flashcard.answerRequired',
      fallback: 'Réponse requise',
    );
    if (_cachedValidator == null || _cachedRequiredLabel != text) {
      _cachedRequiredLabel = text;
      _cachedValidator = (value) =>
          (value == null || value.trim().isEmpty) ? text : null;
    }
    return _cachedValidator!;
  }

  String? _cachedRequiredLabel;
  FormFieldValidator<String>? _cachedValidator;
}

/// Tranche **MINUTEUR** isolée (SM-1) — 🔒 seul ce sous-arbre se reconstruit au
/// tick : ni la carte, ni le champ de saisie.
class _TimerSlot extends StatelessWidget {
  const _TimerSlot({
    required this.elapsed,
    required this.display,
    required this.timeLimit,
  });

  final ValueListenable<Duration> elapsed;
  final ZTimerDisplay display;
  final Duration? timeLimit;

  /// Clé de test du texte du minuteur.
  static const ValueKey<String> timerKey = ValueKey<String>('zFlashcardTimer');

  static String _format(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Duration>(
    valueListenable: elapsed,
    builder: (context, value, _) {
      final text = switch (display) {
        // Ce sous-arbre n'est construit que si le minuteur est visible ;
        // `hidden` est ici par exhaustivité (aucun `default`).
        ZTimerDisplay.hidden => '',
        ZTimerDisplay.elapsed => _format(value),
        ZTimerDisplay.countdown => _format(
          // 🔒 S'arrête à ZÉRO, jamais de négatif (AD-10).
          () {
            final remaining = (timeLimit ?? Duration.zero) - value;
            return remaining.isNegative ? Duration.zero : remaining;
          }(),
        ),
      };
      // 🔒 Le SENS est porté par le libellé (AD-13) : « Minuteur, 00:03 » ne
      // dit pas s'il RESTE 3 s ou s'il en a été consommé 3 — l'information
      // décisive en examen blanc (su-7). Pas de `liveRegion` : une annonce
      // par seconde noierait le lecteur d'écran.
      final timerLabel = switch (display) {
        ZTimerDisplay.hidden => label(
          context,
          'zcrud.flashcard.timer',
          fallback: 'Minuteur',
        ),
        ZTimerDisplay.elapsed => label(
          context,
          'zcrud.flashcard.timer.elapsed',
          fallback: 'Temps écoulé',
        ),
        ZTimerDisplay.countdown => label(
          context,
          'zcrud.flashcard.timer.countdown',
          fallback: 'Temps restant',
        ),
      };
      return Semantics(
        label: timerLabel,
        value: text,
        child: Text(text, key: timerKey, textAlign: TextAlign.start),
      );
    },
  );
}

/// Saisie **QCM** — cases **exclusives** si 1 correct, **cumulatives** si ≥ 2
/// (🔒 mode **DÉDUIT** des données, jamais d'un champ/paramètre — AC1).
class _ChoicesInput extends StatelessWidget {
  const _ChoicesInput({
    required this.card,
    required this.selected,
    required this.correction,
    required this.visibility,
    required this.onSubmit,
  });

  final ZFlashcard card;
  final ValueNotifier<Set<int>> selected;
  final ValueListenable<_Correction?> correction;

  /// Régime d'apparition de la correction (SU-7/D2) — **rendu seul**.
  final ZCorrectionVisibility visibility;
  final VoidCallback onSubmit;


  /// Préfixe de clé d'un choix (testabilité).
  static const String choiceKeyPrefix = 'zAnswerChoice_';

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final choices = card.choices;
    // 🔒 AD-10 — `choices` absent/vide ou sans aucun correct ⇒ **aucune saisie
    // offerte**, et surtout **aucun plantage** : repli l10n, jamais un `!`.
    if (choices == null ||
        choices.isEmpty ||
        zCorrectChoiceIndexes(card).isEmpty) {
      return _UnavailableInput(
        labelKey: 'zcrud.flashcard.noChoices',
        fallback: 'Aucun choix disponible',
      );
    }
    final single = zIsSingleChoiceQcm(card);

    return ValueListenableBuilder<_Correction?>(
      valueListenable: correction,
      builder: (context, corrected, _) => ValueListenableBuilder<Set<int>>(
        valueListenable: selected,
        builder: (context, current, _) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (var i = 0; i < choices.length; i++)
              _ChoiceRow(
                key: ValueKey<String>('$choiceKeyPrefix$i'),
                index: i,
                choice: choices[i],
                isSelected: current.contains(i),
                // La correction n'apparaît qu'APRÈS soumission (AC9 : causée par
                // la soumission, jamais par un tap) — et, en `deferred`
                // (examen blanc, SU-7/D2), **jamais** : l'hôte la révèle en fin
                // d'examen.
                // 🔒 Polarité UNIQUE via `paintsCorrection` (`switch` exhaustif)
                // — jamais une comparaison `==` recopiée site par site.
                showCorrection: corrected != null && visibility.paintsCorrection,
                single: single,
                // 🔒 **NE JAMAIS mêler `visibility` à CE gate** (SU-7/G4) : il
                // porte le **VERROU D'INTERACTION**, pas l'affichage. Le rendre
                // sensible au report ferait re-taper un choix après soumission
                // ⇒ double `onSubmitted` (défaut majeur D2 de su-3).
                onTap: corrected != null
                    ? null
                    : () {
                        // 🔒 1 correct ⇒ EXCLUSIF (cocher B décoche A) ;
                        //    ≥ 2 corrects ⇒ CUMULATIF.
                        if (single) {
                          selected.value = <int>{i};
                        } else {
                          final next = <int>{...current};
                          if (!next.remove(i)) next.add(i);
                          selected.value = next;
                        }
                      },
              ),
            SizedBox(height: theme.gapM),
            if (corrected == null) _SubmitButton(onPressed: onSubmit),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de choix — 🔒 `MergeSemantics` : le marqueur de correction est
/// **ASSOCIÉ à SON choix** (leçon **D2** de su-2 : un marqueur détaché s'attache
/// au **mauvais** choix et **enseigne une erreur** à un utilisateur non-voyant).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.index,
    required this.choice,
    required this.isSelected,
    required this.showCorrection,
    required this.single,
    required this.onTap,
    super.key,
  });

  final int index;
  final ZChoice choice;
  final bool isSelected;
  final bool showCorrection;
  final bool single;
  final VoidCallback? onTap;

  /// Cible tap minimale (AD-13).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // 🔒 Canal NON-COLORÉ (AD-13) : une FORME porte l'état, jamais la seule
    // couleur. Sélection : case cochée/décochée. Correction : ✓ / ✗.
    //
    // 🔒 **DEUX informations, DEUX axes de forme** (défaut réel de su-3) : après
    // correction, l'icône ne portait plus QUE la vérité (`check_circle`/`cancel`)
    // et **effaçait le choix de l'utilisateur** — un choix faux COCHÉ et un choix
    // faux NON coché étaient **pixel-identiques**. Le canal sémantique, lui,
    // conservait `checked: isSelected` ⇒ **un utilisateur non-voyant était MIEUX
    // informé qu'un voyant**, qui ne savait plus ce qu'il avait coché. AD-13 exige
    // la **parité** des canaux, pas leur inversion. Désormais : ✓/✗ = la VÉRITÉ ;
    // **plein** = « vous l'aviez coché », **contour** = « vous ne l'aviez pas
    // coché ». Les deux axes sont des FORMES — aucune couleur n'est sollicitée.
    final IconData icon;
    if (showCorrection) {
      icon = choice.isCorrect
          ? (isSelected ? Icons.check_circle : Icons.check_circle_outline)
          : (isSelected ? Icons.cancel : Icons.cancel_outlined);
    } else if (single) {
      icon = isSelected ? Icons.radio_button_checked : Icons.radio_button_off;
    } else {
      icon = isSelected ? Icons.check_box : Icons.check_box_outline_blank;
    }
    final statusText = showCorrection
        ? (choice.isCorrect
              ? label(context, 'zcrud.flashcard.correct', fallback: 'correct')
              : label(
                  context,
                  'zcrud.flashcard.incorrect',
                  fallback: 'incorrect',
                ))
        : null;

    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: single,
        checked: isSelected,
        // Le statut de correction est porté par la MÊME node que le libellé du
        // choix ⇒ impossible de l'attacher au voisin.
        value: statusText,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minTarget),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: theme.fieldPadding,
              child: Row(
                children: <Widget>[
                  Icon(icon, color: theme.labelColor),
                  SizedBox(width: theme.gapM),
                  Expanded(
                    child: Text(choice.content, textAlign: TextAlign.start),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Saisie **Vrai/Faux** — 🔒 **deux boutons à AUTO-SOUMISSION** (FR-SU2 : le tap
/// **vaut** la soumission, aucun second geste).
class _TrueFalseInput extends StatelessWidget {
  const _TrueFalseInput({
    required this.card,
    required this.correction,
    required this.visibility,
    required this.onAnswer,
  });

  final ZFlashcard card;
  final ValueListenable<_Correction?> correction;

  /// Régime d'apparition de la correction (SU-7/D2) — **rendu seul**.
  final ZCorrectionVisibility visibility;
  final ValueChanged<bool> onAnswer;

  /// Clé du bouton « Vrai ».
  static const ValueKey<String> trueKey = ValueKey<String>('zAnswerTrue');

  /// Clé du bouton « Faux ».
  static const ValueKey<String> falseKey = ValueKey<String>('zAnswerFalse');

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // 🔒 AD-10 — `isTrue == null` ⇒ aucune saisie, aucun plantage.
    if (card.isTrue == null) {
      return _UnavailableInput(
        labelKey: 'zcrud.flashcard.noAnswer',
        fallback: 'Aucune réponse',
      );
    }
    final expected = card.isTrue!;
    return ValueListenableBuilder<_Correction?>(
      valueListenable: correction,
      builder: (context, corrected, _) => Row(
        children: <Widget>[
          _tfButton(
            context,
            corrected: corrected,
            value: true,
            expected: expected,
          ),
          SizedBox(width: theme.gapM),
          _tfButton(
            context,
            corrected: corrected,
            value: false,
            expected: expected,
          ),
        ],
      ),
    );
  }

  /// Un bouton V/F, **avec son canal de correction** (AC1/AD-13).
  ///
  /// 🔒 **Défaut réel de su-3 : il n'y avait AUCUN canal de correction sur V/F**
  /// — ni icône, ni `Semantics.value`, ni feedback. Les deux boutons se
  /// **grisaient**, point. Un apprenant qui répondait faux voyait deux boutons
  /// gris et **n'apprenait jamais qu'il s'était trompé** ; un lecteur d'écran
  /// annonçait « Faux, bouton, désactivé », `value` **vide**. La carte était
  /// pédagogiquement **muette**, alors qu'AC1 nomme V/F explicitement et exige un
  /// canal **non-coloré obligatoire** (icône + `Semantics`).
  ///
  /// Aligné sur `_ChoiceRow` : ✓/✗ = la **VÉRITÉ** de cette réponse ; **plein** =
  /// « c'est ce que vous avez répondu », **contour** = « ce n'est pas ce que vous
  /// avez répondu ». Deux axes de **forme**, aucune couleur.
  Widget _tfButton(
    BuildContext context, {
    required _Correction? corrected,
    required bool value,
    required bool expected,
  }) {
    final answered = corrected?.answeredTrue;
    final isCorrect = value == expected;
    final picked = answered == value;
    // 🔒 SU-7/D2 — le canal de correction (icône ✓/✗ **ET** `Semantics.value`)
    // est peint ssi la correction est posée **et** le régime est `immediate`.
    // Les DEUX canaux suivent le MÊME gate : les découpler annoncerait à un
    // lecteur d'écran une correction invisible à l'œil (défaut su-6 « un seul
    // canal », en miroir).
    // 🔒 Polarité UNIQUE via `paintsCorrection` (`switch` exhaustif).
    final reveal = corrected != null && visibility.paintsCorrection;
    return _ControlButton(
      buttonKey: value ? trueKey : falseKey,
      labelKey: value ? 'zcrud.flashcard.true' : 'zcrud.flashcard.false',
      fallback: value ? 'Vrai' : 'Faux',
      statusIcon: !reveal
          ? null
          : (isCorrect
                ? (picked ? Icons.check_circle : Icons.check_circle_outline)
                : (picked ? Icons.cancel : Icons.cancel_outlined)),
      statusValue: !reveal
          ? null
          : (isCorrect
                ? label(context, 'zcrud.flashcard.correct', fallback: 'correct')
                : label(
                    context,
                    'zcrud.flashcard.incorrect',
                    fallback: 'incorrect',
                  )),
      // 🔒 **VERROU D'INTERACTION** — gaté sur la correction SEULE, jamais sur
      // `visibility` (SU-7/G4). Une réponse V/F reste définitive en `deferred`.
      onPressed: corrected != null ? null : () => onAnswer(value),
    );
  }
}

/// Saisie **RÉDIGÉE** — 🔒 le cœur de SM-1 (AC10, **objectif produit n°1**).
///
/// **`TextField` nu + controller détenu par l'hôte**, et **non**
/// `ZTextFieldWidget` (arbitrage n°8 consigné) : celui-ci exige un `ZFieldSpec`
/// — un concept du **moteur d'édition**, dérivé d'un modèle — alors qu'une
/// réponse d'apprenant n'est **pas** un champ de modèle. Fabriquer un
/// `ZFieldSpec` synthétique serait de la cérémonie sans gain, et importerait le
/// décor d'édition dans une surface d'étude. Le **patron** E3-2 est imité
/// (controller stable + `onUserInteraction`), pas le widget.
///
/// 🔒 **Saisie à SENS UNIQUE** : aucune valeur n'est ré-injectée dans le
/// controller pendant la frappe — ce serait écraser la sélection/le curseur.
/// 🔒 **Aucun `setState`** ici : la frappe ne notifie que l'`EditableText`
/// interne ⇒ **rien d'autre** ne se reconstruit (ni la carte, ni le slot).
class _WrittenInput extends StatelessWidget {
  const _WrittenInput({
    required this.controller,
    required this.focusNode,
    required this.correction,
    required this.validator,
    required this.onSubmit,
    this.onSubmitWithoutEvaluation,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueListenable<_Correction?> correction;

  /// 🔒 Validateur **résolu et mémoïsé par l'hôte** (`_requiredValidator`) : son
  /// message est **localisé** et son **identité est stable** entre builds (AC10).
  final FormFieldValidator<String> validator;
  final VoidCallback onSubmit;

  /// CR-LEX-13 — soumission qui n'appelle PAS le port d'évaluation. `null` ⇒
  /// bouton ABSENT (patron d'absence structurelle du dépôt).
  final VoidCallback? onSubmitWithoutEvaluation;

  /// Clé du champ de rédaction.
  static const ValueKey<String> fieldKey = ValueKey<String>('zAnswerField');

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          textField: true,
          label: label(
            context,
            'zcrud.flashcard.yourAnswer',
            fallback: 'Votre réponse',
          ),
          child: ValueListenableBuilder<_Correction?>(
            valueListenable: correction,
            builder: (context, corrected, _) => TextFormField(
              key: fieldKey,
              controller: controller,
              focusNode: focusNode,
              // 🔴 VERROU ONE-SHOT du champ rédigé — défaut MESURÉ. C'était le
              // **SEUL** contrôle de su-3 sans verrou (`_ChoiceRow` : `onTap:
              // null` ; `_tfButton` : `onPressed: null` ; `_DontKnowButton` :
              // disparaît ; `_HintSection` : gatée) : après soumission le champ
              // restait **vivant**. En `immediate` c'était inoffensif (la
              // correction peinte juste en dessous dit « c'est fini ») — mais
              // **`deferred` (SU-7) retire ce signal** : le seul indice de
              // soumission devient la **disparition silencieuse du bouton**.
              // L'apprenant continuait donc de peaufiner sa copie (« je réécris
              // après coup ») en croyant l'améliorer, alors que sa qualité était
              // **déjà notée** sur le texte soumis — et `ZFlashcardSubmission`
              // ne porte **PAS** le texte : le verdict de la révélation portait
              // sur une réponse **qui n'existait plus nulle part**.
              //
              // 🔒 `readOnly` (et non `enabled: false`) : le texte noté reste
              // **lisible et sélectionnable** — l'apprenant doit pouvoir relire
              // ce qui a été évalué. Cela rend D10 (« jamais changer une réponse
              // donnée ») **vrai** pour les 4 `ZFlashcardType` rédigés, et
              // améliore `immediate` au passage.
              readOnly: corrected != null,
              // 🔒 Par CHAMP (patron `z_text_field_widget.dart:37`).
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: validator,
              textAlign: TextAlign.start,
              maxLines: null,
            ),
          ),
        ),
        SizedBox(height: theme.gapM),
        // 🔒 ONE-SHOT (AC4) — même patron que `_ChoicesInput`/`_TrueFalseInput` :
        // le bouton DISPARAÎT une fois la correction affichée. Le verrou
        // `_submitLocked` couvre en plus la fenêtre `await` (avant la correction,
        // le bouton est encore là et n'a aucun indicateur de charge).
        ValueListenableBuilder<_Correction?>(
          valueListenable: correction,
          builder: (context, corrected, _) => corrected != null
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SubmitButton(onPressed: onSubmit),
                    // CR-LEX-13 — voie « évaluer sans IA », offerte À CHAQUE
                    // soumission et non figée à la construction.
                    if (onSubmitWithoutEvaluation != null) ...<Widget>[
                      const SizedBox(width: 8),
                      _ControlButton(
                        buttonKey: ZFlashcardAnswerInput.skipEvaluationKey,
                        labelKey: 'zcrud.flashcard.selfEvaluate',
                        fallback: 'Évaluer sans IA',
                        onPressed: onSubmitWithoutEvaluation!,
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// Section **INDICES** (AC5) — bouton **ABSENT** (jamais grisé) si rien à servir.
class _HintSection extends StatelessWidget {
  const _HintSection({
    required this.shownHints,
    required this.hintError,
    required this.hasStoredHint,
    required this.hasPort,
    required this.correction,
    required this.onRequestHint,
  });

  final ValueListenable<List<String>> shownHints;
  final ValueListenable<String?> hintError;

  /// Correction émise (`null` ⇒ pas encore soumis) — gate le bouton.
  final ValueListenable<_Correction?> correction;

  /// La carte porte-t-elle un indice stocké exploitable ?
  final bool hasStoredHint;

  /// Un port d'indices est-il fourni ?
  final bool hasPort;
  final VoidCallback onRequestHint;

  /// 🔒 Le bouton « Indice » est-il offert ?
  ///
  /// **ABSENT** (jamais grisé) quand il n'y a plus rien à servir : le stocké est
  /// épuisé **ET** aucun port n'est fourni (patron `ZItemActionsMenu`/AD-44 — un
  /// bouton grisé **promet une action qui n'existe pas**).
  ///
  /// ⚠️ Calculé **ICI**, à partir de [shownHints] **observé** : le calculer dans
  /// le `build()` de la surface le figerait à sa valeur initiale (le `build()`
  /// de la surface ne se rejoue pas quand un indice s'ajoute — SM-1) et le
  /// bouton **survivrait à l'épuisement**.
  bool _available(List<String> shown) =>
      (hasStoredHint && shown.isEmpty) || hasPort;

  /// Clé du bouton « Indice ».
  static const ValueKey<String> hintButtonKey = ValueKey<String>('zHintButton');

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ValueListenableBuilder<List<String>>(
          valueListenable: shownHints,
          builder: (context, hints, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final hint in hints)
                Padding(
                  padding: EdgeInsetsDirectional.only(bottom: theme.gapS),
                  child: Semantics(
                    label: label(
                      context,
                      'zcrud.flashcard.hint',
                      fallback: 'Indice',
                    ),
                    value: hint,
                    child: Text(hint, textAlign: TextAlign.start),
                  ),
                ),
              // 🔒 ABSENT si plus rien à servir — recalculé sur `hints`
              // OBSERVÉ (jamais figé au premier build) — et ABSENT une fois la
              // correction émise (un indice n'a plus d'effet sur une note déjà
              // acquise, et coûterait un appel IA facturé pour rien).
              ValueListenableBuilder<_Correction?>(
                valueListenable: correction,
                builder: (context, corrected, _) =>
                    corrected == null && _available(hints)
                    ? _ControlButton(
                        buttonKey: hintButtonKey,
                        labelKey: 'zcrud.flashcard.hint',
                        fallback: 'Indice',
                        onPressed: onRequestHint,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        ValueListenableBuilder<String?>(
          valueListenable: hintError,
          builder: (context, error, _) => error == null
              ? const SizedBox.shrink()
              // 🔒 `liveRegion` (AD-13/AC5) : ce texte apparaît de façon
              // ASYNCHRONE, HORS du focus (qui reste sur le bouton « Indice »).
              // Sans lui, l'échec était non-silencieux pour un voyant seulement :
              // un utilisateur de lecteur d'écran n'entendait RIEN et ré-appuyait
              // en boucle. AC5 exige que l'échec soit perceptible.
              : Semantics(
                  liveRegion: true,
                  child: Text(error, textAlign: TextAlign.start),
                ),
        ),
      ],
    );
  }
}

/// Bouton « **Je ne sais pas** » — borne basse, sans appel au port (AC4).
class _DontKnowButton extends StatelessWidget {
  const _DontKnowButton({required this.correction, required this.onPressed});

  final ValueListenable<_Correction?> correction;
  final VoidCallback onPressed;

  /// Clé du bouton.
  static const ValueKey<String> dontKnowKey = ValueKey<String>('zDontKnow');

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_Correction?>(
    valueListenable: correction,
    // 🔒 ONE-SHOT : ABSENT une fois la correction affichée — la réponse est
    // révélée, « je ne sais pas » n'a plus de sens et ré-émettait la borne
    // BASSE par-dessus une note déjà acquise (mesuré : `[5, 0]`).
    builder: (context, corrected, _) => corrected != null
        ? const SizedBox.shrink()
        : _ControlButton(
            buttonKey: dontKnowKey,
            labelKey: 'zcrud.flashcard.dontKnow',
            fallback: 'Je ne sais pas',
            onPressed: onPressed,
          ),
  );
}

/// Section **CORRECTION + rangée SRS pré-sélectionnée** (AC2).
class _CorrectionSection extends StatelessWidget {
  const _CorrectionSection({
    required this.correction,
    required this.visibility,
    required this.onQualitySelected,
    required this.srsConfig,
  });

  final ValueListenable<_Correction?> correction;

  /// Régime d'apparition de la correction (SU-7/D2) — **rendu seul**.
  final ZCorrectionVisibility visibility;
  final ValueChanged<int>? onQualitySelected;
  final ZSrsConfig srsConfig;

  /// Clé du bloc de feedback.
  static const ValueKey<String> feedbackKey = ValueKey<String>('zFeedback');

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return ValueListenableBuilder<_Correction?>(
      valueListenable: correction,
      builder: (context, corrected, _) {
        if (corrected == null) return const SizedBox.shrink();
        // 🔒 SU-7/D2 — en `deferred` (examen blanc), la correction est POSÉE
        // (verrous de su-3 intacts) mais **rien n'est peint** : ni feedback, ni
        // rangée SRS. L'hôte révèle en fin d'examen, depuis les
        // `ZFlashcardSubmission` mémorisées (D4).
        // 🔒 Polarité UNIQUE via `paintsCorrection` (`switch` exhaustif) — ce
        // site portait la polarité **INVERSE** (`== deferred`) des deux autres
        // (`== immediate`) : une 3ᵉ valeur de l'enum aurait fait **fuiter le
        // feedback** ici pendant que les icônes se taisaient ailleurs.
        if (!visibility.paintsCorrection) {
          return const SizedBox.shrink();
        }
        final selectedQuality = onQualitySelected;
        // 🔒 **AUCUNE affordance de su-3 n'est ANIMÉE** ⇒ aucun appel à
        // `zReduceMotionOf` ici. AC11 le formule exactement ainsi : « **toute
        // affordance ANIMÉE** de su-3 passe par `zReduceMotionOf` » — sans
        // animation, la clause est satisfaite **par vacuité**, et la story ne
        // réclame nulle part une animation de correction.
        //
        // ⚠️ Ce bloc portait un `AnimatedOpacity(opacity: 1, duration: …)` dont
        // la `duration` dérivait de `zReduceMotionOf`. Une animation implicite ne
        // se déclenche que sur un **changement** de valeur : `opacity` étant la
        // **constante 1** et le sous-arbre n'étant **créé** qu'à la correction,
        // elle n'animait **JAMAIS** (mesuré : `FadeTransition.opacity.value == 1.0`
        // à chaque pump). Le résultat de `zReduceMotionOf` était donc **inobservable**
        // — du **code mort qui SIMULAIT la conformité AD-13** — et son test restait
        // vert si la ligne était supprimée. Un verrou factice est **pire** qu'un
        // verrou absent : il se donne pour une preuve. Retiré, avec son test.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (corrected.feedback != null)
              // 🔒 `liveRegion` (AD-13/AC3) : le feedback du barème est le
              // CONTENU PÉDAGOGIQUE CENTRAL de la carte et il apparaît de façon
              // ASYNCHRONE, hors du focus. Sans lui, il était rendu sans jamais
              // être annoncé à un lecteur d'écran.
              Semantics(
                liveRegion: true,
                child: Text(
                  corrected.feedback!,
                  key: feedbackKey,
                  textAlign: TextAlign.start,
                ),
              ),
            // 🔒 Rangée SRS **ABSENTE** si `onQualitySelected == null` (patron
            // `ZItemActionsMenu`/AD-44 — jamais un booléen `showQualityButtons`).
            if (selectedQuality != null) ...<Widget>[
              SizedBox(height: theme.gapM),
              ZSrsQualityButtons(
                scale: ZQualityScale.fromConfig(srsConfig),
                passThreshold: srsConfig.passThreshold,
                // 🔒 ADVISORY : le cran suggéré est **PRÉ-SÉLECTIONNÉ**, et
                // c'est le **tap** de l'utilisateur qui vaut notation.
                selectedQuality: corrected.quality,
                onQualitySelected: selectedQuality,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Repli l10n d'une saisie **indisponible** (AD-10) — jamais un écran vide.
class _UnavailableInput extends StatelessWidget {
  const _UnavailableInput({required this.labelKey, required this.fallback});

  final String labelKey;
  final String fallback;

  @override
  Widget build(BuildContext context) => Text(
    label(context, labelKey, fallback: fallback),
    textAlign: TextAlign.start,
  );
}

/// Bouton de soumission d'une saisie (QCM / rédigée).
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.onPressed});

  final VoidCallback onPressed;

  /// Clé du bouton de soumission.
  static const ValueKey<String> submitKey = ValueKey<String>('zSubmit');

  @override
  Widget build(BuildContext context) => _ControlButton(
    buttonKey: submitKey,
    labelKey: 'zcrud.flashcard.submit',
    fallback: 'Valider',
    onPressed: onPressed,
  );
}

/// Bouton de contrôle générique — 🔒 `Semantics` explicites + cible ≥ 48 dp
/// (AD-13 ; patron `z_srs_quality_buttons.dart:197,212`), libellé l10n, thème
/// injecté, directionnel.
class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.buttonKey,
    required this.labelKey,
    required this.fallback,
    required this.onPressed,
    this.statusIcon,
    this.statusValue,
  });

  final ValueKey<String> buttonKey;
  final String labelKey;
  final String fallback;
  final VoidCallback? onPressed;

  /// Marqueur de correction **non-coloré** (✓/✗), `null` hors correction.
  final IconData? statusIcon;

  /// Statut de correction lu par un lecteur d'écran, `null` hors correction.
  final String? statusValue;

  /// Cible tap minimale Material/AD-13 (dp).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final text = label(context, labelKey, fallback: fallback);
    final icon = statusIcon;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: text,
      // Porté par la MÊME node que le libellé ⇒ impossible de l'attacher au
      // bouton voisin (leçon D2 de su-2).
      value: statusValue,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: minTarget,
          minHeight: minTarget,
        ),
        child: Material(
          color: theme.surfaceColor ?? Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.all(theme.radiusM),
          child: InkWell(
            key: buttonKey,
            onTap: onPressed,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Padding(
              padding: theme.fieldPadding,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, color: theme.labelColor),
                    SizedBox(width: theme.gapS),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            theme.labelColor ??
                            Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
