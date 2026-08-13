/// Barrel d'API publique de `zcrud_list`.
///
/// `DynamicList` (dans `zcrud_core`) derrière le port `ZListRenderer` ; ce
/// package fournit le backend concret Syncfusion `ZSfDataGridRenderer`
/// (invariant AD-8). L'import de `package:zcrud_core/zcrud_core.dart` par le
/// renderer matérialise l'arête AD-1 `zcrud_list → zcrud_core`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

/// Mode de répartition des largeurs de colonnes, ré-exporté **du strict
/// nécessaire** : c'est le seul type venu de Syncfusion qui apparaisse dans la
/// signature publique du paquet (`ZSfDataGridRenderer.columnWidthMode`,
/// `ZSfDataGridRenderer.responsiveColumnWidthMode`, `ZSfColumnSizing.widthMode`).
///
/// Sans cette ré-exportation, figer la largeur — `columnWidthMode:
/// ColumnWidthMode.fill` — obligerait l'application à déclarer elle-même une
/// dépendance sur `syncfusion_flutter_datagrid`, alors que l'intérêt du paquet
/// est justement de rester la **seule** arête Syncfusion du graphe (AD-8).
///
/// Rien d'autre n'est ré-exporté : les types de rendu Syncfusion
/// (`SfDataGrid`, `DataGridRow`, `GridColumn`…) restent internes, et les
/// réglages du renderer passent par les modèles neutres du paquet
/// (`ZSfCellStyle`, `ZSfStackedHeader`, `ZSfColumnSizing`).
export 'package:syncfusion_flutter_datagrid/datagrid.dart'
    show ColumnWidthMode;

export 'src/presentation/z_sf_data_grid_renderer.dart';
export 'src/presentation/z_sf_grid_customization.dart';
