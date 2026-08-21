/// `ZSessionSummaryView` — écran de fin de session.
///
/// ## Il assemble. Il ne réimplémente rien
///
/// Les pièces existent, sont exportées et testées : il monte
/// `ZSessionQualityBreakdown` (alimenté par `result.byQuality` verbatim,
/// aucun recomptage) et `ZStudyProgressRings` (alimenté par
/// `ZProgressRingsData.fromResult(result)`, jamais un ratio recalculé).
/// `scale`/`passThreshold` dérivent de la `ZSrsConfig` injectée
/// (`ZQualityScale.fromConfig`, voie unique).
///
/// ## « Maîtrisées » n'est pas `result.correct`
///
/// `correct` compte les réponses de qualité au moins égale au seuil de
/// réussite (q3, q4 ou q5). Le glossaire du domaine définit « maîtrisée »
/// comme q4-5, un sous-ensemble strict. Afficher `correct` sous le libellé
/// « maîtrisées » serait un nombre juste attribué au mauvais concept.
/// [zMasteredCount] est donc dérivé de `byQuality`, avec un seuil consommé
/// depuis son propriétaire, `ZSrsConfig.masteredThreshold`, jamais un
/// littéral en dur ni redérivé ici. Les anneaux, eux, continuent d'afficher
/// `correct/total` : deux nombres différents, volontairement.
///
/// ## La durée est injectée
///
/// `ZStudySessionResult` ne porte aucune durée : le temps n'est mesuré que
/// par carte (`ZFlashcardSubmission.timeTaken`). L'ajouter au value-object
/// du kernel déclencherait le gate de rétro-compatibilité de sérialisation
/// d'un package hors périmètre de ce paquet, pour aucun bénéfice. Elle est
/// donc un paramètre de cet écran, mesuré par l'appelant.
///
/// ## Confinement de `confetti`
///
/// Ce fichier est le seul de `lib/` à importer `confetti` — le barrel ne le
/// réexporte pas, et aucun type du paquet n'apparaît en signature publique.
/// Réglages imposés par la lecture des sources du paquet (voir
/// `_ConfettiBurst`).
///
/// Widget pur (invariants AD-2/AD-15) : `StatefulWidget` sans aucun
/// gestionnaire d'état, controllers stables (create/dispose),
/// callbacks/thème/labels injectés, aucune écriture SRS, directionnel,
/// `Semantics`, cibles ≥ 48 dp (invariant AD-13).
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

/// Variante de célébration de l'écran de fin — un enum, jamais un booléen.
///
/// Le défaut est [ZSummaryCelebration.none] : le confetti est opt-in, jamais
/// subi. Un `bool showConfetti` interdirait d'ajouter
/// [ZSummaryCelebration.subtle] sans casser tous les appelants.
enum ZSummaryCelebration {
  /// Aucune célébration : le trophée n'est pas rendu, aucun confetti.
  none,

  /// Célébration sobre : trophée et halo animés, aucun confetti.
  subtle,

  /// Célébration complète : trophée, halo et un seul tir de confetti.
  ///
  /// Jamais sous Reduce Motion : le `ConfettiWidget` n'est alors pas
  /// construit du tout.
  confetti,
}

