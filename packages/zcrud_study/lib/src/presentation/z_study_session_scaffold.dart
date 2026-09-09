/// **Lot 1 « étude »** — [ZStudySessionScaffold] : l'enveloppe de PAGE, mince.
///
/// ## Ce que « mince » veut dire ici
///
/// Ce type ne fait **que deux choses** : il pose un `ZPageScaffold`
/// (`zcrud_ui_kit`, SUF-1) et lui donne pour corps un [ZStudySessionHost].
/// Il n'ajoute **aucun** rendu propre, ne réimplémente **aucune** app-bar
/// (la garde `suf3_source_guard_test.dart` interdit `AppBar(`/`SliverAppBar(`
/// dans ce package pour cette raison exacte), et **ne consomme** aucun des
/// paramètres qu'il transmet.
///
/// Tous les slots de page (`ZPageScaffold`) et tous les slots de session
/// ([ZStudySessionHost]) sont en **pass-through**. Un slot non fourni est
/// **structurellement absent** — la valeur transmise est le `null` du
/// paramètre, jamais un objet vide fabriqué ici.
///
/// ## 💡 Quand NE PAS l'utiliser
///
/// Patron **exact** de l'arbitrage documenté par `ZPageScaffold` : un hôte
/// dont le `Scaffold` est non trivial
/// — enveloppé dans un `PopScope`, aiguillé selon l'état, ou porteur d'un slot
/// que ce pass-through n'expose pas — ne doit **pas** passer par ici. Il compose
/// directement [ZStudySessionHost] (ou [ZStudySessionView] s'il détient déjà son
/// propre état) dans son arbre à lui, et garde **tous** ses slots, présents et
/// futurs.
///
/// C'est le même arbitrage `ZPageScaffold` / `ZPageShellBody`, décliné d'un
/// cran plus haut : **un** scaffold, **un** porteur.
///
/// ## Un seul `Scaffold`
///
/// Ce type n'en construit aucun : c'est `ZPageScaffold` qui le fait, en **site
/// unique**. Empiler ce scaffold dans un autre produirait deux porteurs de
/// slots (FAB fantôme, double tiroir) — d'où l'arbitrage ci-dessus.
///
/// ## Deux façons d'énoncer le montage
///
/// Le constructeur par défaut prend les seams **à plat**, chacun optionnel :
/// en oublier un ne se voit qu'à l'écran. `ZStudySessionScaffold.wired` prend
/// un `ZStudySessionWiring`, dont chaque champ est `required` : l'oubli devient
/// une erreur de compilation. Les deux montent le **même** porteur et rendent
/// le même arbre à valeurs égales ; le second n'ajoute qu'une obligation de
/// nommer.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZIndexController;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcard,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardContentBuilder,
        ZFlashcardHintPort,
        ZFlashcardQuestionTypeBadgeBuilder,
        ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZQualityColorKeyResolver,
        ZQualityLabelKeyResolver,
        ZSessionDotsGeometry,
        ZSessionProgressStyle,
        ZSessionReviewer,
        ZSrsQualityEmphasis,
        zDefaultQualityLabelKey;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart'
    show
        ZAppBarAction,
        ZAppBarSearchConfig,
        ZPageAppBarMode,
        ZPageScaffold,
        ZPageTab;

import 'preset/z_study_session_preset.dart';
import 'z_study_session_card_slot.dart';
import 'z_study_session_host.dart';
import 'z_study_session_post_submit.dart';
import 'z_study_session_recall.dart';
import 'z_study_session_reveal.dart';
import 'z_study_session_seam_audit.dart';
import 'z_study_session_view.dart';

