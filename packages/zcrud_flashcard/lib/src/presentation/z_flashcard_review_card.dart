/// `ZFlashcardReviewCard` — carte de révision adaptative (SU-2, AC1..AC7 —
/// FR-SU1 / FR-SU21 aperçu).
///
/// **Surface d'AFFICHAGE avec révélation** — rien de plus (frontière dure avec
/// su-3) : les 6 types canoniques sont **rendus**, les choix QCM sont **affichés
/// non interactifs**, et un **tap** bascule question↔réponse. **AUCUNE** saisie
/// notée, **AUCUN** indice, **AUCUN** minuteur, **AUCUN** port d'évaluation : ils
/// appartiennent à su-3. **AUCUN** `Dismissible`/drag horizontal : le geste de
/// swipe appartient à su-4 (`ZSessionCardSwiper`) — le consommer ici le lui
/// volerait.
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-40** : **tout** contenu textuel de carte (question, réponse,
///   `ZChoice.content`, `explanation`) passe par le slot injectable
///   [ZFlashcardReviewCard.resolvedContentBuilder] — **aucun `Text(card.question)`
///   en dur**. Le **défaut** reste le texte brut thématisé de su-1 : une app qui
///   n'injecte rien **ne construit aucun widget Quill** (l'opt-in porte sur le
///   **rendu** ; la *dépendance* `zcrud_markdown`, elle, est dans la fermeture du
///   package quoi qu'il arrive — cf. `z_flashcard_markdown_content.dart`).
/// - **Contenu = AFFICHAGE PUR** : le sous-arbre du slot est rendu **inerte aux
///   gestes** ([IgnorePointer]). Sans cela, un contenu interactif (le `QuillEditor`
///   du chemin markdown, qui autorise la sélection) **gagne l'arène des gestes**
///   contre l'`InkWell` de la carte et **la révélation par tap ne se produit
///   jamais**. La saisie est **su-3**, pas ici.
/// - **AD-2/SM-1** : l'état de révélation vit dans un `ValueNotifier<bool>`
///   **stable** lu par un `ValueListenableBuilder` ⇒ seule la **tranche de face**
///   se reconstruit. **AUCUN `setState`** à l'échelle de la carte (objectif
///   produit n°1). `AnimationController` créé UNE FOIS, **jamais** recréé au
///   rebuild. Le builder de contenu est résolu par **tear-off statique**, jamais
///   par une closure allouée dans `build()` (identité changeante ⇒ rebuilds
///   cassés) — **et il est hissé en `child:` de l'`AnimatedBuilder`** : le contenu
///   ne dépend pas de la valeur d'animation, il ne doit donc **jamais** être
///   reconstruit par frame.
/// - **AD-13** : Reduce Motion **PRIME** sur [ZRevealTransition] ; variantes
///   directionnelles (RTL) ; `Semantics` explicites ; cibles ≥ 48 dp ; le choix
///   correct est signalé par un **canal non-coloré** (icône + `Semantics`), jamais
///   par la seule couleur.
/// - **AD-10/NFR-SU6** : `answer`/`choices`/`isTrue` nuls ⇒ **repli l10n**,
///   **jamais** de `!`, jamais d'exception, jamais un écran vide.
/// - **AD-45** : `isReadOnly` (ou callback non fourni) ⇒ action **ABSENTE de
///   l'arbre**, **jamais** grisée/désactivée. « Dupliquer pour modifier » est
///   **su-8**, pas ici.
/// - **AD-1** : **aucune** dépendance ajoutée — le flip 3D est **MAISON**
///   (`flip_card` est interdite).
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
const double _kPerspective = 0.001;

/// Mi-course du flip : bascule de face (θ = π/2) — la face arrière prend le
/// relais ET reçoit sa **contre-rotation** (sinon elle s'affiche **en miroir**).
const double _kHalfTurn = 0.5;

/// Cible tap minimale Material/AD-13 (dp) — patron `z_srs_quality_buttons.dart`.
const double _kMinTarget = 48;

/// Carte de révision d'une [ZFlashcard] : rendu adapté au type + révélation.
class ZFlashcardReviewCard extends StatefulWidget {
  /// Construit la carte de révision de [card].
  ///
  /// - [revealTransition] : transition **souhaitée** (Reduce Motion prime — AC3) ;
  /// - [contentBuilder] : slot AD-40 **opt-in** (`null` ⇒ texte brut de su-1) ;
  /// - [transitionDuration] : durée de la transition (défaut 250 ms — valeur de
  ///   la source canonique `SessionFlashcardView`) ;
  /// - [onRevealChanged] : **notification sortante** de la révélation (la carte
  ///   ne cède jamais la propriété de son état — AD-2) ;
  /// - [onEdit]/[onDelete] : actions injectées — `null` ⇒ action **ABSENTE**
  ///   (AD-45), exactement comme [ZFlashcard.isReadOnly] : **une seule règle**.
  const ZFlashcardReviewCard({
    required this.card,
    this.revealTransition = ZRevealTransition.flip3d,
    this.contentBuilder,
    this.transitionDuration = const Duration(milliseconds: 250),
    this.onRevealChanged,
    this.onEdit,
    this.onDelete,
    super.key,
  });

  /// Carte rendue (immuable).
  final ZFlashcard card;

  /// Transition de révélation souhaitée (Reduce Motion la neutralise — AC3).
  final ZRevealTransition revealTransition;

  /// Slot de rendu de contenu **opt-in** (AD-40) — `null` ⇒ défaut texte brut.
  final ZFlashcardContentBuilder? contentBuilder;

  /// Durée de la transition de révélation (défaut 250 ms).
  final Duration transitionDuration;

  /// Notifié à chaque bascule de révélation (`true` = réponse affichée).
  final ValueChanged<bool>? onRevealChanged;

  /// Action d'édition — `null` ⇒ **absente** de l'arbre (jamais grisée, AD-45).
  final VoidCallback? onEdit;

  /// Action de suppression — `null` ⇒ **absente** de l'arbre (AD-45).
  final VoidCallback? onDelete;

  /// Clé de la rangée d'actions (testabilité — patron `buttonKeyPrefix`).
  static const ValueKey<String> actionsKey =
      ValueKey<String>('zFlashcardReviewCard_actions');

  /// Clé de l'action d'édition.
  static const ValueKey<String> editActionKey =
      ValueKey<String>('zFlashcardReviewCard_edit');

  /// Clé de l'action de suppression.
  static const ValueKey<String> deleteActionKey =
      ValueKey<String>('zFlashcardReviewCard_delete');

  /// Builder de contenu **RÉELLEMENT** utilisé par `build` — **tear-off statique**
  /// quand rien n'est injecté (AC1-d/AC7).
  ///
  /// 🔒 Patron exact de `z_mindmap_view.dart` : `widget.contentBuilder ??
  /// ZFlashcardDefaultContent.builder`. **JAMAIS** `?? (c, s) => …` : une closure
  /// serait **réallouée à chaque build**, changerait d'identité et casserait la
  /// stabilité des rebuilds (AD-2/SM-1). Les tear-offs de méthodes statiques sont
  /// **canonicalisés** par Dart ⇒ `identical()` entre deux builds vaut `true`.
  ///
  /// Exposé pour que cette garde soit **falsifiable** : c'est l'unique voie de
  /// résolution, celle que `build` emprunte réellement.
  @visibleForTesting
  ZFlashcardContentBuilder get resolvedContentBuilder =>
      contentBuilder ?? ZFlashcardDefaultContent.builder;

  /// Vrai si une action peut être rendue : jamais en lecture seule (AD-45).
  ///
  /// **Les deux voies convergent** (AC4) : `isReadOnly` **ou** callback non
  /// fourni ⇒ absence. Jamais deux règles concurrentes.
  bool get _actionsAllowed => !card.isReadOnly;

  @override
  State<ZFlashcardReviewCard> createState() => _ZFlashcardReviewCardState();
}

class _ZFlashcardReviewCardState extends State<ZFlashcardReviewCard>
    with SingleTickerProviderStateMixin {
  /// État logique de révélation — **stable**, créé une fois, disposé (AD-2).
  /// Lu par un `ValueListenableBuilder` : la révélation ne reconstruit QUE la
  /// tranche de face, jamais la carte entière.
  late final ValueNotifier<bool> _revealed;

  /// Face **visuellement** au premier plan (`true` = dos/réponse) — **stable**.
  ///
  /// ⚠️ **SM-1** : dérivé du controller par un listener, et **non** recalculé
  /// dans le `builder:` de l'`AnimatedBuilder`. Il ne change qu'**une fois par
  /// flip** (au passage de la mi-course) ⇒ le contenu n'est reconstruit qu'à ce
  /// moment-là, jamais à chaque frame.
  late final ValueNotifier<bool> _showBack;

  /// État **visuel** de la transition — **stable**, jamais recréé (AD-2).
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _revealed = ValueNotifier<bool>(false);
    _showBack = ValueNotifier<bool>(false);
    _controller = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    )..addListener(_syncShowBack);
  }

  /// Aligne [_showBack] sur le controller — `ValueNotifier` ne notifie que sur
  /// **changement** ⇒ au plus une reconstruction de face par flip.
  void _syncShowBack() {
    _showBack.value = _controller.value >= _kHalfTurn;
  }

  @override
  void didUpdateWidget(covariant ZFlashcardReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.transitionDuration != oldWidget.transitionDuration) {
      // Durée ajustée SUR le controller existant — jamais de recréation (AD-2).
      _controller.duration = widget.transitionDuration;
    }
    if (widget.card != oldWidget.card) {
      // Carte suivante ⇒ retour à la face QUESTION (AC7). Sans ce reset, la
      // carte suivante s'ouvrirait réponse déjà révélée — bug fonctionnel réel.
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
    _revealed.dispose();
    super.dispose();
  }

  /// **Voie UNIQUE** de changement de l'état de révélation.
  ///
  /// Les deux voies (tap et reset de carte) convergent ici : le dartdoc de
  /// [ZFlashcardReviewCard.onRevealChanged] promet une notification à **chaque**
  /// bascule — une voie muette ferait diverger l'état de l'hôte du nôtre (su-4
  /// afficherait `ZSrsQualityButtons` sur une carte non révélée ⇒ note SRS
  /// faussée).
  ///
  /// [deferNotification] : `didUpdateWidget` s'exécute **pendant le build du
  /// parent** — notifier synchroniquement y ferait planter tout hôte qui réagit
  /// par un `setState`/`markNeedsBuild` (« called during build »). La
  /// notification est alors reportée en fin de frame ; l'**état**, lui, est juste
  /// immédiatement.
  void _setRevealed(bool next, {required bool deferNotification}) {
    if (_revealed.value == next) return;
    _revealed.value = next;
    if (widget.onRevealChanged == null) return;
    if (!deferNotification) {
      widget.onRevealChanged!(next);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRevealChanged?.call(next);
    });
  }

  /// Bascule question↔réponse (geste de révélation — tap sur la carte).
  ///
  /// Reduce Motion **prime** jusque sur le controller : aucune animation n'est
  /// même lancée (dégradation de l'ANIMATION, jamais de la FONCTION — AC3).
  void _toggle() {
    final next = !_revealed.value;
    _setRevealed(next, deferNotification: false);
    if (zReduceMotionOf(context)) {
      _controller.value = next ? 1 : 0;
    } else if (next) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  /// **Unique** call-site du slot AD-40 : tout contenu de carte passe par ici.
  ///
  /// ⚠️ [IgnorePointer] : en su-2 le contenu est **purement d'affichage**. Un
  /// contenu qui capte les gestes (le `QuillEditor` du chemin markdown autorise
  /// la sélection) **gagnerait l'arène** contre l'`InkWell` de la carte et
  /// **tuerait la révélation par tap** sur le chemin d'usage documenté (AC6). Les
  /// `Semantics` du sous-arbre, elles, restent lisibles (AD-13) : c'est
  /// l'**interactivité** qui est neutralisée, pas l'accessibilité.
  Widget _content(BuildContext context, String content) => IgnorePointer(
        child: widget.resolvedContentBuilder(context, content),
      );

  /// Repli l10n d'un contenu absent (AD-10) — **jamais** un écran vide.
  ///
  /// Rendu par le défaut **thématisé** de su-1 (et non par le slot) : c'est un
  /// libellé d'interface, pas un contenu de carte — l'injecter dans le slot
  /// ferait passer un texte système pour du contenu utilisateur.
  Widget _fallback(BuildContext context) => ZFlashcardDefaultContent(
        content: label(
          context,
          'zcrud.flashcard.noAnswer',
          fallback: 'Aucune réponse',
        ),
      );

  /// **TABLE DE RENDU UNIQUE** par [ZFlashcardType] (AC1).
  ///
  /// `switch` **exhaustif SANS `default`** : une 7ᵉ valeur d'enum casse la
  /// **compilation** — jamais un repli silencieux à l'exécution. Le type n'est
  /// redécidé **nulle part** ailleurs dans ce fichier.
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
              // Face question : l'énoncé + les choix, NON interactifs (su-3).
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
  /// **DÉFILABLE** quand la hauteur est bornée.
  ///
  /// ⚠️ Patron de la source de parité (`lex_ui/…/session_flashcard_view.dart:247`
  /// — `SingleChildScrollView`). Sans lui, une face ordinaire déborde pour de
  /// vrai : un QCM à 8 choix + explication à 800×600 ⇒ `RenderFlex overflowed`,
  /// et un contenu long en produit des milliers de pixels. Le débordement n'a
  /// rien d'un artefact de harnais — c'est ce que verrait l'utilisateur.
  ///
  /// Le [LayoutBuilder] est **nécessaire** : un viewport exige une hauteur
  /// **bornée**. Dans un hôte à hauteur non bornée (une carte posée dans un
  /// `ListView`), la colonne est rendue **telle quelle** — elle y grandit
  /// librement, et un `SingleChildScrollView` y lèverait « Vertical viewport was
  /// given unbounded height ».
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

  /// Choix QCM — **non interactifs** (su-3 les rendra saisissables).
  ///
  /// [marked] : face réponse ⇒ le/les `isCorrect` sont signalés. AD-10 : liste
  /// nulle/vide ⇒ repli l10n sur la face réponse (jamais un écran vide) ; sur la
  /// face question, l'énoncé suffit.
  List<Widget> _choices(BuildContext context, {required bool marked}) {
    final choices = widget.card.choices;
    if (choices == null || choices.isEmpty) {
      return marked ? <Widget>[_fallback(context)] : const <Widget>[];
    }
    return <Widget>[
      for (final choice in choices)
        _choiceRow(context, choice, marked: marked),
    ];
  }

  /// Une ligne de choix : marqueur + contenu (par le slot AD-40).
  ///
  /// **Canal NON-COLORÉ obligatoire** (AD-13) : le choix correct porte une
  /// **icône** ET un `Semantics.label` — un daltonien et un lecteur d'écran le
  /// perçoivent sans lire la moindre couleur.
  ///
  /// ⚠️ [MergeSemantics] : le marqueur doit être annoncé **AVEC son choix**. Le
  /// `explicitChildNodes: true` du parent (indispensable pour que le marqueur ne
  /// soit pas enterré dans un blob) en fait sinon un **nœud autonome** : le
  /// lecteur d'écran lit « Paris » → « Bonne réponse » → « Lomé » et attache le
  /// marqueur au choix **FAUX**. Fusionner la **ligne** conserve l'acquis (le
  /// marqueur reste distinct des autres choix) tout en le rattachant au sien.
  ///
  /// ⚠️ **Aucune `size:` sur le marqueur** : elle était pilotée par `theme.gapL`,
  /// un token d'**espacement** (seul cas du repo). Une app réglant `gapL: 8`
  /// rétrécissait à 8 dp le `check_circle` — **seul canal visuel discriminant**
  /// ⇒ AD-13 perdu pour un daltonien. La taille vient désormais de l'`IconTheme`.
  Widget _choiceRow(BuildContext context, ZChoice choice,
      {required bool marked}) {
    final theme = ZcrudTheme.of(context);
    final isCorrect = marked && choice.isCorrect;
    // Repli aligné sur celui du contenu (`ZFlashcardDefaultContent` : `??
    // onSurface`) : deux replis divergents peignaient marqueur et texte de la
    // MÊME `Row` de couleurs différentes, et `primary` suggérait un élément
    // interactif — que su-2 interdit précisément (les choix sont affichés).
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

  /// Réponse Vrai/Faux dérivée de `isTrue` (AD-10 : `null` ⇒ repli l10n).
  ///
  /// Libellé **l10n** (jamais un littéral utilisateur en dur) rendu par le défaut
  /// thématisé : c'est une valeur d'interface dérivée, pas un contenu de carte.
  Widget _trueFalseAnswer(BuildContext context) {
    final isTrue = widget.card.isTrue;
    if (isTrue == null) return _fallback(context);
    return ZFlashcardDefaultContent(
      content: isTrue
          ? label(context, 'zcrud.flashcard.true', fallback: 'Vrai')
          : label(context, 'zcrud.flashcard.false', fallback: 'Faux'),
    );
  }

  /// Réponse libre (AD-10 : nulle/vide ⇒ repli l10n, jamais de `!`).
  Widget _freeAnswer(BuildContext context) {
    final answer = widget.card.answer;
    if (answer == null || answer.isEmpty) return _fallback(context);
    return _content(context, answer);
  }

  /// Explication — affichée sur la face réponse **seulement si non vide** (AC1 :
  /// jamais un bloc vide).
  List<Widget> _explanation(BuildContext context) {
    final explanation = widget.card.explanation;
    if (explanation == null || explanation.isEmpty) return const <Widget>[];
    return <Widget>[_content(context, explanation)];
  }

  /// Face rendue selon la transition — **Reduce Motion PRIME sur l'enum** (AC3).
  Widget _animatedFace(BuildContext context, bool revealed) {
    // AC3 : instantané. La révélation a bel et bien lieu — seule l'animation est
    // dégradée. Aucune rotation n'est construite, à aucun instant.
    if (zReduceMotionOf(context)) return _faceBody(context, revealed);

    // `switch` exhaustif SANS `default` : une 3ᵉ transition casse la compilation.
    switch (widget.revealTransition) {
      case ZRevealTransition.flip3d:
        return _flip3d(context);
      case ZRevealTransition.fade:
        return _fade(context);
    }
  }

  /// Corps de face **hissable** : il ne dépend que de [_showBack], jamais de la
  /// valeur d'animation ⇒ il vit en `child:` de l'`AnimatedBuilder` (SM-1).
  ///
  /// C'est **LE** point de la garde AC7 : le contenu se reconstruit au plus une
  /// fois par flip (au franchissement de la mi-course), pas ~15 fois (une par
  /// frame) — ce qui, sur le chemin markdown, coûtait autant de `md.Document` +
  /// `MarkdownToDelta.convert` + `jsonEncode` **jetés** par la déduplication de
  /// `ZMarkdownReader.didUpdateWidget`, qui n'arrive qu'APRÈS le travail.
  Widget _faceSlot(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: _showBack,
        builder: (BuildContext context, bool showBack, Widget? _) =>
            _faceBody(context, showBack),
      );

  /// Flip 3D **MAISON** — `Matrix4` à perspective + `rotateY` (AC2).
  ///
  /// Aucune dépendance tierce (`flip_card` interdite). La face suit le
  /// controller : elle bascule à mi-course (θ = π/2) et la face arrière reçoit
  /// une **contre-rotation** de π — sans elle, le dos s'afficherait **en miroir**
  /// (piège classique du flip maison).
  ///
  /// ⚠️ **`child:` NON NÉGOCIABLE** (SM-1, objectif produit n°1) : seule la
  /// `Matrix4` est réévaluée par frame. Rendre le contenu depuis le `builder:`
  /// le reconstruirait à chaque tick.
  Widget _flip3d(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: _faceSlot(context),
        builder: (BuildContext context, Widget? child) {
          final t = _controller.value;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, _kPerspective)
            ..rotateY(t * math.pi);
          if (t >= _kHalfTurn) {
            transform.rotateY(math.pi); // contre-rotation : jamais de miroir
          }
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: child,
          );
        },
      );

  /// Fondu court — **aucune rotation** (AC2).
  ///
  /// `Opacity` piloté par le controller (et non un `FadeTransition` nu) : la face
  /// doit **changer** à mi-course, ce qu'une opacité seule ne fait pas.
  ///
  /// ⚠️ **`child:`** : cf. [_flip3d] — seule l'opacité est réévaluée par frame.
  Widget _fade(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: _faceSlot(context),
        builder: (BuildContext context, Widget? child) {
          final t = _controller.value;
          final showBack = t >= _kHalfTurn;
          final opacity =
              ((showBack ? t - _kHalfTurn : _kHalfTurn - t) * 2).clamp(0.0, 1.0);
          return Opacity(opacity: opacity, child: child);
        },
      );

  /// Rangée d'actions — **absente** si lecture seule ou si aucun callback (AD-45).
  ///
  /// Retourne `null` (et non un widget désactivé) : l'absence est structurelle.
  Widget? _actions(BuildContext context) {
    if (!widget._actionsAllowed) return null;
    final theme = ZcrudTheme.of(context);
    final actions = <Widget>[
      if (widget.onEdit != null)
        _action(
          context,
          key: ZFlashcardReviewCard.editActionKey,
          icon: Icons.edit,
          labelKey: 'zcrud.flashcard.action.edit',
          fallback: 'Modifier',
          onTap: widget.onEdit!,
        ),
      if (widget.onDelete != null)
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

  /// Une action : cible ≥ 48 dp, `Semantics` explicite, libellé l10n, couleur
  /// thématisée (patron `z_srs_quality_buttons.dart`).
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
          minWidth: _kMinTarget,
          minHeight: _kMinTarget,
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

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final surface =
        theme.surfaceColor ?? Theme.of(context).colorScheme.surface;

    // ⚠️ SM-1 : construit UNE FOIS par build de la carte, et rendu en SIBLING du
    // `ValueListenableBuilder` — une révélation ne re-rentre PAS dans `build`,
    // donc cette instance est **préservée** telle quelle (identité stable). Un
    // `setState` de carte la reconstruirait : c'est ce que la garde SM-1 mesure.
    final actions = _actions(context);

    // Seule tranche reconstruite à la révélation (AD-2/SM-1).
    final face = ValueListenableBuilder<bool>(
      valueListenable: _revealed,
      builder: (BuildContext context, bool revealed, Widget? _) => Semantics(
        container: true,
        // ⚠️ SANS ceci, le nœud FUSIONNE tous ses descendants : le lecteur
        // d'écran annoncerait un unique bloc « Afficher la réponse · Q · Bon ·
        // Mauvais… » et le marqueur « Bonne réponse » du choix correct serait
        // ENTERRÉ dans ce blob — le canal non-coloré d'AD-13 serait perdu en
        // pratique. (Le rattachement du marqueur à SON choix est assuré par le
        // `MergeSemantics` de `_choiceRow`.)
        explicitChildNodes: true,
        button: true,
        onTap: _toggle,
        // ⚠️ Le libellé d'un contrôle TOGGLE doit décrire ce que le tap FAIT
        // MAINTENANT : face réponse, il MASQUE. Un libellé constant annoncerait
        // « Afficher la réponse » sur une réponse déjà affichée — faux dans 50 %
        // des états.
        label: revealed
            ? label(context, 'zcrud.flashcard.hide',
                fallback: 'Masquer la réponse')
            : label(context, 'zcrud.flashcard.reveal',
                fallback: 'Afficher la réponse'),
        // L'état révélé est ANNONCÉ (AC5) : la révélation n'est pas qu'un effet
        // visuel.
        value: revealed
            ? label(context, 'zcrud.flashcard.face.answer', fallback: 'Réponse')
            : label(context, 'zcrud.flashcard.face.question',
                fallback: 'Question'),
        child: _animatedFace(context, revealed),
      ),
    );

    return Material(
      color: surface,
      borderRadius: BorderRadius.all(theme.radiusM),
      child: InkWell(
        onTap: _toggle,
        // ⚠️ La révélation est DÉJÀ exposée, NOMMÉE, par le `Semantics` de la
        // face. Sans cette exclusion, l'`InkWell` ajoute un second nœud tappable
        // **ANONYME** (`label: ""`, `actions: tap`) autour de la carte :
        // TalkBack annonce un contrôle sans nom qui duplique le premier.
        excludeFromSemantics: true,
        borderRadius: BorderRadius.all(theme.radiusM),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _kMinTarget,
            minHeight: _kMinTarget,
          ),
          child: Padding(
            padding: theme.fieldPadding,
            child: LayoutBuilder(
              // La face n'est **défilable** (AD-13/parité lex_ui) que si la
              // hauteur est bornée : `Flexible` lui cède alors la place
              // restante. En hauteur non bornée (carte dans un `ListView`), un
              // `Flexible` lèverait « non-zero flex … unbounded height » ⇒ la
              // face est rendue telle quelle et grandit librement.
              builder: (BuildContext context, BoxConstraints constraints) =>
                  Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
