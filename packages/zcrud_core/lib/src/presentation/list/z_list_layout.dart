/// Variantes de **vue** sélectionnables de `DynamicList` (AD-8).
///
/// `ZListLayout` est un sélecteur `sealed` à **quatre** variantes : `dataGrid`
/// (délègue au backend `SfDataGrid` de `zcrud_list`), `builder` (rendu
/// `ListView.builder` **dans le cœur**, Material-free), `grid` (grille de
/// cartes **responsive** rendue `GridView.builder` **dans le cœur**, sans
/// dépendance tierce) et `custom` (widget arbitraire fourni par l'app). Les
/// vues `builder`/`grid`/`custom` se rendent **entièrement dans `zcrud_core`**
/// et n'exigent AUCUN `ZListRenderer` injecté — preuve exécutable qu'une liste
/// (verticale OU en grille de cartes) se rend **sans Syncfusion**.
///
/// **Neutre** : imports limités à `package:flutter/widgets.dart` + contrat neutre
/// `ZListRenderRequest`/`ZListRow`/`ZListColumn`. AUCUN `package:syncfusion`.
library;

import 'package:flutter/widgets.dart';

import '../../domain/contracts/z_entity.dart';
import 'z_list_column.dart';
import 'z_list_render_request.dart';

/// Construit la tuile d'une ligne à partir de la [ZListRow] **neutre** et des
/// colonnes dérivées.
///
/// C'est la forme historique : la tuile ne voit que les cellules brutes de la
/// ligne. Pour rendre une **carte métier** (qui a besoin de l'objet, pas de
/// ses cellules), préférer [ZEntityTileBuilder].
typedef ZRowTileBuilder = Widget Function(
  BuildContext context,
  ZListRow row,
  List<ZListColumn> columns,
);

/// Construit la tuile d'une ligne à partir de l'**entité `T` résolue** et des
/// colonnes dérivées.
///
/// C'est la forme à privilégier pour une **grille de cartes métier** : la carte
/// reçoit directement l'objet qu'elle affiche (`Consignee`, `Declaration`…) au
/// lieu d'un sac de cellules à re-décoder. L'entité est résolue par le seam
/// `DynamicList.entityFor` (`ZListRow → T?`) : une ligne dont l'entité reste
/// introuvable retombe sur la tuile de ligne du layout, s'il en porte une.
typedef ZEntityTileBuilder<T extends ZEntity> = Widget Function(
  BuildContext context,
  T entity,
  List<ZListColumn> columns,
);

/// Adapte un [ZEntityTileBuilder] typé `T` en builder de surface `ZEntity`.
///
/// La surface stockée par les layouts est **volontairement effacée**
/// (`ZEntityTileBuilder<ZEntity>`) : les variantes de `ZListLayout` restent
/// non génériques, donc `const`, donc utilisables sans paramètre de type par
/// un hôte qui n'en a pas besoin. Le typage revient au point d'usage par cet
/// adaptateur, qui **ne lève jamais** (AD-10) : une entité d'un autre type que
/// `T` rend une tuile vide au lieu d'une exception de cast.
ZEntityTileBuilder<ZEntity> zAdaptEntityTile<T extends ZEntity>(
  ZEntityTileBuilder<T> builder,
) =>
    (BuildContext context, ZEntity entity, List<ZListColumn> columns) =>
        entity is T
            ? builder(context, entity, columns)
            : const SizedBox.shrink();

/// Sélecteur **fermé** de la variante de rendu de `DynamicList`.
///
/// `sealed` (fermé, intra-package) : le `switch` de dispatch dans `DynamicList`
/// est exhaustif **sans branche `default`**. Un satellite n'ajoute jamais de
/// variante supplémentaire (les rendus concrets passent par un `ZListRenderer`
/// ou `custom`).
sealed class ZListLayout {
  /// Constructeur `const` de base.
  const ZListLayout();

