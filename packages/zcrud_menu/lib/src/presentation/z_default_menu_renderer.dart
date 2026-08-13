/// [ZDefaultMenuRenderer] — repli SDK, ZÉRO dépendance tierce.
///
/// Ce repli encode des décisions d'accessibilité et de composition non
/// évidentes, reprises ici avec leur motif :
/// * `Semantics(label:) + excludeSemantics: true` sur chaque entrée (porté par
///   [ZMenuEntryTile]) — `PopupMenuItem` FUSIONNE son sous-arbre : sans
///   exclusion le lecteur d'écran annonce l'action DEUX FOIS (« Ouvrir\nOuvrir »)
///   ; retirer le `label:` rend le nœud MUET ;
/// * le contenu injecté est porté par un `PopupMenuEntry` **NU**, jamais un
///   `PopupMenuItem` — celui-ci imposerait sa hauteur, son `padding` et son
///   `TextStyle` au sous-arbre de l'hôte, et poserait un `InkWell` qui ferme le
///   menu au moindre tap tombé entre deux cellules ;
/// * pas de `Semantics(label:)` supplémentaire sur le déclencheur : le `tooltip`
///   de `PopupMenuButton` porte DÉJÀ le nom accessible et `button: true`.
///
/// Capacités offertes au-delà d'un menu d'actions classique :
/// * l'entrée **désactivée avec motif** ([ZMenuEntry.disabledReason]) ;
/// * le glyphe d'entrée **optionnel** ;
/// * le déclencheur porté par un **widget** (`ZMenuTrigger.widget`) ;
/// * un menu **sans entrées mais à contenu injecté** reste ouvrable — c'est la
///   forme d'un sélecteur (date, récurrence, rappel…) dont le contenu n'est
///   pas une liste d'actions ;
/// * une liste vide SANS contenu injecté rend un déclencheur **inerte**, jamais
///   une surface fantôme (invariant AD-10).
///
/// AUCUNE couleur littérale, AUCUNE chaîne d'interface en dur — tout libellé
/// vient de l'appelant, tout style du thème.
library;

import 'package:flutter/material.dart';

import '../domain/z_menu_entry.dart';
import 'z_menu_entry_tile.dart';
import 'z_menu_renderer.dart';
import 'z_menu_request.dart';
import 'z_menu_surface.dart';

/// Repli zéro-dépendance : déclencheur `PopupMenuButton`, surface Material.
class ZDefaultMenuRenderer extends ZMenuRenderer {
  /// Construit le repli (`const` — identité stable pour les scopes).
  const ZDefaultMenuRenderer();

  @override
  Widget build(BuildContext context, ZMenuRequest request) {
    final trigger = request.trigger;
    final contentBuilder = request.contentBuilder;
    final entries = request.entries;
    // Cible ≥ 48 dp garantie sur les DEUX chemins de déclencheur — le chemin
    // `child` (widget hôte) n'a aucune taille minimale propre.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: kZMenuMinTapTarget,
        minHeight: kZMenuMinTapTarget,
      ),
      child: PopupMenuButton<ZMenuEntry>(
        // invariant AD-10 : rien à montrer ⇒ déclencheur INERTE (jamais une
        // surface vide, jamais une levée). Un contenu injecté suffit à donner
        // quelque chose à montrer, même sans aucune entrée (menus SÉLECTEURS).
        enabled: entries.isNotEmpty || contentBuilder != null,
        icon: trigger.child == null ? Icon(trigger.icon) : null,
        // Nom accessible : porté UNE seule fois, par le tooltip (qui fournit
        // aussi `button: true`). `semanticLabel` étant requis et non vide, le
        // déclencheur ne peut pas être muet — y compris hors Material.
        tooltip: trigger.tooltip ?? trigger.semanticLabel,
        // Voie UNIQUE de sélection (contrat ZMenuRenderer, point 3).
        onSelected: request.select,
        // Items composés par le site PARTAGÉ avec la surface contextuelle
        // (`zMenuPopupItems`) : le déclencheur visible et le clic droit ne
        // peuvent pas diverger.
        itemBuilder: (context) => zMenuPopupItems(request),
        child: trigger.child,
      ),
    );
  }
}
