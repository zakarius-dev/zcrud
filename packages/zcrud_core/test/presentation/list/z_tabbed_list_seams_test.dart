// CR tabbed-list (recherche & état, 2026-08-12) : seams de `ZTabbedList` /
// `ZListTab`.
//
// Gardes :
// 1. `header` : le widget partagé est rendu AU-DESSUS de la barre d'onglets
//    (présent dans l'arbre, dy < dy du TabBar) ; sans header, rien n'est rendu.
// 2. `pageKey` découple libellé et clé de page : deux onglets HOMONYMES à
//    `pageKey` distinctes construisent sans assert (clés de page distinctes) ;
//    une COLLISION de `pageKey` déclenche l'assert d'unicité.
// 3. `activeIndexNotifier` suit l'onglet actif : positionné à l'index initial
//    effectif dès le montage (sans passer par `onTabChanged`), puis à chaque
//    changement — AVANT l'appel de `onTabChanged`.
// 4. `canCreate` : transporté intact (constructeur + fabrique `category`) et
//    respecté au point où le geste de création de l'hôte consomme
//    `defaultItemBuilder` (onglet actif via le notifieur).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

ZListTab _tab(String labelKey, String page, {String? pageKey}) => ZListTab(
      labelKey: labelKey,
      pageKey: pageKey,
      builder: (context) => Text('page-$page'),
    );

Widget _host(Widget child, {Map<String, String> labels = const {}}) {
  return MaterialApp(
    home: Scaffold(
      body: ZcrudScope(
        labels: ZcrudLabels(labels),
        child: child,
      ),
    ),
  );
}

