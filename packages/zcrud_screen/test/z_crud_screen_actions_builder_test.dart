// Gardes des ACTIONS D'APP-BAR DÉPENDANTES DE L'ÉTAT (CR DODLP « les actions
// d'app-bar ne peuvent pas dépendre de l'état de la liste », 2026-08-17).
//
// Le CR est explicite : `actions` (liste figée de `ZAppBarAction`) est le BON
// défaut — c'est lui qui garantit qu'un geste porte son libellé accessible, là
// où le chemin déprécié `appBarActions` transmet des widgets muets pour un
// lecteur d'écran. Ce qui manquait n'est pas un remplaçant, c'est un
// COMPLÉMENT : un builder qui rend des `ZAppBarAction`, réévalué quand l'état
// change.
//
// Ce que ces gardes tiennent, dans l'ordre :
//   (a) le builder rend des ACTIONS EN DONNÉES — chaque geste porte son
//       `semanticLabel`, mesuré sur la sémantique RENDUE, pas sur l'intention ;
//   (b) il est RÉÉVALUÉ quand le comptage de la vue change ;
//   (c) il est RÉÉVALUÉ quand l'onglet actif change, et l'ACL reçue est celle
//       de l'onglet (cascade `onglet ∩ écran ∩ scope`) ;
//   (d) il est RÉÉVALUÉ quand la vue bascule en corbeille ;
//   (e) 🔴 AD-2 — un rendu de coquille SEUL réévalue le builder sans
//       reconstruire AUCUNE tuile (comptes absolus), et un écran qui déclare un
//       builder ne construit pas une tuile de plus qu'un écran qui n'en déclare
//       pas (comptes différentiels sur un changement RÉEL de comptage) ;
//   (f) 🔴 CONTRE-TÉMOIN — un écran sans builder ne paie RIEN : pas un
//       abonnement de plus dans l'arbre (comptes absolus de widgets) ;
//   (g) l'exclusivité `actions` / `actionsBuilder` est GARDÉE (assertion) ;
//   (h) AD-10 — un builder qui lève ne peut pas emporter l'app-bar.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZAppBarAction;

import 'support/fixtures.dart';

const List<Item> _seed = <Item>[
  Item(id: 'a', name: 'Alpha', qty: 1),
  Item(id: 'b', name: 'Bravo', qty: 2),
  Item(id: 'c', name: 'Charlie', qty: 3),
];

/// Journal des contextes reçus par le builder, dans l'ordre — c'est LA mesure
/// de la réévaluation (le nombre d'appels) et de son exactitude (la valeur).
class _Journal {
  final List<ZAppBarActionsContext> vus = <ZAppBarActionsContext>[];

  int get appels => vus.length;

  ZAppBarActionsContext get dernier => vus.isEmpty
      ? (throw StateError('le builder n\'a jamais été appelé'))
      : vus.last;
}

/// L'icône d'une action conditionnelle : présente si et seulement si la vue
/// n'est pas vide.
const IconData _iconeFiltres = Icons.filter_alt_off_outlined;

Widget _screen(
  FakeItemRepo repo, {
  Key? key,
  _Journal? journal,
  List<ZListTab>? tabs,
  ZCrudItemBuilder<Item>? itemBuilder,
  ValueListenable<int>? trashCount,
  ZAppBarActionsBuilder? actionsBuilder,
  List<ZAppBarAction> actions = const <ZAppBarAction>[],
}) =>
    ZCrudScreen<Item>(
      key: key,
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      tabs: tabs,
      itemBuilder: itemBuilder,
      trashCount: trashCount,
      actions: actions,
      actionsBuilder: actionsBuilder ??
          (journal == null
              ? null
              : (state) {
                  journal.vus.add(state);
                  return <ZAppBarAction>[
                    if (!state.isEmpty)
                      ZAppBarAction(
                        icon: _iconeFiltres,
                        semanticLabel: 'Filtres',
                        tooltip: 'Filtres',
                        onPressed: () {},
                      ),
                  ];
                }),
    );

