/// `ZSessionCardSwiper` — pile de session swipeable.
///
/// ## Le swipe est une navigation. Il ne note jamais.
///
/// Ce type n'a aucun paramètre de qualité, de notation ou de reviewer : la
/// notation y est structurellement impossible — le régime d'écriture est une
/// propriété du type. Elle appartient aux `ZSrsQualityButtons`, que l'hôte
/// compose en frère, hors de la pile. La tentation « gauche = raté / droite
/// = réussi » (le geste façon appli de rencontre) est précisément ce que ce
/// widget interdit : ici, les deux directions horizontales font avancer, ce
/// qui dissout au passage la question RTL — `CardSwiperDirection.left/right`
/// étant physiques, pas logiques.
///
/// ## Pourquoi aucun retour arrière — ni au geste, ni au bouton
///
/// La pile n'avance que. Ce n'est pas un manque, c'est le modèle :
///
/// - les deux directions de swipe avancent. `CardSwiperController.swipe(left)`
///   n'est pas « aller à la carte précédente » : c'est « chasser la carte
///   courante vers la gauche », donc avancer, quelle que soit la direction ;
/// - aucun runtime ne recule : dans les trois moteurs, `cursor` ne fait que
///   croître ou se recaler après un retrait — aucun n'expose de retour
///   arrière. Un bouton qui reculerait l'index du widget laisserait le
///   `cursor` du moteur sur place, fabriquant la désynchronisation à deux
///   sources de vérité que [_queueGeneration] existe précisément pour
///   fermer ;
/// - le besoin qui motive ce widget est « avancer dans la pile », pas
///   « revenir en arrière ».
///
/// Ce que [ZSessionCardSwiper.indexController] ne remet pas en cause : le
/// widget n'expose toujours aucun bouton de retour, et aucune de ses voies
/// internes ne recule. Ce qui change, c'est qu'un hôte qui possède déjà une
/// barre de navigation externe (flèches, saut direct à un index) cesse
/// d'obtenir des boutons morts : il commande la carte courante par un
/// [ZIndexController], et le composant lit/écrit chez lui. La
/// synchronisation avec le `cursor` d'un moteur (qui, lui, ne recule pas)
/// reste la charge de cet hôte — c'est sa commande, pas une voie du widget.
///
/// Un bouton « carte précédente » avait un temps existé ici, câblé sur
/// `swipe(left)` — mais ce geste avance toujours, quelle que soit la
/// direction. Il ne mentait donc pas à n'importe qui : il mentait à
/// l'utilisateur de lecteur d'écran, le seul public que cette rangée existe
/// pour servir, et de façon irrattrapable (chaque tentative de correction
/// avançait encore). Un contrôle absent vaut mieux qu'un contrôle qui
/// annonce l'inverse de ce qu'il fait : l'utilisateur de lecteur d'écran
/// dispose donc exactement des mêmes déplacements que l'utilisateur du
/// geste — la parité qu'exige l'invariant AD-13.
///
/// ## L'arène des gestes — dissolution par la géométrie
///
/// `flutter_card_swiper` pose sur la carte de devant un `GestureDetector`
/// avec `onPanStart/Update/End` — un `PanGestureRecognizer` qui revendique
/// les deux axes — et un `onTap` toujours enregistré. Il entre donc en
/// arène contre tout ce qui vit sous lui. La réponse ici n'est pas de
/// dompter des recognizers, mais de faire en sorte que les gestes
/// concurrents ne se rencontrent jamais :
///
/// ```text
/// ZSessionCardSwiper           ← le pan ne couvre QUE ceci
/// └── CardSwiper(cardBuilder:)
///     └── Stack
///         ├── carte d'AFFICHAGE               ← instance mémoïsée
///         └── ZSwipeEmotionIndicator          ← IgnorePointer, ne vole rien
/// ─────────────────── frontière du swiper ───────────────────
/// ZFlashcardAnswerInput   ← FRÈRE — jamais sous le pan
/// ZSrsQualityButtons      ← FRÈRE — la notation
/// ```
///
/// Règle non négociable : `ZFlashcardAnswerInput` / `ZSrsQualityButtons` ne
/// descendent jamais dans le [cardBuilder]. Un `TextField` sous un pan
/// ancêtre, c'est le placement du curseur et la sélection qui se battent
/// contre la navigation — aucun réglage de seuil ne rend cela fiable. Le
/// conflit drag contre saisie est dissous par construction, pas arbitré.
///
/// ## Réglages du `CardSwiper` — chacun adossé à un comportement vérifié du
/// paquet tiers
///
/// | Réglage | Valeur | Pourquoi (invariant AD-10) |
/// |---|---|---|
/// | `cardsCount` | `queue.length`, jamais 0 | `cardsCount = 0` ferait lever deux asserts du constructeur ⇒ repli avant construction |
/// | `numberOfCardsDisplayed` | `min(2, queue.length)` | défaut 2 exigerait `<= cardsCount` ⇒ crash sur une file d'une carte |
/// | `isLoop` | `false` | défaut `true` ⇒ la session ne se termine jamais |
/// | `duration` | `Duration.zero` sous Reduce Motion | sinon une animation réelle de 200 ms persiste |
/// | `allowedSwipeDirection` | `symmetric(horizontal: true)` | porteur pendant le drag et à la fin — voir ci-dessous |
/// | `onSwipe` | navigation seule → [onIndexChanged] | `FutureOr<bool>` attendu par le paquet ⇒ handler gardé synchrone |
///
/// `allowedSwipeDirection` fait deux choses :
/// 1. à la fin du geste, il rejette une direction verticale et empêche
///    `onSwipe` d'être appelé ;
/// 2. pendant le drag, le paquet n'applique un déplacement vertical que si
///    la direction verticale correspondante est autorisée. Avec
///    `symmetric(horizontal: true)`, aucune direction verticale n'est
///    autorisée, donc aucun déplacement vertical n'est appliqué même pendant
///    un pan qui gagne l'arène sur cet axe.
///
/// Ne pas en conclure que ce réglage est cosmétique pendant le drag et le
/// remplacer par `AllowedSwipeDirection.all()` : cela rendrait réelle une
/// translation verticale qui n'existe pas aujourd'hui, et sur une carte
/// courte (où le `Scrollable` décline le geste, faute de quoi défiler) la
/// carte se mettrait à suivre le doigt verticalement et à s'envoler. Le
/// `PanGestureRecognizer` revendique bien les deux axes dans l'arène — c'est
/// ce réglage qui est le garde-fou pendant le drag, pas seulement la
/// validation de fin de geste.
///
/// Widget pur (invariants AD-2/AD-15) : aucun gestionnaire d'état, aucun
/// moteur, aucun `ZSrsScheduler`. Le `CardSwiperController` est possédé
/// (créé en `initState`, libéré en `dispose` — jamais dans `build`).
///
/// Confinement : c'est le seul fichier du monorepo qui importe
/// `flutter_card_swiper`, et aucun type du paquet n'apparaît dans une
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

