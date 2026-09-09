/// `ZSessionProgressIndicator` + `ZSwipeEmotionIndicator` — indicateurs de
/// session (présentation pure).
///
/// Deux surfaces distinctes, toutes deux pures (invariants AD-2/AD-15 :
/// `StatelessWidget`, aucun gestionnaire d'état, aucun moteur,
/// callbacks/couleurs/labels injectés) :
///
/// 1. [ZSessionProgressIndicator] — où en suis-je dans la pile, rendu selon
///    [ZSessionProgressStyle] (un enum plutôt qu'un `bool isBatch` : une
///    variante est un choix nommé, pas une bascule binaire qu'on ne saura
///    plus étendre).
/// 2. [ZSwipeEmotionIndicator] — le retour émotionnel pendant le drag,
///    piloté par le `horizontalOffsetPercentage` que le `cardBuilder`
///    fournit.
///
/// ## Distinct de `ZSessionQualityBreakdown`
///
/// Les deux widgets rendent des segments colorés par qualité, d'où la
/// question. Ils n'agrègent pas la même chose et ne sont pas substituables :
///
/// | | `ZSessionQualityBreakdown` | `ZSessionProgressIndicator` |
/// |---|---|---|
/// | Entrée | `Map<String,int> byQuality` — compte par qualité | `total` + `currentIndex` + seam `qualityOf(index)` |
/// | Unité rendue | une qualité (« 4 cartes notées 5 ») | une carte (« la 3ᵉ carte, notée 5 ») |
/// | Ordre | l'échelle de qualité | la position dans la file |
/// | Cardinalité | `scale.qualities.length` (6) | `total` (N cartes) |
/// | Répond à | « comment ai-je noté ? » | « où en suis-je ? » |
///
/// Le breakdown a perdu la position (sa map est une agrégation) : il ne
/// peut pas rendre « où en suis-je ». Réutiliser l'un pour l'autre
/// exigerait de lui rendre l'information qu'il agrège — c'est-à-dire d'en
/// faire ce widget-ci. Aucune duplication : ils partagent en revanche les
/// seams `labelKeyFor`/`colorKeyFor` et `ZQualityScale`, définis une seule
/// fois (`z_srs_quality_buttons.dart`).
library;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_session_dots_geometry.dart';
import 'z_srs_quality_buttons.dart';

/// Style de rendu de la progression — un enum, jamais un booléen.
///
/// Un `bool isBatch` fermerait l'extension (une troisième variante n'aurait
/// aucune place) et forcerait chaque appelant à retraduire la bascule.
enum ZSessionProgressStyle {
  /// Points colorés par qualité — un point par carte. Lisible tant que la
  /// file tient à l'écran : le mode « lot N ».
  dots,

  /// Barre segmentée — segments proportionnels. Le mode « complet », où N
  /// points deviendraient illisibles.
  segmentedBar,

  /// Barre segmentée **à marqueur** — segments détachés, tous pleinement
  /// arrondis, surmontés d'un repère triangulaire sur le segment courant.
  ///
  /// Ce que ce style dit de plus que [segmentedBar] : *où* on en est. La barre
  /// segmentée signale la carte courante en l'épaississant, ce qui se perd dès
  /// que la file est longue (un segment 1,5 fois plus haut au milieu de
  /// quarante segments ne saute pas aux yeux). Le marqueur, lui, est un repère
  /// **hors bande** : il vit au-dessus de la barre, il ne dispute sa place à
  /// aucun segment, et il reste repérable quelle que soit la longueur de la
  /// file.
  ///
  /// Les segments sont **détachés** : chacun garde ses quatre coins arrondis,
  /// séparé du suivant par un intervalle. Une barre dont seules les extrémités
  /// sont arrondies laisse croire à une jauge continue — ici chaque segment est
  /// une carte, et sa forme le dit.
  ///
  /// Rien n'est codé en dur : l'épaisseur vient de
  /// [ZSessionProgressIndicator.segmentedMarkerThickness] (défaut :
  /// `ZcrudTheme.gapS`), toute la géométrie (intervalle, rayon, taille du
  /// marqueur) en dérive, et les couleurs viennent du seam
  /// `zResolveColorKeyOrSlot` — le marqueur reprend la couleur du segment
  /// qu'il désigne, il n'introduit aucun rôle supplémentaire.
  ///
  /// **RTL** (invariant AD-13) : le sens de lecture est celui du
  /// `Directionality` ambiant. Le premier segment est à gauche en LTR, à droite
  /// en RTL — aucune direction n'est présumée.
  ///
  /// Contrat a11y **identique aux autres styles** : le nœud
  /// [ZSessionProgressIndicator.progressKey] porte label et `value`. Le
  /// marqueur ne fait que redire visuellement la position déjà annoncée : il
  /// suit la **même** source bornée que le `Semantics(value:)`, les deux ne
  /// peuvent donc pas désigner deux cartes différentes.
  segmentedMarker,

