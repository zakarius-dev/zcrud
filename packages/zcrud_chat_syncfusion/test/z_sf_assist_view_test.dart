// Gardes de la coquille Syncfusion, devenue **BACKEND DU PORT** (CHAT-3b,
// ex-CHAT-6 · AD-13/FR-26/AD-57).
//
// 🔴 Ce que ces gardes prouvent, et pourquoi c'est nécessaire :
// la coquille change le CADRE, jamais le CONTENU. C6 l'affirmait pour un widget
// PARALLÈLE — et l'affirmation était fausse : la vue parallèle faisait perdre la
// région live, le dépli inline et `ZChatMessageTile`, qu'elle ne réimplémentait
// pas. Ce fichier monte désormais la coquille **là où un hôte la monte** — sous
// `ZChatConversationView`, via `ZChatShellRendererScope` — et mesure ce que le
// socle conserve MALGRÉ elle. C'est la seule façon de prouver « ne fait rien
// perdre » : monter la vue du socle, pas celle du satellite.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_chat/assist_view.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_syncfusion/zcrud_chat_syncfusion.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Libellés fournis par l'hôte — aucune chaîne n'est inventée par le paquet.
///
/// 🔴 Les clés de la région live et de la réponse en cours sont celles du
/// SOCLE (`kZChatLabel…`) : la coquille n'en déclare plus de jumelles
/// (CHAT-3b).
const Map<String, String> kLabels = <String, String>{
  kZSfAssistLabelUserAuthor: 'Moi',
  kZSfAssistLabelAssistantAuthor: 'Assistant',
  kZChatLabelLiveRegion: 'Conversation',
  kZChatLabelStreaming: 'Rédaction en cours',
  kZChatLabelShowMore: 'Afficher plus',
  kZChatLabelShowLess: 'Afficher moins',
};

