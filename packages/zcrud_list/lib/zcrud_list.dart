/// Barrel d'API publique de `zcrud_list`.
///
/// `DynamicList` (dans `zcrud_core`) derrière le port `ZListRenderer` ; ce
/// package fournit le backend concret Syncfusion `ZSfDataGridRenderer`
/// (invariant AD-8). L'import de `package:zcrud_core/zcrud_core.dart` par le
/// renderer matérialise l'arête AD-1 `zcrud_list → zcrud_core`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_sf_data_grid_renderer.dart';
