/// [ZMenuEntry] — une entrée de menu DÉCLARÉE EN DONNÉES (CHAT-4).
///
/// Data-class de présentation immuable (`const`). [label] et [icon] sont
/// INJECTÉS (i18n + thème, jamais codés en dur — FR-26/NFR-S7).
///
/// ## 🔴 Les TROIS états, dont un que le socle n'exprimait pas
///
/// | [onSelected] | [disabledReason] | État rendu |
/// |---|---|---|
/// | non-`null` | `null` (obligatoire) | **présente et actionnable** |
/// | `null` | `null` | **ABSENTE** — règle AD-4 de `ZItemAction`, PRÉSERVÉE |
/// | `null` | non-`null` | **présente, DÉSACTIVÉE, motif ANNONCÉ** |
///
/// [permitted] `false` force l'absence, quel que soit le reste de la ligne.
///
/// Les deux premières lignes reproduisent **exactement** la sémantique de
/// `ZItemAction` (`zcrud_study`) : un hôte qui n'utilise jamais
/// [disabledReason] obtient le comportement historique, au caractère près.
///
/// La troisième ligne est ce que le socle ne savait pas dire. Elle n'affaiblit
/// PAS l'invariant « jamais un item grisé silencieux » : c'est le **silence**
/// qui reste inexprimable, pas la désactivation. Un motif est OBLIGATOIRE pour
/// désactiver — un `enabled: false` nu ne compile pas ici.
///
/// Défaut réel comblé (mesuré, LECTURE SEULE) :
/// `lex_douane/packages/lex_ui/lib/presentation/widgets/study/study_item_actions_menu.dart`
/// réécrit un `PopupMenuButton` **entier** à la main pour obtenir trois choses
/// que `ZItemActionsMenu` refuse : « Ouvrir » désactivée avec l'indice
/// `hubComingSoon` (`_DeferredEntry(label, hint)`), « Monter »/« Descendre »
/// désactivées aux bornes du groupe (`enabled: canMoveUp` / `canMoveDown`).
/// Trois entrées **présentes mais inertes, avec motif** — donc trois entrées que
/// la règle absolue rendait ABSENTES, c'est-à-dire une capacité perdue.
///
/// ## 🔴 [permitted] — la couche de traduction que l'hôte réécrivait
///
/// IFFD s'est branché sur `ZItemActionsMenu` et a dû écrire, POUR CELA, une
/// data-class à lui plus une fonction de traduction (mesuré, LECTURE SEULE :
/// `iffd/lib/src/presentation/features/folders/zcrud/folder_actions_menu_zcrud.dart`,
/// `IffdMenuAction.permitted` + `iffdMenuActions()` = `permitted ? onSelected :
/// null`). Sa dartdoc dit exactement pourquoi : « `permitted` est SÉPARÉ de
/// `onSelected` volontairement ». Le droit et l'effet sont deux notions
/// distinctes, et les écraser l'une sur l'autre est le travail que TOUT hôte
/// refera. [permitted] le porte donc ici, une fois pour toutes.
library;

import 'package:flutter/widgets.dart';

/// Une entrée de menu — donnée immuable, jamais un widget.
@immutable
class ZMenuEntry {
  /// Construit une entrée.
  ///
  /// [id] : identité OPAQUE et STABLE de l'entrée (jamais affichée). Sert de
  /// valeur de sélection et de clé de widget — c'est ce qui permet à un
  /// renderer injecté d'être stable au rebuild sans connaître le libellé.
  ///
  /// [label] : libellé LOCALISÉ INJECTÉ (i18n — jamais une chaîne en dur).
  ///
  /// [icon] : glyphe INJECTÉ, **optionnel** (`null` ⇒ entrée sans glyphe : un
  /// menu de conversation en est souvent dépourvu, là où `ZItemAction` impose
  /// une icône `required`).
  ///
  /// [onSelected] : effet. `null` **et** [disabledReason] `null` ⇒ entrée
  /// ABSENTE (AD-4).
  ///
  /// [disabledReason] : motif LOCALISÉ INJECTÉ de désactivation. Non-`null` ⇒
  /// l'entrée est rendue **présente mais inerte**, et le motif est ANNONCÉ
  /// (a11y AD-13). Incompatible avec un [onSelected] non-`null` (assert) : une
  /// entrée ne peut pas être à la fois actionnable et désactivée.
  ///
  /// [isDestructive] : l'entrée détruit ou remplace du contenu déjà visible.
  /// C'est une **donnée**, pas un style : le socle ne lui associe AUCUNE
  /// couleur (FR-26) ; un renderer injecté est libre de la traduire visuellement.
  ///
  /// [permitted] : l'utilisateur a-t-il le DROIT de voir cette entrée ?
  /// `false` ⇒ entrée ABSENTE, quels que soient [onSelected]/[disabledReason].
  /// Défaut `true` : un appelant qui ne gère pas de droits n'en voit rien.
  const ZMenuEntry({
    required this.id,
    required this.label,
    this.icon,
    this.onSelected,
    this.disabledReason,
    this.isDestructive = false,
    this.permitted = true,
  }) : assert(
          onSelected == null || disabledReason == null,
          'ZMenuEntry: une entrée ACTIONNABLE (onSelected non nul) ne peut pas '
          'porter un disabledReason — les deux états sont exclusifs. Pour une '
          'entrée désactivée, laisser onSelected nul et fournir le motif ; pour '
          'une entrée absente, laisser les deux nuls.',
        );