/// Page complète d'une session de révision : `ZPageScaffold` + session.
///
/// Voir la dartdoc de bibliothèque pour l'arbitrage « quand NE PAS l'utiliser ».
class ZStudySessionScaffold extends StatelessWidget {
  /// Assemble la page. [title] est un `Widget` ou un `String` (contrat
  /// `ZPageScaffold`). Tous les autres paramètres sont des pass-through.
  const ZStudySessionScaffold({
    required this.title,
    required this.mode,
    required this.queue,
    this.reviewer,
    this.config = const ZSrsConfig(),
    this.cardBuilder,
    this.cardSlotBuilder,
    this.contentBuilder,
    this.questionTypeBadgeBuilder,
    this.instructionBanner,
    this.cardTypeGradientKey,
    this.cardAccentHeight,
    this.cardBackgroundColor,
    this.evaluationPort,
    this.hintPort,
    this.onQualitySelected,
    this.qualityLabelKeyFor = zDefaultQualityLabelKey,
    this.qualityColorKeyFor,
    this.qualityPreviewLabelFor,
    this.qualityEmphasis = ZSrsQualityEmphasis.none,
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
    this.preset,
    this.progressStyle,
    this.progressDotsGeometry,
    this.progressLinearThickness,
    this.progressSegmentedMarkerThickness,
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
    this.seamAudit,
    // ── Slots de page (`ZPageScaffold`) — pass-through intégral ────────────
    this.subtitle,
    this.gradientKey,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.pageMode = ZPageAppBarMode.fixed,
    this.tabAlignment,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    super.key,
  }) : _wiring = null;

  /// Page dont le montage de session est **ÉNUMÉRÉ** par [wiring].
  ///
  /// Même garantie qu'au porteur, d'un cran plus haut : chaque seam est un
  /// champ `required` de [ZStudySessionWiring], donc un montage doit tous les
  /// nommer, `null` compris. Oublier un seam devient une **erreur de
  /// compilation**, là où le constructeur par défaut le laisserait retomber en
  /// silence sur le défaut du socle.
  ///
  /// L'enveloppe ne lit **aucun** champ du wiring : elle le remet entier au
  /// porteur. Un seam qui rejoindra le montage demain traversera donc cette
  /// page sans qu'une ligne y soit écrite — et sans pouvoir y être oublié.
  ///
  /// Aucun seam ne se pose à plat ici : il n'y a ni règle de fusion, ni conflit
  /// possible entre deux façons de dire la même chose. Restent à plat les
  /// paramètres cosmétiques, ceux qui portent un défaut non nul, et **tous** les
  /// slots de page — que le montage de session ne décrit pas.
  ///
  /// À valeurs égales, l'écran rendu est celui du constructeur par défaut, nœud
  /// pour nœud.
  ///
  /// `const` — un montage dont tous les seams sont eux-mêmes constants (le cas
  /// d'un banc d'essai, ou de [ZStudySessionWiring.none]) se pose donc sans
  /// allocation.
  const ZStudySessionScaffold.wired({
    required ZStudySessionWiring wiring,
    required this.title,
    required this.mode,
    required this.queue,
    this.config = const ZSrsConfig(),
    this.cardTypeGradientKey,
    this.cardAccentHeight,
    this.cardBackgroundColor,
    this.qualityLabelKeyFor = zDefaultQualityLabelKey,
    this.qualityEmphasis = ZSrsQualityEmphasis.none,
    this.progressStyle,
    this.progressDotsGeometry,
    this.progressLinearThickness,
    this.progressSegmentedMarkerThickness,
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
    // ── Slots de page (`ZPageScaffold`) — pass-through intégral ────────────
    this.subtitle,
    this.gradientKey,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.pageMode = ZPageAppBarMode.fixed,
    this.tabAlignment,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    super.key,
  })  :
        // Un champ PRIVÉ ne peut pas être un paramètre initialisant : un
        // paramètre nommé ne commence jamais par `_`.
        // ignore: prefer_initializing_formals
        _wiring = wiring,
        // Les canaux à plat appartiennent à l'AUTRE constructeur : ici le
        // montage passe entier par `wiring`, et ces champs restent vides. Un
        // seam ajouté demain devra être nommé ici aussi — le compilateur
        // l'exige, aucun ne peut donc rejoindre la page en silence.
        reviewer = null,
        cardBuilder = null,
        cardSlotBuilder = null,
        contentBuilder = null,
        questionTypeBadgeBuilder = null,
        instructionBanner = null,
        evaluationPort = null,
        hintPort = null,
        onQualitySelected = null,
        qualityColorKeyFor = null,
        qualityPreviewLabelFor = null,
        headerBuilder = null,
        counterBuilder = null,
        gradingBuilder = null,
        summaryBuilder = null,
        emptyBuilder = null,
        celebrationBuilder = null,
        labels = null,
        onSessionEnd = null,
        onExit = null,
        indexController = null,
        preset = null,
        // Le montage énuméré ne peut RIEN oublier : il n'y a pas de filet à
        // poser sur un constructeur que le compilateur garde déjà.
        seamAudit = null;

