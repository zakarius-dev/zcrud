/// La surface notebook d'une conversation.
///
/// ## Pourquoi ce widget existe
///
/// Un même moteur de conversation sert deux usages distincts :
/// * une conversation a un interlocuteur — on le nomme, on l'affiche, on lui
///   « écrit » ;
/// * un notebook n'en a pas — on interroge un corpus, et la réponse est un
///   matériau : elle se transforme (carte mentale, flashcards, variantes,
///   note) et s'exporte.
///
/// Ces deux usages sont rendus par deux widgets nommés, sur une seule racine
/// commune.
///
/// ## Une composition, pas une copie
///
/// La distinction est portée par la composition : `build()` retourne un
/// [ZChatConversationView] — ce widget ne construit ni liste, ni tuile, ni
/// région live lui-même. La fabrique de tuile, unique dans ce paquet, rend
/// donc les deux surfaces : une régression dans la fabrique affecte les deux,
/// une amélioration profite aux deux.
///
/// ## Ce qui distingue les défauts d'usage
///
/// | Axe | [ZChatConversationView] | [ZChatNotebookView] |
/// |---|---|---|
/// | identité de l'interlocuteur | créneau `identityBuilder` disponible | structurellement masquée : le paramètre n'existe pas |
/// | actions par message | créneau `actionsBuilder` disponible | même créneau, c'est la raison d'être de la surface |
///
/// Sans réglage, la conversation reste une conversation — rendu strictement
/// inchangé — et le notebook rend le même fil sans identité, prêt à recevoir
/// ses actions de transformation.
///
/// ## Les capacités notebook passent par le contrat d'invocation existant
///
/// Les capacités de transformation (carte mentale, flashcards, variantes,
/// export, enregistrer en note) se montent par [actionsBuilder] et
/// s'exécutent par
/// `ZChatController.runAction(ZChatCustomAction(verb: ..., payload: ...))`,
/// l'unique point d'entrée des verbes, routé par l'unique répartiteur. Ce
/// widget n'ajoute aucun chemin d'exécution.
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
    this.composer,
    super.key,
  });

  /// Le contrôleur du fil — le même type, le même cycle de vie (invariant
  /// AD-2) que pour la conversation : il n'existe pas de « contrôleur de
  /// notebook » distinct.
  final ZChatController controller;

  /// Le créneau d'actions par message — cf.
  /// [ZChatMessageTile.actionsBuilder]. C'est ici que l'hôte monte ses
  /// capacités notebook ; leurs rappels passent par
  /// `controller.runAction(ZChatCustomAction(...))`.
  ///
  /// `null` signifie aucun bandeau d'actions : un notebook en lecture seule
  /// reste un notebook (invariant AD-4 — créneau nul, absent de l'arbre).
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// Hauteur repliée des tuiles — relayée telle quelle.
  final double? collapsedMaxHeight;

  /// Marge directionnelle de la liste (invariant AD-13) — relayée telle
  /// quelle.
  final EdgeInsetsDirectional? padding;

  /// Liste inversée — relayée telle quelle.
  final bool reverse;

  /// La zone de saisie — relayée telle quelle à la racine commune.
  ///
  /// Le notebook n'en monte pas une à lui : il relaie. C'est la même
  /// discipline que pour la tuile — la saisie du notebook et celle de la
  /// conversation sont rendues par la même fabrique unique, donc elles ne
  /// peuvent pas diverger. `null` signifie absent de l'arbre (invariant
  /// AD-4) : un notebook en lecture seule reste un notebook, et un hôte
  /// passif ne voit pas son arbre changer.
  final Widget? composer;

  @override
  Widget build(BuildContext context) {
    // La composition : rien d'autre. Toute logique ajoutée ici recréerait une
    // seconde implémentation de la même surface.
    return ZChatConversationView(
      controller: controller,
      collapsedMaxHeight: collapsedMaxHeight,
      padding: padding,
      reverse: reverse,
      // Identité : pas de paramètre sur cette surface — le masquage n'est pas
      // un défaut réglable, c'est la définition de l'usage notebook.
      actionsBuilder: actionsBuilder,
      // Relai, jamais une seconde saisie : la fabrique unique rend les deux
      // surfaces.
      composer: composer,
    );
  }
}