/// Construit la carte d'affichage d'un item (typiquement
/// `ZFlashcardReviewCard`). Jamais une surface de saisie ou de notation :
/// celles-ci vivent en frères, hors de la pile.
typedef ZSessionCardBuilder = Widget Function(
  BuildContext context,
  ZSessionItem item,
);

/// Pile de session swipeable — navigation seule.
class ZSessionCardSwiper extends StatefulWidget {
  /// Construit la pile.
  ///
  /// - [queue] : file déjà sélectionnée — ce widget ne sélectionne jamais,
  ///   il ne connaît ni filtre, ni échéance, ni mode ;
  /// - [cardBuilder] : carte d'affichage d'un item ;
  /// - [onIndexChanged] : navigation seule — émis à chaque avancée, quelle
  ///   qu'en soit l'origine (geste ou bouton d'accessibilité : une seule
  ///   voie d'émission) ;
  /// - [onStackEnd] : fin de pile. Ce widget émet l'événement et ne rend
  ///   aucune UI de fin — l'écran de fin est composé par l'hôte ;
  /// - [emptyBuilder] : repli file vide (invariant AD-10) ;
  /// - [progressStyle] : variante d'indicateur (enum) ;
  /// - [qualityOf] : seam « qualité obtenue à l'index i » (indicateur) ;
  /// - [passThreshold] : frontière réussite/lapse injectée (jamais un
  ///   littéral en dur) ;
  /// - [swipeDuration] : durée d'animation, ramenée à zéro sous Reduce Motion.
  ///
  /// Aucun paramètre de notation — c'est un invariant du type, pas un oubli.
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
    this.indexController,
    super.key,
  });

  /// File déjà sélectionnée (invariant AD-1).
  final List<ZSessionItem> queue;

  /// Constructeur de la carte d'affichage.
  final ZSessionCardBuilder cardBuilder;

  /// Frontière réussite/lapse injectée, relayée à l'indicateur.
  final int passThreshold;

  /// Notification d'avancée — navigation seule, jamais une note.
  final ValueChanged<int>? onIndexChanged;

  /// Notification de fin de pile (aucune UI de fin rendue ici).
  final VoidCallback? onStackEnd;

  /// Repli file vide (invariant AD-10). `null` : repli par défaut localisé.
  final WidgetBuilder? emptyBuilder;

  /// Variante d'indicateur de progression (enum).
  final ZSessionProgressStyle progressStyle;

  /// Seam « qualité obtenue à l'index i » (`null` : aucune carte notée).
  final ZSessionQualityAtIndex? qualityOf;

  /// Durée d'animation de swipe (`Duration.zero` sous Reduce Motion).
  final Duration swipeDuration;

  /// Pilote optionnel de la carte courante (patron [ZDisplayStateBinding]).
  ///
  /// - `null` (défaut) : l'index vit en interne, comportement et rendu
  ///   strictement inchangés ;
  /// - non-null : le contrôleur est la source de vérité, le composant n'en
  ///   garde aucun miroir (il lit et écrit chez l'hôte), de sorte que deux
  ///   états ne peuvent pas diverger. Une écriture de l'hôte (`value = 3`,
  ///   `next()`, `previous()`) déplace réellement la carte de devant via
  ///   `CardSwiperController.moveTo` — c'est ce qui distingue ce paramètre
  ///   d'un passe-plat inerte.
  ///
  /// Défensif (invariant AD-10) : une commande hors bornes (`< 0` ou
  /// `>= queue.length`) est ramenée dans les bornes et réécrite dans le
  /// contrôleur, jamais simplement ignorée — l'ignorer laisserait le
  /// contrôleur de l'hôte affirmer un index que rien n'affiche.
  ///
  /// [onIndexChanged] reste émis, quelle que soit l'origine (geste, bouton
  /// d'accessibilité, ou commande de l'hôte) — la notification sortante
  /// n'est pas remplacée par le pilote, elle lui survit.
  final ZIndexController? indexController;

  /// Clé du bouton de navigation suivant (alternative accessible).
  ///
  /// Il n'existe délibérément aucun bouton « précédent » — voir la dartdoc
  /// de librairie, section « Pourquoi aucun retour arrière ».
  static const ValueKey<String> nextButtonKey =
      ValueKey<String>('zSwiperNext');

  /// Clé du repli file vide par défaut, pour qu'un test puisse observer le
  /// repli plutôt que constater seulement l'absence d'exception.
  static const ValueKey<String> emptyKey = ValueKey<String>('zSwiperEmpty');

  /// Clé l10n du repli file vide.
  static const String emptyLabelKey = 'zcrud.session.empty';

  /// Clé l10n du bouton « carte suivante ».
  static const String nextLabelKey = 'zcrud.session.next';

  /// Cible tap minimale (dp), invariant AD-13.
  ///
  /// Non négociable ici : le paquet tiers `flutter_card_swiper` n'expose
  /// aucune sémantique, ce qui rendrait la pile inutilisable au lecteur
  /// d'écran sans cette alternative accessible.
  static const double minTarget = 48;

  @override
  State<ZSessionCardSwiper> createState() => _ZSessionCardSwiperState();
}

