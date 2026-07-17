/// `ZSessionSummaryView` — **écran de fin de session** (SU-5, AC1..AC11 —
/// FR-SU8/FR-SU9).
///
/// ## Il ASSEMBLE. Il ne réimplémente RIEN (AC1)
///
/// Les pièces existent, sont exportées et testées : il **monte**
/// `ZSessionQualityBreakdown` (alimenté par `result.byQuality` **verbatim** —
/// aucun recomptage) et `ZStudyProgressRings` (alimenté par
/// `ZProgressRingsData.fromResult(result)` — jamais un ratio recalculé).
/// `scale`/`passThreshold` **dérivent** de la `ZSrsConfig` injectée
/// (`ZQualityScale.fromConfig`, voie UNIQUE — AD-46).
///
/// ## 🔴 « maîtrisées » n'est PAS `result.correct` (D3)
///
/// Fait LU sur disque (`z_white_exam_session_engine.dart:210-216`) :
/// `correct = nombre de réponses q >= passThreshold` — soit **q3-4-5**. Or le
/// glossaire PRD et l'AD-46 définissent **maîtrisée = q4-5**. Afficher `correct`
/// sous le libellé « maîtrisées » serait un nombre **juste attribué au mauvais
/// concept** — vert tant que personne ne compare les deux. [zMasteredCount] est
/// donc **dérivé de `byQuality`**, avec un seuil **CONSOMMÉ** depuis son
/// propriétaire AD-46 (`ZSrsConfig.masteredThreshold`), **jamais le littéral `4`**
/// et **jamais redérivé ici** (su-6/D2 : le seuil a été **promu** dans
/// `ZSrsConfig` — les filtres FR-SU12 vivent en AMONT et ne peuvent pas importer
/// ce package ; `z_quality_scale_single_source_test.dart` rougit sur un littéral
/// de borne ou un `masteredThreshold ?? <littéral>` ICI). Les anneaux, eux,
/// continuent d'afficher `correct/total` : **deux nombres différents,
/// volontairement**.
///
/// ## 🔴 La durée est INJECTÉE (D4)
///
/// `ZStudySessionResult` **ne porte AUCUNE durée** (grep RC=1) : le temps n'est
/// mesuré que **par carte** (`ZFlashcardSubmission.timeTaken`). L'ajouter au VO
/// déclencherait le gate de rétro-compatibilité de sérialisation d'un package
/// **hors périmètre**, pour zéro gain d'AC. Elle est donc un **paramètre**,
/// mesuré par l'appelant.
///
/// ## 🔒 Confinement de `confetti` (AC8, NFR-SU7)
///
/// **CE FICHIER est le SEUL de `lib/` à importer `confetti`** — le barrel ne le
/// réexporte pas, et aucun type du paquet n'apparaît en signature publique
/// (gardé par `test/z_third_party_confinement_test.dart` : `graph_proof` ne voit
/// AUCUNE fuite tierce). Réglages **imposés par la lecture des sources du
/// paquet** (cf. `_ConfettiBurst`).
///
/// **Widget PUR** (AD-2/AD-15) : `StatefulWidget` sans aucun gestionnaire d'état,
/// controllers **stables** (create/dispose), callbacks/thème/labels INJECTÉS,
/// aucune écriture SRS (AD-33), directionnel + `Semantics` + cibles ≥ 48 dp
/// (AD-13).
library;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show ZSrsConfig, zReduceMotionOf;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

import 'z_session_feedback_bank.dart';
import 'z_session_quality_breakdown.dart';
import 'z_srs_quality_buttons.dart';
import 'z_study_progress_rings.dart';

/// Variante de **célébration** de l'écran de fin — **enum**, jamais un booléen
/// (AC11, convention du spine « enums > booléens »).
///
/// Le défaut est [ZSummaryCelebration.none] : le confetti est **OPT-IN**, jamais
/// subi. Un `bool showConfetti` interdirait d'ajouter [ZSummaryCelebration.subtle]
/// sans casser tous les appelants.
enum ZSummaryCelebration {
  /// Aucune célébration : le trophée n'est pas rendu, aucun confetti.
  none,

