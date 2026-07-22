/// **zcrud_reorder** — implémentation OPT-IN du port `ZReorderRenderer`
/// (`zcrud_core`) adossée au paquet `reorderable_grid_view` de l'écosystème
/// pub.dev (AD-57).
///
/// ## Ce que ce barrel expose — et ce qu'il n'expose PAS
///
/// Il n'expose **qu'un renderer** : [ZPackageReorderRenderer]. **Aucun** type de
/// `reorderable_grid_view` n'apparaît ici ni dans une signature publique — c'est
/// la condition 2 d'AD-57 (« le tiers est une implémentation du port, jamais le
/// type public que l'hôte manipule »). L'hôte continue de ne connaître que
/// `ZReorderRenderer` / `ZReorderRenderRequest`.
///
/// ## Installer ce paquet est un CHOIX, jamais une obligation
///
/// Le port a un **défaut zéro-dépendance** (`ZDefaultReorderRenderer`, dans
/// `zcrud_responsive`). Ne pas installer `zcrud_reorder` laisse donc une
/// capacité **fonctionnelle**, seulement dégradée. Les deux implémentations sont
/// **interchangeables** : même convention d'index linéaires, même voie
/// accessible non-gestuelle, même repli AD-10 — verrouillé par
/// `test/interchangeability_test.dart`.
///
/// ## Usage
///
/// ```dart
/// ZcrudScope(
///   reorderRenderer: const ZPackageReorderRenderer(),
///   child: MyApp(),
/// )
/// ```
library;

export 'src/presentation/z_package_reorder_renderer.dart'
    show
        ZPackageReorderRenderer,
        kDefaultMoveBeforeLabel,
        kDefaultMoveAfterLabel;