  /// Barre continue — une seule barre remplie à `position/total`, sans
  /// découpage par carte, pour les files longues où même une barre
  /// segmentée deviendrait illisible (un segment par carte sur une file de
  /// 200 cartes produit 200 traits d'un pixel).
  ///
  /// Rien n'est codé en dur : l'épaisseur vient de
  /// [ZSessionProgressIndicator.linearThickness] (défaut : `ZcrudTheme.gapS`) ;
  /// le rayon de `ZcrudTheme.radiusS` ; les deux couleurs des seams
  /// `zResolveColorKeyOrSlot` (remplissage `'primary'`, piste
  /// [ZSessionProgressIndicator.pendingColorKey]). Le contrat a11y est
  /// identique aux deux autres styles : le `Semantics(value: 'position/total')`
  /// reste porté par [ZSessionProgressIndicator.progressKey] — la couleur
  /// n'est donc jamais le seul canal (invariant AD-13).
  linear,

  /// Pilule compacte — la position écrite **en toutes lettres** (« 3/12 »)
  /// dans une forme de stade, sans aucun élément par carte.
  ///
  /// Le seul style dont l'information passe par du **texte** plutôt que par
  /// une géométrie : il tient dans une barre d'outils ou un en-tête où même
  /// une barre continue prendrait toute la largeur, et il reste lisible quel
  /// que soit `total` (une file de 500 cartes s'y écrit aussi bien qu'une
  /// file de 3).
  ///
  /// Rien n'est codé en dur : le fond et le premier plan viennent du seam
  /// `zResolveColorKeyOrSlot` ([ZSessionProgressIndicator.pillColorKey] et sa
  /// couleur `on*` associée, donc un contraste garanti — invariant AD-13), la
  /// forme d'un `StadiumBorder` (le rayon suit la hauteur du texte, il n'y a
  /// donc pas de valeur à poser), les marges internes des tokens
  /// d'espacement du thème.
  ///
  /// Contrat a11y **identique aux trois autres styles** : le nœud
  /// [ZSessionProgressIndicator.progressKey] porte label et `value`, et le
  /// texte de la pilule est retiré de l'arbre sémantique — sans quoi la même
  /// position serait annoncée deux fois.
  pill,
}

/// Résout la **qualité déjà obtenue** pour la carte d'index donné, ou `null` si
/// la carte n'est pas encore notée (seam injecté — le widget ne calcule rien et
/// ne détient aucun état).
typedef ZSessionQualityAtIndex = int? Function(int index);

/// Indicateur de progression d'une session (présentation pure).
class ZSessionProgressIndicator extends StatelessWidget {
  /// Construit l'indicateur.
  ///
  /// - [total] : nombre de cartes de la file ;
  /// - [currentIndex] : index de la carte courante (0-based) ;
  /// - [passThreshold] : frontière réussite/lapse injectée (`ZSrsConfig`,
  ///   jamais un littéral en dur) ;
  /// - [style] : variante de rendu (enum) ;
  /// - [qualityOf] : seam « qualité de la carte i », `null` si aucune carte
  ///   notée ;
  /// - [labelKeyFor]/[colorKeyFor] : seams de libellé/couleur (défauts injectés).
  const ZSessionProgressIndicator({
    required this.total,
    required this.currentIndex,
    required this.passThreshold,
    this.style = ZSessionProgressStyle.dots,
    this.qualityOf,
    this.labelKeyFor = zDefaultQualityLabelKey,
    this.colorKeyFor,
    this.linearThickness,
    this.dotsGeometry,
    this.segmentedMarkerThickness,
    super.key,
  });

  /// Nombre total de cartes de la file.
  final int total;

  /// Index 0-based de la carte courante.
  final int currentIndex;