  /// Montage énuméré, ou `null` quand la page est montée à plat.
  final ZStudySessionWiring? _wiring;

  /// Filet d'audit du montage — cf. [ZStudySessionHost.seamAudit].
  final ZStudySeamAuditPolicy? seamAudit;

  /// Titre de page : `Widget` rendu tel quel, ou `String` emballé.
  final Object title;

  /// Mode de session (entrée de `zSessionRuntimeForMode`).
  final ZReviewMode mode;

  /// File déjà sélectionnée.
  final List<ZFlashcard> queue;

  /// Voie d'écriture SRS injectée (AD-33).
  final ZSessionReviewer? reviewer;

  /// Configuration SRS (AD-46).
  final ZSrsConfig config;

  /// Slot de carte d'affichage.
  final Widget Function(BuildContext context, ZFlashcard card)? cardBuilder;

  /// Slot de carte qui reçoit le créneau complet (carte, rang, `isFront`,
  /// état de révélation, commande de bascule).
  final ZStudySessionCardSlotBuilder? cardSlotBuilder;

  /// Slot AD-40 de rendu du contenu.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Badge de type de question de la carte par défaut.
  final ZFlashcardQuestionTypeBadgeBuilder? questionTypeBadgeBuilder;

  /// Bandeau de consigne de la carte par défaut.
  final Widget? instructionBanner;

  /// Clé de dégradé explicite de la carte par défaut.
  ///
  /// À ne pas confondre avec [gradientKey], qui teinte l'**app-bar** de la
  /// page : celui-ci gouverne la **carte**.
  final String? cardTypeGradientKey;

  /// Hauteur du liseré de tête de la carte par défaut.
  final double? cardAccentHeight;

  /// Fond de la carte par défaut.
  ///
  /// À ne pas confondre avec [backgroundColor], qui peint le `Scaffold` de la
  /// page : celui-ci gouverne la **carte**.
  final Color? cardBackgroundColor;

  /// Port d'évaluation advisory.
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Port d'indices.
  final ZFlashcardHintPort? hintPort;

  /// Voie de notation manuelle de la surface de saisie.
  ///
  /// `null` ⇒ la rangée de crans est **absente de l'arbre** (AD-4) : c'est le
  /// seul état qui la monte, et sans elle les quatre seams de présentation qui
  /// suivent n'ont rien à peindre.
  final ValueChanged<int>? onQualitySelected;

  /// Seam de clé de libellé l10n d'un cran de notation.
  final ZQualityLabelKeyResolver qualityLabelKeyFor;

  /// Seam de clé de couleur d'un cran de notation.
  final ZQualityColorKeyResolver? qualityColorKeyFor;

  /// Seam d'aperçu d'intervalle prévisionnel sous chaque cran.
  final String Function(int quality)? qualityPreviewLabelFor;

  /// Affordance d'emphase des crans de notation.
  final ZSrsQualityEmphasis qualityEmphasis;

  /// Slot d'en-tête de session.
  final ZStudySessionHeaderBuilder? headerBuilder;

  /// Slot de compteurs.
  final ZStudySessionCounterBuilder? counterBuilder;

  /// Slot de saisie/notation.
  final ZStudySessionGradingSlotBuilder? gradingBuilder;

  /// Slot de résumé de fin.
  final ZStudySessionResultBuilder? summaryBuilder;

  /// Slot de repli « session vide ».
  final WidgetBuilder? emptyBuilder;

  /// Slot de célébration.
  final ZStudySessionCelebrationBuilder? celebrationBuilder;

