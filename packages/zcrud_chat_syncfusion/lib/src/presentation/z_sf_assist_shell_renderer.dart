/// Backend Syncfusion du port `ZChatShellRenderer` — CHAT-3b (ex-CHAT-6).
///
/// ## 🔴 Ce que ce fichier REMPLACE, et pourquoi c'était un doublon
///
/// C6 avait livré `ZSfAssistConversationView` : un widget **parallèle** à
/// `ZChatConversationView`, faute d'une couture au niveau LISTE. Conséquence
/// **mesurée** : un hôte qui choisissait Syncfusion **perdait** la région live
/// (`liveAnnouncement`), le dépli inline et `ZChatMessageTile` — la coquille ne
/// réimplémentait aucun des trois. Et les deux vues étaient promises à diverger,
/// motif **CR-LEX-78** que ce dépôt a déjà payé.
///
/// `ZSfAssistShellRenderer` n'est plus une vue : c'est un **backend du port**.
/// Il rend le **CADRE** (`SfAIAssistView`) et rappelle, pour chaque index, la
/// fabrique du socle (`request.itemBuilder`). Tout ce qui n'est pas le cadre —
/// région live, tuile, dépli, seam de blocs de l'hôte, tranche de streaming par
/// requête — reste produit par `zcrud_chat` et lui est **hors d'atteinte**.
///
/// Ce que la consommation du seam a **supprimé** :
/// * `ZSfAssistConversationView` (217 lignes) — la vue parallèle ;
/// * son `_ZSfStreamingBody` — la tuile de streaming recopiée, avec son propre
///   `Semantics`, sa propre contrainte de 48 dp et son propre abonnement
///   (contrainte **remontée** dans le rendu neutre, où elle vaut pour les deux
///   chemins) ;
/// * son `_accessibleSummary` — le résumé accessible local qui ne connaissait
///   que `ZTextBlock` (**tableaux et sources non annoncés**), remplacé par
///   `ZContentBlock.accessibleText` du kernel, exhaustif par construction ;
/// * son paramètre `streamingText` — le texte en cours passait HORS de la
///   couture, il la traverse désormais ;
/// * `ZSfAssistRenderer` — un renderer de BLOCS qui déclinait tout et ne
///   servait qu'à rechaîner celui de l'hôte. Les deux ports vivant dans deux
///   scopes **indépendants**, le seam de bloc n'a jamais été intercepté : le
///   chaînage manuel n'avait plus d'objet.
///
/// ## La surface Syncfusion adaptée, et pourquoi pas davantage
///
/// IFFD ne consomme de `SfAIAssistView` que le **squelette de liste** :
/// `messages:`, `composer: AssistComposer.builder(...)`, `placeholderBehavior`,
/// `placeholderBuilder` (`chatbot_conversation_screen.dart:3417-3436`). On
/// adapte ces quatre membres plus `messageContentBuilder` — par lequel le
/// contenu repart vers le socle. Cinq membres, pas un de plus.
///
/// Délibérément laissés à l'hôte (`AssistMessageSettings`,
/// `AssistMessageToolbarSettings`, `messageHeaderBuilder`,
/// `messageAvatarBuilder`, `responseLoadingBuilder`, `onToolbarItemSelected`,
/// `actionButton`) : ce sont des choix d'**apparence et d'actions produit**, et
/// FR-26 interdit au socle de décider d'une couleur ou d'un libellé.
///
/// 🔴 **`data:` n'est jamais le corps rendu.** Syncfusion exige un `String` pour
/// `AssistMessage.data` ; on lui donne le **résumé accessible du kernel**, et le
/// corps visible vient de `messageContentBuilder`. Aplatir les blocs en texte
/// pour l'affichage, c'est perdre tableaux, sources et diagrammes — ce que fait
/// IFFD.
///
/// ⚠️ **HIGH-2 — et `data:` n'est PAS NON PLUS la voie d'annonce.**
/// `syncfusion_flutter_chat` ne lit `AssistMessage.data` que dans la branche
/// `else` de son constructeur de contenu, celle qu'un `messageContentBuilder`
/// **court-circuite toujours** — et nous en fournissons un systématiquement. Le
/// champ est donc **inerte** pour un lecteur d'écran. Le résumé y reste (c'est
/// la donnée que le modèle de Syncfusion exige, et un futur usage tiers la
/// lira), mais l'annonce réelle est portée par le `Semantics` de
/// `ZChatMessageTile`, dans `zcrud_chat`, sur le chemin commun aux deux
/// branches de rendu. Les gardes de ce paquet assertent désormais l'**arbre
/// sémantique fusionné**, pas la propriété de widget : la version « propriété »
/// serait restée verte alors même que personne n'entendait rien.
library;

import 'package:flutter/widgets.dart';
import 'package:syncfusion_flutter_chat/assist_view.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

import 'z_sf_assist_labels.dart';

