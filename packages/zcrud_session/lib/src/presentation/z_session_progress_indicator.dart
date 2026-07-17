/// `ZSessionProgressIndicator` + `ZSwipeEmotionIndicator` — indicateurs de
/// session (présentation PURE, SU-4 AC8 — FR-SU7/NFR-SU3/AD-13).
///
/// Deux surfaces distinctes, toutes deux **PURES** (AD-2/AD-15 : `StatelessWidget`,
/// aucun gestionnaire d'état, aucun moteur, callbacks/couleurs/labels INJECTÉS) :
///
/// 1. [ZSessionProgressIndicator] — **où en suis-je dans la pile**, rendu selon
///    [ZSessionProgressStyle] (**enum**, jamais un `bool isBatch` : une variante
///    est un choix nommé, pas une bascule binaire qu'on ne saura plus étendre).
/// 2. [ZSwipeEmotionIndicator] — le retour émotionnel **pendant le drag**, piloté
///    par le `horizontalOffsetPercentage` que le `cardBuilder` fournit.
///
/// 🔴 **DISTINCT de `ZSessionQualityBreakdown` (arbitrage A3, vérifié sur
/// disque)** — les deux rendent des segments colorés par qualité, d'où la
/// question. Ils n'agrègent PAS la même chose et ne sont pas substituables :
///
/// | | `ZSessionQualityBreakdown` (ES-4.5) | `ZSessionProgressIndicator` (su-4) |
/// |---|---|---|
/// | Entrée | `Map<String,int> byQuality` — **compte par qualité** | `total` + `currentIndex` + seam `qualityOf(index)` |
/// | Unité rendue | **une qualité** (« 4 cartes notées 5 ») | **une carte** (« la 3ᵉ carte, notée 5 ») |
/// | Ordre | l'échelle de qualité | la **position** dans la file |
/// | Cardinalité | `scale.qualities.length` (6) | `total` (N cartes) |
/// | Répond à | « comment ai-je noté ? » | « où en suis-je ? » |
///
/// Le breakdown **a perdu la position** (sa map est une agrégation) : il ne peut
/// pas rendre « où en suis-je », qui est *toute* la fonction d'AC8. Réutiliser
/// l'un pour l'autre exigerait de lui rendre l'information qu'il agrège —
/// c'est-à-dire d'en faire ce widget-ci. Aucune duplication : ils partagent en
/// revanche les seams `labelKeyFor`/`colorKeyFor` et `ZQualityScale`, qui restent
/// définis **une seule fois** (`z_srs_quality_buttons.dart`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_srs_quality_buttons.dart';

/// Style de rendu de la progression — **enum, jamais un booléen**.
///
/// Le spine impose « variantes par enum » : un `bool isBatch` fermerait
/// l'extension (une 3ᵉ variante n'aurait aucune place) et forcerait chaque
/// appelant à retraduire la bascule.
enum ZSessionProgressStyle {
  /// **Points colorés par qualité** — un point par carte. Lisible tant que la
  /// file tient à l'écran : le mode « lot N » (FR-SU7).
  dots,

  /// **Barre segmentée** — segments proportionnels. Le mode « complet », où N
  /// points deviendraient illisibles.
  segmentedBar,
}

/// Résout la **qualité déjà obtenue** pour la carte d'index donné, ou `null` si
/// la carte n'est pas encore notée (seam injecté — le widget ne calcule rien et
/// ne détient aucun état).
typedef ZSessionQualityAtIndex = int? Function(int index);

