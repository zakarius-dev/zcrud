/// Carte de révision d'une [ZFlashcard] : rendu adapté au type, avec
/// bascule question/réponse par tap.
///
/// C'est une surface d'**affichage** avec révélation, rien de plus : les six
/// types canoniques de carte sont rendus, les choix à choix multiples sont
/// affichés **non interactifs**, et un tap bascule entre la question et la
/// réponse. Cette carte ne porte ni saisie notée, ni indice, ni minuteur, ni
/// port d'évaluation — ces responsabilités vivent dans la couche de session.
/// Elle ne consomme pas non plus le glissement horizontal : ce geste
/// appartient au composant qui empile les cartes en session
/// (`ZSessionCardSwiper`), et l'intercepter ici le lui volerait.
///
/// ## Invariants
///
/// - **Contenu par slot injectable** : tout contenu textuel de carte
///   (question, réponse, [ZChoice.content], explication) passe par
///   [ZFlashcardReviewCard.resolvedContentBuilder] — jamais un
///   `Text(card.question)` en dur. Le défaut reste un texte brut thématisé :
///   une application qui n'injecte aucun builder ne construit aucun widget
///   de rendu enrichi (l'opt-in porte sur le **rendu** ; la dépendance à
///   `zcrud_markdown`, elle, reste dans la fermeture du paquet quoi qu'il
///   arrive — voir `z_flashcard_markdown_content.dart`).
/// - **Contenu en affichage pur** : le sous-arbre du slot est rendu inerte
///   aux gestes ([IgnorePointer]). Sans cela, un contenu interactif (un
///   éditeur enrichi qui autorise la sélection) gagnerait l'arène des
///   gestes contre l'`InkWell` de la carte, et la révélation par tap ne se
///   produirait jamais. Les `Semantics` du sous-arbre, elles, restent
///   lisibles (invariant AD-13) : seule l'interactivité est neutralisée,
///   pas l'accessibilité.
/// - **Réactivité granulaire (invariant AD-2)** : l'état de révélation vit
///   dans un `ValueNotifier<bool>` stable, lu par un
///   `ValueListenableBuilder` — seule la tranche de face se reconstruit,
///   jamais la carte entière. Aucun `setState` à l'échelle de la carte.
///   `AnimationController` créé une seule fois, jamais recréé au rebuild.
///   Le builder de contenu est résolu par tear-off statique, jamais par une
///   closure allouée dans `build()` (une identité changeante casserait la
///   stabilité des rebuilds) — et il est hissé en `child:` de
///   l'`AnimatedBuilder` : le contenu ne dépend pas de la valeur
///   d'animation, il n'est donc jamais reconstruit par frame.
/// - **RTL, accessibilité (invariant AD-13)** : Reduce Motion prime sur
///   [ZRevealTransition] ; variantes directionnelles ; `Semantics`
///   explicites ; cibles ≥ 48 dp ; le choix correct est signalé par un
///   canal non coloré (icône + `Semantics`), jamais par la seule couleur.
/// - **Désérialisation défensive (invariant AD-10)** : `answer`/`choices`/
///   `isTrue` nuls entraînent un repli l10n — jamais un opérateur `!`,
///   jamais d'exception, jamais un écran vide.
/// - **Actions structurellement absentes** : `isReadOnly` (ou l'absence du
///   callback correspondant) fait disparaître l'action de l'arbre, jamais
///   grisée ni désactivée.
/// - **Aucune dépendance tierce ajoutée** : le flip 3D est implémenté en
///   interne (`Matrix4` + `rotateY`), sans bibliothèque de flip-card
///   externe.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_flashcard.dart';
import '../domain/z_reveal_transition.dart';
import 'z_flashcard_content_slot.dart';
import 'z_reduce_motion.dart';

/// Profondeur de perspective du flip 3D (`Matrix4.setEntry(3, 2, …)`).
///
/// Valeur canonique d'une perspective douce : sans elle, `rotateY` produit un
/// simple écrasement horizontal (aucune impression de volume).
const double ZFlashcardReviewCardPerspective = 0.001;

/// Mi-course du flip : bascule de face (θ = π/2) — la face arrière prend le
/// relais ET reçoit sa **contre-rotation** (sinon elle s'affiche **en miroir**).
const double ZFlashcardReviewCardHalfTurn = 0.5;

/// Cible tap minimale, en dp (invariant AD-13).
const double ZFlashcardReviewCardMinTarget = 48;

/// Construit le contenu déjà localisé du badge de type de question.
///
/// Le paquet ne traduit ni ne nomme les valeurs de [ZFlashcardType] : l'hôte
/// choisit son libellé et son éventuelle icône dans ce builder. Ce contrat
/// suit le précédent de [ZFlashcardContentBuilder] : le discriminant métier
/// est transmis à l'hôte, plutôt que converti en table de textes locale.
typedef ZFlashcardQuestionTypeBadgeBuilder =
    Widget Function(BuildContext context, ZFlashcardType type);

