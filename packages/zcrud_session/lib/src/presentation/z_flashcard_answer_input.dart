/// Surface de saisie notée `ZFlashcardAnswerInput`.
///
/// ## L'arène des gestes — le point de conception principal
///
/// Sur le chemin d'usage documenté (`contentBuilder:
/// ZFlashcardMarkdownContent.builder()`), un `QuillEditor` gagnerait l'arène
/// des gestes contre l'`InkWell` de la carte d'affichage : le tap de
/// révélation ne recevrait rien, la réponse n'apparaissant jamais, y
/// compris avec une suite de tests par ailleurs entièrement verte. Le
/// correctif est un `IgnorePointer` sur le sous-arbre du slot de contenu
/// (`z_flashcard_review_card.dart`), légitime parce que ce sous-arbre est de
/// l'affichage.
///
/// Cette surface introduit la saisie : le contenu doit redevenir
/// interactif — mais pas n'importe où. Le conflit n'est ni arbitré par
/// priorité de geste, ni « réglé » en retirant le correctif de la carte
/// d'affichage : il est dissous par construction —
///
/// | Zone | Régime | Pourquoi |
/// |---|---|---|
/// | Contenu | [IgnorePointer] maintenu | c'est de l'affichage, même ici : sans cela un `QuillEditor` volerait le geste aux contrôles de saisie |
/// | Contrôles de saisie | seuls interactifs | ce sont les seuls capteurs de geste de la surface |
/// | Révélation par tap | absente | la correction est causée par la soumission, jamais par un tap |
///
/// « Répondre » et « dévoiler » sont mutuellement exclusifs. Un apprenant
/// noté ne peut pas dévoiler la réponse d'un tap — ce serait tricher et
/// voler le geste au contrôle de saisie. `ZFlashcardReviewCard` reste la
/// surface d'affichage avec sa révélation par tap ; celle-ci est la surface
/// de saisie, sans tap-to-reveal. Un hôte qui compose les deux les compose
/// en frères (sous-arbres disjoints), donc aucune arène commune.
///
/// Interdit : retirer ou affaiblir l'`IgnorePointer` du contenu ; poser un
/// `Dismissible`/`onHorizontalDrag` (le swipe appartient à
/// `ZSessionCardSwiper`).
///
/// ## Ce que cette surface n'écrit pas
///
/// Rien. Elle émet un fait ([ZFlashcardSubmission]) via `onSubmitted` ;
/// l'hôte branche `onQualitySelected` sur `ZSessionReviewer.reviewCard` —
/// l'unique voie d'écriture SRS du dépôt (invariant AD-9). Le danger est
/// local : `zcrud_flashcard` (dont ce package dépend) contient
/// `ZSm2Scheduler`, `ZSrsScheduler` et `ZRepetitionStore` — tous
/// atteignables d'ici. Une garde de pureté du paquet interdit de les
/// mentionner.
///
/// ## L'ordre d'attribution de la qualité
///
/// ```text
/// QCM/VF     → zEvaluateLocally (max/minQuality)  ─┐
/// rédigée    → clampQuality(port.suggestedQuality) ─┤
/// repli      → passThreshold                       ─┼→ zApplyHintCeiling(...) → quality
/// « Je ne sais pas » → minQuality                  ─┘   ▲ une seule voie, en dernier
/// ```
///
/// Aucune borne en dur : tout vient de [ZSrsConfig]. Le plafond est
/// appliqué en dernier, sur la valeur rendue — un port qui suggère dix
/// indices ne contourne pas le plafond.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, setEquals;
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

/// Construit le contenu visuel d'un choix de réponse.
///
/// Le builder reçoit le [ZChoice] complet afin qu'un hôte puisse rendre son
/// contenu riche sans que cette surface dépende d'un moteur d'édition.
typedef ZFlashcardChoiceContentBuilder =
    Widget Function(BuildContext context, ZChoice choice);

/// Construit le champ de réponse rédigée.
///
/// Le builder reçoit le `controller` et le `focusNode` **détenus par la
/// surface** : les réutiliser est obligatoire, sinon la valeur saisie ne part
/// pas au barème (la soumission lit ce controller-là, et lui seul). Le
/// `validator` est déjà localisé et mémoïsé ; `isSubmitted` porte le verrou
/// à appliquer au champ (le rendre inerte, sans le vider).
typedef ZFlashcardWrittenAnswerFieldBuilder =
    Widget Function(
      BuildContext context, {
      required TextEditingController controller,
      required FocusNode focusNode,
      required FormFieldValidator<String> validator,
      required bool isSubmitted,
    });

/// Représentation courante de la réponse en cours de saisie.
///
/// Instantané advisory : la surface reste propriétaire de son état. Écrire
/// dans cet objet ne change rien à la saisie.
@immutable
class ZFlashcardAnswerDraft {
  /// Construit un instantané de réponse.
  const ZFlashcardAnswerDraft({
    this.text = '',
    this.selectedChoiceIndexes = const <int>{},
    this.answeredTrue,
  });

  /// Texte rédigé courant (`''` hors carte à rédaction).
  final String text;

  /// Positions cochées d'un QCM (vide hors QCM).
  ///
  /// Ce sont des **positions**, jamais des identifiants : `ZChoice` n'en
  /// porte pas, et deux choix peuvent avoir le même contenu.
  final Set<int> selectedChoiceIndexes;

  /// Réponse d'un Vrai/Faux (`null` hors Vrai/Faux, et tant que rien n'est
  /// répondu).
  final bool? answeredTrue;

  @override
  bool operator ==(Object other) =>
      other is ZFlashcardAnswerDraft &&
      other.text == text &&
      other.answeredTrue == answeredTrue &&
      setEquals(other.selectedChoiceIndexes, selectedChoiceIndexes);

  @override
  int get hashCode =>
      Object.hash(text, answeredTrue, Object.hashAllUnordered(
        selectedChoiceIndexes,
      ));

  @override
  String toString() =>
      'ZFlashcardAnswerDraft(text: $text, '
      'selectedChoiceIndexes: $selectedChoiceIndexes, '
      'answeredTrue: $answeredTrue)';
}

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

  /// Réponse donnée par l'utilisateur sur un Vrai/Faux (`null` hors V/F).
  ///
  /// Nécessaire au canal de correction (invariant AD-13) : sans elle, la
  /// surface ne pourrait pas distinguer « le bouton que vous avez tapé » de
  /// « l'autre » — les deux se griseraient à l'identique et l'apprenant
  /// n'apprendrait jamais qu'il s'était trompé.
  final bool? answeredTrue;
}

