/// Injection du port de coquille et chaîne totale de résolution.
///
/// Suit le patron du résolveur de dégradé du cœur, et le même principe que
/// `zResolveChatBlock` : une chaîne totale seam de l'hôte vers `null`, qui ne
/// lève jamais et dont `null` est une valeur fonctionnelle.
///
/// Ce scope vit dans ce paquet plutôt que dans `ZcrudScope` du cœur pour la
/// même raison que `ZChatRendererScope` : `ZChatShellRenderRequest` porte des
/// `ZChatMessage`, donc du vocabulaire de `zcrud_chat_kernel`. Ajouter ce port
/// à `ZcrudScope` créerait une arête du cœur vers un paquet satellite, en
/// violation de l'invariant AD-1. Le scope vit dans le paquet qui possède le
/// vocabulaire ; les scopes du cœur et du chat s'empilent sans se gêner.
///
/// Coquille et blocs sont deux décisions indépendantes, par construction : un
/// hôte peut remplacer la coquille de conversation tout en gardant son
/// renderer de blocs, ou l'inverse — le seam de bloc n'est jamais intercepté
/// par la coquille, il vit dans son propre scope.
library;

import 'package:flutter/widgets.dart';

import 'z_chat_seam_failure.dart';
import 'z_chat_shell_render_request.dart';
import 'z_chat_shell_renderer.dart';

/// Porte le [ZChatShellRenderer] injecté par l'hôte jusqu'à la vue de
/// conversation.
class ZChatShellRendererScope extends InheritedWidget {
  /// Injecte [renderer] pour le sous-arbre [child].
  const ZChatShellRendererScope({
    required this.renderer,
    required super.child,
    super.key,
  });

  /// La coquille de l'hôte. `null` signifie liste neutre partout (état par
  /// défaut, strictement identique à l'absence de scope).
  final ZChatShellRenderer? renderer;

  /// Le scope le plus proche, ou `null` — jamais de `throw` (invariant AD-10).
  static ZChatShellRendererScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZChatShellRendererScope>();

  @override
  bool updateShouldNotify(ZChatShellRendererScope oldWidget) =>
      !identical(renderer, oldWidget.renderer);
}

/// Chaîne totale : seam de l'hôte vers `null`.
///
/// Scope absent, renderer absent, ou coquille qui décline rendent tous `null`
/// sans lever. `null` signifie « liste neutre », ce qui garantit qu'un
/// consommateur non configuré rend exactement comme si ce port n'existait
/// pas.
///
/// L'invariant AD-10 s'applique ici comme sur `zResolveChatBlock` : le seam
/// absorbe l'exception plutôt que de la laisser se propager, pour que le
/// rendu neutre reste toujours atteignable, même quand la coquille fournie
/// par l'hôte échoue.
///
/// L'exception reste relayée à `FlutterError.reportError` (console et
/// rapports de crash de l'hôte, avec sa pile) : elle est débogable, elle
/// n'emporte plus la conversation.
Widget? zResolveChatShell(
  BuildContext context,
  ZChatShellRenderRequest request,
) {
  final ZChatShellRenderer? renderer =
      ZChatShellRendererScope.maybeOf(context)?.renderer;
  if (renderer == null) return null;
  try {
    return renderer.buildShell(context, request);
  } catch (error, stack) {
    zChatReportSeamFailure(
      error: error,
      stack: stack,
      seam: kZChatSeamShell,
    );
    return null;
  }
}