/// Indicateur de progression d'une session (présentation PURE).
class ZSessionProgressIndicator extends StatelessWidget {
  /// Construit l'indicateur.
  ///
  /// - [total] : nombre de cartes de la file ;
  /// - [currentIndex] : index de la carte courante (0-based) ;
  /// - [passThreshold] : frontière réussite/lapse **INJECTÉE** (`ZSrsConfig`,
  ///   jamais `3` en dur — AD-46) ;
  /// - [style] : variante de rendu (**enum**) ;
  /// - [qualityOf] : seam « qualité de la carte i », `null` ⇒ aucune carte notée ;
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés).
  const ZSessionProgressIndicator({
    required this.total,
    required this.currentIndex,
    required this.passThreshold,
    this.style = ZSessionProgressStyle.dots,
    this.qualityOf,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    super.key,
  });

  /// Nombre total de cartes de la file.
  final int total;

  /// Index 0-based de la carte courante.
  final int currentIndex;

  /// Frontière réussite/lapse INJECTÉE (`quality >= passThreshold`).
  final int passThreshold;

  /// Variante de rendu (**enum**, jamais un booléen).
  final ZSessionProgressStyle style;

  /// Seam « qualité obtenue à l'index i » (`null` ⇒ non notée).
  final ZSessionQualityAtIndex? qualityOf;

  /// Seam de clé de libellé l10n (défaut [zDefaultQualityLabelKey]).
  final ZQualityLabelKeyResolver labelKeyFor;

  /// Seam de clé de couleur (défaut : réussite/lapse via [passThreshold]).
  final ZQualityColorKeyResolver? colorKeyFor;

  /// Clé du nœud portant la progression (testabilité — AC9 : l'ASSOCIATION du
  /// `Semantics(value:)` se prouve sur CE nœud, jamais sur une chaîne trouvée
  /// au hasard de l'arbre).
  static const ValueKey<String> progressKey =
      ValueKey<String>('zSessionProgress');

  /// Clé l10n du libellé de progression (`Semantics.label`).
  static const String progressLabelKey = 'zcrud.session.progress';

  /// Clé de couleur d'une carte **non notée** — rôle neutre, jamais une teinte
  /// en dur.
  static const String pendingColorKey = 'neutral';

  String _colorKeyOf(int quality) {
    final resolver = colorKeyFor;
    if (resolver != null) return resolver(quality);
    return quality >= passThreshold ? 'primary' : 'error';
  }

  /// Paire de couleurs d'une carte : sa qualité si notée, sinon le rôle neutre.
  ZColorPair _pairFor(BuildContext context, int index) {
    final quality = qualityOf?.call(index);
    if (quality == null) {
      return zResolveColorKeyOrSlot(context, pendingColorKey, slotIndex: index);
    }
    return zResolveColorKeyOrSlot(
      context,
      _colorKeyOf(quality),
      slotIndex: quality,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    // Progression rendue en TEXTE dans le `Semantics.value` : la couleur n'est
    // jamais le seul canal (AD-13). `total == 0` ⇒ aucune division, aucun
    // segment (AD-10 : jamais d'exception sur une file vide).
    final position = total == 0 ? 0 : (currentIndex + 1).clamp(1, total);
    final value = '$position/$total';

    return Semantics(
      key: progressKey,
      // 🔒 AC9 — l'ASSOCIATION : le `value` est porté par le nœud DE LA
      // progression, pas déposé quelque part dans l'arbre.
      label: label(context, progressLabelKey, fallback: value),
      value: value,
      child: switch (style) {
        ZSessionProgressStyle.dots => _dots(context, theme),
        ZSessionProgressStyle.segmentedBar => _bar(context, theme),
      },
    );
  }

  /// Points colorés par qualité — un par carte (mode « lot N »).
  Widget _dots(BuildContext context, ZcrudTheme theme) => Wrap(
        spacing: theme.gapS,
        runSpacing: theme.gapS,
        alignment: WrapAlignment.start,
        children: <Widget>[
          for (var i = 0; i < total; i++)
            _Dot(
              key: ValueKey<String>('$_dotKeyPrefix$i'),
              color: _pairFor(context, i).color,
              current: i == currentIndex,
              size: theme.gapM,
            ),
        ],
      );

  /// Barre segmentée — un segment `Expanded` par carte (mode « complet »).
  Widget _bar(BuildContext context, ZcrudTheme theme) => Row(
        children: <Widget>[
          for (var i = 0; i < total; i++)
            Expanded(
              child: Padding(
                // Directionnel (AD-13) — jamais `EdgeInsets.only(left:)`.
                padding: EdgeInsetsDirectional.only(end: theme.gapS / 2),
                child: _Segment(
                  key: ValueKey<String>('$_segmentKeyPrefix$i'),
                  color: _pairFor(context, i).color,
                  current: i == currentIndex,
                  height: theme.gapS,
                ),
              ),
            ),
        ],
      );

  /// Préfixe de [ValueKey] d'un point (testabilité, AC8).
  static const String _dotKeyPrefix = 'zProgressDot_';

  /// Préfixe de [ValueKey] d'un segment de barre (testabilité, AC8).
  static const String _segmentKeyPrefix = 'zProgressSegment_';
}

