/// CHAT-3b — le **seam de CONVERSATION** : gardes de comportement.
///
/// 🔴 Ce que ce fichier existe pour empêcher, MESURÉ par le lot C6 : faute de
/// couture au niveau LISTE, l'adaptateur Syncfusion avait livré un **widget
/// parallèle** à `ZChatConversationView`. Un hôte qui choisissait Syncfusion
/// **perdait** la région live, le dépli inline et `ZChatMessageTile` — et les
/// deux vues étaient promises à diverger (motif CR-LEX-78).
///
/// La garde centrale du lot est [_lotGuard] : **une coquille tierce ne fait
/// perdre NI la région live, NI le dépli inline, NI la tuile.**
@TestOn('vm')
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';
import 'support/z_chat_sources.dart';

/// Le nom de la garde centrale, cité par la dartdoc du fichier.
const String _lotGuard = 'G-S2';

typedef Rig = ({
  ZChatController controller,
  FakeStreamPort port,
  SpyExecutor executor,
  SeqIds ids,
  List<ZChatActionPlan> confirmed,
});

Rig rigWith(int messageCount) => buildController(
  initialMessages: <ZChatMessage>[
    for (int i = 0; i < messageCount; i++)
      assistant(<ZContentBlock>[longText(20)], id: 'm$i'),
  ],
);

