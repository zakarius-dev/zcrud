/// Le porteur de créneaux du composer assemblé : ce qui rend le
/// remplacement de composer **graduel** sur les écrans assemblés.
///
/// ## Le choix qu'il ouvre
///
/// Un écran assemblé (`ZChatNotebookScreen`, `ZChatConversationScreen`)
/// câble pour l'hôte tout ce qu'il ne veut pas recâbler : le contrôleur de
/// réglages, le déclencheur qui ouvre la feuille, le badge du compte
/// d'outils, le sélecteur de routeur qui se substitue au sélecteur de
/// modèle, les jetons de chrome. Le paramètre `composerBuilder` de ces
/// écrans est une échappatoire **totale** : l'hôte qui veut styliser une
/// seule pièce doit remonter un composer entier, et reperd ce câblage.
///
/// Ce porteur est l'autre voie : un champ par créneau, tous nullables, tous
/// relayés **tels quels** à `ZDefaultChatComposer`. L'hôte remplace la ou
/// les pièces qui l'intéressent et **garde** le reste de l'assemblage.
///
/// ## Trois cas, comme partout
///
/// Chaque champ suit la règle des trois cas de `ZChatComposerSlotBuilder` :
/// absent (`null`) donne le défaut de l'écran ; fourni et rendant un widget,
/// il remplace la pièce ; fourni et rendant `null`, la pièce est absente
/// (invariant AD-4).
///
/// ## Inertie
///
/// Un porteur absent laisse l'écran **strictement** dans son état : aucun
/// des créneaux n'est renseigné, l'assemblé reçoit exactement les mêmes
/// paramètres qu'auparavant.
///
/// ## Exclusivité avec le remplacement total
///
/// Déclarer à la fois `composerBuilder` et `composerSlots` est
/// contradictoire : le premier remplace le composer entier, le second en
/// habille les pièces — l'un des deux serait silencieusement perdu. Les
/// écrans assemblés le refusent par une assertion en debug ; en release, le
/// remplacement total **prime**.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_composer.dart' show ZChatComposerSlotBuilder;

/// Les créneaux du composer assemblé, un champ nullable par pièce.
///
/// Passé à un écran assemblé, il est relayé tel quel au composer par défaut.
/// Chaque champ nomme la pièce qu'il remplace ; l'ordre de déclaration suit
/// celui du cadre — les rangs empilés au-dessus du champ de saisie, puis les
/// pièces de la bande, puis les cibles d'action.
@immutable
class ZChatComposerSlots {
  /// Construit un porteur de créneaux. Tout champ omis laisse la pièce
  /// correspondante au défaut de l'écran.
  const ZChatComposerSlots({
    this.draftNotice,
    this.editingBanner,
    this.progress,
    this.suggestions,
    this.attachments,
    this.capture,
    this.hint,
    this.plus,
    this.thinking,
    this.webSearch,
    this.tools,
    this.effort,
    this.model,
    this.dictationTrigger,
    this.stop,
    this.send,
  });

  /// Rang 0 — l'indicateur de brouillon restitué.
  final ZChatComposerSlotBuilder? draftNotice;

  /// Rang 1 — le bandeau d'édition.
  final ZChatComposerSlotBuilder? editingBanner;

  /// Rang 2 — la progression de téléversement.
  final ZChatComposerSlotBuilder? progress;

  /// Rang 3 — la bande de propositions.
  final ZChatComposerSlotBuilder? suggestions;

  /// Rang 4 — l'aperçu des pièces jointes.
  final ZChatComposerSlotBuilder? attachments;

  /// Rang 5 — le créneau libre au-dessus du champ (une bande de capture
  /// d'hôte, par exemple).
  final ZChatComposerSlotBuilder? capture;

  /// Le placeholder du champ de saisie.
  final ZChatComposerSlotBuilder? hint;

  /// Bande — le `+` des pickers.
  final ZChatComposerSlotBuilder? plus;

  /// Bande — la bascule « réfléchir ».
  final ZChatComposerSlotBuilder? thinking;

  /// Bande — la bascule « internet ».
  final ZChatComposerSlotBuilder? webSearch;

  /// Bande — le déclencheur d'outils (le bouton, jamais la feuille : la
  /// rendre ici reste détecté par l'assemblé).
  ///
  /// Le remplacer emporte le badge de compte que l'écran câblait sur la
  /// pièce par défaut : la nouvelle pièce est responsable de son propre
  /// canal de comptage.
  final ZChatComposerSlotBuilder? tools;

  /// Bande — le déclencheur d'effort.
  final ZChatComposerSlotBuilder? effort;

  /// Bande — le sélecteur de modèle.
  ///
  /// Fourni, il **prime** sur le sélecteur de routeur que l'écran monte à
  /// cette place quand une session de routage est déclarée : c'est le sens
  /// de la règle des trois cas — un créneau d'hôte remplace le défaut de
  /// l'écran, quel que soit ce défaut.
  final ZChatComposerSlotBuilder? model;

  /// Bande — le déclencheur compact de dictée.
  final ZChatComposerSlotBuilder? dictationTrigger;

  /// La cible d'arrêt de génération.
  final ZChatComposerSlotBuilder? stop;

  /// La cible d'envoi.
  final ZChatComposerSlotBuilder? send;
}
