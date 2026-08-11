/// **Lot 1 « étude »** — [ZStudySessionView] : le CORPS COMPOSABLE de l'écran
/// de session de révision.
///
/// 🚫 **Aucun `Scaffold`, aucune `AppBar`, aucune route.** C'est ce qu'un hôte
/// pose en page, en feuille modale ou en dialogue. L'enveloppe de page vit dans
/// `ZStudySessionScaffold` (mince, sur `ZPageScaffold`) ; le runtime vit dans
/// `ZStudySessionHost`. Trois responsabilités, trois types.
///
/// ## Ce que cette vue ne fait PAS
///
/// Elle ne détient **aucun** état, ne connaît **aucun** moteur, n'écrit
/// **aucun** SRS. Elle reçoit des [ZStudySessionSlices] (un `ValueListenable`
/// par tranche) et des callbacks. C'est ce qui rend SM-1 structurel : la vue
/// **ne peut pas** se reconstruire en entier, elle n'a pas les valeurs.
///
/// ## Les quatre pièges d'intégration, traités ici
///
/// La dartdoc de l'assemblage de référence
/// (`example/lib/demos/study_session_demo_screen.dart:72-100`) énumère les
/// pièges. Deux d'entre eux se règlent **dans cette vue** :
///
/// 1. **`key` de pile dérivée de l'identité de file** (su-4 D1) — la pile porte
///    `ValueKey('zStudySessionStack_<identité>')` où l'identité est l'ordre des
///    `flashcardId` (`zSessionQueueIdentity`). Une `key` constante, ou dérivée
///    de la seule longueur, laisserait l'`Element` du swiper survivre à une
///    file qu'il n'indexe plus → `RangeError`.
/// 2. **Résolution par `flashcardId`, jamais par index** (su-7) — la vue passe
///    au [cardBuilder] le `ZSessionItem` lui-même. Elle n'indexe **aucune**
///    liste parallèle : la table `flashcardId → ZFlashcard` est la charge du
///    constructeur de carte, et la vue ne lui donne pas d'index à confondre.
///
/// Les deux autres (source de séquence unique, resync `didUpdateWidget`) sont
/// des propriétés du **détenteur du runtime** — cf. `ZStudySessionHost`.
///
/// ## Slots — AD-4, avec la distinction qui compte
///
/// | Slot | `null` ⇒ |
/// |---|---|
/// | [headerBuilder] | **absent de l'arbre** |
/// | [counterBuilder] | **absent de l'arbre** |
/// | [gradingBuilder] | **absent de l'arbre** (avec son séparateur) |
/// | [celebrationBuilder] | **absent de l'arbre** |
/// | [summaryBuilder] | **absent de l'arbre** |
/// | [emptyBuilder] | repli par défaut **observable** (AD-10 : jamais un vide) |
///
/// Un slot additif nul est retiré par une **absence de nœud**
/// (`if (b != null) …` dans la liste d'enfants), **jamais** par un
/// `SizedBox.shrink()` inerte : un tel placeholder occupe une place dans le
/// `Column`, participe au calcul de flex, et rend l'assertion « le slot est
/// absent » indistinguable de « le slot rend du vide ».
///
/// 🔒 [emptyBuilder] n'est pas un slot additif mais un **repli remplaçable** —
/// patron `ZSessionCardSwiper.emptyBuilder` : AD-10 exige qu'une session sans
/// carte offre une **issue**, pas un écran muet. Le fournir **remplace** le
/// repli ; ne pas le fournir laisse le repli du socle.
///
/// ## FR-26 / AD-13
///
/// Aucun libellé en dur : chaque texte passe par [ZStudySessionLabels] injecté,
/// à défaut par `label(context, clé, fallback:)` (idiome `zcrud_session`).
/// Aucune couleur littérale : le chrome est résolu par `zStudySessionChromeOf`
/// en rôles du `ColorScheme`. Espacements directionnels, `Semantics` explicites,
/// cibles ≥ 48 dp **en géométrie rendue**.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZIndexController, label;
import 'package:zcrud_session/zcrud_session.dart'
    show
        ZSessionCardBuilder,
        ZSessionCardSwiper,
        ZSessionItem,
        ZSessionProgressStyle,
        ZSessionQualityAtIndex;

import 'z_study_session_reference.dart';
import 'z_study_session_slices.dart';