/// Surface de saisie notée d'une flashcard.
///
/// Ne pose aucun tap-to-reveal : la correction est causée par la soumission.
class ZFlashcardAnswerInput extends StatefulWidget {
  /// Construit la surface de saisie.
  const ZFlashcardAnswerInput({
    required this.card,
    required this.mode,
    this.srsConfig = const ZSrsConfig(),
    this.contentBuilder,
    this.choiceContentBuilder,
    this.writtenAnswerFieldBuilder,
    this.initialAnswer,
    this.onAnswerChanged,
    this.isSubmitted,
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

  /// Carte à répondre — jamais mutée : les indices générés sont éphémères,
  /// jamais persistés sur la carte.
  final ZFlashcard card;

  /// Mode de session — alimente la table unique [zDefaultAdvanceBehavior].
  final ZReviewMode mode;

  /// Configuration SRS — propriétaire de l'échelle.
  final ZSrsConfig srsConfig;

  /// Slot de rendu du contenu (`null` : défaut texte brut thématisé).
  final ZFlashcardContentBuilder? contentBuilder;

  /// Slot de rendu du contenu de chaque choix.
  ///
  /// `null` conserve le [Text] brut historique, au même emplacement dans la
  /// ligne. Le builder ne remplace ni la sélection, ni les sémantiques, ni la
  /// cible tactile : il ne produit que l'enfant du `Expanded` du libellé.
  final ZFlashcardChoiceContentBuilder? choiceContentBuilder;

  /// Slot de rendu du champ de réponse rédigée.
  ///
  /// `null` conserve le `TextFormField` historique. Le builder remplace le
  /// champ, et lui seul : les `Semantics` de la zone de saisie, le verrou de
  /// soumission et la place du champ dans la colonne restent ceux de la
  /// surface. Sans effet sur un QCM ou un Vrai/Faux, qui n'ont pas de champ.
  final ZFlashcardWrittenAnswerFieldBuilder? writtenAnswerFieldBuilder;

  /// Réponse rédigée préremplie, appliquée **une seule fois, au montage**.
  ///
  /// Jamais réinjectée ensuite : une valeur repoussée dans le controller à
  /// chaque build écraserait la sélection et le curseur de l'utilisateur en
  /// pleine frappe. Changer cette valeur sur une surface déjà montée est donc
  /// sans effet — pour repartir d'un autre brouillon, remontez la surface
  /// (`key` distincte).
  ///
  /// Un changement de carte remet le champ à vide, comme sans ce paramètre.
  final String? initialAnswer;

  /// Observe la réponse en cours (`null` : rien n'est observé).
  ///
  /// Émis à chaque changement de saisie : frappe dans le champ rédigé,
  /// (dé)cochage d'un choix, et tap d'un Vrai/Faux — dans ce dernier cas
  /// juste avant la soumission qu'il déclenche. Purement advisory : la
  /// surface reste propriétaire de son état.
  ///
  /// Jamais émis au montage, ni au changement de carte : la valeur initiale
  /// et la remise à zéro ne sont pas des saisies de l'utilisateur.
  ///
  /// Ne reconstruit rien : la notification part d'un écouteur, pas d'un
  /// `setState`. Ce que l'hôte fait de la valeur reçue lui appartient — la
  /// remonter dans son propre état reconstruira son arbre à lui, à chaque
  /// frappe.
  final ValueChanged<ZFlashcardAnswerDraft>? onAnswerChanged;

  /// Verrou de soumission imposé (`null` : la correction locale décide).
  ///
  /// `true` rend la saisie inerte — choix, boutons Vrai/Faux, champ rédigé,
  /// « Indice » et « Je ne sais pas » — exactement comme après une
  /// soumission interne, mais **sans peindre de correction** : la surface
  /// n'en a pas fabriqué. Utile à un hôte qui gouverne lui-même la fin de
  /// réponse (examen minuté, remise groupée).
  ///
  /// `false` maintient les affordances visibles, mais ne rouvre pas une
  /// soumission déjà consommée : le verrou interne « une carte, au plus une
  /// soumission » reste seul maître de ce qui part au barème.
  final bool? isSubmitted;

  /// Port d'évaluation advisory (`null` : repli qualité neutre).
  ///
  /// Jamais appelé pour un QCM/Vrai-Faux : l'évaluation locale y est
  /// déterministe et n'a pas besoin d'un port.
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Offre, à chaque soumission, une voie « évaluer sans IA » qui n'appelle
  /// pas [evaluationPort]. `false` par défaut.
  ///
  /// Le choix avec/sans IA peut être modélisé comme une propriété de
  /// construction (port fourni ou non) ; un hôte qui l'offre comme
  /// affordance d'interaction — bouton d'auto-évaluation à côté du bouton
  /// IA — a besoin, lui, de ne pas remonter le widget entier à chaque
  /// bascule. Les deux modèles sont cohérents ; ce drapeau permet le second.
  ///
  /// Sans effet si [evaluationPort] est `null` (il n'y a alors rien à esquiver).
  final bool allowSkipEvaluation;

  /// Clé du bouton « évaluer sans IA », pour la testabilité.
  static const ValueKey<String> skipEvaluationKey = ValueKey<String>(
    'zSkipEvaluation',
  );

  /// Port d'indices (`null` : bouton « Indice » absent après épuisement du
  /// stocké — absent si non fourni, jamais grisé).
  final ZFlashcardHintPort? hintPort;

  /// Sert l'indice stocké de la carte d'emblée, sans geste. `false` par
  /// défaut — le bouton « Indice » reste l'unique voie.
  ///
  /// L'indice est une ressource consommée et pénalisée par défaut, mais sa
  /// visibilité est une décision distincte : ce drapeau permet le modèle
  /// « aide toujours offerte », courant dans les jeux de cartes, sans faire
  /// disparaître de l'écran un contenu que l'hôte veut afficher.
  ///
  /// La pénalité reste gouvernée par [hintPolicy], indépendamment de ce
  /// drapeau : un indice révélé d'emblée est compté (`hintsUsed`) et
  /// plafonne la qualité comme tout autre. Pour l'offrir sans coût,
  /// neutralisez le plafond (`ZHintPenaltyPolicy(floor: config.maxQuality)`) —
  /// visibilité et pénalité restent deux décisions distinctes, jamais
  /// couplées en douce.
  final bool revealStoredHint;

  /// Politique de plafond d'indices (plancher dérivé par défaut).
  final ZHintPenaltyPolicy hintPolicy;

  /// Mode d'affichage du minuteur (défaut `hidden`).
  ///
  /// Le temps est toujours mesuré, même en `hidden`.
  final ZTimerDisplay timerDisplay;

  /// Limite de temps — requise par `countdown` ; `null` dégrade en
  /// `elapsed` (invariant AD-10 : jamais de rebours depuis `null`).
  final Duration? timeLimit;

  /// Comportement d'avance — `null` : table unique [zDefaultAdvanceBehavior].
  final ZCardAdvanceBehavior? advanceBehavior;

  /// Délai d'auto-passage (défaut 200 ms).
  final Duration autoAdvanceDelay;

  /// Régime d'apparition de la correction — défaut
  /// [ZCorrectionVisibility.immediate], comportement historique inchangé.
  ///
  /// Gate de rendu uniquement : en [ZCorrectionVisibility.deferred], la
  /// correction est posée (donc la saisie est verrouillée : `onTap`/
  /// `onPressed` à `null`, bouton de soumission retiré, `_submitLocked`
  /// armé) mais jamais peinte. Voir la dartdoc de [ZCorrectionVisibility] :
  /// mêler ce gate au verrou rouvrirait la double soumission.
  final ZCorrectionVisibility correctionVisibility;

  /// Émis à la soumission (advisory : cette surface n'écrit rien).
  final ValueChanged<ZFlashcardSubmission>? onSubmitted;

  /// Voie unique de notation — `null` : rangée SRS absente, jamais un
  /// booléen `showQualityButtons`.
  final ValueChanged<int>? onQualitySelected;

  /// Demande d'avance à la carte suivante (cette surface ne navigue pas
  /// elle-même).
  final VoidCallback? onAdvance;

  /// Voie unique de résolution du builder du slot de contenu.
  ///
  /// Tear-off statique, jamais `?? (c, s) => …` : une closure serait
  /// réallouée à chaque build, changerait d'identité et casserait la
  /// stabilité des rebuilds.
  ///
  /// Publique (`@visibleForTesting`) pour qu'un test puisse observer que le
  /// builder résolu est `identical()` entre deux builds — un accesseur
  /// privé serait invérifiable depuis l'extérieur du `State`.
  @visibleForTesting
  static ZFlashcardContentBuilder resolveContentBuilder(
    ZFlashcardContentBuilder? injected,
  ) => injected ?? ZFlashcardDefaultContent.builder;

  @override
  State<ZFlashcardAnswerInput> createState() => _ZFlashcardAnswerInputState();
}

class _ZFlashcardAnswerInputState extends State<ZFlashcardAnswerInput> {
  /// Mesure de temps toujours armée, y compris en `ZTimerDisplay.hidden` :
  /// l'affichage est un réglage d'UI, pas une condition de mesure.
  /// `timeTaken` est lu ici à la soumission.
  final Stopwatch _stopwatch = Stopwatch();

  /// Ticker d'affichage — armé uniquement si le minuteur est visible (en
  /// `hidden`, un tick réveillerait l'arbre pour rien). `cancel()` au dispose.
  ///
  /// Ré-examiné à chaque `didUpdateWidget` ([_syncTicker]) : `timerDisplay`
  /// est une prop mutable, pas une constante de montage. Sans ce ré-examen,
  /// une bascule `hidden → elapsed` à chaud figerait l'affichage à `00:00`
  /// pour toujours pendant que [_stopwatch] compterait et que `timeTaken`
  /// partirait au barème — l'apprenant chronométré sans le voir.
  Timer? _ticker;

  /// Période du ticker d'affichage (granularité de la seconde).
  static const Duration _tickPeriod = Duration(seconds: 1);

  /// Timer d'auto-passage — `cancel()` au dispose et garde `mounted`.
  Timer? _advanceTimer;

  /// Temps affiché, cumulé par le ticker — tranche du minuteur : un tick ne
  /// reconstruit que le `ValueListenableBuilder` abonné, jamais la carte,
  /// jamais le champ.
  ///
  /// L'affichage cumule les ticks plutôt que de relire [_stopwatch] à
  /// chaque tick : ce sont deux besoins distincts. La mesure (`timeTaken`,
  /// envoyée au barème) doit être exacte, d'où [_stopwatch], qui lit
  /// l'horloge réelle. L'affichage, lui, n'a besoin que de progresser à la
  /// seconde et est piloté par le ticker : le lier à l'horloge réelle à
  /// chaque tick le rendrait invérifiable en test (le temps virtuel d'un
  /// test fait avancer les `Timer`, mais pas un `Stopwatch`, qui n'est pas
  /// simulable).
  ///
  /// [_stopwatch] reste néanmoins la source de mesure unique : l'affichage
  /// en dérive à chaque (ré)armement du ticker ([_syncTicker] :
  /// `_elapsed = _stopwatch.elapsed`). Sans cette resynchronisation, un
  /// ticker annulé pendant un masquage puis ré-armé reprendrait là où il
  /// s'était arrêté et mentirait sur le temps écoulé. Entre deux
  /// armements, la dérive est bornée par les ticks manqués (jank,
  /// arrière-plan).
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(
    Duration.zero,
  );

  /// Sélection QCM — positions (`ZChoice` ne porte aucun `id` : deux choix
  /// peuvent avoir le même `content`, la position est la seule identité
  /// fiable).
  final ValueNotifier<Set<int>> _selected = ValueNotifier<Set<int>>(<int>{});

  /// Indices déjà montrés (stocké inclus) — cumulatif, anti-répétition.
  final ValueNotifier<List<String>> _shownHints = ValueNotifier<List<String>>(
    const <String>[],
  );

  /// Message d'erreur d'indice (l10n) — un échec n'est jamais silencieux,
  /// et n'incrémente pas [_shownHints] (un indice non obtenu ne pénalise pas).
  final ValueNotifier<String?> _hintError = ValueNotifier<String?>(null);

  /// Correction affichée après soumission (`null` : pas encore soumis).
  final ValueNotifier<_Correction?> _correction = ValueNotifier<_Correction?>(
    null,
  );

  /// Controller stable (invariant AD-2) : créé une fois ici, disposé
  /// ci-dessous. Jamais recréé dans `build()` — ce serait le bug historique
  /// que zcrud existe pour corriger (perte de focus et de curseur à chaque
  /// frappe).
  final TextEditingController _answerController = TextEditingController();

  /// `FocusNode` stable — même raison.
  final FocusNode _answerFocus = FocusNode();

  /// Jeton de fraîcheur — incrémenté à chaque changement de carte.
  ///
  /// Capturé avant tout `await` de port et re-comparé au retour : un
  /// résultat qui revient après un changement de carte est périmé et
  /// ignoré.
  ///
  /// `mounted` seul ne suffit pas : quand la carte change, seul le widget
  /// est remplacé — l'`Element` et le `State` survivent, `mounted` reste
  /// `true`. Sans ce jeton, le feedback et la note de la carte A
  /// atterriraient silencieusement sur la carte B ; une fois `onSubmitted`
  /// branché sur `ZSessionReviewer.reviewCard`, ce serait un SRS faux écrit
  /// sur la mauvaise carte, par la voie légitime.
  int _generation = 0;

  /// Verrou de soumission one-shot — une carte, au plus une soumission.
  ///
  /// Posé à l'entrée de chacun des trois chemins (rédigée, QCM/VF
  /// auto-soumis, « Je ne sais pas »), il couvre la fenêtre `await` que le
  /// seul gating par `_correction` ne ferme pas (la correction n'arrive
  /// qu'après la réponse du port). Sans lui, un double-tap facturerait deux
  /// appels IA et émettrait deux `onSubmitted` — et un tap sur « Je ne sais
  /// pas » après une bonne réponse ré-émettrait une note basse par-dessus,
  /// fabriquant un lapse sur une réponse exacte.
  bool _submitLocked = false;

  /// Verrou d'indice one-shot (même discipline) — une demande en vol
  /// interdit la suivante.
  ///
  /// Sans lui, deux demandes concurrentes capturaient le même
  /// `shownHints`, la seconde réponse écrasant la première : un indice
  /// payé puis jeté, `hintsUsed` sous-comptant les appels réels, faussant
  /// le plafond et rendant l'anti-répétition aveugle.
  bool _hintInFlight = false;

  /// Coupe l'observation pendant une écriture qui n'est pas une saisie de
  /// l'utilisateur (amorçage, remise à zéro d'une nouvelle carte).
  ///
  /// Sans elle, `_answerController.clear()` et `_selected.value = {}` du
  /// changement de carte partiraient à `onAnswerChanged` comme si
  /// l'utilisateur avait effacé sa réponse — un hôte qui persiste ce qu'il
  /// reçoit écraserait le brouillon de la carte précédente par du vide, au
  /// moment précis où elle disparaît de l'écran.
  bool _muteAnswerNotifications = false;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    // Ticker armé uniquement si le minuteur est affiché — la mesure, elle,
    // tourne toujours (`_stopwatch` ci-dessus). Pas de resynchronisation au
    // montage : `_stopwatch` vient de démarrer, `_elapsed` est déjà exact
    // (zéro).
    _syncTicker(resync: false);
    _maybeRevealStoredHint();
    _applyInitialAnswer();
    // Abonnements posés APRÈS l'amorçage : la valeur initiale n'est pas une
    // saisie, elle ne doit donc rien notifier. L'observation passe par des
    // écouteurs, jamais par un `setState` — la frappe ne reconstruit toujours
    // que l'`EditableText` (invariant AD-2).
    _answerController.addListener(_onAnswerTextChanged);
    _selected.addListener(_notifyAnswerChanged);
  }

  /// Dernier texte notifié — voir [_onAnswerTextChanged].
  String _lastAnswerText = '';

  /// Filtre les notifications du controller qui ne changent pas la réponse.
  ///
  /// Un `TextEditingController` notifie aussi sur la sélection et le curseur :
  /// le seul fait de poser le focus dans le champ (la sélection passe d'un
  /// offset invalide à zéro) émettrait une « saisie » vide avant la première
  /// frappe, et chaque déplacement de curseur en émettrait une identique à la
  /// précédente.
  void _onAnswerTextChanged() {
    final text = _answerController.text;
    if (text == _lastAnswerText) return;
    _lastAnswerText = text;
    _notifyAnswerChanged();
  }

  /// Préremplit le champ rédigé — une fois, au montage.
  ///
  /// La sélection est posée en fin de texte : sans elle, `TextEditingValue`
  /// laisserait un `offset` de `-1`, et le premier tap dans le champ ferait
  /// sauter le curseur au début.
  void _applyInitialAnswer() {
    final initial = widget.initialAnswer;
    if (initial == null || initial.isEmpty) return;
    _answerController.value = TextEditingValue(
      text: initial,
      selection: TextSelection.collapsed(offset: initial.length),
    );
    _lastAnswerText = initial;
  }

  /// Voie unique de notification de la réponse courante.
  void _notifyAnswerChanged({bool? answeredTrue}) {
    if (_muteAnswerNotifications) return;
    final observer = widget.onAnswerChanged;
    if (observer == null) return;
    observer(
      ZFlashcardAnswerDraft(
        text: _answerController.text,
        // Copie défensive : l'hôte reçoit un instantané, jamais le `Set`
        // vivant que la surface remplace à chaque tap.
        selectedChoiceIndexes: Set<int>.unmodifiable(_selected.value),
        answeredTrue: answeredTrue,
      ),
    );
  }

  /// Sert l'indice stocké d'emblée quand l'hôte le demande.
  ///
  /// Passe par la même voie que le bouton (`_shownHints`) : l'indice est
  /// donc compté (`hintsUsed`) et plafonne la qualité exactement comme s'il
  /// avait été demandé. Un chemin parallèle qui l'afficherait sans le
  /// compter ferait diverger la pénalité de ce que l'utilisateur a
  /// réellement vu.
  void _maybeRevealStoredHint() {
    if (!widget.revealStoredHint) return;
    if (!_hasUnservedStoredHint) return;
    _shownHints.value = <String>[widget.card.hint!];
  }

  @override
  void didUpdateWidget(covariant ZFlashcardAnswerInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // La carte est une prop mutable : sans réinitialisation, `_selected`,
    // `_shownHints`, `_correction`, `_answerController` et `_stopwatch`
    // fuiraient sur la carte suivante. Deux dégâts possibles : l'indice
    // stocké de la nouvelle carte ne serait jamais servi
    // (`_hasUnservedStoredHint` court-circuité à jamais) et le port
    // recevrait le contenu de l'ancienne carte dans le prompt de la nouvelle.
    if (oldWidget.card != widget.card) _resetForNewCard();
    // `timerDisplay`/`timeLimit` sont eux aussi des props mutables.
    _syncTicker(resync: true);
  }

  /// Réinitialise tout l'état de réponse pour une nouvelle carte.
  void _resetForNewCard() {
    // Une remise à zéro n'est pas une saisie (voir [_muteAnswerNotifications]).
    _muteAnswerNotifications = true;
    try {
      _resetStateForNewCard();
    } finally {
      _muteAnswerNotifications = false;
    }
  }

  void _resetStateForNewCard() {
    // Périme tout appel de port en vol (voir [_generation]).
    _generation++;
    _submitLocked = false;
    _hintInFlight = false;
    _selected.value = <int>{};
    _shownHints.value = const <String>[];
    // La nouvelle carte doit servir son indice stocké d'emblée.
    _maybeRevealStoredHint();
    _hintError.value = null;
    _correction.value = null;
    _answerController.clear();
    // L'auto-passage de la carte précédente ne doit pas faire avancer la
    // nouvelle.
    _advanceTimer?.cancel();
    _advanceTimer = null;
    _stopwatch
      ..reset()
      ..start();
    _elapsed.value = Duration.zero;
    _ticker?.cancel();
    _ticker = null;
  }

  /// Le rebours est-il épuisé ? (Le ticker n'a alors plus rien à afficher.)
  bool get _countdownExhausted {
    if (_effectiveTimerDisplay != ZTimerDisplay.countdown) return false;
    final limit = widget.timeLimit;
    return limit != null && _elapsed.value >= limit;
  }

  /// Voie unique d'(dés)armement du ticker d'affichage — appelée au montage
  /// et à chaque `didUpdateWidget`.
  ///
  /// - `hidden` : ticker annulé, sans quoi il survivrait au masquage et
  ///   tirerait sans aucun abonné ;
  /// - `countdown` épuisé : ticker annulé (il reconstruirait indéfiniment
  ///   un `00:00` immuable et ferait croître `_elapsed` sans borne) ;
  /// - (ré)armement : l'affichage est resynchronisé sur [_stopwatch], la
  ///   source de mesure unique. Sans ce `resync`, corriger le ré-armement
  ///   seul rendrait l'affichage faux : il repartirait de la valeur d'avant
  ///   le masquage, en ignorant le temps réellement écoulé.
  void _syncTicker({required bool resync}) {
    if (_effectiveTimerDisplay == ZTimerDisplay.hidden || _countdownExhausted) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    // Déjà armé : ne pas ré-armer (ce serait resynchroniser à chaque
    // rebuild de l'hôte, pour rien).
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
    // Aucun tick, aucune avance après démontage : un `Timer` survivant
    // appellerait `onAdvance` sur un arbre mort.
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

  /// Slot de contenu — délègue à
  /// [ZFlashcardAnswerInput.resolveContentBuilder], la voie unique de
  /// résolution.
  ZFlashcardContentBuilder get _contentBuilder =>
      ZFlashcardAnswerInput.resolveContentBuilder(widget.contentBuilder);

  /// `countdown` sans `timeLimit` dégrade en `elapsed` (invariant AD-10 :
  /// jamais d'exception, jamais un rebours depuis `null`).
  ZTimerDisplay get _effectiveTimerDisplay =>
      widget.timerDisplay == ZTimerDisplay.countdown && widget.timeLimit == null
      ? ZTimerDisplay.elapsed
      : widget.timerDisplay;

  /// Table unique — une valeur explicite de l'hôte prime.
  ZCardAdvanceBehavior get _advanceBehavior =>
      widget.advanceBehavior ?? zDefaultAdvanceBehavior(widget.mode);

  int get _hintsUsed => _shownHints.value.length;

  /// La carte porte-t-elle un indice stocké exploitable ?
  bool get _hasStoredHint {
    final stored = widget.card.hint;
    return stored != null && stored.isNotEmpty;
  }

  /// L'indice stocké est-il encore à servir ? (Le stocké passe toujours
  /// avant le port.)
  ///
  /// Dépend de `_shownHints.value`, donc ne doit jamais être lu depuis
  /// `build()` : le `build()` de la surface ne se rejoue pas quand un
  /// indice s'ajoute (rebuild granulaire). Il est lu dans les callbacks, et
  /// la disponibilité affichée est recalculée dans le
  /// `ValueListenableBuilder` de `_HintSection` — sinon le bouton « Indice »
  /// resterait visible après épuisement.
  bool get _hasUnservedStoredHint =>
      _hasStoredHint && _shownHints.value.isEmpty;

  /// Voie unique d'attribution : le plafond d'indices est appliqué en
  /// dernier, sur la valeur rendue, sur tous les chemins.
  int _finalQuality(int rawQuality) => zApplyHintCeiling(
    rawQuality: rawQuality,
    hintsUsed: _hintsUsed,
    config: widget.srsConfig,
    policy: widget.hintPolicy,
  );

  /// Émet la soumission advisory et arme l'auto-passage éventuel.
  ///
  /// N'écrit rien et n'appelle pas `onQualitySelected` : soumettre n'est
  /// pas noter. Le port suggère, la rangée SRS montre, et seul le tap de
  /// l'utilisateur note.
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
        // `mounted` : ne jamais tirer sur un arbre démonté.
        if (mounted) widget.onAdvance?.call();
      });
    }
  }

  /// Soumission d'un QCM / Vrai-Faux — locale, le port n'est jamais appelé.
  void _submitLocal({bool? answeredTrue}) {
    // One-shot (voir [_submitLocked]) — le V/F s'auto-soumet au tap : rien
    // n'empêcherait deux taps d'émettre deux soumissions.
    if (_submitLocked) return;
    final raw = zEvaluateLocally(
      card: widget.card,
      selectedChoiceIndexes: _selected.value,
      answeredTrue: answeredTrue,
      config: widget.srsConfig,
    );
    // Carte malformée (invariant AD-10) : aucune saisie n'était offerte,
    // donc rien à soumettre. Le verrou n'est posé qu'après : ne rien
    // soumettre ne « consomme » pas la soumission unique de la carte.
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

  /// Soumission d'une réponse rédigée — port advisory + replis défensifs.
  Future<void> _submitWritten({bool skipEvaluation = false}) async {
    // Propriétaire unique de la décision de routage, et le seul point du
    // code d'où le port est atteignable : la fonction du domaine décide,
    // et elle seule, plutôt qu'une table redondante ici.
    if (zIsLocallyEvaluatedType(widget.card.type)) {
      _submitLocal();
      return;
    }
    // One-shot (voir [_submitLocked]) : posé avant l'`await`, il ferme la
    // fenêtre que le gating par `_correction` ne ferme pas (la correction
    // n'arrive qu'après la réponse du port, et le bouton n'a aucun
    // indicateur de charge).
    if (_submitLocked) return;
    _submitLocked = true;
    // Jeton de fraîcheur capturé avant l'`await` (voir [_generation]).
    final generation = _generation;

    // `skipEvaluation` est une décision de soumission (affordance), pas de
    // construction : l'hôte peut offrir « évaluer sans IA » à côté du
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
            // Informatif : le port n'en tire aucune pénalité — le plafond
            // local est l'unique propriétaire.
            hintsUsed: _hintsUsed,
          ),
        );
        evaluation = result.fold(
          // Un échec fait retomber sur un repli neutre, aucun nouveau
          // canal d'erreur.
          (_) => null,
          (value) => value,
        );
      } on Object {
        // Jamais d'exception (invariant AD-10). Le repli couvre aussi le
        // `throw` d'une implémentation hôte hostile, pas seulement l'échec
        // typé : une session ne doit jamais mourir parce qu'un routeur IA a
        // paniqué. Ce n'est pas un `try-catch` nu de repository : c'est la
        // frontière défensive d'une surface face à du code tiers injecté.
        evaluation = null;
      }
    }

    // `mounted` ne suffit pas : la carte a pu changer sous le `State` (qui,
    // lui, survit). Un résultat périmé est ignoré, jamais écrit sur la
    // carte suivante.
    if (!mounted || generation != _generation) return;

    final int raw;
    final String feedback;
    if (evaluation == null) {
      // Qualité neutre = `passThreshold`, jamais un littéral en dur : c'est
      // le seuil de passage qui fait autorité.
      raw = widget.srsConfig.passThreshold;
      // L'échec n'est jamais silencieux : jamais un blanc.
      feedback = label(
        context,
        'zcrud.flashcard.evaluationUnavailable',
        fallback: 'Évaluation indisponible — note neutre proposée.',
      );
    } else {
      // `clampQuality` : unique voie de clamp, jamais un `.clamp(0, 5)` en
      // dur, jamais une seconde échelle.
      raw = widget.srsConfig.clampQuality(evaluation.suggestedQuality);
      feedback = evaluation.feedback;
    }

    _emit(
      _Correction(
        // Clamp puis plafond — l'ordre imposé.
        quality: _finalQuality(raw),
        isCorrect: evaluation?.isCorrect,
        feedback: feedback,
      ),
    );
  }

  /// « Je ne sais pas » — borne basse, sans appel au port.
  ///
  /// `minQuality` est la borne basse : `0` par défaut, `1` si l'application
  /// configure `ZSrsConfig(minQuality: 1)`.
  void _submitDontKnow() {
    // One-shot (voir [_submitLocked]) : sans lui, le bouton resterait actif
    // après la correction, et une bonne réponse déjà notée pourrait être
    // ré-émise à la borne basse pour une seule carte répondue juste.
    if (_submitLocked) return;
    _submitLocked = true;
    _emit(
      _Correction(
        quality: _finalQuality(widget.srsConfig.minQuality),
        isCorrect: false,
      ),
    );
  }

  /// Demande d'indice — stocké d'abord, port après épuisement.
  Future<void> _requestHint() async {
    // One-shot (voir [_hintInFlight]) — une demande en vol interdit la
    // suivante.
    if (_hintInFlight) return;
    _hintError.value = null;

    // 1) L'indice stocké d'abord — le port n'est pas appelé : la carte
    // porte déjà son indice, appeler le port serait un aller IA superflu.
    if (_hasUnservedStoredHint) {
      _shownHints.value = <String>[widget.card.hint!];
      return;
    }

    // 2) Le port, seulement après épuisement, avec les indices déjà
    // montrés (anti-répétition : sans eux, le barème paraphraserait le
    // même indice).
    final port = widget.hintPort;
    if (port == null) return; // bouton absent — défensif (invariant AD-10).

    _hintInFlight = true;
    // Jeton de fraîcheur capturé avant l'`await` (voir [_generation]) : un
    // indice qui revient après un changement de carte est périmé — l'afficher
    // fuirait le contenu de la carte précédente sur la nouvelle et la
    // plafonnerait à tort.
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
          // Éphémère : ajouté à l'état de session, jamais persisté sur la
          // carte — `widget.card` n'est pas mutée, aucune écriture n'a lieu.
          // Cumul lu au dernier moment (jamais depuis la copie pré-`await`) :
          // une accumulation depuis `shown` écraserait tout indice arrivé
          // entre-temps.
          _shownHints.value = <String>[..._shownHints.value, hint];
        },
      );
    } on Object {
      // Aucune exception ne franchit la surface (invariant AD-10). Le
      // compteur d'indices reste inchangé — un indice non obtenu ne
      // pénalise pas.
      if (!mounted || generation != _generation) return;
      _hintError.value = label(
        context,
        'zcrud.flashcard.hintUnavailable',
        fallback: 'Indice indisponible.',
      );
    } finally {
      // Le verrou est libéré même sur échec : un indice non obtenu doit
      // pouvoir être redemandé (le compteur, lui, reste inchangé).
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
        // Slot de contenu sous `IgnorePointer` : le contenu est de
        // l'affichage, un `QuillEditor` injecté ne peut pas voler le tap
        // d'une case QCM. Les `Semantics` du sous-arbre restent lisibles :
        // c'est l'interactivité qui est neutralisée, pas l'accessibilité.
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
          // Gaté sur la correction, comme les trois autres contrôles :
          // après soumission, un indice n'a plus d'effet sur la note déjà
          // émise — et déclencherait un appel IA facturé pour une carte
          // déjà corrigée.
          correction: _correction,
          submittedOverride: widget.isSubmitted,
          onRequestHint: _requestHint,
        ),
        SizedBox(height: theme.gapM),
        _DontKnowButton(
          correction: _correction,
          submittedOverride: widget.isSubmitted,
          onPressed: _submitDontKnow,
        ),
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

  /// Table d'affordance de saisie par type — `switch` exhaustif sans
  /// `default` sur les six `ZFlashcardType` (une septième valeur casse la
  /// compilation).
  ///
  /// Un propriétaire chacun : cette table ne redécide pas la table
  /// d'affichage de `ZFlashcardReviewCard`. Deux tables, deux objets.
  Widget _buildInput(BuildContext context) => switch (widget.card.type) {
    ZFlashcardType.multipleChoice => _ChoicesInput(
      card: widget.card,
      selected: _selected,
      correction: _correction,
      visibility: widget.correctionVisibility,
      choiceContentBuilder: widget.choiceContentBuilder,
      submittedOverride: widget.isSubmitted,
      onSubmit: _submitLocal,
    ),
    ZFlashcardType.trueOrFalse => _TrueFalseInput(
      card: widget.card,
      correction: _correction,
      visibility: widget.correctionVisibility,
      submittedOverride: widget.isSubmitted,
      // Le tap vaut la soumission (auto-soumission, aucun second geste).
      // L'observation précède la soumission : l'hôte apprend ce qui a été
      // répondu avant d'apprendre que c'est parti au barème.
      onAnswer: (value) {
        _notifyAnswerChanged(answeredTrue: value);
        _submitLocal(answeredTrue: value);
      },
    ),
    ZFlashcardType.openQuestion ||
    ZFlashcardType.exercise ||
    ZFlashcardType.fillBlank ||
    ZFlashcardType.shortAnswer => _WrittenInput(
      controller: _answerController,
      focusNode: _answerFocus,
      correction: _correction,
      validator: _requiredValidator(context),
      fieldBuilder: widget.writtenAnswerFieldBuilder,
      submittedOverride: widget.isSubmitted,
      onSubmit: _submitWritten,
      onSubmitWithoutEvaluation:
          (widget.allowSkipEvaluation && widget.evaluationPort != null)
          ? () => _submitWritten(skipEvaluation: true)
          : null,
    ),
  };

  /// Validateur mémoïsé du champ de rédaction (identité stable entre
  /// builds — une closure recréée à chaque build ferait retravailler le
  /// `FormField`).
  ///
  /// Vit ici plutôt qu'en `static` sur `_WrittenInput` : le message
  /// d'erreur est affiché à l'utilisateur (`errorText` sous le champ,
  /// `autovalidateMode: onUserInteraction`) — il doit donc être localisé,
  /// ce qui exige un `BuildContext`. Une version statique rendrait un
  /// littéral en dur, invariablement anglais ou français. La mémoïsation
  /// est préservée : la closure n'est reconstruite que si le libellé
  /// résolu change (changement de locale).
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

