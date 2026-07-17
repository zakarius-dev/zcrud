/// `ZSessionCardSwiper` — pile de session **swipeable** (SU-4, AC1 — FR-SU6).
///
/// 🎯 **Le swipe est une NAVIGATION. Il ne note JAMAIS.**
///
/// 🚫 Ce type n'a **AUCUN** paramètre de qualité, de notation ou de reviewer :
/// la notation y est **structurellement impossible** (AD-33/AD-34 — le régime
/// d'écriture est une propriété du TYPE). Elle appartient aux
/// `ZSrsQualityButtons`, que l'hôte compose en **FRÈRE**, *hors* de la pile. La
/// tentation « gauche = raté / droite = réussi » (le geste Tinder-like) est
/// précisément ce que FR-SU6 interdit : ici, **les deux directions horizontales
/// font avancer** (arbitrage A2) — ce qui **dissout** au passage la question RTL,
/// `CardSwiperDirection.left/right` étant *physiques*.
///
/// ## Pourquoi AUCUN retour arrière — ni au geste, ni au bouton
///
/// **La pile n'avance que.** Ce n'est pas un manque, c'est le modèle :
///
/// - **A2** — les deux directions de swipe **avancent**. Fait vérifié sur
///   disque : `_swipe(dir)` mène à `_undoableIndex.state = _nextIndex`, soit
///   **`+1` quelle que soit la direction** (`card_swiper_state.dart:295-300`).
///   `CardSwiperController.swipe(left)` n'est **pas** « aller à la carte
///   précédente » : c'est « chasser la carte courante vers la gauche », donc
///   **avancer**.
/// - **Aucun runtime ne recule** (AD-34) : dans les **trois** moteurs, `cursor`
///   ne fait que croître (`cursor + 1`) ou se recaler après un retrait — aucun
///   n'expose de retour arrière. Un bouton qui reculerait l'index **du widget**
///   laisserait le `cursor` **du moteur** sur place : c'est-à-dire qu'il
///   **fabriquerait** la désynchronisation à deux sources de vérité que
///   [_queueGeneration] existe précisément pour fermer.
/// - **AC9 n'en demande pas** : « l'apprenant veut **avancer** dans la pile ».
///
/// 🚫 Un bouton `previousButtonKey` étiqueté « carte précédente » a existé ici
/// et **a été RETIRÉ** : câblé sur `swipe(left)`, il **avançait** (mesuré :
/// index 0→1→**2**). Il ne mentait pas à n'importe qui — il mentait à
/// **l'utilisateur de lecteur d'écran**, le seul public que cette rangée
/// existe pour servir, et de façon **irrattrapable** (chaque tentative de
/// correction avançait encore). La seule voie de retour du paquet, `undo()`,
/// n'était câblée nulle part. **Un contrôle absent vaut mieux qu'un contrôle
/// qui annonce l'inverse de ce qu'il fait** : l'utilisateur de lecteur d'écran
/// dispose désormais **exactement** des mêmes déplacements que l'utilisateur du
/// geste — la **parité** qu'exige AD-13.
///
/// ## L'ARÈNE DES GESTES, acte III — dissolution par la GÉOMÉTRIE
///
/// `flutter_card_swiper` pose sur la carte de devant un `GestureDetector` avec
/// `onPanStart/Update/End` — un **`PanGestureRecognizer`, qui revendique LES DEUX
/// AXES** (lu sur disque : `lib/src/widget/card_swiper_state.dart:109-174`) — **et** un `onTap`
/// **toujours** enregistré. Il entre donc en arène contre tout ce qui vit
/// **sous** lui. La réponse de su-4 n'est pas de dompter des recognizers, mais
/// de faire en sorte que les gestes concurrents **ne se rencontrent jamais** :
///
/// ```text
/// ZSessionCardSwiper           ← le pan ne couvre QUE ceci
/// └── CardSwiper(cardBuilder:)
///     └── Stack
///         ├── carte d'AFFICHAGE (su-2)   ← instance MÉMOÏSÉE (AC7)
///         └── ZSwipeEmotionIndicator     ← IgnorePointer, ne vole rien
/// ─────────────────── frontière du swiper ───────────────────
/// ZFlashcardAnswerInput   ← FRÈRE (su-3) — JAMAIS sous le pan
/// ZSrsQualityButtons      ← FRÈRE (su-3) — la notation
/// ```
///
/// 🚫 **Règle non négociable** : `ZFlashcardAnswerInput` / `ZSrsQualityButtons`
/// ne descendent **JAMAIS** dans le [cardBuilder]. Un `TextField` sous un pan
/// ancêtre, c'est le placement du curseur et la sélection qui se battent contre
/// la navigation — aucun réglage de seuil ne rend cela fiable. Le conflit *drag
/// ∥ saisie* est **dissous par construction**, pas arbitré.
///
/// ## Réglages du `CardSwiper` — chacun adossé à un fait vérifié sur disque
///
/// | Réglage | Valeur | Pourquoi (AD-10) |
/// |---|---|---|
/// | `cardsCount` | `queue.length`, **jamais 0** | `cardsCount = 0` ⇒ **2 asserts du ctor lèvent** ⇒ repli AVANT construction |
/// | `numberOfCardsDisplayed` | `min(2, queue.length)` | défaut **2** ⇒ `assert(… <= cardsCount)` ⇒ **crash sur une file d'UNE carte** |
/// | `isLoop` | **`false`** | défaut **`true`** ⇒ la session **ne se termine jamais** |
/// | `duration` | `Duration.zero` sous Reduce Motion | animation **réelle** de 200 ms (NFR-SU3) |
/// | `allowedSwipeDirection` | `symmetric(horizontal: true)` | **porteur PENDANT le drag ET à la fin** — cf. ci-dessous |
/// | `onSwipe` | navigation seule → [onIndexChanged] | `FutureOr<bool>` **`await`é** par le paquet ⇒ handler gardé **SYNCHRONE** (AC12) |
///
/// ⚠️ **`allowedSwipeDirection` fait DEUX choses** (mesuré, contre une version
/// antérieure de cette dartdoc qui n'en voyait qu'une) :
/// 1. **à la fin du geste** — `_isValidDirection` (lu dans `_onEndAnimation`)
///    rejette `top`/`bottom` ⇒ `_goBack()`, `onSwipe` jamais appelé ;
/// 2. **PENDANT le drag** — `CardAnimation.update` (`card_animation.dart:79-96`)
///    n'applique `dy` **que si** `up`/`down` est autorisé. Avec
///    `symmetric(horizontal: true)`, `up == down == false` ⇒ **aucune branche**
///    ⇒ `top` n'est **jamais** modifié : un pan vertical gagnant **ne translate
///    rien** (mesuré : `topLeft` (8,8) → (8,8), delta 0).
///
/// 🚫 Ne pas en conclure que ce réglage est « cosmétique pendant le drag » et le
/// remplacer par `AllowedSwipeDirection.all()` : cela **rendrait réelle** une
/// translation verticale qui n'existe pas aujourd'hui, et sur une carte courte
/// (où le `Scrollable` décline le geste, faute de quoi défiler) la carte se
/// mettrait à suivre le doigt verticalement et à s'envoler. Le `PanGestureRecognizer`
/// revendique bien les deux axes dans l'arène — c'est `CardAnimation.update` qui
/// est le garde-fou, pas `_isValidDirection` seul.
///
/// **Widget PUR** (AD-2/AD-15) : aucun gestionnaire d'état, aucun moteur, aucun
/// `ZSrsScheduler`. Le `CardSwiperController` est **possédé** (créé en
/// `initState`, libéré en `dispose` — jamais dans `build`).
///
/// 🔒 **Confinement (AC10/NFR-SU7)** : c'est le **SEUL** fichier du monorepo qui
/// importe `flutter_card_swiper`, et **aucun** type du paquet n'apparaît dans une
/// signature publique — le barrel ne le réexporte pas.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show zReduceMotionOf;

