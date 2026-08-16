// Gardes de la LECTURE PUBLIQUE DU LISTING (CR DODLP « l'écran assemblé ne dit
// à personne ce qu'il liste ») : sur la voie dépôt, l'application ne détient
// plus la liste — l'écran la lit, la filtre, la cherche, la trie et la pagine.
// Sans point de lecture, un document métier construit par l'application doit
// relire la source en parallèle : deux lectures, deux instants, deux règles à
// tenir d'accord. `entitiesInView` supprime la seconde lecture.
//
// Ce que ces gardes tiennent, dans l'ordre :
//   (a) 🔴 LE critère — pour chaque vue et chaque filtre, le nombre d'entités
//       LUES est ÉGAL à celui des lignes RENDUES : jamais supérieur (on
//       imprimerait ce qui n'est pas listé), jamais inférieur (on en perdrait) ;
//   (b) une recherche tapée restreint la liste ET la lecture suivante, sans que
//       l'appelant rejoue quoi que ce soit ;
//   (c) l'ordre lu est l'ordre PEINT (tri appliqué) ;
//   (d) la PORTÉE compte : en vue corbeille, on lit les supprimés, pas les
//       vivants ;
//   (e) en mode onglets, on lit l'onglet ACTIF ;
//   (f) `entitiesSelectedOrInView` suit la règle de l'export intégré — la
//       sélection l'emporte quand elle porte, et ne réordonne pas ;
//   (g) 🔴 AD-2 — la lecture notifiée ne provoque AUCUNE reconstruction
//       supplémentaire du corps (compteur de constructions de tuiles), et
//       n'émet RIEN quand la liste ne change pas ;
//   (h) écran qui ne montre plus rien ⇒ lecture VIDE, jamais le rendu
//       précédent ;
//   (i) 🔴 CONTRE-TÉMOIN — un écran qui ne lit rien se comporte exactement
//       comme aujourd'hui : aucune construction de plus, aucune lecture armée.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

const List<Item> _seed = <Item>[
  Item(id: 'a', name: 'Alpha', qty: 1),
  Item(id: 'b', name: 'Bravo', qty: 2),
  Item(id: 'c', name: 'Charlie', qty: 3),
];

/// Réceptacle des gestes de l'écran, relevés par [_ActionsProbe].
class _Sink {
  ZCrudScreenActions? actions;

  /// Les gestes de l'écran — échoue explicitement s'ils n'ont jamais été posés
  /// (une garde qui lirait `null` mesurerait le montage, pas la lecture).
  ZCrudScreenActions get required =>
      actions ?? (throw StateError('aucun ZCrudScreenScope posé'));
}

/// Sonde montée DANS l'écran (via `header:`), donc descendante du scope des
/// gestes — exactement la position d'où une application déclenche son export.
class _ActionsProbe extends StatelessWidget {
  const _ActionsProbe(this.sink);

  final _Sink sink;

  @override
  Widget build(BuildContext context) {
    sink.actions = ZCrudScreenScope.maybeOf(context);
    return const SizedBox.shrink();
  }
}

Widget _screen(
  FakeItemRepo repo, {
  required _Sink sink,
  Key? key,
  ZListQueryPolicy query = const ZListQueryPolicy(),
  ZSelectionPolicy? selection,
  List<ZListTab>? tabs,
  ZCrudItemBuilder<Item>? itemBuilder,
}) =>
    ZCrudScreen<Item>(
      key: key,
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      query: query,
      selection: selection,
      tabs: tabs,
      itemBuilder: itemBuilder,
      header: _ActionsProbe(sink),
    );

/// Identités des lignes RÉELLEMENT peintes, dans l'ordre de peinture.
///
/// Relevées sur la clé que la tuile porte (`zCrudTile_<id>`) : c'est le rendu
/// qui est mesuré, pas l'état interne de l'écran.
List<String> _paintedIds(WidgetTester tester) => <String>[
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
        if (tile.key case final ValueKey<String> key)
          if (key.value.startsWith('zCrudTile_'))
            key.value.substring('zCrudTile_'.length),
    ];

/// Parent qui reconstruit son enfant **à neuf** à la demande — l'équivalent
/// d'une application dont un état voisin change et qui redessine son écran.
class _Rebuildable extends StatefulWidget {
  const _Rebuildable(this.builder);

  final Widget Function() builder;

  /// Force une reconstruction, puis laisse la trame se poser.
  static void rebuild(WidgetTester tester) =>
      tester.state<_RebuildableState>(find.byType(_Rebuildable)).bump();

  @override
  State<_Rebuildable> createState() => _RebuildableState();
}

class _RebuildableState extends State<_Rebuildable> {
  void bump() => setState(() {});