/// Recette visuelle optionnelle de la célébration du résumé.
///
/// Chaque champ `null` conserve explicitement le comportement historique. La
/// valeur est donc additive : une application peut ne surcharger qu'un détail
/// sans toucher aux autres réglages.
@immutable
class ZCelebrationSpec {
  /// Crée une recette de célébration partielle ou complète.
  ///
  /// Les bornes ci-dessous reprennent celles que `confetti` assertionne en
  /// interne (durée strictement positive, particules > 0, gravité et
  /// fréquence dans `[0, 1]`). Sans elles, une valeur invalide traverserait
  /// cette API publique sans bruit et n'échouerait qu'au fond du paquet
  /// tiers, avec un message sans rapport avec le préréglage fautif. Échouer
  /// ici nomme le vrai coupable — et `null` reste toujours licite : il
  /// signifie « garde le défaut historique ».
  const ZCelebrationSpec({
    this.burstDuration,
    this.numberOfParticles,
    this.gravity,
    this.emissionFrequency,
    this.entranceCurve,
    this.trophyIcon,
    this.trophyDecoration,
    this.ringsDiameter,
    this.ringsStrokeWidth,
    this.ringsTrackColorKey,
    this.ringsProgressColorKey,
  }) : // `burstDuration` n'est pas vérifiée ici : comparer deux `Duration`
       // n'est pas évaluable dans un `assert` de constructeur `const`
       // (opérateur non constant) — l'y mettre casserait la compilation de
       // tout appelant const. Sa validation vit donc au point de
       // consommation, dans `_ConfettiBurst`.
       assert(
         numberOfParticles == null || numberOfParticles > 0,
         'numberOfParticles doit être > 0 ; utiliser `null` pour le défaut.',
       ),
       assert(
         gravity == null || (gravity >= 0 && gravity <= 1),
         'gravity doit appartenir à [0, 1] ; utiliser `null` pour le défaut.',
       ),
       assert(
         emissionFrequency == null ||
             (emissionFrequency >= 0 && emissionFrequency <= 1),
         'emissionFrequency doit appartenir à [0, 1] ; `null` pour le défaut.',
       ),
       assert(
         ringsDiameter == null || ringsDiameter > 0,
         'ringsDiameter doit être > 0 ; utiliser `null` pour le défaut.',
       ),
       assert(
         ringsStrokeWidth == null || ringsStrokeWidth > 0,
         'ringsStrokeWidth doit être > 0 ; utiliser `null` pour le défaut.',
       );

  /// Durée du burst de confetti ; `null` conserve la durée historique.
  final Duration? burstDuration;

  /// Nombre de particules ; `null` conserve le défaut historique.
  final int? numberOfParticles;

  /// Gravité des particules ; `null` conserve le défaut historique.
  final double? gravity;

  /// Fréquence d'émission ; `null` conserve le défaut historique.
  final double? emissionFrequency;

  /// Courbe de l'animation d'entrée ; `null` délègue au token puis au défaut.
  final Curve? entranceCurve;

  /// Icône du trophée ; `null` conserve [Icons.emoji_events].
  final IconData? trophyIcon;

  /// Décor du halo ; `null` reconstruit le cercle historique résolu du thème.
  final BoxDecoration? trophyDecoration;

  /// Diamètre des anneaux ; `null` conserve `96`.
  final double? ringsDiameter;

  /// Épaisseur des anneaux ; `null` conserve `10`.
  final double? ringsStrokeWidth;

  /// Clé de couleur de piste des anneaux ; `null` conserve `neutral`.
  final String? ringsTrackColorKey;

  /// Clé de couleur de progression ; `null` conserve `primary`.
  final String? ringsProgressColorKey;
}

/// Compte des cartes maîtrisées — dérivé de [byQuality].
///
/// Ce n'est pas `result.correct` (`q >= passThreshold`, donc q3 et plus).
/// Ici : `q >= [masteredThreshold]` (q4-5 en échelle canonique).
///
/// - somme les comptes des crans de l'échelle dont `q >= masteredThreshold` ;
/// - une clé hors échelle (`'9'`, `'03'`, `''`) n'est jamais comptée : le
///   breakdown la signale à part, et une note que l'échelle ne reconnaît
///   pas ne peut pas être « maîtrisée » ;
/// - jamais de `throw` (invariant AD-10) : `byQuality` corrompu fait
///   ignorer les paires inconnues, jamais une exception.
///
/// Un cran négatif n'est jamais compté (invariant AD-10). Le décodage de
/// `ZStudySessionResult` ne filtre que le type (`is int`) : un `-3` venu
/// d'un document persisté corrompu traverse verbatim. Sans ce plancher,
/// l'écran afficherait « Maîtrisées : -1 » et le lecteur d'écran annoncerait
/// « moins un » — aucun throw, aucun test rouge. Le value-object lui-même
/// clampe déjà `total`/`correct` à `>= 0` : la norme du dépôt est explicite,
/// un compteur n'est jamais négatif. On clampe le cran (et non la somme) :
/// un `{'5': -3, '4': 2}` rend `2`, jamais `-1` — ignorer le cran aberrant,
/// sans laisser un autre cran valide compenser une valeur absurde.
///
/// Comparaison de chaîne exacte (`'$quality'`), comme
/// `ZSessionQualityBreakdown._isInScale` : les deux faces partagent le même
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
    // Plancher défensif (invariant AD-10) : un compteur n'est jamais négatif.
    count += raw < 0 ? 0 : raw;
  }
  return count;
}