import '../domain/z_session_item.dart';
import 'z_session_progress_indicator.dart';

/// Construit la carte d'**AFFICHAGE** d'un item (typiquement
/// `ZFlashcardReviewCard`, su-2). **Jamais** une surface de saisie ou de
/// notation : celles-ci vivent en frères, hors de la pile.
typedef ZSessionCardBuilder = Widget Function(
  BuildContext context,
  ZSessionItem item,
);

/// Pile de session swipeable — **navigation seule**.
class ZSessionCardSwiper extends StatefulWidget {
  /// Construit la pile.
  ///
  /// - [queue] : file **DÉJÀ sélectionnée** (AD-33 : ce widget ne sélectionne
  ///   jamais — il ne connaît ni filtre, ni échéance, ni mode) ;
  /// - [cardBuilder] : carte d'**AFFICHAGE** d'un item ;
  /// - [onIndexChanged] : **navigation seule** — émis à chaque avancée, quelle
  ///   qu'en soit l'origine (geste **ou** bouton d'accessibilité : une seule
  ///   voie d'émission, arbitrage A6) ;
  /// - [onStackEnd] : fin de pile. su-4 **émet** l'événement et rend **aucune**
  ///   UI de fin — l'écran de fin est su-5 (arbitrage A7) ;
  /// - [emptyBuilder] : repli **file vide** (AD-10/AC11) ;
  /// - [progressStyle] : variante d'indicateur (**enum**) ;
  /// - [qualityOf] : seam « qualité obtenue à l'index i » (indicateur) ;
  /// - [passThreshold] : frontière réussite/lapse **INJECTÉE** (jamais `3`) ;
  /// - [swipeDuration] : durée d'animation, **ramenée à zéro** sous Reduce Motion.
  ///
  /// 🚫 **Aucun paramètre de notation** — c'est un invariant du type, pas un
  /// oubli (AC1). En ajouter un rougit `z_swipe_never_grades_test.dart`.
  const ZSessionCardSwiper({
    required this.queue,
    required this.cardBuilder,
    required this.passThreshold,
    this.onIndexChanged,
    this.onStackEnd,
    this.emptyBuilder,
    this.progressStyle = ZSessionProgressStyle.dots,
    this.qualityOf,
    this.swipeDuration = const Duration(milliseconds: 200),
    super.key,
  });