/// Tranche minuteur isolée — seul ce sous-arbre se reconstruit au tick : ni
/// la carte, ni le champ de saisie.
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
          // S'arrête à zéro, jamais de négatif (invariant AD-10).
          () {
            final remaining = (timeLimit ?? Duration.zero) - value;
            return remaining.isNegative ? Duration.zero : remaining;
          }(),
        ),
      };
      // Le sens est porté par le libellé (invariant AD-13) : « Minuteur,
      // 00:03 » ne dit pas s'il reste 3 s ou s'il en a été consommé 3 —
      // l'information décisive en examen blanc. Pas de `liveRegion` : une
      // annonce par seconde noierait le lecteur d'écran.
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

/// Saisie QCM — cases exclusives si un seul choix correct, cumulatives si
/// deux ou plus (mode déduit des données, jamais d'un champ/paramètre).
class _ChoicesInput extends StatelessWidget {
  const _ChoicesInput({
    required this.card,
    required this.selected,
    required this.correction,
    required this.visibility,
    required this.choiceContentBuilder,
    required this.submittedOverride,
    required this.onSubmit,
  });

  final ZFlashcard card;
  final ValueNotifier<Set<int>> selected;
  final ValueListenable<_Correction?> correction;

  /// Régime d'apparition de la correction — rendu seul.
  final ZCorrectionVisibility visibility;
  final ZFlashcardChoiceContentBuilder? choiceContentBuilder;