  /// Frontière réussite/lapse injectée (`quality >= passThreshold`).
  final int passThreshold;

  /// Variante de rendu (enum, jamais un booléen).
  final ZSessionProgressStyle style;

  /// Seam « qualité obtenue à l'index i » (`null` si non notée).
  final ZSessionQualityAtIndex? qualityOf;

  /// Seam de clé de libellé l10n (défaut [zDefaultQualityLabelKey]).
  final ZQualityLabelKeyResolver labelKeyFor;

  /// Seam de clé de couleur (défaut : réussite/lapse via [passThreshold]).
  final ZQualityColorKeyResolver? colorKeyFor;

  /// Épaisseur de la barre [ZSessionProgressStyle.linear] — injectée.
  /// `null` : dérivée du thème (`ZcrudTheme.of(context).gapS`).
  ///
  /// Ce paramètre existe pour qu'une application atteigne l'épaisseur exacte
  /// de son design sans que ce widget code une valeur en dur ni qu'elle
  /// doive tordre le token global `gapS`, partagé par tout le chrome. Une
  /// valeur `<= 0` ou non finie est ignorée (repli thème) — jamais une
  /// exception, jamais une barre invisible (invariant AD-10). Sans effet
  /// sur les styles [dots]/[segmentedBar].
  final double? linearThickness;

  /// Géométrie du style [ZSessionProgressStyle.dots] — injectée.
  /// `null` : rendu par défaut (cf. [ZSessionDotsGeometry]).
  ///
  /// Ce paramètre existe pour qu'une application atteigne la forme exacte de
  /// son design — points en pilule plutôt qu'en cercle, file centrée, file qui
  /// défile au lieu de passer à la ligne — sans que ce widget code la moindre
  /// dimension en dur ni qu'elle doive tordre les tokens `gapS`/`gapM`,
  /// partagés par tout le chrome. Sans effet sur les autres styles.
  final ZSessionDotsGeometry? dotsGeometry;

  /// Épaisseur de la barre [ZSessionProgressStyle.segmentedMarker] — injectée.
  /// `null` : dérivée du thème (`ZcrudTheme.of(context).gapS`).
  ///
  /// Toute la géométrie de ce style en dérive : l'intervalle entre deux
  /// segments, le rayon de leurs coins et la taille du marqueur. Régler
  /// l'épaisseur suffit donc à mettre le style à l'échelle, sans qu'aucune
  /// autre valeur ait à être posée ni tenue cohérente à la main. Une valeur
  /// `<= 0` ou non finie est ignorée (repli thème) — jamais une exception,
  /// jamais une barre invisible (invariant AD-10). Sans effet sur les autres
  /// styles.
  final double? segmentedMarkerThickness;

  /// Clé du nœud portant la progression, pour la testabilité : l'association
  /// du `Semantics(value:)` se prouve sur ce nœud, jamais sur une chaîne
  /// trouvée au hasard de l'arbre.
  static const ValueKey<String> progressKey =
      ValueKey<String>('zSessionProgress');

  /// Clé l10n du libellé de progression (`Semantics.label`).
  static const String progressLabelKey = 'zcrud.session.progress';

  /// Clé de couleur d'une carte non notée — rôle neutre, jamais une teinte
  /// en dur.
  static const String pendingColorKey = 'neutral';

  /// Clé du nœud de la barre continue (style [ZSessionProgressStyle.linear]).
  ///
  /// L'épaisseur et la fraction se lisent sur ce nœud — jamais sur un
  /// `LinearProgressIndicator` trouvé au hasard de l'arbre.
  static const ValueKey<String> linearKey = ValueKey<String>('zProgressLinear');

  /// Clé de couleur du remplissage de la barre continue — rôle Material 3
  /// résolu par le cœur, jamais une teinte en dur.
  static const String linearFillColorKey = 'primary';

  /// Clé du nœud de la pilule (style [ZSessionProgressStyle.pill]).
  ///
  /// Le fond peint et le texte rendu se lisent sur ce nœud — jamais sur un
  /// `Container` trouvé au hasard de l'arbre.
  static const ValueKey<String> pillKey = ValueKey<String>('zProgressPill');

