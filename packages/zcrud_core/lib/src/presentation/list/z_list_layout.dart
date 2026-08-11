/// Variantes de **vue** sélectionnables de `DynamicList` (AD-8).
///
/// `ZListLayout` est un sélecteur `sealed` à **trois** variantes : `dataGrid`
/// (délègue au backend `SfDataGrid` de `zcrud_list`), `builder` (rendu
/// `ListView.builder` **dans le cœur**, Material-free) et `custom` (widget
/// arbitraire fourni par l'app). Les vues `builder`/`custom` se rendent
/// **entièrement dans `zcrud_core`** et n'exigent AUCUN `ZListRenderer`
/// injecté — preuve exécutable qu'une liste se rend **sans Syncfusion**.
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
/// est exhaustif **sans branche `default`**. Un satellite n'ajoute jamais une 4ᵉ
/// variante (les rendus concrets passent par un `ZListRenderer` ou `custom`).
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

/// Vue **personnalisée** : rend un widget **arbitraire** fourni par l'app à
/// partir du `ZListRenderRequest` complet. N'exige AUCUN renderer.
final class ZListCustomLayout extends ZListLayout {
  /// Construit la vue personnalisée avec son [customView].
  const ZListCustomLayout({required this.customView});

  /// Construit le widget de liste à partir de la requête neutre complète.
  final Widget Function(BuildContext context, ZListRenderRequest request)
      customView;
}
