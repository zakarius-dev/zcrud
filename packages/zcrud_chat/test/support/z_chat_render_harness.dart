// Primitives PARTAGÉES des gardes de RENDU (CHAT-3).
//
// 🔴 Source UNIQUE (patron `z_chat_fakes.dart` / `z_chat_sources.dart`) : les
// recopier dans chaque garde créerait deux définitions divergentes de « ce que
// l'hôte monte autour du rendu ».
//
// ⚠️ Ce fichier n'est PAS un `*_test.dart` : le runner ne l'exécute jamais seul.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Monte [child] dans un hôte minimal : thème (pour `ZcrudTheme.of`),
/// directionnalité, et — optionnellement — un registre de libellés et un
/// renderer injecté.
///
/// 🔴 `material` est importé ICI, dans le TEST, jamais dans `lib/` : la garde
/// de pureté vérifie que le package ne dépend d'aucune surface stylée. Un hôte
/// réel apporte son propre `Theme`.
Widget harness(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Map<String, String>? labels,
  ZChatRenderer? renderer,
  ZChatShellRenderer? shell,
}) {
  Widget tree = child;
  if (renderer != null) {
    tree = ZChatRendererScope(renderer: renderer, child: tree);
  }
  if (shell != null) {
    tree = ZChatShellRendererScope(renderer: shell, child: tree);
  }
  if (labels != null) {
    tree = ZcrudScope(labels: ZcrudLabels(labels), child: tree);
  }
  return MaterialApp(
    home: Directionality(
      textDirection: direction,
      child: Scaffold(body: tree),
    ),
  );
}

/// Un message d'assistant portant [blocks].
ZChatMessage assistant(List<ZContentBlock> blocks, {String id = 'm1'}) =>
    ZChatMessage(
      id: id,
      conversationId: 'c1',
      role: ZChatRole.assistant,
      contentBlocks: blocks,
    );

/// Un bloc de texte de [lines] lignes — de quoi dépasser une hauteur repliée.
ZTextBlock longText(int lines) => ZTextBlock(
  text: List<String>.generate(lines, (int i) => 'ligne $i').join('\n'),
);

/// Tous les libellés `Text` rendus, dans l'ordre de l'arbre.
List<String> renderedTexts(WidgetTester tester) => <String>[
  for (final Text t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? '',
];

/// Un nœud sémantique de l'arbre courant satisfaisant [test], ou `null`.
SemanticsNode? findSemantics(
  WidgetTester tester,
  bool Function(SemanticsNode node) test,
) {
  // 🔴 `binding.pipelineOwner.semanticsOwner` est DÉPRÉCIÉ ; et
  // `rootPipelineOwner.semanticsOwner` est `null` — la sémantique appartient
  // aux owners ENFANTS. Mesuré : la première rédaction, littérale du message de
  // dépréciation, a rendu `null` partout et fait rougir deux gardes d'annonce.
  SemanticsOwner? owner;
  tester.binding.rootPipelineOwner.visitChildren((PipelineOwner child) {
    owner ??= child.semanticsOwner;
  });
  final SemanticsNode? root = owner?.rootSemanticsNode;
  if (root == null) return null;
  SemanticsNode? hit;
  void visit(SemanticsNode node) {
    if (hit != null) return;
    if (test(node)) {
      hit = node;
      return;
    }
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return hit == null;
    });
  }

  visit(root);
  return hit;
}

/// **Tous** les nœuds sémantiques satisfaisant [test] — et pas seulement le
/// premier.
///
/// 🔴 [findSemantics] s'arrête au premier trouvé : il ne peut donc PAS prouver
/// l'absence de DOUBLON, qui est exactement ce que la revue a mesuré sur la
/// bande de pièces jointes (`<rapport.pdf\nrapport.pdf>`). Une garde de
/// non-duplication a besoin du COMPTE, pas d'une existence.
List<SemanticsNode> collectSemantics(
  WidgetTester tester,
  bool Function(SemanticsNode node) test,
) {
  SemanticsOwner? owner;
  tester.binding.rootPipelineOwner.visitChildren((PipelineOwner child) {
    owner ??= child.semanticsOwner;
  });
  final SemanticsNode? root = owner?.rootSemanticsNode;
  final List<SemanticsNode> hits = <SemanticsNode>[];
  if (root == null) return hits;
  void visit(SemanticsNode node) {
    if (test(node)) hits.add(node);
    node.visitChildren((SemanticsNode child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return hits;
}

/// Observateur de navigation : compte les routes poussées.
///
/// 🔴 C'est l'instrument qui distingue un **dépli inline** d'une **ouverture
/// plein écran** — la confusion exacte que fait le bouton « Afficher plus »
/// d'IFFD.
class RouteSpy extends NavigatorObserver {
  /// Nombre de routes poussées depuis le montage.
  int pushed = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed++;
    super.didPush(route, previousRoute);
  }
}

/// Renderer qui **décline tout** : il prouve que la chaîne interroge bien le
/// seam, sans rien changer au rendu (garde de neutralité).
class DecliningRenderer extends ZChatRenderer {
  /// Construit un renderer déclinant.
  DecliningRenderer();

  /// Requêtes vues — non vide ⇒ le seam a réellement été interrogé.
  final List<ZChatBlockRenderRequest> seen = <ZChatBlockRenderRequest>[];

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) {
    seen.add(request);
    return null;
  }
}

/// Une coquille TIERCE **plausible** : ni `ListView`, ni `Sliver` — un simple
/// empilement, comme le ferait un widget de liste maison.
///
/// 🔴 Elle est délibérément ÉTRANGÈRE au socle : elle ne construit **aucune**
/// tuile elle-même et se contente de rappeler `request.itemBuilder`. C'est le
/// contrat minimal, et c'est tout ce qu'on peut exiger d'un backend. Ce que le
/// socle garantit malgré cela est **exactement** la mesure de la non-perte.
class FakeShellRenderer extends ZChatShellRenderer {
  /// Construit une coquille de test.
  FakeShellRenderer({this.decline = false});

  /// `true` ⇒ rend `null` (« garde la liste neutre ») au lieu d'une coquille.
  final bool decline;

  /// Requêtes vues — non vide ⇒ le seam a réellement été interrogé.
  final List<ZChatShellRenderRequest> seen = <ZChatShellRenderRequest>[];

  @override
  Widget? buildShell(BuildContext context, ZChatShellRenderRequest request) {
    seen.add(request);
    if (decline) return null;
    return SingleChildScrollView(
      padding: request.padding,
      reverse: request.reverse,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < request.itemCount; i++)
            request.itemBuilder(context, i),
        ],
      ),
    );
  }
}

/// Une coquille qui **ignore** `itemBuilder` — le pire cas admissible.
///
/// Elle sert de contre-preuve : la seule dégradation qui reste à un backend est
/// de ne rien afficher, panne **bruyante** et non silencieuse.
class BlindShellRenderer extends ZChatShellRenderer {
  /// Construit une coquille aveugle.
  const BlindShellRenderer();

  @override
  Widget? buildShell(BuildContext context, ZChatShellRenderRequest request) =>
      const SizedBox.shrink();
}

/// Renderer qui prend en charge **un seul `kind`** — la prise en charge
/// partielle que le contrat promet.
class KindRenderer extends ZChatRenderer {
  /// Prend en charge les blocs dont `kind == [kind]`, rendus comme [marker].
  const KindRenderer({required this.kind, required this.marker});

  /// Le discriminant pris en charge.
  final String kind;

  /// Le texte rendu à la place du bloc.
  final String marker;

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) =>
      request.block.kind == kind ? Text(marker) : null;
}