  /// Verrou imposé par l'hôte (`null` : la correction décide seule).
  final bool? submittedOverride;
  final VoidCallback onSubmit;

  /// Préfixe de clé d'un choix, pour la testabilité.
  static const String choiceKeyPrefix = 'zAnswerChoice_';

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final choices = card.choices;
    // `choices` absent/vide ou sans aucun correct (invariant AD-10) :
    // aucune saisie offerte, et surtout aucun plantage — repli l10n,
    // jamais un `!`.
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
        builder: (context, current, _) {
          // Verrou effectif : l'imposition de l'hôte prime, sinon la
          // correction locale décide — jamais l'inverse, jamais un mélange
          // avec `visibility` (qui ne gouverne que la peinture).
          final locked = submittedOverride ?? corrected != null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < choices.length; i++)
                _ChoiceRow(
                  key: ValueKey<String>('$choiceKeyPrefix$i'),
                  index: i,
                  choice: choices[i],
                  isSelected: current.contains(i),
                  // La correction n'apparaît qu'après soumission (causée par
                  // la soumission, jamais par un tap) — et, en `deferred`
                  // (examen blanc), jamais : l'hôte la révèle en fin
                  // d'examen. Polarité unique via `paintsCorrection`
                  // (`switch` exhaustif) — jamais une comparaison `==`
                  // recopiée site par site. Une soumission IMPOSÉE ne peint
                  // rien : la surface n'a fabriqué aucune correction.
                  showCorrection:
                      corrected != null && visibility.paintsCorrection,
                  single: single,
                  choiceContentBuilder: choiceContentBuilder,
                  // Ne jamais mêler `visibility` à ce gate : il porte le
                  // verrou d'interaction, pas l'affichage. Le rendre sensible
                  // au report ferait re-taper un choix après soumission,
                  // donc un double `onSubmitted`.
                  onTap: locked
                      ? null
                      : () {
                          // Un seul correct : exclusif (cocher B décoche A) ;
                          // deux ou plus corrects : cumulatif.
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
              if (!locked) _SubmitButton(onPressed: onSubmit),
            ],
          );
        },
      ),
    );
  }
}

