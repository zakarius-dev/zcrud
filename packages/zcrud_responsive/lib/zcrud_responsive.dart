/// Barrel d'API publique de `zcrud_responsive`.
///
/// Infrastructure UI **responsive transverse** (epic EX-UI). Contenu :
/// * [ZWindowSizeClass] (EX-UI.1) : classe de fenêtre **Material 3** en **enum**
///   (3 paliers, seuils 600/840) — l'unique type de classe d'écran (aucun `bool`
///   isMobile/isTablet/isDesktop, NFR-U7) ;
/// * [ZBreakpointValue] (EX-UI.1) : valeur générique `T` **par breakpoint fin**,
///   cascade mobile-first, bâtie **sur** l'enum `ZBreakpoint` (5 paliers Bootstrap)
///   de `zcrud_core` ;
/// * [ZResponsiveLayout] (EX-UI.2) : aiguilleur à 3 builders (compact/medium/
///   expanded) en cascade descendante, mesure **locale** via `LayoutBuilder` ;
/// * [computeCrossAxisCount] + [ZAdaptiveGrid] (EX-UI.3) : nombre de colonnes borné
///   (**clamp ≥ 1** — anti-bug iffd) et grille d'items par largeur-min ;
/// * [ZReorderableAdaptiveGrid] (CR-IFFD-15) : la MÊME grille, **réordonnable**
///   par appui long (+ actions sémantiques a11y), autoscroll de bord, ordre
///   LINÉAIRE inter-lignes — bâtie **sur** [ZAdaptiveGrid] (donc sur
///   [computeCrossAxisCount]) et **sur le seul SDK** (aucun paquet tiers, AD-1).
///
/// **Dépendance (AD-29 AMENDÉ — réconciliation E3-4, Option A)** : ce package
/// **dépend de `zcrud_core`** et **RÉUTILISE** ses primitives responsives —
/// l'enum `ZBreakpoint` (axe de [ZBreakpointValue]) et `ZResponsiveBreakpoints`
/// (table de seuils Bootstrap, utilisée par [ZBreakpointValue.resolve]). ⛔ Ces
/// symboles **restent définis dans `zcrud_core`** et ne sont **JAMAIS**
/// redéclarés ici. Ils sont **ré-exportés par confort** ci-dessous (un seul import
/// pour le consommateur) ; leur source de vérité demeure `zcrud_core`.
///
/// **Coexistence des deux échelles (D2/D3)** : la table **M3** (600/840, 3
/// paliers, [ZWindowSizeClass]) et la table **Bootstrap** (576/768/992/1200, 5
/// paliers, `ZBreakpoint`/`ZResponsiveBreakpoints`) **coexistent délibérément** —
/// notions orthogonales (classer la fenêtre vs porter une valeur d'authoring par
/// palier fin), aucune ne remplace l'autre.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Ré-export de CONFORT (les symboles restent DÉFINIS dans `zcrud_core`, jamais
// redéclarés) : évite au consommateur d'importer les deux barrels pour l'usage
// courant de [ZBreakpointValue] (axe `ZBreakpoint`, résolution largeur via
// `ZResponsiveBreakpoints`). `ZResponsiveSpan` (le `ZBreakpointValue<int>` borné
// du moteur d'édition) est inclus pour cohérence.
export 'package:zcrud_core/zcrud_core.dart'
    show ZBreakpoint, ZResponsiveBreakpoints, ZResponsiveSpan;

// Primitives de mesure PURES neuves (domaine, sans `BuildContext`) :
// EX-UI.1 [ZWindowSizeClass] + [ZBreakpointValue] ; EX-UI.3 [computeCrossAxisCount]
// (nombre de colonnes borné, clamp ≥ 1 — anti-bug iffd).
export 'src/domain/compute_cross_axis_count.dart';
export 'src/domain/z_breakpoint_value.dart';
export 'src/domain/z_window_size_class.dart';

// Widgets responsives (présentation, mesure LOCALE via `LayoutBuilder`) :
// EX-UI.2 [ZResponsiveLayout] (3 builders, cascade descendante) ;
// EX-UI.3 [ZAdaptiveGrid] (grille d'items par largeur-min, garde vide→shrink).
export 'src/presentation/z_adaptive_grid.dart';
// AD-57 — repli ZERO-DEPENDANCE du port `ZReorderRenderer` (defini dans
// zcrud_core). C'est le plancher garanti : un hote qui n'installe aucun
// satellite garde une capacite fonctionnelle.
export 'src/presentation/z_default_reorder_renderer.dart';
export 'src/presentation/z_reorderable_adaptive_grid.dart';
export 'src/presentation/z_responsive_layout.dart';
