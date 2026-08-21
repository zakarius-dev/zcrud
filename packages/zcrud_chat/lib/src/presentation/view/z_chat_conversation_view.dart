/// Rendu neutre d'une conversation.
///
/// ## Trois défauts fréquents qu'un rendu de conversation doit éviter
///
/// 1. Une liste non virtualisée monte toutes ses bulles à la fois, chacune
///    portant potentiellement un rendu riche — ce qui contredit l'invariant
///    AD-2. Ici la liste est bâtie paresseusement
///    (`SliverChildBuilderDelegate`) : le viewport culle des deux côtés.
/// 2. Une réponse qui arrive en streaming sans aucun nœud d'accessibilité
///    est muette pour un lecteur d'écran. Ici la liste est une région live
///    dont le libellé suit `controller.liveAnnouncement` — la tranche que le
///    contrôleur ne fait bouger qu'aux jalons, jamais à chaque jeton (une
///    région live qui parle des centaines de fois par tour est inutilisable).
/// 3. Prendre l'abonnement au texte à haute fréquence en dehors de
///    l'`itemBuilder` reconstruirait toute la conversation à chaque
///    fragment. Ici l'abonnement est pris à l'intérieur de l'`itemBuilder`,
///    sur `controller.streamText(requestId)` — la tranche par requête. Un
///    jeton reconstruit la tuile en cours, pas la conversation. Les tranches
///    grossières (`messages`, `activeRequests`) sont écoutées au-dessus, mais
///    elles ne changent qu'aux transitions de tour.
///
/// ## Où le seam de coquille est posé, et pourquoi là
///
/// ```
/// _ZLiveRegion(liveAnnouncement)     <- AU-DESSUS du seam
///   └── _ZChatList
///         ├── zResolveChatShell(...) <- LE SEAM : le CONTENEUR, et rien d'autre
///         └── ListView.builder(...)  <- le defaut, si la chaine rend `null`
///               └── _item(context, i) <- LA FABRIQUE, partagee par les DEUX
/// ```
///
/// La fabrique [_ZChatList._item] est la même dans les deux branches. C'est
/// ce qui rend la non-perte structurelle plutôt que promise : une coquille
/// tierce ne construit ni la tuile, ni le dépli, ni la tuile de streaming —
/// elle les rappelle. Et la région live l'enveloppe, donc lui échappe.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../render/z_chat_render_request.dart';
import '../render/z_chat_seam_failure.dart';
import '../render/z_chat_shell_render_request.dart';
import '../render/z_chat_shell_renderer_scope.dart';
import '../z_chat_controller.dart';
import 'z_chat_block_view.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart';
import 'z_chat_tile_shell.dart';

/// Rend la conversation d'un [ZChatController] — zéro dépendance tierce.
///
/// Sans `ZChatRendererScope` au-dessus, cette vue est utilisable seule :
/// c'est le défaut fonctionnel qu'exige tout port de rendu de ce paquet.
class ZChatConversationView extends StatelessWidget {
  /// Construit la vue de conversation.
  const ZChatConversationView({
    required this.controller,
    this.collapsedMaxHeight,
    this.padding,
    this.reverse = false,
    this.identityBuilder,
    this.actionsBuilder,
    this.shell,
    this.composer,
    super.key,
  });

  /// Le contrôleur dont les tranches sont écoutées. Il n'est ni créé ni
  /// disposé ici : son cycle de vie appartient à l'hôte (invariant AD-2).
  final ZChatController controller;

  /// Hauteur repliée des tuiles. `null` signifie aucun repli (cf.
  /// [ZChatMessageTile]).
  final double? collapsedMaxHeight;

  /// Marge directionnelle de la liste (invariant AD-13).
  final EdgeInsetsDirectional? padding;

  /// Liste inversée (dernier message en bas, ancrage naturel d'un chat).
  final bool reverse;

  /// Créneau d'identité par message — relayé tel quel à la fabrique de tuile
  /// unique ([_ZChatList._item]). `null` (défaut) donne un rendu strictement
  /// inchangé. Cf. [ZChatMessageTile.identityBuilder].
  final ZChatMessageSlotBuilder? identityBuilder;

  /// Créneau d'actions par message — relayé tel quel à la fabrique de tuile
  /// unique. `null` (défaut) donne un rendu strictement inchangé. Cf.
  /// [ZChatMessageTile.actionsBuilder] — les verbes passent par
  /// `runAction(ZChatCustomAction(...))`, jamais par un canal parallèle.
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// La **coquille** relayée à la fabrique de tuile unique.
  ///
  /// `null` (défaut) laisse l'arbre strictement inchangé. Déclarée, elle
  /// apporte la carte, son filet, l'horodatage, le style du bouton de dépli,
  /// et la coiffe : [ZChatTileShell.topicOf] est résolu **ici**, parce que
  /// cette vue est la seule à voir le message qui précède.
  final ZChatTileShell? shell;

