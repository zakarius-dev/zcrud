// Gardes de la **fiche de détail comme geste de ligne** : consulter et
// administrer ne sont pas exclusifs.
//
// Ce que ces gardes mesurent, et pourquoi aucune ne remplace les autres :
//
// (a) écran COMPLET + `detailsEnabled` : la fiche s'ouvre, ET le bouton de
//     création, ET la corbeille restent présents — c'est le cœur du lot, et
//     c'est exactement ce que `ZScreenMode.details` retirait ;
// (b) la fiche ouverte depuis un écran complet est bien EN LECTURE SEULE ;
// (c) elle rend le FORMULAIRE, pas les colonnes (plus de champs que la liste
//     n'a de colonnes) ;
// (d) contre-témoin : `ZScreenMode.details` seul reste STRICTEMENT ce qu'il
//     était — ni création, ni corbeille. Sans lui, la garde (a) serait verte
//     même si le mode de consultation avait été dénaturé ;
// (e) `ZCrudAction.view` refusé ⇒ aucun geste de consultation, ni action de
//     ligne, ni ouverture programmatique ;
// (f) forme explicite : `zCrudDetailsOpener` rend le rappel sur un écran
//     complet déclaré consultable, et `null` sans la déclaration.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Liste à UNE colonne, formulaire à TROIS champs : l'écart est chiffrable.
const List<ZFieldSpec> _listOneColumn = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
];

const List<ZFieldSpec> _formThreeFields = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text),
  ZFieldSpec(name: 'qty', type: EditionFieldType.integer),
  ZFieldSpec(name: 'note', type: EditionFieldType.text, showIfNull: true),
];