void main() {
  group('🔴 G-S1 — NEUTRALITÉ : sans coquille injectée, rendu STRICTEMENT '
      'inchangé', () {
    testWidgets('aucune coquille / coquille `null` / coquille qui décline ⇒ '
        'même arbre, et la liste neutre reste VIRTUALISÉE', (
      WidgetTester tester,
    ) async {
      final Rig rig = rigWith(4);
      addTearDown(rig.controller.dispose);

      Future<List<String>> textsOf(Widget tree) async {
        await tester.pumpWidget(tree);
        await tester.pumpAndSettle();
        return renderedTexts(tester);
      }

      final Widget view = ZChatConversationView(controller: rig.controller);
      final List<String> sansScope = await textsOf(harness(view));
      final List<String> scopeNul = await textsOf(
        harness(
          ZChatShellRendererScope(renderer: null, child: view),
        ),
      );
      final FakeShellRenderer declining = FakeShellRenderer(decline: true);
      final List<String> declinante = await textsOf(
        harness(view, shell: declining),
      );

      // 🔴 NON-VACUITÉ : sans ceci, une coquille jamais interrogée rendrait
      // l'égalité trivialement vraie.
      expect(
        declining.seen,
        isNotEmpty,
        reason: '🔴 le seam de COQUILLE n\'a pas été interrogé : la chaîne de '
            'résolution n\'est pas branchée',
      );
      expect(sansScope, isNotEmpty);
      expect(scopeNul, sansScope,
          reason: '🔴 un scope à renderer `null` doit être indiscernable de '
              'l\'absence de scope');
      expect(declinante, sansScope,
          reason: '🔴 une coquille qui décline doit laisser un rendu au mot '
              'près identique — la sémantique `null` de `zResolveGradient`');

      // …et le défaut est toujours la liste PARESSEUSE.
      final ListView list = tester.widget<ListView>(find.byType(ListView));
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    testWidgets('AD-10 — la chaîne est TOTALE : aucun scope, scope nul, '
        'coquille déclinante ⇒ jamais de throw', (WidgetTester tester) async {
      final Rig rig = rigWith(1);
      addTearDown(rig.controller.dispose);
      final Widget view = ZChatConversationView(controller: rig.controller);
      for (final Widget tree in <Widget>[
        harness(view),
        harness(ZChatShellRendererScope(renderer: null, child: view)),
        harness(view, shell: FakeShellRenderer(decline: true)),
        harness(view, shell: FakeShellRenderer()),
      ]) {
        await tester.pumpWidget(tree);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('🔴 $_lotGuard — LA GARDE DU LOT : une coquille TIERCE ne fait perdre '
      'NI la région live, NI le dépli inline, NI la tuile', () {
    testWidgets('les trois sont présents SOUS une coquille étrangère au socle',
        (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final Rig rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[longText(20)], id: 'm0'),
        ],
      );
      addTearDown(rig.controller.dispose);

      final FakeShellRenderer shell = FakeShellRenderer();
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            collapsedMaxHeight: 60,
          ),
          shell: shell,
          labels: <String, String>{
            kZChatLabelLiveRegion: 'conversation',
            kZChatLabelShowMore: 'Afficher plus',
            kZChatLabelShowLess: 'Afficher moins',
          },
        ),
      );
      await tester.pumpAndSettle();

      // (0) La coquille tierce est BIEN celle qui rend le cadre — sans quoi les
      // trois assertions suivantes ne prouveraient rien (elles seraient vraies
      // parce qu'on regarde toujours la liste neutre).
      expect(shell.seen, isNotEmpty);
      expect(find.byType(ListView), findsNothing,
          reason: '🔴 GARDE VACUELLE : la liste NEUTRE est encore montée — la '
              'coquille n\'a pas remplacé le conteneur');
      expect(find.byType(SingleChildScrollView), findsOneWidget,
          reason: '🔴 la coquille de test n\'est pas dans l\'arbre');

      // (1) LA RÉGION LIVE — elle enveloppe le seam, donc elle lui échappe.
      final SemanticsNode? live = findSemantics(
        tester,
        (SemanticsNode n) => n.getSemanticsData().flagsCollection.isLiveRegion,
      );
      expect(live, isNotNull,
          reason: '🔴 LA PERTE MESURÉE PAR C6 : sous une coquille tierce, une '
              'réponse qui arrive est MUETTE au lecteur d\'écran');
      expect(live!.label, 'conversation');

      // (2) LA TUILE — produite par la fabrique du socle, jamais par la
      // coquille.
      expect(find.byType(ZChatMessageTile), findsOneWidget,
          reason: '🔴 la coquille a construit son propre corps de message : le '
              'doublon de C6 est de retour');
      expect(find.byType(ZChatBlockView), findsOneWidget,
          reason: '🔴 les blocs ne passent plus par le rendu de blocs du socle');

      // (3) LE DÉPLI INLINE — réel : il augmente la hauteur, il n'ouvre rien.
      final Finder tile = find.byType(ZChatMessageTile);
      final double collapsed = tester.getSize(tile).height;
      expect(find.text('Afficher plus'), findsOneWidget,
          reason: '🔴 aucun bouton de dépli sous la coquille tierce');
      await tester.tap(find.text('Afficher plus'));
      await tester.pumpAndSettle();
      expect(tester.getSize(tile).height, greaterThan(collapsed),
          reason: '🔴 « Afficher plus » ne déplie pas sous la coquille — le '
              'défaut `showAll` d\'IFFD, reconstitué par la couture');
      expect(find.text('Afficher moins'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('le seam de BLOC de l\'hôte reste atteignable SOUS la coquille',
        (WidgetTester tester) async {
      final Rig rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[
            const ZTextBlock(text: 'neutre'),
            ZCustomContentBlock('mindmap', const <String, dynamic>{'n': 1}),
          ], id: 'm0'),
        ],
      );
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          shell: FakeShellRenderer(),
          renderer: const KindRenderer(kind: 'mindmap', marker: 'CARTE'),
        ),
      );
      await tester.pumpAndSettle();
      final List<String> texts = renderedTexts(tester);
      expect(texts, contains('CARTE'),
          reason: '🔴 la coquille a intercepté le seam de BLOC : les deux ports '
              'doivent rester INDÉPENDANTS (deux scopes distincts)');
      expect(texts, contains('neutre'),
          reason: '🔴 prise en charge partielle perdue sous la coquille');
    });

    testWidgets('🔬 contre-preuve — une coquille qui IGNORE `itemBuilder` perd '
        'tout, et la garde le VOIT', (WidgetTester tester) async {
      // Sans ce témoin, « la tuile est là » pourrait être vrai par construction
      // et ne rien discriminer. La seule dégradation qui reste à un backend est
      // BRUYANTE : il n'affiche rien.
      final Rig rig = rigWith(1);
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          shell: const BlindShellRenderer(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ZChatMessageTile), findsNothing);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('la requête reste NEUTRE : elle porte la donnée du socle, et '
        'ses accès sont TOTAUX (AD-10)', (WidgetTester tester) async {
      final Rig rig = rigWith(3);
      addTearDown(rig.controller.dispose);
      final FakeShellRenderer shell = FakeShellRenderer();
      await tester.pumpWidget(
        harness(
          ZChatConversationView(
            controller: rig.controller,
            reverse: true,
            padding: const EdgeInsetsDirectional.only(start: 7),
          ),
          shell: shell,
        ),
      );
      await tester.pumpAndSettle();

      final ZChatShellRenderRequest req = shell.seen.last;
      expect(req.messages, hasLength(3));
      expect(req.activeRequestIds, isEmpty);
      expect(req.itemCount, 3);
      expect(req.reverse, isTrue);
      expect(req.padding, const EdgeInsetsDirectional.only(start: 7));
      expect(req.messageAt(0)?.id, 'm0');
      expect(req.isStreamingAt(0), isFalse);
      // Hors-bornes : `null`, jamais une exception — une coquille tierce indexe
      // comme elle veut.
      for (final int out in <int>[-1, 3, 99]) {
        expect(req.messageAt(out), isNull);
        expect(req.requestIdAt(out), isNull);
        expect(req.isStreamingAt(out), isFalse);
      }
      // …et la fabrique elle-même ne tombe pas sur un index hors-bornes.
      expect(
        () => req.itemBuilder(tester.element(find.byType(Directionality).first), 99),
        returnsNormally,
      );
    });
  });

  group('🔴 G-S3 — le texte de STREAMING traverse la couture', () {
    testWidgets('le seam de bloc reçoit `isStreaming` ET le canal '
        '`streamingText`', (WidgetTester tester) async {
      final Rig rig = buildController();
      addTearDown(rig.controller.dispose);
      final DecliningRenderer seam = DecliningRenderer();
      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          renderer: seam,
        ),
      );
      rig.controller.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = rig.controller.send();
      await tester.pump();
      rig.port.last.add(tok('par'));
      await tester.pumpAndSettle();

      final Iterable<ZChatBlockRenderRequest> streaming = seam.seen.where(
        (ZChatBlockRenderRequest r) => r.isStreaming,
      );
      expect(streaming, isNotEmpty,
          reason: '🔴 LE défaut C6 : la réponse EN COURS ne passait pas par la '
              'couture du tout — un rendu riche d\'hôte ne l\'atteignait '
              'jamais');
      expect(
        streaming.last.streamingText,
        isNotNull,
        reason: '🔴 la requête portait `isStreaming` mais AUCUN canal pour le '
            'texte : l\'adaptateur devait le sortir de la couture',
      );
      expect(streaming.last.streamingText!.value, 'par',
          reason: '🔴 le canal ne porte pas le texte réellement accumulé');
      // …et le rendu neutre l'a bien affiché.
      expect(find.text('par'), findsOneWidget);

      await rig.port.closeAll();
      await sending;
      await tester.pumpAndSettle();
    });

    testWidgets('un renderer d\'hôte peut RENDRE le texte en cours par la '
        'couture', (WidgetTester tester) async {
      final Rig rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          renderer: const _StreamingRenderer(),
        ),
      );
      rig.controller.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = rig.controller.send();
      await tester.pump();
      rig.port.last.add(tok('abc'));
      await tester.pumpAndSettle();
      expect(find.text('HOTE:abc'), findsOneWidget,
          reason: '🔴 l\'hôte ne peut pas prendre en charge le texte en cours');

      rig.port.last.add(tok('def'));
      await tester.pumpAndSettle();
      expect(find.text('HOTE:abcdef'), findsOneWidget,
          reason: '🔴 le canal ne rafraîchit pas le rendu de l\'hôte');

      await rig.port.closeAll();
      await sending;
      await tester.pumpAndSettle();
    });

    testWidgets('AD-13 — la tuile en cours mesure AU MOINS 48 dp', (
      WidgetTester tester,
    ) async {
      final Rig rig = buildController();
      addTearDown(rig.controller.dispose);
      await tester.pumpWidget(
        harness(ZChatConversationView(controller: rig.controller)),
      );
      rig.controller.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = rig.controller.send();
      await tester.pump();
      rig.port.last.add(tok('x'));
      await tester.pumpAndSettle();

      // 🔴 Ciblée PAR SON NŒUD, jamais par `.last` d'un type générique : la
      // liste monte ses propres `ConstrainedBox` (leçon C6, où une première
      // rédaction mesurait l'un des leurs — 0 dp).
      final Finder tuile = find.byWidgetPredicate(
        (Widget w) =>
            w is Semantics &&
            // HIGH-1 : le nœud porte le libellé RÉSOLU (registre → … → repli),
            // plus jamais la clé brute. Le test suit la même chaîne.
            w.properties.label ==
                kZChatLabelFallbacks[kZChatLabelStreaming],
      );
      expect(tuile, findsOneWidget);
      final Finder box = find
          .descendant(of: tuile, matching: find.byType(ConstrainedBox))
          .first;
      expect(tester.getSize(box).height,
          greaterThanOrEqualTo(kZChatMinTapTarget));

      await rig.port.closeAll();
      await sending;
      await tester.pumpAndSettle();
    });
  });

  group('🔴 G-S4 — SM-1 NON DÉGRADÉ : sous coquille, un jeton ne reconstruit '
      'que la tuile en cours', () {
    testWidgets('100 jetons : la coquille n\'est PAS reconstruite, les tuiles '
        'établies non plus', (WidgetTester tester) async {
      final Rig rig = buildController(
        initialMessages: <ZChatMessage>[
          assistant(<ZContentBlock>[const ZTextBlock(text: 'stable')],
              id: 'm0'),
        ],
      );
      addTearDown(rig.controller.dispose);

      final FakeShellRenderer shell = FakeShellRenderer();
      int blockBuilds = 0;
      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          shell: shell,
          renderer: _CountingRenderer(() => blockBuilds++),
        ),
      );
      rig.controller.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = rig.controller.send();
      await tester.pump();

      final int shells0 = shell.seen.length;
      final int blocks0 = blockBuilds;
      for (int i = 0; i < 100; i++) {
        rig.port.last.add(tok('x', seq: 's$i'));
        await tester.pump();
      }

      // Non-vacuité : les jetons sont bien arrivés.
      final String requestId = rig.controller.activeRequests.value.single;
      expect(rig.controller.streamText(requestId).value, 'x' * 100);
      expect(
        shell.seen.length,
        shells0,
        reason: '🔴 SM-1 : chaque jeton reconstruit LA COQUILLE ENTIÈRE — '
            'c\'est-à-dire toute la conversation, 300 fois par tour. Le canal '
            'du texte doit être une `ValueListenable` portée par la requête, '
            'jamais un `String` qui en change la valeur.',
      );
      expect(
        blockBuilds,
        blocks0,
        reason: '🔴 SM-1 : chaque jeton réinterroge le seam de BLOC de tous les '
            'messages établis. L\'abonnement doit être pris SOUS le seam.',
      );

      // 🔴 Le tour est TERMINÉ par son événement terminal, jamais par une
      // fermeture de canal : les jetons ci-dessus portent un `sequenceId`, donc
      // une fin abrupte serait une interruption SUBIE — le contrôleur
      // relancerait une reprise et le test attendrait un flux qui n'arrive
      // jamais. (Mesuré : c'est ce qui a fait pendre la première rédaction.)
      rig.port.last.add(done());
      await tester.pump();
      await sending;
      await tester.pumpAndSettle();
    });
  });

  group('🔴 G-S5 — AUCUN second constructeur de tuile (grep NÉGATIF)', () {
    test('`ZChatMessageTile(` n\'est instancié qu\'à UN seul endroit de `lib/`',
        () {
      // 🔴 Les gardes de comportement ci-dessus prouvent ce qui se produit sur
      // l'arbre qu'elles montent. Elles sont AVEUGLES à une seconde vue que
      // personne ne monte — et c'est exactement ainsi que le widget parallèle de
      // C6 s'est installé. Ce test est le balayage, exécuté par une machine.
      final List<String> sites = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        // 🔴 Le fichier qui DÉCLARE la tuile porte forcément la signature de son
        // constructeur (`const ZChatMessageTile({`) : l'y compter ferait
        // rougir la garde sur l'existence même de ce qu'elle protège. Exemption
        // de FICHIER, comme celle de `z_chat_labels.dart` dans G-R10 — la
        // formuler en motif (« pas précédé de `const` ») serait plus fragile et
        // moins lisible.
        if (e.key.replaceAll(r'\', '/').endsWith('z_chat_message_tile.dart')) {
          continue;
        }
        for (int i = 0; i < e.value.length; i++) {
          if (RegExp(r'\bZChatMessageTile\s*\(').hasMatch(e.value[i])) {
            sites.add('${e.key}:${i + 1}');
          }
        }
      }
      expect(sites, hasLength(1),
          reason: '🔴 la tuile est construite depuis $sites. UNE seule fabrique '
              '(`_ZChatList._item`) doit exister : c\'est ce qui rend '
              'impossible qu\'une coquille tierce en ait une variante — le '
              'doublon que ce lot supprime (motif CR-LEX-78).');
      expect(sites.single.replaceAll(r'\', '/'),
          contains('view/z_chat_conversation_view.dart'));
    });

    test('🔬 contre-preuve — le motif VOIT une seconde instanciation', () {
      final RegExp use = RegExp(r'\bZChatMessageTile\s*\(');
      expect(use.hasMatch('      return ZChatMessageTile(message: m);'), isTrue);
      expect(use.hasMatch('  final ZChatMessageTile t = w;'), isFalse,
          reason: '🔴 sans l\'ancre `(`, une simple DÉCLARATION de type '
              'accuserait — et une garde qui crie au loup finit désactivée');
    });
  });
}

/// Renderer d'hôte qui prend en charge **le texte en cours** par la couture.
class _StreamingRenderer extends ZChatRenderer {
  const _StreamingRenderer();

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) {
    final ValueListenable<String>? live = request.streamingText;
    if (live == null) return null;
    // 🔴 L'abonnement est pris DANS le sous-arbre de l'hôte : c'est ce que le
    // type `ValueListenable` rend possible, et un `String` interdisait.
    return ValueListenableBuilder<String>(
      valueListenable: live,
      builder: (BuildContext context, String value, Widget? child) =>
          Text('HOTE:$value'),
    );
  }
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