/// Construit l'en-tête de session (titre, contexte de dossier…).
typedef ZStudySessionHeaderBuilder = Widget Function(
  BuildContext context,
  ZStudySessionProgress progress,
);

/// Construit le bloc de compteurs (« 3 / 12 », lapses, restant…).
typedef ZStudySessionCounterBuilder = Widget Function(
  BuildContext context,
  ZStudySessionProgress progress,
);

/// Construit la surface de saisie **et** de notation de la carte de devant.
///
/// Reçoit le [ZSessionItem] — **jamais un index**. C'est le piège su-7 fermé
/// par la signature elle-même : la vue ne dispose d'aucun index à passer.
typedef ZStudySessionGradingBuilder = Widget Function(
  BuildContext context,
  ZSessionItem item,
);

/// Construit le résumé de fin de session.
typedef ZStudySessionSummaryBuilder = Widget Function(BuildContext context);

/// Construit la couche de célébration, **au-dessus** du résumé.
typedef ZStudySessionCelebrationBuilder = Widget Function(BuildContext context);

/// Libellés **injectés** de l'écran de session (FR-26).
///
/// Un champ nul retombe sur `label(context, clé, fallback:)` — donc sur la
/// résolution l10n de l'hôte (`ZcrudScope.labels`, puis le delegate, puis la
/// table `en`), et seulement en tout dernier recours sur le repli français.
/// Aucun libellé n'est donc figé dans l'arbre.
@immutable
class ZStudySessionLabels {
  /// Construit un jeu de libellés (tous optionnels).
  const ZStudySessionLabels({
    this.emptyMessage,
    this.exitAction,
    this.missingCard,
    this.unavailableMessage,
  });

  /// Message du repli « aucune carte à étudier ».
  final String? emptyMessage;

  /// Message du repli « session indisponible pour ce mode »
  /// ([ZStudySessionPhase.unavailable]).
  final String? unavailableMessage;

  /// Libellé **et** étiquette sémantique de l'issue de sortie.
  final String? exitAction;

  /// Message du repli « carte introuvable » (désynchronisation AD-10).
  final String? missingCard;
}

/// Corps composable de l'écran de session de révision.
///
/// Voir la dartdoc de bibliothèque pour les slots, les pièges traités et les
/// invariants. Ce type est un `StatelessWidget` **par construction** : tout
/// l'état vit dans les [slices].
class ZStudySessionView extends StatelessWidget {
  /// Assemble la vue.
  ///
  /// [slices] fournit les quatre tranches réactives ; [cardBuilder] rend la
  /// carte d'AFFICHAGE d'un item (typiquement `ZFlashcardReviewCard`) ;
  /// [passThreshold] est le seuil de réussite (propriétaire `ZSrsConfig`,
  /// AD-46) — il n'est **pas** redérivé ici.
  const ZStudySessionView({
    required this.slices,
    required this.cardBuilder,
    required this.passThreshold,
    this.headerBuilder,
    this.counterBuilder,
    this.gradingBuilder,
    this.summaryBuilder,
    this.emptyBuilder,
    this.celebrationBuilder,
    this.labels,
    this.onIndexChanged,
    this.onStackEnd,
    this.onExit,
    this.indexController,
    this.progressStyle = ZSessionProgressStyle.dots,
    this.qualityOf,
    this.stackFlex,
    this.inputFlex,
    this.contentPadding,
    this.dividerThickness,
    this.sectionGap,
    this.minTarget,
    this.counterStyle,
    super.key,
  });

  /// Clé de l'issue de sortie du repli « session vide » (testabilité).
  static const ValueKey<String> exitButtonKey =
      ValueKey<String>('zStudySessionExit');

  /// Clé du repli « session vide » (le test doit pouvoir **observer** le repli,
  /// pas seulement constater l'absence d'exception).
  static const ValueKey<String> emptyKey =
      ValueKey<String>('zStudySessionEmpty');

  /// Clé du repli « carte introuvable » (AD-10).
  static const ValueKey<String> missingCardKey =
      ValueKey<String>('zStudySessionMissingCard');

  /// Clé du repli « session indisponible pour ce mode » (AD-10/AD-34).
  static const ValueKey<String> unavailableKey =
      ValueKey<String>('zStudySessionUnavailable');

  /// Clé l10n du repli « session indisponible ».
  static const String unavailableLabelKey = 'zcrud.study.session.unavailable';

  /// Préfixe de la `key` d'identité de la pile (su-4 D1).
  static const String stackKeyPrefix = 'zStudySessionStack_';

