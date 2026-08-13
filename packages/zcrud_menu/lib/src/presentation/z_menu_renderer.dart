/// Port de **rendu de menu contextuel** — patron strict de
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
/// **Pourquoi ce port existe** — construire le déclencheur en dur (un
/// `PopupMenuButton` codé directement) fige à la fois le geste (appui long,
/// clic droit), la surface (feuille modale, panneau ancré) et le placement :
/// un hôte qui veut autre chose n'a alors qu'une issue, réécrire le menu
/// entier. Un simple slot de contenu injecté n'ouvre que l'**intérieur** de
/// la surface, pas ces trois axes.
///
/// Le défaut zéro-dépendance n'est pas une politesse : un consommateur qui
/// n'injecte rien garde une capacité **fonctionnelle**, jamais absente.
library;

import 'package:flutter/widgets.dart';

import 'z_menu_request.dart';
import 'z_menu_surface.dart';

/// Abstraction de rendu d'un menu à partir d'une [ZMenuRequest] neutre.
///
/// **Contrat que toute implémentation doit tenir** — c'est ce qui les rend
/// interchangeables :
/// 1. **le widget rendu EST le déclencheur** : il occupe la place de l'appelant
///    dans l'arbre et ouvre lui-même sa surface ;
/// 2. **nom accessible** : `request.trigger.semanticLabel` est porté par le
///    déclencheur — exactement une fois (jamais dupliqué par un `Semantics`
///    parent qui FUSIONNERAIT deux annonces en une) ;
/// 3. **voie unique de sélection** : toute sélection passe par
///    [ZMenuRequest.select], jamais par `entry.onSelected` directement ;
/// 4. **entrées désactivées** : rendues présentes, inertes, motif ANNONCÉ ;
/// 5. **a11y (invariant AD-13)** : cibles ≥ 48 dp, variantes directionnelles ;
/// 6. **invariant AD-10** : aucune entrée ne doit faire lever le rendu — une
///    liste vide rend un déclencheur inerte, jamais une exception.
abstract class ZMenuRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZMenuRenderer();

  /// Construit le DÉCLENCHEUR (et, par lui, la surface) de la [request].
  Widget build(BuildContext context, ZMenuRequest request);

  /// Ouvre la MÊME surface **sans déclencheur visible**, à la position globale
  /// [globalPosition] — c'est la voie du geste contextuel (clic droit sur
  /// pointeur, appui long sur tactile), servie par `ZContextMenuRegion`.
  ///
  /// **Implémentation par défaut fournie** : la surface Material du repli
  /// ([zShowZMenuAt]), composée des mêmes cellules que le déclencheur visible.
  /// Un renderer n'a donc rien à écrire pour que le geste contextuel
  /// fonctionne, et reste libre de le redéfinir (feuille modale, panneau
  /// ancré, menu radial) sans que l'appelant change d'un caractère.
  ///
  /// Contrat inchangé : la sélection passe par [ZMenuRequest.select] — jamais
  /// par `entry.onSelected` — et rien à montrer ⇒ **aucune surface** (invariant
  /// AD-10), jamais une levée.
  Future<void> openAt(
    BuildContext context,
    ZMenuRequest request,
    Offset globalPosition,
  ) =>
      zShowZMenuAt(context, request, globalPosition);
}