/// Une ligne de choix — `MergeSemantics` : le marqueur de correction est
/// associé à son choix (un marqueur détaché s'attacherait au mauvais choix
/// et enseignerait une erreur à un utilisateur non-voyant).
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.index,
    required this.choice,
    required this.isSelected,
    required this.showCorrection,
    required this.single,
    required this.choiceContentBuilder,
    required this.onTap,
    super.key,
  });

  final int index;
  final ZChoice choice;
  final bool isSelected;
  final bool showCorrection;
  final bool single;
  final ZFlashcardChoiceContentBuilder? choiceContentBuilder;
  final VoidCallback? onTap;

  /// Cible tap minimale (invariant AD-13).
  static const double minTarget = 48;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Canal non-coloré (invariant AD-13) : une forme porte l'état, jamais
    // la seule couleur. Sélection : case cochée/décochée. Correction : ✓ / ✗.
    //
    // Deux informations, deux axes de forme : si l'icône ne portait que la
    // vérité (`check_circle`/`cancel`), elle effacerait le choix de
    // l'utilisateur — un choix faux coché et un choix faux non coché
    // deviendraient pixel-identiques, alors que le canal sémantique
    // conserverait `checked: isSelected`, rendant un utilisateur non-voyant
    // mieux informé qu'un voyant. L'invariant AD-13 exige la parité des
    // canaux, pas leur inversion. D'où : ✓/✗ = la vérité ; plein = « vous
    // l'aviez coché », contour = « vous ne l'aviez pas coché ». Les deux
    // axes sont des formes — aucune couleur n'est sollicitée.
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
                    child:
                        choiceContentBuilder?.call(context, choice) ??
                        Text(choice.content, textAlign: TextAlign.start),
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