  // Un widget NEUF à chaque construction : c'est ce qui fait repasser l'écran
  // par sa mise à jour, donc par le relevé des lignes listées.
  @override
  Widget build(BuildContext context) => widget.builder();
}

/// Identités LUES par l'application, dans l'ordre rendu par la lecture.
List<String> _readIds(List<ZEntity> entities) =>
    <String>[for (final item in entities.whereType<Item>()) item.id!];

/// 🔴 L'assertion du CR, dans un seul test : les deux comptes, puis les deux
/// suites d'identités — un compte égal sur des identités différentes ne
/// vaudrait rien.
void _expectReadMatchesPainted(WidgetTester tester, List<ZEntity> read) {
  final painted = _paintedIds(tester);
  expect(
    read.length,
    painted.length,
    reason: 'entités lues (${read.length}) ≠ lignes rendues (${painted.length})',
  );
  expect(_readIds(read), painted);
}

void main() {
  group('(a) 🔴 autant d\'entités lues que de lignes rendues', () {
    testWidgets('listing nu — trois lignes rendues, trois entités lues',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      expect(_paintedIds(tester), <String>['a', 'b', 'c']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });

    testWidgets('filtre permanent — la lecture ne voit pas ce que l\'écran '
        'ne montre pas', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(
        tester,
        _screen(
          repo,
          sink: sink,
          query: const ZListQueryPolicy(
            baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
          ),
        ),
      );

      expect(_paintedIds(tester), <String>['b', 'c']);
      // La source en contient trois : lire trois ici, c'est exactement le
      // défaut que le CR décrit (un document qui déborde de sa liste).
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
      expect(sink.required.entitiesInView.length, 2);
    });

    testWidgets('post-filtre déclaré — même égalité', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(
        tester,
        _screen(
          repo,
          sink: sink,
          query: ZListQueryPolicy(
            itemFilter:
                ZItemFilter.of<Item>((item) => item.name.startsWith('C')),
          ),
        ),
      );

      expect(_paintedIds(tester), <String>['c']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });

    testWidgets('pagination — « ce qui est listé » = les PAGES CHARGÉES, '
        'ni plus ni moins', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(
        tester,
        _screen(repo, sink: sink, query: const ZListQueryPolicy(pageSize: 2)),
      );

      // Deux lignes rendues sur trois en source : la lecture s'arrête où le
      // rendu s'arrête.
      expect(_paintedIds(tester), <String>['a', 'b']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });

    testWidgets('filtre DEMANDÉ par l\'application (filterBy)',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      sink.required.filterBy(const <ZFilter>[ZFilter('qty', ZFilterOp.eq, 2)]);
      await tester.pumpAndSettle();

      expect(_paintedIds(tester), <String>['b']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });
  });

  group('(b) la recherche restreint la liste ET la lecture suivante', () {
    testWidgets('trois lettres tapées, rien à rejouer côté application',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      expect(sink.required.entitiesInView.length, 3);

      await searchInAppBar(tester, 'Bra');

      expect(_paintedIds(tester), <String>['b']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);

      // Et la recherche relâchée rend la liste entière — la lecture suit dans
      // les deux sens.
      await searchInAppBar(tester, '');
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
      expect(sink.required.entitiesInView.length, 3);
    });
  });

  group('(c) l\'ordre lu est l\'ordre PEINT', () {
    testWidgets('tri déclaré descendant', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(
        tester,
        _screen(
          repo,
          sink: sink,
          query: const ZListQueryPolicy(
            sort: <ZSort>[ZSort('name', ZSortDirection.desc)],
          ),
        ),
      );

      expect(_paintedIds(tester), <String>['c', 'b', 'a']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });

    testWidgets('tri DEMANDÉ par l\'application (sortBy) — la lecture bascule '
        'avec le rendu', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      expect(_readIds(sink.required.entitiesInView), <String>['a', 'b', 'c']);

      sink.required.sortBy(const <ZSort>[ZSort('name', ZSortDirection.desc)]);
      await tester.pumpAndSettle();

      expect(_paintedIds(tester), <String>['c', 'b', 'a']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });
  });

  group('(d) la PORTÉE compte — corbeille', () {
    testWidgets('en vue corbeille on lit les supprimés, pas les vivants',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      await softDeleteFirstRow(tester);
      await openTrashView(tester);

      expect(_paintedIds(tester), <String>['a']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
      // Le seul élément lu est le SUPPRIMÉ : lire les vivants ici imprimerait
      // la vue d'à côté.
      expect(_readIds(sink.required.entitiesInView), <String>['a']);
    });
  });

  group('(e) mode onglets — on lit l\'onglet ACTIF', () {
    List<ZListTab> tabs() => const <ZListTab>[
          ZListTab(
            labelKey: 'Un',
            baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 1)],
          ),
          ZListTab(
            labelKey: 'Deux',
            baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
          ),
        ];

    testWidgets('changer d\'onglet change ce qui est lu', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink, tabs: tabs()));

      expect(_paintedIds(tester), <String>['a']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);

      await tester.tap(find.widgetWithText(Tab, 'Deux'));
      await tester.pumpAndSettle();

      expect(_paintedIds(tester), <String>['b', 'c']);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });

    testWidgets('la lecture NOTIFIÉE suit l\'onglet actif, alors que la page '
        'quittée reste montée (keep-alive)', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink, tabs: tabs()));

      final listenable = sink.required.entitiesInViewListenable;
      expect(_readIds(listenable.value), <String>['a']);

      await tester.tap(find.widgetWithText(Tab, 'Deux'));
      await tester.pumpAndSettle();

      expect(_readIds(listenable.value), <String>['b', 'c']);
    });
  });

  group('(f) entitiesSelectedOrInView — la règle de l\'export intégré', () {
    Future<void> tick(WidgetTester tester, String id) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(ValueKey<String>('zListRow_$id')),
          matching: find.byType(Checkbox),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sélection vide ⇒ exactement ce qui est listé', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(
        tester,
        _screen(repo, sink: sink, selection: const ZSelectionPolicy()),
      );

      expect(
        _readIds(sink.required.entitiesSelectedOrInView),
        _readIds(sink.required.entitiesInView),
      );
    });

    testWidgets('sélection non vide ⇒ la sélection SEULE, sans réordonner',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(
        tester,
        _screen(repo, sink: sink, selection: const ZSelectionPolicy()),
      );

      // Cochées à l'envers de l'ordre peint : la sélection restreint, elle ne
      // réordonne pas.
      await tick(tester, 'c');
      await tick(tester, 'a');

      expect(
        _readIds(sink.required.entitiesSelectedOrInView),
        <String>['a', 'c'],
      );
      // La lecture non restreinte, elle, n'a pas bougé.
      expect(
        _readIds(sink.required.entitiesInView),
        <String>['a', 'b', 'c'],
      );
    });

    testWidgets('CONTRE-TÉMOIN — sans politique de sélection déclarée, c\'est '
        'la liste entière', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      expect(find.byType(Checkbox), findsNothing);
      expect(
        _readIds(sink.required.entitiesSelectedOrInView),
        <String>['a', 'b', 'c'],
      );
    });
  });

  group('(g) 🔴 AD-2 — la lecture notifiée ne reconstruit pas le corps', () {
    /// Écran dont chaque construction de tuile est COMPTÉE : c'est le compteur
    /// de reconstructions du corps, mesuré sur le rendu réel et non sur une
    /// intention.
    Widget counted(
      FakeItemRepo repo,
      _Sink sink,
      List<int> builds, {
      Key? key,
    }) =>
        _screen(
          repo,
          key: key,
          sink: sink,
          itemBuilder: (context, entity, columns) {
            builds[0]++;
            return ListTile(
              key: ValueKey<String>('zCrudTile_${entity.id}'),
              title: Text(entity.name),
            );
          },
        );

    testWidgets('abonner la lecture n\'ajoute AUCUNE construction, et n\'émet '
        'RIEN tant que la liste ne change pas', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      final builds = <int>[0];
      await pumpScreen(tester, counted(repo, sink, builds));

      final afterMount = builds[0];
      expect(afterMount, greaterThan(0));

      var emissions = 0;
      final listenable = sink.required.entitiesInViewListenable;
      void onChanged() => emissions++;
      listenable.addListener(onChanged);
      addTearDown(() => listenable.removeListener(onChanged));

      // La valeur est disponible IMMÉDIATEMENT : un abonné tardif lit ce qui
      // est à l'écran, il n'attend pas une notification.
      expect(_readIds(listenable.value), <String>['a', 'b', 'c']);

      // Plusieurs trames sans rien changer : ni construction, ni émission.
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(builds[0], afterMount, reason: 'corps reconstruit sans raison');
      expect(emissions, 0, reason: 'émission sans changement de liste');
    });

    testWidgets('un RENDU de l\'écran qui ne change pas la liste n\'émet rien '
        '— le critère est le contenu, pas l\'identité de la liste',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      final builds = <int>[0];
      // Un parent qui reconstruit l'écran : le cas courant d'une application
      // dont un état voisin change. Le listing, lui, est le même.
      await pumpScreen(tester, _Rebuildable(() => counted(repo, sink, builds)));

      var emissions = 0;
      final listenable = sink.required.entitiesInViewListenable;
      void onChanged() => emissions++;
      listenable.addListener(onChanged);
      addTearDown(() => listenable.removeListener(onChanged));

      _Rebuildable.rebuild(tester);
      _Rebuildable.rebuild(tester);
      await tester.pumpAndSettle();

      // Le corps A ÉTÉ reconstruit (le relevé des lignes est donc repassé)…
      expect(builds[0], greaterThan(0));
      // …et pourtant rien n'a été émis : la liste est la même.
      expect(emissions, 0, reason: 'émission sur une liste inchangée');
      expect(_readIds(listenable.value), <String>['a', 'b', 'c']);
    });

    testWidgets('une liste qui change RÉELLEMENT émet, et la valeur émise est '
        'celle qui est peinte', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      final builds = <int>[0];
      await pumpScreen(tester, counted(repo, sink, builds));

      final listenable = sink.required.entitiesInViewListenable;
      final emitted = <List<String>>[];
      void onChanged() => emitted.add(_readIds(listenable.value));
      listenable.addListener(onChanged);
      addTearDown(() => listenable.removeListener(onChanged));

      await searchInAppBar(tester, 'Bra');

      expect(emitted, isNotEmpty, reason: 'un changement réel doit être émis');
      expect(emitted.last, <String>['b']);
      expect(_readIds(listenable.value), _paintedIds(tester));

      // Les trames qui suivent ne réémettent pas : le critère est le contenu,
      // pas l'identité de la liste reconstruite à chaque rendu.
      final settled = emitted.length;
      await tester.pump();
      await tester.pumpAndSettle();
      expect(emitted.length, settled);
    });

    testWidgets('🔴 CONTRE-TÉMOIN (i) — l\'écran qui ne lit rien construit '
        'EXACTEMENT autant que celui qui lit, au repos comme sur un '
        'changement réel', (tester) async {
      // Deux écrans identiques, même scénario, même nombre de trames : le SEUL
      // écart est l'abonnement. Le compteur de constructions de tuiles doit
      // rendre le même nombre — une lecture notifiée qui redessinerait le corps
      // se verrait ici, et nulle part ailleurs.
      Future<int> constructions({required bool abonne}) async {
        final repo = FakeItemRepo(_seed);
        addTearDown(repo.dispose);
        final builds = <int>[0];
        final sink = _Sink();
        // Clé DISTINCTE par exécution : sans elle, la seconde monte sur
        // l'état de la première (même type au même endroit de l'arbre) et les
        // deux comptes ne seraient plus comparables.
        await pumpScreen(
          tester,
          counted(repo, sink, builds, key: ValueKey<bool>(abonne)),
        );
        if (abonne) {
          final listenable = sink.required.entitiesInViewListenable;
          void onChanged() {}
          listenable.addListener(onChanged);
          addTearDown(() => listenable.removeListener(onChanged));
        }
        // Au repos.
        await tester.pump();
        await tester.pumpAndSettle();
        // Puis sur un changement RÉEL de la liste — le moment où la lecture
        // notifiée émet, donc le seul où elle pourrait entraîner le corps.
        await searchInAppBar(tester, 'Bra');
        await tester.pumpAndSettle();
        return builds[0];
      }

      final sansAbonnement = await constructions(abonne: false);
      final avecAbonnement = await constructions(abonne: true);

      expect(sansAbonnement, greaterThan(0));
      expect(avecAbonnement, sansAbonnement);
    });
  });

  group('(h) écran qui ne montre plus rien ⇒ lecture VIDE', () {
    testWidgets('source vide — rien à l\'écran, rien à lire', (tester) async {
      final repo = FakeItemRepo(const <Item>[]);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      expect(_paintedIds(tester), isEmpty);
      expect(sink.required.entitiesInView, isEmpty);
      expect(sink.required.entitiesSelectedOrInView, isEmpty);
    });

    testWidgets('recherche sans résultat APRÈS un rendu peuplé — la lecture ne '
        'reste jamais sur le rendu précédent', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final sink = _Sink();
      await pumpScreen(tester, _screen(repo, sink: sink));

      expect(sink.required.entitiesInView.length, 3);

      await searchInAppBar(tester, 'zzz');

      expect(_paintedIds(tester), isEmpty);
      expect(sink.required.entitiesInView, isEmpty);
      _expectReadMatchesPainted(tester, sink.required.entitiesInView);
    });
  });

  group('(i) 🔴 CONTRE-TÉMOIN — hors écran, il n\'y a rien à lire', () {
    testWidgets('un widget monté seul n\'atteint aucun listing',
        (tester) async {
      ZCrudScreenActions? actions;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              actions = ZCrudScreenScope.maybeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(actions, isNull);
    });
  });
}
