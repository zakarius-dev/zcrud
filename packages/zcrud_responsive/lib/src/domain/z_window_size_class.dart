/// Classe de fenêtre **Material 3** (EX-UI.1, AD-31) — primitive de mesure PURE.
///
/// [ZWindowSizeClass] classe la largeur de la fenêtre en **trois paliers**
/// (`compact`/`medium`/`expanded`, seuils M3 **600 / 840**) pour piloter un choix
/// de présentation aval (layout EX-UI.2, grille adaptative EX-UI.3, politique de
/// présentation EX-UI.5). C'est un **enum** — l'UNIQUE type de classe d'écran
/// exposé : aucune API `bool isMobile/isTablet/isDesktop` (NFR-U7, « enums >
/// booléens »).
///
/// **Pureté (AD-5/AD-14/NFR-U6)** : la résolution [ZWindowSizeClass.fromWidth]
/// est une fonction pure `double → ZWindowSizeClass`, testable **sans
/// `BuildContext`**. Le helper contextuel [ZWindowSizeClass.of] lit la largeur via
/// `MediaQuery.sizeOf` (jamais `Get.width` — AD-31/AD-2/AD-15) et délègue à la
/// résolution pure.
///
/// **Défaut sûr (AD-10/NFR-U10)** : `fromWidth` ne lève **jamais** ; `0`, une
/// largeur négative, `double.nan` retombent sur `compact` ; `double.infinity`
/// donne `expanded`.
///
/// **Coexistence M3 ↔ Bootstrap (D2/D3)** : cette table M3 (600/840, 3 paliers)
/// **coexiste délibérément** avec la table Bootstrap (`ZResponsiveBreakpoints` de
/// `zcrud_core` : 576/768/992/1200, 5 paliers) portée par `ZBreakpoint` /
/// [ZBreakpointValue]. Elles sont sémantiquement distinctes — l'une **classe la
/// fenêtre** pour un choix de présentation, l'autre porte une **valeur
/// d'authoring par palier fin** — et ne se remplacent pas.
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
/// UI-pure, **non sérialisé** (D6) ⇒ aucun `@JsonKey`. Si une sérialisation
/// devenait nécessaire, l'enum devrait alors porter `@JsonKey(unknownEnumValue:)`
/// (AD-10) — hors périmètre de cette story.
enum ZWindowSizeClass {
  /// Fenêtre compacte : largeur `< 600` dp (téléphone portrait). **Défaut sûr.**
  compact,

  /// Fenêtre moyenne : `600 ≤` largeur `< 840` dp (téléphone paysage / tablette
  /// portrait).
  medium,

  /// Fenêtre étendue : largeur `≥ 840` dp (tablette paysage / desktop).
  expanded;

  /// Résout la classe de fenêtre depuis une [width] (dp) — **PURE**, déterministe,
  /// **testable sans `BuildContext`**, **ne lève jamais** (AD-10/D4).
  ///
  /// - `width < 600` → [compact] (inclut `0`, négatif, `double.nan` : toute
  ///   comparaison `NaN >= seuil` est `false` ⇒ retombée naturelle sur [compact]) ;
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
  /// d'import de gestionnaire d'état (NFR-U2/AD-2/AD-15). Directionnellement neutre
  /// (correct sous `Directionality.rtl` — AD-13/NFR-U4).
  static ZWindowSizeClass of(BuildContext context) =>
      fromWidth(MediaQuery.sizeOf(context).width);
}