/// Ouvre la fiche de la première ligne par l'action « détails ».
Future<void> _openDetails(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.visibility_outlined).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'garde (a) — écran COMPLET + detailsEnabled : la fiche s\'ouvre, et la '
      'création ET la corbeille restent offertes', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
      ),
    );

    // Le geste de consultation est là…
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    // …et RIEN n'a été retiré : c'est tout l'objet du lot.
    expect(find.byKey(const ValueKey('zCrudCreate')), findsOneWidget);
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

    // La fiche s'ouvre réellement.
    await _openDetails(tester);
    expect(find.byKey(const ValueKey('zCrudFormTitle')), findsOneWidget);

    // Et la corbeille reste opérante depuis cet écran : on y met la ligne, on
    // la retrouve dans la vue corbeille, on la restaure. Aucun de ces gestes
    // n'était atteignable en `ZScreenMode.details`.
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();
    await softDeleteFirstRow(tester);
    expect(repo.softDeleted, <String>['i1']);
    await openTrashView(tester);
    await tester.tap(find.byIcon(Icons.restore_from_trash).first);
    await tester.pumpAndSettle();
    expect(repo.restored, <String>['i1']);
    repo.dispose();
  });

  testWidgets(
      'garde (b) — la fiche ouverte depuis un écran complet est EN LECTURE '
      'SEULE, et l\'édition reste joignable par son action', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
      ),
    );
    await _openDetails(tester);
    // Aucun endroit où taper, aucun enregistrement : c'est une consultation.
    expect(find.byType(EditableText), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);
    expect(find.byKey(const ValueKey('zCrudFormClose')), findsOneWidget);

    // CONTRASTE — l'action « modifier » de la même ligne ouvre, elle, une
    // surface saisissable : sans ce couple, la garde ci-dessus serait verte
    // même si la fiche n'affichait jamais rien.
    await tester.tap(find.byKey(const ValueKey('zCrudFormClose')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(EditableText), findsWidgets);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsOneWidget);
    repo.dispose();
  });

  testWidgets(
      'garde (c) — la fiche d\'un écran complet rend le FORMULAIRE (3 champs), '
      'pas les colonnes de la liste (1 colonne)', (tester) async {
    final repo = FakeItemRepo(
      const <Item>[Item(id: 'i1', name: 'Alpha', qty: 7)],
    );
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        listFields: _listOneColumn,
        formFields: _formThreeFields,
        detailsEnabled: true,
      ),
    );
    // La LISTE ne connaît qu'une colonne : `qty` n'y est pas.
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('7'), findsNothing);

    await _openDetails(tester);
    final rendered = <String>[
      for (final spec in _formThreeFields)
        if (find.byKey(ValueKey<String>(spec.name)).evaluate().isNotEmpty)
          spec.name,
    ];
    expect(rendered, <String>['name', 'qty', 'note']);
    expect(rendered.length, greaterThan(_listOneColumn.length));
    expect(_listOneColumn.length, 1);
    repo.dispose();
  });

  testWidgets(
      'garde (d) — CONTRE-TÉMOIN : `ZScreenMode.details` seul reste ce qu\'il '
      'était — ni création, ni corbeille', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.details,
      ),
    );
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(find.byIcon(Icons.copy_outlined), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde (d bis) — le drapeau est IGNORÉ en `ZScreenMode.locked` : un '
      'écran verrouillé n\'ouvre pas de fiche', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        mode: ZScreenMode.locked,
        detailsEnabled: true,
      ),
    );
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde (e) — `view` refusé : aucun geste de consultation, et l\'ouverture '
      'programmatique reste inerte', (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    ZCrudOpener? seen;
    var probed = false;
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        // `view` gouverne l'écran entier : le refuser globalement rendrait
        // l'état « accès refusé ». Ici il n'est refusé que pour une CIBLE —
        // c'est le filtrage par ligne, celui que la fiche doit honorer.
        acl: const _DenyViewOnTargetAcl(),
        itemBuilder: (context, item, columns) {
          probed = true;
          seen = zCrudDetailsOpener(context, item);
          return Text(item.name, key: ValueKey<String>('tile_${item.id}'));
        },
      ),
    );
    expect(probed, isTrue, reason: 'la tuile doit avoir été rendue');
    expect(seen, isNull);
    // L'action de ligne « détails » est filtrée par la même permission.
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    repo.dispose();
  });

  testWidgets(
      'garde (f) — forme explicite : `zCrudDetailsOpener` rend le rappel sur '
      'un écran complet déclaré consultable, `null` sans la déclaration',
      (tester) async {
    Future<bool> openerOffered({required bool detailsEnabled}) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      var offered = false;
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          detailsEnabled: detailsEnabled,
          itemBuilder: (context, item, columns) {
            offered = zCrudDetailsOpener(context, item) != null;
            return Text(item.name, key: ValueKey<String>('tile_${item.id}'));
          },
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      repo.dispose();
      return offered;
    }

    expect(await openerOffered(detailsEnabled: true), isTrue);
    // Sans la déclaration, la consultation n'est pas offerte : le rappel est
    // `null`, et l'hôte ne dessine pas un geste mort.
    expect(await openerOffered(detailsEnabled: false), isFalse);
  });

  testWidgets(
      'garde (f bis) — le rappel OUVRE réellement la fiche, en lecture seule',
      (tester) async {
    final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        detailsEnabled: true,
        itemBuilder: (context, item, columns) => TextButton(
          key: ValueKey<String>('tile_${item.id}'),
          onPressed: zCrudDetailsOpener(context, item),
          child: Text(item.name),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('tile_i1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('zCrudFormClose')), findsOneWidget);
    expect(find.byKey(const ValueKey('zCrudFormSave')), findsNothing);
    repo.dispose();
  });
}

/// ACL autorisant tout, SAUF la consultation d'une ligne précise (cible
/// non nulle) : `view` reste accordé à l'écran (sinon l'écran entier serait
/// refusé), et refusé ligne par ligne.
class _DenyViewOnTargetAcl implements ZAcl {
  const _DenyViewOnTargetAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !(action == ZCrudAction.view && target != null);
}
