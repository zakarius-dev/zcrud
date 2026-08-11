/// Barrel d'API publique de `zcrud_responsive`.
///
/// Infrastructure UI **responsive transverse**. Contenu :
/// * [ZWindowSizeClass] : classe de fenêtre **Material 3** en **enum**
///   (3 paliers, seuils 600/840) — l'unique type de classe d'écran (aucun
///   `bool` isMobile/isTablet/isDesktop) ;
/// * [ZBreakpointValue] : valeur générique `T` **par breakpoint fin**,
///   cascade mobile-first, bâtie **sur** l'enum `ZBreakpoint` (5 paliers
///   Bootstrap) de `zcrud_core` ;
/// * [ZResponsiveLayout] : aiguilleur à 3 builders (compact/medium/
///   expanded) en cascade descendante, mesure **locale** via `LayoutBuilder` ;
/// * [computeCrossAxisCount] + [ZAdaptiveGrid] : nombre de colonnes borné
///   (**clamp ≥ 1**) et grille d'items par largeur-min ;
/// * [ZReorderableAdaptiveGrid] : la MÊME grille, **réordonnable** par appui
///   long (+ actions sémantiques a11y), autoscroll de bord, ordre LINÉAIRE
///   inter-lignes — bâtie **sur** [ZAdaptiveGrid] (donc sur
///   [computeCrossAxisCount]) et **sur le seul SDK** (aucun paquet tiers,
///   invariant AD-1).
///
/// **Dépendance** : ce package **dépend de `zcrud_core`** et **réutilise**
/// ses primitives responsives — l'enum `ZBreakpoint` (axe de
/// [ZBreakpointValue]) et `ZResponsiveBreakpoints` (table de seuils
/// Bootstrap, utilisée par [ZBreakpointValue.resolve]). Ces symboles
/// **restent définis dans `zcrud_core`** et ne sont **jamais** redéclarés
/// ici : ils sont **ré-exportés par confort** ci-dessous (un seul import
/// pour le consommateur), leur source de vérité demeure `zcrud_core`.
///
/// **Coexistence des deux échelles** : la table **M3** (600/840, 3 paliers,
/// [ZWindowSizeClass]) et la table **Bootstrap** (576/768/992/1200, 5
/// paliers, `ZBreakpoint`/`ZResponsiveBreakpoints`) **coexistent
/// délibérément** — notions orthogonales (classer la fenêtre vs porter une
/// valeur d'authoring par palier fin), aucune ne remplace l'autre.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Ré-export de confort (les symboles restent DÉFINIS dans `zcrud_core`,
// jamais redéclarés) : évite au consommateur d'importer les deux barrels
// pour l'usage courant de [ZBreakpointValue] (axe `ZBreakpoint`, résolution
// largeur via `ZResponsiveBreakpoints`). `ZResponsiveSpan` (le
// `ZBreakpointValue<int>` borné du moteur d'édition) est inclus pour
// cohérence.
export 'package:zcrud_core/zcrud_core.dart'
    show ZBreakpoint, ZResponsiveBreakpoints, ZResponsiveSpan;

// Primitives de mesure PURES (domaine, sans `BuildContext`) :
// [ZWindowSizeClass] + [ZBreakpointValue] ; [computeCrossAxisCount] (nombre
// de colonnes borné, clamp ≥ 1).
export 'src/domain/compute_cross_axis_count.dart';
export 'src/domain/z_breakpoint_value.dart';
export 'src/domain/z_window_size_class.dart';

// Widgets responsives (présentation, mesure LOCALE via `LayoutBuilder`) :
// [ZResponsiveLayout] (3 builders, cascade descendante) ; [ZAdaptiveGrid]
// (grille d'items par largeur-min, garde vide → shrink).
export 'src/presentation/z_adaptive_grid.dart';
// Repli zéro-dépendance du port `ZReorderRenderer` (défini dans
// `zcrud_core`) : c'est le plancher garanti — un hôte qui n'installe aucun
// satellite garde une capacité fonctionnelle.
export 'src/presentation/z_default_reorder_renderer.dart';
export 'src/presentation/z_reorderable_adaptive_grid.dart';
export 'src/presentation/z_responsive_layout.dart';