class _ZSessionCardSwiperState extends State<ZSessionCardSwiper> {
  /// Contrôleur possédé — créé ici, libéré ici. Jamais dans `build`
  /// (`dispose()` est `Future<void>` et le recréer par frame fuirait).
  late final CardSwiperController _controller = CardSwiperController();

  /// Carte courante — liaison vers l'index, jamais un miroir.
  ///
  /// Sans [ZSessionCardSwiper.indexController], l'état vit dans le
  /// `ValueNotifier` interne de la liaison (comportement d'origine). Avec un
  /// contrôleur, toute lecture et toute écriture le traversent : il n'y a
  /// qu'un seul état, donc rien qui puisse diverger.
  late final ZDisplayStateBinding<int> _current;

  /// Index sur lequel se trouve le paquet tiers (`CardSwiper._currentIndex`).
  ///
  /// Ce n'est pas un miroir de l'état d'affichage : c'est notre connaissance
  /// du curseur interne d'une dépendance tierce, que rien n'expose en
  /// lecture. Il sert à décider si une nouvelle valeur vient du paquet (rien
  /// à faire) ou de l'hôte (le paquet doit être déplacé) — sans lui, chaque
  /// swipe déclencherait un `moveTo` redondant sur l'index où le paquet se
  /// trouve déjà.
  int _swiperIndex = 0;

