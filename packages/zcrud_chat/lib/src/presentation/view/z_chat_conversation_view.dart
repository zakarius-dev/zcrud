/// Rendu neutre d'une conversation — `ZChatConversationView` (CHAT-3).
///
/// ## Trois dettes d'IFFD, chiffrées, que cette vue ne reproduit pas
///
/// 1. **`ListView.builder` → 0 occurrence** dans les 5153 lignes de
///    `chatbot_conversation_screen.dart`. Une conversation non virtualisée
///    monte *toutes* ses bulles — chacune portant un lecteur riche — et viole
///    SM-1, l'objectif produit n°1 du dépôt. Ici la liste est **bâtie
///    paresseusement** (`SliverChildBuilderDelegate`), et la garde le prouve
///    **par ce mécanisme**, jamais en comptant des tuiles montées : le viewport
///    culle des deux côtés et un comptage a déjà été pris en défaut ici.
/// 2. **`Semantics` → 0 occurrence** sur tout le chat d'IFFD : une réponse qui
///    arrive en streaming y est **muette** pour un lecteur d'écran. Ici la liste
///    est une **région live** dont le libellé suit `controller.liveAnnouncement`
///    — la tranche que le contrôleur ne fait bouger qu'aux **jalons**, jamais à
///    chaque jeton (une région live qui parle 300 fois par tour est
///    inutilisable).
/// 3. **Reconstruction O(n²) à chaque fragment SSE.** L'abonnement au texte à
///    haute fréquence est pris **à l'intérieur** de l'`itemBuilder`, sur
///    `controller.streamText(requestId)` — la tranche **par requête**. Un jeton
///    reconstruit la **tuile en cours**, pas la conversation. Les tranches
///    grossières (`messages`, `activeRequests`) sont écoutées au-dessus, mais
///    elles ne changent qu'aux **transitions de tour**.
///
/// ## 🔴 CHAT-3b — où le seam de COQUILLE est posé, et pourquoi là
///
/// ```
/// _ZLiveRegion(liveAnnouncement)     ← AU-DESSUS du seam
///   └── _ZChatList
///         ├── zResolveChatShell(...) ← LE SEAM : le CONTENEUR, et rien d'autre
///         └── ListView.builder(...)  ← le défaut, si la chaîne rend `null`
///               └── _item(context, i) ← LA FABRIQUE, partagée par les DEUX
/// ```
///
/// La fabrique [_ZChatList._item] est **la même** dans les deux branches. C'est
/// ce qui rend la non-perte **structurelle** plutôt que promise : une coquille
/// tierce ne construit ni la tuile, ni le dépli, ni la tuile de streaming — elle
/// les **rappelle**. Et la région live l'enveloppe, donc lui échappe.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../render/z_chat_render_request.dart';
import '../render/z_chat_shell_render_request.dart';
import '../render/z_chat_shell_renderer_scope.dart';
import '../z_chat_controller.dart';
import 'z_chat_block_view.dart';
import 'z_chat_labels.dart';
import 'z_chat_message_tile.dart';

/// Rend la conversation d'un [ZChatController] — **zéro dépendance tierce**.
///
/// Sans `ZChatRendererScope` au-dessus, cette vue est **utilisable seule** :
/// c'est le défaut fonctionnel qu'AD-57 exige de tout port.
class ZChatConversationView extends StatelessWidget {
  /// Construit la vue de conversation.
  const ZChatConversationView({
    required this.controller,
    this.collapsedMaxHeight,
    this.padding,
    this.reverse = false,
    this.identityBuilder,
    this.actionsBuilder,
    this.composer,
    super.key,
  });

  /// Le contrôleur dont les tranches sont écoutées. Il n'est **ni créé ni
  /// disposé** ici : son cycle de vie appartient à l'hôte (AD-2).
  final ZChatController controller;

  /// Hauteur repliée des tuiles. `null` ⇒ aucun repli (cf. [ZChatMessageTile]).
  final double? collapsedMaxHeight;

