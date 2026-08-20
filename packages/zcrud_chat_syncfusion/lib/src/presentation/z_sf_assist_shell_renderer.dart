/// Backend Syncfusion du port `ZChatShellRenderer`.
///
/// `ZSfAssistShellRenderer` n'est pas une vue de conversation : c'est un
/// backend de port. Il rend le cadre (`SfAIAssistView`) et rappelle, pour
/// chaque index, la fabrique de tuile du socle (`request.itemBuilder`).
/// Tout ce qui n'est pas le cadre — région live d'accessibilité, dépli
/// inline, port de rendu de bloc de l'hôte, tranche de streaming par
/// requête — reste produit par `zcrud_chat` et hors d'atteinte de cette
/// coquille. Une vue de conversation qui réimplémenterait elle-même ces
/// pièces en perdrait la cohérence avec le rendu neutre, et divergerait
/// dans le temps.
///
/// ## La surface Syncfusion adaptée, et pourquoi pas davantage
///
/// Cinq membres de `SfAIAssistView` sont adaptés : `messages`, `composer`,
/// `placeholderBehavior`, `placeholderBuilder`, et
/// `messageContentBuilder` — par lequel le contenu repart vers le socle.
/// `requestMessageSettings`/`responseMessageSettings` s'y ajoutent, mais
/// uniquement si l'hôte fournit un [ZSfAssistShellRenderer.notebookSkin] ;
/// sans skin, ils valent `const AssistMessageSettings()`, le défaut de
/// Syncfusion, laissant l'arbre inchangé pour un hôte qui n'a rien demandé.
///
/// Délibérément laissés à l'hôte (réglages de barre d'outils de message,
/// constructeurs d'en-tête/avatar/chargement, sélection d'action) : ce sont
/// des choix d'apparence et d'actions produit, hors du rôle de ce backend.
///
/// ## `AssistMessage.data` n'est ni le corps rendu ni la voie d'annonce
///
/// Syncfusion exige un `String` pour `AssistMessage.data` ; ce backend lui
/// donne le résumé accessible du kernel, et le corps visible vient de
/// `messageContentBuilder`. Aplatir les blocs en texte pour l'affichage
/// perdrait tableaux, sources et diagrammes.
///
/// `data` n'est pas non plus la voie d'annonce à l'accessibilité :
/// `syncfusion_flutter_chat` ne le lit que dans la branche de son
/// constructeur de contenu qu'un `messageContentBuilder` fourni
/// systématiquement court-circuite toujours. Le champ est donc inerte pour
/// un lecteur d'écran ; l'annonce réelle est portée par le `Semantics` de
/// `ZChatMessageTile`, dans `zcrud_chat`, sur le chemin commun aux deux
/// branches de rendu. Les gardes de ce paquet vérifient donc l'arbre
/// sémantique effectivement rendu, pas la seule valeur de la propriété
/// `data`.
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
/// Invariant AD-2 : aucun gestionnaire d'état, aucun `setState` d'échelle
/// conversation — l'état reste dans le `ZChatController` du socle.
class ZSfAssistShellRenderer extends ZChatShellRenderer {
  /// Construit le backend. `const` : il est comparé par identité par
  /// `ZChatShellRendererScope.updateShouldNotify`.
  const ZSfAssistShellRenderer({
    this.composerBuilder,
    this.placeholderBuilder,
    this.accessibleTextResolver,
    this.notebookSkin,
  });

  /// Constructeur du composeur (`AssistComposer.builder`) — l'hôte décide de
  /// son champ de saisie, de ses boutons et de ses libellés.
  ///
  /// `null` ⇒ aucun composeur (conversation en lecture seule).
  final WidgetBuilder? composerBuilder;

  /// Contenu affiché tant qu'aucun message n'existe.
  ///
  /// `null` ⇒ pas de placeholder. Aucun texte n'est inventé ici.
  final WidgetBuilder? placeholderBuilder;

  /// Surcharge locale du résolveur de texte accessible (invariant AD-4).
  ///
  /// C'est par lui qu'un hôte annonce son propre bloc ouvert et localise ce
  /// qui doit l'être : le kernel, pur-Dart, n'émet que de la donnée.
  ///
  /// Le point d'injection de référence reste `ZChatAccessibleTextScope`,
  /// à préférer à ce champ : le résolveur doit alimenter deux
  /// consommateurs — le résumé de `AssistMessage.data` (inerte pour un
  /// lecteur d'écran) et le nœud `Semantics` de `ZChatMessageTile` (celui
  /// qui est réellement énoncé). Renseigner ce champ seul annoncerait un
  /// résumé au champ mort et un autre à l'utilisateur. `null` ⇒ le
  /// résolveur du scope, sinon le résumé du kernel seul.
  final ZAccessibleTextResolver? accessibleTextResolver;

