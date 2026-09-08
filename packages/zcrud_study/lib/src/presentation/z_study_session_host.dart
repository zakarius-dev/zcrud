/// **Lot 1 « étude »** — [ZStudySessionHost] : le DÉTENTEUR DU RUNTIME.
///
/// Il possède le moteur de session, nourrit [ZStudySessionView] en tranches et
/// en callbacks, et **reçoit** son `ZSessionReviewer` — il n'en fabrique jamais.
///
/// ## Le runtime est DÉSIGNÉ, jamais redécidé
///
/// Le choix du runtime passe par `zSessionRuntimeForMode` (`zcrud_session`,
/// AD-34) — **table unique du dépôt**. L'assemblage de référence, lui,
/// redécidait : son `_makeRuntime` portait un second
/// `switch` sur `ZReviewMode`, parallèle à la table. Deux tables qui disent la
/// même chose aujourd'hui diront deux choses différentes le jour où l'une des
/// deux bougera — et c'est le **régime d'écriture SRS** qui serait en jeu.
///
/// Ici : un `switch` sur `ZSessionRuntimeKind` (le verdict de la table), et
/// **aucun** aiguillage secondaire sur le mode.
///
/// 🔬 **Y compris pour `list` / `cramming`** : la démo les séparait
/// (`list → advance()`, `cramming → answer(q)`). Vérifié sur disque — c'était
/// redondant : `ZLinearSessionState.answer(quality)` **ignore la qualité en
/// mode `list`** et
/// délègue à `advanceLinear`, « comportement identique à `advance()` » (sa
/// propre dartdoc). Un seul appel sert donc les deux modes, et le point
/// d'entrée « cramming » devient gratuit.
///
/// ## ZÉRO `setState` — et pourquoi ce n'est pas une coquetterie
///
/// La référence pilote tout par `setState` d'écran. Ici, tout l'état vit dans
/// des `ValueNotifier` **possédés**, et `build()` ne lit **aucune** de leurs
/// valeurs : il monte l'arbre une fois et délègue chaque tranche à son
/// `ValueListenableBuilder`.
///
/// Ce n'est pas qu'une affaire de SM-1. La `key` de la pile est dérivée de
/// l'identité de la file : un rebuild d'écran qui traverse un changement de
/// file **recrée l'`Element`** du swiper, et c'est exactement le chemin du
/// `RangeError` de su-4 D1. La granularité **ferme** la classe de bug que la
/// dartdoc de la référence décrit — elle ne fait pas que l'éviter.
///
/// La garde de source `z_study_session_source_guard_test.dart` assère
/// **`0` occurrence de `setState(`** dans les fichiers de ce lot.
///
/// ## Les quatre pièges d'intégration
///
/// | Piège (dartdoc de la référence) | Où il est traité |
/// |---|---|
/// | ① une seule source de séquence (su-10 D1) | [_gradeAndAdvance] — la file du swiper **suit** `engine.state.queue`, la carte notée est **toujours** `engine.current` |
/// | ② résolution par `flashcardId` (su-7) | [_buildCard] / [_buildGrading] — lecture dans `_cardsById`, **jamais** par index |
/// | ③ `key` de pile = identité de file (su-4 D1) | `ZStudySessionView` (`_StackSlice`) |
/// | ④ resync `didUpdateWidget` clampé (su-8) | [didUpdateWidget] — re-seed sur changement RÉEL de file, index clampé |
///
/// Plus le **latch one-shot** d'`onStackEnd` : la célébration est poussée
/// exactement une fois, même si l'événement est ré-émis.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZDisplayStateBinding,
        ZDisplayStateOwnerMixin,
        ZIndexController,
        ZToggleController,
        label;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcard,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardContentBuilder,
        ZFlashcardHintPort,
        ZFlashcardReviewCard,
        ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZFlashcardAnswerInput,
        ZSessionCardSlot,
        ZFlashcardSubmission,
        ZLinearSessionState,
        ZSessionItem,
        ZSessionProgressStyle,
        ZSessionReviewer,
        ZSessionRuntimeKind,
        ZStudySessionEngine,
        ZWhiteExamPhase,
        ZWhiteExamSessionEngine,
        zSessionRuntimeForMode;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;

import 'z_faded_overflow.dart';
import 'z_study_session_card_slot.dart';
import 'z_study_session_post_submit.dart';
import 'z_study_session_recall.dart';
import 'z_study_session_reference.dart';
import 'z_study_session_reveal.dart';
import 'z_study_session_slices.dart';
import 'z_study_session_view.dart';

/// Construit le résumé de fin — reçoit le résultat **agrégé** et la durée.
typedef ZStudySessionResultBuilder = Widget Function(
  BuildContext context,
  ZStudySessionResult result,
  Duration duration,
);

/// Construit la surface de saisie/notation **branchée sur le runtime**.
///
/// **Reçoit [submit]** — et c'est le point du type. `ZStudySessionView`
/// prend un builder à deux arguments : elle n'a pas de runtime, donc rien à
/// offrir. Le **host**, lui, en détient un ; un slot de notation qui ne pourrait
/// pas l'atteindre serait une **commande morte** — l'hôte remplacerait la
/// surface par la sienne, taperait « Je sais », et rien n'atteindrait jamais le
/// SRS. *Une commande morte coûte plus cher qu'une commande absente, parce
/// qu'elle promet.*
///
/// 🔬 Ce défaut a été démasqué par la contre-preuve de non-vacuité de
/// `z_study_session_sm1_test.dart` : le premier jet du slot était à deux
/// arguments, la session instrumentée notait dans le vide, et le compteur
/// d'écritures SRS restait à `0`.
///
/// [submit] route la soumission vers le runtime **désigné**, exactement comme
/// la surface par défaut : association par `flashcardId`, jamais par index.
typedef ZStudySessionGradingSlotBuilder = Widget Function(
  BuildContext context,
  ZSessionItem item,
  ValueChanged<ZFlashcardSubmission> submit,
);