  /// Libellés injectés (FR-26).
  final ZStudySessionLabels? labels;

  /// Notifié une seule fois en fin de session.
  final void Function(ZStudySessionResult result, Duration duration)?
      onSessionEnd;

  /// Issue de sortie des replis.
  final VoidCallback? onExit;

  /// Pilote optionnel de l'index de la pile.
  final ZIndexController? indexController;

  /// Formes de référence de session, relayées telles quelles.
  ///
  /// `null` ⇒ aucune branche prise. Chaque forme décrite est battue par le
  /// paramètre explicite qui lui correspond.
  final ZStudySessionPreset? preset;

  /// Style de l'indicateur de progression.
  ///
  /// `null` ⇒ le style du [preset] s'il en décrit un, sinon le style par
  /// défaut.
  final ZSessionProgressStyle? progressStyle;

  /// Forme des points de l'indicateur de progression — pass-through.
  ///
  /// `null` ⇒ la forme du [preset] s'il en décrit une, sinon le rendu par
  /// défaut de l'indicateur.
  final ZSessionDotsGeometry? progressDotsGeometry;

  /// Épaisseur de l'indicateur de progression continu — pass-through.
  final double? progressLinearThickness;

  /// Épaisseur de l'indicateur de progression segmenté à marqueur —
  /// pass-through.
  final double? progressSegmentedMarkerThickness;

  /// Politique de révélation de la réponse.
  final ZStudySessionRevealPolicy revealPolicy;

  /// Politique de retenue de la carte après notation.
  final ZStudySessionPostSubmitPolicy postSubmitPolicy;

  /// Régime de rappel de la question sous la surface de saisie.
  final ZStudySessionQuestionRecall questionRecall;

  /// Gouttière basse réservée sous la surface de saisie.
  ///
  /// À ne pas confondre avec [resizeToAvoidBottomInset], qui gouverne le
  /// redimensionnement du `Scaffold` au clavier.
  final double? bottomInset;

  /// Dossier de repli d'une carte sans `folderId`.
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

  /// Sous-titre d'app-bar — pass-through `ZPageScaffold`.
  final Widget? subtitle;

  /// Identité opaque alimentant le dégradé d'app-bar — pass-through.
  final String? gradientKey;

  /// Leading d'app-bar — pass-through.
  final Widget? leading;

  /// Actions d'app-bar — pass-through.
  final List<ZAppBarAction> actions;

  /// Configuration de recherche — pass-through.
  final ZAppBarSearchConfig? search;

  /// Onglets déclaratifs — pass-through.
  final List<ZPageTab>? tabs;

  /// Mode d'app-bar (fixe / sliver) — pass-through.
  final ZPageAppBarMode pageMode;

  /// Alignement de la barre d'onglets — pass-through `ZPageScaffold`.
  ///
  /// `null` (défaut) ⇒ rien n'est déclaré : le `TabBar` garde la résolution
  /// Flutter (`TabAlignment.startOffset`, la barre étant défilante).
  /// `TabAlignment.start` supprime le décrochage de tête et gagne la place
  /// correspondante pour les derniers onglets. `TabAlignment.fill` n'est pas
  /// valide sur une barre défilante et est assertionné par Flutter.
  final TabAlignment? tabAlignment;

  /// FAB — pass-through `Scaffold`.
  final Widget? floatingActionButton;

  /// Emplacement du FAB — pass-through `Scaffold`.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Boutons de pied persistants — pass-through `Scaffold`.
  final List<Widget>? persistentFooterButtons;

  /// Tiroir — pass-through `Scaffold`.
  final Widget? drawer;

  /// Tiroir de fin — pass-through `Scaffold`.
  final Widget? endDrawer;

  /// Barre de navigation basse — pass-through `Scaffold`.
  final Widget? bottomNavigationBar;

  /// Feuille basse — pass-through `Scaffold`.
  final Widget? bottomSheet;

  /// Couleur de fond — pass-through `Scaffold`.
  final Color? backgroundColor;

  /// Redimensionnement au clavier — pass-through `Scaffold`.
  final bool? resizeToAvoidBottomInset;