/// Écran de fin de session — assemble, ne réimplémente rien.
class ZSessionSummaryView extends StatefulWidget {
  /// Construit l'écran de fin.
  ///
  /// - [result] : `ZStudySessionResult` injecté (value-object du kernel) ;
  /// - [duration] : durée de session injectée — le value-object ne la porte
  ///   pas ;
  /// - [config] : `ZSrsConfig`, source de `scale` et `passThreshold` ;
  /// - [onFinish] : callback « Terminer » injecté ;
  /// - [dueRemaining] : cartes encore dues (`0` : bouton « Encore N dues »
  ///   absent, jamais grisé) ;
  /// - [onContinue] : callback « Encore N dues » injecté ;
  /// - [celebration] : variante de célébration (défaut `none` : confetti
  ///   opt-in) ;
  /// - [masteredThreshold] : seuil de maîtrise — défaut consommé depuis
  ///   `config.masteredThreshold` (son propriétaire), jamais un littéral en
  ///   dur ni redérivé ici ;
  /// - [feedbackKey] : clé de message pédagogique (= `zFeedbackKeyFor(tier)`,
  ///   calculée par l'hôte via la fonction pure `zFeedbackTierFor` — ce
  ///   widget ne connaît aucune soumission) ;
  /// - [feedbackBank] : banque de messages — remplace intégralement la
  ///   banque par défaut.
  const ZSessionSummaryView({
    required this.result,
    required this.duration,
    required this.config,
    required this.onFinish,
    this.dueRemaining = 0,
    this.onContinue,
    this.celebration = ZSummaryCelebration.none,
    this.celebrationSpec,
    this.masteredThreshold,
    this.feedbackKey,
    this.feedbackBank,
    this.breakdownCoverage = ZQualityBreakdownCoverage.presentKeysOnly,
    super.key,
  });

  /// Résultat de session injecté (value-object pur du kernel).
  final ZStudySessionResult result;

  /// Durée de la session — injectée (le value-object ne la porte pas).
  ///
  /// Une durée négative (horloge incohérente) est affichée `00:00` — jamais
  /// un temps négatif, jamais une exception (invariant AD-10).
  final Duration duration;

  /// Config SRS injectée : source unique de l'échelle et du seuil.
  final ZSrsConfig config;

  /// Callback « Terminer » — voie unique de sortie.
  final VoidCallback onFinish;

  /// Cartes encore dues. `0` : bouton « Encore N dues » absent.
  final int dueRemaining;

  /// Callback « Encore N dues ». `null` : bouton absent (rien à faire).
  final VoidCallback? onContinue;

  /// Variante de célébration (défaut `none` : confetti opt-in).
  final ZSummaryCelebration celebration;

  /// Recette optionnelle de célébration ; les champs `null` gardent le rendu
  /// historique.
  final ZCelebrationSpec? celebrationSpec;

  /// Seuil de maîtrise injecté. `null` : consommé depuis son propriétaire,
  /// `config.masteredThreshold`, jamais redérivé ici.
  final int? masteredThreshold;

  /// Clé l10n du message pédagogique, ou `null` (aucun message rendu).
  final String? feedbackKey;

  /// Banque de messages injectée — surcharge intégrale.
  final ZFeedbackBank? feedbackBank;

  /// Couverture de la répartition, passée telle quelle à
  /// [ZSessionQualityBreakdown]. Défaut historique : seules les clés
  /// présentes.
  ///
  /// Sans ce pass-through, une application montant ce widget ne pourrait pas
  /// atteindre une répartition à longueur stable : le breakdown est
  /// construit ici, pas par l'appelant.
  final ZQualityBreakdownCoverage breakdownCoverage;

  /// [ValueKey] du bouton « Terminer », pour la testabilité.
  static const ValueKey<String> finishButtonKey = ValueKey<String>(
    'zSummaryFinish',
  );