/// Un point de progression (privé).
class _Dot extends StatelessWidget {
  const _Dot({
    required this.color,
    required this.current,
    required this.size,
    super.key,
  });

  final Color color;
  final bool current;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: current ? size * 1.5 : size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.circular(size)),
        ),
      );
}

/// Un segment de barre (privé).
class _Segment extends StatelessWidget {
  const _Segment({
    required this.color,
    required this.current,
    required this.height,
    super.key,
  });

  final Color color;
  final bool current;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: current ? height * 1.5 : height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.circular(height)),
        ),
      );
}

/// Sens du drag en cours — **enum**, jamais un `bool isRight`.
///
/// ⚠️ **Aucune sémantique de notation n'y est attachée** (FR-SU6, arbitrage A2) :
/// le swipe **navigue**, les DEUX directions font avancer. Cet enum décrit
/// seulement **où va le doigt**, pour placer le retour visuel du bon côté — il
/// ne dit ni « réussi » ni « raté ».
///
/// 🚫 **Cette neutralité est une contrainte de RENDU, pas une intention** : elle
/// n'est tenue que si le glyphe rendu est lui aussi neutre. Un visage
/// souriant/mécontent la **détruirait** — c'est exactement ce qui était rendu ici
/// avant correction (cf. le commentaire de `build` de [ZSwipeEmotionIndicator]).
/// Ne pas réintroduire de glyphe **évaluatif** sous couvert de cet enum.
enum ZSwipeEmotion {
  /// Drag vers le **début** (gauche en LTR).
  towardsStart,

  /// Drag vers la **fin** (droite en LTR).
  towardsEnd,
}

/// Retour émotionnel **pendant le drag** (présentation PURE).
///
/// 🔴 **Reduce Motion : l'animation EXISTE VRAIMENT, et elle est RÉELLEMENT
/// dégradée** (NFR-SU3/AD-13 — leçon su-3/D8, où un `AnimatedOpacity(opacity: 1)`
/// n'animait rien et rendait son test incapable de rougir) :
/// - **sans** Reduce Motion : opacité **et** échelle varient **continûment** avec
///   [offsetPercentage] — l'indicateur *suit le doigt* ;
/// - **avec** Reduce Motion : apparition **binaire au seuil**
///   ([appearThreshold]), opacité et échelle **fixes**, **aucune interpolation**.
///
/// 🔒 **La FONCTION n'est jamais dégradée, seulement l'ANIMATION** (règle
/// su-2/AC3) : au-delà du seuil, l'indicateur **apparaît toujours**, Reduce
/// Motion ou non. Un utilisateur qui refuse les animations ne perd pas le retour
/// visuel — il perd son interpolation.
class ZSwipeEmotionIndicator extends StatelessWidget {
  /// Construit l'indicateur de drag.
  ///
  /// - [offsetPercentage] : offset horizontal du drag en % du seuil (fourni tel
  ///   quel par le `cardBuilder` de la pile) ;
  /// - [reduceMotion] : signal **INJECTÉ** — résolu par `zReduceMotionOf` chez
  ///   l'appelant (primitive UNIQUE du repo ; ce widget n'en lit pas une 2ᵉ).
  const ZSwipeEmotionIndicator({
    required this.offsetPercentage,
    required this.reduceMotion,
    super.key,
  });

  /// Offset horizontal courant du drag, en pourcentage du seuil de swipe.
  final int offsetPercentage;

  /// `true` si l'utilisateur a demandé la réduction des animations.
  final bool reduceMotion;

  /// Fraction d'offset à partir de laquelle l'indicateur apparaît sous Reduce
  /// Motion (apparition **binaire**). En-deçà, rien ne s'affiche.
  static const double appearThreshold = 0.15;

  /// Échelle minimale de l'indicateur (drag naissant), interpolée jusqu'à `1`.
  static const double _minScale = 0.5;

  /// Clé du nœud d'opacité (testabilité : AC8 lit la valeur **résolue** sur le
  /// widget, elle ne la déduit pas).
  static const ValueKey<String> opacityKey =
      ValueKey<String>('zSwipeEmotionOpacity');

  /// Magnitude normalisée du drag (`0..1`).
  double get _magnitude => (offsetPercentage.abs() / 100).clamp(0.0, 1.0);

