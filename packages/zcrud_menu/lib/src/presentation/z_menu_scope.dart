/// Couture d'injection du [ZMenuRenderer] — chaîne **TOTALE** (CHAT-4).
///
/// Patron strict de `zResolveGradient` (`zcrud_core`, `z_gradient_resolver.dart`) :
/// `paramètre appelant → scope hôte → repli`. Aucune levée, aucun
/// déréférencement nul possible — scope absent ou renderer absent rendent tous
/// deux [ZDefaultMenuRenderer].
///
/// 🔴 **Pourquoi un scope LOCAL et non `ZcrudScope.menuRenderer`.** Les seams de
/// rendu du dépôt (`listRenderer`, `reorderRenderer`, `dropRegionRenderer`)
/// vivent sur `ZcrudScope`, dans `zcrud_core`. Ce serait le foyer naturel — et
/// c'est ce qu'il faudra faire le jour où le cœur voudra lui-même déléguer un
/// menu. Ce n'est PAS fait ici, pour une raison de périmètre d'écriture, pas de
/// conception : ce lot n'a pas le droit d'écrire `zcrud_core`. La conséquence
/// est ASSUMÉE et nommée plutôt que masquée :
/// * un hôte qui injecte déjà ses renderers via `ZcrudScope` doit poser **un
///   second widget**, [ZMenuScope], au lieu d'un paramètre de plus ;
/// * `ZBatchActionBar` (`zcrud_core`) ne peut pas consommer cette couture.
/// La migration vers `ZcrudScope.menuRenderer` sera **additive** : [zResolveMenuRenderer]
/// est le seul site de résolution, un maillon s'y insère sans toucher les appelants.
library;

import 'package:flutter/widgets.dart';

import 'z_default_menu_renderer.dart';
import 'z_menu_renderer.dart';

/// Repli du dépôt : Material/SDK seul, ZÉRO dépendance tierce (AD-57).
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
/// celui du repli — c'est l'invariant de **neutralité** du lot : brancher
/// `zcrud_menu` sans rien configurer ne change rien à ce qu'un hôte voit.
///
/// ⚠️ Limite explicite, IDENTIQUE à celle de `zResolveGradient` : une exception
/// levée PAR LE RENDERER DE L'HÔTE se propage — elle n'est pas avalée. Un
/// renderer qui lève est un défaut de l'hôte ; l'étouffer le rendrait
/// indébogable, et protéger cette couture seule ferait DIVERGER les garanties de
/// deux seams voisines. La totalité promise porte sur la LOGIQUE DE LA CHAÎNE,
/// pas sur le code arbitraire que l'hôte y branche.
ZMenuRenderer zResolveMenuRenderer(
  BuildContext context, {
  ZMenuRenderer? override,
}) =>
    override ?? ZMenuScope.maybeOf(context)?.renderer ?? zFallbackMenuRenderer;