void main() {
  group('(a) le builder rend des ACTIONS EN DONNÉES, pas des widgets', () {
    testWidgets(
        'l\'action produite est rendue ET porte son libellé accessible',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal));

      expect(find.byIcon(_iconeFiltres), findsOneWidget);
      // La sémantique est celle du socle (`Semantics(label:)` autour du
      // glyphe) : c'est exactement ce que le chemin déprécié ne pouvait pas
      // offrir. On l'affirme sur l'arbre de sémantique RENDU.
      expect(
        find.bySemanticsLabel('Filtres'),
        findsOneWidget,
        reason: 'l\'action du builder a perdu son libellé accessible',
      );
    });

    testWidgets('rien à rendre ⇒ app-bar strictement inchangée',
        (tester) async {
      final repo = FakeItemRepo(const <Item>[]);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal));

      // Liste vide ⇒ le builder n'émet rien : l'action conditionnelle n'existe
      // pas, elle n'est pas juste désactivée.
      expect(journal.dernier.isEmpty, isTrue);
      expect(find.byIcon(_iconeFiltres), findsNothing);
    });
  });

  group('(b) RÉÉVALUÉ quand le comptage de la vue change', () {
    testWidgets('une recherche qui vide la liste retire l\'action, et la '
        'relâcher la rend', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal));

      expect(journal.dernier.itemCount, 3);
      expect(find.byIcon(_iconeFiltres), findsOneWidget);

      await searchInAppBar(tester, 'zzz');

      expect(
        journal.dernier.itemCount,
        0,
        reason: 'le builder n\'a pas revu le comptage de la vue',
      );
      expect(journal.dernier.isEmpty, isTrue);
      expect(find.byIcon(_iconeFiltres), findsNothing);

      await searchInAppBar(tester, '');

      expect(journal.dernier.itemCount, 3);
      expect(find.byIcon(_iconeFiltres), findsOneWidget);
    });

    testWidgets('le comptage est celui de la VUE, pas celui de la source',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal));

      await searchInAppBar(tester, 'Bra');

      // La source en porte trois ; la vue en montre une.
      expect(journal.dernier.itemCount, 1);
    });
  });

  group('(c) RÉÉVALUÉ quand l\'onglet actif change', () {
    List<ZListTab> tabs() => const <ZListTab>[
          ZListTab(
            labelKey: 'Un',
            baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.eq, 1)],
          ),
          ZListTab(
            labelKey: 'Deux',
            baseFilters: <ZFilter>[ZFilter('qty', ZFilterOp.gt, 1)],
            acl: DenyAcl(<ZCrudAction>{ZCrudAction.create}),
          ),
        ];

    testWidgets('l\'index ET le comptage suivent l\'onglet', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal, tabs: tabs()));

      expect(journal.dernier.tabIndex, 0);
      expect(journal.dernier.itemCount, 1);

      await tester.tap(find.widgetWithText(Tab, 'Deux'));
      await tester.pumpAndSettle();

      expect(journal.dernier.tabIndex, 1);
      expect(
        journal.dernier.itemCount,
        2,
        reason: 'le comptage est resté sur l\'onglet quitté',
      );
    });

    testWidgets('l\'ACL reçue est celle de l\'ONGLET, pas celle de l\'écran nu',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal, tabs: tabs()));

      // Onglet 0 : rien ne restreint — la création est permise par le scope.
      expect(journal.dernier.acl.can(ZCrudAction.create), isTrue);

      await tester.tap(find.widgetWithText(Tab, 'Deux'));
      await tester.pumpAndSettle();

      // Onglet 1 : sa restriction RETIRE la création. Une ACL d'écran nue
      // rendrait `true` ici — c'est la cascade qu'on garde.
      expect(
        journal.dernier.acl.can(ZCrudAction.create),
        isFalse,
        reason: 'la restriction de l\'onglet actif n\'est pas composée',
      );
    });
  });

  group('(d) RÉÉVALUÉ quand la vue bascule en corbeille', () {
    testWidgets('isTrashView suit la bascule, dans les deux sens',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      await pumpScreen(tester, _screen(repo, journal: journal));

      expect(journal.dernier.isTrashView, isFalse);

      await softDeleteFirstRow(tester);
      await openTrashView(tester);

      expect(
        journal.dernier.isTrashView,
        isTrue,
        reason: 'le builder n\'a pas revu la portée',
      );
      // Et le comptage est celui de la CORBEILLE (un supprimé), pas des vivants.
      expect(journal.dernier.itemCount, 1);

      await tester.tap(find.byKey(const ValueKey('zCrudTrashBack')));
      await tester.pumpAndSettle();

      expect(journal.dernier.isTrashView, isFalse);
    });
  });

  group('(e) 🔴 AD-2 — la réévaluation ne reconstruit pas le corps', () {
    /// Écran dont chaque construction de tuile est COMPTÉE : le compteur de
    /// reconstructions du corps, mesuré sur le rendu réel.
    Widget compte(
      FakeItemRepo repo,
      List<int> tuiles, {
      Key? key,
      _Journal? journal,
      ValueListenable<int>? trashCount,
    }) =>
        _screen(
          repo,
          key: key,
          journal: journal,
          trashCount: trashCount,
          itemBuilder: (context, entity, columns) {
            tuiles[0]++;
            return ListTile(
              key: ValueKey<String>('zCrudTile_${entity.id}'),
              title: Text(entity.name),
            );
          },
        );

    testWidgets('🔴 un rendu de COQUILLE SEULE réévalue le builder et ne '
        'construit AUCUNE tuile (comptes absolus)', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final journal = _Journal();
      final tuiles = <int>[0];
      // Le compte de corbeille DÉCLARÉ est le seul déclencheur qui ne touche
      // que la coquille : le bumper redessine la barre, jamais la liste. C'est
      // donc la mesure la plus nette de la granularité.
      final compteur = ValueNotifier<int>(0);
      addTearDown(compteur.dispose);
      await pumpScreen(
        tester,
        compte(repo, tuiles, journal: journal, trashCount: compteur),
      );

      final tuilesApresMontage = tuiles[0];
      final appelsApresMontage = journal.appels;
      expect(tuilesApresMontage, greaterThan(0));
      expect(appelsApresMontage, greaterThan(0));

      compteur.value = 7;
      await tester.pumpAndSettle();

      expect(
        journal.appels,
        greaterThan(appelsApresMontage),
        reason: 'le builder n\'a pas été réévalué au rendu de la coquille',
      );
      expect(
        tuiles[0],
        tuilesApresMontage,
        reason: 'le corps a été reconstruit par un rendu de coquille',
      );
    });

    testWidgets('🔴 sur un changement RÉEL de comptage, l\'écran QUI DÉCLARE '
        'un builder construit EXACTEMENT autant de tuiles que celui qui n\'en '
        'déclare pas', (tester) async {
      // Deux écrans identiques, même scénario, même nombre de trames : le SEUL
      // écart est la déclaration du builder. Un abonnement au comptage posé
      // au-dessus du corps (au lieu d'au-dessus de la seule coquille) se
      // verrait ici, et nulle part ailleurs.
      Future<int> tuilesConstruites({required bool avecBuilder}) async {
        final repo = FakeItemRepo(_seed);
        addTearDown(repo.dispose);
        final tuiles = <int>[0];
        // Clé DISTINCTE par exécution : sans elle, la seconde monte sur l'état
        // de la première (même type au même endroit de l'arbre).
        await pumpScreen(
          tester,
          compte(
            repo,
            tuiles,
            key: ValueKey<bool>(avecBuilder),
            journal: avecBuilder ? _Journal() : null,
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();
        // Le moment où le comptage change RÉELLEMENT — le seul où un
        // abonnement mal placé pourrait entraîner le corps.
        await searchInAppBar(tester, 'Bra');
        await tester.pumpAndSettle();
        await searchInAppBar(tester, '');
        await tester.pumpAndSettle();
        return tuiles[0];
      }

      final sansBuilder = await tuilesConstruites(avecBuilder: false);
      final avecBuilder = await tuilesConstruites(avecBuilder: true);

      expect(sansBuilder, greaterThan(0));
      expect(avecBuilder, sansBuilder);
    });
  });

  group('(f) 🔴 CONTRE-TÉMOIN — un écran sans builder ne paie rien', () {
    /// Nombre d'abonnements posés par l'écran : chaque `ValueListenableBuilder`
    /// monté est un abonnement, et le comptage n'en ajoute un que si un builder
    /// est déclaré.
    int abonnements(WidgetTester tester) =>
        tester.widgetList(find.byType(ValueListenableBuilder<List<ZEntity>>))
            .length;

    testWidgets('aucun abonnement au comptage n\'est posé (compte absolu)',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo));

      expect(
        abonnements(tester),
        0,
        reason: 'un écran sans builder s\'est abonné au comptage',
      );
    });

    testWidgets('déclarer un builder en pose EXACTEMENT un (compte absolu)',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo, journal: _Journal()));

      expect(abonnements(tester), 1);
    });
  });

  group('(g) l\'exclusivité `actions` / `actionsBuilder` est GARDÉE', () {
    testWidgets('déclarer les deux lève une assertion actionnable',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          actions: <ZAppBarAction>[
            const ZAppBarAction(icon: Icons.abc, semanticLabel: 'Figée'),
          ],
          journal: _Journal(),
        ),
      );

      final erreur = tester.takeException();
      expect(erreur, isAssertionError);
      expect(
        erreur.toString(),
        contains('EXCLUSIFS'),
        reason: 'le message d\'assertion ne nomme pas le contrat violé',
      );
    });

    testWidgets('CONTRE-TÉMOIN — `actions` seule reste offerte, inchangée',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          actions: <ZAppBarAction>[
            ZAppBarAction(
              icon: _iconeFiltres,
              semanticLabel: 'Figée',
              onPressed: () {},
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(_iconeFiltres), findsOneWidget);
    });
  });

  group('(h) AD-10 — un builder qui lève n\'emporte pas l\'app-bar', () {
    testWidgets('l\'écran reste debout, les actions assemblées restent là',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          actionsBuilder: (_) => throw StateError('builder fautif'),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(AppBar), findsOneWidget);
      // Les gestes assemblés de l'écran survivent au builder fautif.
      expect(find.byKey(const ValueKey('zCrudCreate')), findsOneWidget);
    });
  });
}
