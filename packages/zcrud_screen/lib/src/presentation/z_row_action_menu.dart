/// Actions de ligne présentées en **menu** : la conversion des actions
/// résolues du cœur en entrées de menu, et la tuile qui les porte.
///
/// ## Où vit cette conversion, et pourquoi ici
///
/// `ZResolvedRowAction` (cœur) et `ZMenuEntry` (`zcrud_menu`) se correspondent
/// presque terme à terme — libellé, glyphe, effet, droit, caractère
/// destructif, motif de désactivation. La conversion pourrait donc être écrite
/// dans l'un ou l'autre paquet **sans créer la moindre arête** : `zcrud_menu`
/// dépend déjà de `zcrud_core`.
///
/// Elle vit néanmoins ici, dans l'assemblage, pour une raison de **sens** et
/// non de graphe : aucun type de la surface publique de `zcrud_menu` ne nomme
/// une liste, une ligne ni une entité — c'est ce qui lui permet de servir
/// indifféremment une carte, une barre d'application ou une conversation. Y
/// faire entrer un type d'action de LISTE lui donnerait une clientèle
/// privilégiée, et le prochain domaine réclamerait la sienne.
///
/// ## Droit refusé : masquer ou montrer inerte, c'est l'application qui dit
///
/// Une action refusée par l'ACL n'a pas à disparaître : montrée **inerte avec
/// son motif**, elle apprend à l'utilisateur que le geste existe et pourquoi il
/// lui est fermé — ce qu'un bouton absent ne dit pas. Mais le choix reste celui
/// de l'application : le mode d'ACL déclaré sur l'écran (`ZActionAclMode`)
/// gouverne, et la conversion se contente de le refléter fidèlement — l'action
/// masquée n'arrive jamais jusqu'ici, l'action montrée arrive avec son motif.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZResolvedRowAction, label;
import 'package:zcrud_menu/zcrud_menu.dart'
    show ZActionMenu, ZContextMenuRegion, ZMenuEntry, ZMenuTrigger;

/// Convertit une action de ligne **résolue** (entité liée, ACL déjà tranchée)
/// en entrée de menu.
///
/// Correspondance :
///
/// | `ZResolvedRowAction` | `ZMenuEntry` |
/// |---|---|
/// | `id` | `id` |
/// | `labelKey` | `label` (résolu via `label(context, …)`) |
/// | `icon` | `icon` |
/// | `destructive` | `isDestructive` |
/// | `enabled` | `onSelected` si vrai, sinon `disabledReason` |
/// | `disabledReasonKey` | `disabledReason` (résolu via `label(context, …)`) |
///
/// Une action **désactivée** devient une entrée présente, inerte, dont le
/// motif est annoncé aux lecteurs d'écran. Le motif retenu est, dans l'ordre :
/// celui que porte l'action elle-même (`disabledReasonKey` — un droit retiré à
/// cette ligne, ou une action qui ne s'y applique pas), puis le
/// [disabledReason] fourni par l'appelant, puis le libellé générique
/// `actionNotAllowed`. L'entrée reste **inexécutable** : la voie de sélection
/// de `zcrud_menu` refuse une entrée sans effet, quelle que soit la
/// présentation.
ZMenuEntry zMenuEntryOfRowAction(
  BuildContext context,
  ZResolvedRowAction action, {
  String? disabledReason,
}) {
  final String? reasonKey = action.disabledReasonKey;
  return ZMenuEntry(
    id: action.id,
    label: label(context, action.labelKey),
    icon: action.icon,
    isDestructive: action.destructive,
    onSelected: action.enabled ? action.onInvoke : null,
    disabledReason: action.enabled
        ? null
        : reasonKey != null
            ? label(context, reasonKey)
            : disabledReason ?? label(context, 'actionNotAllowed'),
  );
}

/// Convertit une liste d'actions résolues, **ordre préservé**.
///
/// La liste reçue est déjà celle que l'écran offre : les actions que le mode
/// d'ACL déclaré masque n'y figurent pas, celles qu'il montre désactivées y
/// figurent avec `enabled: false`.
List<ZMenuEntry> zMenuEntriesOfRowActions(
  BuildContext context,
  List<ZResolvedRowAction> actions, {
  String? disabledReason,
}) =>
    <ZMenuEntry>[
      for (final action in actions)
        zMenuEntryOfRowAction(context, action, disabledReason: disabledReason),
    ];

/// Tuile de ligne dont les actions sont offertes **en menu** — déclencheur
/// visible, geste contextuel, ou les deux.
///
/// Le déclencheur est rendu par le renderer du `ZMenuScope` ambiant (repli
/// Material sinon) : un hôte qui a branché son propre paquet de menus le voit
/// servir ici aussi, sans rien déclarer de plus.
///
/// **L'affordance visible n'est jamais retirée** : quand un geste contextuel
/// est offert, le déclencheur reste rendu, faute de quoi l'action deviendrait
/// inatteignable au clavier et aux lecteurs d'écran (invariant AD-13).
class ZRowActionsMenu extends StatelessWidget {
  /// Construit la tuile.
  ///
  /// [actions] : actions résolues de la ligne (ordre préservé).
  ///
  /// [child] : la tuile de la ligne, telle que l'écran ou l'application la
  /// rend — ses gestes propres restent intacts.
  ///
  /// [showTrigger] : rend le déclencheur de menu à côté du contenu. `false`
  /// n'est légitime que lorsque les actions sont **déjà** rendues en boutons
  /// visibles dans la ligne (présentation adaptative en ligne).
  ///
  /// [secondaryTap] / [longPress] : gestes contextuels offerts.
  ///
  /// [triggerIcon] : glyphe du déclencheur.
  const ZRowActionsMenu({
    required this.actions,
    required this.child,
    this.showTrigger = true,
    this.secondaryTap = false,
    this.longPress = false,
    this.triggerIcon = Icons.more_vert,
    super.key,
  });

  /// Actions résolues de la ligne.
  final List<ZResolvedRowAction> actions;

  /// Contenu de la ligne.
  final Widget child;

  /// Rend le déclencheur de menu à côté du contenu.
  final bool showTrigger;

  /// Ouvre le menu au clic droit (pointeur).
  final bool secondaryTap;

  /// Ouvre le menu à l'appui long (tactile).
  final bool longPress;

  /// Glyphe du déclencheur.
  final IconData triggerIcon;

  @override
  Widget build(BuildContext context) {
    // Aucune action offerte : la tuile est rendue telle quelle — ni
    // déclencheur inerte, ni geste qui n'ouvrirait rien (invariant AD-10).
    if (actions.isEmpty) return child;
    final entries = zMenuEntriesOfRowActions(context, actions);
    final trigger = ZMenuTrigger(
      icon: triggerIcon,
      semanticLabel: label(context, 'moreActions'),
    );
    Widget content = child;
    if (showTrigger) {
      content = Row(
        children: <Widget>[
          Expanded(child: child),
          ZActionMenu(
            key: const ValueKey<String>('zCrudRowMenuTrigger'),
            trigger: trigger,
            entries: entries,
          ),
        ],
      );
    }
    if (!secondaryTap && !longPress) return content;
    return ZContextMenuRegion(
      entries: entries,
      trigger: trigger,
      secondaryTap: secondaryTap,
      longPress: longPress,
      child: content,
    );
  }
}