/// Rend le **cadre** d'une conversation avec `SfAIAssistView`.
///
/// Injecté par l'hôte via `ZChatShellRendererScope` :
///
/// ```dart
/// ZChatShellRendererScope(
///   renderer: const ZSfAssistShellRenderer(),
///   child: ZChatConversationView(controller: c),
/// )
/// ```
///
/// AD-2 : aucun gestionnaire d'état, aucun `setState` d'échelle conversation —
/// l'état reste dans le `ZChatController` du socle.
class ZSfAssistShellRenderer extends ZChatShellRenderer {
  /// Construit le backend. `const` : il est comparé par **identité** par
  /// `ZChatShellRendererScope.updateShouldNotify`.
  const ZSfAssistShellRenderer({
    this.composerBuilder,
    this.placeholderBuilder,
    this.accessibleTextResolver,
  });

  /// Constructeur du composeur (`AssistComposer.builder`) — l'hôte décide de
  /// son champ de saisie, de ses boutons et de ses libellés.
  ///
  /// `null` ⇒ aucun composeur (conversation en lecture seule).
  final WidgetBuilder? composerBuilder;

  /// Contenu affiché tant qu'aucun message n'existe.
  ///
  /// `null` ⇒ pas de placeholder. Aucun texte n'est inventé ici (FR-26).
  final WidgetBuilder? placeholderBuilder;

  /// Surcharge **locale** du seam d'annonce (AD-4/FR-26).
  ///
  /// C'est par lui qu'un hôte annonce **son** bloc ouvert
  /// (`'legalReference'`, `'flashcards'`, `'mindmap'`) et **localise** ce qui
  /// doit l'être : le kernel, pur-Dart, n'émet que de la donnée.
  ///
  /// 🔴 **Le point d'injection de référence est `ZChatAccessibleTextScope`**, et
  /// c'est lui qu'il faut préférer : le résolveur doit alimenter **deux**
  /// consommateurs — ce champ `data` (inerte pour un lecteur d'écran) et le
  /// nœud `Semantics` de `ZChatMessageTile` (celui qui est réellement énoncé).
  /// Renseigner ce champ **seul** annoncerait un résumé au champ mort et un
  /// autre à l'utilisateur : la divergence exacte que CHAT-3b avait supprimée.
  /// `null` ⇒ le résolveur du scope, sinon le résumé du kernel seul.
  final ZAccessibleTextResolver? accessibleTextResolver;

  @override
  Widget? buildShell(BuildContext context, ZChatShellRenderRequest request) {
    final String userName = zSfAssistLabel(context, kZSfAssistLabelUserAuthor);
    final String assistantName = zSfAssistLabel(context, kZSfAssistLabelAssistantAuthor);

    final List<AssistMessage> assistMessages = <AssistMessage>[
      for (final ZChatMessage m in request.messages)
        if (m.role == ZChatRole.user)
          AssistMessage.request(
            data: _summary(context, m),
            time: m.createdAt,
            author: AssistMessageAuthor(id: m.id, name: userName),
          )
        else
          AssistMessage.response(
            data: _summary(context, m),
            time: m.createdAt,
            author: AssistMessageAuthor(id: m.id, name: assistantName),
          ),
      for (final String requestId in request.activeRequestIds)
        // 🔴 `data` VIDE, et c'est correct : le texte en cours n'est PAS une
        // donnée figée. Il arrive par la tranche `ValueListenable` que le socle
        // fait traverser la couture de bloc — s'il transitait par `data`, la
        // liste entière se reconstruirait à chaque jeton (SM-1).
        AssistMessage.response(
          data: '',
          author: AssistMessageAuthor(id: requestId, name: assistantName),
        ),
    ];

    return SfAIAssistView(
      messages: assistMessages,
      composer: composerBuilder == null
          ? null
          : AssistComposer.builder(builder: composerBuilder!),
      placeholderBehavior: AssistPlaceholderBehavior.hideOnMessage,
      placeholderBuilder: placeholderBuilder,
      // 🔴 LE point où la coquille rend la main. Elle ne construit AUCUNE tuile :
      // elle rappelle la fabrique du socle. C'est ce qui rend la non-perte
      // structurelle — région live, dépli inline, tuile et seam de blocs sont
      // hors de sa portée.
      messageContentBuilder: (BuildContext context, int index, _) =>
          request.itemBuilder(context, index),
    );
  }

  /// Résumé **accessible** d'un message pour `AssistMessage.data`.
  ///
  /// 🔴 Il vient du **kernel** (`accessibleText`, `switch` exhaustif sur l'union
  /// scellée), plus d'un résumé local. C6 en avait écrit un qui ne connaissait
  /// que `ZTextBlock` : un tableau ou un bloc de sources n'était annoncé
  /// **nulle part**. Régler cela une fois, côté kernel, vaut pour tout
  /// adaptateur présent et futur.
  String _summary(BuildContext context, ZChatMessage message) =>
      zChatAccessibleTextOf(
        message.contentBlocks,
        // 🔴 UN seul résolveur pour les deux consommateurs : la surcharge
        // locale d'abord, sinon celui du scope — jamais deux résumés distincts
        // entre ce champ et le nœud `Semantics` de la tuile.
        resolver:
            accessibleTextResolver ??
            ZChatAccessibleTextScope.resolverOf(context),
      );
}