  /// Marge **directionnelle** de la liste (AD-13).
  final EdgeInsetsDirectional? padding;

  /// Liste inversée (dernier message en bas, ancrage naturel d'un chat).
  final bool reverse;

  /// Créneau d'**identité par message** (CR-IFFD-71) — relayé tel quel à la
  /// fabrique de tuile UNIQUE ([_ZChatList._item]). `null` (défaut) ⇒ rendu
  /// strictement inchangé. Cf. [ZChatMessageTile.identityBuilder].
  final ZChatMessageSlotBuilder? identityBuilder;

  /// Créneau d'**actions par message** (CR-IFFD-71) — relayé tel quel à la
  /// fabrique de tuile UNIQUE. `null` (défaut) ⇒ rendu strictement inchangé.
  /// Cf. [ZChatMessageTile.actionsBuilder] — les verbes passent par
  /// `runAction(ZChatCustomAction(...))`, jamais par un canal parallèle.
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// La **zone de saisie** montée sous le fil — typiquement un `ZChatComposer`
  /// (lot α, CR-IFFD-72).
  ///
  /// 🔴 `null` (défaut) ⇒ **l'arbre est STRICTEMENT celui d'avant le lot** : la
  /// vue rend son fil, et rien d'autre. Un hôte passif ne voit donc aucune
  /// différence — c'est ce qu'assertent les gardes CMP-P1/CMP-P2, et c'est la
  /// leçon de l'incident du 2026-08-01 sur ce volet (un paramètre rendu
  /// obligatoire avait laissé le paquet rouge).
  ///
  /// [ZChatNotebookView] relaie ce créneau **tel quel** : les deux surfaces
  /// passent donc par [_zChatComposeSurface], la fabrique UNIQUE.
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
                      // 🔴 La région live est AU-DESSUS du seam : aucune
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
                      ),
                    );
                  },
            );
          },
    );
    // 🔴 LA fabrique UNIQUE de la zone de saisie — cf. son dartdoc. Le fil est
    // construit AU-DESSUS d'elle : le composer est donc un FRÈRE des tranches
    // `messages`/`activeRequests`, jamais leur descendant (SM-1 — un tour ne le
    // reconstruit pas).
    return _zChatComposeSurface(thread: thread, composer: composer);
  }
}

/// Compose le fil et la zone de saisie — **le SEUL endroit du paquet** qui
/// place un composer dans une surface.
///
/// 🔴 C'est l'anti-divergence, au patron exact de la fabrique de tuile
/// (`_ZChatList._item`, garde G-S5/G-N1) : [ZChatNotebookView] délègue à
/// [ZChatConversationView], qui appelle cette fonction — il n'existe donc
/// **aucun second endroit** où monter une saisie. Une régression ici fait
/// rougir les DEUX surfaces ensemble (gardes CMP-N1a/CMP-N1b), et c'est ce que
/// l'injection R3 du lot démontre.
///
/// 🔴 `composer == null` ⇒ **[thread] est rendu tel quel**. Pas une `Column`
/// d'un seul enfant, pas un `SizedBox.shrink()` en second : rien (AD-4).
/// L'arbre de l'hôte passif est identique à celui d'avant le lot.
Widget _zChatComposeSurface({required Widget thread, required Widget? composer}) {
  if (composer == null) return thread;
  return Column(
    children: <Widget>[
      // Le fil prend la place restante ; la saisie garde SA hauteur naturelle —
      // c'est la disposition des deux hôtes (lex et IFFD).
      Expanded(child: thread),
      composer,
    ],
  );
}

