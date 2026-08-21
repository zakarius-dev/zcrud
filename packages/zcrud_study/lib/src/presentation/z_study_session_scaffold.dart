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
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZIndexController;
import 'package:zcrud_flashcard/zcrud_flashcard.dart'
    show
        ZFlashcard,
        ZFlashcardAnswerEvaluationPort,
        ZFlashcardContentBuilder,
        ZFlashcardHintPort,
        ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart'
    show ZSessionProgressStyle, ZSessionReviewer;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZReviewMode, ZStudySessionResult;
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart'
    show
        ZAppBarAction,
        ZAppBarSearchConfig,
        ZPageAppBarMode,
        ZPageScaffold,
        ZPageTab;

import 'z_study_session_host.dart';
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
  });

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

  /// Slot AD-40 de rendu du contenu.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Port d'évaluation advisory.
  final ZFlashcardAnswerEvaluationPort? evaluationPort;

  /// Port d'indices.
  final ZFlashcardHintPort? hintPort;

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

  /// Style de l'indicateur de progression.
  final ZSessionProgressStyle progressStyle;

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
        body: ZStudySessionHost(
          mode: mode,
          queue: queue,
          reviewer: reviewer,
          config: config,
          cardBuilder: cardBuilder,
          contentBuilder: contentBuilder,
          evaluationPort: evaluationPort,
          hintPort: hintPort,
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
          progressStyle: progressStyle,
          fallbackFolderId: fallbackFolderId,
          stackFlex: stackFlex,
          inputFlex: inputFlex,
          contentPadding: contentPadding,
          dividerThickness: dividerThickness,
          sectionGap: sectionGap,
          minTarget: minTarget,
          counterStyle: counterStyle,
        ),
      );
}
