import 'package:flutter/widgets.dart';

import '../domain/compute_cross_axis_count.dart';

/// Grille d'items **adaptative** dont le nombre de colonnes est calculé par la
/// fonction pure [computeCrossAxisCount] à partir de la **largeur LOCALE** du
/// conteneur (mesurée par un `LayoutBuilder`), garantissant **au moins 1
/// colonne** et gardant le cas `children` vide.
///
/// **Nom `ZAdaptiveGrid` — JAMAIS `ZResponsiveGrid`** (AD-31) : `ZResponsiveGrid`
/// est réservé à la grille **12 colonnes de formulaire** de `zcrud_core`. Cette
/// grille-ci dispose des **cartes d'items** (une colonne par tranche de
/// [minItemWidth]), notion distincte.
///
/// **Largeur LOCALE (AD-31 / D2)** : `availableWidth = constraints.maxWidth` du
/// `LayoutBuilder` — **jamais** `Get.width`, **jamais** `MediaQuery.sizeOf` /
/// `MediaQuery.of(context).size` (écran global). Mesurer le conteneur (et non la
/// fenêtre) donne le bon nombre de colonnes en **split-view**, **master-detail**,
/// **bottom-sheet partiel** ou toute colonne d'une `Row`.
///
/// **Garde vide (AD-10)** : `children` vide → `const SizedBox.shrink()` **avant**
/// tout `LayoutBuilder`/`GridView` — jamais de grille fantôme ni de division par
/// zéro.
///
/// **Aspect déduit (D4)** : les items s'étirent pour remplir la largeur (largeur
/// d'item déduite `itemWidth = (maxWidth − spacing·(n − 1)) / n`). Si [itemHeight]
/// est fourni (`> 0`), `childAspectRatio = itemWidth / itemHeight` ; sinon
/// `aspectRatio ?? 1.0`.
///
/// **Sans état, RTL-neutre (AD-2 / AD-15 / AD-13)** : `StatelessWidget` pur —
/// aucun gestionnaire d'état/routeur, aucun `setState`. [padding] est
/// `EdgeInsetsGeometry?` (accepte `EdgeInsetsDirectional`) ; le nombre de colonnes
/// est **identique** sous `Directionality.ltr` et `.rtl` à largeur égale.
///
/// **Rendu paresseux (NFR-U4)** : `GridView.builder` (`itemCount` +
/// `itemBuilder`) — jamais `GridView.count(children:)`/`GridView(children:)`. La
/// grille ne scrolle pas d'elle-même (`shrinkWrap` + `NeverScrollableScrollPhysics`) :
/// c'est le parent qui scrolle.
///
/// ## Deux constructeurs, une seule mécanique (SU-8/D3)
///
/// * [ZAdaptiveGrid] (`children:`) — **historique, inchangé**. Lazy au *rendu*
///   mais **EAGER à la construction** : l'appelant matérialise **tous** les
///   widgets d'abord, et `shrinkWrap` + `NeverScrollableScrollPhysics` font
///   layouter **tout** (aucun culling de viewport). Convient à un **petit
///   nombre** d'items imbriqués dans un parent scrollable.
/// * [ZAdaptiveGrid.builder] (`itemCount`/`itemBuilder`) — **SU-8/AC2**, pour
///   les collections **volumineuses** (des milliers de cartes, NFR-SU9) : la
///   grille **scrolle d'elle-même** et ne construit que le viewport.
///
/// Les deux partagent **la même** primitive de colonnes ([computeCrossAxisCount]),
/// **la même** garde vide et **les mêmes** replis AD-10 : `build` est un **corps
/// unique** paramétré par `virtualized` — jamais deux branches de calcul. La
/// **seule** divergence est le couple `shrinkWrap`/`physics` (qui scrolle : le
/// parent, ou la grille). Vérifié par « les DEUX ctors donnent le MÊME nombre de
/// colonnes » (`z_adaptive_grid_test.dart`).
class ZAdaptiveGrid extends StatelessWidget {
  /// Crée une grille adaptative. Seuls [children] et [minItemWidth] sont requis.
  ///
  /// ⚠️ **EAGER** : [children] est matérialisé en entier par l'appelant, et la
  /// grille layoute **tout** (`shrinkWrap`, parent scrollable). Pour une
  /// collection volumineuse, préférer [ZAdaptiveGrid.builder] (NFR-SU9).
  const ZAdaptiveGrid({
    required this.children,
    required this.minItemWidth,
    this.spacing = 8.0,
    this.runSpacing,
    this.itemHeight,
    this.aspectRatio,
    this.minColumns = 1,
    this.maxColumns,
    this.padding,
    super.key,
  })  : _itemCount = null,
        _itemBuilder = null;

  /// Crée une grille adaptative **VIRTUALISÉE** (SU-8/AC2 — NFR-SU9).
  ///
  /// Construit **à la demande** ([itemBuilder] n'est appelé que pour les items
  /// du viewport, ≪ [itemCount]) et **scrolle d'elle-même** : ni `shrinkWrap`,
  /// ni `NeverScrollableScrollPhysics` — c'est la surface scrollable.
  ///
  /// Réutilise **à l'identique** [computeCrossAxisCount], la garde vide
  /// (`itemCount <= 0 → SizedBox.shrink()`) et les replis AD-10 du ctor
  /// historique : « jamais une grille réécrite » reste **vrai** (même widget,
  /// même primitive de colonnes).
  ///
  /// [itemCount] `<= 0` ⇒ `SizedBox.shrink()` (AD-10, jamais de throw).
  const ZAdaptiveGrid.builder({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required this.minItemWidth,
    this.spacing = 8.0,
    this.runSpacing,
    this.itemHeight,
    this.aspectRatio,
    this.minColumns = 1,
    this.maxColumns,
    this.padding,
    super.key,
  })  : _itemCount = itemCount,
        _itemBuilder = itemBuilder,
        // Les deux modes sont mutuellement exclusifs **PAR CONSTRUCTION** (deux
        // constructeurs distincts) — jamais par un `assert` runtime (AD-10).
        children = const <Widget>[];