  /// Célébration **sobre** : trophée + halo animés, **aucun confetti**.
  subtle,

  /// Célébration **complète** : trophée + halo + **un seul tir** de confetti.
  ///
  /// 🔒 Jamais sous Reduce Motion (NFR-SU3) : le `ConfettiWidget` n'est alors
  /// **pas construit du tout**.
  confetti,
}

/// Compte des cartes **MAÎTRISÉES** — dérivé de [byQuality] (D3).
///
/// 🔴 **CE N'EST PAS `result.correct`** (= `q >= passThreshold`, soit q3+ —
/// vérifié `z_white_exam_session_engine.dart:210-216`). Ici : `q >=
/// [masteredThreshold]` (q4-5 en échelle canonique).
///
/// - somme les comptes des crans **de l'échelle** dont `q >= masteredThreshold` ;
/// - une clé **hors échelle** (`'9'`, `'03'`, `''`) n'est **jamais** comptée :
///   le breakdown la **signale** à part (R6), et une note que l'échelle ne
///   reconnaît pas ne peut pas être « maîtrisée » ;
/// - **jamais de throw** (AD-10) : `byQuality` corrompu ⇒ les paires inconnues
///   sont ignorées, jamais une exception.
///
/// 🔴 **Un cran NÉGATIF n'est jamais compté** (AD-10 — code-review su-5, D3).
/// `ZStudySessionResult._decodeByQuality` ne filtre que le **type** (`is int`) :
/// un `-3` venu d'un document persisté corrompu traverse **verbatim**. Sans ce
/// plancher, l'écran afficherait « Maîtrisées : **-1** » et le lecteur d'écran
/// annoncerait « moins un » — aucun throw, aucun test rouge. Le VO lui-même
/// clampe déjà `total`/`correct` à `>= 0` (`_decodeCount` : « négatif → 0 ») :
/// la norme du repo est explicite — *un compteur n'est jamais négatif*. su-5
/// gardait déjà cette classe d'aberration pour la **durée** (`_formatDuration` :
/// jamais `-1:-30`) ; elle la garde désormais aussi pour le **nombre** qu'il
/// dérive. On clampe le CRAN (et non la somme) : un `{'5': -3, '4': 2}` rend
/// `2`, jamais `-1` — ignorer le cran aberrant, sans laisser un autre cran
/// valide compenser une valeur absurde.
///
/// Comparaison de **string EXACTE** (`'$quality'`), comme
/// `ZSessionQualityBreakdown._isInScale` : les deux faces partagent le MÊME
/// critère canonique — aucune clé ne peut tomber entre les deux.
int zMasteredCount(
  Map<String, int> byQuality,
  ZQualityScale scale,
  int masteredThreshold,
) {
  var count = 0;
  for (final quality in scale.qualities) {
    if (quality < masteredThreshold) continue;
    final raw = byQuality['$quality'] ?? 0;
    // AD-10 — plancher défensif : un compteur n'est jamais négatif.
    count += raw < 0 ? 0 : raw;
  }
  return count;
}

