/// Injection du port de COQUILLE et **chaîne totale** de résolution — CHAT-3b.
///
/// Patron de `zResolveGradient`
/// (`zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart`) et jumeau
/// exact de `zResolveChatBlock` : une chaîne **totale** `seam hôte → null`, qui
/// ne lève jamais et dont `null` est une valeur fonctionnelle.
///
/// 🔴 **Pourquoi un `InheritedWidget` LOCAL plutôt qu'un champ de
/// `ZcrudScope`.** Même justification que `ZChatRendererScope`, et elle vaut
/// **a fortiori** ici : `ZChatShellRenderRequest` porte des `ZChatMessage`, donc
/// du vocabulaire de `zcrud_chat_kernel`. Ajouter ce port au `ZcrudScope` du
/// cœur créerait l'arête `zcrud_core → zcrud_chat_kernel` — **AD-1 ROUGE**,
/// CORE OUT ≠ 0. Le scope vit dans le package qui possède le vocabulaire ; les
/// trois scopes (`ZcrudScope`, `ZChatRendererScope`, celui-ci) s'empilent sans
/// se gêner.
///
/// 🔵 **Deux scopes INDÉPENDANTS, et c'est voulu.** Coquille et blocs sont deux
/// décisions séparées : un hôte peut brancher `SfAIAssistView` **tout en
/// gardant** son renderer de blocs (`'legalReference'`, `'flashcards'`,
/// `'mindmap'`), ou l'inverse. C'est ce qui rend inutile le chaînage manuel
/// `inner:` qu'imposait l'adaptateur C6 : le seam de bloc n'a jamais été
/// intercepté par la coquille, il vit dans son propre scope.
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

  /// La coquille de l'hôte. `null` ⇒ liste neutre partout (état par défaut,
  /// strictement identique à l'absence de scope).
  final ZChatShellRenderer? renderer;

  /// Le scope le plus proche, ou `null` — **jamais de throw** (AD-10).
  static ZChatShellRendererScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZChatShellRendererScope>();

  @override
  bool updateShouldNotify(ZChatShellRendererScope oldWidget) =>
      !identical(renderer, oldWidget.renderer);
}

/// Chaîne **totale** : seam hôte → `null`.
///
/// Scope absent, renderer absent, ou coquille qui décline rendent tous `null`
/// sans lever. `null` signifie « **liste neutre** », et c'est ce qui garantit
/// qu'un consommateur non configuré rend exactement comme si ce port n'existait
/// pas (garde de **neutralité**).
///
/// 🔴 **ARBITRAGE AD-10 TRANCHÉ EN FIN D'EPIC — le seam ABSORBE**, exactement
/// comme `zResolveChatBlock` et comme le résolveur d'annonce du kernel
/// (`z_content_block.dart:300-308`). Cf. le dartdoc de `zResolveChatBlock` pour
/// le raisonnement complet : une coquille tierce qui lève retombait sur un
/// **écran rouge** alors que le seam jumeau du kernel se contentait d'une
/// annonce dégradée, et surtout la liste neutre — le défaut fonctionnel qu'AD-57
/// exige de tout port — n'était **jamais** atteinte.
///
/// L'exception reste relayée à `FlutterError.reportError` (console + rapports de
/// crash de l'hôte, avec sa pile) : elle est débogable, elle n'emporte plus la
/// conversation.
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
