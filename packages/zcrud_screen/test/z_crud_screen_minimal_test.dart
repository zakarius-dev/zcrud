// Garde du CONTRAT CENTRAL du CR « écran CRUD assemblé » : la déclaration
// MINIMALE `ZCrudScreen<T>(title, source, registry)` rend, sans AUCUN code
// hôte : la liste (colonnes + cellules DÉRIVÉES du registre), le bouton de
// création, l'édition pré-remplie au tap d'action de ligne, et la sauvegarde
// via `repository.save` — le tout par les briques existantes (`DynamicList`,
// `presentEdition`, `DynamicEdition`, `ZFormController`).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
      'déclaration minimale : liste dérivée du registre (colonnes + cellules '
      'sans listFields/cellsOf)', (tester) async {
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
    // Cellules dérivées de `registry.encode` : les valeurs métier sont là.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);
    // La colonne `isId` n'est PAS dérivée en colonne (dérivation du cœur).
    expect(find.textContaining('i1'), findsNothing);
    repo.dispose();
  });

  testWidgets('création : bouton « + » → formulaire dérivé → repository.save',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
    await tester.pumpAndSettle();
    // Le formulaire dérivé est monté (DynamicEdition, pas un builder hôte).
    expect(find.byType(DynamicEdition), findsOneWidget);

    // Saisit le nom dans le champ `name` du formulaire.
    final nameField = find.descendant(
      of: find.byType(DynamicEdition),
      matching: find.byType(TextField),
    );
    await tester.enterText(nameField.first, 'Gamma');
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    // Sauvegarde passée par `repository.save`, entité MATÉRIALISÉE, surface
    // fermée, liste rafraîchie.
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.name, 'Gamma');
    expect(repo.saved.single.id, isNotNull);
    expect(find.byType(DynamicEdition), findsNothing);
    expect(find.text('Gamma'), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'édition : action de ligne → formulaire PRÉ-REMPLI → save conserve '
      'l\'identité', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    // Pré-rempli depuis `registry.encode(initial)`.
    final prefilled = find.descendant(
      of: find.byType(DynamicEdition),
      matching: find.widgetWithText(TextField, 'Alpha'),
    );
    expect(prefilled, findsOneWidget);

    await tester.enterText(prefilled, 'Alpha 2');
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.id, 'i1'); // identité conservée (décodage fusionné)
    expect(repo.saved.single.name, 'Alpha 2');
    repo.dispose();
  });

  testWidgets(
      'échec de persistance : la ZFailure est AFFICHÉE dans la surface, '
      'jamais levée, et la surface reste ouverte', (tester) async {
    final repo = FakeItemRepo(const <Item>[]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        onSave: (_) async => throw StateError('refus hôte'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('zCrudFormError')), findsOneWidget);
    expect(find.byType(DynamicEdition), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'sans registre NI schéma : ZScopeError ACTIONNABLE (jamais un défaut '
      'silencieux)', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await tester.pumpWidget(
      MaterialApp(
        // ACL permissive DÉCLARÉE : sans elle, l'écran rendrait l'état « accès
        // refusé » AVANT d'atteindre la dérivation de schéma — et cette garde
        // mesure l'erreur de configuration, pas l'autorisation.
        home: ZcrudScope(
          acl: const ZAllowAllAcl(),
          child: ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
          ),
        ),
      ),
    );
    final exception = tester.takeException();
    expect(exception, isA<ZScopeError>());
    expect('$exception', contains('listFields'));
    repo.dispose();
  });
}