/// Écran de session **assemblé** : détient le runtime, nourrit la vue.
///
/// Voir la dartdoc de bibliothèque pour la table de runtime, la discipline
/// SM-1 et les quatre pièges d'intégration.
class ZStudySessionHost extends StatefulWidget {
  /// Assemble une session sur [queue] dans le [mode] donné.
  ///
  /// [reviewer] est la **voie d'écriture SRS unique** (AD-33) — injectée par
  /// l'hôte, jamais fabriquée ici. Elle n'est consommée que par le runtime
  /// `srsEngine` ; les modes non-SRS n'en reçoivent aucune, et **aucun no-op
  /// n'est inventé** pour combler son absence (AD-34).
  const ZStudySessionHost({
    required this.mode,
    required this.queue,
    this.reviewer,
    this.config = const ZSrsConfig(),
    this.cardBuilder,
    this.cardSlotBuilder,
    this.contentBuilder,
    this.evaluationPort,
    this.hintPort,
    this.headerBuilder,
    this.counterBuilder,
    this.gradingBuilder,
    this.summaryBuilder,
    this.emptyBuilder,
    this.celebrationBuilder,
    this.labels,
    this.onSessionEnd,
    this.onExit,
    this.indexController,
    this.progressStyle = ZSessionProgressStyle.dots,
    this.revealPolicy = ZStudySessionRevealPolicy.auto,
    this.postSubmitPolicy = ZStudySessionPostSubmitPolicy.auto,
    this.questionRecall = ZStudySessionQuestionRecall.auto,
    this.bottomInset,
    this.fallbackFolderId = '',
    this.stackFlex,
    this.inputFlex,
    this.contentPadding,
    this.dividerThickness,
    this.sectionGap,
    this.minTarget,
    this.counterStyle,
    super.key,
  });

  /// Clé de l'action de révélation (testabilité).
  static const ValueKey<String> revealActionKey =
      ValueKey<String>('zStudySessionReveal');

  /// Clé l10n du libellé « afficher la réponse ».
  ///
  /// Partagée avec la carte de révision : la même action porte le même mot
  /// dans tout le dépôt, et un hôte déjà traduit n'a rien à ajouter.
  static const String revealLabelKey = 'zcrud.flashcard.reveal';

  /// Clé l10n du libellé « masquer la réponse ».
  static const String hideLabelKey = 'zcrud.flashcard.hide';

  /// Clé de l'action de continuation après notation (testabilité).
  static const ValueKey<String> continueActionKey =
      ValueKey<String>('zStudySessionContinue');

  /// Clé l10n du libellé « continuer » (passer à la carte suivante).
  static const String continueLabelKey = 'zcrud.session.continue';

  /// Mode de session — **entrée** de `zSessionRuntimeForMode` (AD-34).
  final ZReviewMode mode;

  /// File **déjà sélectionnée** (la sélection est amont : `ZSessionModeSelector`).
  final List<ZFlashcard> queue;

  /// Voie d'écriture SRS **injectée** (AD-33). `null` en mode SRS ⇒ phase
  /// [ZStudySessionPhase.unavailable] : aucun runtime, repli explicite, aucun
  /// no-op fabriqué (AD-34), aucun throw (AD-10).
  final ZSessionReviewer? reviewer;

  /// Configuration SRS — propriétaire de l'échelle et du seuil (AD-46).
  final ZSrsConfig config;

  /// Slot de carte d'AFFICHAGE. `null` ⇒ `ZFlashcardReviewCard` par défaut.
  final Widget Function(BuildContext context, ZFlashcard card)? cardBuilder;

  /// Slot de carte qui reçoit le **créneau complet** ([ZStudySessionCardSlot] :
  /// carte, rang, `isFront`, état de révélation, commande de bascule).
  ///
  /// Prioritaire sur [cardBuilder] : fourni, il rend **toutes** les cartes de
  /// la pile. `null` ⇒ l'écran se comporte exactement comme s'il n'existait
  /// pas.
  ///
  /// C'est la voie d'un hôte qui compose sa propre carte sans renoncer à ce que
  /// l'assemblage sait : il n'a besoin ni d'un contrôleur d'index, ni d'un
  /// contrôleur de révélation.
  ///
  /// L'affordance de révélation **du socle** n'est alors pas rendue : l'hôte a
  /// reçu la commande ([ZStudySessionCardSlot.toggleReveal]) et la place où il
  /// veut. Deux boutons pour le même état se superposeraient et se
  /// contrediraient à l'écran.
  final ZStudySessionCardSlotBuilder? cardSlotBuilder;

  /// Slot AD-40 de rendu du contenu (markdown, LaTeX…) — passé tel quel à la
  /// carte **et** à la surface de saisie.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Port d'évaluation ADVISORY (`null` ⇒ repli qualité neutre côté saisie).
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Port d'indices (`null` ⇒ bouton « Indice » absent, jamais grisé).
  final ZFlashcardHintPort? hintPort;

  /// Slot d'en-tête. `null` ⇒ absent de l'arbre (AD-4).
  final ZStudySessionHeaderBuilder? headerBuilder;

  /// Slot de compteurs. `null` ⇒ absent de l'arbre (AD-4).
  final ZStudySessionCounterBuilder? counterBuilder;

  /// Slot de saisie/notation, **branché sur le runtime** (cf.
  /// [ZStudySessionGradingSlotBuilder]). `null` ⇒ `ZFlashcardAnswerInput` par
  /// défaut.
  ///
  /// 🔒 Distinct des slots additifs : la saisie **est** la session. Un `null`
  /// ici ne retire pas la zone, il prend le défaut du socle — comme
  /// [cardBuilder]. Pour retirer la zone entièrement, un hôte compose
  /// `ZStudySessionView` directement (elle, honore `null` ⇒ absent, AD-4).
  final ZStudySessionGradingSlotBuilder? gradingBuilder;

  /// Slot de résumé. `null` ⇒ absent de l'arbre (la vue rend alors son issue
  /// de sortie AD-10 — jamais un écran dont on ne sort pas).
  final ZStudySessionResultBuilder? summaryBuilder;

  /// Slot de repli « session vide ». `null` ⇒ repli du socle.
  final WidgetBuilder? emptyBuilder;

  /// Slot de célébration, au-dessus du résumé. `null` ⇒ absent de l'arbre.
  final ZStudySessionCelebrationBuilder? celebrationBuilder;

  /// Libellés injectés (FR-26).
  final ZStudySessionLabels? labels;

  /// Notifié **une seule fois** par session, à l'épuisement de la file (latch).
  final void Function(ZStudySessionResult result, Duration duration)?
      onSessionEnd;

  /// Issue de sortie des replis. `null` ⇒ bouton absent : jamais d'action
  /// fabriquée que le widget ne saurait pas exécuter.
  final VoidCallback? onExit;

