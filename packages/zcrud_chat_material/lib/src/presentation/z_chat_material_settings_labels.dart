/// Les **canaux de libellé et de glyphe** de la feuille de réglages Material.
///
/// Ce paquet ne compose aucun texte : chaque affordance qu'il rend reçoit son
/// libellé de l'hôte, déjà localisé, ou d'une clé du registre du socle
/// (`zChatLabel`). Quand un libellé d'hôte manque, c'est **l'affordance** qui
/// est absente, jamais un texte de remplacement inventé ici :
///
/// | Canal absent | Effet |
/// |---|---|
/// | [all] | la puce « tout le catalogue » de la portée documentaire n'est pas rendue |
/// | [revealThinkingStateOf] | la bascule de raisonnement n'a pas de sous-titre d'état |
/// | [capabilityStateOf] | les bascules de capacité n'ont pas de sous-titre d'état |
/// | [reasonOf] rendant `null` | l'entrée indisponible reste **grisée**, sans texte d'explication |
/// | [iconOf] rendant `null` | le glyphe par défaut du satellite, s'il en a un ; sinon aucun |
///
/// Trois libellés retombent sur le registre du socle quand l'hôte ne les
/// fournit pas — le titre de la feuille, « réinitialiser » et « fermer » : ce
/// sont des clés que le socle porte déjà, avec leur repli documenté.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_chat/zcrud_chat.dart';

/// Canaux de libellé et de glyphe de la feuille de réglages.
@immutable
class ZChatMaterialSettingsLabels {
  /// Construit les canaux. Tout est optionnel : un hôte qui ne fournit rien
  /// obtient la feuille réduite aux affordances que le socle sait nommer.
  const ZChatMaterialSettingsLabels({
    this.title,
    this.reset,
    this.close,
    this.all,
    this.revealThinkingStateOf,
    this.capabilityStateOf,
    this.reasonOf,
    this.iconOf,
  });

  /// Titre de la feuille. `null` ⇒ clé du registre du socle.
  final String? title;

  /// Libellé de la remise à zéro. `null` ⇒ clé du registre du socle.
  final String? reset;

  /// Libellé de la fermeture. `null` ⇒ clé du registre du socle.
  final String? close;

  /// Libellé de la puce « tout le catalogue » de la portée documentaire.
  /// `null` ⇒ **aucune puce** : une sélection vide vaut déjà « tous » pour le
  /// contrôleur, la puce n'est qu'un raccourci de lecture.
  final String? all;

  /// Sous-titre d'**état** de la bascule de raisonnement, pour la valeur
  /// courante (`null` signifiant « l'hôte décide »). Rendre `null` ⇒ aucun
  /// sous-titre.
  final String? Function(bool? value)? revealThinkingStateOf;

  /// Sous-titre d'**état** d'une bascule de capacité : [key] est la clé de la
  /// capacité, [requested] vaut `true` quand elle est demandée. Rendre `null`
  /// ⇒ aucun sous-titre.
  final String? Function(String key, bool requested)? capabilityStateOf;

  /// Raison, déjà localisée, pour laquelle l'entrée [key] (clé de corpus ou
  /// de capacité) est indisponible. Rendre `null` ⇒ entrée grisée sans
  /// explication.
  final String? Function(String key)? reasonOf;

  /// Glyphe d'une tuile : [key] est l'identifiant d'entrée standard
  /// (`kZChatSettingsEntryRevealThinking`) ou la clé d'une capacité. Rendre
  /// `null` ⇒ glyphe par défaut du satellite quand il en a un.
  final Widget? Function(String key)? iconOf;
}

/// Résout un libellé à double source du socle : une clé passe par le
/// registre (`zChatLabel`), un texte d'hôte est rendu tel quel.
String zChatMaterialSettingsLabelText(
  BuildContext context,
  ZChatSettingsLabel label,
) {
  final String? key = label.labelKey;
  return key == null ? label.text! : zChatLabel(context, key);
}
