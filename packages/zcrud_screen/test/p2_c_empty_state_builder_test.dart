/// Gardes de l'**état vide injectable** de `ZCrudScreen`
/// ([ZCrudScreen.emptyStateBuilder]).
///
/// Ordre de construction (discipline du lot) : la garde d'INERTIE (a) a été
/// écrite et rendue verte **avant** toute modification de `lib/` — l'étalon
/// `test/support/p2_c_crud_screen_empty.txt` est donc le rendu du code
/// antérieur, nœud pour nœud. Les gardes de comportement (e) sont arrivées
/// ensuite, une par une, chacune avec son injection R3.
@TestOn('vm')
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';
import 'support/p2_c_tree.dart';

/// Clé du rendu injecté : sa présence ou son absence EST la mesure.
const Key _kEmptyKey = ValueKey<String>('p2cEmpty');

Widget _empty(BuildContext context) =>
    const Text('COLLECTION VIDE', key: _kEmptyKey);

/// Écran assemblé sur une source `items` VIDE : l'état vide est atteint sans
/// aucune asynchronie, donc l'arbre figé est déterministe.
Widget _emptyScreen({WidgetBuilder? emptyStateBuilder}) => ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.items(const <Item>[]),
      registry: buildItemRegistry(),
      emptyStateBuilder: emptyStateBuilder,
    );

/// Dépôt dont la première lecture ne se termine **jamais** tant que le test ne
/// l'a pas décidé : c'est le seul moyen d'observer l'état de CHARGEMENT.
class _PendingRepo extends FakeItemRepo {
  _PendingRepo() : super(const <Item>[]);

  final Completer<void> gate = Completer<void>();

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) async {
    await gate.future;
    return super.getAll(request: request);
  }
}

void main() {
  group('(a) INERTIE ABSOLUE — sans `emptyStateBuilder`, arbre identique', () {
    testWidgets('écran vide : arbre strictement égal à l\'étalon',
        (WidgetTester tester) async {
      await pumpScreen(tester, _emptyScreen());
      p2cExpectFrozenTree(
        'test/support/p2_c_crud_screen_empty.txt',
        p2cSerializeTree(tester, find.byType(ZCrudScreen<Item>)),
        what: 'ZCrudScreen sur source vide',
      );
    });
  });

  group('(e) ÉTAT VIDE — rendu quand la source est vide, et alors seulement',
      () {
    testWidgets('source vide ⇒ le rendu déclaré remplace le listing',
        (WidgetTester tester) async {
      await pumpScreen(tester, _emptyScreen(emptyStateBuilder: _empty));
      expect(find.byKey(_kEmptyKey), findsOneWidget);
      expect(find.byType(DynamicList<Item>), findsNothing);
    });

    testWidgets('CHARGEMENT ⇒ pas de rendu vide ; puis vide ⇒ rendu',
        (WidgetTester tester) async {
      final _PendingRepo repo = _PendingRepo();
      addTearDown(repo.dispose);
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: ZcrudScope(
            acl: const ZAllowAllAcl(),
            child: ZCrudScreen<Item>(
              title: 'Items',
              source: ZCrudSource<Item>.repository(repo),
              registry: buildItemRegistry(),
              emptyStateBuilder: _empty,
            ),
          ),
        ),
      );
      // La lecture est en vol : la collection n'est pas vide, elle est
      // INCONNUE. Annoncer « rien ici » serait un mensonge d'attente.
      await tester.pump();
      expect(find.byKey(_kEmptyKey), findsNothing);

      // Contre-témoin apparié : la MÊME déclaration, une fois la lecture
      // rendue et vide, rend bien le remplacement.
      repo.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(_kEmptyKey), findsOneWidget);
    });

    testWidgets('des LIGNES ⇒ pas de rendu vide', (WidgetTester tester) async {
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.items(
            const <Item>[Item(id: 'i1', name: 'Alpha')],
          ),
          registry: buildItemRegistry(),
          emptyStateBuilder: _empty,
        ),
      );
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byKey(_kEmptyKey), findsNothing);
    });

    testWidgets('AUCUN RÉSULTAT de recherche ⇒ pas de rendu vide',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.items(
            const <Item>[Item(id: 'i1', name: 'Alpha')],
          ),
          registry: buildItemRegistry(),
          emptyStateBuilder: _empty,
        ),
      );
      await searchInAppBar(tester, 'zzz');
      // La collection n'est pas vide : c'est le critère qui ne rend rien.
      expect(find.text('Alpha'), findsNothing);
      expect(find.byKey(_kEmptyKey), findsNothing);
    });

    testWidgets('ACL refusant `view` ⇒ ACCÈS REFUSÉ prime sur le rendu vide',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        _emptyScreen(emptyStateBuilder: _empty),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.view}),
      );
      // Fail-closed : l'ordre d'aujourd'hui est FIGÉ — le refus est décidé
      // avant toute lecture de la source, donc avant tout état vide.
      expect(find.byKey(const ValueKey<String>('zCrudAccessDenied')),
          findsOneWidget);
      expect(find.byKey(_kEmptyKey), findsNothing);
    });
  });
}
