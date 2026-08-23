/// Les **canaux de libellé et de glyphe** de la feuille d'outils Material.
///
/// Ce paquet ne compose aucun texte : chaque affordance qu'il rend reçoit son
/// libellé de l'hôte, déjà localisé (FR-26). Quand un libellé manque, c'est
/// **l'affordance** qui est absente, jamais un texte de remplacement inventé
/// ici (invariant AD-4) :
///
/// | Champ absent | Effet |
/// |---|---|
/// | [all] | la puce « tout le catalogue » n'est pas rendue |
/// | [active] | l'en-tête des outils actifs n'est pas rendu |
/// | [search] | la barre de recherche n'est pas proposée |
/// | [reasonOf] rendant `null` | l'entrée reste **grisée**, sans texte d'explication |
/// | [itemLabelOf] rendant `null` | l'entrée de catalogue concernée n'est pas rendue |
///
/// Trois libellés font exception et retombent sur le registre du socle
/// (`zChatLabel`, qui a son propre repli documenté) : le titre de la feuille,
/// « réinitialiser » et « fermer » — ce sont des clés que le socle porte déjà.
library;

import 'package:flutter/material.dart';

/// Canaux de libellé et de glyphe de la feuille d'outils.
@immutable
class ZChatMaterialToolLabels {
  /// Construit les canaux. Tout est optionnel : un hôte qui ne fournit rien
  /// obtient la feuille réduite aux affordances que le socle sait nommer.
  const ZChatMaterialToolLabels({
    this.title,
    this.reset,
    this.close,
    this.search,
    this.all,
    this.active,
    this.reasonOf,
    this.itemLabelOf,
    this.iconOf,
  });

  /// Titre de la feuille. `null` ⇒ clé du registre du socle.
  final String? title;

  /// Libellé du bouton de remise à zéro. `null` ⇒ clé du registre du socle.
  final String? reset;

  /// Libellé de la fermeture. `null` ⇒ clé du registre du socle.
  final String? close;

  /// Invite de la barre de recherche. `null` ⇒ **aucune barre**.
  final String? search;

  /// Libellé de la puce « tout le catalogue ». `null` ⇒ **aucune puce**.
  final String? all;

  /// Titre de l'en-tête des outils actifs. `null` ⇒ **aucun en-tête**.
  final String? active;

  /// Résout un jeton opaque (raison de grisage, indisponibilité) en texte
  /// déjà localisé.
  final String? Function(String token)? reasonOf;

  /// Résout le libellé d'une entrée de catalogue filtrable.
  ///
  /// Le socle interroge d'abord `ZChatToolEntry.stateLabels[itemKey]` : un
  /// hôte qui y range ses libellés d'items n'a rien d'autre à fournir.
  final String? Function(String entryKey, String itemKey)? itemLabelOf;

  /// Glyphe d'une tuile, fourni par l'hôte (le socle n'en invente aucun).
  final Widget? Function(String entryKey)? iconOf;
}
