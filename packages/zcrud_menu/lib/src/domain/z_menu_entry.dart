/// [ZMenuEntry] — une entrée de menu DÉCLARÉE EN DONNÉES.
///
/// Data-class de présentation immuable (`const`). [label] et [icon] sont
/// INJECTÉS (i18n + thème, jamais codés en dur).
///
/// ## Trois états représentables
///
/// | [onSelected] | [disabledReason] | État rendu |
/// |---|---|---|
/// | non-`null` | `null` (obligatoire) | **présente et actionnable** |
/// | `null` | `null` | **ABSENTE** — invariant AD-4 |
/// | `null` | non-`null` | **présente, DÉSACTIVÉE, motif ANNONCÉ** |
///
/// [permitted] `false` force l'absence, quel que soit le reste de la ligne.
///
/// Le troisième état — présente mais inerte, avec un motif annoncé — est ce
/// qu'une règle d'absence pure ne sait pas exprimer : elle n'affaiblit PAS
/// l'invariant « jamais un item grisé silencieux », puisque c'est le
/// **silence** qui reste inexprimable, pas la désactivation elle-même. Un
/// motif est OBLIGATOIRE pour désactiver — un simple drapeau `enabled: false`
/// sans motif n'est pas représentable ici.
///
/// ## Pourquoi [permitted] est séparé de [onSelected]
///
/// Le droit de voir une entrée et l'effet qu'elle produit sont deux notions
/// distinctes : un appelant qui les écrase l'une sur l'autre (« pas de droit
/// ⇒ callback nul ») reconstruit à la main une traduction que ce type porte
/// nativement. [permitted] existe pour que cette traduction n'ait à être
/// écrite qu'une fois, ici, plutôt que dans chaque consommateur.
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
  /// ABSENTE (invariant AD-4).
  ///
  /// [disabledReason] : motif LOCALISÉ INJECTÉ de désactivation. Non-`null` ⇒
  /// l'entrée est rendue **présente mais inerte**, et le motif est ANNONCÉ
  /// (invariant AD-13). Incompatible avec un [onSelected] non-`null` (assert) :
  /// une entrée ne peut pas être à la fois actionnable et désactivée.
  ///
  /// [isDestructive] : l'entrée détruit ou remplace du contenu déjà visible.
  /// C'est une **donnée**, pas un style : ce type ne lui associe AUCUNE
  /// couleur ; un renderer injecté est libre de la traduire visuellement.
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
  /// OU désactivée avec motif). `false` ⇒ ABSENTE (invariant AD-4).
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
/// Nommer explicitement la **nature** de chaque action donne un vocabulaire
/// partagé, utile dès que plusieurs écrans exposent les mêmes gestes
/// (ouvrir, renommer, dupliquer, supprimer…) sur des domaines par ailleurs
/// étrangers les uns aux autres.
///
/// **Pourquoi des `String` et pas un enum.** Un enum déclaré ici ne pourrait
/// jamais être adopté par un type qui vit dans `zcrud_core`, puisque le cœur
/// ne peut dépendre d'aucun satellite (invariant AD-1). Il deviendrait donc
/// un vocabulaire de plus, concurrent des autres, plutôt qu'un point de
/// convergence. Des constantes de chaîne, elles, sont adoptables par
/// n'importe quel paquet sans créer d'arête : le cœur peut écrire
/// `id: 'delete'` sans dépendre de ce package.
///
/// La liste est OUVERTE : un hôte utilise ses propres identités pour ses gestes
/// hors nomenclature, sans rien casser.
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

/// Filtre la règle d'absence (invariant AD-4) — **UN SEUL SITE** dans tout le
/// package.
///
/// C'est ce qui rend la règle INOPPOSABLE à un renderer injecté : la liste qu'il
/// reçoit est déjà filtrée, il ne peut ni la contourner ni la ré-implémenter de
/// travers.
List<ZMenuEntry> zVisibleMenuEntries(List<ZMenuEntry> entries) =>
    entries.where((e) => e.isVisible).toList(growable: false);