  /// Retourne la variante **portant la tuile typée** [builder] — le rendu
  /// reçoit alors l'entité `T` résolue au lieu de la seule `ZListRow`.
  ///
  /// C'est le canal par lequel un **assembleur** (`ZCrudScreen`) fait
  /// descendre la tuile typée déclarée par l'application jusqu'au layout que
  /// cette même application a choisi, sans que l'un ait à connaître l'autre.
  ///
  /// Règles, valables pour toutes les variantes :
  /// * une variante qui ne rend **pas** de tuiles (`dataGrid`, `custom`)
  ///   retourne `this` — rien à porter ;
  /// * une variante qui porte **déjà** sa propre tuile (`itemBuilder` déclaré
  ///   explicitement par l'hôte) retourne `this` : l'explicite l'emporte sur
  ///   l'injecté, le rendu déclaré ne change jamais sous les pieds de l'hôte ;
  /// * sinon, une **copie** portant [builder] est retournée (l'objet courant
  ///   reste immuable).
  ZListLayout withEntityTiles<T extends ZEntity>(
    ZEntityTileBuilder<T> builder,
  ) =>
      this;
}

/// Vue **DataGrid** (défaut) : délègue au `ZListRenderer` injecté (backend
/// `SfDataGrid` de `zcrud_list`) en lui passant le `ZListRenderRequest`
/// **à colonnes dérivées**.
final class ZListDataGridLayout extends ZListLayout {
  /// Construit la vue DataGrid (`const`, sans état).
  const ZListDataGridLayout();
}

/// Vue **liste** : rend un `ListView.builder` **dans le cœur** (Material-free),
/// une entrée par ligne. N'exige AUCUN renderer.
///
/// Deux façons de décrire l'entrée, au choix :
/// * [itemBuilder] — la ligne neutre (`ZListRow` + colonnes) ;
/// * [entityBuilder] — l'**entité résolue**, forme typée obtenue par
///   [ZListBuilderLayout.forEntity] ou posée par un assembleur via
///   [withEntityTiles].
///
/// Quand les deux sont présents, [entityBuilder] l'emporte tant que l'entité
/// de la ligne est résolue (seam `DynamicList.entityFor`) ; sinon le rendu
/// retombe sur [itemBuilder]. Aucun des deux ⇒ entrée vide : la vue attend
/// alors qu'un assembleur lui pose sa tuile.
final class ZListBuilderLayout extends ZListLayout {
  /// Construit la vue liste avec sa tuile de ligne et/ou sa tuile d'entité.
  const ZListBuilderLayout({this.itemBuilder, this.entityBuilder});

  /// Construit la vue liste avec une tuile **typée** recevant l'entité `T`.
  ///
  /// ```dart
  /// ZListBuilderLayout.forEntity<Consignee>(
  ///   (context, consignee, columns) => ConsigneeTile(consignee),
  /// )
  /// ```
  static ZListBuilderLayout forEntity<T extends ZEntity>(
    ZEntityTileBuilder<T> tileBuilder,
  ) =>
      ZListBuilderLayout(entityBuilder: zAdaptEntityTile<T>(tileBuilder));

  /// Construit le widget d'une ligne à partir de la [ZListRow] et des colonnes
  /// dérivées (`List<ZListColumn>`). `null` ⇒ aucune tuile de ligne.
  final ZRowTileBuilder? itemBuilder;

  /// Construit le widget d'une ligne à partir de l'**entité résolue** —
  /// prioritaire sur [itemBuilder]. `null` ⇒ aucune tuile d'entité.
  final ZEntityTileBuilder<ZEntity>? entityBuilder;

  @override
  ZListLayout withEntityTiles<T extends ZEntity>(
    ZEntityTileBuilder<T> builder,
  ) =>
      itemBuilder != null || entityBuilder != null
          ? this
          : ZListBuilderLayout(entityBuilder: zAdaptEntityTile<T>(builder));
}