  /// Pilote optionnel de l'index de la pile, passé tel quel.
  final ZIndexController? indexController;

  /// Style de l'indicateur de progression de la pile.
  final ZSessionProgressStyle progressStyle;

  /// Politique de l'affordance de **révélation de la réponse**.
  ///
  /// Défaut [ZStudySessionRevealPolicy.auto] : l'action n'est offerte que
  /// dans les modes où voir la réponse est l'objet de la session (cf.
  /// [zStudySessionRevealsAnswer]). [ZStudySessionRevealPolicy.never] retire
  /// l'action dans tous les modes.
  ///
  /// L'affordance suppose une carte **branchée sur la révélation** : elle est
  /// retirée dès que [cardBuilder] est fourni seul, parce que la carte de
  /// l'hôte ne s'y branche pas — un bouton qui ne dévoile rien promettrait plus
  /// qu'il ne tient. Avec [cardSlotBuilder], la révélation est bien branchée,
  /// mais c'est l'hôte qui place son propre contrôle.
  ///
  /// La révélation n'écrit **rien** : elle ne note pas, ne fait pas avancer la
  /// pile et n'atteint aucune voie SRS.
  final ZStudySessionRevealPolicy revealPolicy;

  /// Politique de **retenue après soumission**.
  ///
  /// Défaut [ZStudySessionPostSubmitPolicy.auto] : la carte notée est retenue
  /// dans les modes d'apprentissage (cf. [zStudySessionHoldsAfterSubmit]), le
  /// temps que la réponse soit lue ; une action de continuation
  /// ([continueActionKey]) passe alors à la suivante. Les modes notés sont
  /// inchangés — la carte part au moment même de la notation.
  ///
  /// [ZStudySessionPostSubmitPolicy.advance] restaure le passage immédiat dans
  /// tous les modes.
  ///
  /// La retenue ne touche **que** l'instant du passage : la note part au même
  /// moment, avec la même valeur, par la même et unique voie d'écriture SRS.
  final ZStudySessionPostSubmitPolicy postSubmitPolicy;

  /// Régime du **rappel de la question** au-dessus de la saisie.
  ///
  /// Défaut [ZStudySessionQuestionRecall.auto] : le rappel est rendu en
  /// entier sur une fenêtre large, **abrégé** sous
  /// [ZStudySessionReference.narrowWidth]. Poser
  /// [ZStudySessionQuestionRecall.full] rend le rappel entier quelle que soit
  /// la largeur.
  ///
  /// Le régime ne s'applique qu'à la **surface de saisie par défaut** : un
  /// [gradingBuilder] fourni compose son propre rappel.
  final ZStudySessionQuestionRecall questionRecall;

  /// Réserve sous la surface de saisie par défaut (barre de navigation
  /// système, clavier logiciel…).
  ///
  /// `null` ⇒ l'inset système (`MediaQuery.paddingOf(context).bottom`) ;
  /// `0` ⇒ aucune réserve, l'hôte gouverne. La surface **consomme** la valeur
  /// pour son sous-arbre : une rangée de notation imbriquée ne rend donc
  /// jamais une seconde gouttière.
  final double? bottomInset;

  /// Dossier de repli pour une carte dont `folderId` est nul.
  ///
  /// Identité **opaque** (jamais un libellé rendu) : `ZSessionItem.folderId`
  /// est requis, et une carte éphémère peut ne pas en porter.
  final String fallbackFolderId;

  /// Surcharge de la part verticale de la pile.
  final int? stackFlex;

  /// Surcharge de la part verticale de la zone de saisie.
  final int? inputFlex;

  /// Surcharge du padding interne.
  final EdgeInsetsGeometry? contentPadding;

  /// Surcharge de l'épaisseur du séparateur.
  final double? dividerThickness;

  /// Surcharge de l'écart vertical entre blocs.
  final double? sectionGap;

  /// Surcharge de la cible tap minimale.
  final double? minTarget;

  /// Surcharge du style du compteur.
  final TextStyle? counterStyle;

  @override
  State<ZStudySessionHost> createState() => _ZStudySessionHostState();
}