  /// Skin de référence du notebook, opt-in.
  ///
  /// `null` (le défaut) ⇒ aucun réglage de bulle n'est posé : les deux
  /// `AssistMessageSettings` restent ceux de Syncfusion, à l'octet près, et
  /// l'arbre d'un hôte qui n'a rien demandé est inchangé.
  ///
  /// Renseigné, il apporte la fraction de largeur de bulle, le rayon de la
  /// bulle de requête, et le masquage avatar/nom d'une référence de
  /// notebook. Il n'y a pas de rayon de réponse dans cette référence : en
  /// inventer un serait une valeur que personne n'a mesurée. Le format
  /// d'horodatage n'est pas non plus repris : `timestampFormat` reste nul,
  /// et la coquille suit la locale plutôt qu'un format figé.
  ///
  /// Le skin est un objet pur de `zcrud_chat` : la chaîne de résolution
  /// paramètre > jeton > référence est arbitrée là-bas, sans Syncfusion. Ce
  /// fichier ne fait que mapper le résultat.
  final ZChatNotebookSkin? notebookSkin;

  /// Traduit un style résolu en réglages Syncfusion. `shape` n'est posé que
  /// si un rayon existe (invariant AD-4 : rien de nul n'entre dans l'arbre).
  ///
  /// La géométrie directionnelle est résolue **avant** de franchir la couture :
  /// `syncfusion_flutter_chat` 34.1.31 peint son `ShapeBorder` par
  /// `getOuterPath(bounds)`/`paint(canvas, bounds)` sans transmettre de
  /// `TextDirection`. Lui remettre un `BorderRadiusDirectional` interrompt
  /// donc la peinture avant même `paintChild`, bien que le contenu soit monté
  /// et dimensionné. Résoudre ici conserve la décision RTL de l'hôte tout en
  /// donnant au backend tiers une forme autonome à la peinture.
  AssistMessageSettings _settings({
    required ZChatNotebookStyle style,
    required Radius? radius,
    required TextDirection textDirection,
  }) => AssistMessageSettings(
    widthFactor: style.bubbleWidthFactor,
    showAuthorAvatar: style.showAuthorAvatar,
    showAuthorName: style.showAuthorName,
    showTimestamp: style.showTimestamp,
    shape: radius == null
        ? null
        : RoundedRectangleBorder(
            borderRadius: BorderRadiusDirectional.all(
              radius,
            ).resolve(textDirection),
          ),
  );

  @override
  Widget? buildShell(BuildContext context, ZChatShellRenderRequest request) {
    final String userName = zSfAssistLabel(context, kZSfAssistLabelUserAuthor);
    final String assistantName = zSfAssistLabel(
      context,
      kZSfAssistLabelAssistantAuthor,
    );

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
        // `data` vide, et c'est correct : le texte en cours n'est pas une
        // donnée figée. Il arrive par la tranche `ValueListenable` que le
        // socle fait traverser le port de rendu de bloc — s'il transitait
        // par `data`, la liste entière se reconstruirait à chaque jeton.
        AssistMessage.response(
          data: '',
          author: AssistMessageAuthor(id: requestId, name: assistantName),
        ),
    ];

    // `null` ⇒ on passe le même objet que le défaut de `SfAIAssistView`
    // (`const AssistMessageSettings()`), donc l'arbre est inchangé pour un
    // hôte qui n'a rien demandé. Résoudre systématiquement le skin de
    // référence l'aurait imposé à tout le monde.
    final ZChatNotebookStyle? style = notebookSkin?.resolve(context);

    return SfAIAssistView(
      messages: assistMessages,
      requestMessageSettings: style == null
          ? const AssistMessageSettings()
          : _settings(
              style: style,
              radius: style.requestBubbleRadius,
              textDirection: Directionality.of(context),
            ),
      responseMessageSettings: style == null
          ? const AssistMessageSettings()
          : _settings(
              style: style,
              radius: style.responseBubbleRadius,
              textDirection: Directionality.of(context),
            ),
      composer: composerBuilder == null
          ? null
          : AssistComposer.builder(builder: composerBuilder!),
      placeholderBehavior: AssistPlaceholderBehavior.hideOnMessage,
      placeholderBuilder: placeholderBuilder,
      // Le point où la coquille rend la main. Elle ne construit aucune
      // tuile elle-même : elle rappelle la fabrique du socle, ce qui garde
      // la région live, le dépli inline, la tuile et le port de rendu de
      // bloc hors de sa portée.
      messageContentBuilder: (BuildContext context, int index, _) =>
          request.itemBuilder(context, index),
    );
  }

  /// Résumé accessible d'un message pour `AssistMessage.data`.
  ///
  /// Il vient du kernel (`accessibleText`, exhaustif sur la famille de
  /// blocs), et non d'un résumé local qui ne connaîtrait qu'un sous-ensemble
  /// des variantes de bloc — un tableau ou un bloc de sources ne serait
  /// alors annoncé nulle part.
  String _summary(BuildContext context, ZChatMessage message) =>
      zChatAccessibleTextOf(
        message.contentBlocks,
        // Un seul résolveur pour les deux consommateurs : la surcharge
        // locale d'abord, sinon celui du scope — jamais deux résumés
        // distincts entre ce champ et le nœud `Semantics` de la tuile.
        resolver:
            accessibleTextResolver ??
            ZChatAccessibleTextScope.resolverOf(context),
      );
}