/// Écran de fin de session — **assemble**, ne réimplémente rien (FR-SU8).
class ZSessionSummaryView extends StatefulWidget {
  /// Construit l'écran de fin.
  ///
  /// - [result] : `ZStudySessionResult` **INJECTÉ** (VO du kernel) ;
  /// - [duration] : durée de session **INJECTÉE** — le VO ne la porte PAS (D4) ;
  /// - [config] : `ZSrsConfig` → `scale` + `passThreshold` (AD-46) ;
  /// - [onFinish] : callback « Terminer » **injecté** ;
  /// - [dueRemaining] : cartes encore dues (`0` ⇒ bouton « Encore N dues »
  ///   **ABSENT**, jamais grisé — patron AD-45) ;
  /// - [onContinue] : callback « Encore N dues » **injecté** ;
  /// - [celebration] : variante de célébration (**défaut `none`** : confetti
  ///   OPT-IN, AC11) ;
  /// - [masteredThreshold] : seuil de maîtrise — défaut **CONSOMMÉ** depuis
  ///   `config.masteredThreshold` (son propriétaire AD-46), **jamais le littéral
  ///   `4`**, **jamais redérivé ici** (D3/AD-46 ; su-6/D2) ;
  /// - [feedbackKey] : clé de message pédagogique (= `zFeedbackKeyFor(tier)`,
  ///   calculée par l'hôte via la fonction PURE `zFeedbackTierFor` — D1 : ce
  ///   widget ne connaît aucune soumission) ;
  /// - [feedbackBank] : banque de messages — **remplace INTÉGRALEMENT** la
  ///   banque par défaut (AC5).
  const ZSessionSummaryView({
    required this.result,
    required this.duration,
    required this.config,
    required this.onFinish,
    this.dueRemaining = 0,
    this.onContinue,
    this.celebration = ZSummaryCelebration.none,
    this.masteredThreshold,
    this.feedbackKey,
    this.feedbackBank,
    super.key,
  });

  /// Résultat de session **INJECTÉ** (VO pur du kernel).
  final ZStudySessionResult result;

  /// Durée de la session — **INJECTÉE** (D4 : le VO ne la porte pas).
  ///
  /// Une durée **négative** (horloge incohérente) est affichée `00:00` — jamais
  /// un temps négatif, jamais une exception (AD-10).
  final Duration duration;

  /// Config SRS **INJECTÉE** : source UNIQUE de l'échelle et du seuil (AD-46).
  final ZSrsConfig config;

  /// Callback « Terminer » — voie UNIQUE de sortie (AC3).
  final VoidCallback onFinish;

  /// Cartes encore dues. `0` ⇒ bouton « Encore N dues » **absent** (AC3).
  final int dueRemaining;

  /// Callback « Encore N dues ». `null` ⇒ bouton absent (rien à faire).
  final VoidCallback? onContinue;

  /// Variante de célébration (**défaut `none`** — confetti OPT-IN, AC11).
  final ZSummaryCelebration celebration;

  /// Seuil de maîtrise **injecté**. `null` ⇒ **consommé** depuis son propriétaire
  /// AD-46, `config.masteredThreshold` (D3 ; su-6/D2 — jamais redérivé ici).
  final int? masteredThreshold;

  /// Clé l10n du message pédagogique, ou `null` (aucun message rendu).
  final String? feedbackKey;

  /// Banque de messages **injectée** — surcharge INTÉGRALE (AC5).
  final ZFeedbackBank? feedbackBank;

  /// [ValueKey] du bouton « Terminer » (testabilité, AC3).
  static const ValueKey<String> finishButtonKey =
      ValueKey<String>('zSummaryFinish');

  /// [ValueKey] du bouton « Encore N dues » (testabilité, AC3).
  static const ValueKey<String> continueButtonKey =
      ValueKey<String>('zSummaryContinue');

  /// [ValueKey] de la valeur « cartes totales » (testabilité, AC2).
  static const ValueKey<String> totalValueKey =
      ValueKey<String>('zSummaryTotalValue');

  /// [ValueKey] de la valeur « maîtrisées » (testabilité, AC2).
  static const ValueKey<String> masteredValueKey =
      ValueKey<String>('zSummaryMasteredValue');

  /// [ValueKey] de la valeur « durée » (testabilité, AC2).
  static const ValueKey<String> durationValueKey =
      ValueKey<String>('zSummaryDurationValue');