/// Carte de révision d'une [ZFlashcard] : rendu adapté au type + révélation.
class ZFlashcardReviewCard extends StatefulWidget {
  /// Construit la carte de révision de [card].
  ///
  /// - [revealTransition] : transition **souhaitée** (Reduce Motion prime) ;
  /// - [contentBuilder] : slot de rendu de contenu opt-in (`null` ⇒ texte
  ///   brut) ;
  /// - [questionTypeBadgeBuilder] : badge de type déjà localisé par l'hôte ;
  /// - [instructionBanner] : consigne déjà localisée par l'hôte ;
  /// - [transitionDuration] : override explicite de durée. La priorité est
  ///   l'override, puis [ZcrudTheme.flipDuration], puis 250 ms ;
  /// - [onRevealChanged] : **notification sortante** de la révélation (la
  ///   carte ne cède jamais la propriété de son état — invariant AD-2) ;
  /// - [onEdit]/[onDelete]/[onSource] : actions injectées — `null` ⇒ action
  ///   **absente**, exactement comme [ZFlashcard.isReadOnly] : une seule
  ///   règle.
  const ZFlashcardReviewCard({
    required this.card,
    this.revealTransition = ZRevealTransition.flip3d,
    this.contentBuilder,
    this.questionTypeBadgeBuilder,
    this.instructionBanner,
    this.transitionDuration,
    this.revealController,
    this.onRevealChanged,
    this.onEdit,
    this.onDelete,
    this.onSource,
    super.key,
  });

  /// Carte rendue (immuable).
  final ZFlashcard card;

  /// Transition de révélation souhaitée (Reduce Motion la neutralise).
  final ZRevealTransition revealTransition;

  /// Slot de rendu de contenu opt-in — `null` ⇒ défaut texte brut.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Slot de badge de type opt-in — `null` ⇒ absent de l'arbre.
  ///
  /// Un builder est requis ici, comme pour [contentBuilder] : le type
  /// canonique est fourni à l'hôte, seul propriétaire du libellé traduit et
  /// de sa présentation. Le paquet ne contient donc aucune table
  /// type → libellé.
  final ZFlashcardQuestionTypeBadgeBuilder? questionTypeBadgeBuilder;

  /// Bandeau de consigne opt-in, déjà traduit et composé par l'hôte.
  ///
  /// Contrairement au badge, la consigne ne dépend pas du type : un [Widget]
  /// évite un builder sans donnée utile. `null` ⇒ absence structurelle.
  final Widget? instructionBanner;

  /// Override explicite de la durée de transition.
  ///
  /// S'il est absent, [ZcrudTheme.flipDuration] est employé ; si ce token est
  /// lui aussi absent, la durée par défaut de 250 ms est conservée.
  final Duration? transitionDuration;

  /// Pilotage externe de la révélation — `null` ⇒ la carte se gouverne seule
  /// (comportement par défaut, strictement inchangé).
  ///
  /// ## Pourquoi ce paramètre existe
  ///
  /// [onRevealChanged] ne fait que **constater**. Un hôte qui possède un
  /// second chemin de déclenchement — un bouton « Voir la réponse » à côté
  /// de la carte, un bouton « Masquer la réponse » posé par le parent sur la
  /// face arrière — n'a alors aucune façon de **commander** la révélation :
  /// le bouton reste affiché, cliquable et sans effet. Une commande morte
  /// est plus coûteuse qu'une commande absente, parce qu'elle promet.
  ///
  /// ## Le contrat
  ///
  /// Fourni, le contrôleur devient **la source de vérité** : la carte ne
  /// garde aucun miroir de la révélation (voir [ZDisplayStateBinding]) ⇒
  /// les deux états ne peuvent pas diverger, parce qu'il n'y en a qu'un. Le
  /// geste de tap sur la carte écrit **dans le contrôleur**, et
  /// [onRevealChanged] reste émis dans les deux sens.
  ///
  /// Le passage à la carte suivante **écrit `false` dans le contrôleur** :
  /// c'est la contrepartie de la source unique — la carte ne peut pas
  /// revenir en face question sans le dire à son pilote.
  ///
  /// Le contrôleur doit être **possédé hors `build`** : c'est imposé par
  /// [ZDisplayStateOwnerMixin], qui refuse un enregistrement postérieur à la
  /// première frame de son `State`. Un contrôleur créé dans `build` serait
  /// remplacé à chaque rebuild — donc silencieusement inerte.
  final ZToggleController? revealController;

  /// Notifié à chaque bascule de révélation (`true` = réponse affichée).
  ///
  /// **Conservé** malgré [revealController] : un hôte qui n'a pas besoin de
  /// commander a toujours besoin de savoir (l'affichage des boutons de
  /// qualité SRS conditionne son rendu à la révélation).
  final ValueChanged<bool>? onRevealChanged;

  /// Action d'édition — `null` ⇒ **absente** de l'arbre (jamais grisée).
  final VoidCallback? onEdit;

  /// Action de suppression — `null` ⇒ **absente** de l'arbre.
  final VoidCallback? onDelete;

  /// Action « voir la source » — `null` ⇒ action **absente**, comme
  /// [onEdit]/[onDelete].
  ///
  /// Remonter de la carte vers ce dont elle est tirée (article de code,
  /// note, document, conversation…) est une traçabilité que l'hôte seul sait
  /// résoudre : `ZFlashcard.source` est un slot ouvert (`ZSourceRegistry`),
  /// et la carte ne sait donc ni ce que la source désigne ni comment y
  /// naviguer. D'où un callback, jamais une résolution interne.
  final VoidCallback? onSource;

  /// Clé de la rangée d'actions (testabilité).
  static const ValueKey<String> actionsKey = ValueKey<String>(
    'zFlashcardReviewCard_actions',
  );

