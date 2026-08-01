/// Injection du port de rendu et **chaîne totale** de résolution — CHAT-3.
///
/// Patron de `zResolveGradient`
/// (`zcrud_core/lib/src/presentation/theme/z_gradient_resolver.dart`) : une
/// chaîne **totale** `seam hôte → null`, qui ne lève jamais et dont `null` est
/// une valeur fonctionnelle.
///
/// 🔴 **Pourquoi un `InheritedWidget` LOCAL plutôt qu'un champ de
/// `ZcrudScope`.** `ZcrudScope` porte déjà `listRenderer`, `reorderRenderer`,
/// `dropRegionRenderer` : y ajouter `chatRenderer` serait le geste homogène. Il
/// est délibérément **écarté ici** — il ferait connaître au cœur un type de
/// `zcrud_chat_kernel` (`ZContentBlock` traverse la signature du port), donc une
/// arête `zcrud_core → zcrud_chat_kernel` : **AD-1 ROUGE**, CORE OUT ≠ 0. Le
/// scope vit donc dans le package qui possède le vocabulaire. Les deux
/// s'empilent sans se gêner (`ZcrudScope` pour thème/libellés, celui-ci pour le
/// renderer).
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

  /// Le renderer de l'hôte. `null` ⇒ rendu neutre partout (état par défaut,
  /// strictement identique à l'absence de scope).
  final ZChatRenderer? renderer;

  /// Le scope le plus proche, ou `null` — **jamais de throw** (AD-10).
  static ZChatRendererScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZChatRendererScope>();

  @override
  bool updateShouldNotify(ZChatRendererScope oldWidget) =>
      !identical(renderer, oldWidget.renderer);
}

/// Chaîne **totale** : seam hôte → `null`.
///
/// Aucune requête n'est rejetée, aucun déréférencement nul n'est possible —
/// scope absent, renderer absent, ou renderer qui décline rendent tous `null`
/// sans lever. `null` signifie « **rendu neutre** », et c'est ce qui garantit
/// qu'un consommateur non configuré rend exactement comme si ce port n'existait
/// pas (garde de **neutralité**).
///
/// 🔴 **ARBITRAGE AD-10 TRANCHÉ EN FIN D'EPIC — le seam ABSORBE.**
///
/// Ce fichier documentait l'inverse (« une exception du renderer de l'hôte se
/// propage »), en invoquant justement la **non-divergence** avec ses coutures
/// voisines. La revue a mesuré la divergence réelle : le kernel, lui, **absorbe**
/// le résolveur d'annonce qui lève (`z_content_block.dart:300-308`, « un seam
/// d'hôte qui lève ne doit pas rendre le message muet »). Le même défaut d'hôte
/// produisait donc, selon le seam touché, une **annonce dégradée** d'un côté et
/// un **écran rouge** de l'autre — et une coquille tierce qui lève ne retombait
/// **jamais** sur la liste neutre, alors que « le défaut zéro-dépendance reste
/// fonctionnel » est la promesse même d'AD-57.
///
/// Une seule lecture est retenue pour les **trois** seams (bloc, coquille,
/// annonce) : **le code arbitraire de l'hôte qui lève vaut « je décline »**, et
/// la chaîne retombe sur le rendu neutre. C'est la lecture du kernel, et c'est
/// celle d'AD-10 (« un chemin d'exception là où un repli est exigé »).
///
/// ⚠️ **Ce n'est pas un étouffement silencieux.** L'exception est relayée à
/// `FlutterError.reportError` : elle apparaît en console et dans les rapports de
/// crash de l'hôte, avec sa pile — donc elle reste débogable, ce qui était
/// l'unique argument en faveur de la propagation. Ce qu'elle ne fait plus, c'est
/// emporter la conversation.
///
/// Garde : `test/z_chat_seam_ad10_guard_test.dart` (les trois seams, même
/// scénario, même verdict).
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