class _ZStudySessionHostState extends State<ZStudySessionHost>
    with ZDisplayStateOwnerMixin<ZStudySessionHost> {
  // ── Tranches POSSÉDÉES (AD-2) ─────────────────────────────────────────────
  final ValueNotifier<ZStudySessionPhase> _phase =
      ValueNotifier<ZStudySessionPhase>(ZStudySessionPhase.empty);
  final ValueNotifier<List<ZSessionItem>> _queue =
      ValueNotifier<List<ZSessionItem>>(const <ZSessionItem>[]);
  final ValueNotifier<ZSessionItem?> _current =
      ValueNotifier<ZSessionItem?>(null);
  final ValueNotifier<ZStudySessionProgress> _progress =
      ValueNotifier<ZStudySessionProgress>(const ZStudySessionProgress());

  /// Cartes indexées par IDENTITÉ (2ᵉ liste parallèle — su-7).
  Map<String, ZFlashcard> _cardsById = const <String, ZFlashcard>{};

  /// Soumissions enregistrées par **identité de carte**, jamais par index.
  final Map<String, ZFlashcardSubmission> _submissionsById =
      <String, ZFlashcardSubmission>{};

  /// Runtime POSSÉDÉ (libéré au remplacement et au `dispose`).
  ChangeNotifier? _runtime;

  final Stopwatch _stopwatch = Stopwatch();

  /// Index courant du swiper — utile aux SEULS runtimes à file FIXE.
  int _index = 0;

  /// Taille de la file d'ORIGINE (le total ne bouge pas sous les réinsertions).
  int _total = 0;

  /// Latch one-shot de fin de session.
  bool _celebrated = false;

  /// Retenue en cours : la carte est notée, mais pas encore partie.
  ///
  /// Tranche possédée et écoutée SEULE par l'action de continuation : la
  /// bascule de retenue ne reconstruit ni la pile, ni la saisie, ni les
  /// compteurs (AD-2).
  final ValueNotifier<bool> _held = ValueNotifier<bool>(false);

  /// Affichage GELÉ : les tranches ne suivent plus le moteur.
  ///
  /// 🔒 Posé AVANT `grade`, et non après : le moteur notifie pendant sa
  /// notation, et cette notification ferait déjà avancer la carte courante —
  /// la retenue arriverait trop tard, sur une carte déjà remplacée. Champ
  /// simple, non notifiant : il ne gouverne aucun rendu, seulement la
  /// propagation.
  bool _frozen = false;

  /// La file du moteur était-elle épuisée au moment de la retenue ?
  ///
  /// La dernière carte est retenue comme les autres — sinon sa réponse serait
  /// la seule à ne jamais s'afficher. La fin de session est donc différée
  /// jusqu'à la continuation, et l'information doit survivre à l'intervalle.
  bool _pendingComplete = false;

  /// Source de vérité UNIQUE de la révélation — possédée, jamais recréée.
  ///
  /// Créée à la première carte qui la consomme, et **seulement** si l'écran
  /// porte l'affordance : un contrôleur déclaré puis jamais branché serait un
  /// bouton mort, et le patron `ZDisplayStateOwnerMixin` le refuse au
  /// `dispose`.
  ZToggleController? _reveal;

  /// Identité de la carte de DEVANT à la dernière synchronisation.
  ///
  /// Sert l'invariant porteur : la révélation se referme quand la carte de
  /// devant change. Sans elle, l'apprenant verrait la réponse de la carte
  /// suivante avant même sa question — la carte de devant est un `Element`
  /// NEUF (sa `key` dérive du `flashcardId`), donc le reset interne de la
  /// carte au changement de `card` ne s'y produit pas.
  String? _frontId;

  /// Rappel de question ABRÉGÉ, mémoïsé — jamais réalloué par build.
  ///
  /// Une closure réallouée à chaque build changerait d'identité et casserait
  /// la stabilité des rebuilds (AD-2).
  ZFlashcardContentBuilder? _compactRecall;

  /// Rappel de question SUPPRIMÉ, mémoïsé (même motif).
  ZFlashcardContentBuilder? _hiddenRecall;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  // La création du contrôleur de révélation est TARDIVE par construction : on
  // ne le crée qu'au premier créneau de carte qui le consomme, pour ne jamais
  // laisser un contrôleur possédé sans consommateur (file vide, phase
  // `unavailable`, `cardBuilder` de l'hôte). La borne temporelle du patron est
  // donc levée ici, et la propriété qu'elle protège — instance STABLE, jamais
  // remplacée par un rebuild — est tenue par le `??=` de `_revealController`,
  // pas par le hasard.
  @override
  bool get zAllowsLateDisplayState => true;

  /// Vrai si la révélation est réellement **branchée** sur la carte rendue.
  ///
  /// Deux cartes s'y branchent : celle du socle, et celle d'un hôte qui passe
  /// par `cardSlotBuilder` (il reçoit l'état et la commande). Celle d'un
  /// `cardBuilder` seul ne s'y branche pas — un contrôleur qui ne dévoile rien
  /// n'est pas monté.
  bool get _revealAvailable =>
      (widget.cardSlotBuilder != null || widget.cardBuilder == null) &&
      zStudySessionRevealsAnswer(widget.mode, widget.revealPolicy);

  /// Vrai si l'écran rend l'action de révélation **du socle**.
  ///
  /// Un `cardSlotBuilder` fourni la retire : l'hôte a reçu la commande et pose
  /// son propre contrôle, là où il veut. Deux boutons sur le même état se
  /// superposeraient.
  bool get _nativeRevealAction =>
      _revealAvailable && widget.cardSlotBuilder == null;

  /// Vrai si la carte notée est retenue avant de partir (table unique).
  bool get _holdsAfterSubmit =>
      zStudySessionHoldsAfterSubmit(widget.mode, widget.postSubmitPolicy);

  /// Contrôleur de révélation — créé une fois, STABLE, disposé par le patron.
  ZToggleController get _revealController =>
      _reveal ??= ZToggleController(owner: this, initialValue: false);

  @override
  void didUpdateWidget(covariant ZStudySessionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentBuilder != widget.contentBuilder) {
      // Les décorateurs mémoïsés enveloppent le builder de l'hôte : ils sont
      // périmés dès qu'il change.
      _compactRecall = null;
      _hiddenRecall = null;
    }
    // ④ su-8 — RESYNC. Un re-seed n'a lieu que sur un changement RÉEL (mode, ou
    // identité de la file d'entrée). Sans cette garde d'identité, chaque
    // rebuild du parent redémarrerait la session ; avec elle, une file qui
    // rétrécit ou change d'ordre ré-amorce un runtime NEUF — et l'index repart
    // à 0, jamais un curseur survivant à la file qu'il n'indexe plus.
    if (oldWidget.mode != widget.mode ||
        _identityOf(oldWidget.queue) != _identityOf(widget.queue)) {
      _seed();
    }
  }

  @override
  void dispose() {
    _runtime?.removeListener(_onRuntimeChanged);
    _runtime?.dispose();
    _stopwatch.stop();
    _phase.dispose();
    _held.dispose();
    _queue.dispose();
    _current.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Empreinte d'identité d'une file de flashcards (ordre des `id`).
  String _identityOf(List<ZFlashcard> cards) =>
      cards.map((ZFlashcard c) => c.id ?? '').join('|');

  // ── Amorçage ──────────────────────────────────────────────────────────────

  void _seed() {
    _runtime?.removeListener(_onRuntimeChanged);
    _runtime?.dispose();
    _runtime = null;
    _submissionsById.clear();
    _celebrated = false;
    _index = 0;
    // Une session neuve repart FACE QUESTION, quoi qu'ait laissé la
    // précédente.
    _frontId = null;
    _reveal?.value = false;
    _held.value = false;
    _frozen = false;
    _pendingComplete = false;

    final List<ZSessionItem> items = <ZSessionItem>[];
    final Map<String, ZFlashcard> byId = <String, ZFlashcard>{};
    for (final ZFlashcard card in widget.queue) {
      final String? id = card.id;
      if (id == null) continue; // défensif : une carte éphémère est écartée.
      items.add(
        ZSessionItem(
          flashcardId: id,
          folderId: card.folderId ?? widget.fallbackFolderId,
        ),
      );
      byId[id] = card;
    }
    _cardsById = Map<String, ZFlashcard>.unmodifiable(byId);
    _queue.value = List<ZSessionItem>.unmodifiable(items);
    _total = items.length;

    if (items.isEmpty) {
      _current.value = null;
      _progress.value = const ZStudySessionProgress();
      _phase.value = ZStudySessionPhase.empty;
      return;
    }

    final ChangeNotifier? runtime = _makeRuntime(_queue.value);
    if (runtime == null) {
      // AD-34/AD-10 — mode SRS sans reviewer : on ne fabrique PAS de no-op et
      // on ne détourne PAS le mode vers un runtime linéaire (son `assert` le
      // refuserait). On le DIT.
      _current.value = null;
      _progress.value = ZStudySessionProgress(total: _total);
      _phase.value = ZStudySessionPhase.unavailable;
      return;
    }
    _runtime = runtime..addListener(_onRuntimeChanged);
    if (runtime is ZWhiteExamSessionEngine) {
      // Machine d'examen : `setup → running` doit être amorcé avant toute
      // réponse (transition légale unique).
      runtime.start();
    }
    _stopwatch
      ..reset()
      ..start();
    _phase.value = ZStudySessionPhase.studying;
    _sync();
  }

  /// Crée le runtime **DÉSIGNÉ** par la table unique `zSessionRuntimeForMode`.
  ///
  /// 🔒 Un seul `switch`, et il porte sur le **verdict** de la table
  /// (`ZSessionRuntimeKind`), jamais sur le mode : impossible d'introduire ici
  /// une seconde table qui divergerait de celle de `zcrud_session` (AD-34).
  ChangeNotifier? _makeRuntime(List<ZSessionItem> queue) {
    switch (zSessionRuntimeForMode(widget.mode)) {
      case ZSessionRuntimeKind.srsEngine:
        final ZSessionReviewer? reviewer = widget.reviewer;
        if (reviewer == null) return null; // cf. `_seed` — phase `unavailable`.
        return ZStudySessionEngine(
          queue: queue,
          reviewer: reviewer,
          config: widget.config,
          mode: widget.mode,
        );
      case ZSessionRuntimeKind.linear:
        return ZLinearSessionState(
          queue: queue,
          mode: widget.mode,
          config: widget.config,
        );
      case ZSessionRuntimeKind.whiteExam:
        return ZWhiteExamSessionEngine(queue: queue, config: widget.config);
    }
  }

  // ── Synchronisation des tranches ──────────────────────────────────────────

  void _onRuntimeChanged() => _sync();

  /// Recalcule **uniquement** les tranches qui ont bougé.
  ///
  /// `ValueNotifier` n'émet pas si la valeur est `==` : `ZStudySessionProgress`
  /// et `ZSessionItem` sont des value-objects à égalité profonde, donc une
  /// notification du runtime qui ne change ni la carte de devant ni les
  /// compteurs ne reconstruit **aucun** slot.
  void _sync() {
    // Retenue en cours : l'écran reste sur la carte notée, telle quelle. La
    // notation, elle, est déjà partie.
    if (_frozen) return;
    final ChangeNotifier? rt = _runtime;
    final List<ZSessionItem> queue = _queue.value;

    // ① su-10 D1 — UNE SEULE SOURCE DE SÉQUENCE. En régime SRS la carte de
    // devant est TOUJOURS `engine.current` : le swiper suit la file dynamique
    // du moteur (cf. `_gradeAndAdvance`), il ne tient pas un second curseur.
    // Les runtimes à file FIXE (linéaire, examen — aucune réinsertion) suivent
    // l'index du swiper.
    final ZSessionItem? item;
    if (rt is ZStudySessionEngine) {
      item = rt.current;
    } else if (queue.isEmpty) {
      item = null;
    } else {
      item = queue[_index.clamp(0, queue.length - 1)];
    }
    _current.value = item;

    // 🔒 INVARIANT PORTEUR — la révélation se REFERME quand la carte de devant
    // change. La carte de devant est un `Element` neuf à chaque changement (sa
    // `key` dérive du `flashcardId`) : son propre reset au changement de
    // `card` ne s'y produit donc jamais, et sans ce reset l'apprenant verrait
    // la RÉPONSE de la carte suivante avant sa question.
    final String? frontId = item?.flashcardId;
    if (frontId != _frontId) {
      _frontId = frontId;
      _reveal?.value = false;
    }

    final int reviewed;
    final int remaining;
    final int lapses;
    if (rt is ZStudySessionEngine) {
      reviewed = rt.reviewed;
      remaining = rt.remaining;
      lapses = rt.lapses;
    } else if (rt is ZLinearSessionState) {
      reviewed = rt.reviewed;
      remaining = rt.remaining;
      lapses = rt.lapses;
    } else if (rt is ZWhiteExamSessionEngine) {
      reviewed = rt.answered;
      remaining = rt.remaining;
      lapses = 0; // l'examen ne compte pas de lapse : son verdict est différé.
    } else {
      reviewed = 0;
      remaining = 0;
      lapses = 0;
    }
    _progress.value = ZStudySessionProgress(
      total: _total,
      reviewed: reviewed,
      remaining: remaining,
      lapses: lapses,
      index: _index,
    );
  }

  void _onIndexChanged(int index) {
    _index = index;
    _sync();
  }

  // ── Notation ──────────────────────────────────────────────────────────────

  /// Route une soumission vers le runtime **désigné** — aucun aiguillage
  /// secondaire sur le mode.
  void _onSubmitted(String cardId, ZFlashcardSubmission submission) {
    // Pendant une retenue, la session est FIGÉE sur la carte déjà notée : une
    // seconde soumission la noterait une seconde fois. La voie d'écriture reste
    // unique ET tirée une seule fois par carte (AD-33).
    if (_frozen) return;
    // Association réponse ↔ carte par `flashcardId` (su-4 D2 / su-7).
    _submissionsById[cardId] = submission;
    final ChangeNotifier? rt = _runtime;
    switch (zSessionRuntimeForMode(widget.mode)) {
      case ZSessionRuntimeKind.srsEngine:
        final ZStudySessionEngine? engine =
            rt is ZStudySessionEngine ? rt : null;
        // La garde d'identité tient PAR CONSTRUCTION (la carte affichée EST le
        // front du moteur) ; elle protège encore contre une note sur la
        // mauvaise carte, sans jamais diverger du swiper.
        if (engine != null && engine.current?.flashcardId == cardId) {
          unawaited(_gradeAndAdvance(engine, submission.quality));
        }
      case ZSessionRuntimeKind.linear:
        // `answer` sert `list` ET `cramming` : en `list` la qualité est
        // ignorée et l'appel délègue à `advanceLinear` — identique à
        // `advance()`. AUCUNE écriture SRS n'est atteignable (ce runtime n'a
        // pas de seam).
        (rt is ZLinearSessionState ? rt : null)?.answer(submission.quality);
      case ZSessionRuntimeKind.whiteExam:
        final ZWhiteExamSessionEngine? engine =
            rt is ZWhiteExamSessionEngine ? rt : null;
        if (engine != null && engine.state.phase == ZWhiteExamPhase.running) {
          engine.answer(submission.quality);
        }
    }
  }

  /// Note la carte courante, puis fait **SUIVRE** le swiper à la file DYNAMIQUE
  /// du moteur (① su-10 D1).
  ///
  /// Sur réussite/lapse, `engine.state.queue` devient la nouvelle file de la
  /// pile — un lapse y réapparaît en aval, une réussite consomme la carte — et
  /// le front reste `engine.current`. Une seule séquence, jamais deux curseurs
  /// qui divergeraient au 1ᵉʳ lapse (et donc jamais une note qui tombe à côté).
  Future<void> _gradeAndAdvance(
    ZStudySessionEngine engine,
    int quality,
  ) async {
    // Le gel précède la notation : le moteur notifie AVANT que ce `Future` ne
    // retombe, et sans lui la carte serait déjà remplacée quand la retenue
    // s'appliquerait.
    _frozen = _holdsAfterSubmit;
    final result = await engine.grade(quality);
    if (!mounted) return;
    result.fold(
      (_) {
        // AD-10 — échec TYPÉ : la file du moteur est inchangée, la saisie est
        // conservée, la carte reste affichée. L'échec vit dans l'état du
        // moteur ; il n'est ni avalé, ni transformé en exception. Rien n'a été
        // noté : il n'y a donc rien à retenir.
        _frozen = false;
      },
      (_) {
        // 🔒 La note est DÉJÀ partie ci-dessus, au même moment et avec la même
        // valeur qu'avant : ce qui suit ne décide que de l'instant du passage.
        if (_holdsAfterSubmit) {
          _pendingComplete = engine.isComplete;
          // La réponse est portée à l'écran par la carte elle-même — celle du
          // socle via son contrôleur, celle de l'hôte via le créneau.
          if (_revealAvailable) _revealController.value = true;
          _held.value = true;
          return;
        }
        _frozen = false;
        if (engine.isComplete) {
          _onStackEnd();
          return;
        }
        _index = 0;
        _queue.value = engine.state.queue;
        _sync();
      },
    );
  }

  /// Lève la retenue : la carte notée part enfin, ou la session se termine.
  ///
  /// N'écrit **aucun** SRS — la note est partie à la soumission. Ce geste ne
  /// fait que ce que `_gradeAndAdvance` aurait fait sans retenue.
  void _continueAfterHold() {
    if (!_held.value) return;
    _held.value = false;
    _frozen = false;
    if (_pendingComplete) {
      _pendingComplete = false;
      _onStackEnd();
      return;
    }
    final ChangeNotifier? rt = _runtime;
    if (rt is! ZStudySessionEngine) return;
    _index = 0;
    _queue.value = rt.state.queue;
    _sync();
  }

  /// Latch **one-shot** : la fin de session est poussée exactement une fois,
  /// même si l'événement est ré-émis (re-boucle cramming incluse).
  void _onStackEnd() {
    if (_celebrated) return;
    _celebrated = true;
    _stopwatch.stop();
    final ChangeNotifier? rt = _runtime;
    if (rt is ZWhiteExamSessionEngine &&
        rt.state.phase == ZWhiteExamPhase.running) {
      rt.submit(); // fige le score — transition légale unique.
    }
    _phase.value = ZStudySessionPhase.celebrating;
    widget.onSessionEnd?.call(_result(), _stopwatch.elapsed);
  }

  /// Résultat agrégé, construit depuis la **tally d'identité** (association par
  /// `flashcardId`, jamais par index). Pour l'examen, le moteur est le scoreur
  /// légitime : on préfère son résultat figé.
  ZStudySessionResult _result() {
    final ChangeNotifier? rt = _runtime;
    if (rt is ZWhiteExamSessionEngine) {
      final ZStudySessionResult? scored = rt.state.result;
      if (scored != null) return scored;
    }
    final Map<String, int> byQuality = <String, int>{};
    var correct = 0;
    for (final ZFlashcardSubmission sub in _submissionsById.values) {
      final String key = '${sub.quality}';
      byQuality[key] = (byQuality[key] ?? 0) + 1;
      if (sub.quality >= widget.config.passThreshold) correct += 1;
    }
    return ZStudySessionResult(
      mode: widget.mode,
      total: _submissionsById.length,
      correct: correct,
      byQuality: byQuality,
    );
  }

  // ── Construction ──────────────────────────────────────────────────────────

  /// Repli AD-10 **observable** : les deux listes parallèles (file d'identités
  /// / table `flashcardId → ZFlashcard`) se sont désynchronisées.
  ///
  /// Jamais un `SizedBox.shrink()` : un défaut rendu invisible est un défaut
  /// qu'aucun test — et aucun utilisateur — ne peut signaler. Jamais une
  /// exception non plus : la désynchronisation d'une carte ne fait pas tomber
  /// la session.
  Widget _missingCard(BuildContext context) => Center(
        key: ZStudySessionView.missingCardKey,
        child: Text(
          widget.labels?.missingCard ??
              label(
                context,
                ZStudySessionView.missingCardLabelKey,
                fallback: 'Carte introuvable',
              ),
          textAlign: TextAlign.center,
        ),
      );

  /// ② Carte d'AFFICHAGE — résolue par **identité** dans `_cardsById`, jamais
  /// par index.
  Widget _buildCard(BuildContext context, ZSessionItem item) {
    final ZFlashcard? card = _cardsById[item.flashcardId];
    if (card == null) return _missingCard(context);
    final custom = widget.cardBuilder;
    if (custom != null) return custom(context, card);
    return ZFlashcardReviewCard(
      key: ValueKey<String>('zStudySessionCard_${item.flashcardId}'),
      card: card,
      contentBuilder: widget.contentBuilder,
    );
  }

  /// Créneau de carte — même résolution par identité que [_buildCard], plus la
  /// seule information que la pile détient : **quelle carte est devant**.
  ///
  /// Le contrôleur de révélation n'est branché que sur la carte de devant. Le
  /// partager avec les cartes empilées derrière elle les ouvrirait toutes en
  /// même temps : la réponse de la carte suivante serait lisible **avant** sa
  /// question.
  Widget _buildCardSlot(BuildContext context, ZSessionCardSlot slot) {
    final ZFlashcard? card = _cardsById[slot.item.flashcardId];
    if (card == null) return _missingCard(context);
    final ZStudySessionCardSlotBuilder? host = widget.cardSlotBuilder;
    if (host != null) return _buildHostCardSlot(context, slot, card, host);
    return ZFlashcardReviewCard(
      key: ValueKey<String>('zStudySessionCard_${slot.item.flashcardId}'),
      card: card,
      contentBuilder: widget.contentBuilder,
      revealController: slot.isFront ? _revealController : null,
    );
  }

  /// Relais du créneau vers la carte de l'HÔTE.
  ///
  /// La révélation n'est écoutée que pour la carte de devant : abonner les
  /// cartes empilées reconstruirait toute la pile à chaque bascule, et leur
  /// donnerait un état de révélation qu'elles ne doivent pas avoir.
  Widget _buildHostCardSlot(
    BuildContext context,
    ZSessionCardSlot slot,
    ZFlashcard card,
    ZStudySessionCardSlotBuilder host,
  ) {
    if (!slot.isFront || !_revealAvailable) {
      return host(
        context,
        ZStudySessionCardSlot(slot: slot, card: card, revealed: false),
      );
    }
    return _HostRevealSlot(
      // Identité de la carte : un `State` de liaison neuf par carte de devant.
      key: ValueKey<String>('zStudyHostSlot_${slot.item.flashcardId}'),
      controller: _revealController,
      builder: (BuildContext context, bool revealed, VoidCallback toggle) =>
          host(
        context,
        ZStudySessionCardSlot(
          slot: slot,
          card: card,
          revealed: revealed,
          toggleReveal: toggle,
        ),
      ),
    );
  }

  /// Zone d'action sous la pile : action de continuation pendant une retenue,
  /// bascule de révélation sinon.
  ///
  /// Les deux ne coexistent jamais : pendant la retenue, la réponse est déjà à
  /// l'écran et le seul geste attendu est de passer à la suite.
  Widget _buildRevealSlot(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: _held,
        builder: (BuildContext context, bool held, Widget? _) {
          if (held) {
            return Padding(
              padding: ZStudySessionReference.revealActionPadding,
              child: _ContinueAction(
                onPressed: _continueAfterHold,
                minTarget: widget.minTarget ?? ZStudySessionReference.minTarget,
                continueLabel: widget.labels?.continueAction,
              ),
            );
          }
          if (!_nativeRevealAction) return const SizedBox.shrink();
          return _buildReveal(context);
        },
      );

  /// Action de révélation — bascule la SEULE source de vérité, et rien d'autre.
  ///
  /// N'écrit aucun SRS, ne note pas, ne fait pas avancer la pile.
  Widget _buildReveal(BuildContext context) => Padding(
        padding: ZStudySessionReference.revealActionPadding,
        child: _RevealToggle(
          controller: _revealController,
          minTarget: widget.minTarget ?? ZStudySessionReference.minTarget,
          revealLabel: widget.labels?.revealAction,
          hideLabel: widget.labels?.hideAction,
        ),
      );

  /// Builder de rappel de question RÉELLEMENT passé à la surface de saisie.
  ///
  /// En régime `full`, c'est **exactement** la référence de l'hôte : aucun
  /// nœud intercalé, aucune closure allouée.
  ZFlashcardContentBuilder? _recallBuilder(BuildContext context) {
    final ZStudySessionQuestionRecall effective = zResolveQuestionRecall(
      widget.questionRecall,
      // La largeur de la FENÊTRE, lue sans intercaler de nœud : un
      // `LayoutBuilder` changerait l'arbre de tout hôte, y compris celui qui
      // n'a rien demandé.
      MediaQuery.sizeOf(context).width,
    );
    switch (effective) {
      case ZStudySessionQuestionRecall.auto:
      case ZStudySessionQuestionRecall.full:
        return widget.contentBuilder;
      case ZStudySessionQuestionRecall.compact:
        return _compactRecall ??= _buildCompactRecall;
      case ZStudySessionQuestionRecall.hidden:
        return _hiddenRecall ??= _buildHiddenRecall;
    }
  }

  Widget _buildCompactRecall(BuildContext context, String content) {
    final ZFlashcardContentBuilder? inner = widget.contentBuilder;
    final Color surface = Theme.of(context).colorScheme.surface;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: ZStudySessionReference.compactRecallMaxHeight,
      ),
      child: ZFadedOverflow(
        fadeExtent: ZStudySessionReference.compactRecallFadeExtent,
        opaque: surface,
        clear: surface.withAlpha(0),
        child: inner == null
            ? Text(content, textAlign: TextAlign.start)
            : inner(context, content),
      ),
    );
  }

  Widget _buildHiddenRecall(BuildContext context, String content) =>
      const SizedBox.shrink();

  /// ② Surface de saisie/notation — résolue par **identité**, jamais par index.
  Widget _buildGrading(BuildContext context, ZSessionItem item) {
    // Voie de soumission UNIQUE — la même pour le slot de l'hôte et pour la
    // surface par défaut : association par `flashcardId`, jamais par index.
    void submit(ZFlashcardSubmission sub) =>
        _onSubmitted(item.flashcardId, sub);
    final custom = widget.gradingBuilder;
    if (custom != null) return custom(context, item, submit);
    final ZFlashcard? card = _cardsById[item.flashcardId];
    if (card == null) return _missingCard(context);
    return ZFlashcardAnswerInput(
      // Clé d'IDENTITÉ : un `State` neuf par carte courante — jamais une saisie
      // qui fuit d'une carte à l'autre.
      key: ValueKey<String>('zStudySessionAnswer_${item.flashcardId}'),
      card: card,
      mode: widget.mode,
      srsConfig: widget.config,
      contentBuilder: _recallBuilder(context),
      bottomInset: widget.bottomInset,
      evaluationPort: widget.evaluationPort,
      hintPort: widget.hintPort,
      onSubmitted: submit,
    );
  }

  ZStudySessionSummaryBuilder? get _summarySlot {
    final ZStudySessionResultBuilder? builder = widget.summaryBuilder;
    if (builder == null) return null; // AD-4 — absent de l'arbre.
    return (BuildContext context) =>
        builder(context, _result(), _stopwatch.elapsed);
  }

  @override
  Widget build(BuildContext context) => ZStudySessionView(
        slices: ZStudySessionSlices(
          phase: _phase,
          queue: _queue,
          current: _current,
          progress: _progress,
        ),
        cardBuilder: _buildCard,
        // AD-4 — `null` quand l'affordance n'est pas portée : la pile emprunte
        // alors `cardBuilder`, exactement comme avant.
        cardSlotBuilder: (widget.cardSlotBuilder != null || _revealAvailable)
            ? _buildCardSlot
            : null,
        // AD-4 — `null` tant qu'aucune des deux actions n'est possible : la
        // zone n'est alors PAS dans l'arbre, exactement comme avant.
        revealBuilder: (_nativeRevealAction || _holdsAfterSubmit)
            ? _buildRevealSlot
            : null,
        gradingBuilder: _buildGrading,
        passThreshold: widget.config.passThreshold,
        headerBuilder: widget.headerBuilder,
        counterBuilder: widget.counterBuilder,
        summaryBuilder: _summarySlot,
        emptyBuilder: widget.emptyBuilder,
        celebrationBuilder: widget.celebrationBuilder,
        labels: widget.labels,
        onIndexChanged: _onIndexChanged,
        onStackEnd: _onStackEnd,
        onExit: widget.onExit,
        indexController: widget.indexController,
        progressStyle: widget.progressStyle,
        stackFlex: widget.stackFlex,
        inputFlex: widget.inputFlex,
        contentPadding: widget.contentPadding,
        dividerThickness: widget.dividerThickness,
        sectionGap: widget.sectionGap,
        minTarget: widget.minTarget,
        counterStyle: widget.counterStyle,
      );
}