  /// Clé de couleur du fond de la pilule — rôle Material 3 résolu par le
  /// cœur, jamais une teinte en dur.
  ///
  /// Délibérément **pas** le rôle d'erreur : la pilule dit « où en suis-je »,
  /// jamais « vous avez échoué ». Un hôte qui veut sa propre teinte l'injecte
  /// par `ZcrudScope.colorKeyResolver`, sans que ce widget connaisse la
  /// moindre couleur.
  static const String pillColorKey = 'primary';

  /// Clé du nœud peignant la barre à marqueur (style
  /// [ZSessionProgressStyle.segmentedMarker]).
  ///
  /// La géométrie réellement peinte se lit sur ce nœud — jamais sur un
  /// `CustomPaint` trouvé au hasard de l'arbre.
  static const ValueKey<String> segmentedMarkerKey =
      ValueKey<String>('zProgressSegmentedMarker');

  /// Position 1-based dans la file, bornée (`0` si la file est vide).
  ///
  /// Source unique de la progression : le `Semantics(value:)` annoncé et la
  /// fraction peinte par [ZSessionProgressStyle.linear] en dérivent tous
  /// deux — ils ne peuvent donc pas diverger (un lecteur d'écran qui
  /// annonce « 3/4 » devant une barre au quart serait exactement le défaut
  /// évité ici). Défensif (invariant AD-10) : `total <= 0` donne `0`, un
  /// `currentIndex` négatif ou au-delà de la file est ramené dans
  /// `[1, total]`.
  int get position => total <= 0 ? 0 : (currentIndex + 1).clamp(1, total);

  /// Fraction résolue de la barre continue (`0..1`).
  ///
  /// `total <= 0` donne `0` : aucune division, aucune exception, barre vide
  /// (invariant AD-10).
  double get resolvedLinearValue =>
      total <= 0 ? 0 : (position / total).clamp(0.0, 1.0).toDouble();

  /// Épaisseur résolue de la barre continue.
  ///
  /// [linearThickness] si elle est utilisable (finie et `> 0`), sinon le
  /// token de thème `gapS` — jamais un littéral.
  double resolvedLinearThickness(ZcrudTheme theme) {
    final thickness = linearThickness;
    if (thickness == null || !thickness.isFinite || thickness <= 0) {
      return theme.gapS;
    }
    return thickness;
  }

  /// Épaisseur résolue de la barre à marqueur.
  ///
  /// [segmentedMarkerThickness] si elle est utilisable (finie et `> 0`), sinon
  /// le token de thème `gapS` — jamais un littéral.
  double resolvedSegmentedMarkerThickness(ZcrudTheme theme) {
    final thickness = segmentedMarkerThickness;
    if (thickness == null || !thickness.isFinite || thickness <= 0) {
      return theme.gapS;
    }
    return thickness;
  }

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
    // Progression rendue en texte dans le `Semantics.value` : la couleur
    // n'est jamais le seul canal (invariant AD-13). `total == 0` donne
    // aucune division, aucun segment (invariant AD-10).
    final value = '$position/$total';