  /// [ValueKey] de l'icône du trophée — **sonde d'échelle** (AC7).
  ///
  /// L'échelle se mesure sur la **géométrie peinte** (`tester.getRect`), jamais
  /// sur le champ `transform` du widget : `Transform.scale` ne le peuple pas
  /// (faux négatif MESURÉ en su-4).
  static const ValueKey<String> trophyIconKey =
      ValueKey<String>('zSummaryTrophyIcon');

  /// [ValueKey] du halo (`Opacity`) — **sonde d'opacité** (AC7).
  static const ValueKey<String> glowKey = ValueKey<String>('zSummaryGlow');

  /// Cible tap minimale Material/AD-13 (dp).
  static const double minTarget = 48;

  /// Durée de l'animation d'entrée (trophée + halo).
  static const Duration entranceDuration = Duration(milliseconds: 600);

  @override
  State<ZSessionSummaryView> createState() => ZSessionSummaryViewState();
}

/// État de [ZSessionSummaryView] — **public** pour exposer le compteur de tirs
/// aux tests (patron `ScaffoldState`).
class ZSessionSummaryViewState extends State<ZSessionSummaryView>
    with SingleTickerProviderStateMixin {
  /// Controller d'entrée **STABLE** (créé une fois, disposé une fois — AD-2 :
  /// jamais recréé au rebuild).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ZSessionSummaryView.entranceDuration,
  );

  /// Échelle du trophée — animation **RÉELLE** (`0.6 → 1.0`, rebond élastique).
  late final Animation<double> _trophyScale = Tween<double>(
    begin: 0.6,
    end: 1,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.elasticOut));

  /// Opacité du halo — animation **RÉELLE** (`0.0 → 1.0`).
  late final Animation<double> _glowOpacity = Tween<double>(
    begin: 0,
    end: 1,
  ).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeIn));

  /// Controller de confetti — **POSSÉDÉ par nous** (T5), `null` tant qu'aucun
  /// tir n'est parti (et à jamais sous Reduce Motion / hors opt-in).
  ConfettiController? _confetti;

  /// 🔒 Latch **one-shot** du tir (patron `_stackEnded` de su-4, `:360`).
  bool _celebrationFired = false;

  /// Latch de démarrage de l'animation d'entrée (idem : `didChangeDependencies`
  /// est ré-entrant — il refire à CHAQUE changement de `MediaQuery`).
  bool _entranceStarted = false;

  int _celebrationPlays = 0;

  /// Nombre de tirs de confetti **réellement** déclenchés (seam de test, AC6).
  ///
  /// 🔴 On assère sur CE compteur, sur la présence du `ConfettiWidget` et sur
  /// ses **réglages** — **jamais sur les particules** : le paquet calcule son
  /// `deltaTime` sur l'horloge **murale** (`DateTime.now()`), donc le nombre de
  /// particules d'une frame de test n'est pas déterministe. C'est un **détail
  /// d'implémentation du paquet** : une assertion dessus serait fausse pour la
  /// mauvaise raison.
  ///
  /// ⚠️ **Rectification (code-review su-5)** : la justification d'origine
  /// invoquait « **zéro particule** en test, l'émission étant suspendue sous bas
  /// framerate ». C'était vrai **avec le défaut** `pauseEmissionOnLowFrameRate:
  /// true` (`particle.dart:165` : `if (pauseEmission) return;` **avant**
  /// l'émission) — or on passe précisément `false` (T3) : la prémisse est
  /// **inversée par le correctif lui-même**. La consigne tient, pour une raison
  /// **meilleure** : on n'assère pas sur les internes d'un paquet tiers.
  @visibleForTesting
  int get celebrationPlays => _celebrationPlays;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `zReduceMotionOf` = primitive UNIQUE (jamais un `MediaQuery.of(context)
    // .disableAnimations` réécrit). Lue ICI : `MediaQuery` est une dépendance
    // héritée ⇒ un changement de réglage système nous rappelle.
    final reduceMotion = zReduceMotionOf(context);
    if (reduceMotion) {
      // Dégradation de l'ANIMATION, jamais de la FONCTION : l'état FINAL est
      // rendu IMMÉDIATEMENT (pas de `forward`, pas d'interpolation).
      _entrance.value = 1;
    } else if (!_entranceStarted) {
      _entranceStarted = true;
      _entrance.forward();
    }
    _maybeCelebrate(reduceMotion: reduceMotion);
  }

  @override
  void didUpdateWidget(ZSessionSummaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le latch survit aux rebuilds : `celebration` passant à `confetti` APRÈS
    // coup ne redéclenche rien si un tir est déjà parti (AC6 : UN SEUL tir).
    _maybeCelebrate(reduceMotion: zReduceMotionOf(context));
  }

  /// Déclenche le tir — **au plus une fois dans la vie du widget** (AC6).
  void _maybeCelebrate({required bool reduceMotion}) {
    if (_celebrationFired) return; // 🔒 one-shot.
    if (widget.celebration != ZSummaryCelebration.confetti) return;
    // 🔒 NFR-SU3 : sous Reduce Motion, on ne construit JAMAIS le confetti — et
    // surtout pas « avec une durée nulle » : `ConfettiController` porte
    // `assert(!duration.isNegative && duration.inMicroseconds > 0)`
    // (`confetti.dart:501`) ⇒ `Duration.zero` fait ASSERT-FAIL.
    if (reduceMotion) return;

    _celebrationFired = true;
    _celebrationPlays++;
    setState(() {
      _confetti = ConfettiController(duration: _ConfettiBurst.burstDuration)
        ..play();
    });
  }

  @override
  void dispose() {
    // T5 — ORDRE CRITIQUE, vérifié dans les sources du paquet : Flutter démonte
    // les ENFANTS d'abord (`_InactiveElements._unmount` visite les enfants avant
    // le parent), donc `_ConfettiWidgetState.dispose()` (`confetti.dart:377-382`)
    // a DÉJÀ retiré son listener quand on arrive ici. Notre `dispose()` ne peut
    // donc pas notifier un `State` démonté — alors que
    // `ConfettiController.dispose()` fait bien `notifyListeners()` AVANT
    // `super.dispose()` (`:531-534`).
    _confetti?.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// Formate une durée en `mm:ss` — **défensif** (AD-10).
  ///
  /// Une durée **négative** (horloge incohérente, mesure absente) rend `00:00` :
  /// jamais `-1:-30`, jamais une exception.
  static String _formatDuration(Duration duration) {
    final safe = duration.isNegative ? Duration.zero : duration;
    final minutes = safe.inMinutes.toString().padLeft(2, '0');
    final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // AD-46 — l'échelle DÉRIVE de la config : jamais redéclarée ici.
    final scale = ZQualityScale.fromConfig(widget.config);
    // 🔴 Défaut CONSOMMÉ depuis son PROPRIÉTAIRE AD-46 (`ZSrsConfig`), JAMAIS
    // redérivé ici et JAMAIS le littéral `4` (su-6/D2 : le seuil a été **promu**
    // dans `ZSrsConfig.masteredThreshold` parce que les filtres FR-SU12 vivent en
    // AMONT, dans `zcrud_flashcard`, et qu'un amont ne peut pas importer un aval
    // — AD-1). Le point d'injection `widget.masteredThreshold` de su-5 est
    // **conservé tel quel** : seul le DÉFAUT change de foyer.
    final masteredThreshold =
        widget.masteredThreshold ?? widget.config.masteredThreshold;
    final mastered =
        zMasteredCount(widget.result.byQuality, scale, masteredThreshold);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (widget.celebration != ZSummaryCelebration.none) ...<Widget>[
          _buildCelebrationHeader(context),
          SizedBox(height: theme.gapL),
        ],
        Text(
          label(context, 'zcrud.session.summary.title',
              fallback: 'Session terminée'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: theme.gapM),
        // AC1 — les anneaux sont alimentés par la fonction PURE du DTO : jamais
        // un ratio recalculé ici. `total == 0` ⇒ ratio 0 (aucune division par
        // zéro) ; `correct > total` ⇒ ratio clampé. Contrat EXISTANT, consommé.
        ZStudyProgressRings(
          data: ZProgressRingsData.fromResult(widget.result),
        ),
        SizedBox(height: theme.gapM),
        if (widget.feedbackKey != null) ...<Widget>[
          ZSessionFeedbackText(
            feedbackKey: widget.feedbackKey!,
            bank: widget.feedbackBank,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: theme.gapM),
        ],
        _buildStats(context, mastered: mastered),
        SizedBox(height: theme.gapM),
        // AC1 — `byQuality` VERBATIM (aucun recomptage), `scale`/`passThreshold`
        // dérivés de la config. Contrat EXISTANT, consommé.
        ZSessionQualityBreakdown(
          byQuality: widget.result.byQuality,
          scale: scale,
          passThreshold: widget.config.passThreshold,
        ),
        SizedBox(height: theme.gapL),
        _buildActions(context),
      ],
    );

    // Jamais `ListView(children: [...])` (AD-13/garde) — et un écran de fin doit
    // rester lisible en textScaler élevé ou en paysage : le contenu DÉFILE
    // plutôt que de déborder (leçon su-2 : un débordement se corrige dans le
    // widget, jamais en modifiant le test).
    final scrollable = SingleChildScrollView(
      padding: theme.fieldPadding,
      child: content,
    );

    final confetti = _confetti;
    if (confetti == null) return scrollable;
    return Stack(
      alignment: AlignmentDirectional.topCenter,
      children: <Widget>[
        scrollable,
        _ConfettiBurst(controller: confetti),
      ],
    );
  }

  /// En-tête de célébration : halo + trophée — **animations RÉELLES** (D7).
  ///
  /// `AnimatedBuilder` n'abonne QUE ce sous-arbre au controller (AD-2 : rebuild
  /// granulaire — le reste de l'écran ne se reconstruit pas à chaque frame).
  Widget _buildCelebrationHeader(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, 'primary', slotIndex: 0);
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) => Opacity(
        key: ZSessionSummaryView.glowKey,
        opacity: _glowOpacity.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: _trophyScale.value,
          child: child,
        ),
      ),
      // `child` est construit UNE fois et réutilisé à chaque frame (jamais
      // reconstruit dans la closure — AD-2).
      // 🟡 LOW (code-review su-5) : le repli était « Session terminée, bravo »,
      // que le lecteur d'écran annonçait juste AVANT le titre « Session
      // terminée » (`:376`) — deux nœuds quasi identiques, consécutifs. Le
      // trophée ne porte que la CÉLÉBRATION ; le titre porte le FAIT. La clé
      // l10n est inchangée (un hôte qui la surcharge n'est pas impacté).
      child: Semantics(
        label: label(context, 'zcrud.session.summary.celebration',
            fallback: 'Bravo'),
        child: Container(
          padding: theme.fieldPadding,
          decoration: BoxDecoration(
            color: pair.color,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.emoji_events,
            key: ZSessionSummaryView.trophyIconKey,
            size: theme.gapL * 2,
            color: pair.onColor,
          ),
        ),
      ),
    );
  }

  /// Bloc de stats : **totales / maîtrisées / durée** (AC2).
  Widget _buildStats(BuildContext context, {required int mastered}) {
    final theme = ZcrudTheme.of(context);
    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapS,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _StatTile(
          valueKey: ZSessionSummaryView.totalValueKey,
          labelText:
              label(context, 'zcrud.session.summary.total', fallback: 'Cartes'),
          valueText: '${widget.result.total}',
        ),
        // 🔴 D3 — « maîtrisées » (q4-5), JAMAIS `result.correct` (q3+). Les
        // anneaux ci-dessus affichent `correct/total` : deux nombres
        // DIFFÉRENTS, volontairement.
        _StatTile(
          valueKey: ZSessionSummaryView.masteredValueKey,
          labelText: label(context, 'zcrud.session.summary.mastered',
              fallback: 'Maîtrisées'),
          valueText: '$mastered',
        ),
        _StatTile(
          valueKey: ZSessionSummaryView.durationValueKey,
          labelText:
              label(context, 'zcrud.session.summary.duration', fallback: 'Durée'),
          valueText: _formatDuration(widget.duration),
        ),
      ],
    );
  }

  /// Boutons d'action — callbacks **injectés** (AC3).
  Widget _buildActions(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final onContinue = widget.onContinue;
    // `dueRemaining == 0` ⇒ bouton ABSENT (jamais grisé — patron AD-45). Idem
    // si aucun callback n'est fourni : un bouton qui ne fait rien est un
    // mensonge d'affordance.
    final showContinue = widget.dueRemaining > 0 && onContinue != null;

    // Le compte vient du paramètre INJECTÉ, jamais d'un recomptage : le patron
    // `{n}` laisse l'app placer le nombre où sa langue l'exige.
    final continueText = label(context, 'zcrud.session.summary.continue',
            fallback: 'Encore {n} dues')
        .replaceAll('{n}', '${widget.dueRemaining}');

    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapM,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _ActionButton(
          buttonKey: ZSessionSummaryView.finishButtonKey,
          text: label(context, 'zcrud.session.summary.finish',
              fallback: 'Terminer'),
          onPressed: widget.onFinish,
          filled: true,
        ),
        if (showContinue)
          _ActionButton(
            buttonKey: ZSessionSummaryView.continueButtonKey,
            text: continueText,
            onPressed: onContinue,
            filled: false,
          ),
      ],
    );
  }
}

