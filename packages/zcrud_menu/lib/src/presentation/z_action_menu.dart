/// [ZActionMenu] — le point d'entrée unique du menu contextuel.
///
/// L'appelant DÉCLARE ses entrées et son déclencheur ; le rendu est résolu par
/// [zResolveMenuRenderer] (chaîne totale : paramètre → scope → repli SDK).
/// Aucun gestionnaire d'état (invariants AD-2/AD-15) : ce widget est
/// `StatelessWidget` et ne détient rien.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_menu_entry.dart';
import '../domain/z_menu_trigger.dart';
import 'z_menu_renderer.dart';
import 'z_menu_request.dart';
import 'z_menu_scope.dart';

/// Menu contextuel à déclencheur et contenu DÉCOUPLÉS.
class ZActionMenu extends StatelessWidget {
  /// Construit le menu.
  ///
  /// [entries] : entrées candidates, ordre PRÉSERVÉ. La règle d'absence
  /// (invariant AD-4) leur est appliquée ICI, une seule fois, avant tout
  /// renderer.
  ///
  /// [trigger] : description du déclencheur (jamais un widget construit par
  /// l'appelant — c'est ce qui le rend substituable).
  ///
  /// [contentBuilder] : présentation INJECTÉE du contenu (`null` ⇒ celle du
  /// renderer).
  ///
  /// [renderer] : surcharge PONCTUELLE du renderer, prioritaire sur [ZMenuScope]
  /// (utile pour un écran isolé ou un test). `null` ⇒ scope, puis repli.
  const ZActionMenu({
    required this.entries,
    required this.trigger,
    this.contentBuilder,
    this.renderer,
    super.key,
  });

  /// Entrées candidates (celles ni actionnables ni désactivées sont ABSENTES).
  final List<ZMenuEntry> entries;

  /// Description du déclencheur.
  final ZMenuTrigger trigger;

  /// Présentation INJECTÉE du contenu (`null` ⇒ celle du renderer).
  final ZMenuContentBuilder? contentBuilder;

  /// Surcharge ponctuelle du renderer (prioritaire sur le scope).
  final ZMenuRenderer? renderer;

  @override
  Widget build(BuildContext context) {
    // Filtrage AMONT, site UNIQUE (invariant AD-4) : la liste transmise au
    // renderer est déjà filtrée ; la règle lui est INOPPOSABLE, il ne peut ni
    // la contourner ni la ré-implémenter de travers.
    final visible = zVisibleMenuEntries(entries);
    return zResolveMenuRenderer(context, override: renderer).build(
      context,
      ZMenuRequest(
        trigger: trigger,
        entries: visible,
        contentBuilder: contentBuilder,
        // Voie de sélection UNIQUE, fabriquée par le site partagé
        // (`zMenuSelectFor`) : le déclencheur visible et le menu contextuel
        // (`ZContextMenuRegion`) empruntent exactement le même chemin, avec la
        // même résolution d'entrée périmée.
        select: zMenuSelectFor(visible),
      ),
    );
  }
}