  /// [ValueKey] du bouton « Encore N dues », pour la testabilité.
  static const ValueKey<String> continueButtonKey = ValueKey<String>(
    'zSummaryContinue',
  );

  /// [ValueKey] de la valeur « cartes totales », pour la testabilité.
  static const ValueKey<String> totalValueKey = ValueKey<String>(
    'zSummaryTotalValue',
  );

  /// [ValueKey] de la valeur « maîtrisées », pour la testabilité.
  static const ValueKey<String> masteredValueKey = ValueKey<String>(
    'zSummaryMasteredValue',
  );

  /// [ValueKey] de la valeur « durée », pour la testabilité.
  static const ValueKey<String> durationValueKey = ValueKey<String>(
    'zSummaryDurationValue',
  );

  /// [ValueKey] de l'icône du trophée — sonde d'échelle.
  ///
  /// L'échelle se mesure sur la géométrie peinte (`tester.getRect`), jamais
  /// sur le champ `transform` du widget : `Transform.scale` ne le peuple pas.
  static const ValueKey<String> trophyIconKey = ValueKey<String>(
    'zSummaryTrophyIcon',
  );

  /// [ValueKey] du halo (`Opacity`) — sonde d'opacité.
  static const ValueKey<String> glowKey = ValueKey<String>('zSummaryGlow');

  /// Cible tap minimale (dp), invariant AD-13.
  static const double minTarget = 48;

  /// Durée de l'animation d'entrée (trophée + halo).
  static const Duration entranceDuration = Duration(milliseconds: 600);

  @override
  State<ZSessionSummaryView> createState() => ZSessionSummaryViewState();
}