  /// File **déjà sélectionnée** (AD-33).
  final List<ZSessionItem> queue;

  /// Constructeur de la carte d'affichage.
  final ZSessionCardBuilder cardBuilder;

  /// Frontière réussite/lapse INJECTÉE, relayée à l'indicateur (AD-46).
  final int passThreshold;

  /// Notification d'avancée — **navigation seule**, jamais une note.
  final ValueChanged<int>? onIndexChanged;

  /// Notification de fin de pile (aucune UI — su-5).
  final VoidCallback? onStackEnd;

  /// Repli **file vide** (AD-10). `null` ⇒ repli par défaut localisé.
  final WidgetBuilder? emptyBuilder;

  /// Variante d'indicateur de progression (**enum**).
  final ZSessionProgressStyle progressStyle;

  /// Seam « qualité obtenue à l'index i » (`null` ⇒ aucune carte notée).
  final ZSessionQualityAtIndex? qualityOf;

  /// Durée d'animation de swipe (`Duration.zero` sous Reduce Motion).
  final Duration swipeDuration;

  /// Clé du bouton de navigation **suivant** (alternative accessible, AC9).
  ///
  /// 🚫 **Il n'existe DÉLIBÉRÉMENT aucun bouton « précédent »** — cf. la
  /// dartdoc de librairie, § « Pourquoi aucun retour arrière ».
  static const ValueKey<String> nextButtonKey =
      ValueKey<String>('zSwiperNext');

  /// Clé du repli **file vide** par défaut (AC11 — le test doit pouvoir
  /// **observer** le repli, pas seulement constater l'absence d'exception).
  static const ValueKey<String> emptyKey = ValueKey<String>('zSwiperEmpty');

  /// Clé l10n du repli file vide.
  static const String emptyLabelKey = 'zcrud.session.empty';

  /// Clé l10n du bouton « carte suivante ».
  static const String nextLabelKey = 'zcrud.session.next';

