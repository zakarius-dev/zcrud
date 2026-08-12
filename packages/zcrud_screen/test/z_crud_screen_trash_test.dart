// Garde de la CORBEILLE voie repository : la bascule vivants/corbeille passe
// par `ZDataRequest.deletedScope` (le décorateur force `deletedOnly` — c'est
// le CHEMIN BACKEND du CR, pas une partition client), `softDelete` retire des
// vivants, `restore` REND l'élément aux vivants.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
      'cycle corbeille repository : softDelete → bascule deletedOnly → '
      'restore → retour aux vivants', (tester) async {
    final repo = FakeItemRepo(const <Item>[
      Item(id: 'i1', name: 'Alpha', qty: 3),
      Item(id: 'i2', name: 'Beta', qty: 7),
    ]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);

    // Soft-delete d'Alpha (première ligne) : quitte les vivants.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);
    expect(find.text('Beta'), findsOneWidget);

    // Bascule corbeille : le listing vient du repository en portée
    // `deletedOnly` (le fake n'y répond QUE par les soft-deleted).
    await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    // En corbeille : ni édition, ni création.
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);

    // Restore : Alpha quitte la corbeille…
    await tester.tap(find.byIcon(Icons.restore_from_trash).first);
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsNothing);

    // …et est RENDU aux vivants.
    await tester.tap(find.byKey(const ValueKey('zCrudTrashBack')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('la recherche de la vue corbeille interroge la portée deletedOnly',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[
      Item(id: 'i1', name: 'Alpha', qty: 3),
      Item(id: 'i2', name: 'Beta', qty: 7),
    ]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    // Met les DEUX éléments à la corbeille.
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
    await tester.pumpAndSettle();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // Recherche dans la corbeille : filtre in-scope (schema `searchable`).
    await tester.enterText(find.byKey(const ValueKey('zCrudSearch')), 'bet');
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    repo.dispose();
  });
}
