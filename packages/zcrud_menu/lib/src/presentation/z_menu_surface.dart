/// Surface FLOTTANTE de menu, ouverte à une **position** plutôt que sous un
/// déclencheur visible.
///
/// C'est le pendant, pour le **geste contextuel** (clic droit sur pointeur,
/// appui long sur tactile), de ce que [ZDefaultMenuRenderer] est pour le
/// déclencheur : mêmes entrées, mêmes cellules, **même voie de sélection**
/// ([ZMenuRequest.select]). Un renderer qui n'implémente pas sa propre surface
/// contextuelle hérite de celle-ci : le geste contextuel n'est donc jamais
/// absent, quel que soit le renderer branché.
///
/// Les décisions d'accessibilité sont celles du déclencheur visible, portées
/// par [ZMenuEntryTile] : cible ≥ 48 dp, `Semantics` non dupliquées, motif de
/// désactivation annoncé. Aucune couleur ni chaîne d'interface n'est écrite
/// ici — tout libellé vient de l'appelant, tout style du thème.
library;

import 'package:flutter/material.dart';

import '../domain/z_menu_entry.dart';
import 'z_default_menu_renderer.dart';
import 'z_menu_entry_tile.dart';
import 'z_menu_request.dart';

/// Construit les items Material d'une [request] — colonne d'entrées par
/// défaut, ou **présentation injectée** portée par une entrée nue.
///
/// Partagé par le déclencheur visible et par la surface contextuelle : les
/// deux chemins ne peuvent donc pas diverger (mêmes cellules, mêmes états
/// désactivés, même absence de détecteur superposé).
///
/// [contentBuilder] surcharge celle de la requête : c'est ainsi qu'un renderer
/// impose sa propre présentation (une grille, par exemple) sans priver
/// l'appelant de la sienne.
List<PopupMenuEntry<ZMenuEntry>> zMenuPopupItems(
  ZMenuRequest request, {
  ZMenuContentBuilder? contentBuilder,
}) {
  final builder = contentBuilder ?? request.contentBuilder;
  if (builder != null) {
    return <PopupMenuEntry<ZMenuEntry>>[
      ZMenuPanelEntry(builder: builder, entries: request.entries),
    ];
  }
  return <PopupMenuEntry<ZMenuEntry>>[
    for (final entry in request.entries)
      PopupMenuItem<ZMenuEntry>(
        value: entry,
        enabled: entry.isEnabled,
        // `PopupMenuItem` porte déjà son propre détecteur de geste :
        // `onSelected` de la cellule reste nul (deux détecteurs superposés
        // produiraient DEUX invocations pour un seul tap).
        child: ZMenuEntryTile(entry: entry),
      ),
  ];
}

/// Ouvre la surface du menu à la position globale [globalPosition].
///
/// Ne rend RIEN dans l'arbre de l'appelant : c'est un geste, pas un widget.
/// Retourne quand la surface est refermée ; la sélection éventuelle est
/// invoquée par [ZMenuRequest.select] — l'unique voie d'exécution d'une entrée,
/// celle qui garantit qu'une entrée désactivée ou inconnue reste sans effet.
///
/// Rien à montrer (aucune entrée visible et aucune présentation injectée) ⇒
/// **aucune surface** n'est ouverte, jamais une surface vide ni une levée
/// (invariant AD-10). Idem si l'`Overlay` est introuvable.
Future<void> zShowZMenuAt(
  BuildContext context,
  ZMenuRequest request,
  Offset globalPosition, {
  ZMenuContentBuilder? contentBuilder,
}) async {
  final builder = contentBuilder ?? request.contentBuilder;
  if (request.entries.isEmpty && builder == null) return;
  final overlay = Overlay.maybeOf(context)?.context.findRenderObject();
  if (overlay is! RenderBox) return;
  final selected = await showMenu<ZMenuEntry>(
    context: context,
    // Position DIRECTIONNELLE : `RelativeRect.fromRect` se calcule contre la
    // boîte de l'overlay, et Material la résout selon la directionnalité
    // ambiante — aucun `left:`/`right:` n'est écrit ici (invariant AD-13).
    position: RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    ),
    items: zMenuPopupItems(request, contentBuilder: contentBuilder),
    semanticLabel: request.trigger.semanticLabel,
  );
  if (selected == null) return;
  request.select(selected);
}

/// Entrée UNIQUE portant la présentation **INJECTÉE** du contenu.
///
/// Délibérément un `PopupMenuEntry` **NU**, jamais un `PopupMenuItem` : celui-ci
/// imposerait sa hauteur, son `padding` et son `TextStyle` au sous-arbre de
/// l'hôte, et poserait un `InkWell` qui referme le menu au moindre tap tombé
/// entre deux cellules.
///
/// Offerte aux renderers qui composent leur propre présentation (grille,
/// panneau) tout en gardant la voie de sortie du rendu par défaut.
class ZMenuPanelEntry extends PopupMenuEntry<ZMenuEntry> {
  /// Construit l'entrée de panneau : [builder] rend le contenu, [entries] lui
  /// est transmise (déjà filtrée par la règle d'absence).
  const ZMenuPanelEntry({
    required this.builder,
    required this.entries,
    super.key,
  });

  /// Présentation injectée du contenu.
  final ZMenuContentBuilder builder;

  /// Entrées visibles transmises à [builder].
  final List<ZMenuEntry> entries;

  /// Hauteur d'ESTIMATION du défilement (le contenu se dimensionne lui-même).
  @override
  double get height => kZMenuMinTapTarget;

  /// L'entrée ne représente AUCUNE valeur : aucune surbrillance d'« item
  /// courant » n'est due.
  @override
  bool represents(ZMenuEntry? value) => false;

  @override
  State<ZMenuPanelEntry> createState() => _ZMenuPanelEntryState();
}

class _ZMenuPanelEntryState extends State<ZMenuPanelEntry> {
  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        widget.entries,
        // MÊME chemin de sortie que la colonne par défaut : la valeur poppée
        // est récupérée par l'appelant (`PopupMenuButton.onSelected` ou le
        // retour de `showMenu`), qui appelle `request.select`. Une présentation
        // injectée ne peut donc ni oublier de fermer, ni invoquer deux fois, ni
        // diverger du défaut.
        (entry) => Navigator.of(context).pop(entry),
      );
}