  /// Cible tap minimale Material/AD-13 (dp).
  ///
  /// ⚠️ **Non négociable ici** : `grep -rn "Semantics" flutter_card_swiper-7.2.0/lib/`
  /// → **RC=1**. Le paquet n'expose **AUCUNE** sémantique ⇒ la pile est
  /// **inutilisable** au lecteur d'écran. Cette alternative n'est pas une
  /// précaution : elle comble un **trou mesuré**.
  static const double minTarget = 48;

  @override
  State<ZSessionCardSwiper> createState() => _ZSessionCardSwiperState();
}

class _ZSessionCardSwiperState extends State<ZSessionCardSwiper> {
  /// Contrôleur **POSSÉDÉ** — créé ici, libéré ici. Jamais dans `build`
  /// (`dispose()` est `Future<void>` et le recréer par frame fuirait).
  late final CardSwiperController _controller = CardSwiperController();

  /// Index de la carte courante (source de vérité de l'indicateur).
  int _index = 0;

  /// 🔒 **Verrou ONE-SHOT de [ZSessionCardSwiper.onIndexChanged]** : le dernier
  /// index réellement émis — dédoublonne toute ré-émission d'un même index.
  ///
  /// ⚠️ **Portée honnête, MESURÉE** : avec le paquet en 7.2.0 et un
  /// [_handleSwipe] **synchrone**, ce verrou n'est **jamais atteint** (mesuré :
  /// un triple tap sans laisser retomber l'animation n'émet qu'un seul index —
  /// le paquet avance `_undoableIndex` une fois par swipe **complété**). Il est
  /// conservé comme **défense en profondeur** d'AC12, pas comme la cause du
  /// comportement : ce dernier tient à la **synchronicité** de [_handleSwipe]
  /// (cf. sa dartdoc) et au gating d'animation du paquet.
  int? _lastEmittedIndex;

  /// 🔒 **Verrou ONE-SHOT de fin de pile** (même portée honnête que
  /// [_lastEmittedIndex] : non atteint avec `isLoop: false`, où l'index devient
  /// `null` après la dernière carte et interdit tout swipe ultérieur).
  bool _stackEnded = false;

  /// Cache d'instances de carte **par index** (AC7/NFR-SU2).
  ///
  /// ⚠️ **Pourquoi un cache et non un `const`** : `onPanUpdate` appelle
  /// `setState` ⇒ le [ZSessionCardSwiper.cardBuilder] **EST** ré-invoqué à
  /// **chaque frame** de drag (fait vérifié sur disque, non contournable depuis
  /// l'extérieur du paquet). La granularité s'obtient donc en rendant
  /// l'invocation **inoffensive** : on renvoie l'instance **identique**
  /// (`identical(w1, w2) == true`) ⇒ `Element.updateChild` court-circuite tout
  /// le sous-arbre de la carte. Patron hérité de su-2 (contenu hissé en `child:`).
  final Map<int, Widget> _cardCache = <int, Widget>{};