  /// Clé de l'action d'édition.
  static const ValueKey<String> editActionKey = ValueKey<String>(
    'zFlashcardReviewCard_edit',
  );

  /// Clé de l'action de suppression.
  static const ValueKey<String> deleteActionKey = ValueKey<String>(
    'zFlashcardReviewCard_delete',
  );

  /// Clé de l'action « voir la source ».
  static const ValueKey<String> sourceActionKey = ValueKey<String>(
    'zFlashcardReviewCard_source',
  );

  /// Clé de la barre de dégradé optionnelle (testabilité du seam de thème).
  static const ValueKey<String> gradientAccentKey = ValueKey<String>(
    'zFlashcardReviewCard_gradientAccent',
  );

  /// Clé du chrome du badge de type (testabilité des slots).
  static const ValueKey<String> questionTypeBadgeKey = ValueKey<String>(
    'zFlashcardReviewCard_questionTypeBadge',
  );

  /// Clé du slot de bandeau de consigne (testabilité des slots).
  static const ValueKey<String> instructionBannerKey = ValueKey<String>(
    'zFlashcardReviewCard_instructionBanner',
  );

  /// Builder de contenu **réellement** utilisé par `build` — tear-off
  /// statique quand rien n'est injecté.
  ///
  /// Patron partagé avec la carte mentale : `widget.contentBuilder ??
  /// ZFlashcardDefaultContent.builder`. **Jamais** `?? (c, s) => …` : une
  /// closure serait **réallouée à chaque build**, changerait d'identité et
  /// casserait la stabilité des rebuilds (invariant AD-2). Les tear-offs de
  /// méthodes statiques sont **canonicalisés** par Dart ⇒ `identical()`
  /// entre deux builds vaut `true`.
  ///
  /// Exposé pour que cette garde soit falsifiable : c'est l'unique voie de
  /// résolution, celle que `build` emprunte réellement.
  @visibleForTesting
  ZFlashcardContentBuilder get resolvedContentBuilder =>
      contentBuilder ?? ZFlashcardDefaultContent.builder;

  /// Vrai si une action de **mutation** peut être rendue : jamais en lecture
  /// seule. Concerne [onEdit] et [onDelete].
  ///
  /// **Ne gouverne pas [onSource]**. `onSource` est une action de
  /// **consultation** : remonter au texte dont la carte est tirée ne
  /// modifie rien. La faire dépendre de `isReadOnly` la supprimerait
  /// précisément sur la population qui la motive — les cartes curées issues
  /// d'un corpus officiel, qui sont en lecture seule ET porteuses d'une
  /// source. La consultation précède la mutation.
  ///
  /// Les deux voies d'absence convergent toujours pour les mutations :
  /// `isReadOnly` **ou** callback non fourni ⇒ absence.
  bool get _actionsAllowed => !card.isReadOnly;

  @override
  State<ZFlashcardReviewCard> createState() => _ZFlashcardReviewCardState();
}