/// État de [ZSessionSummaryView] — public pour exposer le compteur de tirs
/// aux tests.
class ZSessionSummaryViewState extends State<ZSessionSummaryView>
    with SingleTickerProviderStateMixin {
  /// Controller d'entrée stable (créé une fois, disposé une fois, invariant
  /// AD-2 : jamais recréé au rebuild).
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: ZSessionSummaryView.entranceDuration,
  );

  /// Controller de confetti — possédé par ce `State`, `null` tant qu'aucun
  /// tir n'est parti (et à jamais sous Reduce Motion ou hors opt-in).
  ConfettiController? _confetti;

  /// Latch one-shot du tir.
  bool _celebrationFired = false;

  /// Latch de démarrage de l'animation d'entrée (`didChangeDependencies` est
  /// ré-entrant — il refire à chaque changement de `MediaQuery`).
  bool _entranceStarted = false;

  int _celebrationPlays = 0;

  /// Nombre de tirs de confetti réellement déclenchés, un seam de test.
  ///
  /// On assère sur ce compteur, sur la présence du `ConfettiWidget` et sur
  /// ses réglages — jamais sur les particules : le paquet calcule son
  /// `deltaTime` sur l'horloge murale (`DateTime.now()`), donc le nombre de
  /// particules d'une frame de test n'est pas déterministe. C'est un détail
  /// d'implémentation du paquet tiers ; une assertion dessus serait fausse
  /// pour la mauvaise raison.
  @visibleForTesting
  int get celebrationPlays => _celebrationPlays;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `zReduceMotionOf` est la primitive unique (jamais un
    // `MediaQuery.of(context).disableAnimations` réécrit). Lue ici :
    // `MediaQuery` est une dépendance héritée, donc un changement de
    // réglage système nous rappelle.
    final reduceMotion = zReduceMotionOf(context);
    if (reduceMotion) {
      // Dégradation de l'animation, jamais de la fonction : l'état final
      // est rendu immédiatement (pas de `forward`, pas d'interpolation).
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
    // Le latch survit aux rebuilds : `celebration` passant à `confetti`
    // après coup ne redéclenche rien si un tir est déjà parti (un seul tir).
    _maybeCelebrate(reduceMotion: zReduceMotionOf(context));
  }

  /// Déclenche le tir — au plus une fois dans la vie du widget.
  void _maybeCelebrate({required bool reduceMotion}) {
    if (_celebrationFired) return; // one-shot.
    if (widget.celebration != ZSummaryCelebration.confetti) return;
    // Sous Reduce Motion, on ne construit jamais le confetti — et surtout
    // pas avec une durée nulle : `ConfettiController` assertionne une durée
    // strictement positive, et `Duration.zero` ferait échouer cet assert.
    if (reduceMotion) return;

    _celebrationFired = true;
    _celebrationPlays++;
    final spec = widget.celebrationSpec;
    final candidate =
        spec?.burstDuration ??
        ZcrudTheme.of(context).celebrationDuration ??
        _ConfettiBurst.burstDuration;
    // Repli défensif (invariant AD-10) sur une durée non strictement
    // positive. `ConfettiController` assertionne une durée strictement
    // positive : une valeur nulle ferait planter le bilan de session,
    // l'écran de fin d'apprentissage, au pire moment possible. La source ne
    // peut pas être fermée en amont : le token de thème est interpolé
    // pendant les transitions et transite par du code hôte. On retombe donc
    // sur le défaut historique plutôt que de laisser lever.
    final burstDuration = candidate > Duration.zero
        ? candidate
        : _ConfettiBurst.burstDuration;
    setState(() {
      _confetti = ConfettiController(duration: burstDuration)..play();
    });
  }

  @override
  void dispose() {
    // Ordre important, vérifié dans les sources du paquet : Flutter démonte
    // les enfants d'abord, donc le `State` du `ConfettiWidget` a déjà retiré
    // son listener quand on arrive ici. Notre `dispose()` ne peut donc pas
    // notifier un `State` démonté, alors que `ConfettiController.dispose()`
    // notifie ses écouteurs avant d'appeler `super.dispose()`.
    _confetti?.dispose();
    _entrance.dispose();
    super.dispose();
  }

  /// Formate une durée en `mm:ss` — défensif (invariant AD-10).
  ///
  /// Une durée négative (horloge incohérente, mesure absente) rend `00:00` :
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
    // L'échelle dérive de la config : jamais redéclarée ici.
    final scale = ZQualityScale.fromConfig(widget.config);
    // Défaut consommé depuis son propriétaire, `ZSrsConfig`, jamais
    // redérivé ici et jamais un littéral en dur : le seuil de maîtrise est
    // possédé par `ZSrsConfig.masteredThreshold` parce que les filtres de
    // test vivent en amont, dans `zcrud_flashcard`, et qu'un paquet en
    // amont ne peut pas importer un aval (invariant AD-1). Le point
    // d'injection `widget.masteredThreshold` reste disponible : seul le
    // défaut change de foyer.
    final masteredThreshold =
        widget.masteredThreshold ?? widget.config.masteredThreshold;
    final mastered = zMasteredCount(
      widget.result.byQuality,
      scale,
      masteredThreshold,
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (widget.celebration != ZSummaryCelebration.none) ...<Widget>[
          _buildCelebrationHeader(context),
          SizedBox(height: theme.gapL),
        ],
        Text(
          label(
            context,
            'zcrud.session.summary.title',
            fallback: 'Session terminée',
          ),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        SizedBox(height: theme.gapM),
        // Les anneaux sont alimentés par la fonction pure du DTO : jamais un
        // ratio recalculé ici. `total == 0` donne un ratio de 0 (aucune
        // division par zéro) ; `correct > total` donne un ratio clampé.
        ZStudyProgressRings(
          data: ZProgressRingsData.fromResult(widget.result),
          diameter: widget.celebrationSpec?.ringsDiameter ?? 96,
          strokeWidth: widget.celebrationSpec?.ringsStrokeWidth ?? 10,
          trackColorKey:
              widget.celebrationSpec?.ringsTrackColorKey ?? 'neutral',
          progressColorKey:
              widget.celebrationSpec?.ringsProgressColorKey ?? 'primary',
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
        // `byQuality` verbatim (aucun recomptage), `scale`/`passThreshold`
        // dérivés de la config.
        ZSessionQualityBreakdown(
          byQuality: widget.result.byQuality,
          scale: scale,
          passThreshold: widget.config.passThreshold,
          coverage: widget.breakdownCoverage,
        ),
        SizedBox(height: theme.gapL),
        _buildActions(context),
      ],
    );

    // Jamais `ListView(children: [...])` — et un écran de fin doit rester
    // lisible en textScaler élevé ou en paysage : le contenu défile plutôt
    // que de déborder.
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
        _ConfettiBurst(controller: confetti, spec: widget.celebrationSpec),
      ],
    );
  }

  /// En-tête de célébration : halo et trophée — animations réelles.
  ///
  /// `AnimatedBuilder` n'abonne que ce sous-arbre au controller (invariant
  /// AD-2 : rebuild granulaire, le reste de l'écran ne se reconstruit pas à
  /// chaque frame).
  Widget _buildCelebrationHeader(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final pair = zResolveColorKeyOrSlot(context, 'primary', slotIndex: 0);
    final spec = widget.celebrationSpec;
    final entranceCurve = spec?.entranceCurve ?? theme.celebrationCurve;
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final trophyScale = 0.6 +
            0.4 *
                (entranceCurve ?? Curves.elasticOut).transform(_entrance.value);
        final glowOpacity =
            (entranceCurve ?? Curves.easeIn).transform(_entrance.value);
        return Opacity(
          key: ZSessionSummaryView.glowKey,
          opacity: glowOpacity.clamp(0.0, 1.0),
          child: Transform.scale(scale: trophyScale, child: child),
        );
      },
      // `child` est construit une fois et réutilisé à chaque frame (jamais
      // reconstruit dans la closure, invariant AD-2).
      //
      // Le repli du trophée porte la célébration seule (« Bravo »), distinct
      // du titre qui porte le fait (« Session terminée ») : deux nœuds
      // sémantiques annonçant des contenus proches mais non identiques.
      child: Semantics(
        label: label(
          context,
          'zcrud.session.summary.celebration',
          fallback: 'Bravo',
        ),
        child: Container(
          padding: theme.fieldPadding,
          decoration:
              spec?.trophyDecoration ??
              BoxDecoration(color: pair.color, shape: BoxShape.circle),
          child: Icon(
            spec?.trophyIcon ?? Icons.emoji_events,
            key: ZSessionSummaryView.trophyIconKey,
            size: theme.gapL * 2,
            color: pair.onColor,
          ),
        ),
      ),
    );
  }

  /// Bloc de stats : totales, maîtrisées, durée.
  Widget _buildStats(BuildContext context, {required int mastered}) {
    final theme = ZcrudTheme.of(context);
    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapS,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _StatTile(
          valueKey: ZSessionSummaryView.totalValueKey,
          labelText: label(
            context,
            'zcrud.session.summary.total',
            fallback: 'Cartes',
          ),
          valueText: '${widget.result.total}',
        ),
        // « Maîtrisées » (q4-5), jamais `result.correct` (q3 et plus). Les
        // anneaux ci-dessus affichent `correct/total` : deux nombres
        // différents, volontairement.
        _StatTile(
          valueKey: ZSessionSummaryView.masteredValueKey,
          labelText: label(
            context,
            'zcrud.session.summary.mastered',
            fallback: 'Maîtrisées',
          ),
          valueText: '$mastered',
        ),
        _StatTile(
          valueKey: ZSessionSummaryView.durationValueKey,
          labelText: label(
            context,
            'zcrud.session.summary.duration',
            fallback: 'Durée',
          ),
          valueText: _formatDuration(widget.duration),
        ),
      ],
    );
  }

  /// Boutons d'action — callbacks injectés.
  Widget _buildActions(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final onContinue = widget.onContinue;
    // `dueRemaining == 0` : bouton absent, jamais grisé. Idem si aucun
    // callback n'est fourni : un bouton qui ne fait rien est un mensonge
    // d'affordance.
    final showContinue = widget.dueRemaining > 0 && onContinue != null;

    // Le compte vient du paramètre injecté, jamais d'un recomptage : le
    // patron `{n}` laisse l'application placer le nombre où sa langue l'exige.
    final continueText = label(
      context,
      'zcrud.session.summary.continue',
      fallback: 'Encore {n} dues',
    ).replaceAll('{n}', '${widget.dueRemaining}');

    return Wrap(
      spacing: theme.gapM,
      runSpacing: theme.gapM,
      alignment: WrapAlignment.center,
      children: <Widget>[
        _ActionButton(
          buttonKey: ZSessionSummaryView.finishButtonKey,
          text: label(
            context,
            'zcrud.session.summary.finish',
            fallback: 'Terminer',
          ),
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

/// Une tuile de stat : libellé et valeur en texte (couleur jamais seul
/// canal, invariant AD-13), `Semantics` label/value localisés.
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
    // `labelText` est déjà résolu par `label(context, …)` chez l'appelant :
    // aucun littéral ne transite ici — la garde de libellés ne couvre pas
    // `Semantics(label:)`, d'où cette discipline manuelle.
    //
    // Sans cet `ExcludeSemantics`, les libellés des deux `Text` fusionneraient
    // avec ceux du `Semantics` parent et le nœud annoncerait « Cartes\n8\n
    // Cartes — valeur : 8 », le lecteur d'écran bégayant sur les trois
    // tuiles. Le libellé et la valeur sont portés par le `Semantics` (canal
    // unique) ; les deux `Text` ne sont que le canal visuel du même contenu
    // (invariant AD-13 : la couleur n'est jamais seul canal, le texte reste
    // rendu).
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

/// Bouton d'action — cible ≥ 48 dp, `Semantics(button: true)`, libellé l10n
/// déjà résolu par l'appelant (invariant AD-13).
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
    final pair = zResolveColorKeyOrSlot(
      context,
      filled ? 'primary' : 'neutral',
      slotIndex: filled ? 0 : 4,
    );
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
                // Sans cet `ExcludeSemantics`, le libellé du `Text` fusionnerait
                // avec celui du `Semantics` parent et le nœud annoncerait
                // « Terminer\nTerminer », un lecteur d'écran le lisant deux
                // fois. Le libellé est porté par le `Semantics` du bouton
                // (canal unique) ; le `Text` n'est ici que le canal visuel
                // du même contenu.
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

/// Tir de confetti — confiné à ce fichier, purement décoratif.
///
/// ## Réglages imposés — lus dans les sources du paquet, pas devinés
///
/// | Fait lu | Réglage |
/// |---|---|
/// | `ConfettiController` assertionne une durée strictement positive et vaut 30 s par défaut | [burstDuration] explicite et courte — jamais le défaut, jamais `Duration.zero` (assert-fail) |
/// | le paquet relance son animation inconditionnellement, hors du drapeau `shouldLoop` | `shouldLoop: false` et `pumpAndSettle` interdit côté test (peut ne jamais converger) |
/// | `pauseEmissionOnLowFrameRate` par défaut suspend l'émission selon une horloge murale (`DateTime.now()`) | `pauseEmissionOnLowFrameRate: false` — et aucune assertion sur les particules, non déterministes sous une horloge murale |
/// | `colors: null` donne des couleurs aléatoires ; le trait est noir en dur | `colors:` injectées du thème |
/// | le paquet n'expose aucun `Semantics` | [ExcludeSemantics] : rien ne doit transiter par un canal que le lecteur d'écran ne voit pas |
class _ConfettiBurst extends StatelessWidget {
  const _ConfettiBurst({required this.controller, required this.spec});

  /// Durée du tir — courte et explicite.
  static const Duration burstDuration = Duration(milliseconds: 800);

  final ConfettiController controller;

  final ZCelebrationSpec? spec;

  @override
  Widget build(BuildContext context) {
    // Couleurs injectées du thème (jamais `null`, ce qui donnerait de
    // l'aléatoire, jamais un `Colors.*` en dur).
    final colors = <Color>[
      zResolveColorKeyOrSlot(context, 'primary', slotIndex: 0).color,
      zResolveColorKeyOrSlot(context, 'secondary', slotIndex: 1).color,
      zResolveColorKeyOrSlot(context, 'tertiary', slotIndex: 2).color,
    ];
    // Le confetti est décoratif : aucune information n'y transite, et le
    // paquet n'expose aucun `Semantics`. Un apprenant au lecteur d'écran ne
    // perd donc rien (le bilan est porté par les stats et leurs `Semantics`).
    return ExcludeSemantics(
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        pauseEmissionOnLowFrameRate: false,
        colors: colors,
        numberOfParticles: spec?.numberOfParticles ?? 12,
        emissionFrequency: spec?.emissionFrequency ?? 0.05,
        gravity: spec?.gravity ?? 0.3,
      ),
    );
  }
}