  /// 🔑 **Génération de file** — incrémentée à chaque changement RÉEL de
  /// [ZSessionCardSwiper.queue], et **seulement** là. Sert de `key` au
  /// `CardSwiper` (cf. [build]).
  ///
  /// ⚠️ **Ce n'est PAS un jeton décoratif** (à ne pas confondre avec le jeton
  /// `_generation` de concurrence, retiré à raison — cf. [_handleSwipe]) : il
  /// ferme un **crash mesuré**. Le `CardSwiper` porte sa **propre** source de
  /// vérité d'index (`_undoableIndex`), posée **uniquement en `initState`**
  /// (`card_swiper_state.dart:32`) et que **son** `didUpdateWidget` ne
  /// réinitialise **jamais** (`:54-60` — il ne fait que ré-abonner le
  /// contrôleur). Sans `key`, l'`Element` est réutilisé au changement de file :
  /// l'index du paquet **survit** à une file qu'il n'indexe plus.
  ///
  /// Trois défauts en découlaient, **tous mesurés**, tous de cette racine :
  /// 1. **CRASH** (`RangeError`) — file qui **rétrécit** : `numberOfCardsOnScreen()`
  ///    rend `min(displayed, cardsCount - index)` (`:338-350`), **négatif** dès
  ///    que `index > cardsCount` ⇒ `List.generate(-1, …)` **lève en plein
  ///    `build`** (écran rouge). Or `ZStudySessionEngine.reduceGrade` fait
  ///    `queue.removeAt(cursor)` **sans réinsérer sur une réussite**
  ///    (`z_study_session_engine.dart:79`) : **toute réussite rétrécit la file**.
  ///    C'était le chemin **NOMINAL**, pas un cas limite.
  /// 2. **Indicateur MENTEUR** — file remplacée à longueur égale : `_index`
  ///    repartait à `0` (« 1/3 ») pendant que le paquet restait sur la 3ᵉ carte.
  /// 3. **Cul-de-sac** — `index == cardsCount` : `min(2, 0) = 0` ⇒ écran **vide**
  ///    sans repli (la file n'est pas vide ⇒ `emptyBuilder` hors d'atteinte) et
  ///    **`onStackEnd` jamais émis** ⇒ session sans fin ni recours (AD-10).
  ///
  /// En remontant le `CardSwiper`, `initState` est rejoué ⇒ `_undoableIndex`
  /// revient à `initialIndex` (0) — **aligné** sur le `_index = 0` que ce State
  /// s'impose déjà. Les trois défauts se ferment d'un seul geste.
  int _queueGeneration = 0;

