/// Couture d'injection du [ZMenuRenderer] — chaîne **TOTALE**.
///
/// `paramètre appelant → scope hôte → repli`. Aucune levée, aucun
/// déréférencement nul possible — scope absent ou renderer absent rendent tous
/// deux [ZDefaultMenuRenderer].
///
/// **Pourquoi un scope LOCAL et non `ZcrudScope.menuRenderer`.** Les autres
/// seams de rendu du dépôt (`listRenderer`, `reorderRenderer`,
/// `dropRegionRenderer`) vivent sur `ZcrudScope`, dans `zcrud_core`. Ce
/// paquet ne peut pas y écrire (invariant AD-1 : le cœur ne dépend d'aucun
/// satellite), d'où un scope dédié plutôt qu'un paramètre supplémentaire sur
/// `ZcrudScope`. La conséquence est assumée : un hôte qui injecte déjà ses
/// renderers via `ZcrudScope` doit poser **un second widget**,
/// [ZMenuScope]. Une éventuelle migration vers `ZcrudScope.menuRenderer`
/// resterait **additive** : [zResolveMenuRenderer] est le seul site de
/// résolution, un maillon s'y insère sans toucher les appelants.
library;

import 'package:flutter/widgets.dart';

import 'z_default_menu_renderer.dart';
import 'z_menu_renderer.dart';

/// Repli du dépôt : Material/SDK seul, ZÉRO dépendance tierce.
///
/// `const` : c'est ce qui rend [ZMenuScope.updateShouldNotify] (comparaison
/// d'identité) stable quand aucun hôte n'injecte.
const ZMenuRenderer zFallbackMenuRenderer = ZDefaultMenuRenderer();

/// Scope d'injection du renderer de menus.
///
/// Conserver le [renderer] `const` ou mémoïsé HORS de `build` : la comparaison
/// se fait par identité (même règle que `ZcrudScope`).
class ZMenuScope extends InheritedWidget {
  /// Construit le scope.
  const ZMenuScope({
    required this.renderer,
    required super.child,
    super.key,
  });

  /// Renderer injecté par l'hôte.
  final ZMenuRenderer renderer;

  /// Scope le plus proche, ou `null` (jamais une levée).
  static ZMenuScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZMenuScope>();

  @override
  bool updateShouldNotify(ZMenuScope oldWidget) =>
      !identical(renderer, oldWidget.renderer);
}

/// Chaîne **totale** : [override] → [ZMenuScope] → [zFallbackMenuRenderer].
///
/// Ne rend JAMAIS `null`, ne lève JAMAIS. Sans aucune injection, le rendu est
/// celui du repli — c'est l'invariant de **neutralité** de cette couture :
/// brancher `zcrud_menu` sans rien configurer ne change rien à ce qu'un hôte
/// voit.
///
/// Limite explicite : une exception levée PAR LE RENDERER DE L'HÔTE se
/// propage — elle n'est pas avalée. Un renderer qui lève est un défaut de
/// l'hôte ; l'étouffer le rendrait indébogable. La totalité promise porte
/// sur la LOGIQUE DE LA CHAÎNE de résolution, pas sur le code arbitraire que
/// l'hôte y branche.
ZMenuRenderer zResolveMenuRenderer(
  BuildContext context, {
  ZMenuRenderer? override,
}) =>
    override ?? ZMenuScope.maybeOf(context)?.renderer ?? zFallbackMenuRenderer;