  /// La zone de saisie montée sous le fil — typiquement un `ZChatComposer`.
  ///
  /// `null` (défaut) laisse l'arbre strictement inchangé : la vue rend son
  /// fil, et rien d'autre — un hôte passif ne voit donc aucune différence.
  ///
  /// [ZChatNotebookView] relaie ce créneau tel quel : les deux surfaces
  /// passent donc par [_zChatComposeSurface], la fabrique unique.
  final Widget? composer;

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final Widget thread = ValueListenableBuilder<List<ZChatMessage>>(
      valueListenable: controller.messages,
      builder:
          (BuildContext context, List<ZChatMessage> messages, Widget? child) {
            return ValueListenableBuilder<List<String>>(
              valueListenable: controller.activeRequests,
              builder:
                  (BuildContext context, List<String> active, Widget? child) {
                    return _ZLiveRegion(
                      // La région live est au-dessus du seam : aucune
                      // coquille tierce ne peut la faire disparaître.
                      announcement: controller.liveAnnouncement,
                      child: _ZChatList(
                        controller: controller,
                        messages: messages,
                        activeRequestIds: active,
                        collapsedMaxHeight: collapsedMaxHeight,
                        padding: padding ?? theme.formPadding,
                        reverse: reverse,
                        identityBuilder: identityBuilder,
                        actionsBuilder: actionsBuilder,
                        shell: shell,
                      ),
                    );
                  },
            );
          },
    );
    // La fabrique unique de la zone de saisie — cf. son dartdoc. Le fil est
    // construit au-dessus d'elle : le composer est donc un frère des
    // tranches `messages`/`activeRequests`, jamais leur descendant (invariant
    // AD-2 — un tour ne le reconstruit pas).
    return _zChatComposeSurface(thread: thread, composer: composer);
  }
}

/// Compose le fil et la zone de saisie — le seul endroit du paquet qui place
/// un composer dans une surface.
///
/// [ZChatNotebookView] délègue à [ZChatConversationView], qui appelle cette
/// fonction : il n'existe donc aucun second endroit où monter une saisie.
/// Une régression ici affecte les deux surfaces à la fois — même patron que
/// la fabrique de tuile unique.
///
/// `composer == null` fait rendre [thread] tel quel — pas une `Column` d'un
/// seul enfant, pas un `SizedBox.shrink()` en second : rien (invariant
/// AD-4). L'arbre d'un hôte qui ne fournit pas de composer reste donc
/// identique à celui d'une vue sans ce paramètre.
Widget _zChatComposeSurface({required Widget thread, required Widget? composer}) {
  if (composer == null) return thread;
  return Column(
    children: <Widget>[
      // Le fil prend la place restante ; la saisie garde sa hauteur
      // naturelle.
      Expanded(child: thread),
      composer,
    ],
  );
}

/// Le conteneur de la conversation : coquille de l'hôte, sinon liste neutre.
///
/// Les deux branches partagent la même fabrique [_item] : c'est l'unique
/// raison pour laquelle brancher une coquille tierce ne peut rien faire
/// perdre. Dupliquer la construction des tuiles dans la coquille
/// recréerait exactement la divergence que cette architecture évite.
class _ZChatList extends StatelessWidget {
  const _ZChatList({
    required this.controller,
    required this.messages,
    required this.activeRequestIds,
    required this.collapsedMaxHeight,
    required this.padding,
    required this.reverse,
    required this.identityBuilder,
    required this.actionsBuilder,
    required this.shell,
  });

  final ZChatController controller;
  final List<ZChatMessage> messages;
  final List<String> activeRequestIds;
  final double? collapsedMaxHeight;
  final EdgeInsetsDirectional padding;
  final bool reverse;
  final ZChatMessageSlotBuilder? identityBuilder;
  final ZChatMessageSlotBuilder? actionsBuilder;
  final ZChatTileShell? shell;

  /// La tuile de l'index [index] — le seul constructeur de tuile du paquet.
  Widget _item(BuildContext context, int index) {
    if (index < messages.length) {
      final ZChatMessage message = messages[index];
      return ZChatMessageTile(
        key: ValueKey<String>(message.id ?? 'msg#$index'),
        message: message,
        collapsedMaxHeight: collapsedMaxHeight,
        // Les créneaux traversent la fabrique unique : une coquille tierce
        // qui rappelle `itemBuilder` les obtient donc aussi, sans rien
        // savoir d'eux. C'est ce qui rend la non-divergence structurelle :
        // il n'existe aucun second endroit où les brancher.
        identityBuilder: identityBuilder,
        actionsBuilder: actionsBuilder,
        shell: shell,
        // Le SUJET du tour, résolu ici : c'est le seul endroit qui voit le
        // message précédent. Une tuile, seule, ne peut pas savoir quelle
        // question l'a produite.
        topic: _topicOf(message, index),
      );
    }
    final int active = index - messages.length;
    // Invariant AD-10 : une coquille tierce indexe comme elle veut ; un
    // hors-bornes ne fait pas tomber la conversation.
    if (active < 0 || active >= activeRequestIds.length) {
      return const SizedBox.shrink();
    }
    final String requestId = activeRequestIds[active];
    return _ZStreamingTile(
      key: ValueKey<String>('stream#$requestId'),
      controller: controller,
      requestId: requestId,
    );
  }

