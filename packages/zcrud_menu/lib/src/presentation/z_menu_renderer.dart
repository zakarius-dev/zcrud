/// Port de **rendu de menu contextuel** (CHAT-4) — patron strict de
/// `ZListRenderer` / `ZReorderRenderer` / `ZDropRegionRenderer` (`zcrud_core`).
///
/// `zcrud_menu` n'expose que cette abstraction plus un repli SDK. Les
/// implémentations lourdes vivent ailleurs :
///
/// | Implémentation | Paquet | Dépendance tirée |
/// |---|---|---|
/// | repli SDK maison | `zcrud_menu` ([ZDefaultMenuRenderer]) | aucune |
/// | paquet de l'écosystème | satellite adaptateur, opt-in | le paquet tiers |
/// | propre à l'hôte | l'application | ce qu'elle veut |
///
/// **Pourquoi ce port existe** — le socle construisait le déclencheur EN DUR :
/// `PopupMenuButton` dans `ZItemActionsMenu` (`zcrud_study`), dans
/// `_OverflowMenu` (`zcrud_core`) et dans le débordement de `ZPageShell`
/// (`zcrud_ui_kit`). Le slot `menuBuilder` de `ZItemActionsMenu` n'ouvre que le
/// contenu **à l'intérieur** de la surface Material : ni le geste (appui long,
/// clic droit), ni la surface (feuille modale, panneau ancré), ni le placement
/// ne sont substituables. Un hôte qui voulait autre chose n'avait qu'une issue —
/// réécrire le menu entier, ce que lex_douane fait effectivement
/// (`packages/lex_ui/.../study_item_actions_menu.dart`).
///
/// Le défaut zéro-dépendance n'est pas une politesse (AD-57) : un consommateur
/// qui n'injecte rien garde une capacité **fonctionnelle**, jamais absente.
library;

import 'package:flutter/widgets.dart';

import 'z_menu_request.dart';

/// Abstraction de rendu d'un menu à partir d'une [ZMenuRequest] neutre.
///
/// **Contrat que toute implémentation doit tenir** — c'est ce qui les rend
/// interchangeables :
/// 1. **le widget rendu EST le déclencheur** : il occupe la place de l'appelant
///    dans l'arbre et ouvre lui-même sa surface ;
/// 2. **nom accessible** : `request.trigger.semanticLabel` est porté par le
///    déclencheur — exactement une fois (jamais dupliqué par un `Semantics`
///    parent qui FUSIONNERAIT, leçon SU-8/AC20) ;
/// 3. **voie unique de sélection** : toute sélection passe par
///    [ZMenuRequest.select], jamais par `entry.onSelected` directement ;
/// 4. **entrées désactivées** : rendues présentes, inertes, motif ANNONCÉ ;
/// 5. **a11y (AD-13)** : cibles ≥ 48 dp, variantes directionnelles ;
/// 6. **AD-10** : aucune entrée ne doit faire lever le rendu — une liste vide
///    rend un déclencheur inerte, jamais une exception.
abstract class ZMenuRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZMenuRenderer();

  /// Construit le DÉCLENCHEUR (et, par lui, la surface) de la [request].
  Widget build(BuildContext context, ZMenuRequest request);
}