  /// Identité opaque et stable (jamais affichée à l'utilisateur).
  final String id;

  /// Libellé LOCALISÉ INJECTÉ.
  final String label;

  /// Glyphe INJECTÉ, optionnel.
  final IconData? icon;

  /// Effet de l'entrée. `null` ⇒ entrée non actionnable.
  final VoidCallback? onSelected;

  /// Motif LOCALISÉ INJECTÉ de désactivation (`null` ⇒ pas de désactivation).
  final String? disabledReason;

  /// L'entrée détruit ou remplace du contenu visible (donnée, pas style).
  final bool isDestructive;

  /// Droit de l'utilisateur sur cette entrée. `false` ⇒ ABSENTE.
  final bool permitted;

  /// `true` si l'entrée doit apparaître dans le menu : permise ET (actionnable
  /// OU désactivée avec motif). `false` ⇒ ABSENTE (AD-4).
  bool get isVisible =>
      permitted && (onSelected != null || disabledReason != null);

  /// `true` si l'entrée est actionnable (permise et dotée d'un effet).
  bool get isEnabled => permitted && onSelected != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZMenuEntry &&
          id == other.id &&
          label == other.label &&
          icon == other.icon &&
          onSelected == other.onSelected &&
          disabledReason == other.disabledReason &&
          isDestructive == other.isDestructive &&
          permitted == other.permitted;

  @override
  int get hashCode => Object.hash(
        id,
        label,
        icon,
        onSelected,
        disabledReason,
        isDestructive,
        permitted,
      );
}

/// Vocabulaire CANONIQUE des identités d'entrée (`ZMenuEntry.id`).
///
/// IFFD nomme explicitement ce qu'il retire du socle en second : « la **nature**
/// de chaque action […] qui donne un vocabulaire partagé — utile le jour où
/// plusieurs écrans exposent les mêmes gestes »
/// (`folder_actions_menu_zcrud.dart`). Douze sites de menu dans une seule app,
/// sur des domaines étrangers (étude, moteur de liste générique, workflow/agenda,
/// IA), c'est exactement le besoin.
///
/// 🔴 **Pourquoi des `String` et PAS un quatrième enum.** Le dépôt en porte déjà
/// trois — `ZItemActionKind` (`zcrud_study`), `ZBatchActionKind` (`zcrud_core`),
/// et le couple icône/`isOverflow` de `ZAppBarAction` (`zcrud_ui_kit`). Un enum
/// déclaré ici ne pourrait JAMAIS être adopté par `ZBatchAction` : `zcrud_core`
/// ne peut dépendre d'aucun satellite (CORE OUT = 0). Il deviendrait donc le
/// **quatrième** vocabulaire, pas le premier — précisément le doublon appauvri
/// que CR-LEX-78 reproche. Des constantes de chaîne, elles, sont adoptables par
/// n'importe qui **sans arête** : `zcrud_core` peut demain écrire
/// `id: 'delete'` sans dépendre de ce package.
///
/// La liste est OUVERTE : un hôte utilise ses propres identités pour ses gestes
/// hors nomenclature (pendant du variant `custom`), sans rien casser.
abstract final class ZMenuEntryIds {
  /// Ouvrir/consulter la cible.
  static const String open = 'open';

  /// Éditer la cible.
  static const String edit = 'edit';

  /// Renommer la cible.
  static const String rename = 'rename';

  /// Déplacer la cible.
  static const String move = 'move';

  /// Remonter la cible d'un rang.
  static const String moveUp = 'moveUp';

  /// Descendre la cible d'un rang.
  static const String moveDown = 'moveDown';

  /// Dupliquer la cible.
  static const String duplicate = 'duplicate';

  /// Partager la cible.
  static const String share = 'share';

  /// Copier le rendu de la cible.
  static const String copy = 'copy';

  /// Supprimer la cible.
  static const String delete = 'delete';

  /// Régénérer le contenu de la cible.
  static const String regenerate = 'regenerate';

  /// Annuler l'opération en cours sur la cible.
  static const String cancel = 'cancel';
}

/// Filtre la règle d'absence (AD-4) — **UN SEUL SITE** dans tout le package.
///
/// C'est ce qui rend la règle INOPPOSABLE à un renderer injecté : la liste qu'il
/// reçoit est déjà filtrée, il ne peut ni la contourner ni la ré-implémenter de
/// travers. Même discipline que `ZItemActionsMenu` (filtrage AMONT partagé) et
/// que le répartiteur unique de `ZChatActionDispatcher` (CHAT-0b).
List<ZMenuEntry> zVisibleMenuEntries(List<ZMenuEntry> entries) =>
    entries.where((e) => e.isVisible).toList(growable: false);