  /// Vrai pendant la remise à zéro consécutive à un changement de file : la
  /// réconciliation et l'émission sont alors suspendues (ce reset n'a jamais
  /// dû émettre d'événement).
  bool _resettingQueue = false;

  /// Verrou one-shot de [ZSessionCardSwiper.onIndexChanged] : le dernier
  /// index réellement émis — dédoublonne toute ré-émission d'un même index.
  ///
  /// Portée honnête : avec un [_handleSwipe] synchrone, ce verrou n'est
  /// jamais réellement sollicité en pratique (le paquet n'avance son index
  /// interne qu'une fois par swipe complété). Il est conservé comme défense
  /// en profondeur, pas comme la cause du comportement observé : celui-ci
  /// tient à la synchronicité de [_handleSwipe] (voir sa dartdoc) et au
  /// gating d'animation du paquet.
  int? _lastEmittedIndex;

  /// Verrou one-shot de fin de pile (même portée honnête que
  /// [_lastEmittedIndex] : non atteint avec `isLoop: false`, où l'index
  /// devient `null` après la dernière carte et interdit tout swipe ultérieur).
  bool _stackEnded = false;

  /// Cache d'instances de carte par index.
  ///
  /// Pourquoi un cache et non un `const` : `onPanUpdate` appelle `setState`,
  /// donc le [ZSessionCardSwiper.cardBuilder] est ré-invoqué à chaque frame
  /// de drag (comportement du paquet tiers, non contournable depuis
  /// l'extérieur). La granularité s'obtient donc en rendant l'invocation
  /// inoffensive : on renvoie l'instance identique
  /// (`identical(w1, w2) == true`), ce qui fait court-circuiter tout le
  /// sous-arbre de la carte par `Element.updateChild`.
  final Map<int, Widget> _cardCache = <int, Widget>{};

  /// Génération de file — incrémentée à chaque changement réel de
  /// [ZSessionCardSwiper.queue], et seulement là. Sert de `key` au
  /// `CardSwiper` (voir [build]).
  ///
  /// Ce n'est pas un jeton décoratif : il ferme un crash réel. Le
  /// `CardSwiper` porte sa propre source de vérité d'index, posée
  /// uniquement à sa construction et que son cycle de mise à jour ne
  /// réinitialise jamais (il ne fait que ré-abonner le contrôleur). Sans
  /// `key`, l'`Element` est réutilisé au changement de file : l'index du
  /// paquet survit à une file qu'il n'indexe plus.
  ///
  /// Trois défauts en découlaient, tous de cette même racine :
  /// 1. crash (`RangeError`) sur une file qui rétrécit : le calcul du
  ///    nombre de cartes visibles à l'écran devient négatif dès que l'index
  ///    interne dépasse la nouvelle longueur de file, et lève en plein
  ///    `build`. Or `ZStudySessionEngine.reduceGrade` retire la carte
  ///    courante sans la réinsérer sur une réussite : toute réussite
  ///    rétrécit la file. C'était le chemin nominal, pas un cas limite ;
  /// 2. indicateur menteur — file remplacée à longueur égale : l'indicateur
  ///    de ce widget repartait à `0` pendant que le paquet restait sur une
  ///    carte plus avancée ;
  /// 3. cul-de-sac — quand l'index atteignait le nombre de cartes, l'écran
  ///    restait vide sans repli et `onStackEnd` n'était jamais émis, donc
  ///    une session sans fin ni recours (invariant AD-10).
  ///
  /// En remontant le `CardSwiper`, son état interne est reconstruit et
  /// revient à son index initial (0) — aligné sur le `_swiperIndex = 0` que
  /// ce `State` s'impose déjà. Les trois défauts se ferment d'un seul geste.
  int _queueGeneration = 0;