/// Saisie Vrai/Faux — deux boutons à auto-soumission : le tap vaut la
/// soumission, aucun second geste.
class _TrueFalseInput extends StatelessWidget {
  const _TrueFalseInput({
    required this.card,
    required this.correction,
    required this.visibility,
    required this.submittedOverride,
    required this.onAnswer,
  });

  final ZFlashcard card;
  final ValueListenable<_Correction?> correction;

  /// Régime d'apparition de la correction — rendu seul.
  final ZCorrectionVisibility visibility;

  /// Verrou imposé par l'hôte (`null` : la correction décide seule).
  final bool? submittedOverride;
  final ValueChanged<bool> onAnswer;

  /// Clé du bouton « Vrai ».
  static const ValueKey<String> trueKey = ValueKey<String>('zAnswerTrue');

  /// Clé du bouton « Faux ».
  static const ValueKey<String> falseKey = ValueKey<String>('zAnswerFalse');

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // `isTrue == null` (invariant AD-10) : aucune saisie, aucun plantage.
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

  /// Un bouton V/F, avec son canal de correction (invariant AD-13).
  ///
  /// Sans canal de correction sur V/F — ni icône, ni `Semantics.value`, ni
  /// feedback — les deux boutons se griseraient, point : un apprenant qui
  /// répond faux verrait deux boutons gris sans jamais apprendre qu'il
  /// s'est trompé, et un lecteur d'écran annoncerait un bouton désactivé
  /// sans valeur. La carte serait pédagogiquement muette, alors que
  /// l'invariant AD-13 exige un canal non-coloré obligatoire (icône et
  /// `Semantics`).
  ///
  /// Aligné sur `_ChoiceRow` : ✓/✗ = la vérité de cette réponse ; plein =
  /// « c'est ce que vous avez répondu », contour = « ce n'est pas ce que
  /// vous avez répondu ». Deux axes de forme, aucune couleur.
  Widget _tfButton(
    BuildContext context, {
    required _Correction? corrected,
    required bool value,
    required bool expected,
  }) {
    final answered = corrected?.answeredTrue;
    final isCorrect = value == expected;
    final picked = answered == value;
    // Le canal de correction (icône ✓/✗ et `Semantics.value`) est peint si
    // et seulement si la correction est posée et le régime est `immediate`.
    // Les deux canaux suivent le même gate : les découpler annoncerait à un
    // lecteur d'écran une correction invisible à l'œil.
    // Polarité unique via `paintsCorrection` (`switch` exhaustif).
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
      // Verrou d'interaction gaté sur la correction (ou sur l'imposition de
      // l'hôte), jamais sur `visibility`. Une réponse V/F reste définitive en
      // `deferred`.
      onPressed: (submittedOverride ?? corrected != null)
          ? null
          : () => onAnswer(value),
    );
  }
}