  /// Clé l10n du message « aucune carte à étudier ».
  static const String emptyLabelKey = 'zcrud.study.session.empty';

  /// Clé l10n de l'issue de sortie.
  static const String exitLabelKey = 'zcrud.study.session.exit';

  /// Clé l10n du repli « carte introuvable ».
  static const String missingCardLabelKey = 'zcrud.study.session.missingCard';

  /// Les quatre tranches réactives (AD-2).
  final ZStudySessionSlices slices;

  /// Constructeur de la carte d'AFFICHAGE — reçoit l'item, jamais un index.
  final ZSessionCardBuilder cardBuilder;

  /// Seuil de réussite — **injecté** depuis `ZSrsConfig` (AD-46).
  final int passThreshold;

  /// Slot d'en-tête. `null` ⇒ absent de l'arbre.
  final ZStudySessionHeaderBuilder? headerBuilder;

  /// Slot de compteurs. `null` ⇒ absent de l'arbre.
  final ZStudySessionCounterBuilder? counterBuilder;

  /// Slot de saisie/notation. `null` ⇒ absent de l'arbre, **avec** son
  /// séparateur (jamais un trait orphelin sous une pile pleine hauteur).
  final ZStudySessionGradingBuilder? gradingBuilder;

  /// Slot de résumé de fin. `null` ⇒ absent de l'arbre.
  final ZStudySessionSummaryBuilder? summaryBuilder;

  /// Slot de repli « session vide ». `null` ⇒ repli du socle (AD-10).
  final WidgetBuilder? emptyBuilder;

  /// Slot de célébration, **au-dessus** du résumé. `null` ⇒ absent de l'arbre.
  final ZStudySessionCelebrationBuilder? celebrationBuilder;

  /// Libellés injectés (FR-26).
  final ZStudySessionLabels? labels;

  /// Notifié à chaque changement d'index de la pile.
  final ValueChanged<int>? onIndexChanged;

  /// Notifié à l'épuisement de la pile.
  final VoidCallback? onStackEnd;

  /// Issue de sortie du repli « session vide ».
  ///
  /// `null` ⇒ le bouton est **absent**, jamais grisé (patron AD-45,
  /// `ZSessionSummaryView.onContinue`). Un hôte qui ne le fournit pas porte
  /// lui-même l'issue (route, bouton de feuille) : la vue ne **fabrique** pas
  /// une action qu'elle ne saurait pas exécuter.
  final VoidCallback? onExit;

  /// Pilote optionnel de l'index de la pile.
  final ZIndexController? indexController;

  /// Style de l'indicateur de progression de la pile.
  final ZSessionProgressStyle progressStyle;

  /// Qualité déjà attribuée à l'index donné (colore la progression).
  final ZSessionQualityAtIndex? qualityOf;

  /// Surcharge de la part verticale de la pile (défaut : référence).
  final int? stackFlex;

  /// Surcharge de la part verticale de la zone de saisie (défaut : référence).
  final int? inputFlex;

  /// Surcharge du padding interne (défaut : référence).
  final EdgeInsetsGeometry? contentPadding;

  /// Surcharge de l'épaisseur du séparateur (défaut : référence).
  final double? dividerThickness;

  /// Surcharge de l'écart vertical entre blocs (défaut : référence).
  final double? sectionGap;

  /// Surcharge de la cible tap minimale (défaut : référence, 48 dp).
  final double? minTarget;

  /// Surcharge du style du compteur (défaut : `textTheme.labelLarge`).
  final TextStyle? counterStyle;

  @override
  Widget build(BuildContext context) {
    final ZStudySessionChrome chrome = zStudySessionChromeOf(
      context,
      stackFlex: stackFlex,
      inputFlex: inputFlex,
      contentPadding: contentPadding,
      dividerThickness: dividerThickness,
      sectionGap: sectionGap,
      minTarget: minTarget,
      counterStyle: counterStyle,
    );
    // Aiguillage de phase — SEULE la phase traverse ce builder. Noter ou taper
    // ne le fait PAS rebuilder : `slices.phase` ne notifie pas sur ces gestes.
    return ValueListenableBuilder<ZStudySessionPhase>(
      valueListenable: slices.phase,
      builder: (BuildContext context, ZStudySessionPhase phase, Widget? _) =>
          switch (phase) {
        ZStudySessionPhase.empty => _buildEmpty(
            context,
            chrome,
            labels?.emptyMessage ??
                label(context, emptyLabelKey,
                    fallback: 'Aucune carte à étudier.'),
            emptyKey,
          ),
        ZStudySessionPhase.unavailable => _buildEmpty(
            context,
            chrome,
            labels?.unavailableMessage ??
                label(context, unavailableLabelKey,
                    fallback: 'Session indisponible pour ce mode.'),
            unavailableKey,
          ),
        ZStudySessionPhase.celebrating => _buildSummary(context, chrome),
        ZStudySessionPhase.studying => _buildStudying(context, chrome),
      },
    );
  }

