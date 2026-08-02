/// Gardes de la LISTE de conversations — CR-IFFD-39.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_chat_render_harness.dart';

final DateTime kNow = DateTime.utc(2026, 8, 2, 12);

ZChatConversation c(String id, String title, {int minutes = 5}) =>
    ZChatConversation(
      id: id,
      title: title,
      createdAt: kNow.subtract(const Duration(days: 1)),
      lastMessageAt: kNow.subtract(Duration(minutes: minutes)),
    );

/// Les titres RENDUS, dans l'ordre de l'arbre — jamais l'ordre d'une liste
/// intermédiaire.
///
/// 🔴 C'est le point de la garde de tri : IFFD trie `conversations` (`:189-192`)
/// et rend `rootConversations` (`:211`), une **copie** extraite AVANT le tri.
/// Une garde qui interrogerait la liste triée serait verte sur ce bug exact.
List<String> renderedTitles(WidgetTester t) => <String>[
  for (final ZChatConversationTile tile
      in t.widgetList<ZChatConversationTile>(
        find.byType(ZChatConversationTile),
      ))
    tile.conversation.title,
];

void main() {
  group('🔴 G39-7 — CHARGEMENT, VIDE et ERREUR sont TROIS états distincts', () {
    testWidgets('chargement ⇒ squelette, et surtout PAS « aucune conversation »',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          const ZChatConversationList(
            items: <ZChatConversation>[],
            status: ZChatConversationListStatus.loading,
          ),
        ),
      );
      // Le défaut d'IFFD : `initialData: const []` (`:164`) + un `builder` qui
      // ne teste NI `connectionState` NI `hasError` ⇒ la première frame affiche
      // `EmptyConversationsState` (`:198-205`).
      expect(find.text('Aucune conversation'), findsNothing,
          reason: '🔴 l\'état vide s\'affiche AVANT toute donnée — le défaut '
              'IFFD exact.');
      expect(
        findSemantics(t, (dynamic n) =>
            (n.label as String).contains('Chargement des conversations')),
        isNotNull,
        reason: '🔴 le squelette n\'est pas ANNONCÉ : un lecteur d\'écran ne '
            'sait pas que quelque chose arrive.',
      );
    });

    testWidgets('erreur ⇒ état d\'erreur, et PAS l\'état vide',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          const ZChatConversationList(
            items: <ZChatConversation>[],
            failure: ZServerFailure('boom'),
          ),
        ),
      );
      expect(
        find.text('Les conversations n\'ont pas pu être chargées'),
        findsOneWidget,
      );
      expect(find.text('Aucune conversation'), findsNothing,
          reason: '🔴 une erreur est indiscernable d\'une liste vide — le '
              'défaut IFFD : aucun `hasError` dans '
              '`conversation_list_widget.dart`.');
    });

    testWidgets('🔵 l\'ERREUR est testée AVANT le chargement — sinon l\'écran '
        'reste sur le squelette POUR TOUJOURS', (WidgetTester t) async {
      // L'idée de lex, reprise : un flux qui échoue PENDANT un rechargement
      // porte les DEUX états. Si le chargement gagne, l'utilisateur ne verra
      // jamais l'erreur, et le bouton « réessayer » n'est jamais atteignable.
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: const <ZChatConversation>[],
            status: ZChatConversationListStatus.loading,
            failure: const ZServerFailure('boom'),
            onRetry: () {},
          ),
        ),
      );
      expect(
        find.text('Les conversations n\'ont pas pu être chargées'),
        findsOneWidget,
        reason: '🔴 le chargement a gagné sur l\'erreur : l\'écran est bloqué '
            'sur le squelette et « Réessayer » est inatteignable.',
      );
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('prêt + vide ⇒ état vide, ni squelette ni erreur',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          const ZChatConversationList(items: <ZChatConversation>[]),
        ),
      );
      expect(find.text('Aucune conversation'), findsOneWidget);
      expect(
        find.text('Les conversations n\'ont pas pu être chargées'),
        findsNothing,
      );
      expect(
        findSemantics(t, (dynamic n) =>
            (n.label as String).contains('Chargement des conversations')),
        isNull,
      );
    });
  });

  group('🔴 G39-8 — l\'état vide a DEUX variantes, et l\'action de création est '
      'MASQUÉE en recherche', () {
    testWidgets('aucun élément ⇒ « aucune conversation » + création',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: const <ZChatConversation>[],
            onCreate: () {},
          ),
        ),
      );
      expect(find.text('Aucune conversation'), findsOneWidget);
      expect(find.text('Nouvelle conversation'), findsOneWidget);
    });

    testWidgets('recherche sans résultat ⇒ « aucun résultat », SANS création',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Douane')],
            searchTerm: 'zzz',
            matcher: zChatDefaultConversationMatcher,
            onCreate: () {},
          ),
        ),
      );
      expect(find.text('Aucun résultat'), findsOneWidget);
      expect(find.text('Aucune conversation'), findsNothing);
      expect(find.text('Nouvelle conversation'), findsNothing,
          reason: '🔴 « créer une conversation » ne répond PAS à « votre '
              'recherche ne rend rien » : c\'est un geste hors sujet, et il '
              'efface la seule information utile de l\'écran.');
    });
  });

  group('🔴 G39-9 — le TRI s\'applique à la liste RENDUE', () {
    testWidgets('l\'ordre des tuiles suit le comparateur, pas l\'entrée',
        (WidgetTester t) async {
      final List<ZChatConversation> items = <ZChatConversation>[
        c('a', 'Charlie'),
        c('b', 'Alpha'),
        c('c', 'Bravo'),
      ];
      // Contrôle NÉGATIF d'abord : sans tri, l'ordre est celui de l'entrée.
      await t.pumpWidget(harness(ZChatConversationList(items: items)));
      expect(renderedTitles(t), <String>['Charlie', 'Alpha', 'Bravo']);

      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: items,
            sort: (ZChatConversation x, ZChatConversation y) =>
                x.title.compareTo(y.title),
          ),
        ),
      );
      expect(renderedTitles(t), <String>['Alpha', 'Bravo', 'Charlie'],
          reason: '🔴 le tri ne touche PAS la liste rendue. C\'est le bug vif '
              'de `conversation_list_widget.dart` : `.where().toList()` produit '
              'une COPIE (`:176-180`), le tri s\'applique à la source '
              '(`:189-192`), et c\'est la copie qui est rendue (`:211`).');
    });

    testWidgets('le tri n\'écrase pas la liste de l\'HÔTE',
        (WidgetTester t) async {
      final List<ZChatConversation> items = <ZChatConversation>[
        c('a', 'Charlie'),
        c('b', 'Alpha'),
      ];
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: items,
            sort: (ZChatConversation x, ZChatConversation y) =>
                x.title.compareTo(y.title),
          ),
        ),
      );
      expect(items.map((ZChatConversation x) => x.title).toList(),
          <String>['Charlie', 'Alpha'],
          reason: '🔴 le socle a trié la liste de l\'hôte EN PLACE : tout autre '
              'consommateur de cette liste voit son ordre changer sous lui.');
    });
  });

  group('🔴 G39-10 — la SÉLECTION MULTIPLE entre et sort proprement', () {
    testWidgets('appui long ⇒ entrée ; appui ⇒ bascule ; sortie EXPLICITE',
        (WidgetTester t) async {
      final ZChatConversationSelection sel = ZChatConversationSelection();
      addTearDown(sel.dispose);
      final List<String> opened = <String>[];
      final List<Set<String>> retired = <Set<String>>[];
      Widget tree() => harness(
        ZChatConversationList(
          items: <ZChatConversation>[c('a', 'Alpha'), c('b', 'Bravo')],
          selection: sel,
          onOpen: (ZChatConversation x) => opened.add(x.id!),
          onRetireSelected: retired.add,
        ),
      );

      await t.pumpWidget(tree());
      expect(sel.active, isFalse);
      expect(find.text('Quitter la sélection'), findsNothing);

      // Hors mode : l'appui OUVRE.
      await t.tap(find.text('Alpha'));
      await t.pump();
      expect(opened, <String>['a']);

      await t.longPress(find.text('Alpha'));
      await t.pump();
      expect(sel.active, isTrue);
      expect(sel.count, 1);
      expect(find.text('1 sélectionnée(s)'), findsOneWidget);

      // En mode : l'appui COCHE, il n'ouvre plus.
      await t.tap(find.text('Bravo'));
      await t.pump();
      expect(sel.count, 2);
      expect(opened, <String>['a'],
          reason: '🔴 l\'appui ouvre ENCORE la conversation en mode sélection : '
              'cocher une case fait quitter l\'écran.');
      expect(find.text('2 sélectionnée(s)'), findsOneWidget);

      // Le lot atteint `retireAll` avec les identités cochées.
      await t.tap(find.text('Retirer la sélection'));
      await t.pump();
      expect(retired, <Set<String>>[<String>{'a', 'b'}]);

      // Décocher tout ne fait PAS sortir du mode (sinon la ligne suivante est
      // touchée à vide).
      await t.tap(find.text('Alpha'));
      await t.tap(find.text('Bravo'));
      await t.pump();
      expect(sel.count, 0);
      expect(sel.active, isTrue);

      await t.tap(find.text('Quitter la sélection'));
      await t.pump();
      expect(sel.active, isFalse);
      expect(find.text('Quitter la sélection'), findsNothing);
    });

    testWidgets('sans contrôleur, AUCUNE surface de sélection n\'apparaît',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(items: <ZChatConversation>[c('a', 'Alpha')]),
        ),
      );
      expect(find.text('Quitter la sélection'), findsNothing);
      expect(find.text('Retirer la sélection'), findsNothing);
    });

    testWidgets('l\'action de LOT est absente si son callback est nul',
        (WidgetTester t) async {
      final ZChatConversationSelection sel = ZChatConversationSelection()
        ..begin('a');
      addTearDown(sel.dispose);
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha')],
            selection: sel,
          ),
        ),
      );
      expect(find.text('1 sélectionnée(s)'), findsOneWidget);
      expect(find.text('Retirer la sélection'), findsNothing,
          reason: '🔴 un bouton de retrait par lot sans `retireAll` derrière : '
              'l\'appui ne fait rien, et l\'utilisateur croit avoir supprimé.');
    });
  });

  group('🔴 G39-11 — PAGINATION par curseur', () {
    testWidgets('`hasMore` + `onLoadMore` ⇒ la ligne existe et se déclenche',
        (WidgetTester t) async {
      int calls = 0;
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha')],
            hasMore: true,
            onLoadMore: () => calls++,
          ),
        ),
      );
      await t.pump();
      expect(calls, 1, reason: '🔴 la ligne de fin est montée mais ne charge '
          'rien : la pagination reste MORTE, comme les trois définitions de '
          '`getConversations` de lex, qui n\'ont aucun appelant d\'UI.');
      // …et une seule fois par montage (sinon `hasMore` toujours vrai boucle).
      await t.pump();
      expect(calls, 1);
    });

    testWidgets('sans `onLoadMore`, aucune ligne de pagination',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha')],
            hasMore: true,
          ),
        ),
      );
      expect(find.text('Charger la suite'), findsNothing,
          reason: '🔴 ne pas passer le callback EST le drapeau — il ne doit '
              'rester aucun bouton inerte.');
      // 🔴 GARDE RETENDUE PAR R3 (injection n°12). La forme d'origine ne
      // regardait que le TEXTE : une ligne de pagination FANTÔME — ajoutée à la
      // liste, puis rendue `SizedBox.shrink()` faute de callback — la laissait
      // VERTE. Elle mesurait le rendu, alors que ce qu'on promet ici est
      // qu'aucune ligne n'existe. Le compte de la delegate le dit, lui.
      expect(t.widget<ListView>(find.byType(ListView)).semanticChildCount, 1,
          reason: '🔴 une ligne FANTÔME occupe un index : la liste annonce une '
              'ligne de plus qu\'elle n\'a de conversations, et un lecteur '
              'd\'écran compte faux.');
    });

    testWidgets('🔬 contre-preuve — avec `onLoadMore`, la ligne EXISTE bien',
        (WidgetTester t) async {
      // Sans ceci, l'assertion de compte ci-dessus serait verte sur une liste
      // qui n'ajouterait JAMAIS de ligne de pagination.
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha')],
            hasMore: true,
            autoLoadMore: false,
            onLoadMore: () {},
          ),
        ),
      );
      expect(t.widget<ListView>(find.byType(ListView)).semanticChildCount, 2);
    });

    testWidgets('en mode manuel, la ligne se tape', (WidgetTester t) async {
      int calls = 0;
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha')],
            hasMore: true,
            autoLoadMore: false,
            onLoadMore: () => calls++,
          ),
        ),
      );
      await t.pump();
      expect(calls, 0);
      await t.tap(find.text('Charger la suite'));
      expect(calls, 1);
    });
  });

  group('🔴 G39-12 — les SLOTS : enveloppe, en-tête, groupes', () {
    testWidgets('`itemWrapper` enveloppe CHAQUE ligne', (WidgetTester t) async {
      // C'est le slot sans lequel IFFD réécrit la tuile : chaque ligne y PULSE
      // tant que sa génération n'est pas finie, avec un contrôleur PAR ligne.
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha'), c('b', 'Bravo')],
            itemWrapper:
                (BuildContext ctx, ZChatConversation x, Widget child) =>
                    DecoratedBox(
                      key: ValueKey<String>('wrap#${x.id}'),
                      decoration: const BoxDecoration(),
                      child: child,
                    ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('wrap#a')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('wrap#b')), findsOneWidget);
    });

    testWidgets('slot d\'en-tête de liste', (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha')],
            header: const SizedBox(key: ValueKey<String>('head'), height: 10),
          ),
        ),
      );
      expect(find.byKey(const ValueKey<String>('head')), findsOneWidget);
    });

    testWidgets('la clé de groupe est OPAQUE et le repliement survit au REBUILD',
        (WidgetTester t) async {
      // 🔴 Le bug d'IFFD : `folder_conversations_widget.dart:200-203` crée son
      // `ExpandableController` DANS `build`. Chaque rebuild — donc chaque tick
      // du stream parent — rouvre les groupes repliés.
      final ZChatGroupExpansion exp = ZChatGroupExpansion();
      addTearDown(exp.dispose);
      Widget tree(List<ZChatConversation> items) => harness(
        ZChatConversationList(
          items: items,
          groupExpansion: exp,
          // Une clé opaque : un enregistrement, pas un `String` — la hiérarchie
          // d'un hôte n'a pas à tenir dans un champ du socle.
          groupKeyOf: (ZChatConversation x) => (x.id!.compareTo('b') < 0,),
          groupHeaderBuilder:
              (BuildContext ctx, Object? key, int n) =>
                  Text('G$key ($n)'),
        ),
      );

      await t.pumpWidget(tree(<ZChatConversation>[c('a', 'Alpha'), c('c', 'Charlie')]));
      expect(renderedTitles(t), <String>['Alpha', 'Charlie']);
      expect(find.textContaining('G('), findsNWidgets(2));

      await t.tap(find.textContaining('true'));
      await t.pump();
      expect(renderedTitles(t), <String>['Charlie'],
          reason: '🔴 le repliement ne retire pas les lignes : un groupe replié '
              'coûte toujours ses éléments.');

      // 🔴 LE point : un rebuild complet avec des données neuves.
      await t.pumpWidget(
        tree(<ZChatConversation>[c('a', 'Alpha'), c('c', 'Charlie'), c('d', 'Delta')]),
      );
      expect(renderedTitles(t), <String>['Charlie', 'Delta'],
          reason: '🔴 le groupe s\'est ROUVERT au rebuild : le contrôleur '
              'd\'expansion est recréé quelque part — le défaut d\'IFFD, '
              'reconstitué dans le socle.');
      exp.reset();
    });

    testWidgets('sans en-tête de groupe, la liste reste PLATE',
        (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[c('a', 'Alpha'), c('b', 'Bravo')],
            groupKeyOf: (ZChatConversation x) => x.id,
          ),
        ),
      );
      expect(renderedTitles(t), <String>['Alpha', 'Bravo']);
    });
  });

  group('🔴 G39-13 — la liste est VIRTUALISÉE', () {
    testWidgets('c\'est bien une `ListView.builder`, avec une delegate '
        'PARESSEUSE', (WidgetTester t) async {
      await t.pumpWidget(
        harness(
          ZChatConversationList(
            items: <ZChatConversation>[
              for (int i = 0; i < 200; i++) c('c$i', 'Titre $i'),
            ],
          ),
        ),
      );
      final ListView view = t.widget<ListView>(find.byType(ListView));
      expect(view.childrenDelegate, isA<SliverChildBuilderDelegate>(),
          reason: '🔴 la delegate n\'est plus paresseuse. IFFD : `ListView('
              'children: […])` (`conversation_list_widget.dart:207`), zéro '
              '`ListView.builder` dans tout `ai_assistant/`.');
      expect(t.widgetList<ZChatConversationTile>(
              find.byType(ZChatConversationTile)).length,
          lessThan(200),
          reason: '🔴 les 200 tuiles sont montées : la virtualisation ne '
              'produit aucun effet.');
    });
  });

  group('🔴 G39-14 — les descripteurs : une action ABSENTE si son callback est '
      'nul', () {
    test('aucun callback ⇒ aucun descripteur', () {
      expect(zChatConversationActions(), isEmpty);
    });

    test('chaque callback ouvre EXACTEMENT son descripteur', () {
      expect(
        zChatConversationActions(onShare: (_) {})
            .map((ZChatConversationAction a) => a.labelKey),
        <String>[kZChatLabelShare],
        reason: '🔴 une action « épingler » codée en dur serait MORTE chez '
            'IFFD : `grep -rn "pinned" iffd/lib/ai_assistant/` ⇒ EXIT=1.',
      );
      expect(
        zChatConversationActions(onSetPinned: (_, {required bool pinned}) {})
            .map((ZChatConversationAction a) => a.labelKey),
        <String>[kZChatLabelPin, kZChatLabelUnpin],
      );
      expect(
        zChatConversationActions(onRestore: (_) {})
            .map((ZChatConversationAction a) => a.labelKey),
        <String>[kZChatLabelRestore],
      );
      // Les six clés du catalogue sont toutes atteignables — sinon une opération
      // du kernel n'aurait aucune entrée.
      final Set<String> all = zChatConversationActions(
        onSetPinned: (_, {required bool pinned}) {},
        onShare: (_) {},
        onTrim: (_) {},
        onRestore: (_) {},
        onRetire: (_) {},
      ).map((ZChatConversationAction a) => a.labelKey).toSet();
      expect(all, kZChatConversationActionKeys.toSet());
    });

    test('`setPinned` est UN verbe : deux libellés, deux prédicats exclusifs',
        () {
      final List<bool> writes = <bool>[];
      final List<ZChatConversationAction> a = zChatConversationActions(
        onSetPinned: (ZChatConversation x, {required bool pinned}) =>
            writes.add(pinned),
      );
      const ZChatConversation off = ZChatConversation(id: 'x');
      final ZChatConversation on = off.copyWith(pinned: true);
      expect(a.where((ZChatConversationAction x) => x.visibleFor(off)).length, 1);
      expect(a.where((ZChatConversationAction x) => x.visibleFor(on)).length, 1);
      a.firstWhere((ZChatConversationAction x) => x.visibleFor(off)).onInvoke(off);
      a.firstWhere((ZChatConversationAction x) => x.visibleFor(on)).onInvoke(on);
      expect(writes, <bool>[true, false]);
    });

    testWidgets('une action rendue APPELLE son callback, et la confirmation '
        'peut l\'ANNULER', (WidgetTester t) async {
      final List<String> done = <String>[];
      await t.pumpWidget(
        harness(
          ZChatConversationTile(
            conversation: c('a', 'Alpha'),
            now: kNow,
            actions: zChatConversationActions(
              onRetire: (ZChatConversation x) => done.add(x.id!),
              confirmRetire: (BuildContext ctx) async => false,
            ),
          ),
        ),
      );
      await t.tap(find.text('Retirer la conversation'));
      await t.pumpAndSettle();
      expect(done, isEmpty,
          reason: '🔴 la confirmation a refusé et le retrait a eu lieu quand '
              'même. lex documente un *undo* qu\'il n\'a pas '
              '(`conversations_screen.dart:29`, `:259` ; '
              '`grep -n "SnackBarAction"` ⇒ EXIT=1) : le socle ne doit pas '
              'ajouter une seconde promesse creuse.');
    });

    testWidgets('sans confirmation, l\'action passe directement',
        (WidgetTester t) async {
      final List<String> done = <String>[];
      await t.pumpWidget(
        harness(
          ZChatConversationTile(
            conversation: c('a', 'Alpha'),
            now: kNow,
            actions: zChatConversationActions(
              onRetire: (ZChatConversation x) => done.add(x.id!),
            ),
          ),
        ),
      );
      await t.tap(find.text('Retirer la conversation'));
      await t.pumpAndSettle();
      expect(done, <String>['a']);
    });
  });
}