/// Saisie rédigée — le cœur du rebuild granulaire, l'objectif produit
/// principal du dépôt.
///
/// `TextField` nu avec controller détenu par l'hôte, et non un widget de
/// champ générique du moteur d'édition : celui-ci exige un `ZFieldSpec`, un
/// concept dérivé d'un modèle, alors qu'une réponse d'apprenant n'est pas
/// un champ de modèle. Fabriquer un `ZFieldSpec` synthétique serait de la
/// cérémonie sans gain, et importerait le décor d'édition dans une surface
/// d'étude. Le patron (controller stable + `onUserInteraction`) est imité,
/// pas le widget.
///
/// Saisie à sens unique : aucune valeur n'est ré-injectée dans le
/// controller pendant la frappe — ce serait écraser la sélection ou le
/// curseur. Aucun `setState` ici : la frappe ne notifie que l'`EditableText`
/// interne, donc rien d'autre ne se reconstruit (ni la carte, ni le slot).
class _WrittenInput extends StatelessWidget {
  const _WrittenInput({
    required this.controller,
    required this.focusNode,
    required this.correction,
    required this.validator,
    required this.fieldBuilder,
    required this.submittedOverride,
    required this.onSubmit,
    this.onSubmitWithoutEvaluation,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueListenable<_Correction?> correction;

  /// Validateur résolu et mémoïsé par l'hôte (`_requiredValidator`) : son
  /// message est localisé et son identité est stable entre builds.
  final FormFieldValidator<String> validator;

  /// Slot du champ (`null` : `TextFormField` historique).
  final ZFlashcardWrittenAnswerFieldBuilder? fieldBuilder;

  /// Verrou imposé par l'hôte (`null` : la correction décide seule).
  final bool? submittedOverride;
  final VoidCallback onSubmit;

  /// Soumission qui n'appelle pas le port d'évaluation. `null` : bouton
  /// absent (patron d'absence structurelle du dépôt).
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
            builder: (context, corrected, _) {
              final locked = submittedOverride ?? corrected != null;
              final injected = fieldBuilder;
              // Le champ injecté remplace le champ, et rien d'autre : il
              // reçoit le controller et le focus de la surface (la
              // soumission lit ce controller-là), et le verrou déjà résolu.
              if (injected != null) {
                return injected(
                  context,
                  controller: controller,
                  focusNode: focusNode,
                  validator: validator,
                  isSubmitted: locked,
                );
              }
              return TextFormField(
                key: fieldKey,
                controller: controller,
                focusNode: focusNode,
              // Verrou one-shot du champ rédigé, sur le même patron que les
              // autres contrôles (`_ChoiceRow` : `onTap: null` ; `_tfButton` :
              // `onPressed: null` ; `_DontKnowButton` : disparaît ;
              // `_HintSection` : gatée). Sans lui, le champ resterait vivant
              // après soumission : en `immediate` la correction peinte juste
              // en dessous dit « c'est fini », mais `deferred` retire ce
              // signal, et le seul indice de soumission deviendrait la
              // disparition silencieuse du bouton. L'apprenant continuerait
              // alors de peaufiner sa copie en croyant l'améliorer, alors
              // que sa qualité est déjà notée sur le texte soumis — et
              // `ZFlashcardSubmission` ne porte pas le texte : le verdict
              // de la révélation porterait sur une réponse qui n'existe
              // plus nulle part.
              //
              // `readOnly` (et non `enabled: false`) : le texte noté reste
              // lisible et sélectionnable — l'apprenant doit pouvoir relire
              // ce qui a été évalué.
                readOnly: locked,
                // Par champ.
                autovalidateMode: AutovalidateMode.onUserInteraction,
                validator: validator,
                textAlign: TextAlign.start,
                maxLines: null,
              );
            },
          ),
        ),
        SizedBox(height: theme.gapM),
        // One-shot, même patron que `_ChoicesInput`/`_TrueFalseInput` : le
        // bouton disparaît une fois la correction affichée. Le verrou
        // `_submitLocked` couvre en plus la fenêtre `await` (avant la
        // correction, le bouton est encore là et n'a aucun indicateur de
        // charge).
        ValueListenableBuilder<_Correction?>(
          valueListenable: correction,
          builder: (context, corrected, _) =>
              (submittedOverride ?? corrected != null)
              ? const SizedBox.shrink()
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _SubmitButton(onPressed: onSubmit),
                    // Voie « évaluer sans IA », offerte à chaque soumission
                    // et non figée à la construction.
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

/// Section indices — bouton absent (jamais grisé) si rien à servir.
class _HintSection extends StatelessWidget {
  const _HintSection({
    required this.shownHints,
    required this.hintError,
    required this.hasStoredHint,
    required this.hasPort,
    required this.correction,
    required this.submittedOverride,
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

  /// Verrou imposé par l'hôte (`null` : la correction décide seule).
  final bool? submittedOverride;
  final VoidCallback onRequestHint;

  /// Le bouton « Indice » est-il offert ?
  ///
  /// Absent (jamais grisé) quand il n'y a plus rien à servir : le stocké
  /// est épuisé et aucun port n'est fourni — un bouton grisé promettrait
  /// une action qui n'existe pas.
  ///
  /// Calculé ici, à partir de [shownHints] observé : le calculer dans le
  /// `build()` de la surface le figerait à sa valeur initiale (ce `build()`
  /// ne se rejoue pas quand un indice s'ajoute, rebuild granulaire oblige)
  /// et le bouton survivrait à l'épuisement.
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
              // Absent si plus rien à servir — recalculé sur `hints`
              // observé (jamais figé au premier build) — et absent une fois
              // la correction émise (un indice n'a plus d'effet sur une
              // note déjà acquise, et coûterait un appel IA facturé pour
              // rien).
              ValueListenableBuilder<_Correction?>(
                valueListenable: correction,
                builder: (context, corrected, _) =>
                    !(submittedOverride ?? corrected != null) &&
                        _available(hints)
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
              // `liveRegion` (invariant AD-13) : ce texte apparaît de façon
              // asynchrone, hors du focus (qui reste sur le bouton « Indice »).
              // Sans lui, l'échec ne serait non-silencieux que pour un
              // voyant : un utilisateur de lecteur d'écran n'entendrait
              // rien et ré-appuierait en boucle.
              : Semantics(
                  liveRegion: true,
                  child: Text(error, textAlign: TextAlign.start),
                ),
        ),
      ],
    );
  }
}

/// Bouton « Je ne sais pas » — borne basse, sans appel au port.
class _DontKnowButton extends StatelessWidget {
  const _DontKnowButton({
    required this.correction,
    required this.submittedOverride,
    required this.onPressed,
  });

