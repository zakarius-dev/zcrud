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

import 'z_list_column.dart';
import 'z_list_render_request.dart';

/// Sélecteur **fermé** de la variante de rendu de `DynamicList`.
///
/// `sealed` (fermé, intra-package) : le `switch` de dispatch dans `DynamicList`
/// est exhaustif **sans branche `default`**. Un satellite n'ajoute jamais de
/// variante supplémentaire (les rendus concrets passent par un `ZListRenderer`
/// ou `custom`).
sealed class ZListLayout {
  /// Constructeur `const` de base.
  const ZListLayout();
}

/// Vue **DataGrid** (défaut) : délègue au `ZListRenderer` injecté (backend
/// `SfDataGrid` de `zcrud_list`) en lui passant le `ZListRenderRequest`
/// **à colonnes dérivées**.
final class ZListDataGridLayout extends ZListLayout {
  /// Construit la vue DataGrid (`const`, sans état).
  const ZListDataGridLayout();
}

/// Vue **liste** : rend un `ListView.builder` **dans le cœur** (Material-free),
/// une entrée par ligne construite par [itemBuilder]. N'exige AUCUN renderer.
final class ZListBuilderLayout extends ZListLayout {
  /// Construit la vue liste avec son [itemBuilder].
  const ZListBuilderLayout({required this.itemBuilder});

  /// Construit le widget d'une ligne à partir de la [ZListRow] et des colonnes
  /// dérivées (`List<ZListColumn>`).
  final Widget Function(BuildContext context, ZListRow row,
      List<ZListColumn> columns) itemBuilder;
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
final class ZListGridLayout extends ZListLayout {
  /// Construit la vue grille avec son [itemBuilder].
  const ZListGridLayout({
    required this.itemBuilder,
    this.maxCrossAxisExtent = 360,
    this.mainAxisSpacing = 8,
    this.crossAxisSpacing = 8,
    this.childAspectRatio = 1.0,
    this.mainAxisExtent,
    this.padding,
  });

  /// Construit le widget (la **carte**) d'une ligne à partir de la [ZListRow]
  /// et des colonnes dérivées (`List<ZListColumn>`).
  final Widget Function(BuildContext context, ZListRow row,
      List<ZListColumn> columns) itemBuilder;

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
}

/// Vue **personnalisée** : rend un widget **arbitraire** fourni par l'app à
/// partir du `ZListRenderRequest` complet. N'exige AUCUN renderer.
final class ZListCustomLayout extends ZListLayout {
  /// Construit la vue personnalisée avec son [customView].
  const ZListCustomLayout({required this.customView});

  /// Construit le widget de liste à partir de la requête neutre complète.
  final Widget Function(BuildContext context, ZListRenderRequest request)
      customView;
}
