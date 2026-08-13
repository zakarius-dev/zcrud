// Gardes des GESTES d'écran (CR DODLP « choix dérivés et champs chemin »,
// point 4) : le geste « dupliquer » (action de ligne câblée d'office) ouvre
// la surface en CRÉATION avec une copie SANS identité — la sauvegarde
// matérialise une NOUVELLE entité, l'originale reste intacte — et le
// porte-titres `ZCrudTitles` distingue les TROIS modes (création /
// duplication / édition), la duplication n'étant PAS la création nue.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets(
      'dupliquer : formulaire PRÉ-REMPLI sans identité → save matérialise une '
      'NOUVELLE entité, l\'originale intacte', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha', qty: 3)]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
      ),
    );
    // Le geste est câblé d'office (aucun paramètre).
    await tester.tap(find.byIcon(Icons.copy_outlined).first);
    await tester.pumpAndSettle();

    // Formulaire dérivé pré-rempli de la copie.
    final prefilled = find.descendant(
      of: find.byType(DynamicEdition),
      matching: find.widgetWithText(TextField, 'Alpha'),
    );
    expect(prefilled, findsOneWidget);

    await tester.enterText(prefilled, 'Alpha (copie)');
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    // NOUVELLE entité : identité matérialisée par le save (≠ 'i1'), champs
    // repris de la copie ; l'originale n'a PAS été réécrite.
    expect(repo.saved, hasLength(1));
    expect(repo.saved.single.id, isNotNull);
    expect(repo.saved.single.id, isNot('i1'));
    expect(repo.saved.single.name, 'Alpha (copie)');
    expect(repo.saved.single.qty, 3);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Alpha (copie)'), findsOneWidget);
    repo.dispose();
  });

  testWidgets('permission create refusée → aucun geste dupliquer',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.create}),
      ),
    );
    // L'édition reste offerte (permission update intacte)…
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    // …mais dupliquer est absent : même permission que la création.
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
    repo.dispose();
  });

  testWidgets('canDuplicate: false → geste absent par déclaration',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        canDuplicate: false,
      ),
    );
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
    repo.dispose();
  });

  testWidgets('readOnly / source sans écriture → geste absent',
      (tester) async {
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: const ZCrudSource<Item>.items(<Item>[Item(id: 'i1', name: 'Alpha')]),
        registry: buildItemRegistry(),
      ),
    );
    // Source items SANS onSave : aucune voie d'écriture, donc ni édition ni
    // duplication.
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
  });

  testWidgets(
      'titres : les trois modes affichent leur titre déclaré, la duplication '
      'DISTINCTE de la création', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        titles: const ZCrudTitles(
          create: 'Nouvelle mutation',
          copy: 'Copie de la mutation',
          update: 'Modifier la mutation',
        ),
      ),
    );

    Future<void> openAndAssert(Finder trigger, String title) async {
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final titleFinder = find.byKey(const ValueKey('zCrudFormTitle'));
      expect(titleFinder, findsOneWidget);
      expect(
        (tester.widget<Text>(titleFinder)).data,
        title,
      );
      await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
      await tester.pumpAndSettle();
    }

    await openAndAssert(
      find.byKey(const ValueKey('zCrudCreate')),
      'Nouvelle mutation',
    );
    await openAndAssert(
      find.byIcon(Icons.copy_outlined).first,
      'Copie de la mutation',
    );
    await openAndAssert(
      find.byIcon(Icons.edit_outlined).first,
      'Modifier la mutation',
    );
    repo.dispose();
  });

  testWidgets(
      'titres sans déclaration : replis l10n génériques, « copy » ≠ « create »',
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

    Future<String> openedTitle(Finder trigger) async {
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      final title = tester
          .widget<Text>(find.byKey(const ValueKey('zCrudFormTitle')))
          .data!;
      await tester.tap(find.byKey(const ValueKey('zCrudFormCancel')));
      await tester.pumpAndSettle();
      return title;
    }

    final createTitle =
        await openedTitle(find.byKey(const ValueKey('zCrudCreate')));
    final copyTitle = await openedTitle(find.byIcon(Icons.copy_outlined).first);
    final updateTitle =
        await openedTitle(find.byIcon(Icons.edit_outlined).first);

    // Table `en` intégrée (aucun delegate monté) : clés génériques du cœur.
    expect(createTitle, 'Create');
    expect(copyTitle, 'Copy');
    expect(updateTitle, 'Edit');
    expect(copyTitle, isNot(createTitle));
    repo.dispose();
  });
}
