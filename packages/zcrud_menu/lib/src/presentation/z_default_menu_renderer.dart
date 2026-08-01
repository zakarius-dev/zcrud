/// [ZDefaultMenuRenderer] — repli SDK, ZÉRO dépendance tierce (AD-57, CHAT-4).
///
/// 🔴 **Ce repli est un PORT FIDÈLE de `ZItemActionsMenu`**
/// (`packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart`), pas
/// une paraphrase appauvrie. Les décisions qui y ont été payées cher sont
/// REPRISES telles quelles, avec leur motif :
/// * `Semantics(label:) + excludeSemantics: true` sur chaque entrée (porté par
///   [ZMenuEntryTile]) — `PopupMenuItem` FUSIONNE son sous-arbre : sans exclusion
///   le lecteur d'écran annonce l'action DEUX FOIS (« Ouvrir\nOuvrir », mesuré
///   SU-8/AC20) ; retirer le `label:` rend le nœud MUET ;
/// * le contenu injecté est porté par un `PopupMenuEntry` **NU**, jamais un
///   `PopupMenuItem` — celui-ci imposerait sa hauteur, son `padding` et son
///   `TextStyle` au sous-arbre de l'hôte, et poserait un `InkWell` qui ferme le
///   menu au moindre tap tombé entre deux cellules ;
/// * pas de `Semantics(label:)` supplémentaire sur le déclencheur : le `tooltip`
///   de `PopupMenuButton` porte DÉJÀ le nom accessible et `button: true`.
///
/// Ce qu'il ajoute par rapport à `ZItemActionsMenu` :
/// * l'entrée **désactivée avec motif** ([ZMenuEntry.disabledReason]) ;
/// * le glyphe d'entrée **optionnel** ;
/// * le déclencheur porté par un **widget** (`ZMenuTrigger.widget`) ;
/// * un menu **sans entrées mais à contenu injecté** reste ouvrable — c'est la
///   forme des sélecteurs de menu d'IFFD (`task_due_date_picker.dart`,
///   `recurrence_picker.dart`, `task_reminder_picker.dart`,
///   `event_reminders_widget.dart` — LECTURE SEULE), dont le contenu n'est pas
///   une liste d'actions ;
/// * une liste vide SANS contenu injecté rend un déclencheur **inerte**, jamais
///   une surface fantôme (AD-10).
///
/// FR-26/NFR-S7 : AUCUNE couleur littérale, AUCUNE chaîne d'interface en dur —
/// tout libellé vient de l'appelant, tout style du thème.
library;

import 'package:flutter/material.dart';

import '../domain/z_menu_entry.dart';
import 'z_menu_entry_tile.dart';
import 'z_menu_renderer.dart';
import 'z_menu_request.dart';

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
        // AD-10 : rien à montrer ⇒ déclencheur INERTE (jamais une surface vide,
        // jamais une levée). Un contenu injecté suffit à donner quelque chose à
        // montrer, même sans aucune entrée (menus SÉLECTEURS).
        enabled: entries.isNotEmpty || contentBuilder != null,
        icon: trigger.child == null ? Icon(trigger.icon) : null,
        // Nom accessible : porté UNE seule fois, par le tooltip (qui fournit
        // aussi `button: true`). `semanticLabel` étant requis et non vide, le
        // déclencheur ne peut pas être muet — y compris hors Material.
        tooltip: trigger.tooltip ?? trigger.semanticLabel,
        // Voie UNIQUE de sélection (contrat ZMenuRenderer §3).
        onSelected: request.select,
        itemBuilder: (context) => <PopupMenuEntry<ZMenuEntry>>[
          if (contentBuilder != null)
            _ZMenuPanelEntry(builder: contentBuilder, entries: entries)
          else
            for (final entry in entries)
              PopupMenuItem<ZMenuEntry>(
                value: entry,
                enabled: entry.isEnabled,
                // `PopupMenuItem` porte déjà son propre détecteur de geste :
                // `onSelected` de la tuile reste nul (deux détecteurs
                // superposés produiraient DEUX invocations).
                child: ZMenuEntryTile(entry: entry),
              ),
        ],
        child: trigger.child,
      ),
    );
  }
}

/// Entrée UNIQUE portant la présentation INJECTÉE — `PopupMenuEntry` NU.
///
/// Délibérément PAS un `PopupMenuItem` (cf. dartdoc de bibliothèque).
/// [height] ne sert qu'à l'estimation de défilement du `PopupMenu` (le contenu
/// se dimensionne lui-même) ; [represents] est `false` : l'entrée ne représente
/// AUCUNE valeur, donc aucune surbrillance d'« item courant ».
class _ZMenuPanelEntry extends PopupMenuEntry<ZMenuEntry> {
  const _ZMenuPanelEntry({required this.builder, required this.entries});

  final ZMenuContentBuilder builder;
  final List<ZMenuEntry> entries;

  @override
  double get height => kZMenuMinTapTarget;

  @override
  bool represents(ZMenuEntry? value) => false;

  @override
  State<_ZMenuPanelEntry> createState() => _ZMenuPanelEntryState();
}

class _ZMenuPanelEntryState extends State<_ZMenuPanelEntry> {
  @override
  Widget build(BuildContext context) => widget.builder(
        context,
        widget.entries,
        // MÊME chemin de sortie que la colonne par défaut : la valeur poppée est
        // récupérée par `onSelected` du `PopupMenuButton`, qui appelle
        // `request.select`. Une présentation injectée ne peut donc ni oublier de
        // fermer, ni invoquer deux fois, ni diverger du défaut.
        (entry) => Navigator.of(context).pop(entry),
      );
}