  // ── Phase « étude » ───────────────────────────────────────────────────────

  Widget _buildStudying(BuildContext context, ZStudySessionChrome chrome) {
    final ZStudySessionHeaderBuilder? header = headerBuilder;
    final ZStudySessionCounterBuilder? counter = counterBuilder;
    final ZStudySessionGradingBuilder? grading = gradingBuilder;
    return Column(
      children: <Widget>[
        // AD-4 — un slot nul n'est pas un nœud vide : il n'est PAS dans la
        // liste d'enfants. Le `Column` n'en calcule donc aucun flex.
        if (header != null)
          _ProgressSlice(
            progress: slices.progress,
            builder: header,
          ),
        if (counter != null)
          _ProgressSlice(
            progress: slices.progress,
            builder: counter,
          ),
        Expanded(
          flex: chrome.stackFlex,
          child: _StackSlice(
            queue: slices.queue,
            cardBuilder: cardBuilder,
            passThreshold: passThreshold,
            progressStyle: progressStyle,
            qualityOf: qualityOf,
            indexController: indexController,
            onIndexChanged: onIndexChanged,
            onStackEnd: onStackEnd,
          ),
        ),
        if (grading != null) ...<Widget>[
          Divider(
            height: chrome.dividerThickness,
            thickness: chrome.dividerThickness,
            color: chrome.dividerColor,
          ),
          Expanded(
            flex: chrome.inputFlex,
            child: _GradingSlice(
              current: slices.current,
              builder: grading,
              padding: chrome.contentPadding,
              missingLabel: labels?.missingCard,
            ),
          ),
        ],
      ],
    );
  }

  // ── Phase « résumé » ──────────────────────────────────────────────────────

  Widget _buildSummary(BuildContext context, ZStudySessionChrome chrome) {
    final ZStudySessionSummaryBuilder? summary = summaryBuilder;
    final ZStudySessionCelebrationBuilder? celebration = celebrationBuilder;
    final List<Widget> layers = <Widget>[
      if (summary != null) summary(context),
      if (celebration != null) celebration(context),
    ];
    // AD-10 — aucun cul-de-sac : sans résumé NI célébration, l'issue de sortie
    // reste rendue. (Ce n'est pas un slot par défaut : c'est le refus d'un
    // écran dont on ne peut plus sortir.)
    if (layers.isEmpty) {
      return _buildEmpty(
        context,
        chrome,
        labels?.emptyMessage ??
            label(context, emptyLabelKey, fallback: 'Aucune carte à étudier.'),
        emptyKey,
      );
    }
    if (layers.length == 1) return layers.single;
    return Stack(children: layers);
  }

  // ── Phase « vide » / repli AD-10 ──────────────────────────────────────────