/// Bascule « afficher / masquer la réponse » de la carte de devant.
///
/// N'écoute QUE le contrôleur de révélation : un changement de face ne
/// reconstruit ni la pile, ni la saisie, ni les compteurs (AD-2). Cible
/// ≥ 48 dp en géométrie rendue, `Semantics` explicite, libellés injectés
/// (AD-13 / FR-26).
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({
    required this.controller,
    required this.minTarget,
    required this.revealLabel,
    required this.hideLabel,
  });

  final ZToggleController controller;
  final double minTarget;
  final String? revealLabel;
  final String? hideLabel;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: controller,
        builder: (BuildContext context, bool revealed, Widget? _) {
          // Le libellé d'une bascule décrit ce que le geste fait MAINTENANT :
          // face réponse, il masque. Un libellé constant serait faux dans la
          // moitié des états.
          final String text = revealed
              ? hideLabel ??
                  label(
                    context,
                    ZStudySessionHost.hideLabelKey,
                    fallback: 'Masquer la réponse',
                  )
              : revealLabel ??
                  label(
                    context,
                    ZStudySessionHost.revealLabelKey,
                    fallback: 'Afficher la réponse',
                  );
          return Semantics(
            button: true,
            label: text,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minTarget,
                minHeight: minTarget,
              ),
              child: TextButton(
                key: ZStudySessionHost.revealActionKey,
                onPressed: controller.toggle,
                // Ceinture ET bretelles : le `ButtonStyle` de Material 3 pose
                // une taille minimale sous la cible AD-13. La contrainte
                // parente la relèverait déjà, mais elle ne voyagerait pas avec
                // le bouton chez un hôte qui l'enveloppe autrement.
                style: TextButton.styleFrom(
                  minimumSize: Size(minTarget, minTarget),
                ),
                child: ExcludeSemantics(child: Text(text)),
              ),
            ),
          );
        },
      );
}