  final ValueListenable<_Correction?> correction;

  /// Verrou imposé par l'hôte (`null` : la correction décide seule).
  final bool? submittedOverride;
  final VoidCallback onPressed;

  /// Clé du bouton.
  static const ValueKey<String> dontKnowKey = ValueKey<String>('zDontKnow');

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<_Correction?>(
    valueListenable: correction,
    // One-shot : absent une fois la correction affichée — la réponse est
    // révélée, « je ne sais pas » n'a plus de sens et ré-émettrait la
    // borne basse par-dessus une note déjà acquise. Une soumission imposée
    // le retire pour la même raison : sans cela, ce bouton resterait la
    // seule voie ouverte pour envoyer une note basse au barème sur une carte
    // que l'hôte a déclarée close.
    builder: (context, corrected, _) => (submittedOverride ?? corrected != null)
        ? const SizedBox.shrink()
        : _ControlButton(
            buttonKey: dontKnowKey,
            labelKey: 'zcrud.flashcard.dontKnow',
            fallback: 'Je ne sais pas',
            onPressed: onPressed,
          ),
  );
}

/// Section correction et rangée SRS pré-sélectionnée.
class _CorrectionSection extends StatelessWidget {
  const _CorrectionSection({
    required this.correction,
    required this.visibility,
    required this.onQualitySelected,
    required this.srsConfig,
  });

  final ValueListenable<_Correction?> correction;

  /// Régime d'apparition de la correction — rendu seul.
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
        // En `deferred` (examen blanc), la correction est posée (verrous
        // intacts) mais rien n'est peint : ni feedback, ni rangée SRS.
        // L'hôte révèle en fin d'examen, depuis les `ZFlashcardSubmission`
        // mémorisées.
        // Polarité unique via `paintsCorrection` (`switch` exhaustif) —
        // toute comparaison `== deferred` recopiée ici divergerait de la
        // polarité `== immediate` des autres sites.
        if (!visibility.paintsCorrection) {
          return const SizedBox.shrink();
        }
        final selectedQuality = onQualitySelected;
        // Aucune affordance de cette surface n'est animée, donc aucun
        // appel à `zReduceMotionOf` ici : sans animation, l'invariant AD-13
        // sur les animations est satisfait par vacuité.
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (corrected.feedback != null)
              // `liveRegion` (invariant AD-13) : le feedback du barème est
              // le contenu pédagogique central de la carte et il apparaît
              // de façon asynchrone, hors du focus. Sans lui, il serait
              // rendu sans jamais être annoncé à un lecteur d'écran.
              Semantics(
                liveRegion: true,
                child: Text(
                  corrected.feedback!,
                  key: feedbackKey,
                  textAlign: TextAlign.start,
                ),
              ),
            // Rangée SRS absente si `onQualitySelected == null`, jamais un
            // booléen `showQualityButtons`.
            if (selectedQuality != null) ...<Widget>[
              SizedBox(height: theme.gapM),
              ZSrsQualityButtons(
                scale: ZQualityScale.fromConfig(srsConfig),
                passThreshold: srsConfig.passThreshold,
                // Advisory : le cran suggéré est pré-sélectionné, et c'est
                // le tap de l'utilisateur qui vaut notation.
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

/// Repli l10n d'une saisie indisponible (invariant AD-10) — jamais un écran
/// vide.
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

/// Bouton de contrôle générique — `Semantics` explicites et cible ≥ 48 dp
/// (invariant AD-13), libellé l10n, thème injecté, directionnel.
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

  /// Cible tap minimale (dp), invariant AD-13.
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
      // Porté par le même nœud que le libellé, donc impossible de
      // l'attacher au bouton voisin.
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