  Widget _buildEmpty(
    BuildContext context,
    ZStudySessionChrome chrome,
    String message,
    ValueKey<String> key,
  ) {
    final WidgetBuilder? custom = emptyBuilder;
    if (custom != null) return custom(context);
    final VoidCallback? exit = onExit;
    return Center(
      key: key,
      child: Padding(
        padding: chrome.contentPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: chrome.secondaryTextColor),
            ),
            // Patron AD-45 : sans callback, le bouton est ABSENT — jamais grisé,
            // jamais un bouton mort.
            if (exit != null) ...<Widget>[
              SizedBox(height: chrome.sectionGap),
              _ExitButton(
                onPressed: exit,
                minTarget: chrome.minTarget,
                text: labels?.exitAction ??
                    label(context, exitLabelKey, fallback: 'Retour'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tranche « compteurs » — n'écoute que [ZStudySessionSlices.progress].
class _ProgressSlice extends StatelessWidget {
  const _ProgressSlice({required this.progress, required this.builder});

  final ValueListenable<ZStudySessionProgress> progress;
  final ZStudySessionCounterBuilder builder;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<ZStudySessionProgress>(
        valueListenable: progress,
        builder: (BuildContext context, ZStudySessionProgress value,
                Widget? _) =>
            builder(context, value),
      );
}

/// Tranche « pile » — n'écoute que [ZStudySessionSlices.queue].
///
/// C'est ici que vit la `key` d'identité de file (su-4 D1). Elle est
/// recalculée **à chaque valeur de la tranche**, jamais figée au montage.
class _StackSlice extends StatelessWidget {
  const _StackSlice({
    required this.queue,
    required this.cardBuilder,
    required this.passThreshold,
    required this.progressStyle,
    required this.qualityOf,
    required this.indexController,
    required this.onIndexChanged,
    required this.onStackEnd,
  });

  final ValueListenable<List<ZSessionItem>> queue;
  final ZSessionCardBuilder cardBuilder;
  final int passThreshold;
  final ZSessionProgressStyle progressStyle;
  final ZSessionQualityAtIndex? qualityOf;
  final ZIndexController? indexController;
  final ValueChanged<int>? onIndexChanged;
  final VoidCallback? onStackEnd;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<List<ZSessionItem>>(
        valueListenable: queue,
        builder:
            (BuildContext context, List<ZSessionItem> items, Widget? _) =>
                ZSessionCardSwiper(
          // su-4 D1 — identité de FILE, jamais une clé constante ni la seule
          // longueur : un changement réel de file remonte l'`Element`, donc
          // aucun index ne survit à la file qu'il n'indexe plus.
          key: ValueKey<String>(
            '${ZStudySessionView.stackKeyPrefix}'
            '${zSessionQueueIdentity(items)}',
          ),
          queue: items,
          cardBuilder: cardBuilder,
          passThreshold: passThreshold,
          progressStyle: progressStyle,
          qualityOf: qualityOf,
          indexController: indexController,
          onIndexChanged: onIndexChanged,
          onStackEnd: onStackEnd,
        ),
      );
}

/// Tranche « saisie / notation » — n'écoute que [ZStudySessionSlices.current].
class _GradingSlice extends StatelessWidget {
  const _GradingSlice({
    required this.current,
    required this.builder,
    required this.padding,
    required this.missingLabel,
  });

  final ValueListenable<ZSessionItem?> current;
  final ZStudySessionGradingBuilder builder;
  final EdgeInsetsGeometry padding;
  final String? missingLabel;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ZSessionItem?>(
        valueListenable: current,
        builder: (BuildContext context, ZSessionItem? item, Widget? _) {
          if (item == null) {
            // Repli AD-10 **observable** — jamais une boîte vide : si la carte
            // de devant manque (file épuisée d'une frame, désynchronisation),
            // l'écran le DIT. Un `SizedBox.shrink()` rendrait le défaut
            // indétectable au test comme à l'œil.
            return Center(
              key: ZStudySessionView.missingCardKey,
              child: Text(
                missingLabel ??
                    label(
                      context,
                      ZStudySessionView.missingCardLabelKey,
                      fallback: 'Carte introuvable',
                    ),
                textAlign: TextAlign.center,
              ),
            );
          }
          return SingleChildScrollView(
            padding: padding,
            child: builder(context, item),
          );
        },
      );
}

/// Issue de sortie accessible — cible ≥ 48 dp **en géométrie rendue**,
/// `Semantics` explicite, libellé injecté (AD-13/FR-26).
class _ExitButton extends StatelessWidget {
  const _ExitButton({
    required this.onPressed,
    required this.minTarget,
    required this.text,
  });

  final VoidCallback onPressed;
  final double minTarget;
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: text,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minTarget,
            minHeight: minTarget,
          ),
          child: FilledButton(
            key: ZStudySessionView.exitButtonKey,
            onPressed: onPressed,
            // Ceinture ET bretelles : le `ButtonStyle` de Material 3 pose une
            // taille minimale de 40 dp — sous la cible AD-13. La contrainte
            // parente la relèverait déjà, mais un hôte qui envelopperait ce
            // bouton autrement perdrait la garantie. On la porte donc AUSSI
            // dans le style, là où elle voyage avec le bouton.
            style: FilledButton.styleFrom(
              minimumSize: Size(minTarget, minTarget),
            ),
            child: ExcludeSemantics(child: Text(text)),
          ),
        ),
      );
}
