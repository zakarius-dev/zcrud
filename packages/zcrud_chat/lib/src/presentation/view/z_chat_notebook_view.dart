/// La surface **NOTEBOOK** — CR-IFFD-71.
///
/// ## Pourquoi ce widget existe
///
/// IFFD sert deux usages avec le même monolithe de 5 180 lignes, discriminé par
/// un booléen `isChatSession` relu à 21 endroits :
/// * une **conversation** a un interlocuteur — on le nomme, on l'affiche, on
///   lui « écrit » ;
/// * un **notebook** n'en a pas — on « demande » à propos d'un corpus, et la
///   réponse est un **matériau** : elle se transforme (carte mentale,
///   flashcards, variantes, note) et s'exporte.
///
/// Le propriétaire a demandé que le socle « les distingue dans des widgets
/// différents, peut-être pouvant hériter d'une racine commune si besoin ».
/// C'est exactement la forme livrée : deux widgets **nommés**, une **seule**
/// racine.
///
/// ## 🔴 Anti-divergence (motif CR-LEX-78) — une composition, pas une copie
///
/// Le legacy d'IFFD porte déjà `SfChatBotScreen extends SfExplainScreen`, un
/// héritage **cosmétique** : la sous-classe ne fait que pousser un booléen, et
/// tout le comportement reste décidé dans le corps monolithique. Ici la
/// distinction est portée par la **composition** : `build()` retourne un
/// [ZChatConversationView] — ce widget ne construit **ni liste, ni tuile, ni
/// région live**. La fabrique de tuile (`_ZChatList._item`, le SEUL
/// constructeur de tuile du package, garde G-S5) rend donc les DEUX surfaces :
/// une régression dans la fabrique rougit les deux, une amélioration profite
/// aux deux. La garde G-N1 (`z_chat_cr71_guard_test.dart`) le prouve sur les
/// sources.
///
/// ## Ce qui distingue les défauts d'usage
///
/// | Axe | [ZChatConversationView] | [ZChatNotebookView] |
/// |---|---|---|
/// | identité de l'interlocuteur | créneau `identityBuilder` disponible | **structurellement masquée** : le paramètre n'existe pas |
/// | actions par message | créneau `actionsBuilder` disponible | même créneau, **c'est la raison d'être de la surface** |
///
/// Sans réglage (CR-56), la conversation reste une conversation — rendu
/// strictement inchangé — et le notebook rend le même fil **sans identité**,
/// prêt à recevoir ses actions de transformation.
///
/// ## Les capacités notebook passent par le contrat d'invocation EXISTANT
///
/// Les cinq capacités du legacy (carte mentale, flashcards, variantes, export,
/// enregistrer en note) se montent par [actionsBuilder] et s'exécutent par
/// `ZChatController.runAction(ZChatCustomAction(verb: ..., payload: ...))` —
/// l'unique point d'entrée des verbes (G-CH1), routé par l'unique répartiteur
/// (G-U1/G-CH2). Ce widget n'ajoute **aucun** chemin d'exécution ; le pont
/// métier des flashcards existe déjà (`zcrud_chat_study`,
/// `zChatMessageGenerationRequest`). Preuve de composition :
/// `test/z_chat_cr71_composition_test.dart`.
library;

import 'package:flutter/widgets.dart';

import '../z_chat_controller.dart';
import 'z_chat_conversation_view.dart';
import 'z_chat_message_tile.dart';

/// Rend un fil en usage **notebook** : même racine que la conversation,
/// identité masquée, créneau d'actions par message exposé.
class ZChatNotebookView extends StatelessWidget {
  /// Construit la surface notebook.
  ///
  /// Tous les paramètres partagés gardent **exactement** les défauts de
  /// [ZChatConversationView] (additivité stricte — aucun défaut ne bouge).
  const ZChatNotebookView({
    required this.controller,
    this.actionsBuilder,
    this.collapsedMaxHeight,
    this.padding,
    this.reverse = false,
    super.key,
  });

  /// Le contrôleur du fil — le MÊME type, le MÊME cycle de vie (AD-2) que pour
  /// la conversation : il n'existe pas de « contrôleur de notebook ».
  final ZChatController controller;

  /// Le créneau d'**actions par message** — cf.
  /// [ZChatMessageTile.actionsBuilder]. C'est ici que l'hôte monte ses
  /// capacités notebook ; leurs rappels passent par
  /// `controller.runAction(ZChatCustomAction(...))`.
  ///
  /// `null` ⇒ aucun bandeau d'actions : un notebook en lecture seule reste un
  /// notebook (AD-4 — slot nul, absent de l'arbre).
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// Hauteur repliée des tuiles — relayée telle quelle.
  final double? collapsedMaxHeight;

  /// Marge **directionnelle** de la liste (AD-13) — relayée telle quelle.
  final EdgeInsetsDirectional? padding;

  /// Liste inversée — relayée telle quelle.
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    // 🔴 LA composition : rien d'autre. Toute logique ajoutée ici serait un
    // début de « surface B » (le défaut IFFD que G-S5/G-N1 interdisent).
    return ZChatConversationView(
      controller: controller,
      collapsedMaxHeight: collapsedMaxHeight,
      padding: padding,
      reverse: reverse,
      // Identité : PAS de paramètre sur cette surface — le masquage n'est pas
      // un défaut réglable, c'est la définition de l'usage notebook.
      actionsBuilder: actionsBuilder,
    );
  }
}
