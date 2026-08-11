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
        // UNIQUE site d'invocation de l'effet, pour TOUS les renderers. Un
        // renderer (y compris un adaptateur tiers) ne peut pas exécuter une
        // entrée désactivée ni une entrée qu'il aurait fabriquée lui-même : la
        // garde est ici, pas dans sa bonne volonté.
        //
        // On RÉSOUT l'entrée dans la liste COURANTE, puis on invoque l'effet
        // de CELLE-LÀ — jamais celui porté par la valeur reçue.
        //
        // Pourquoi pas `visible.contains(entry)` : `ZMenuEntry.==` compare
        // `onSelected`, donc une IDENTITÉ DE CLOSURE. Or une surface flottante
        // capture la valeur de l'entrée à l'OUVERTURE et lit le callback de
        // sélection à la SÉLECTION ; tout hôte déclarant `onSelected: () =>
        // faire(x)` — le patron normal — en refabrique à chaque rebuild. Un
        // simple rebuild pendant que le menu est ouvert rendait donc l'entrée
        // « non contenue » et AVALAIT la sélection SANS AUCUNE TRACE : le no-op
        // silencieux que l'invariant AD-4 proscrit, entré par la porte de
        // derrière du garde-fou censé le prévenir.
        //
        // Ce que la résolution garde intact : une entrée FABRIQUÉE par un
        // renderer ne peut toujours pas imposer son effet (c'est l'effet
        // DÉCLARÉ par l'appelant qui s'exécute), et une entrée inconnue ou
        // désactivée reste sans effet.
        select: (entry) => _resoudre(visible, entry)?.onSelected?.call(),
      ),
    );
  }

  /// Retrouve dans [visible] l'entrée que désigne [recue], ou `null`.
  ///
  /// Deux passes, dans cet ordre :
  /// 1. **identité** — le cas courant (aucun rebuild n'est survenu) ;
  /// 2. **`id` + `label`** — l'identité DÉCLARÉE de l'entrée, stable au
  ///    rebuild là où la closure ne l'est pas. `id` seul ne suffirait pas :
  ///    la liste des identités est OUVERTE et un hôte peut réutiliser
  ///    `'custom'` sur plusieurs entrées.
  static ZMenuEntry? _resoudre(List<ZMenuEntry> visible, ZMenuEntry recue) {
    for (final e in visible) {
      if (identical(e, recue)) return e;
    }
    for (final e in visible) {
      if (e.id == recue.id && e.label == recue.label) return e;
    }
    return null;
  }
}