  /// Items à disposer (ctor historique). **Vide → `SizedBox.shrink()`** (garde
  /// AD-10). Reste `const <Widget>[]` avec [ZAdaptiveGrid.builder].
  final List<Widget> children;

  /// Nombre d'items du mode **virtualisé**, ou `null` en mode [children]
  /// (SU-8/AC2). Privé : le mode est un détail d'implémentation, la surface
  /// publique reste les deux constructeurs.
  final int? _itemCount;

  /// Constructeur d'item du mode **virtualisé**, ou `null` en mode [children].
  final IndexedWidgetBuilder? _itemBuilder;

  /// Largeur minimale d'un item (dp) : pilote le nombre de colonnes
  /// (`largeur locale / minItemWidth`, borné). Remplace le ternaire `300/350`
  /// codé en dur d'iffd/dodlp.
  final double minItemWidth;

  /// Espacement **inter-colonnes** (dp), aussi défaut de l'espacement
  /// **inter-lignes** si [runSpacing] est `null`.
  final double spacing;

  /// Espacement **inter-lignes** (dp). `null` → reprend [spacing].
  final double? runSpacing;

  /// Hauteur cible d'un item (dp). Fournie (`> 0`) → `childAspectRatio` recalculé
  /// sur la largeur d'item déduite ; sinon repli sur [aspectRatio].
  final double? itemHeight;

  /// Ratio largeur/hauteur explicite des items. **Ignoré si [itemHeight] fourni**
  /// (`> 0`). `null` → `1.0`.
  final double? aspectRatio;

  /// Plancher de colonnes (**remonté à 1** si `< 1`, AD-10).
  final int minColumns;

  /// Plafond de colonnes. `null` → illimité (borne haute pratique = `floor`).
  final int? maxColumns;

  /// Marge interne de la grille — `EdgeInsetsGeometry?` (accepte
  /// `EdgeInsetsDirectional`, RTL-safe AD-13).
  final EdgeInsetsGeometry? padding;

  /// Item du mode [children] — **tear-off d'instance**, jamais une closure
  /// réallouée à chaque build (stabilité d'identité, AD-2/SM-1).
  Widget _childAt(BuildContext context, int index) => children[index];

  @override
  Widget build(BuildContext context) {
    // Mode VIRTUALISÉ (`.builder`) ou HISTORIQUE (`children:`) — une seule
    // mécanique en dessous (aucune branche de calcul dupliquée).
    final bool virtualized = _itemBuilder != null;
    final int count = _itemCount ?? children.length;
    final IndexedWidgetBuilder itemBuilder = _itemBuilder ?? _childAt;

    // Garde vide AD-10 **PARTAGÉE** : jamais de LayoutBuilder/GridView fantôme.
    // `<= 0` (et non `== 0`) : un `itemCount` négatif fourni par un appelant est
    // absorbé ici, jamais propagé au delegate (qui lèverait).
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Padding horizontal résolu **directionnellement** (AC9 / AD-13) : il est
        // retranché de la largeur pour le calcul des colonnes ET de la largeur
        // d'item, mais reste appliqué au GridView pour l'espace visuel (jamais
        // double-compté).
        final double horizontalPadding =
            padding?.resolve(Directionality.of(context)).horizontal ?? 0;

        final int n = computeCrossAxisCount(
          availableWidth: constraints.maxWidth,
          minItemWidth: minItemWidth,
          minColumns: minColumns,
          maxColumns: maxColumns,
          spacing: spacing,
          horizontalPadding: horizontalPadding,
        );

        // Largeur d'item déduite sur la MÊME base cohérente que le calcul des
        // colonnes (largeur utile = maxWidth − padding horizontal ; les items
        // remplissent la largeur, gouttières comprises, pas de reste).
        final double effectiveWidth = constraints.maxWidth - horizontalPadding;
        final double rawItemWidth =
            (effectiveWidth - spacing * (n - 1)) / n;
        // AD-10 (défensif, jamais de throw) : `spacing > minItemWidth` (n ≥ 2 →
        // largeur négative) ou une contrainte infinie peuvent produire une largeur
        // ≤ 0 / non finie qui violerait l'assertion `childAspectRatio > 0` du
        // delegate. On retombe alors sur `minItemWidth`.
        final double itemWidth =
            (rawItemWidth.isFinite && rawItemWidth > 0) ? rawItemWidth : minItemWidth;

        final double? height = itemHeight;
        double ratio = (height != null && height > 0)
            ? itemWidth / height
            : (aspectRatio ?? 1.0);
        // Plancher défensif ultime : le delegate exige `childAspectRatio > 0` fini
        // (AD-10) — couvre aussi un `aspectRatio`/`minItemWidth` dégénéré fourni.
        if (!ratio.isFinite || ratio <= 0) ratio = 1.0;

        return GridView.builder(
          // 🔴 SU-8/AC2 — LA seule différence entre les deux modes.
          // `children:` : shrinkWrap + physics figées (le PARENT scrolle) —
          //   contrat historique, INCHANGÉ (zéro régression).
          // `.builder`  : la grille est la surface SCROLLABLE ⇒ le viewport
          //   cull réellement les items (NFR-SU9). `shrinkWrap: true` ici
          //   layouterait TOUT et tuerait la virtualisation.
          shrinkWrap: !virtualized,
          physics: virtualized ? null : const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: count,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: runSpacing ?? spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: ratio,
          ),
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