    return Semantics(
      key: progressKey,
      // Le `value` est porté par le nœud de la progression elle-même, pas
      // déposé quelque part dans l'arbre.
      label: label(context, progressLabelKey, fallback: value),
      value: value,
      child: switch (style) {
        ZSessionProgressStyle.dots => _dots(context, theme),
        ZSessionProgressStyle.segmentedBar => _bar(context, theme),
        ZSessionProgressStyle.segmentedMarker =>
          _segmentedMarker(context, theme),
        ZSessionProgressStyle.linear => _linear(context, theme),
        // `value` est PASSÉ, jamais recalculé : le texte peint et le `value`
        // annoncé ci-dessus sont alors littéralement la même expression, donc
        // structurellement incapables de diverger.
        ZSessionProgressStyle.pill => _pill(context, theme, value),
      },
    );
  }

  /// Pilule compacte portant la position en toutes lettres.
  ///
  /// Aucune couleur ni dimension en dur : fond/premier plan par le seam du
  /// cœur, forme de stade (rayon dérivé de la hauteur du contenu), marges
  /// internes issues des tokens d'espacement. Le `Semantics(value:)` reste
  /// porté par le nœud parent ([progressKey]) — contrat a11y identique aux
  /// trois autres styles.
  Widget _pill(BuildContext context, ZcrudTheme theme, String value) {
    final pair = zResolveColorKeyOrSlot(context, pillColorKey, slotIndex: 0);
    // Le texte EST la progression : laissé dans l'arbre sémantique, il
    // ajouterait un second nœud annonçant la même position dans la même
    // unité que le nœud parent. `ExcludeSemantics` retire ce doublon ; la
    // pilule n'est ni focusable ni actionnable, il n'y a rien à re-déclarer.
    return ExcludeSemantics(
      child: Align(
        // Directionnel (invariant AD-13) — jamais `Alignment.centerLeft`.
        // Sans cet `Align`, la pilule s'étirerait sur toute la largeur sous
        // les contraintes serrées d'un `Expanded` : elle ne serait plus
        // compacte, ce qui est sa seule raison d'être.
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          key: pillKey,
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapM,
            vertical: theme.gapS,
          ),
          decoration: ShapeDecoration(
            color: pair.color,
            // Un stade, pas un rayon posé : le rayon suit la hauteur du
            // contenu, donc la pilule reste une pilule quelle que soit la
            // taille de police de l'utilisateur.
            shape: const StadiumBorder(),
          ),
          // Le repli `TextStyle()` garantit que la couleur du seam est
          // appliquée même si le thème hôte n'expose pas ce style (AD-10) —
          // un `?.copyWith` rendrait un style nul, donc un texte peint à la
          // couleur héritée, illisible sur le fond résolu.
          child: Text(
            value,
            style: (Theme.of(context).textTheme.labelMedium ??
                    const TextStyle())
                .copyWith(color: pair.onColor),
          ),
        ),
      ),
    );
  }

  /// Barre continue.
  ///
  /// Aucune dimension ni couleur en dur : épaisseur par
  /// [resolvedLinearThickness], rayon `theme.radiusS`, couleurs par les seams
  /// du cœur. Le `Semantics(value:)` reste porté par le nœud parent
  /// ([progressKey]) — contrat a11y identique aux deux autres styles.
  Widget _linear(BuildContext context, ZcrudTheme theme) {
    final fill = zResolveColorKeyOrSlot(
      context,
      linearFillColorKey,
      slotIndex: 0,
    );
    final track = zResolveColorKeyOrSlot(context, pendingColorKey, slotIndex: 0);
    // `semanticsValue: null` ne supprime pas l'annonce du `ProgressIndicator`
    // : il la fait calculer (un pourcentage), ce qui produirait un second
    // nœud sémantique annonçant la progression dans une unité différente du
    // nœud parent. `ExcludeSemantics` retire ce nœud enfant ; le nœud parent
    // ([progressKey]) porte déjà label et value, et l'indicateur n'est ni
    // focusable ni actionnable : rien à re-déclarer.
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.all(theme.radiusS),
        child: LinearProgressIndicator(
          key: linearKey,
          value: resolvedLinearValue,
          minHeight: resolvedLinearThickness(theme),
          color: fill.color,
          backgroundColor: track.color,
        ),
      ),
    );
  }

  /// Points colorés par qualité — un par carte (mode « lot N »).
  ///
  /// Toute la géométrie vient de [dotsGeometry] et de ses défauts : ce corps
  /// ne pose aucune dimension.
  Widget _dots(BuildContext context, ZcrudTheme theme) {
    final geometry = dotsGeometry ?? const ZSessionDotsGeometry();
    final inactiveSize = geometry.resolvedInactiveSize(theme);
    final activeWidth = geometry.resolvedActiveWidth(theme);
    final gap = geometry.resolvedGap(theme);
    final dots = <Widget>[
      for (var i = 0; i < total; i++)
        _Dot(
          key: ValueKey<String>('$_dotKeyPrefix$i'),
          color: _pairFor(context, i).color,
          current: i == currentIndex,
          size: inactiveSize,
          activeWidth: activeWidth,
        ),
    ];

    if (!geometry.resolvedScrollable) {
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        alignment: geometry.resolvedAlignment,
        children: dots,
      );
    }

    // File défilante : une seule rangée, quelle que soit la longueur de la
    // file. Le `ConstrainedBox` sur la largeur du viewport est ce qui garde
    // l'alignement demandé opérant tant que la file TIENT — sans lui, le
    // `Row` s'ajusterait à son contenu et `center` n'aurait plus de place à
    // distribuer, donc plus aucun effet visible. Dès que la file déborde, il
    // n'y a plus d'espace libre : l'alignement s'efface de lui-même et la
    // rangée démarre au bord de lecture.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
          ),
          child: Row(
            mainAxisAlignment: _mainAxisOf(geometry.resolvedAlignment),
            children: <Widget>[
              for (var i = 0; i < dots.length; i++) ...<Widget>[
                if (i > 0) SizedBox(width: gap),
                dots[i],
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Traduction 1:1 de l'alignement de file vers l'axe principal d'une rangée.
  ///
  /// `switch` exhaustif sans `default` : une valeur nouvelle de
  /// [WrapAlignment] casserait la compilation plutôt que de retomber
  /// silencieusement sur un alignement qui n'est pas celui demandé.
  static MainAxisAlignment _mainAxisOf(WrapAlignment alignment) =>
      switch (alignment) {
        WrapAlignment.start => MainAxisAlignment.start,
        WrapAlignment.end => MainAxisAlignment.end,
        WrapAlignment.center => MainAxisAlignment.center,
        WrapAlignment.spaceBetween => MainAxisAlignment.spaceBetween,
        WrapAlignment.spaceAround => MainAxisAlignment.spaceAround,
        WrapAlignment.spaceEvenly => MainAxisAlignment.spaceEvenly,
      };

  /// Barre segmentée à marqueur — segments détachés et repère triangulaire.
  ///
  /// Aucune dimension ni couleur en dur : toute la géométrie dérive de
  /// [resolvedSegmentedMarkerThickness], les couleurs des seams du cœur, le
  /// sens de lecture du `Directionality` ambiant (invariant AD-13). Le
  /// `Semantics(value:)` reste porté par le nœud parent ([progressKey]) — le
  /// `CustomPaint` n'ajoute aucun nœud sémantique, le contrat a11y est donc
  /// identique aux autres styles.
  Widget _segmentedMarker(BuildContext context, ZcrudTheme theme) {
    final thickness = resolvedSegmentedMarkerThickness(theme);
    return SizedBox(
      // Le marqueur vit AU-DESSUS de la barre : la hauteur réservée est celle
      // de la barre plus celle du marqueur, sinon le repère serait rogné par
      // le parent.
      height: thickness + _markerHeightFor(thickness),
      child: CustomPaint(
        key: segmentedMarkerKey,
        // `Size.infinite` sous des contraintes bornées vaut « prends toute la
        // largeur offerte » — la barre occupe la place qu'on lui donne, comme
        // celle du style segmenté classique.
        size: Size.infinite,
        painter: _SegmentedMarkerPainter(
          colors: <Color>[
            for (var i = 0; i < total; i++) _pairFor(context, i).color,
          ],
          // `position - 1`, jamais `currentIndex` brut : le marqueur et le
          // `Semantics(value:)` annoncé dérivent alors du MÊME entier borné,
          // ils ne peuvent donc pas désigner deux cartes différentes
          // (invariant AD-10 — un index hors file ne fait ni lever, ni
          // disparaître le repère).
          currentIndex: position - 1,
          thickness: thickness,
          separation: _separationFor(thickness),
          markerHeight: _markerHeightFor(thickness),
          markerBase: _markerBaseFor(thickness),
          radius: thickness / 2,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }

  /// Intervalle entre deux segments détachés, dérivé de l'épaisseur.
  ///
  /// La moitié de l'épaisseur : assez pour que la coupure se voie, assez peu
  /// pour que la file reste lue comme une seule barre.
  static double _separationFor(double thickness) => thickness / 2;

  /// Hauteur du marqueur triangulaire, dérivée de l'épaisseur.
  static double _markerHeightFor(double thickness) => thickness;

  /// Largeur de base du marqueur triangulaire, dérivée de l'épaisseur.
  ///
  /// Le double de sa hauteur : un triangle à sommet droit, assez large pour
  /// rester lisible au-dessus d'un segment étroit.
  static double _markerBaseFor(double thickness) => thickness * 2;

  /// Barre segmentée — un segment `Expanded` par carte (mode « complet »).
  Widget _bar(BuildContext context, ZcrudTheme theme) => Row(
        children: <Widget>[
          for (var i = 0; i < total; i++)
            Expanded(
              child: Padding(
                // Directionnel (invariant AD-13) — jamais `EdgeInsets.only(left:)`.
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

  /// Préfixe de [ValueKey] d'un point, pour la testabilité.
  static const String _dotKeyPrefix = 'zProgressDot_';

  /// Préfixe de [ValueKey] d'un segment de barre, pour la testabilité.
  static const String _segmentKeyPrefix = 'zProgressSegment_';
}

/// Un point de progression (privé).
class _Dot extends StatelessWidget {
  const _Dot({
    required this.color,
    required this.current,
    required this.size,
    required this.activeWidth,
    super.key,
  });

  final Color color;
  final bool current;

  /// Taille d'un point NON courant — la hauteur vaut pour les deux états.
  final Size size;

  /// Largeur du point courant (déjà résolue par la géométrie).
  final double activeWidth;

  @override
  Widget build(BuildContext context) => Container(
        width: current ? activeWidth : size.width,
        height: size.height,
        // Rayon = hauteur : la forme est pleinement arrondie dans les deux
        // états — un cercle quand le point est carré, une pilule quand il est
        // plus large que haut. Aucun rayon n'a donc à être posé.
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.all(Radius.circular(size.height)),
        ),
      );
}

/// Peintre de la barre segmentée à marqueur (privé).
///
/// Un seul passage : pour chaque carte, un segment arrondi détaché de son
/// voisin ; sur la carte courante, un triangle posé au-dessus de son segment.
class _SegmentedMarkerPainter extends CustomPainter {
  const _SegmentedMarkerPainter({
    required this.colors,
    required this.currentIndex,
    required this.thickness,
    required this.separation,
    required this.markerHeight,
    required this.markerBase,
    required this.radius,
    required this.textDirection,
  });

  /// Une couleur par carte, dans l'ordre de la file (déjà résolues par le seam).
  final List<Color> colors;

  /// Index de la carte courante, déjà borné par l'appelant.
  final int currentIndex;

  /// Épaisseur de la barre.
  final double thickness;

  /// Intervalle entre deux segments voisins.
  final double separation;

  /// Hauteur du marqueur triangulaire.
  final double markerHeight;

  /// Largeur de base du marqueur triangulaire.
  final double markerBase;

  /// Rayon des coins d'un segment.
  final double radius;

  /// Sens de lecture — la file démarre du côté du début (invariant AD-13).
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final count = colors.length;
    // Bornes (invariant AD-10) : une file vide, une largeur nulle ou une file
    // si dense que les intervalles mangent toute la place ne font rien peindre
    // — jamais un segment de largeur négative, jamais une exception.
    if (count <= 0 || !size.width.isFinite || size.width <= 0) return;
    final available = size.width - separation * (count - 1);
    if (available <= 0) return;

    final segmentWidth = available / count;
    final top = size.height - thickness;

    for (var i = 0; i < count; i++) {
      final start = i * (segmentWidth + separation);
      // Miroir strict pour le sens droite-à-gauche : le segment d'index 0
      // occupe le bord de DÉBUT, quel qu'il soit. Aucune direction n'est
      // codée en dur.
      final left = textDirection == TextDirection.rtl
          ? size.width - start - segmentWidth
          : start;
      final rect = Rect.fromLTWH(left, top, segmentWidth, thickness);
      final paint = Paint()..color = colors[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        paint,
      );

      if (i != currentIndex) continue;
      // Trois sommets, pas un de plus : un sommet en haut, une base posée sur
      // le bord supérieur du segment.
      final centerX = rect.center.dx;
      canvas.drawPath(
        Path()
          ..moveTo(centerX, top - markerHeight)
          ..lineTo(centerX - markerBase / 2, top)
          ..lineTo(centerX + markerBase / 2, top)
          ..close(),
        paint,
      );
    }
  }

  /// Repeint si — et seulement si — un champ a changé.
  ///
  /// Chaque champ est comparé, la liste de couleurs élément par élément : un
  /// `=> true` inconditionnel repeindrait à chaque frame de l'arbre parent, et
  /// un `=> false` laisserait la barre figée sur la carte précédente.
  @override
  bool shouldRepaint(covariant _SegmentedMarkerPainter oldDelegate) =>
      oldDelegate.currentIndex != currentIndex ||
      oldDelegate.thickness != thickness ||
      oldDelegate.separation != separation ||
      oldDelegate.markerHeight != markerHeight ||
      oldDelegate.markerBase != markerBase ||
      oldDelegate.radius != radius ||
      oldDelegate.textDirection != textDirection ||
      !listEquals(oldDelegate.colors, colors);
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

/// Sens du drag en cours — un enum, jamais un `bool isRight`.
///
/// Aucune sémantique de notation n'y est attachée : le swipe navigue, les
/// deux directions font avancer. Cet enum décrit seulement où va le doigt,
/// pour placer le retour visuel du bon côté — il ne dit ni « réussi » ni
/// « raté ».
///
/// Cette neutralité est une contrainte de rendu, pas une intention : elle
/// n'est tenue que si le glyphe rendu est lui aussi neutre. Un visage
/// souriant ou mécontent la détruirait en réintroduisant une évaluation. Ne
/// pas réintroduire de glyphe évaluatif sous couvert de cet enum.
enum ZSwipeEmotion {
  /// Drag vers le **début** (gauche en LTR).
  towardsStart,

  /// Drag vers la **fin** (droite en LTR).
  towardsEnd,
}

/// Retour émotionnel pendant le drag (présentation pure).
///
/// Sous Reduce Motion, l'animation est réellement dégradée, pas seulement
/// désactivée en apparence :
/// - sans Reduce Motion : opacité et échelle varient continûment avec
///   [offsetPercentage] — l'indicateur suit le doigt ;
/// - avec Reduce Motion : apparition binaire au seuil ([appearThreshold]),
///   opacité et échelle fixes, aucune interpolation.
///
/// La fonction n'est jamais dégradée, seulement l'animation : au-delà du
/// seuil, l'indicateur apparaît toujours, Reduce Motion ou non. Un
/// utilisateur qui refuse les animations ne perd pas le retour visuel — il
/// perd son interpolation.
class ZSwipeEmotionIndicator extends StatelessWidget {
  /// Construit l'indicateur de drag.
  ///
  /// - [offsetPercentage] : offset horizontal du drag en % du seuil (fourni
  ///   tel quel par le `cardBuilder` de la pile) ;
  /// - [reduceMotion] : signal injecté, résolu par `zReduceMotionOf` chez
  ///   l'appelant (primitive unique du dépôt ; ce widget n'en lit pas une
  ///   seconde).
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

  /// Clé du nœud d'opacité, pour la testabilité : un test lit la valeur
  /// résolue sur le widget, il ne la déduit pas.
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

  /// Opacité résolue — continue, ou binaire sous Reduce Motion.
  double get resolvedOpacity {
    if (reduceMotion) {
      // Dégradation réelle : aucune interpolation. La valeur ne dépend plus
      // de l'amplitude, seulement du franchissement du seuil.
      return _magnitude >= appearThreshold ? 1 : 0;
    }
    return _magnitude;
  }

  /// Échelle résolue — continue, ou fixe sous Reduce Motion.
  double get resolvedScale {
    if (reduceMotion) return 1;
    return _minScale + (1 - _minScale) * _magnitude;
  }

  @override
  Widget build(BuildContext context) {
    final emotion = _emotion;
    if (emotion == null) return const SizedBox.shrink();

    // Rôle Material 3 résolu par le cœur — jamais un `Colors.*`/`Color(0x…)`.
    // Les deux sens sont neutres quant à la note : on distingue le sens du
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
      // L'overlay ne doit rien voler à l'arène de gestes : il est purement
      // décoratif et vit au-dessus de la carte.
      child: Align(
        // Directionnel (invariant AD-13) — jamais `Alignment.centerLeft/Right`.
        // L'icône est placée du côté où va le doigt (ce que la dartdoc de
        // [ZSwipeEmotion] annonce).
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
              // Glyphe neutre et directionnel — jamais un visage. Un visage
              // souriant ou mécontent serait une évaluation, un signal
              // strictement plus fort que les couleurs `primary`/`error` déjà
              // écartées ci-dessus pour cette même raison : le swipe navigue
              // et n'écrit aucune note, donc rien ne doit laisser croire à
              // l'apprenant qu'il vient de noter la carte. Une flèche ne dit
              // que où va le doigt, ce qui est exactement — et seulement — ce
              // que cet enum décrit.
              //
              // RTL (invariant AD-13) : `arrow_back`/`arrow_forward` portent
              // `matchTextDirection: true`, donc le glyphe se retourne avec la
              // direction du texte. `towardsEnd` pointe ainsi vers la fin
              // dans les deux directions — un émoji, lui, n'aurait rien
              // retourné du tout.
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
