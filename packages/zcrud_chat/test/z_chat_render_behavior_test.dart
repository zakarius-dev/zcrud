/// Gardes de **COMPORTEMENT** du rendu neutre — CHAT-3.
///
/// Les gardes de source (`z_chat_render_guard_test.dart`) prouvent ce qui est
/// écrit ; celles-ci prouvent ce qui **se produit à l'écran**. Aucune des deux
/// ne remplace l'autre : un `ListView.builder` correctement écrit peut être
/// enveloppé dans un `SingleChildScrollView` qui annule la virtualisation, et
/// un `Semantics` correctement écrit peut ne produire **aucun nœud** s'il est
/// posé sur un widget de taille nulle.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_fakes.dart';
import 'support/z_chat_render_harness.dart';

void main() {
  group('🔴 G-R1 — NEUTRALITÉ : sans renderer, et avec un renderer qui '
      'décline, le rendu est STRICTEMENT identique', () {
    testWidgets('même arbre de textes, et le seam a bien été interrogé', (
      WidgetTester tester,
    ) async {
      final ZChatMessage message = assistant(<ZContentBlock>[
        const ZTextBlock(text: 'bonjour'),
        const ZTableBlock(
          title: 'tarif',
          headers: <String>['code', 'droit'],
          rows: <List<String>>[
            <String>['01', '5%'],
          ],
        ),
        const ZAlertBlock(level: 'warning', title: 'attention', message: 'lis'),
      ]);

      await tester.pumpWidget(harness(ZChatMessageTile(message: message)));
      final List<String> withoutScope = renderedTexts(tester);

      final DecliningRenderer declining = DecliningRenderer();
      await tester.pumpWidget(
        harness(ZChatMessageTile(message: message), renderer: declining),
      );
      final List<String> withDecliningRenderer = renderedTexts(tester);

      // 🔴 NON-VACUITÉ : sans cette assertion, un seam jamais appelé rendrait
      // l'égalité ci-dessous trivialement vraie — la garde ne prouverait rien.
      expect(
        declining.seen.map((ZChatBlockRenderRequest r) => r.block.kind).toList(),
        <String>['text', 'table', 'alert'],
        reason: '🔴 le seam n\'a pas été interrogé BLOC PAR BLOC : la prise en '
            'charge partielle promise par le contrat est impossible',
      );
      expect(withoutScope, isNotEmpty);
      expect(
        withDecliningRenderer,
        withoutScope,
        reason: '🔴 un renderer qui décline TOUT doit laisser un rendu au mot '
            'près identique à l\'absence de scope. C\'est l\'invariant AC9 de '
            'VIS transposé : le défaut ne bouge pas quand on branche une '
            'couture.',
      );
    });

    testWidgets('prise en charge PARTIELLE : un seul `kind` est dérouté, les '
        'autres gardent le rendu neutre', (WidgetTester tester) async {
      final ZChatMessage message = assistant(<ZContentBlock>[
        const ZTextBlock(text: 'neutre'),
        ZCustomContentBlock('mindmap', const <String, dynamic>{'n': 1}),
      ]);
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(message: message),
          renderer: const KindRenderer(kind: 'mindmap', marker: 'CARTE'),
        ),
      );
      final List<String> texts = renderedTexts(tester);
      expect(texts, contains('neutre'),
          reason: '🔴 un bloc décliné a perdu son rendu neutre');
      expect(texts, contains('CARTE'),
          reason: '🔴 le bloc pris en charge n\'a pas été dérouté vers l\'hôte');
      expect(texts, isNot(contains('mindmap')),
          reason: '🔴 le repli neutre a été rendu EN PLUS du renderer de '
              'l\'hôte — double rendu');
    });

    testWidgets('AD-10 — la chaîne est TOTALE : aucun scope, un scope à '
        'renderer `null`, un renderer qui décline ⇒ jamais de throw', (
      WidgetTester tester,
    ) async {
      final ZChatMessage message = assistant(<ZContentBlock>[
        const ZTextBlock(text: 'x'),
      ]);
      for (final Widget tree in <Widget>[
        harness(ZChatMessageTile(message: message)),
        harness(
          ZChatRendererScope(
            renderer: null,
            child: ZChatMessageTile(message: message),
          ),
        ),
        harness(
          ZChatMessageTile(message: message),
          renderer: DecliningRenderer(),
        ),
      ]) {
        await tester.pumpWidget(tree);
        expect(tester.takeException(), isNull);
        expect(find.text('x'), findsOneWidget);
      }
    });
  });

  group('🔴 G-R2 — VIRTUALISATION prouvée PAR SON MÉCANISME', () {
    testWidgets('la liste est bâtie par un `SliverChildBuilderDelegate` — pas '
        'par comptage de tuiles montées', (WidgetTester tester) async {
      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController(
        initialMessages: <ZChatMessage>[
          for (int i = 0; i < 200; i++)
            assistant(<ZContentBlock>[
              ZTextBlock(text: 'message $i'),
            ], id: 'm$i'),
        ],
      );
      addTearDown(rig.controller.dispose);

      await tester.pumpWidget(
        harness(ZChatConversationView(controller: rig.controller)),
      );

      final ListView list = tester.widget<ListView>(find.byType(ListView));
      // 🔴 LE MÉCANISME : un délégué PARESSEUX. Compter les tuiles montées
      // serait une garde faible — le viewport culle des deux côtés, et un
      // `ListView(children:)` sous un viewport suffisamment petit afficherait
      // le même petit nombre de tuiles tout en ayant TOUT construit.
      expect(
        list.childrenDelegate,
        isA<SliverChildBuilderDelegate>(),
        reason: '🔴 SM-1 : la conversation doit être VIRTUALISÉE. Un '
            '`SliverChildListDelegate` (produit par `ListView(children: [...])`) '
            'construit les 200 tuiles — et chaque tuile de chat porte un rendu '
            'de blocs. C\'est la dette d\'IFFD : 0 `ListView.builder` dans '
            '5153 lignes.',
      );
      expect(
        (list.childrenDelegate as SliverChildBuilderDelegate)
            .estimatedChildCount,
        200,
        reason: '🔴 le délégué ne couvre pas tous les messages',
      );

      // Preuve COMPLÉMENTAIRE, du côté du rendu : le sliver n'a matérialisé
      // qu'une fenêtre. Elle ne remplace PAS l'assertion de mécanisme
      // ci-dessus — elle la corrobore.
      final RenderSliverList sliver = tester.renderObject<RenderSliverList>(
        find.byType(SliverList),
      );
      int materialised = 0;
      RenderBox? node = sliver.firstChild;
      while (node != null) {
        materialised++;
        node = sliver.childAfter(node);
      }
      expect(materialised, lessThan(200));
      expect(materialised, greaterThan(0));
    });

    testWidgets('🔬 contre-preuve R3 — l\'assertion de mécanisme SAIT rougir '
        'sur un délégué non paresseux', (WidgetTester tester) async {
      // Le témoin est un `ListView(children:)` monté ICI, dans le test : il
      // prouve que `isA<SliverChildBuilderDelegate>()` n'est pas satisfait par
      // n'importe quel `ListView`. Sans lui, la garde ci-dessus pourrait être
      // vraie « par construction » et ne rien discriminer.
      await tester.pumpWidget(
        harness(ListView(children: const <Widget>[Text('a'), Text('b')])),
      );
      final ListView eager = tester.widget<ListView>(find.byType(ListView));
      expect(eager.childrenDelegate, isNot(isA<SliverChildBuilderDelegate>()));
      expect(eager.childrenDelegate, isA<SliverChildListDelegate>());
    });
  });

  group('🔴 G-R3 — ANNONCE : le contenu qui arrive est ANNONÇABLE', () {
    testWidgets('un nœud sémantique porte le drapeau LIVE REGION et le texte '
        'annoncé — la présence d\'un `Semantics` ne suffit pas', (
      WidgetTester tester,
    ) async {
      // 🔴 `addTearDown(handle.dispose)` NE SUFFIT PAS : la vérification
      // « aucun SemanticsHandle actif » de `flutter_test` s'exécute AVANT les
      // tearDowns. Le handle est donc libéré explicitement en fin de test.
      final SemanticsHandle handle = tester.ensureSemantics();

      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController();
      addTearDown(rig.controller.dispose);

      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          labels: <String, String>{kZChatLabelLiveRegion: 'conversation'},
        ),
      );

      SemanticsNode? live() => findSemantics(
        tester,
        (SemanticsNode n) =>
            n.getSemanticsData().flagsCollection.isLiveRegion,
      );

      expect(live(), isNotNull,
          reason: '🔴 aucune région live : une réponse en streaming serait '
              'MUETTE au lecteur d\'écran — la dette d\'IFFD (0 `Semantics` '
              'sur tout le chat)');
      expect(live()!.label, 'conversation');

      // Le tour se termine : le contrôleur publie une annonce.
      rig.controller.composer.text = 'question';
      // 🔴 `send()` ne se complète qu'à la FIN du flux : l'attendre ici
      // bloquerait le test avant d'avoir pu émettre le moindre jeton.
      final Future<ZResult<ZChatRequestToken>> sending = rig.controller.send();
      await tester.pump();
      rig.port.last.add(tok('réponse '));
      rig.port.last.add(tok('complète'));
      rig.port.last.add(done());
      await rig.port.last.close();
      await sending;
      await tester.pumpAndSettle();

      final SemanticsNode? after = live();
      expect(after, isNotNull);
      expect(
        after!.label,
        contains('réponse'),
        reason: '🔴 c\'est l\'ANNONCE qui est mesurée, pas la présence d\'un '
            'nœud : le libellé de la région doit devenir celui de la réponse, '
            'sans quoi le lecteur d\'écran ne dit rien de neuf.',
      );
      expect(
        after.getSemanticsData().flagsCollection.isLiveRegion,
        isTrue,
        reason: '🔴 le drapeau a été perdu à la mise à jour — le nœud existe '
            'mais ne sera JAMAIS annoncé automatiquement',
      );
      handle.dispose();
    });

    testWidgets('la réponse en cours est elle-même étiquetée', (
      WidgetTester tester,
    ) async {
      // 🔴 `addTearDown(handle.dispose)` NE SUFFIT PAS : la vérification
      // « aucun SemanticsHandle actif » de `flutter_test` s'exécute AVANT les
      // tearDowns. Le handle est donc libéré explicitement en fin de test.
      final SemanticsHandle handle = tester.ensureSemantics();
      final ({
        ZChatController controller,
        FakeStreamPort port,
        SpyExecutor executor,
        SeqIds ids,
        List<ZChatActionPlan> confirmed,
      })
      rig = buildController();
      addTearDown(rig.controller.dispose);

      await tester.pumpWidget(
        harness(
          ZChatConversationView(controller: rig.controller),
          labels: <String, String>{kZChatLabelStreaming: 'réponse en cours'},
        ),
      );
      rig.controller.composer.text = 'q';
      final Future<ZResult<ZChatRequestToken>> sending = rig.controller.send();
      await tester.pump();
      rig.port.last.add(tok('par'));
      await tester.pumpAndSettle();

      expect(find.text('par'), findsOneWidget,
          reason: '🔴 le texte en cours n\'est pas rendu');
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) => n.label.contains('réponse en cours'),
        ),
        isNotNull,
        reason: '🔴 la tuile de streaming n\'est pas identifiable au lecteur '
            'd\'écran',
      );
      await rig.port.closeAll();
      await sending;
      await tester.pumpAndSettle();
      handle.dispose();
    });
  });

  group('🔴 G-R4 — DÉPLI INLINE RÉEL (le défaut `showAll` d\'IFFD)', () {
    testWidgets('déplier AUGMENTE la hauteur de la tuile et ne pousse AUCUNE '
        'route', (WidgetTester tester) async {
      final RouteSpy spy = RouteSpy();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[spy],
          home: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topStart,
              child: ZChatMessageTile(
                // 🔴 20 lignes, pas 40 : la surface de test fait 600 dp de
                // haut. Un contenu déplié plus grand y serait ÉCRASÉ par le
                // viewport, et la garde mesurerait 600 dans les deux états —
                // verte sur une régression.
                message: assistant(<ZContentBlock>[longText(20)]),
                collapsedMaxHeight: 60,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder tile = find.byType(ZChatMessageTile);
      final double collapsed = tester.getSize(tile).height;
      final int pushedBefore = spy.pushed;

      expect(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!), findsOneWidget,
          reason: '🔴 aucun bouton de dépli alors que le contenu DÉPASSE');

      await tester.tap(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!));
      await tester.pumpAndSettle();

      final double expanded = tester.getSize(tile).height;
      expect(
        expanded,
        greaterThan(collapsed),
        reason: '🔴 LE défaut d\'IFFD : « Afficher plus » ne déplie pas. La '
            'contrainte de hauteur y est pilotée par un `showAll` MASQUANT '
            '(`:4124`) tandis que le bouton lit le `showAll` MASQUÉ (`:3733`) '
            '— les deux ne se rencontrent jamais.',
      );
      expect(
        spy.pushed,
        pushedBefore,
        reason: '🔴 le dépli a POUSSÉ UNE ROUTE : c\'est une ouverture plein '
            'écran déguisée en dépli, exactement ce que fait la branche '
            '`exportExplanationToPdf` d\'IFFD sous le libellé « Afficher plus ».',
      );
      expect(tile, findsOneWidget,
          reason: '🔴 la tuile a été remplacée : le dépli n\'est pas INLINE');
      expect(find.text(kZChatLabelFallbacks[kZChatLabelShowLess]!), findsOneWidget);

      // …et le repli redevient exactement l'état initial (le geste est
      // réversible, pas un aller simple).
      await tester.tap(find.text(kZChatLabelFallbacks[kZChatLabelShowLess]!));
      await tester.pumpAndSettle();
      expect(tester.getSize(tile).height, collapsed);
    });

    testWidgets('COÛT à densité contrainte : replié, la tuile ne dépasse PAS '
        'la hauteur demandée', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(200)]),
              collapsedMaxHeight: 48,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final RenderBox content = tester.renderObject<RenderBox>(
        find.byType(ZChatMessageTile),
      );
      // 🔴 On mesure le COÛT de la surface, pas seulement son rendu : un slot
      // « correct » mais qui occupe 200 lignes à l'état replié est inutilisable
      // à densité contrainte — le dépôt l'a déjà payé (CR-IFFD-37).
      expect(
        content.size.height,
        lessThan(48 + kZChatMinTapTarget + 8),
        reason: '🔴 la tuile repliée occupe ${content.size.height} dp pour une '
            'hauteur repliée de 48 dp + un bouton de 48 dp : la contrainte '
            'n\'est pas appliquée',
      );
    });

    testWidgets('aucun bouton quand il n\'y a RIEN à déplier — un geste sans '
        'effet est une promesse non tenue', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[
                const ZTextBlock(text: 'court'),
              ]),
              collapsedMaxHeight: 400,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('court'), findsOneWidget);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!), findsNothing);
    });

    testWidgets('sans `collapsedMaxHeight`, le message est ENTIER et sans '
        'bouton (défaut non tronquant)', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          SingleChildScrollView(
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!), findsNothing);
      expect(find.textContaining('ligne 39'), findsOneWidget);
    });
  });

  group('🔴 G-R5 — AD-13 : cible tactile ≥ 48 dp et RTL réel', () {
    testWidgets('la cible du bouton de dépli mesure au moins 48 dp', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 60,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final Size target = tester.getSize(
        find.ancestor(
          of: find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!),
          matching: find.byType(ConstrainedBox),
        ).first,
      );
      expect(target.height, greaterThanOrEqualTo(kZChatMinTapTarget));
      expect(target.width, greaterThanOrEqualTo(kZChatMinTapTarget));
    });

    testWidgets('RTL — le bouton se pose du côté DÉBUT du texte, à droite', (
      WidgetTester tester,
    ) async {
      Future<double> startEdge(TextDirection direction) async {
        await tester.pumpWidget(
          harness(
            ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 60,
            ),
            direction: direction,
          ),
        );
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!)).dx;
      }

      final double ltr = await startEdge(TextDirection.ltr);
      final double rtl = await startEdge(TextDirection.rtl);
      expect(
        rtl,
        greaterThan(ltr),
        reason: '🔴 AD-13 : l\'alignement du bouton ne suit pas la direction '
            'du texte. Avec `Alignment.centerLeft` au lieu de '
            '`AlignmentDirectional.centerStart`, ces deux positions seraient '
            'IDENTIQUES.',
      );
    });

    testWidgets('RTL — le tableau neutre suit la direction du texte', (
      WidgetTester tester,
    ) async {
      Future<double> firstCell(TextDirection direction) async {
        await tester.pumpWidget(
          harness(
            ZChatMessageTile(
              message: assistant(<ZContentBlock>[
                const ZTableBlock(
                  headers: <String>['A', 'B'],
                  rows: <List<String>>[
                    <String>['1', '2'],
                  ],
                ),
              ]),
            ),
            direction: direction,
          ),
        );
        await tester.pumpAndSettle();
        return tester.getTopLeft(find.text('A')).dx;
      }

      expect(
        await firstCell(TextDirection.rtl),
        greaterThan(await firstCell(TextDirection.ltr)),
        reason: '🔴 la première colonne reste à gauche en RTL : le tableau est '
            'figé en LTR',
      );
    });
  });

  group('🔴 G-R6 — les libellés viennent du REGISTRE, jamais du socle', () {
    testWidgets('un `ZcrudLabels` injecté remplace la clé rendue', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 60,
            ),
          ),
          // 🔴 Un libellé d'hôte DISTINCT du repli — sans quoi le test serait
          // vert même si le registre n'était jamais consulté (HIGH-1 : le
          // repli vaut désormais « Afficher plus »).
          labels: <String, String>{kZChatLabelShowMore: 'Déployer (hôte)'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Déployer (hôte)'), findsOneWidget);
      expect(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!), findsNothing,
          reason: '🔴 le REPLI a gagné sur le registre de l\'hôte : la '
              'priorité `ZcrudScope.labels` → … → repli est inversée');
      expect(find.text(kZChatLabelShowMore), findsNothing,
          reason: '🔴 la clé brute atteint l\'écran');
    });

    testWidgets('sans registre, c\'est le REPLI LISIBLE qui s\'affiche — '
        'jamais la clé brute (HIGH-1)', (WidgetTester tester) async {
      await tester.pumpWidget(
        harness(
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ZChatMessageTile(
              message: assistant(<ZContentBlock>[longText(40)]),
              collapsedMaxHeight: 60,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 🔴 **GARDE RENVERSÉE (HIGH-1).** Elle assertait l'inverse : « sans
      // registre, c'est la CLÉ qui s'affiche ». Elle défendait donc, en toute
      // rigueur, le défaut — un hôte au registre non alimenté lisait
      // littéralement `zchat.showMore` sur son bouton, et un lecteur d'écran
      // s'entendait annoncer `zchat.liveRegion`. Le dépôt avait déjà tranché
      // dans l'autre sens (`zcrud_session` : `label(context, 'cancel',
      // fallback: 'Annuler')`). Ce qu'elle défend maintenant : le repli est
      // LISIBLE, et la clé brute n'atteint JAMAIS l'écran.
      expect(find.text(kZChatLabelFallbacks[kZChatLabelShowMore]!),
          findsOneWidget,
          reason: '🔴 aucun repli lisible : la clé brute atteint l\'écran');
      expect(find.text(kZChatLabelShowMore), findsNothing,
          reason: '🔴 la CLÉ BRUTE est affichée — le défaut HIGH-1 exactement.');
    });
  });

  group('🔴 G-R7 — un `kind` inconnu n\'est PAS dumpé à l\'écran (D5)', () {
    testWidgets('le payload n\'apparaît pas ; le bloc est signalé', (
      WidgetTester tester,
    ) async {
      // 🔴 `addTearDown(handle.dispose)` NE SUFFIT PAS : la vérification
      // « aucun SemanticsHandle actif » de `flutter_test` s'exécute AVANT les
      // tearDowns. Le handle est donc libéré explicitement en fin de test.
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        harness(
          ZChatMessageTile(
            message: assistant(<ZContentBlock>[
              ZCustomContentBlock('legalReference', const <String, dynamic>{
                'articles': <String>['art. 42'],
              }),
            ]),
          ),
          labels: <String, String>{
            kZChatLabelUnsupportedBlock: 'contenu non pris en charge',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('art. 42'), findsNothing,
          reason: '🔴 le payload brut est affiché : le défaut de lex '
              '(`TextBlock(text: json.toString())`) est reproduit un étage '
              'plus haut');
      expect(
        findSemantics(
          tester,
          (SemanticsNode n) => n.label.contains('contenu non pris en charge'),
        ),
        isNotNull,
      );
      handle.dispose();
    });
  });
}