  @override
  void didUpdateWidget(ZSessionCardSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Invalidation UNIQUEMENT sur changement réel de la file : sinon le cache
    // rendrait une carte périmée (et un `identical` mensonger).
    if (!listEquals(oldWidget.queue, widget.queue)) {
      _cardCache.clear();
      _lastEmittedIndex = null;
      _stackEnded = false;
      _index = 0;
      // 🔑 Remonte le `CardSwiper` : sans cela son index interne survivrait à la
      // file (crash / indicateur menteur / cul-de-sac — cf. [_queueGeneration]).
      _queueGeneration++;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Émission **UNIQUE** de l'avancée (arbitrage A6 : geste et bouton
  /// d'accessibilité passent par **la même** voie — deux voies donneraient deux
  /// comptages divergents).
  void _emitIndexChanged(int index) {
    if (_lastEmittedIndex == index) return; // 🔒 one-shot
    _lastEmittedIndex = index;
    if (mounted) setState(() => _index = index);
    widget.onIndexChanged?.call(index);
  }

  /// `onSwipe` du paquet — **navigation SEULE**, et **SYNCHRONE** (AC12).
  ///
  /// 🚫 Aucune qualité n'est dérivée de [direction] : le paramètre est ignoré,
  /// et c'est **délibéré** (FR-SU6/AC2). Le mapper serait le geste Tinder-like
  /// que la story interdit.
  ///
  /// 🔒 **SYNCHRONE — c'est ICI que la fenêtre de concurrence est DISSOUTE, pas
  /// gardée** (AC12). `CardSwiperOnSwipe` est un `FutureOr<bool>` que le paquet
  /// **`await`e** (`_handleCompleteSwipe` :
  /// `await widget.onSwipe?.call(...) == false`). Un handler **asynchrone**
  /// ouvrirait donc une fenêtre réelle pendant laquelle la file peut changer —
  /// la racine exacte du D1 MAJEUR de su-3.
  ///
  /// ⚠️ **Formulation exacte** (une version antérieure de cette dartdoc disait
  /// « aucune fenêtre ne s'ouvre » — **techniquement faux**) : en Dart,
  /// `await <non-Future>` **suspend quand même** (reprise en microtâche). Le
  /// paquet cède donc une microtâche sur son `await`, **inconditionnellement**,
  /// même face à un handler synchrone. Ce qui est vrai — et qui **suffit** — est
  /// autre : en **retournant `bool`** (et non `Future<bool>`), ce handler
  /// s'exécute **INTÉGRALEMENT avant** ce point de suspension. Quand la fenêtre
  /// du paquet s'ouvre, su-4 **n'a plus rien à faire** : tout son travail est
  /// déjà commis. Aucun jeton de fraîcheur n'aurait donc quoi que ce soit à
  /// garder ici. La propriété appartient à **notre handler**, pas au paquet — ne
  /// pas lire l'inverse.
  ///
  /// ⚠️ **Un jeton `_generation` a été écrit puis RETIRÉ** : l'injection R3-I17a
  /// (le supprimer) **ne rougissait aucun test** — il était **structurellement
  /// inatteignable**, et sa dartdoc affirmait « capturé avant l'`await` » alors
  /// qu'il n'existe **aucun** `await`. C'était le défaut **D8 de su-3** rejoué
  /// (du code décoratif adossé à un test incapable de rougir), et une **fausse
  /// affirmation de conformité**. La dissolution est conservée ; l'invariant qui
  /// la rend vraie — la **synchronicité** — est désormais **GARDÉ** par
  /// `z_session_swipe_concurrency_test.dart`, qui rougit si ce handler devient
  /// `async`. Le jeton reste RÉELLEMENT nécessaire là où la fenêtre existe :
  /// `z_flashcard_answer_input.dart:280` (port d'évaluation `await`é, su-3) —
  /// et l'assemblage le prouve.
  bool _handleSwipe(int previousIndex, int? currentIndex, Object? direction) {
    if (currentIndex == null) return true; // fin de pile : `onEnd` s'en charge.
    _emitIndexChanged(currentIndex);
    return true;
  }

  /// `onEnd` du paquet — n'est appelé que sur la **dernière** carte, **après**
  /// `onSwipe` (vérifié : `_handleCompleteSwipe`).
  void _handleEnd() {
    if (_stackEnded) return; // 🔒 one-shot : `onEnd` peut être ré-entrant.
    _stackEnded = true;
    widget.onStackEnd?.call();
  }

  /// **Avancée** programmatique (alternative accessible, AC9).
  ///
  /// Passe par `controller.swipe` — et **non** par `moveTo` : vérifié sur disque,
  /// `_moveTo` **court-circuite `onSwipe`** (`lib/src/widget/card_swiper_state.dart:329-336`),
  /// donc [ZSessionCardSwiper.onIndexChanged] ne serait **jamais** émis pour une
  /// navigation au clavier/lecteur d'écran. `swipe`, lui, rejoint
  /// `_handleCompleteSwipe` ⇒ **une seule voie d'émission** (arbitrage A6).
  ///
  /// ⚠️ **`direction` ne choisit PAS un sens de déplacement** — fait vérifié sur
  /// disque : `_swipe(dir)` mène à `_undoableIndex.state = _nextIndex`, soit
  /// **`+1` quelle que soit la direction** (`card_swiper_state.dart:295-300`) ;
  /// `direction` n'est lue que par `_isValidDirection` (validation de fin de
  /// geste). C'est cohérent avec A2 (« les deux directions avancent ») — et c'est
  /// **exactement pourquoi il ne peut exister aucun bouton « précédent »** ici
  /// (cf. § « Pourquoi aucun retour arrière »).
  void _advance() => _controller.swipe(CardSwiperDirection.right);

  /// Carte **mémoïsée** par index (AC7).
  Widget _cardAt(BuildContext context, int index) =>
      _cardCache.putIfAbsent(index, () {
        return widget.cardBuilder(context, widget.queue[index]);
      });

  @override
  Widget build(BuildContext context) {
    // 🔴 AC11 — file VIDE : `cardsCount = 0` fait lever **DEUX** asserts du ctor
    // de `CardSwiper` (`numberOfCardsDisplayed >= 1 && <= cardsCount`, puis
    // `initialIndex < cardsCount`). On ne le construit donc PAS : repli défini,
    // jamais un crash (AD-10).
    if (widget.queue.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? _defaultEmpty(context);
    }

    final reduceMotion = zReduceMotionOf(context);
    final theme = ZcrudTheme.of(context);

    return Column(
      children: <Widget>[
        Expanded(
          child: CardSwiper(
            // 🔑 AD-10 — l'index interne du paquet DOIT mourir avec la file
            // qu'il indexait (crash mesuré sans cela — cf. [_queueGeneration]).
            key: ValueKey<int>(_queueGeneration),
            controller: _controller,
            cardsCount: widget.queue.length,
            // 🔴 défaut `2` ⇒ `assert(numberOfCardsDisplayed <= cardsCount)`
            // ⇒ CRASH sur une file d'UNE carte — une session parfaitement
            // normale.
            numberOfCardsDisplayed: math.min(2, widget.queue.length),
            // 🔴 défaut `true` ⇒ la pile boucle ⇒ la session NE SE TERMINE
            // JAMAIS et `onEnd` n'est jamais atteint.
            isLoop: false,
            // 🔒 Animation RÉELLE (200 ms) réellement supprimée (NFR-SU3).
            duration: reduceMotion ? Duration.zero : widget.swipeDuration,
            // ⚠️ Ne filtre QUE la fin de geste : n'empêche PAS le pan de
            // revendiquer le vertical (cf. dartdoc de librairie).
            allowedSwipeDirection:
                const AllowedSwipeDirection.symmetric(horizontal: true),
            onSwipe: _handleSwipe,
            onEnd: _handleEnd,
            padding: EdgeInsets.all(theme.gapM),
            cardBuilder: (context, index, horizontalOffset, verticalOffset) {
              return Stack(
                children: <Widget>[
                  // 🔒 AC7 — instance IDENTIQUE d'une frame à l'autre : le
                  // `cardBuilder` est ré-invoqué à chaque frame de drag, mais
                  // `Element.updateChild` court-circuite ce sous-arbre.
                  _cardAt(context, index),
                  // Seul nœud qui dépend RÉELLEMENT de l'offset ⇒ seul à se
                  // reconstruire pendant le drag (frère, sous IgnorePointer).
                  ZSwipeEmotionIndicator(
                    offsetPercentage: horizontalOffset,
                    reduceMotion: reduceMotion,
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(height: theme.gapM),
        _navigationRow(context, theme),
      ],
    );
  }

  /// Alternative **accessible** au swipe (AC9/AD-13) + progression annoncée.
  ///
  /// 🚫 **Un seul bouton, et c'est délibéré** : la pile n'a **aucun** retour
  /// arrière (cf. § « Pourquoi aucun retour arrière » de la dartdoc de
  /// librairie). L'utilisateur de lecteur d'écran dispose donc **exactement**
  /// des mêmes déplacements que l'utilisateur du geste — c'est la parité
  /// qu'exige AD-13, et non un contrôle supplémentaire qui mentirait.
  Widget _navigationRow(BuildContext context, ZcrudTheme theme) => Row(
        children: <Widget>[
          Expanded(
            child: ZSessionProgressIndicator(
              total: widget.queue.length,
              currentIndex: _index,
              passThreshold: widget.passThreshold,
              style: widget.progressStyle,
              qualityOf: widget.qualityOf,
            ),
          ),
          _NavButton(
            key: ZSessionCardSwiper.nextButtonKey,
            labelKey: ZSessionCardSwiper.nextLabelKey,
            fallback: 'carte suivante',
            icon: Icons.chevron_right,
            onPressed: _advance,
          ),
        ],
      );

  /// Repli **file vide** par défaut — localisé, observable (AC11).
  Widget _defaultEmpty(BuildContext context) => Center(
        key: ZSessionCardSwiper.emptyKey,
        child: Text(
          label(
            context,
            ZSessionCardSwiper.emptyLabelKey,
            fallback: 'Aucune carte',
          ),
          textAlign: TextAlign.center,
        ),
      );
}

/// Bouton de navigation accessible (privé) — cible ≥ 48 dp, `Semantics`, label
/// **localisé** (jamais un libellé en dur), icône directionnelle.
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.labelKey,
    required this.fallback,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String labelKey;
  final String fallback;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Semantics(
      button: true,
      label: label(context, labelKey, fallback: fallback),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: ZSessionCardSwiper.minTarget,
          minHeight: ZSessionCardSwiper.minTarget,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.all(theme.radiusM),
            child: Icon(icon),
          ),
        ),
      ),
    );
  }
}
