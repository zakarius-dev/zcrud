/// `zcrud_menu` — menus contextuels à **déclencheur et contenu découplés**.
///
/// L'hôte branche SON package de menus derrière [ZMenuRenderer] ; sans
/// injection, [ZDefaultMenuRenderer] (Flutter/Material seul, ZÉRO dépendance
/// tierce) reste pleinement fonctionnel.
///
/// ```dart
/// ZActionMenu(
///   trigger: ZMenuTrigger(icon: monGlyphe, semanticLabel: l10n.moreOptions),
///   entries: [
///     ZMenuEntry(id: 'open', label: l10n.open, onSelected: ouvrir),
///     // présente, INERTE, motif annoncé :
///     ZMenuEntry(id: 'edit', label: l10n.edit, disabledReason: l10n.comingSoon),
///     // ni actionnable ni désactivée ⇒ ABSENTE (invariant AD-4) :
///     const ZMenuEntry(id: ZMenuEntryIds.share, label: '—'),
///     // droit refusé ⇒ ABSENTE, sans que l'appelant traduise quoi que ce soit :
///     ZMenuEntry(
///       id: ZMenuEntryIds.delete,
///       label: l10n.delete,
///       permitted: peutSupprimer,
///       onSelected: supprimer,
///     ),
///   ],
/// )
/// ```
///
/// ## Une seule couture pour plusieurs surfaces
///
/// Ce package n'est **pas** un menu spécifique à un domaine : aucun type de
/// sa surface publique ne nomme un message, une conversation ou une entité
/// métier. Il sert indifféremment un item de liste, une carte de contenu,
/// une barre d'application ou un message de conversation — parce que c'est
/// le même geste (déclencheur + entrées d'action). Un satellite métier qui a
/// besoin d'un menu contextuel construit ses entrées en données et délègue à
/// [ZActionMenu], plutôt que de reconstruire son propre `PopupMenuButton`.
///
/// ## Ce qui reste hors de cette couture
///
/// `zcrud_core` ne peut dépendre d'aucun satellite (invariant AD-1) : un menu
/// qui vit dans le cœur (ex. le débordement d'une barre d'actions par lot) ne
/// peut donc pas être injecté via ce package sans que la couture soit
/// elle-même déplacée dans le cœur (`ZcrudScope.menuRenderer`).
library;

export 'src/domain/z_menu_entry.dart';
export 'src/domain/z_menu_trigger.dart';
export 'src/presentation/z_action_menu.dart';
export 'src/presentation/z_default_menu_renderer.dart';
export 'src/presentation/z_menu_entry_tile.dart';
export 'src/presentation/z_menu_renderer.dart';
export 'src/presentation/z_menu_request.dart';
export 'src/presentation/z_menu_scope.dart';