Widget host(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  Map<String, String>? labels = kLabels,
  ZChatRenderer? renderer,
  ZChatShellRenderer? shell = const ZSfAssistShellRenderer(),
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

/// Premier nœud sémantique satisfaisant [test] — sur l'arbre **fusionné**,
/// c'est-à-dire ce qu'un lecteur d'écran énonce réellement.
///
/// 🔴 C'est l'instrument qui distingue « la propriété de widget porte le
/// résumé » de « le résumé est annoncé ». Les deux gardes `data` de ce fichier
/// n'avaient que le premier, et seraient restées vertes avec un champ inerte.
SemanticsNode? semanticsWhere(
  WidgetTester tester,
  bool Function(SemanticsNode node) test,
) {
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

ZChatMessage assistant(List<ZContentBlock> blocks, {String id = 'm1'}) =>
    ZChatMessage(
      id: id,
      conversationId: 'c1',
      role: ZChatRole.assistant,
      contentBlocks: blocks,
    );

List<String> texts(WidgetTester tester) => <String>[
  for (final Text t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? '',
];

/// Contrôleur minimal + son port piloté par le test.
///
/// 🔴 Le texte en cours arrive par la **tranche RÉELLE** du contrôleur, pas par
/// un `ValueNotifier` de doublure : sans cela, la mesure SM-1 mesurerait le
/// test, pas le code.
typedef SfRig = ({ZChatController controller, FakePort port});

SfRig controllerWith(List<ZChatMessage> messages) {
  int n = 0;
  final FakePort port = FakePort();
  final ZChatController c = ZChatController(
    streamPort: port,
    actionExecutor: _NoExecutor(),
    confirm: (ZChatActionPlan _) async => true,
    newRequestId: () => 'r${n++}',
    buildRequest: (ZChatDraft d) =>
        ZChatGenerationRequest(style: ZChatGenerationStyle.converse, subject: d.text),
    conversationId: 'c1',
    initialMessages: messages,
  );
  return (controller: c, port: port);
}

/// Port de streaming piloté : un canal par appel, jamais fermé de lui-même.
class FakePort implements ZChatStreamPort {
  /// Canaux ouverts, un par appel.
  final List<StreamController<ZResult<ZChatStreamEvent>>> channels =
      <StreamController<ZResult<ZChatStreamEvent>>>[];

  /// Canal du dernier appel.
  StreamController<ZResult<ZChatStreamEvent>> get last => channels.last;

  /// Ferme tous les canaux — appelé en `tearDown` pour ne laisser aucun flux
  /// pendant.
  Future<void> closeAll() async {
    for (final StreamController<ZResult<ZChatStreamEvent>> c in channels) {
      if (!c.isClosed) await c.close();
    }
  }

  @override
  Stream<ZResult<ZChatStreamEvent>> stream(
    ZChatGenerationRequest request, {
    required ZChatRequestToken token,
  }) {
    final StreamController<ZResult<ZChatStreamEvent>> channel =
        StreamController<ZResult<ZChatStreamEvent>>();
    channels.add(channel);
    return channel.stream;
  }
}

ZTextBlock longText(int lines) => ZTextBlock(
  text: List<String>.generate(lines, (int i) => 'ligne $i').join('\n'),
);

/// Un renderer d'hôte qui ne connaît QU'UN `kind` custom.
class _HostRenderer extends ZChatRenderer {
  const _HostRenderer();

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) {
    if (request.block.kind == 'legalReference') {
      return const Text('RENDU-HOTE');
    }
    return null;
  }
}

void main() {
  testWidgets('la coquille rend bien le CADRE : `SfAIAssistView` est monté et '
      'la liste NEUTRE ne l\'est plus', (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[ZTextBlock(text: 'x')]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(host(ZChatConversationView(controller: c)));
    await tester.pump();
    // 🔴 NON-VACUITÉ de tout ce fichier : sans ces assertions, les gardes
    // suivantes seraient vraies parce qu'on regarderait encore la liste neutre.
    expect(find.byType(SfAIAssistView), findsOneWidget);
    // ⚠️ « aucun `ListView` » NE MORDRAIT PAS : `SfAIAssistView` monte le sien.
    // La question n'est pas qu'il n'y ait pas de liste, c'est QUI la porte —
    // donc que le contenu du socle soit bien DANS la coquille.
    expect(
      find.ancestor(
        of: find.byType(ZChatMessageTile),
        matching: find.byType(SfAIAssistView),
      ),
      findsOneWidget,
      reason: '🔴 la coquille n\'enveloppe pas le contenu du socle : elle n\'a '
          'pas remplacé le conteneur, ou elle a construit son propre corps',
    );
  });

  testWidgets('le CONTENU vient de zcrud_chat, pas de `AssistMessage.data`',
      (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[
        ZTextBlock(text: 'Premier bloc'),
        ZAlertBlock(level: 'warning', message: 'Second bloc'),
      ]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(host(ZChatConversationView(controller: c)));
    await tester.pump();
    // 🔴 Deux blocs distincts sont rendus : la coquille n'a pas aplati.
    expect(find.byType(ZChatBlockView), findsNWidgets(2));
    expect(texts(tester), contains('Premier bloc'));
    expect(texts(tester), contains('Second bloc'));
  });

  testWidgets('🔴 LA GARDE DU LOT · sous la coquille, l\'hôte ne perd NI la '
      'région live, NI le dépli inline, NI la tuile',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(<ZContentBlock>[longText(20)]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(
      host(
        ZChatConversationView(controller: c, collapsedMaxHeight: 60),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SfAIAssistView), findsOneWidget);

    // (1) LA RÉGION LIVE — perdue par la vue parallèle de C6 dès lors qu'elle
    //     ne recevait pas de contrôleur ; ici elle enveloppe le seam.
    expect(find.bySemanticsLabel('Conversation'), findsOneWidget,
        reason: '🔴 sous la coquille, une réponse qui arrive serait MUETTE au '
            'lecteur d\'écran');

    // (2) LA TUILE du socle.
    expect(find.byType(ZChatMessageTile), findsOneWidget,
        reason: '🔴 la coquille construit son propre corps de message : le '
            'doublon de C6 est de retour');

    // (3) LE DÉPLI INLINE, réel.
    final Finder tile = find.byType(ZChatMessageTile);
    final double collapsed = tester.getSize(tile).height;
    expect(find.text('Afficher plus'), findsOneWidget);
    await tester.tap(find.text('Afficher plus'));
    await tester.pumpAndSettle();
    expect(tester.getSize(tile).height, greaterThan(collapsed),
        reason: '🔴 « Afficher plus » ne déplie pas sous la coquille');
    expect(find.text('Afficher moins'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('le seam de BLOC de l\'hôte reste ATTEIGNABLE sous la coquille',
      (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(<ZContentBlock>[
        ZCustomContentBlock('legalReference', const <String, dynamic>{}),
        const ZTextBlock(text: 'neutre'),
      ]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(
      host(
        ZChatConversationView(controller: c),
        renderer: const _HostRenderer(),
      ),
    );
    await tester.pump();
    // Le bloc custom passe par l'hôte…
    expect(texts(tester), contains('RENDU-HOTE'));
    // …et le bloc connu garde le rendu neutre : prise en charge PARTIELLE.
    expect(texts(tester), contains('neutre'));
  });

  testWidgets('🔴 `AssistMessage.data` porte le résumé ACCESSIBLE du kernel — '
      'tableaux et sources compris', (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[
        ZTableBlock(
          headers: <String>['code', 'droit'],
          rows: <List<String>>[
            <String>['0101', 'cinq'],
          ],
        ),
      ]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(host(ZChatConversationView(controller: c)));
    await tester.pump();

    final SfAIAssistView view = tester.widget<SfAIAssistView>(
      find.byType(SfAIAssistView),
    );
    expect(view.messages, hasLength(1));
    expect(
      view.messages.first.data,
      allOf(contains('0101'), contains('droit')),
      reason: '🔴 LE défaut C6 : le résumé local ne connaissait que '
          '`ZTextBlock`, donc un TABLEAU n\'était annoncé nulle part. Le '
          'résumé vient désormais de `ZContentBlock.accessibleText` — `switch` '
          'exhaustif sur l\'union scellée.',
    );

    // 🔴 **GARDE RETENDUE (HIGH-2) — sur l'ARBRE SÉMANTIQUE, pas sur une
    // propriété de widget.** L'assertion ci-dessus était VRAIE et
    // NON PORTEUSE : `syncfusion_flutter_chat` ne lit `AssistMessage.data`
    // que dans la branche `else` de son constructeur de contenu, celle qu'un
    // `messageContentBuilder` court-circuite **toujours** — et nous en
    // fournissons un systématiquement. Le résumé partait donc dans un champ
    // INERTE, et cette garde serait restée verte alors que personne
    // n'entendait rien. Ce qui suit mesure ce que le lecteur d'écran ÉNONCE.
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pump();
    expect(
      semanticsWhere(
        tester,
        (SemanticsNode n) =>
            n.label.contains('0101') && n.label.contains('droit'),
      ),
      isNotNull,
      reason: '🔴 le résumé exhaustif du kernel n\'est ANNONCÉ nulle part : '
          'il est calculé, rangé dans `AssistMessage.data`, et perdu.',
    );
    handle.dispose();
  });

  testWidgets('AD-13 · la tuile en cours fait AU MOINS 48 dp de haut',
      (WidgetTester tester) async {
    final SfRig rig = controllerWith(const <ZChatMessage>[]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(host(ZChatConversationView(controller: c)));
    await startTurn(tester, rig);

    // 🔴 Cibler la tuile PAR SON NŒUD SÉMANTIQUE, jamais `.last` d'un type
    // générique : `SfAIAssistView` monte ses propres `ConstrainedBox`, et une
    // première rédaction du test (C6) mesurait l'un des leurs (0 dp) — un rouge
    // qui ne disait rien du code sous garde.
    final Finder tuile = find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.label == 'Rédaction en cours',
    );
    expect(tuile, findsOneWidget);
    final Finder box = find
        .descendant(of: tuile, matching: find.byType(ConstrainedBox))
        .first;
    final ConstrainedBox widget = tester.widget<ConstrainedBox>(box);
    expect(widget.constraints.minHeight, greaterThanOrEqualTo(48.0));
    expect(tester.getSize(box).height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('SM-1 · un jeton ne reconstruit QUE la tuile en cours',
      (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[ZTextBlock(text: 'stable')]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    int blockBuilds = 0;
    await tester.pumpWidget(
      host(
        ZChatConversationView(controller: c),
        renderer: _CountingRenderer(() => blockBuilds++),
      ),
    );
    final String requestId = await startTurn(tester, rig);
    final int before = blockBuilds;
    // 🔴 Le texte arrive par la TRANCHE du contrôleur — le canal réel, pas une
    // doublure : c'est ce qui fait de cette mesure une mesure de SM-1 et non
    // celle d'un `ValueNotifier` de test.
    rig.port.last.add(
      const Right<ZFailure, ZChatStreamEvent>(ZChatTokenEvent(content: 'b')),
    );
    await tester.pump();
    expect(c.streamText(requestId).value, 'b',
        reason: '🔴 le jeton n\'a pas atteint la tranche : la mesure '
            'ci-dessous serait vraie par VACUITÉ');
    // Si l'abonnement au texte était pris AU-DESSUS de la liste, ce compteur
    // bougerait à chaque jeton — le bug historique du dépôt.
    expect(blockBuilds, before);
  });

  testWidgets('RTL · la coquille se monte et rend en `TextDirection.rtl`',
      (WidgetTester tester) async {
    // 🔴 LA TUILE EN COURS EST MONTÉE ICI DÉLIBÉRÉMENT (leçon C6 : sans flux
    // ouvert, le seul `Align` sous garde n'existait pas dans l'arbre et la
    // boucle restait VERTE après injection de `Alignment.centerLeft`).
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[ZTextBlock(text: 'مرحبا')]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(
      host(
        ZChatConversationView(controller: c),
        direction: TextDirection.rtl,
      ),
    );
    await startTurn(tester, rig);
    expect(texts(tester), contains('مرحبا'));

    final Finder tuile = find.byWidgetPredicate(
      (Widget w) => w is Semantics && w.properties.label == 'Rédaction en cours',
    );
    final Finder aligns = find.descendant(
      of: tuile,
      matching: find.byType(Align),
    );
    expect(aligns, findsWidgets,
        reason: 'sans Align sous garde, la boucle ci-dessous ne prouve rien');
    for (final Align a in tester.widgetList<Align>(aligns)) {
      expect(a.alignment, isNot(Alignment.centerLeft),
          reason: 'AD-13 : bord figé — utiliser AlignmentDirectional');
      expect(a.alignment, isNot(Alignment.centerRight));
    }
  });

  testWidgets('FR-26/HIGH-1 · sans registre de libellés, c\'est le REPLI '
      'LISIBLE qui sort — jamais la clé brute, jamais une phrase inventée '
      'hors table', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[ZTextBlock(text: 'x')]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(
      host(ZChatConversationView(controller: c), labels: null),
    );
    await tester.pump();
    // 🔴 **GARDE RENVERSÉE (HIGH-1).** Elle assertait que la CLÉ BRUTE sortait
    // — elle défendait donc le défaut : un hôte au registre non alimenté lisait
    // `zchat.sf.assistantAuthor` au-dessus de chaque réponse, et un lecteur
    // d'écran s'entendait annoncer `zchat.liveRegion`. Ce qu'elle défend
    // maintenant : le repli est LISIBLE, il vient de la TABLE du paquet (donc
    // il reste greppable et traduisible en un seul endroit), et aucune clé
    // brute n'atteint l'utilisateur.
    expect(
      find.bySemanticsLabel(kZChatLabelFallbacks[kZChatLabelLiveRegion]!),
      findsOneWidget,
      reason: '🔴 la région live annonce autre chose que son repli — la clé '
          'brute `zchat.liveRegion` était énoncée telle quelle.',
    );
    expect(find.bySemanticsLabel(kZChatLabelLiveRegion), findsNothing,
        reason: '🔴 CLÉ BRUTE ANNONCÉE.');
    final SfAIAssistView view = tester.widget<SfAIAssistView>(
      find.byType(SfAIAssistView),
    );
    expect(
      view.messages.first.author?.name,
      kZSfAssistLabelFallbacks[kZSfAssistLabelAssistantAuthor],
      reason: '🔴 un nom d\'auteur inventé HORS de la table du paquet — FR-26 — '
          'ou bien la clé brute affichée telle quelle — HIGH-1',
    );
    handle.dispose();
  });

  testWidgets('AD-57 · la coquille est OPTIONNELLE : sans elle, le socle rend '
      'sa liste neutre et rien de Syncfusion n\'est monté',
      (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(const <ZContentBlock>[ZTextBlock(text: 'x')]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(
      host(ZChatConversationView(controller: c), shell: null),
    );
    await tester.pump();
    expect(find.byType(SfAIAssistView), findsNothing);
    expect(find.byType(ListView), findsOneWidget,
        reason: '🔴 le défaut zéro-dépendance d\'AD-57 doit rester fonctionnel');
    expect(texts(tester), contains('x'));
  });

  testWidgets('le seam d\'annonce de l\'hôte atteint `AssistMessage.data` '
      '(AD-4 : un bloc OUVERT est annonçable)', (WidgetTester tester) async {
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(<ZContentBlock>[
        ZCustomContentBlock('legalReference', const <String, dynamic>{}),
      ]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final ZChatController c = rig.controller;
    await tester.pumpWidget(
      host(
        ZChatConversationView(controller: c),
        shell: ZSfAssistShellRenderer(
          accessibleTextResolver: (ZContentBlock b) =>
              b.kind == 'legalReference' ? 'reference juridique' : null,
        ),
      ),
    );
    await tester.pump();
    final SfAIAssistView view = tester.widget<SfAIAssistView>(
      find.byType(SfAIAssistView),
    );
    expect(view.messages.first.data, 'reference juridique',
        reason: '🔴 sans ce seam, un bloc d\'hôte ne serait annonçable que par '
            'son discriminant machine, et JAMAIS localisable');
  });

  testWidgets('🔴 HIGH-2 — le seam d\'annonce injecté par SCOPE est réellement '
      'ÉNONCÉ (arbre sémantique fusionné)', (WidgetTester tester) async {
    // Le point d'injection de référence est `ZChatAccessibleTextScope` : c'est
    // lui qui alimente À LA FOIS le champ `data` de Syncfusion et le nœud
    // `Semantics` de `ZChatMessageTile`. Le renseigner sur le SEUL renderer
    // laisserait un résumé au champ mort et un autre à l'utilisateur.
    final SfRig rig = controllerWith(<ZChatMessage>[
      assistant(<ZContentBlock>[
        ZCustomContentBlock('legalReference', const <String, dynamic>{}),
      ]),
    ]);
    addTearDown(rig.controller.dispose);
    addTearDown(rig.port.closeAll);
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        ZChatAccessibleTextScope(
          resolver: (ZContentBlock b) =>
              b.kind == 'legalReference' ? 'reference juridique' : null,
          child: ZChatConversationView(controller: rig.controller),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final SfAIAssistView view = tester.widget<SfAIAssistView>(
      find.byType(SfAIAssistView),
    );
    expect(view.messages.first.data, 'reference juridique',
        reason: '🔴 le résolveur du SCOPE n\'atteint pas `data` : deux '
            'résumés distincts, promis à diverger.');
    expect(
      semanticsWhere(
        tester,
        (SemanticsNode n) => n.label.contains('reference juridique'),
      ),
      isNotNull,
      reason: '🔴 le résumé de l\'hôte n\'est ÉNONCÉ nulle part sous '
          'Syncfusion — le défaut HIGH-2 exactement.',
    );
    handle.dispose();
  });
}

/// Lance un envoi sans l'attendre (le flux de test ne se termine jamais).
void unawaitedSend(ZChatController c) {
  // ignore: discarded_futures
  c.send();
}

/// Ouvre un tour et rend son `requestId` — la tuile « en cours » est montée.
Future<String> startTurn(WidgetTester tester, SfRig rig) async {
  rig.controller.composer.text = 'q';
  unawaitedSend(rig.controller);
  await tester.pump();
  return rig.controller.activeRequests.value.single;
}

/// Compte les appels du seam de bloc — sonde de granularité de rebuild.
class _CountingRenderer extends ZChatRenderer {
  const _CountingRenderer(this.onBuild);

  final void Function() onBuild;

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) {
    onBuild();
    return null;
  }
}

/// Exécuteur inerte — AUCUN verbe n'est joué par ces gardes de rendu.
///
/// Chaque membre rend un `Left` typé plutôt que de lever : si une garde en
/// atteignait un par mégarde, elle rougirait sur une failure lisible et non sur
/// une exception qui ne dirait pas d'où elle vient (AD-5/AD-10).
class _NoExecutor implements ZChatActionExecutor {
  static ZResult<T> _no<T>() =>
      Left<ZFailure, T>(const ZDomainFailure('executor not wired in this test'));

  @override
  Future<ZResult<ZChatActionImpact>> estimateImpact(ZChatAction action) async =>
      _no<ZChatActionImpact>();

  @override
  Future<ZResult<List<String>>> editAndResend({
    required String messageId,
    required String newText,
  }) async =>
      _no<List<String>>();

  @override
  Future<ZResult<List<String>>> regenerate({required String messageId}) async =>
      _no<List<String>>();

  @override
  Future<ZResult<List<String>>> softDeleteMessages({
    required String messageId,
    required bool cascadeToPair,
  }) async =>
      _no<List<String>>();

  @override
  Future<ZResult<Unit>> cancelRequest(String requestId) async => _no<Unit>();

  @override
  Future<ZResult<String>> renderForCopy({
    required String messageId,
    required ZChatCopyFormat format,
  }) async =>
      _no<String>();

  @override
  Future<ZResult<List<String>>> executeCustom(ZChatCustomAction action) async =>
      _no<List<String>>();
}
