import 'package:flutter/widgets.dart';

import '../domain/z_window_size_class.dart';

/// Aiguilleur de disposition responsive **piloté par [ZWindowSizeClass]** mesurée
/// sur la **largeur LOCALE du conteneur** (EX-UI.2, AD-31/D1).
///
/// [ZResponsiveLayout] enveloppe son rendu dans un `LayoutBuilder`, dérive la
/// classe d'écran via `ZWindowSizeClass.fromWidth(constraints.maxWidth)` — la
/// largeur allouée **au conteneur immédiat**, **jamais** `MediaQuery.sizeOf`
/// (écran global) ni `Get.width` — puis invoque **le seul** builder du palier
/// retenu. Mesurer le conteneur (et non la fenêtre) donne la bonne disposition en
/// **split-view**, **master-detail**, **bottom-sheet partiel** ou toute colonne
/// d'une `Row`, où la largeur du widget diffère de la largeur écran.
///
/// **Trois builders, cascade descendante (AD-10/D2)** : [compact] est **REQUIS**
/// (plancher garanti) ; [medium] et [expanded] sont optionnels et **retombent**
/// vers le palier inférieur quand ils sont absents (`expanded → medium → compact`,
/// `medium → compact`). La cascade est **strictement descendante** : elle ne
/// remonte jamais et, `compact` étant requis, il existe **toujours** un builder à
/// invoquer — **jamais** d'écran vide.
///
/// **Enums > booléens (NFR-U7)** : la sélection délègue **entièrement** à l'enum
/// `ZWindowSizeClass` ; aucun `bool isMobile/isTablet/isDesktop`, aucun seuil
/// `600`/`840` n'est redéclaré ici.
///
/// **Sans état, RTL-neutre (AD-2/AD-15/AD-13)** : `StatelessWidget` pur — aucun
/// gestionnaire d'état/routeur, aucun `setState`. La sélection ne dépend que de
/// `constraints.maxWidth` (grandeur directionnellement neutre) : elle est
/// **identique** sous `Directionality.ltr` et `.rtl` à largeur égale.
///
/// **Builders paresseux** : le type est [WidgetBuilder] (`Widget Function(
/// BuildContext)`), **jamais** un `Widget` pré-construit — seul le sous-arbre du
/// palier retenu est instancié (aligné rebuild ciblé, AD-25).
class ZResponsiveLayout extends StatelessWidget {
  /// Crée un aiguilleur responsive. Seul [compact] est requis ; [medium] et
  /// [expanded] retombent en cascade descendante s'ils sont omis.
  const ZResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  /// Builder du palier **compact** (largeur locale `< 600` dp). **REQUIS** —
  /// plancher de la cascade, garantit qu'aucun palier ne retombe sur du vide
  /// (défaut sûr, AD-10).
  final WidgetBuilder compact;

  /// Builder du palier **medium** (`600 ≤ w < 840` dp). Optionnel : absent, le
  /// palier medium **retombe** sur [compact] (cascade descendante).
  final WidgetBuilder? medium;

  /// Builder du palier **expanded** (`w ≥ 840` dp). Optionnel : absent, le palier
  /// expanded **retombe** sur [medium] s'il est fourni, sinon sur [compact]
  /// (cascade descendante).
  final WidgetBuilder? expanded;

  /// Résout le builder à invoquer pour [cls] par **cascade descendante** — jamais
  /// `null`, jamais de remontée. Aucun seuil de largeur ici (délégué à
  /// `ZWindowSizeClass.fromWidth`).
  WidgetBuilder _builderFor(ZWindowSizeClass cls) {
    switch (cls) {
      case ZWindowSizeClass.expanded:
        return expanded ?? medium ?? compact;
      case ZWindowSizeClass.medium:
        return medium ?? compact;
      case ZWindowSizeClass.compact:
        return compact;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cls = ZWindowSizeClass.fromWidth(constraints.maxWidth);
        return _builderFor(cls)(context);
      },
    );
  }
}