  @override
  void initState() {
    super.initState();
    _current = ZDisplayStateBinding<int>(consumer: this, initialValue: 0)
      ..bind(widget.indexController);
    // Voie unique de réaction : geste du paquet, bouton d'accessibilité et
    // commande de l'hôte convergent ici. Deux voies feraient diverger le
    // comptage émis de la carte affichée.
    _current.listenable.addListener(_onCurrentChanged);
    // Un contrôleur d'hôte peut arriver DÉJÀ positionné (reprise de session).
    _swiperIndex = _clampIndex(_current.value);
    if (_swiperIndex != _current.value) {
      // Commande initiale hors bornes : corrigée À LA SOURCE, mais en fin de
      // frame — écrire ici notifierait l'hôte pendant son propre `build`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _current.value = _swiperIndex;
      });
    }
  }

  /// Ramène [index] dans les bornes de la file (invariant AD-10) — file
  /// vide donne `0`.
  int _clampIndex(int index) {
    final int last = widget.queue.length - 1;
    if (last < 0) return 0;
    return index < 0 ? 0 : (index > last ? last : index);
  }

  @override
  void didUpdateWidget(ZSessionCardSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'hôte a le droit de changer (ou de retirer) son pilote — sans quoi le
    // composant resterait branché sur l'ancien, muet pour le nouveau.
    _current.bind(widget.indexController);
    // Invalidation UNIQUEMENT sur changement réel de la file : sinon le cache
    // rendrait une carte périmée (et un `identical` mensonger).
    if (!listEquals(oldWidget.queue, widget.queue)) {
      _cardCache.clear();
      _lastEmittedIndex = null;
      _stackEnded = false;
      _swiperIndex = 0;
      // Écrit À LA SOURCE (donc chez l'hôte quand il pilote) : la file a
      // changé, l'index 0 est le seul vrai. Suspendre la voie unique le temps
      // de cette écriture préserve le comportement d'origine — ce reset
      // n'émettait pas `onIndexChanged`, et ne doit pas se mettre à le faire.
      _resettingQueue = true;
      _current.value = 0;
      _resettingQueue = false;
      // Remonte le `CardSwiper` : sans cela son index interne survivrait à
      // la file (crash / indicateur menteur / cul-de-sac — voir
      // [_queueGeneration]).
      _queueGeneration++;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    // La liaison ne dispose jamais le contrôleur de l'hôte : il ne nous
    // appartient pas (son propriétaire est un `State` de l'hôte).
    _current.listenable.removeListener(_onCurrentChanged);
    _current.dispose();
    super.dispose();
  }

  /// Écrit l'avancée à la source (interne, ou contrôleur de l'hôte).
  ///
  /// Ne fait qu'écrire : la réconciliation du paquet et l'émission sont la
  /// charge de [_onCurrentChanged], qui écoute la source. Émettre ici
  /// laisserait muet le chemin qui ne passe pas par le composant (l'hôte
  /// écrivant dans son contrôleur), et la promesse « émis à chaque avancée »
  /// ne vaudrait que pour les chemins internes.
  void _emitIndexChanged(int index) {
    _swiperIndex = index; // le paquet est déjà là : aucun `moveTo` à demander.
    _current.value = index;
  }

  /// Voie unique de réaction à un changement de carte courante, d'où qu'il
  /// vienne : swipe, bouton d'accessibilité, ou commande de l'hôte.
  void _onCurrentChanged() {
    if (_resettingQueue) return;
    final int raw = _current.value;
    final int clamped = _clampIndex(raw);
    if (clamped != raw) {
      // Commande hors bornes : corrigée à la source (ré-entrée avec la
      // valeur valide). L'ignorer laisserait le contrôleur de l'hôte
      // affirmer un index que rien n'affiche.
      _current.value = clamped;
      return;
    }
    if (clamped != _swiperIndex) {
      // Origine hôte : le paquet ne bouge pas tout seul. Sans ce `moveTo`,
      // le paramètre serait un passe-plat inerte — un bouton mort de plus.
      _swiperIndex = clamped;
      _controller.moveTo(clamped);
    }
    if (_lastEmittedIndex == clamped) return; // one-shot
    _lastEmittedIndex = clamped;
    widget.onIndexChanged?.call(clamped);
  }

  /// `onSwipe` du paquet — navigation seule, et synchrone.
  ///
  /// Aucune qualité n'est dérivée de [direction] : le paramètre est ignoré,
  /// et c'est délibéré. Le mapper serait le geste façon appli de rencontre
  /// que ce widget interdit.
  ///
  /// Synchrone : c'est ici que la fenêtre de concurrence est dissoute, pas
  /// gardée. `CardSwiperOnSwipe` est un `FutureOr<bool>` que le paquet
  /// attend. Un handler asynchrone ouvrirait donc une fenêtre réelle pendant
  /// laquelle la file peut changer.
  ///
  /// En Dart, `await <non-Future>` suspend quand même (reprise en
  /// microtâche) : le paquet cède donc une microtâche sur son `await`,
  /// inconditionnellement, même face à un handler synchrone. Ce qui compte
  /// est autre : en retournant `bool` (et non `Future<bool>`), ce handler
  /// s'exécute intégralement avant ce point de suspension. Quand la fenêtre
  /// du paquet s'ouvre, il n'y a plus rien à faire ici : tout le travail est
  /// déjà commis. Aucun jeton de fraîcheur n'a donc quoi que ce soit à
  /// garder dans ce handler — cette propriété lui appartient, elle n'est pas
  /// garantie par le paquet lui-même.
  ///
  /// L'invariant qui rend cette dissolution vraie — la synchronicité — est
  /// gardé par un test dédié qui rougit si ce handler devient `async`. Un
  /// jeton de fraîcheur reste réellement nécessaire là où une fenêtre de
  /// concurrence existe réellement, par exemple autour d'un port
  /// d'évaluation attendu (`await`) côté surface de saisie.
  bool _handleSwipe(int previousIndex, int? currentIndex, Object? direction) {
    if (currentIndex == null) return true; // fin de pile : `onEnd` s'en charge.
    _emitIndexChanged(currentIndex);
    return true;
  }

  /// `onEnd` du paquet — n'est appelé que sur la **dernière** carte, **après**
  /// `onSwipe` (vérifié : `_handleCompleteSwipe`).
  void _handleEnd() {
    if (_stackEnded) return; // one-shot : `onEnd` peut être ré-entrant.
    _stackEnded = true;
    widget.onStackEnd?.call();
  }

  /// Avancée programmatique (alternative accessible).
  ///
  /// Passe par `controller.swipe` et non par `moveTo` : `moveTo`
  /// court-circuite `onSwipe`, donc [ZSessionCardSwiper.onIndexChanged] ne
  /// serait jamais émis pour une navigation au clavier ou au lecteur
  /// d'écran. `swipe`, lui, rejoint le même chemin que le geste — une seule
  /// voie d'émission.
  ///
  /// `direction` ne choisit pas un sens de déplacement : le paquet avance
  /// toujours son index d'un cran, quelle que soit la direction passée ;
  /// `direction` n'est lue que pour la validation de fin de geste. C'est
  /// cohérent avec le fait que les deux directions avancent — et c'est
  /// exactement pourquoi il ne peut exister aucun bouton « précédent » ici
  /// (voir la section « Pourquoi aucun retour arrière »).
  void _advance() => _controller.swipe(CardSwiperDirection.right);

  /// Carte mémoïsée par index.
  Widget _cardAt(BuildContext context, int index) =>
      _cardCache.putIfAbsent(index, () {
        return widget.cardBuilder(context, widget.queue[index]);
      });

  @override
  Widget build(BuildContext context) {
    // File vide : `cardsCount = 0` ferait lever deux asserts du constructeur
    // de `CardSwiper`. On ne le construit donc pas : repli défini, jamais un
    // crash (invariant AD-10).
    if (widget.queue.isEmpty) {
      return widget.emptyBuilder?.call(context) ?? _defaultEmpty(context);
    }

    final reduceMotion = zReduceMotionOf(context);
    final theme = ZcrudTheme.of(context);

    return Column(
      children: <Widget>[
        Expanded(
          child: CardSwiper(
            // L'index interne du paquet doit mourir avec la file qu'il
            // indexait (crash sans cela — voir [_queueGeneration]).
            key: ValueKey<int>(_queueGeneration),
            controller: _controller,
            cardsCount: widget.queue.length,
            // Un contrôleur d'hôte peut arriver déjà positionné : la
            // première carte montée est alors la sienne, jamais l'index 0
            // (sans quoi l'affichage contredirait la source de vérité dès
            // le montage). Borné par l'assert du constructeur du paquet.
            initialIndex: _clampIndex(_swiperIndex),
            // Défaut du paquet à 2, ce qui exigerait `<= cardsCount` et
            // crasherait sur une file d'une seule carte — une session
            // parfaitement normale.
            numberOfCardsDisplayed: math.min(2, widget.queue.length),
            // Défaut du paquet à `true`, ce qui ferait boucler la pile : la
            // session ne se terminerait jamais et `onEnd` ne serait jamais
            // atteint.
            isLoop: false,
            // Animation réelle (200 ms) réellement supprimée sous Reduce
            // Motion.
            duration: reduceMotion ? Duration.zero : widget.swipeDuration,
            // Ne filtre que la fin de geste : n'empêche pas le pan de
            // revendiquer le vertical (voir la dartdoc de librairie).
            allowedSwipeDirection:
                const AllowedSwipeDirection.symmetric(horizontal: true),
            onSwipe: _handleSwipe,
            onEnd: _handleEnd,
            padding: EdgeInsets.all(theme.gapM),
            cardBuilder: (context, index, horizontalOffset, verticalOffset) {
              return Stack(
                children: <Widget>[
                  // Instance identique d'une frame à l'autre : le
                  // `cardBuilder` est ré-invoqué à chaque frame de drag,
                  // mais `Element.updateChild` court-circuite ce sous-arbre.
                  _cardAt(context, index),
                  // Seul nœud qui dépend réellement de l'offset : seul à se
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

  /// Alternative accessible au swipe (invariant AD-13) et progression
  /// annoncée.
  ///
  /// Un seul bouton, et c'est délibéré : la pile n'a aucun retour arrière
  /// (voir la section « Pourquoi aucun retour arrière » de la dartdoc de
  /// librairie). L'utilisateur de lecteur d'écran dispose donc exactement
  /// des mêmes déplacements que l'utilisateur du geste — c'est la parité
  /// qu'exige l'invariant AD-13, et non un contrôle supplémentaire qui
  /// mentirait.
  Widget _navigationRow(BuildContext context, ZcrudTheme theme) => Row(
        children: <Widget>[
          Expanded(
            // L'avancée ne reconstruit que l'indicateur (invariant AD-2) :
            // la valeur est lue à la source (interne ou contrôleur de
            // l'hôte), jamais dans une copie locale rafraîchie par `setState`.
            child: ValueListenableBuilder<int>(
              valueListenable: _current.listenable,
              builder: (BuildContext context, int currentIndex, Widget? _) =>
                  ZSessionProgressIndicator(
                total: widget.queue.length,
                currentIndex: currentIndex,
                passThreshold: widget.passThreshold,
                style: widget.progressStyle,
                qualityOf: widget.qualityOf,
              ),
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

  /// Repli file vide par défaut — localisé, observable.
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