/// Vue **grille** : rend une **grille de cartes responsive** `GridView.builder`
/// **dans le cœur** (virtualisée, sans dépendance tierce — une grille de cartes
/// ne demande pas un DataGrid). N'exige AUCUN renderer.
///
/// Le nombre de colonnes est **dérivé de la largeur disponible** via
/// `SliverGridDelegateWithMaxCrossAxisExtent` : chaque tuile occupe au plus
/// [maxCrossAxisExtent] de large (une colonne sur téléphone, plusieurs sur
/// tablette/desktop, sans configuration par point de rupture). Le rendu est
/// **directionnel** (la grille suit le `TextDirection` ambiant — RTL inclus)
/// et ne porte aucune couleur : la carte est entièrement l'affaire de
/// [itemBuilder] (thème via `ZcrudScope`/`Theme.of(context)`).
///
/// La hauteur des tuiles se règle par [mainAxisExtent] (hauteur fixe,
/// prioritaire) ou [childAspectRatio] (ratio largeur/hauteur, défaut `1.0`).
///
/// La carte se décrit au choix par [itemBuilder] (ligne neutre) ou par
/// [entityBuilder] (**entité résolue** — forme typée via
/// [ZListGridLayout.forEntity], ou posée par un assembleur via
/// [withEntityTiles]). Une carte métier veut presque toujours la seconde :
///
/// ```dart
/// ZListGridLayout.forEntity<Consignee>(
///   (context, consignee, columns) => ConsigneeCard(consignee),
///   mainAxisExtent: 180,
/// )
/// ```
final class ZListGridLayout extends ZListLayout {
  /// Construit la vue grille avec sa tuile de ligne et/ou sa tuile d'entité.
  const ZListGridLayout({
    this.itemBuilder,
    this.entityBuilder,
    this.maxCrossAxisExtent = 360,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
    this.padding,
    this.maxColumns,
  }) : assert(
          maxColumns == null || maxColumns >= 1,
          'ZListGridLayout.maxColumns doit être >= 1.',
        );

  /// Construit la vue grille avec une carte **typée** recevant l'entité `T` ;
  /// la géométrie (extent, espacements, plafond de colonnes) est celle du
  /// constructeur principal.
  static ZListGridLayout forEntity<T extends ZEntity>(
    ZEntityTileBuilder<T> tileBuilder, {
    double maxCrossAxisExtent = 360,
    double mainAxisSpacing = 8,
    double crossAxisSpacing = 8,
    double childAspectRatio = 1.0,
    double? mainAxisExtent,
    EdgeInsetsGeometry? padding,
    int? maxColumns,
  }) =>
      ZListGridLayout(
        entityBuilder: zAdaptEntityTile<T>(tileBuilder),
        maxCrossAxisExtent: maxCrossAxisExtent,
        mainAxisSpacing: mainAxisSpacing,
        crossAxisSpacing: crossAxisSpacing,
        childAspectRatio: childAspectRatio,
        mainAxisExtent: mainAxisExtent,
        padding: padding,
        maxColumns: maxColumns,
      );

  /// Construit le widget (la **carte**) d'une ligne à partir de la [ZListRow]
  /// et des colonnes dérivées (`List<ZListColumn>`). `null` ⇒ aucune carte de
  /// ligne (la grille attend alors [entityBuilder]).
  final ZRowTileBuilder? itemBuilder;

  /// Construit la **carte** d'une ligne à partir de l'**entité résolue** —
  /// prioritaire sur [itemBuilder] dès que l'entité de la ligne est connue
  /// (seam `DynamicList.entityFor`). `null` ⇒ aucune carte d'entité.
  final ZEntityTileBuilder<ZEntity>? entityBuilder;

  /// Largeur **maximale** d'une tuile (dp) — pilote la responsivité : nombre
  /// de colonnes = largeur disponible ÷ [maxCrossAxisExtent], arrondi au
  /// supérieur (défaut `360`).
  final double maxCrossAxisExtent;

  /// Espacement vertical entre tuiles (défaut `8`).
  final double mainAxisSpacing;

  /// Espacement horizontal entre tuiles (défaut `8`).
  final double crossAxisSpacing;

  /// Ratio largeur/hauteur des tuiles (défaut `1.0`) — ignoré si
  /// [mainAxisExtent] est fourni.
  final double childAspectRatio;

  /// Hauteur **fixe** des tuiles (dp) ; `null` (défaut) = hauteur dérivée de
  /// [childAspectRatio].
  final double? mainAxisExtent;

  /// Marge intérieure de la grille (`EdgeInsetsGeometry` — préférer
  /// `EdgeInsetsDirectional`, AD-13) ; `null` = aucune.
  final EdgeInsetsGeometry? padding;

  /// **Plafond** optionnel du nombre de colonnes dérivé de
  /// [maxCrossAxisExtent] : sur un écran très large, la grille cesse
  /// d'ajouter des colonnes au-delà de [maxColumns] — les tuiles s'élargissent
  /// alors au-delà de [maxCrossAxisExtent] pour occuper la largeur
  /// (équivalent du motif legacy `(largeur / extent).clamp(1, N)`).
  ///
  /// `null` (défaut) = aucun plafond, comportement antérieur inchangé
  /// (colonnes illimitées, dérivées de la seule largeur disponible).
  final int? maxColumns;