  /// Corps étendu — pass-through `Scaffold`.
  final bool extendBody;

  /// Corps étendu sous l'app-bar — pass-through `Scaffold`.
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) => ZPageScaffold(
        title: title,
        subtitle: subtitle,
        gradientKey: gradientKey,
        leading: leading,
        actions: actions,
        search: search,
        tabs: tabs,
        mode: pageMode,
        // Pass-through pur : `null` ⇒ aucun alignement déclaré côté shell.
        tabAlignment: tabAlignment,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        persistentFooterButtons: persistentFooterButtons,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
        body: _sessionHost(),
      );

  /// Le porteur de session, monté par la voie qu'a choisie le constructeur.
  ///
  /// Un seul `ZPageScaffold`, un seul porteur : la page ne se dédouble pas
  /// pour offrir deux montages.
  Widget _sessionHost() {
    final ZStudySessionWiring? wiring = _wiring;
    if (wiring != null) {
      return ZStudySessionHost.wired(
        wiring: wiring,
        mode: mode,
        queue: queue,
        config: config,
        cardTypeGradientKey: cardTypeGradientKey,
        cardAccentHeight: cardAccentHeight,
        cardBackgroundColor: cardBackgroundColor,
        qualityLabelKeyFor: qualityLabelKeyFor,
        qualityEmphasis: qualityEmphasis,
        progressStyle: progressStyle,
        progressDotsGeometry: progressDotsGeometry,
        progressLinearThickness: progressLinearThickness,
        progressSegmentedMarkerThickness: progressSegmentedMarkerThickness,
        revealPolicy: revealPolicy,
        postSubmitPolicy: postSubmitPolicy,
        questionRecall: questionRecall,
        bottomInset: bottomInset,
        fallbackFolderId: fallbackFolderId,
        stackFlex: stackFlex,
        inputFlex: inputFlex,
        contentPadding: contentPadding,
        dividerThickness: dividerThickness,
        sectionGap: sectionGap,
        minTarget: minTarget,
        counterStyle: counterStyle,
      );
    }
    return ZStudySessionHost(
      mode: mode,
      queue: queue,
      reviewer: reviewer,
      config: config,
      cardBuilder: cardBuilder,
      cardSlotBuilder: cardSlotBuilder,
      contentBuilder: contentBuilder,
      questionTypeBadgeBuilder: questionTypeBadgeBuilder,
      instructionBanner: instructionBanner,
      cardTypeGradientKey: cardTypeGradientKey,
      cardAccentHeight: cardAccentHeight,
      cardBackgroundColor: cardBackgroundColor,
      evaluationPort: evaluationPort,
      hintPort: hintPort,
      onQualitySelected: onQualitySelected,
      qualityLabelKeyFor: qualityLabelKeyFor,
      qualityColorKeyFor: qualityColorKeyFor,
      qualityPreviewLabelFor: qualityPreviewLabelFor,
      qualityEmphasis: qualityEmphasis,
      headerBuilder: headerBuilder,
      counterBuilder: counterBuilder,
      gradingBuilder: gradingBuilder,
      summaryBuilder: summaryBuilder,
      emptyBuilder: emptyBuilder,
      celebrationBuilder: celebrationBuilder,
      labels: labels,
      onSessionEnd: onSessionEnd,
      onExit: onExit,
      indexController: indexController,
      preset: preset,
      progressStyle: progressStyle,
      progressDotsGeometry: progressDotsGeometry,
      progressLinearThickness: progressLinearThickness,
      progressSegmentedMarkerThickness: progressSegmentedMarkerThickness,
      revealPolicy: revealPolicy,
      postSubmitPolicy: postSubmitPolicy,
      questionRecall: questionRecall,
      bottomInset: bottomInset,
      fallbackFolderId: fallbackFolderId,
      stackFlex: stackFlex,
      inputFlex: inputFlex,
      contentPadding: contentPadding,
      dividerThickness: dividerThickness,
      sectionGap: sectionGap,
      minTarget: minTarget,
      counterStyle: counterStyle,
      seamAudit: seamAudit,
    );
  }
}