/// Action « continuer » — lève la retenue et rien d'autre.
///
/// N'écoute aucun état : elle n'existe que pendant la retenue, et son libellé
/// ne change pas. Cible ≥ 48 dp en géométrie rendue, `Semantics` explicite,
/// libellé injecté (AD-13 / FR-26).
class _ContinueAction extends StatelessWidget {
  const _ContinueAction({
    required this.onPressed,
    required this.minTarget,
    required this.continueLabel,
  });

  final VoidCallback onPressed;
  final double minTarget;
  final String? continueLabel;

  @override
  Widget build(BuildContext context) {
    final String text = continueLabel ??
        label(
          context,
          ZStudySessionHost.continueLabelKey,
          fallback: 'Continuer',
        );
    return Semantics(
      button: true,
      label: text,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minTarget, minHeight: minTarget),
        child: TextButton(
          key: ZStudySessionHost.continueActionKey,
          onPressed: onPressed,
          // Ceinture ET bretelles : le `ButtonStyle` de Material 3 pose une
          // taille minimale sous la cible AD-13, et la contrainte parente ne
          // voyagerait pas avec le bouton chez un hôte qui l'enveloppe.
          style: TextButton.styleFrom(
            minimumSize: Size(minTarget, minTarget),
          ),
          child: ExcludeSemantics(child: Text(text)),
        ),
      ),
    );
  }
}