  @override
  ZListLayout withEntityTiles<T extends ZEntity>(
    ZEntityTileBuilder<T> builder,
  ) =>
      itemBuilder != null || entityBuilder != null
          ? this
          : ZListGridLayout(
              entityBuilder: zAdaptEntityTile<T>(builder),
              maxCrossAxisExtent: maxCrossAxisExtent,
              mainAxisSpacing: mainAxisSpacing,
              crossAxisSpacing: crossAxisSpacing,
              childAspectRatio: childAspectRatio,
              mainAxisExtent: mainAxisExtent,
              padding: padding,
              maxColumns: maxColumns,
            );
}

/// Résout l'entité `T` d'une ligne neutre ; `null` si la ligne n'en a pas
/// (ou si aucun résolveur n'a été déclaré sur `DynamicList.entityFor`).
typedef ZEntityResolver<T extends ZEntity> = T? Function(ZListRow row);

/// Construit une vue de liste **entière** à partir de la requête neutre et du
/// résolveur d'entités de la liste.
///
/// C'est la forme typée de [ZListCustomLayout] : la vue reçoit, en plus de
/// [ZListRenderRequest], le même `entityFor` que celui qui sert aux actions de
/// ligne et aux tuiles typées — elle n'a jamais à reconstruire l'index
/// `ligne → entité`.
typedef ZEntityListViewBuilder<T extends ZEntity> = Widget Function(
  BuildContext context,
  ZListRenderRequest request,
  ZEntityResolver<T> entityFor,
);

/// Vue **personnalisée** : rend un widget **arbitraire** fourni par l'app à
/// partir du `ZListRenderRequest` complet. N'exige AUCUN renderer.
///
/// Deux façons de décrire la vue, au choix :
/// * [customView] — la requête neutre seule (lignes + colonnes dérivées) ;
/// * [entityView] — la requête **et** le résolveur `ZListRow → entité`
///   (forme typée via [ZListCustomLayout.forEntity]). Prioritaire sur
///   [customView] quand les deux sont présents.
///
/// Une vue personnalisée n'a pas de tuile : [withEntityTiles] la rend
/// inchangée. Le rendu d'un écran assemblé (`ZCrudScreen.itemBuilder`) ne
/// descend donc pas dans cette variante — c'est la vue qui décide de tout.
final class ZListCustomLayout extends ZListLayout {
  /// Construit la vue personnalisée avec [customView] et/ou [entityView] —
  /// au moins l'un des deux.
  const ZListCustomLayout({this.customView, this.entityView})
      : assert(
          customView != null || entityView != null,
          'ZListCustomLayout exige customView ou entityView.',
        );

  /// Construit la vue personnalisée **typée** : [view] reçoit le résolveur
  /// `ZListRow → T?` de la liste.
  ///
  /// Le résolveur **ne lève jamais** (AD-10) : une entité d'un autre type que
  /// `T` est résolue `null`, comme une ligne inconnue.
  ///
  /// ```dart
  /// ZListCustomLayout.forEntity<Consignee>(
  ///   (context, request, entityFor) => ConsigneeBoard(
  ///     consignees: request.rows.map(entityFor).nonNulls.toList(),
  ///   ),
  /// )
  /// ```
  static ZListCustomLayout forEntity<T extends ZEntity>(
    ZEntityListViewBuilder<T> view,
  ) =>
      ZListCustomLayout(
        entityView: (context, request, entityFor) => view(
          context,
          request,
          (row) {
            final entity = entityFor(row);
            return entity is T ? entity : null;
          },
        ),
      );

  /// Construit le widget de liste à partir de la requête neutre complète.
  /// `null` ⇒ la vue est décrite par [entityView].
  final Widget Function(BuildContext context, ZListRenderRequest request)?
      customView;

  /// Construit le widget de liste à partir de la requête neutre **et** du
  /// résolveur d'entités — prioritaire sur [customView]. `null` ⇒ la vue est
  /// décrite par [customView].
  final ZEntityListViewBuilder<ZEntity>? entityView;
}