void main() {
  group('header (garde 1)', () {
    testWidgets('rendu AU-DESSUS de la barre d\'onglets', (tester) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            header: const TextField(key: ValueKey('sharedSearch')),
            tabs: <ZListTab>[_tab('tab.a', 'a'), _tab('tab.b', 'b')],
          ),
          labels: const {'tab.a': 'Alpha', 'tab.b': 'Bravo'},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('sharedSearch')), findsOneWidget);
      final headerTop =
          tester.getTopLeft(find.byKey(const ValueKey('sharedSearch')));
      final tabBarTop = tester.getTopLeft(find.byType(TabBar));
      expect(
        headerTop.dy,
        lessThan(tabBarTop.dy),
        reason: 'le header est posé au-dessus de la barre d\'onglets',
      );
      // Le header partage l'arbre des onglets (même Column ancêtre direct).
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('sharedSearch')),
          matching: find.ancestor(
            of: find.byType(TabBar),
            matching: find.byType(Column),
          ),
        ),
        findsWidgets,
      );
    });

    testWidgets('null (défaut) : aucun en-tête rendu', (tester) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            tabs: <ZListTab>[_tab('tab.a', 'a'), _tab('tab.b', 'b')],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sharedSearch')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('pageKey (garde 2)', () {
    testWidgets(
        'deux libellés IDENTIQUES + pageKey distinctes = construction OK',
        (tester) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            tabs: <ZListTab>[
              _tab('tab.same', 'un', pageKey: 'k1'),
              _tab('tab.same', 'deux', pageKey: 'k2'),
            ],
          ),
          labels: const {'tab.same': 'Homonyme'},
        ),
      );
      await tester.pumpAndSettle();

      // Pas d'assert de collision : les deux onglets homonymes coexistent.
      expect(tester.takeException(), isNull);
      expect(find.text('Homonyme'), findsNWidgets(2));
      // Les clés de page dérivent bien de pageKey (pas du libellé).
      expect(find.byKey(const ValueKey<String>('zTab_k1')), findsOneWidget);
    });

    testWidgets('collision de pageKey = assert au build', (tester) async {
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            tabs: <ZListTab>[
              _tab('tab.a', 'a', pageKey: 'dup'),
              _tab('tab.b', 'b', pageKey: 'dup'),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isAssertionError);
    });

    test('repli : sans pageKey, resolvedPageKey retombe sur labelKey', () {
      expect(_tab('tab.a', 'a').resolvedPageKey, 'tab.a');
      expect(_tab('tab.a', 'a', pageKey: 'k').resolvedPageKey, 'k');
    });
  });

  group('activeIndexNotifier (garde 3)', () {
    testWidgets('positionné à l\'index initial effectif dès le montage, '
        'SANS notifier onTabChanged', (tester) async {
      final notifier = ValueNotifier<int>(0);
      final changes = <int>[];
      addTearDown(notifier.dispose);
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            initialIndex: 1,
            activeIndexNotifier: notifier,
            onTabChanged: changes.add,
            tabs: <ZListTab>[_tab('tab.a', 'a'), _tab('tab.b', 'b')],
          ),
          labels: const {'tab.a': 'Alpha', 'tab.b': 'Bravo'},
        ),
      );
      await tester.pumpAndSettle();

      expect(notifier.value, 1, reason: 'index initial suivi dès le montage');
      expect(changes, isEmpty,
          reason: 'onTabChanged n\'est pas notifié à la construction');
    });

    testWidgets('suit le changement d\'onglet, mis à jour AVANT onTabChanged',
        (tester) async {
      final notifier = ValueNotifier<int>(0);
      addTearDown(notifier.dispose);
      int? seenInCallback;
      await tester.pumpWidget(
        _host(
          ZTabbedList(
            activeIndexNotifier: notifier,
            onTabChanged: (_) => seenInCallback = notifier.value,
            tabs: <ZListTab>[_tab('tab.a', 'a'), _tab('tab.b', 'b')],
          ),
          labels: const {'tab.a': 'Alpha', 'tab.b': 'Bravo'},
        ),
      );
      await tester.pumpAndSettle();
      expect(notifier.value, 0);

      await tester.tap(find.text('Bravo'));
      await tester.pumpAndSettle();

      expect(notifier.value, 1, reason: 'le notifieur suit l\'onglet actif');
      expect(seenInCallback, 1,
          reason: 'onTabChanged voit déjà le nouvel index dans le notifieur');
    });
  });

  group('canCreate (garde 4)', () {
    test('transporté intact par le constructeur ET la fabrique category', () {
      expect(_tab('tab.a', 'a').canCreate, isTrue, reason: 'défaut true');
      expect(
        ZListTab(
          labelKey: 'tab.a',
          canCreate: false,
          builder: (context) => const SizedBox.shrink(),
        ).canCreate,
        isFalse,
      );
      expect(
        ZListTab.category(
          labelKey: 'tab.a',
          filters: const <ZFilter>[],
          canCreate: false,
          buildList: (context, filters) => const SizedBox.shrink(),
        ).canCreate,
        isFalse,
        reason: 'la fabrique category ne perd pas canCreate:false',
      );
    });

    testWidgets('canCreate:false respecté au point de consommation de '
        'defaultItemBuilder (geste « + » de l\'hôte)', (tester) async {
      final notifier = ValueNotifier<int>(0);
      addTearDown(notifier.dispose);
      final created = <Object?>[];
      final tabs = <ZListTab>[
        ZListTab.category(
          labelKey: 'tab.open',
          filters: const <ZFilter>[],
          defaultItemBuilder: () => 'brouillon-open',
          buildList: (context, filters) => const Text('page-open'),
        ),
        ZListTab.category(
          labelKey: 'tab.locked',
          filters: const <ZFilter>[],
          canCreate: false,
          defaultItemBuilder: () => 'brouillon-locked',
          buildList: (context, filters) => const Text('page-locked'),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZcrudScope(
              labels: ZcrudLabels(const {
                'tab.open': 'Ouverts',
                'tab.locked': 'Verrouillés',
              }),
              child: ZTabbedList(activeIndexNotifier: notifier, tabs: tabs),
            ),
            // Geste de création de l'hôte : lit l'onglet ACTIF via le
            // notifieur et n'invoque defaultItemBuilder que si canCreate.
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                final tab = tabs[notifier.value];
                if (tab.canCreate) created.add(tab.defaultItemBuilder?.call());
              },
              child: const Icon(Icons.add),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Onglet autorisé : la création passe, avec le contexte de l'onglet.
      await tester.tap(find.byType(FloatingActionButton));
      expect(created, <Object?>['brouillon-open']);

      // Onglet canCreate:false : le geste ne crée RIEN.
      await tester.tap(find.text('Verrouillés'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FloatingActionButton));
      expect(created, <Object?>['brouillon-open'],
          reason: 'aucune création depuis un onglet canCreate:false');
    });
  });

  group('onglet sans vue déclarée (builder optionnel)', () {
    testWidgets(
        'un onglet ASSEMBLÉ monté nu rend une page VIDE, sans jamais lever',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const ZTabbedList(
            tabs: <ZListTab>[
              ZListTab(labelKey: 'sans-vue'),
              ZListTab(labelKey: 'avec-vue', builder: _pageAvecVue),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('page-avec-vue', skipOffstage: false),
        findsNothing,
        reason: 'seul l\'onglet ACTIF (le premier, sans vue) est monté',
      );

      // CONTRE-TÉMOIN : l'onglet qui DÉCLARE sa vue la rend, inchangé.
      await tester.tap(find.widgetWithText(Tab, 'avec-vue'));
      await tester.pumpAndSettle();
      expect(find.text('page-avec-vue'), findsOneWidget);
    });
  });
}

Widget _pageAvecVue(BuildContext context) => const Text('page-avec-vue');