/// Une tuile de stat : libellé + valeur **en texte** (couleur jamais seul canal,
/// AD-13), `Semantics` label/value **localisés**.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.valueKey,
    required this.labelText,
    required this.valueText,
  });

  final ValueKey<String> valueKey;
  final String labelText;
  final String valueText;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // ⚠️ La garde de libellés ne couvre PAS `Semantics(label:)` (angle mort
    // CONSIGNÉ) : ici, l'auto-discipline. `labelText` est DÉJÀ résolu par
    // `label(context, …)` chez l'appelant — aucun littéral ne transite.
    //
    // 🔴 Défaut MESURÉ (code-review su-5, D1) : sans cet `ExcludeSemantics`, les
    // libellés des DEUX `Text` FUSIONNENT avec ceux du `Semantics` parent et le
    // nœud annonce « Cartes\n8\nCartes — valeur : 8 » — le lecteur d'écran
    // BÉGAIE sur les 3 tuiles. C'est le MOTIF déjà corrigé sur `_ActionButton`
    // (`ExcludeSemantics`, plus bas) : un défaut trouvé est une CLASSE à
    // balayer, jamais une occurrence à patcher. Le libellé et la valeur sont
    // portés par le `Semantics` (canal UNIQUE) ; les deux `Text` ne sont que le
    // canal VISUEL du même contenu (AD-13 : la couleur n'est jamais seul canal,
    // le texte reste rendu). Gardé par un `getSemantics` sur les 3 tuiles —
    // l'assertion sur le `Text` VISUEL ne l'aurait jamais vu.
    return Semantics(
      label: labelText,
      value: valueText,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              valueText,
              key: valueKey,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: theme.gapS),
            Text(
              labelText,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton d'action — cible **≥ 48 dp**, `Semantics(button: true)`, libellé l10n
/// **déjà résolu** par l'appelant (AD-13).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.buttonKey,
    required this.text,
    required this.onPressed,
    required this.filled,
  });

  final ValueKey<String> buttonKey;
  final String text;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, filled ? 'primary' : 'neutral',
        slotIndex: filled ? 0 : 4);
    return Semantics(
      button: true,
      label: text,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: ZSessionSummaryView.minTarget,
          minHeight: ZSessionSummaryView.minTarget,
        ),
        child: Material(
          key: buttonKey,
          color: pair.color,
          borderRadius: BorderRadius.all(theme.radiusM),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Padding(
              padding: theme.fieldPadding,
              child: Center(
                widthFactor: 1,
                // 🔴 Défaut RÉEL démasqué par le test d'AC3 : sans cet
                // `ExcludeSemantics`, le libellé du `Text` FUSIONNE avec celui
                // du `Semantics` parent et le nœud annonce « Terminer\nTerminer »
                // — un lecteur d'écran le lit DEUX FOIS. Le libellé est porté
                // par le `Semantics` du bouton (canal unique) ; le `Text` n'est
                // ici que le canal VISUEL du même contenu.
                child: ExcludeSemantics(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pair.onColor),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tir de confetti — **CONFINÉ à ce fichier** (AC8), purement **décoratif**.
///
/// ## Réglages IMPOSÉS — lus dans les sources du paquet, pas devinés
///
/// | Fait lu | Réglage |
/// |---|---|
/// | `ConfettiController({duration = 30 s})` + `assert(duration.inMicroseconds > 0)` (`:501`) | [burstDuration] **explicite et courte** — jamais le défaut 30 s, jamais `Duration.zero` (**assert-fail**) |
/// | `_animationStatusListener` appelle `_continueAnimation()` **HORS** du `if (!shouldLoop)` (`:252-258`) ⇒ relance **inconditionnelle** | `shouldLoop: false` **et** `pumpAndSettle` **INTERDIT** côté test (peut ne jamais converger) |
/// | `pauseEmissionOnLowFrameRate = true` + `deltaTime` sur `DateTime.now()` (horloge **murale**) + `if (pauseEmission) return;` avant l'émission (`particle.dart:165`) | `pauseEmissionOnLowFrameRate: false` — et **aucune assertion sur les particules** (interne du paquet, non déterministe sous une horloge murale) |
/// | `colors: null` ⇒ couleurs **aléatoires** ; `strokeColor = Colors.black` en dur | `colors:` **injectées du thème** (NFR-SU5) |
/// | `grep Semantics confetti-0.8.0/lib/` → **RC=1** — **ZÉRO `Semantics`** | [ExcludeSemantics] : rien ne doit transiter par un canal que le lecteur d'écran ne voit pas |
class _ConfettiBurst extends StatelessWidget {
  const _ConfettiBurst({required this.controller});

  /// Durée du tir — **courte et explicite** (T1).
  static const Duration burstDuration = Duration(milliseconds: 800);

  final ConfettiController controller;

  @override
  Widget build(BuildContext context) {
    // T4 — couleurs INJECTÉES du thème (jamais `null` ⇒ aléatoire, jamais un
    // `Colors.*` : la garde de couleurs en dur rougirait, et à raison).
    final colors = <Color>[
      zResolveColorKeyOrSlot(context, 'primary', slotIndex: 0).color,
      zResolveColorKeyOrSlot(context, 'secondary', slotIndex: 1).color,
      zResolveColorKeyOrSlot(context, 'tertiary', slotIndex: 2).color,
    ];
    // T6 — le confetti est DÉCORATIF : aucune information n'y transite, et le
    // paquet n'expose aucun `Semantics`. Un apprenant au lecteur d'écran ne perd
    // donc RIEN (le bilan est porté par les stats et leurs `Semantics`).
    return ExcludeSemantics(
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        pauseEmissionOnLowFrameRate: false,
        colors: colors,
        numberOfParticles: 12,
        emissionFrequency: 0.05,
        gravity: 0.3,
      ),
    );
  }
}
