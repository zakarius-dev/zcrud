// Gardes du TROISIÈME geste de corbeille (suppression définitive) et de la
// SÉPARATION des canaux d'actions de ligne.
//
// Ce que ces gardes verrouillent :
//  * `rowActions` (vue vivante) et `trashRowActions` (corbeille) sont
//    DISJOINTES — une action déclarée pour l'une n'apparaît jamais dans
//    l'autre ;
//  * la purge n'est offerte que si la source sait la servir (mixin
//    `ZPurgeable`, ou rappel `onPurge`) ET que `ZCrudAction.clear` est accordé ;
//  * annuler la confirmation irréversible n'écrit RIEN (assertion d'absence
//    d'appel au dépôt, pas seulement d'absence visuelle) ;
//  * les gestes existants (mise à la corbeille, restauration) sont inchangés.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZConfirmDialog;

import 'support/fixtures.dart';

/// Action de ligne applicative, reconnaissable à son icône.
ZRowAction<Item> _marker(String id, IconData icon) => ZRowAction<Item>(
      id: id,
      labelKey: id,
      icon: icon,
      onInvoke: (context, entity) {},
    );

void main() {
  group('séparation des canaux d\'actions de ligne', () {
    testWidgets(
        'une action déclarée en `rowActions` n\'apparaît PAS en corbeille',
        (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          rowActions: <ZRowAction<Item>>[_marker('vivant', Icons.star)],
        ),
      );
      // Vue vivante : l'action de l'app est bien là.
      expect(find.byIcon(Icons.star), findsOneWidget);

      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      expect(find.text('Alpha'), findsOneWidget);
      // Vue corbeille : l'action de la vue VIVANTE ne doit pas avoir suivi.
      expect(
        find.byIcon(Icons.star),
        findsNothing,
        reason: 'une action de la vue vivante a fui dans la corbeille',
      );
      repo.dispose();
    });

    testWidgets(
        'une action déclarée en `trashRowActions` n\'apparaît PAS sur les '
        'éléments vivants', (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          trashRowActions: <ZRowAction<Item>>[_marker('corbeille', Icons.flag)],
        ),
      );
      expect(
        find.byIcon(Icons.flag),
        findsNothing,
        reason: 'une action de corbeille a fui dans la vue vivante',
      );

      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      expect(find.byIcon(Icons.flag), findsOneWidget);
      repo.dispose();
    });
  });

  group('suppression définitive', () {
    testWidgets(
        'dépôt appliquant `ZPurgeable` + `clear` accordé ⇒ geste offert, '
        'confirmé, et l\'élément disparaît de la corbeille', (tester) async {
      final repo =
          FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      );
      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      expect(find.byIcon(Icons.delete_forever), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_forever).first);
      await tester.pumpAndSettle();
      // La confirmation de purge porte SON texte, distinct de la mise à la
      // corbeille : elle annonce l'irréversibilité.
      expect(find.byType(ZConfirmDialog), findsOneWidget);
      // Ton distinct de la mise à la corbeille : le texte annonce que le
      // geste ne se défait pas (libellés `deleteForever` /
      // `confirmDeleteForeverItem`, ici dans leur repli intégré).
      expect(
        find.textContaining('permanently'),
        findsWidgets,
        reason: 'la confirmation de purge doit annoncer l\'irréversibilité',
      );
      await confirmDestructiveDialog(tester);

      expect(repo.purged, <String>['i1']);
      expect(find.text('Alpha'), findsNothing);
      repo.dispose();
    });

    testWidgets('`clear` refusé ⇒ aucun geste de purge, malgré le mixin',
        (tester) async {
      final repo =
          FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.clear}),
      );
      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(repo.purged, isEmpty);
      repo.dispose();
    });

    testWidgets(
        'dépôt SANS le mixin ⇒ aucun geste de purge, et rien ne casse',
        (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      expect(repo, isNot(isA<ZPurgeable<Item>>()));
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      );
      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      // La corbeille fonctionne : l'élément est là, restaurable…
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);
      // …simplement, elle n'offre pas ce que la source ne sait pas faire.
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(tester.takeException(), isNull);
      repo.dispose();
    });

    testWidgets(
        'annuler la confirmation ⇒ AUCUNE écriture (le dépôt n\'est pas '
        'appelé)', (tester) async {
      final repo =
          FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      );
      await softDeleteFirstRow(tester);
      await openTrashView(tester);

      await tester.tap(find.byIcon(Icons.delete_forever).first);
      await tester.pumpAndSettle();
      await cancelDestructiveDialog(tester);

      expect(
        repo.purged,
        isEmpty,
        reason: 'annuler la confirmation ne doit appeler AUCUNE écriture',
      );
      expect(find.text('Alpha'), findsOneWidget);
      repo.dispose();
    });

    testWidgets('`ZTrashPolicy.withoutPurge` retire le geste, mixin ou non',
        (tester) async {
      final repo =
          FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          trashPolicy: ZTrashPolicy.withoutPurge,
        ),
      );
      await softDeleteFirstRow(tester);
      await openTrashView(tester);
      expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      repo.dispose();
    });
  });

  group('voie `items` : rappels de corbeille', () {
    testWidgets(
        '`onPurge` déclaré ⇒ geste offert, confirmé, rappel appelé avec un '
        '`BuildContext` RÉEL de l\'arbre', (tester) async {
      final deleted = <String>{'i1'};
      final purged = <String>[];
      var scopeSeen = false;
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.items(
            const <Item>[Item(id: 'i1', name: 'Alpha')],
            onSave: (item) async {},
            onSoftDelete: (context, item) => deleted.add(item.id!),
            onPurge: (context, item) {
              // Le `BuildContext` transmis est celui de la ligne : il permet à
              // l'application de remonter l'arbre (confirmation maison,
              // navigation, notification) sans capturer un contexte externe.
              scopeSeen = ZcrudScope.maybeOf(context) != null;
              purged.add(item.id!);
            },
            isDeleted: (item) => deleted.contains(item.id),
          ),
          registry: buildItemRegistry(),
        ),
      );
      await openTrashView(tester);
      expect(find.text('Alpha'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_forever).first);
      await tester.pumpAndSettle();
      await confirmDestructiveDialog(tester);

      expect(purged, <String>['i1']);
      expect(scopeSeen, isTrue);
    });

    testWidgets('sans `onPurge`, la corbeille `items` n\'offre pas la purge',
        (tester) async {
      final deleted = <String>{'i1'};
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.items(
            const <Item>[Item(id: 'i1', name: 'Alpha')],
            onSave: (item) async {},
            onRestore: (context, item) => deleted.remove(item.id!),
            isDeleted: (item) => deleted.contains(item.id),
          ),
          registry: buildItemRegistry(),
        ),
      );
      await openTrashView(tester);
      expect(find.byIcon(Icons.restore_from_trash), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('contre-témoin : les deux gestes existants sont inchangés', () {
    testWidgets(
        'mise à la corbeille et restauration gardent leur cycle et leur '
        'confirmation', (tester) async {
      final repo =
          FakePurgeableItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
        ),
      );
      // Vue vivante : la mise à la corbeille est offerte, la purge non.
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.delete_forever), findsNothing);

      // Elle reste confirmée, avec SON texte (réversible), et annuler n'écrit
      // rien.
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('permanently'),
        findsNothing,
        reason: 'la mise à la corbeille se défait : elle ne doit pas emprunter '
            'le texte de la suppression définitive',
      );
      await cancelDestructiveDialog(tester);
      expect(find.text('Alpha'), findsOneWidget);

      // Confirmée, elle retire des vivants ; la restauration rend l'élément.
      await softDeleteFirstRow(tester);
      expect(find.text('Alpha'), findsNothing);
      await openTrashView(tester);
      await tester.tap(find.byIcon(Icons.restore_from_trash).first);
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('zCrudTrashBack')));
      await tester.pumpAndSettle();
      expect(find.text('Alpha'), findsOneWidget);
      expect(repo.purged, isEmpty);
      repo.dispose();
    });
  });
}
