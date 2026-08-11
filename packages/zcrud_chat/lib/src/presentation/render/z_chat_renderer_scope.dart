/// Injection du port de rendu et chaîne totale de résolution.
///
/// Suit le patron du résolveur de dégradé du cœur : une chaîne totale seam de
/// l'hôte vers `null`, qui ne lève jamais et dont `null` est une valeur
/// fonctionnelle.
///
/// Ce scope vit dans ce paquet plutôt que comme champ additionnel de
/// `ZcrudScope`. `ZcrudScope` porte déjà les renderers de liste, de réordonnancement
/// et de zone de dépôt du cœur : y ajouter un renderer de chat suivrait le même
/// geste — mais cela ferait connaître au cœur un type de `zcrud_chat_kernel`
/// (`ZContentBlock` traverse la signature du port), en violation de
/// l'invariant AD-1. Le scope vit donc dans le paquet qui possède le
/// vocabulaire ; les deux s'empilent sans se gêner (`ZcrudScope` pour
/// thème/libellés, celui-ci pour le renderer).
library;

import 'package:flutter/widgets.dart';

import 'z_chat_render_request.dart';
import 'z_chat_renderer.dart';
import 'z_chat_seam_failure.dart';

/// Porte le [ZChatRenderer] injecté par l'hôte jusqu'au rendu des blocs.
class ZChatRendererScope extends InheritedWidget {
  /// Injecte [renderer] pour le sous-arbre [child].
  const ZChatRendererScope({
    required this.renderer,
    required super.child,
    super.key,
  });

  /// Le renderer de l'hôte. `null` signifie rendu neutre partout (état par
  /// défaut, strictement identique à l'absence de scope).
  final ZChatRenderer? renderer;

  /// Le scope le plus proche, ou `null` — jamais de `throw` (invariant AD-10).
  static ZChatRendererScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZChatRendererScope>();

  @override
  bool updateShouldNotify(ZChatRendererScope oldWidget) =>
      !identical(renderer, oldWidget.renderer);
}

/// Chaîne totale : seam de l'hôte vers `null`.
///
/// Aucune requête n'est rejetée, aucun déréférencement nul n'est possible :
/// scope absent, renderer absent, ou renderer qui décline rendent tous `null`
/// sans lever. `null` signifie « rendu neutre », ce qui garantit qu'un
/// consommateur non configuré rend exactement comme si ce port n'existait
/// pas.
///
/// Invariant AD-10 : le code arbitraire de l'hôte qui lève vaut « je
/// décline », et la chaîne retombe sur le rendu neutre plutôt que de faire
/// tomber tout l'écran. Cette lecture est appliquée de façon homogène aux
/// trois seams de rendu de ce paquet (bloc, coquille, annonce), pour éviter
/// qu'un même défaut d'hôte produise un écran rouge sur l'un et une
/// dégradation silencieuse sur l'autre.
///
/// Ce n'est pas un étouffement silencieux : l'exception est relayée à
/// `FlutterError.reportError`, donc elle apparaît en console et dans les
/// rapports de crash de l'hôte, avec sa pile complète — elle reste débogable.
/// Ce qu'elle ne fait plus, c'est emporter la conversation.
Widget? zResolveChatBlock(
  BuildContext context,
  ZChatBlockRenderRequest request,
) {
  final ZChatRenderer? renderer = ZChatRendererScope.maybeOf(context)?.renderer;
  if (renderer == null) return null;
  try {
    return renderer.buildBlock(context, request);
  } catch (error, stack) {
    zChatReportSeamFailure(
      error: error,
      stack: stack,
      seam: kZChatSeamBlock,
    );
    return null;
  }
}