/// Le CONTENEUR de la conversation : coquille de l'hôte, sinon liste neutre.
///
/// 🔴 Les deux branches partagent **la même** fabrique [_item] : c'est
/// l'unique raison pour laquelle brancher une coquille tierce ne peut RIEN
/// faire perdre. Dupliquer la construction des tuiles dans la coquille — ce que
/// faisait le widget parallèle de C6 — recréerait la divergence que ce lot
/// supprime.
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
  });

  final ZChatController controller;
  final List<ZChatMessage> messages;
  final List<String> activeRequestIds;
  final double? collapsedMaxHeight;
  final EdgeInsetsDirectional padding;
  final bool reverse;
  final ZChatMessageSlotBuilder? identityBuilder;
  final ZChatMessageSlotBuilder? actionsBuilder;

  /// La tuile de l'index [index] — **le seul** constructeur de tuile du package.
  Widget _item(BuildContext context, int index) {
    if (index < messages.length) {
      final ZChatMessage message = messages[index];
      return ZChatMessageTile(
        key: ValueKey<String>(message.id ?? 'msg#$index'),
        message: message,
        collapsedMaxHeight: collapsedMaxHeight,
        // CR-IFFD-71 — les créneaux traversent LA fabrique unique : une
        // coquille tierce (Syncfusion) qui rappelle `itemBuilder` les obtient
        // donc AUSSI, sans rien savoir d'eux. C'est ce qui rend l'anti-
        // divergence structurelle : il n'existe aucun second endroit où les
        // brancher.
        identityBuilder: identityBuilder,
        actionsBuilder: actionsBuilder,
      );
    }
    final int active = index - messages.length;
    // AD-10 : une coquille tierce indexe comme elle veut ; un hors-bornes ne
    // fait pas tomber la conversation.
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

  @override
  Widget build(BuildContext context) {
    final ZChatShellRenderRequest request = ZChatShellRenderRequest(
      messages: messages,
      activeRequestIds: activeRequestIds,
      itemBuilder: _item,
      padding: padding,
      reverse: reverse,
    );
    // 🔴 Chaîne TOTALE : `null` ⇒ liste neutre — y compris quand la coquille de
    // l'hôte LÈVE (arbitrage AD-10 tranché en fin d'epic ; l'exception est
    // relayée à `FlutterError`, cf. `zResolveChatShell`).
    final Widget? shell = zResolveChatShell(context, request);
    if (shell != null) return shell;
    return ListView.builder(
      // 🔴 `.builder` — JAMAIS `ListView(children: [...])`.
      padding: padding,
      reverse: reverse,
      itemCount: request.itemCount,
      itemBuilder: _item,
    );
  }
}

/// Région live : le libellé annoncé suit `liveAnnouncement`.
///
/// 🔴 Le sous-arbre est passé en `child` du [ValueListenableBuilder] : une
/// annonce **ne reconstruit pas la liste**. Le nœud sémantique est porté par un
/// widget **réellement dimensionné** (la liste elle-même) — un
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

/// La tuile d'une réponse **en cours** — le seul point abonné au canal à haute
/// fréquence.
///
/// 🔴 **CHAT-3b — elle passe désormais PAR la couture de bloc.** Elle rendait un
/// `Text` en dur : le rendu riche d'un hôte (Markdown, LaTeX) n'atteignait donc
/// **jamais** la réponse en train d'arriver, et l'adaptateur C6 avait dû sortir
/// ce texte de la couture pour le passer en paramètre de sa vue. Le texte
/// traverse maintenant `ZChatBlockView` comme n'importe quel bloc, avec son
/// canal `ValueListenable` — un renderer d'hôte peut le prendre, et prendra
/// **lui-même** l'abonnement dans son sous-arbre (SM-1 préservé).
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
        // AD-13 : la région reste atteignable et annonçable même vide — une
        // bulle de 4 dp de haut n'est ni pointable ni repérable. Contrainte
        // remontée du satellite Syncfusion (C6) vers le rendu neutre : elle
        // valait pour les DEUX chemins.
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
              // 🔴 La tranche **PAR REQUÊTE**, pas un canal global : un jeton
              // d'une requête ne reconstruit rien de ce qui appartient à une
              // autre. Elle est passée en `ValueListenable` — l'abonnement est
              // pris SOUS le seam, jamais ici.
              streamingText: controller.streamText(requestId),
            ),
          ),
        ),
      ),
    );
  }
}
