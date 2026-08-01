/// `zcrud_menu` — menus contextuels à **déclencheur et contenu découplés**.
///
/// L'hôte branche SON package de menus derrière [ZMenuRenderer] ; sans
/// injection, [ZDefaultMenuRenderer] (Flutter/Material seul, ZÉRO dépendance
/// tierce — AD-57) reste pleinement fonctionnel.
///
/// ```dart
/// ZActionMenu(
///   trigger: ZMenuTrigger(icon: monGlyphe, semanticLabel: l10n.moreOptions),
///   entries: [
///     ZMenuEntry(id: 'open', label: l10n.open, onSelected: ouvrir),
///     // présente, INERTE, motif annoncé — inexprimable avec ZItemAction :
///     ZMenuEntry(id: 'edit', label: l10n.edit, disabledReason: l10n.comingSoon),
///     // ni actionnable ni désactivée ⇒ ABSENTE (AD-4) :
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
/// ## Une seule couture pour QUATRE surfaces
///
/// Ce package n'est **pas** un menu « de chat » : aucun type de sa surface
/// publique ne nomme un message ni une conversation. Il sert indifféremment un
/// **item de liste**, une **carte de matériel pédagogique**, une **barre d'app**
/// et un **message de conversation** — parce que c'est le même geste. IFFD
/// duplique ce motif sur **douze** fichiers, dans des domaines étrangers les uns
/// aux autres (étude, moteur de liste générique `data_crud`, workflow/agenda,
/// IA) ; lex_douane le réécrit à la main dans `lex_ui`. Factoriser un moteur
/// dupliqué à l'identique est la mission même de zcrud.
///
/// Position dans le dépôt (lire `pubspec.yaml` pour la justification mesurée) :
/// ce package est le foyer NEUTRE et ATTEIGNABLE que `ZItemActionsMenu`
/// (`zcrud_study`, satellite métier) ne pouvait pas être.
///
/// ## ✅ Le doublon est SUPPRIMÉ (CHAT-4b)
///
/// `ZItemActionsMenu` (`zcrud_study`) est désormais un **consommateur** de cette
/// couture : il traduit ses `ZItemAction` en [ZMenuEntry] et délègue à
/// [ZActionMenu]. Il ne construit plus AUCUN `PopupMenuButton` — grep négatif
/// prouvé par `test/z_menu_supersedes_test.dart`, qui vérifie aussi que les 15
/// capacités historiques vivent toujours ici et que les capacités supérieures
/// (`permitted`, `disabledReason`, [ZMenuEntryIds], [ZMenuEntryTile],
/// [ZMenuRenderer]) sont ATTEIGNABLES depuis la façade. Sa surface publique est
/// inchangée : les hôtes existants (IFFD, lex_douane) ne réécrivent rien.
///
/// ## ⚠️ Ce qui RESTE hors de cette couture
///
/// Deux menus du dépôt gardent leur `PopupMenuButton` en dur, **par
/// construction** et non par oubli :
/// * `ZBatchActionBar._OverflowMenu` (`zcrud_core`) — `zcrud_core` ne peut
///   dépendre d'AUCUN satellite (CORE OUT = 0). Il faudrait déplacer la couture
///   dans `zcrud_core` (`ZcrudScope.menuRenderer`) pour l'en doter ;
/// * le débordement de `ZPageShell` (`zcrud_ui_kit`) — migrable, lui, mais hors
///   du périmètre d'écriture de CHAT-4b.
library;

export 'src/domain/z_menu_entry.dart';
export 'src/domain/z_menu_trigger.dart';
export 'src/presentation/z_action_menu.dart';
export 'src/presentation/z_default_menu_renderer.dart';
export 'src/presentation/z_menu_entry_tile.dart';
export 'src/presentation/z_menu_renderer.dart';
export 'src/presentation/z_menu_request.dart';
export 'src/presentation/z_menu_scope.dart';