  /// Le sujet du tour du message d'index [index], ou `null`.
  ///
  /// La **question** d'un tour est le message d'utilisateur le plus proche
  /// au-dessus : la recherche remonte le fil, jamais la position d'affichage
  /// — `reverse` retourne la liste à l'écran, pas l'ordre du dialogue.
  ///
  /// Chaîne totale (invariant AD-10) : un résolveur d'hôte qui lève perd la
  /// coiffe, jamais le message ; l'échec est relayé à `FlutterError` avec le
  /// nom du seam.
  String? _topicOf(ZChatMessage message, int index) {
    final ZChatTurnTopicResolver? resolver = shell?.topicOf;
    if (resolver == null) return null;
    ZChatMessage? request;
    for (int i = index - 1; i >= 0; i--) {
      if (messages[i].role == ZChatRole.user) {
        request = messages[i];
        break;
      }
    }
    try {
      return resolver(message, request);
    } catch (error, stack) {
      zChatReportSeamFailure(
        error: error,
        stack: stack,
        seam: kZChatSeamTopic,
      );
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ZChatShellRenderRequest request = ZChatShellRenderRequest(
      messages: messages,
      activeRequestIds: activeRequestIds,
      itemBuilder: _item,
      padding: padding,
      reverse: reverse,
    );
    // Chaîne totale : `null` signifie liste neutre — y compris quand la
    // coquille de l'hôte lève (invariant AD-10 ; l'exception est relayée à
    // `FlutterError`, cf. `zResolveChatShell`).
    final Widget? shell = zResolveChatShell(context, request);
    if (shell != null) return shell;
    return ListView.builder(
      // `.builder` — jamais `ListView(children: [...])`.
      padding: padding,
      reverse: reverse,
      itemCount: request.itemCount,
      itemBuilder: _item,
    );
  }
}

/// Région live : le libellé annoncé suit `liveAnnouncement`.
///
/// Le sous-arbre est passé en `child` du [ValueListenableBuilder] : une
/// annonce ne reconstruit pas la liste. Le nœud sémantique est porté par un
/// widget réellement dimensionné (la liste elle-même) — un
/// `SizedBox.shrink()` annoté n'aurait produit aucun nœud exploitable.
class _ZLiveRegion extends StatelessWidget {
  const _ZLiveRegion({required this.announcement, required this.child});

  final ValueListenable<String> announcement;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: announcement,
      builder: (BuildContext context, String text, Widget? child) {
        return Semantics(
          container: true,
          liveRegion: true,
          // Aucune annonce en cours ⇒ le nœud porte le libellé NEUTRE de la
          // région (clé résolue), jamais une phrase écrite en dur.
          label: text.isEmpty ? zChatLabel(context, kZChatLabelLiveRegion) : text,
          child: child,
        );
      },
      child: child,
    );
  }
}

/// La tuile d'une réponse en cours — le seul point abonné au canal à haute
/// fréquence.
///
/// Elle passe par la couture de bloc plutôt que de rendre un `Text` en dur :
/// un rendu riche fourni par l'hôte (Markdown, LaTeX) atteint ainsi la
/// réponse en train d'arriver, pas seulement les messages déjà établis. Le
/// texte traverse `ZChatBlockView` comme n'importe quel bloc, avec son canal
/// `ValueListenable` — un renderer d'hôte peut le prendre, et prendra
/// lui-même l'abonnement dans son sous-arbre (invariant AD-2 préservé).
class _ZStreamingTile extends StatelessWidget {
  const _ZStreamingTile({
    required this.controller,
    required this.requestId,
    super.key,
  });

  final ZChatController controller;
  final String requestId;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: zChatLabel(context, kZChatLabelStreaming),
      child: ConstrainedBox(
        // Invariant AD-13 : la région reste atteignable et annonçable même
        // vide — une bulle de quelques pixels de haut n'est ni pointable ni
        // repérable.
        constraints: const BoxConstraints(minHeight: kZChatMinTapTarget),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ZChatBlockView(
            request: ZChatBlockRenderRequest(
              // Un bloc de texte **vide** porteur du canal : c'est la tranche
              // qui porte le contenu, pas la valeur figée du bloc.
              block: const ZTextBlock(),
              message: ZChatMessage(
                id: requestId,
                conversationId: controller.conversationId,
                role: ZChatRole.assistant,
              ),
              isStreaming: true,
              // La tranche par requête, pas un canal global : un jeton d'une
              // requête ne reconstruit rien de ce qui appartient à une
              // autre. Elle est passée en `ValueListenable` — l'abonnement
              // est pris sous le seam, jamais ici.
              streamingText: controller.streamText(requestId),
            ),
          ),
        ),
      ),
    );
  }
}
