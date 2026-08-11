/// Classe de fenêtre **Material 3** — primitive de mesure PURE.
///
/// [ZWindowSizeClass] classe la largeur de la fenêtre en **trois paliers**
/// (`compact`/`medium`/`expanded`, seuils M3 **600 / 840**) pour piloter un
/// choix de présentation aval (layout, grille adaptative, politique de
/// présentation). C'est un **enum** — l'unique type de classe d'écran
/// exposé : jamais une API `bool isMobile`/`isTablet`/`isDesktop`.
///
/// **Pureté (invariants AD-5, AD-14)** : la résolution
/// [ZWindowSizeClass.fromWidth] est une fonction pure `double →
/// ZWindowSizeClass`, testable **sans `BuildContext`**. Le helper contextuel
/// [ZWindowSizeClass.of] lit la largeur via `MediaQuery.sizeOf` (jamais
/// `Get.width`, invariants AD-2, AD-15) et délègue à la résolution pure.
///
/// **Défaut sûr (invariant AD-10)** : `fromWidth` ne lève **jamais** ; `0`,
/// une largeur négative, `double.nan` retombent sur `compact` ;
/// `double.infinity` donne `expanded`.
///
/// **Coexistence M3 ↔ Bootstrap** : cette table M3 (600/840, 3 paliers)
/// **coexiste délibérément** avec la table Bootstrap
/// (`ZResponsiveBreakpoints` de `zcrud_core` : 576/768/992/1200, 5 paliers)
/// portée par `ZBreakpoint` / [ZBreakpointValue]. Elles sont sémantiquement
/// distinctes — l'une **classe la fenêtre** pour un choix de présentation,
/// l'autre porte une **valeur d'authoring par palier fin** — et ne se
/// remplacent pas.
library;

import 'package:flutter/widgets.dart';

/// Seuils de largeur (dp) Material 3 des [ZWindowSizeClass].
///
/// `compact < 600 ≤ medium < 840 ≤ expanded`. Constantes **centralisées** ici
/// (nom neuf, aucune collision avec `ZResponsiveBreakpoints` du cœur qui porte
/// 576/768/992/1200) — les nombres `600`/`840` ne sont redéclarés nulle part
/// ailleurs dans le package.
abstract final class ZWindowSizeThresholds {
  /// Largeur minimale (dp) de la classe `medium` (largeur ≥ 600 dp).
  static const double mediumMinWidth = 600;

  /// Largeur minimale (dp) de la classe `expanded` (largeur ≥ 840 dp).
  static const double expandedMinWidth = 840;
}

/// Palier de largeur de fenêtre Material 3 (valeurs **camelCase**).
///
/// UI-pure, **non sérialisé** ⇒ aucun `@JsonKey`. Si une sérialisation
/// devenait nécessaire, l'enum devrait alors porter
/// `@JsonKey(unknownEnumValue:)` (invariant AD-10).
enum ZWindowSizeClass {
  /// Fenêtre compacte : largeur `< 600` dp (téléphone portrait). Défaut sûr.
  compact,

  /// Fenêtre moyenne : `600 ≤` largeur `< 840` dp (téléphone paysage /
  /// tablette portrait).
  medium,

  /// Fenêtre étendue : largeur `≥ 840` dp (tablette paysage / desktop).
  expanded;

  /// Résout la classe de fenêtre depuis une [width] (dp) — **pure**,
  /// déterministe, **testable sans `BuildContext`**, **ne lève jamais**
  /// (invariant AD-10).
  ///
  /// - `width < 600` → [compact] (inclut `0`, négatif, `double.nan` : toute
  ///   comparaison `NaN >= seuil` est `false` ⇒ retombée naturelle sur
  ///   [compact]) ;
  /// - `600 ≤ width < 840` → [medium] ;
  /// - `width ≥ 840` → [expanded] (inclut `double.infinity`).
  static ZWindowSizeClass fromWidth(double width) {
    if (width >= ZWindowSizeThresholds.expandedMinWidth) {
      return ZWindowSizeClass.expanded;
    }
    if (width >= ZWindowSizeThresholds.mediumMinWidth) {
      return ZWindowSizeClass.medium;
    }
    return ZWindowSizeClass.compact;
  }

  /// Dérive la classe de fenêtre depuis un [context].
  ///
  /// Lit la largeur **toujours** via `MediaQuery.sizeOf(context)` (et non
  /// `MediaQuery.of(context).size`, pour ne se réabonner qu'à la **taille**) puis
  /// délègue à [fromWidth] — jamais `Get.width`/`MediaQueryData` figée, jamais
  /// d'import de gestionnaire d'état (invariants AD-2, AD-15). Directionnellement neutre
  /// (correct sous `Directionality.rtl`, invariant AD-13).
  static ZWindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}