class _ZFlashcardReviewCardState extends State<ZFlashcardReviewCard>
    with SingleTickerProviderStateMixin {
  /// État logique de révélation — **stable**, créé une fois, disposé
  /// (invariant AD-2). Lu par un `ValueListenableBuilder` : la révélation ne
  /// reconstruit QUE la tranche de face, jamais la carte entière.
  ///
  /// Ce n'est pas un `ValueNotifier` privé mais une **liaison** — état
  /// interne par défaut, contrôleur de l'hôte quand il y en a un. La liaison
  /// ne **copie** rien : quand l'hôte pilote, la valeur est lue et écrite
  /// **chez lui**. `_reveal.listenable` reste **stable** au travers d'un
  /// changement de contrôleur, ce qui évite un `setState` d'échelle carte
  /// sur la bascule.
  late final ZDisplayStateBinding<bool> _reveal;

  /// Reporte la prochaine notification en fin de frame — voir [_emitReveal].
  bool _deferNextNotification = false;

  /// Face **visuellement** au premier plan (`true` = dos/réponse) — stable.
  ///
  /// Dérivé du controller par un listener, et **non** recalculé dans le
  /// `builder:` de l'`AnimatedBuilder`. Il ne change qu'une fois par flip (au
  /// passage de la mi-course) ⇒ le contenu n'est reconstruit qu'à ce
  /// moment-là, jamais à chaque frame.
  late final ValueNotifier<bool> _showBack;

  /// État **visuel** de la transition — stable, jamais recréé (invariant
  /// AD-2).
  late final AnimationController _controller;

  static const Duration _fallbackTransitionDuration = Duration(
    milliseconds: 250,
  );

  Duration _effectiveTransitionDuration(BuildContext context) =>
      widget.transitionDuration ??
      ZcrudTheme.of(context).flipDuration ??
      _fallbackTransitionDuration;

  Curve _effectiveTransitionCurve(BuildContext context) =>
      ZcrudTheme.of(context).flipCurve ?? Curves.linear;

  @override
  void initState() {
    super.initState();
    _reveal = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)
      ..bind(widget.revealController);
    // Voie unique : tout changement de révélation — tap, commande de
    // l'hôte, reset de carte — passe par ce listener. Une seconde voie
    // ferait diverger l'animation de l'état, ou tairait la notification sur
    // l'un des chemins.
    _reveal.listenable.addListener(_onRevealChanged);
    // Un contrôleur d'hôte peut arriver déjà révélé (l'hôte restaure une
    // session). L'état visuel part alors de la face arrière : sans cela, la
    // carte s'afficherait question tandis que sa source de vérité dit
    // réponse — exactement la divergence que le contrat interdit.
    final bool revealed = _reveal.value;
    _showBack = ValueNotifier<bool>(revealed);
    _controller = AnimationController(
      vsync: this,
      // `initState` ne peut pas dépendre d'un InheritedWidget. La durée de
      // thème est appliquée juste après dans `didChangeDependencies`, sur ce
      // controller unique et déjà stable.
      duration: widget.transitionDuration ?? _fallbackTransitionDuration,
      value: revealed ? 1 : 0,
    )..addListener(_syncShowBack);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final duration = _effectiveTransitionDuration(context);
    if (_controller.duration != duration) _controller.duration = duration;
  }

  /// Aligne [_showBack] sur le controller — `ValueNotifier` ne notifie que sur
  /// **changement** ⇒ au plus une reconstruction de face par flip.
  void _syncShowBack() {
    _showBack.value = _controller.value >= ZFlashcardReviewCardHalfTurn;
  }

  @override
  void didUpdateWidget(covariant ZFlashcardReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Durée ajustée SUR le controller existant — jamais de recréation
    // (invariant AD-2).
    final duration = _effectiveTransitionDuration(context);
    if (_controller.duration != duration) _controller.duration = duration;
    // L'hôte a le droit de changer (ou de retirer) son pilote — sans quoi la
    // carte resterait branchée sur l'ancien, muette pour le nouveau.
    _reveal.bind(widget.revealController);
    if (widget.card != oldWidget.card) {
      // Carte suivante ⇒ retour à la face question. Sans ce reset, la carte
      // suivante s'ouvrirait réponse déjà révélée. Quand l'hôte pilote, ce
      // reset est écrit chez lui : la source de vérité est unique, la carte
      // ne peut pas revenir en question en cachette.
      _setRevealed(false, deferNotification: true);
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_syncShowBack)
      ..dispose();
    _showBack.dispose();
    // La liaison ne dispose jamais le contrôleur de l'hôte : il ne nous
    // appartient pas (son propriétaire est un `State` de l'hôte).
    _reveal.listenable.removeListener(_onRevealChanged);
    _reveal.dispose();
    super.dispose();
  }

  /// Écrit l'état de révélation **à la source** (interne, ou contrôleur de
  /// l'hôte). Ne fait QUE écrire : l'animation et la notification sont la
  /// charge de [_onRevealChanged], qui écoute la source.
  ///
  /// Pourquoi la notification n'est pas émise ici : il existe un chemin
  /// d'écriture qui ne passe **pas** par la carte (l'hôte écrit dans son
  /// contrôleur). Émettre depuis l'écriture aurait laissé ce chemin-là
  /// muet, et la promesse « notifié à chaque bascule » aurait été tenue
  /// pour les seuls chemins internes.
  ///
  /// [deferNotification] : `didUpdateWidget` s'exécute **pendant le build du
  /// parent** — notifier synchroniquement y ferait planter tout hôte qui
  /// réagit par un `setState`/`markNeedsBuild` (« called during build »). La
  /// notification est alors reportée en fin de frame ; l'**état**, lui, est
  /// juste immédiatement.
  void _setRevealed(bool next, {required bool deferNotification}) {
    if (_reveal.value == next) return;
    _deferNextNotification = deferNotification;
    _reveal.value = next;
    _deferNextNotification = false;
  }

  /// **Voie unique** de réaction à un changement de révélation, d'où qu'il
  /// vienne : tap sur la carte, reset de carte, ou commande de l'hôte.
  ///
  /// Le dartdoc de [ZFlashcardReviewCard.onRevealChanged] promet une
  /// notification à **chaque** bascule — une voie muette ferait diverger
  /// l'état de l'hôte du nôtre (les boutons de qualité SRS s'afficheraient
  /// sur une carte non révélée ⇒ note SRS faussée).
  void _onRevealChanged() {
    final bool next = _reveal.value;
    // Reduce Motion **prime** jusque sur le controller : aucune animation
    // n'est même lancée (dégradation de l'animation, jamais de la
    // fonction).
    if (zReduceMotionOf(context)) {
      _controller.value = next ? 1 : 0;
    } else if (next) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _emitReveal(next);
  }

  /// Émet [ZFlashcardReviewCard.onRevealChanged], en reportant la notification
  /// quand elle tomberait pendant le build du parent.
  void _emitReveal(bool next) {
    if (widget.onRevealChanged == null) return;
    if (!_deferNextNotification) {
      widget.onRevealChanged!(next);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRevealChanged?.call(next);
    });
  }

  /// Bascule question↔réponse (geste de révélation — tap sur la carte).
  ///
  /// N'écrit QUE l'état : l'animation suit dans [_onRevealChanged], au même
  /// endroit que pour une commande de l'hôte. C'est ce qui garantit que le
  /// bouton externe et le tap produisent **exactement** le même effet visuel.
  void _toggle() =>
      _setRevealed(!_reveal.value, deferNotification: false);

  /// **Unique** point d'entrée du slot de contenu : tout contenu de carte
  /// passe par ici.
  ///
  /// [IgnorePointer] : le contenu est **purement d'affichage**. Un contenu
  /// qui capte les gestes (un éditeur enrichi qui autorise la sélection)
  /// gagnerait l'arène contre l'`InkWell` de la carte et tuerait la
  /// révélation par tap. Les `Semantics` du sous-arbre, elles, restent
  /// lisibles (invariant AD-13) : c'est l'interactivité qui est
  /// neutralisée, pas l'accessibilité.
  Widget _content(BuildContext context, String content) =>
      IgnorePointer(child: widget.resolvedContentBuilder(context, content));

  /// Repli l10n d'un contenu absent (invariant AD-10) — jamais un écran
  /// vide.
  ///
  /// Rendu par le défaut thématisé (et non par le slot) : c'est un libellé
  /// d'interface, pas un contenu de carte — l'injecter dans le slot ferait
  /// passer un texte système pour du contenu utilisateur.
  Widget _fallback(BuildContext context) => ZFlashcardDefaultContent(
    content: label(
      context,
      'zcrud.flashcard.noAnswer',
      fallback: 'Aucune réponse',
    ),
  );

  /// **Table de rendu unique** par [ZFlashcardType].
  ///
  /// `switch` **exhaustif sans `default`** : une septième valeur d'enum
  /// casse la **compilation** — jamais un repli silencieux à l'exécution.
  /// Le type n'est redécidé **nulle part** ailleurs dans ce fichier.
  Widget _faceBody(BuildContext context, bool revealed) {
    final card = widget.card;
    switch (card.type) {
      case ZFlashcardType.multipleChoice:
        return _column(
          context,
          revealed
              // Face réponse : les choix + le marquage du/des `isCorrect`.
              ? <Widget>[
                  ..._choices(context, marked: true),
                  ..._explanation(context),
                ]
              // Face question : l'énoncé + les choix, non interactifs.
              : <Widget>[
                  _content(context, card.question),
                  ..._choices(context, marked: false),
                ],
        );
      case ZFlashcardType.trueOrFalse:
        return _column(
          context,
          revealed
              ? <Widget>[_trueFalseAnswer(context), ..._explanation(context)]
              : <Widget>[_content(context, card.question)],
        );
      case ZFlashcardType.openQuestion:
      case ZFlashcardType.exercise:
      case ZFlashcardType.fillBlank:
      case ZFlashcardType.shortAnswer:
        return _column(
          context,
          revealed
              ? <Widget>[_freeAnswer(context), ..._explanation(context)]
              : <Widget>[_content(context, card.question)],
        );
    }
  }

  /// Colonne de face — `CrossAxisAlignment.start` (directionnel, RTL-safe) et
  /// **défilable** quand la hauteur est bornée.
  ///
  /// Sans le défilement, une face ordinaire déborde pour de vrai : un choix
  /// multiple à 8 options + explication à 800×600 lève `RenderFlex
  /// overflowed`, et un contenu long en produit des milliers de pixels. Le
  /// débordement n'a rien d'un artefact de harnais de test — c'est ce que
  /// verrait l'utilisateur.
  ///
  /// Le [LayoutBuilder] est **nécessaire** : un viewport exige une hauteur
  /// **bornée**. Dans un hôte à hauteur non bornée (une carte posée dans un
  /// `ListView`), la colonne est rendue **telle quelle** — elle y grandit
  /// librement, et un `SingleChildScrollView` y lèverait « Vertical viewport
  /// was given unbounded height ».
  Widget _column(BuildContext context, List<Widget> children) {
    final theme = ZcrudTheme.of(context);
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: theme.gapM),
          children[i],
        ],
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          constraints.hasBoundedHeight
          ? SingleChildScrollView(child: column)
          : column,
    );
  }

  /// Choix à choix multiples — **non interactifs** (une couche ultérieure
  /// les rendra saisissables).
  ///
  /// [marked] : face réponse ⇒ le/les `isCorrect` sont signalés. Invariant
  /// AD-10 : liste nulle/vide ⇒ repli l10n sur la face réponse (jamais un
  /// écran vide) ; sur la face question, l'énoncé suffit.
  List<Widget> _choices(BuildContext context, {required bool marked}) {
    final choices = widget.card.choices;
    if (choices == null || choices.isEmpty) {
      return marked ? <Widget>[_fallback(context)] : const <Widget>[];
    }
    return <Widget>[
      for (final choice in choices) _choiceRow(context, choice, marked: marked),
    ];
  }

  /// Une ligne de choix : marqueur + contenu (par le slot de rendu de
  /// contenu).
  ///
  /// **Canal non coloré obligatoire** (invariant AD-13) : le choix correct
  /// porte une **icône** ET un `Semantics.label` — un daltonien et un
  /// lecteur d'écran le perçoivent sans lire la moindre couleur.
  ///
  /// [MergeSemantics] : le marqueur doit être annoncé **avec son choix**. Le
  /// `explicitChildNodes: true` du parent (indispensable pour que le
  /// marqueur ne soit pas enterré dans un blob) en ferait sinon un **nœud
  /// autonome** : le lecteur d'écran lirait « Paris » → « Bonne réponse » →
  /// « Lomé » et attacherait le marqueur au choix **faux**. Fusionner la
  /// **ligne** conserve l'acquis (le marqueur reste distinct des autres
  /// choix) tout en le rattachant au sien.
  ///
  /// **Aucune `size:` explicite sur le marqueur** : la taille vient de
  /// l'`IconTheme` ambiant — un jeton d'espacement mal réglé par l'hôte ne
  /// doit jamais rétrécir le seul canal visuel discriminant.
  Widget _choiceRow(
    BuildContext context,
    ZChoice choice, {
    required bool marked,
  }) {
    final theme = ZcrudTheme.of(context);
    final isCorrect = marked && choice.isCorrect;
    // Repli aligné sur celui du contenu (`ZFlashcardDefaultContent` : `??
    // onSurface`) : deux replis divergents peindraient marqueur et texte de
    // la MÊME `Row` de couleurs différentes, et `primary` suggérerait un
    // élément interactif — que cette surface d'affichage interdit
    // précisément (les choix sont affichés, jamais interactifs).
    final markerColor =
        theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    final marker = Icon(
      isCorrect ? Icons.check_circle : Icons.radio_button_unchecked,
      color: markerColor,
    );
    return MergeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isCorrect)
            Semantics(
              label: label(
                context,
                'zcrud.flashcard.choice.correct',
                fallback: 'Bonne réponse',
              ),
              child: marker,
            )
          else
            ExcludeSemantics(child: marker),
          SizedBox(width: theme.gapS),
          Flexible(child: _content(context, choice.content)),
        ],
      ),
    );
  }

  /// Réponse Vrai/Faux dérivée de `isTrue` (invariant AD-10 : `null` ⇒
  /// repli l10n).
  ///
  /// Libellé **l10n** (jamais un littéral utilisateur en dur) rendu par le
  /// défaut thématisé : c'est une valeur d'interface dérivée, pas un
  /// contenu de carte.
  Widget _trueFalseAnswer(BuildContext context) {
    final isTrue = widget.card.isTrue;
    if (isTrue == null) return _fallback(context);
    return ZFlashcardDefaultContent(
      content: isTrue
          ? label(context, 'zcrud.flashcard.true', fallback: 'Vrai')
          : label(context, 'zcrud.flashcard.false', fallback: 'Faux'),
    );
  }

  /// Réponse libre (invariant AD-10 : nulle/vide ⇒ repli l10n, jamais de
  /// `!`).
  Widget _freeAnswer(BuildContext context) {
    final answer = widget.card.answer;
    if (answer == null || answer.isEmpty) return _fallback(context);
    return _content(context, answer);
  }

  /// Explication — affichée sur la face réponse **seulement si non vide**
  /// (jamais un bloc vide).
  List<Widget> _explanation(BuildContext context) {
    final explanation = widget.card.explanation;
    if (explanation == null || explanation.isEmpty) return const <Widget>[];
    return <Widget>[_content(context, explanation)];
  }

  /// Face rendue selon la transition — **Reduce Motion prime sur l'enum**.
  Widget _animatedFace(BuildContext context, bool revealed) {
    // Reduce Motion : instantané. La révélation a bel et bien lieu — seule
    // l'animation est dégradée. Aucune rotation n'est construite, à aucun
    // instant.
    if (zReduceMotionOf(context)) return _faceBody(context, revealed);

    // `switch` exhaustif sans `default` : une troisième transition casse la
    // compilation.
    switch (widget.revealTransition) {
      case ZRevealTransition.flip3d:
        return _flip3d(context);
      case ZRevealTransition.fade:
        return _fade(context);
    }
  }

  /// Corps de face **hissable** : il ne dépend que de [_showBack], jamais de
  /// la valeur d'animation ⇒ il vit en `child:` de l'`AnimatedBuilder`
  /// (réactivité granulaire, invariant AD-2).
  ///
  /// C'est le point clé qui garantit que le contenu se reconstruit au plus
  /// une fois par flip (au franchissement de la mi-course), et non à chaque
  /// frame — ce qui, sur le chemin de rendu enrichi, éviterait de refaire
  /// à chaque frame le travail de conversion et d'encodage que le contenu
  /// ne demande qu'une fois par bascule.
  Widget _faceSlot(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: _showBack,
    builder: (BuildContext context, bool showBack, Widget? _) =>
        _faceBody(context, showBack),
  );

  /// Flip 3D **interne** — `Matrix4` à perspective + `rotateY`.
  ///
  /// Aucune dépendance tierce de flip-card. La face suit le controller :
  /// elle bascule à mi-course (θ = π/2) et la face arrière reçoit une
  /// **contre-rotation** de π — sans elle, le dos s'afficherait **en
  /// miroir** (piège classique du flip fait maison).
  ///
  /// `child:` **non négociable** (réactivité granulaire) : seule la
  /// `Matrix4` est réévaluée par frame. Rendre le contenu depuis le
  /// `builder:` le reconstruirait à chaque tick.
  Widget _flip3d(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: _faceSlot(context),
    builder: (BuildContext context, Widget? child) {
      final t = _effectiveTransitionCurve(context).transform(_controller.value);
      final transform = Matrix4.identity()
        ..setEntry(3, 2, ZFlashcardReviewCardPerspective)
        ..rotateY(t * math.pi);
      if (_controller.value >= ZFlashcardReviewCardHalfTurn) {
        transform.rotateY(math.pi); // contre-rotation : jamais de miroir
      }
      return Transform(
        transform: transform,
        alignment: Alignment.center,
        child: child,
      );
    },
  );

  /// Fondu court — **aucune rotation**.
  ///
  /// `Opacity` piloté par le controller (et non un `FadeTransition` nu) : la
  /// face doit **changer** à mi-course, ce qu'une opacité seule ne fait pas.
  ///
  /// `child:` : voir [_flip3d] — seule l'opacité est réévaluée par frame.
  Widget _fade(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: _faceSlot(context),
    builder: (BuildContext context, Widget? child) {
      final t = _effectiveTransitionCurve(context).transform(_controller.value);
      final showBack = _controller.value >= ZFlashcardReviewCardHalfTurn;
      final opacity =
          ((showBack
                      ? t - ZFlashcardReviewCardHalfTurn
                      : ZFlashcardReviewCardHalfTurn - t) *
                  2)
              .clamp(0.0, 1.0);
      return Opacity(opacity: opacity, child: child);
    },
  );

  /// Rangée d'actions — **absente** si lecture seule ou si aucun callback.
  ///
  /// Retourne `null` (et non un widget désactivé) : l'absence est
  /// structurelle.
  Widget? _actions(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // La consultation (voir la source) survit à la lecture seule ; seules
    // les mutations y sont soumises. La garde s'applique donc par action,
    // pas globalement à la rangée.
    final mutationsAllowed = widget._actionsAllowed;
    final actions = <Widget>[
      // Consultation avant mutation : la source précède édition/suppression.
      if (widget.onSource != null)
        _action(
          context,
          key: ZFlashcardReviewCard.sourceActionKey,
          icon: Icons.link,
          labelKey: 'zcrud.flashcard.action.source',
          fallback: 'Voir la source',
          onTap: widget.onSource!,
        ),
      if (mutationsAllowed && widget.onEdit != null)
        _action(
          context,
          key: ZFlashcardReviewCard.editActionKey,
          icon: Icons.edit,
          labelKey: 'zcrud.flashcard.action.edit',
          fallback: 'Modifier',
          onTap: widget.onEdit!,
        ),
      if (mutationsAllowed && widget.onDelete != null)
        _action(
          context,
          key: ZFlashcardReviewCard.deleteActionKey,
          icon: Icons.delete,
          labelKey: 'zcrud.flashcard.action.delete',
          fallback: 'Supprimer',
          onTap: widget.onDelete!,
        ),
    ];
    if (actions.isEmpty) return null;
    return Padding(
      key: ZFlashcardReviewCard.actionsKey,
      padding: EdgeInsetsDirectional.only(top: theme.gapM),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (var i = 0; i < actions.length; i++) ...<Widget>[
            if (i > 0) SizedBox(width: theme.gapS),
            actions[i],
          ],
        ],
      ),
    );
  }

  /// Une action : cible ≥ 48 dp, `Semantics` explicite, libellé l10n,
  /// couleur thématisée.
  Widget _action(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String labelKey,
    required String fallback,
    required VoidCallback onTap,
  }) {
    final theme = ZcrudTheme.of(context);
    final color = theme.labelColor ?? Theme.of(context).colorScheme.onSurface;
    return Semantics(
      key: key,
      button: true,
      label: label(context, labelKey, fallback: fallback),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: ZFlashcardReviewCardMinTarget,
          minHeight: ZFlashcardReviewCardMinTarget,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Center(child: Icon(icon, color: color)),
          ),
        ),
      ),
    );
  }

  /// Barre décorative opt-in, résolue uniquement par le seam de thème de
  /// l'hôte.
  ///
  /// L'identité est le nom stable du type, jamais une position de liste. Les
  /// entrées requises (spécification + jetons de thème) restent nullables :
  /// l'absence de l'une d'elles garde l'arbre historique strictement
  /// inchangé.
  Gradient? _resolvedGradient(ZGradientSpec spec, ZcrudTheme theme) {
    final begin = theme.gradientBegin;
    final end = theme.gradientEnd;
    if (begin == null || end == null) return null;
    return switch (spec.gradient) {
      final LinearGradient linear => LinearGradient(
        begin: begin,
        end: end,
        colors: linear.colors,
        stops: linear.stops,
        tileMode: linear.tileMode,
        transform: linear.transform,
      ),
      _ => spec.gradient,
    };
  }

  /// Badge de type informatif, absent sans builder.
  ///
  /// Le chrome réutilise les jetons de pastille de comptage et la
  /// résolution de gradient de la carte. [Semantics] laisse le libellé déjà
  /// localisé de l'hôte annonçable : c'est une information, jamais une
  /// décoration.
  Widget? _questionTypeBadge(
    BuildContext context,
    ZGradientSpec? gradientSpec,
  ) {
    final builder = widget.questionTypeBadgeBuilder;
    if (builder == null) return null;
    final theme = ZcrudTheme.of(context);
    final gradient = gradientSpec == null
        ? null
        : _resolvedGradient(gradientSpec, theme);
    final iconSize =
        theme.countPillIconSize ?? IconTheme.of(context).size ?? 24.0;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: IgnorePointer(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            key: ZFlashcardReviewCard.questionTypeBadgeKey,
            padding:
                theme.countPillPadding ??
                EdgeInsetsDirectional.symmetric(
                  horizontal: theme.gapS,
                  vertical: theme.gapS / 2,
                ),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.all(
                theme.countPillRadius ?? theme.radiusM,
              ),
            ),
            child: IconTheme.merge(
              data: IconThemeData(size: iconSize),
              child: builder(context, widget.card.type),
            ),
          ),
        ),
      ),
    );
  }

  /// Bandeau de consigne informatif, absent sans injection.
  Widget? _instructionBanner() {
    final banner = widget.instructionBanner;
    if (banner == null) return null;
    return IgnorePointer(
      child: KeyedSubtree(
        key: ZFlashcardReviewCard.instructionBannerKey,
        child: banner,
      ),
    );
  }

  Widget? _gradientAccent(BuildContext context, ZGradientSpec? spec) {
    final theme = ZcrudTheme.of(context);
    final height = theme.accentBarHeight;
    if (spec == null || height == null) return null;
    final gradient = _resolvedGradient(spec, theme);
    if (gradient == null) return null;
    return Container(
      key: ZFlashcardReviewCard.gradientAccentKey,
      height: height,
      decoration: BoxDecoration(gradient: gradient),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final surface = theme.surfaceColor ?? Theme.of(context).colorScheme.surface;

    // Construit UNE FOIS par build de la carte, et rendu en sibling du
    // `ValueListenableBuilder` — une révélation ne re-rentre pas dans
    // `build`, donc cette instance est **préservée** telle quelle (identité
    // stable). Un `setState` de carte la reconstruirait — c'est précisément
    // ce que la réactivité granulaire interdit.
    final actions = _actions(context);
    // Résolution UNIQUE : la barre et le badge lisent exactement le même
    // gradient hôte, indexé par l'identité stable du type.
    final gradientSpec = zResolveGradient(context, widget.card.type.name);
    final gradientAccent = _gradientAccent(context, gradientSpec);
    final questionTypeBadge = _questionTypeBadge(context, gradientSpec);
    final instructionBanner = _instructionBanner();

    // Seule tranche reconstruite à la révélation (invariant AD-2).
    final face = ValueListenableBuilder<bool>(
      valueListenable: _reveal.listenable,
      builder: (BuildContext context, bool revealed, Widget? _) => Semantics(
        container: true,
        // Sans ceci, le nœud FUSIONNE tous ses descendants : le lecteur
        // d'écran annoncerait un unique bloc « Afficher la réponse · Q ·
        // Bon · Mauvais… » et le marqueur « Bonne réponse » du choix
        // correct serait enterré dans ce blob — le canal non coloré serait
        // perdu en pratique. (Le rattachement du marqueur à SON choix est
        // assuré par le `MergeSemantics` de `_choiceRow`.)
        explicitChildNodes: true,
        button: true,
        onTap: _toggle,
        // Le libellé d'un contrôle bascule doit décrire ce que le tap FAIT
        // maintenant : face réponse, il masque. Un libellé constant
        // annoncerait « Afficher la réponse » sur une réponse déjà
        // affichée — faux dans la moitié des états.
        label: revealed
            ? label(
                context,
                'zcrud.flashcard.hide',
                fallback: 'Masquer la réponse',
              )
            : label(
                context,
                'zcrud.flashcard.reveal',
                fallback: 'Afficher la réponse',
              ),
        // L'état révélé est ANNONCÉ : la révélation n'est pas qu'un effet
        // visuel.
        value: revealed
            ? label(context, 'zcrud.flashcard.face.answer', fallback: 'Réponse')
            : label(
                context,
                'zcrud.flashcard.face.question',
                fallback: 'Question',
              ),
        child: _animatedFace(context, revealed),
      ),
    );

    return Material(
      color: surface,
      borderRadius: BorderRadius.all(theme.radiusM),
      child: InkWell(
        onTap: _toggle,
        // La révélation est déjà exposée, nommée, par le `Semantics` de la
        // face. Sans cette exclusion, l'`InkWell` ajouterait un second nœud
        // tappable **anonyme** (`label: ""`, `actions: tap`) autour de la
        // carte : un lecteur d'écran annoncerait un contrôle sans nom qui
        // duplique le premier.
        excludeFromSemantics: true,
        borderRadius: BorderRadius.all(theme.radiusM),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: ZFlashcardReviewCardMinTarget,
            minHeight: ZFlashcardReviewCardMinTarget,
          ),
          child: Padding(
            padding: theme.fieldPadding,
            child: LayoutBuilder(
              // La face n'est **défilable** (invariant AD-13) que si la
              // hauteur est bornée : `Flexible` lui cède alors la place
              // restante. En hauteur non bornée (carte dans un `ListView`),
              // un `Flexible` lèverait « non-zero flex … unbounded height »
              // ⇒ la face est rendue telle quelle et grandit librement.
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (gradientAccent != null) gradientAccent,
                      if (questionTypeBadge != null) ...<Widget>[
                        if (gradientAccent != null)
                          SizedBox(height: theme.gapM),
                        questionTypeBadge,
                      ],
                      if (instructionBanner != null) ...<Widget>[
                        if (gradientAccent != null || questionTypeBadge != null)
                          SizedBox(height: theme.gapM),
                        instructionBanner,
                      ],
                      if (gradientAccent != null ||
                          questionTypeBadge != null ||
                          instructionBanner != null)
                        SizedBox(height: theme.gapM),
                      if (constraints.hasBoundedHeight)
                        Flexible(child: face)
                      else
                        face,
                      if (actions != null) actions,
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