/// Liaison d'écoute entre le contrôleur de révélation de l'écran et la carte
/// composée par l'hôte.
///
/// Passe par [ZDisplayStateBinding] plutôt que d'écouter le contrôleur
/// directement : c'est la liaison qui **marque la consommation**, sans laquelle
/// un contrôleur possédé mais jamais branché est refusé au `dispose`. Le
/// rebuild reste borné à ce sous-arbre (AD-2).
class _HostRevealSlot extends StatefulWidget {
  const _HostRevealSlot({
    required this.controller,
    required this.builder,
    super.key,
  });

  final ZToggleController controller;

  final Widget Function(BuildContext context, bool revealed, VoidCallback
      toggle) builder;

  @override
  State<_HostRevealSlot> createState() => _HostRevealSlotState();
}

class _HostRevealSlotState extends State<_HostRevealSlot> {
  late final ZDisplayStateBinding<bool> _binding;

  @override
  void initState() {
    super.initState();
    _binding = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)
      ..bind(widget.controller);
  }

  @override
  void didUpdateWidget(covariant _HostRevealSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _binding.bind(widget.controller); // no-op si identique
  }

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: _binding.listenable,
        builder: (BuildContext context, bool revealed, Widget? _) =>
            widget.builder(context, revealed, widget.controller.toggle),
      );
}