  /// Sens du drag (`null` ⇒ aucun drag en cours).
  ZSwipeEmotion? get _emotion => offsetPercentage == 0
      ? null
      : (offsetPercentage.isNegative
          ? ZSwipeEmotion.towardsStart
          : ZSwipeEmotion.towardsEnd);

  /// Opacité **résolue** — continue, ou binaire sous Reduce Motion.
  double get resolvedOpacity {
    if (reduceMotion) {
      // 🔒 Dégradation RÉELLE : aucune interpolation. La valeur ne dépend plus
      // de l'amplitude, seulement du franchissement du seuil.
      return _magnitude >= appearThreshold ? 1 : 0;
    }
    return _magnitude;
  }

  /// Échelle **résolue** — continue, ou fixe sous Reduce Motion.
  double get resolvedScale {
    if (reduceMotion) return 1;
    return _minScale + (1 - _minScale) * _magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final emotion = _emotion;
    if (emotion == null) return const SizedBox.shrink();

    // Rôle Material 3 résolu par le cœur — jamais un `Colors.*`/`Color(0x…)`.
    // Les deux sens sont NEUTRES quant à la note (A2) : on distingue le sens du
    // geste, pas une réussite. D'où deux rôles décoratifs, pas `primary`/`error`.
    final pair = zResolveColorKeyOrSlot(
      context,
      switch (emotion) {
        ZSwipeEmotion.towardsEnd => 'secondary',
        ZSwipeEmotion.towardsStart => 'tertiary',
      },
      slotIndex: emotion.index,
    );
    final theme = ZcrudTheme.of(context);

    return IgnorePointer(
      // 🔒 L'overlay ne doit RIEN voler à l'arène (AC6) : il est purement
      // décoratif et vit au-dessus de la carte.
      child: Align(
        // Directionnel (AD-13) — jamais `Alignment.centerLeft/Right`.
        // 🔒 L'icône est placée DU CÔTÉ OÙ VA LE DOIGT (ce que la dartdoc de
        // [ZSwipeEmotion] annonce). Une version antérieure les inversait.
        alignment: switch (emotion) {
          ZSwipeEmotion.towardsEnd => AlignmentDirectional.topEnd,
          ZSwipeEmotion.towardsStart => AlignmentDirectional.topStart,
        },
        child: Padding(
          padding: EdgeInsetsDirectional.all(theme.gapL),
          child: Opacity(
            key: opacityKey,
            opacity: resolvedOpacity,
            child: Transform.scale(
              scale: resolvedScale,
              // 🚫 **Glyphe NEUTRE et DIRECTIONNEL — jamais un visage** (FR-SU6,
              // arbitrage A2). Une version antérieure rendait ici
              // `sentiment_very_satisfied` (fin) vs `sentiment_dissatisfied`
              // (début) — les émojis de l'app source IFFD, où **la direction EST
              // la note** (`quality < 3 ? left : right`). Portés ici, ils
              // réintroduisaient verbatim la sémantique « gauche = raté /
              // droite = réussi » que FR-SU6 interdit — et le faisaient dans le
              // pire des mondes : l'apprenant voyait un visage mécontent suivre
              // son doigt, en concluait avoir **noté**… alors que le swipe
              // **n'écrit RIEN** (c'est l'AC centrale, AC4). Il pouvait « noter »
              // une session entière sans une seule écriture SRS.
              // Un visage est une **évaluation** — un signal strictement plus
              // fort que les couleurs `primary`/`error` déjà écartées ci-dessus
              // pour cette raison même. Une flèche ne dit que **où va le doigt**,
              // ce qui est exactement — et seulement — ce que cet enum décrit.
              //
              // 🔒 RTL (AD-13) : `arrow_back`/`arrow_forward` portent
              // `matchTextDirection: true` (vérifié sur disque —
              // `flutter/lib/src/material/icons.dart:2290,2482`) ⇒ le glyphe
              // **se retourne** avec la direction du texte. `towardsEnd` pointe
              // donc vers la fin dans les DEUX directions — un émoji, lui,
              // n'aurait rien retourné du tout.
              child: Icon(
                switch (emotion) {
                  ZSwipeEmotion.towardsEnd => Icons.arrow_forward,
                  ZSwipeEmotion.towardsStart => Icons.arrow_back,
                },
                color: pair.color,
                size: theme.gapL * 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
