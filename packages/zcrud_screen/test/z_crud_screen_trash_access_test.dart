// Gardes de l'ACCÈS à la corbeille : critère de visibilité (restaurer/purger,
// jamais « supprimer »), effacement de l'accès à corbeille vide, et pastille
// de comptage qui se rafraîchit SANS reconstruire le corps de l'écran (AD-2).
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

import 'support/fixtures.dart';

/// ACL n'autorisant que la consultation et les actions de [allowed].
class ViewPlusAcl implements ZAcl {
  const ViewPlusAcl(this.allowed);

  final Set<ZCrudAction> allowed;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action == ZCrudAction.view || allowed.contains(action);
}

/// Sonde du CORPS de l'écran : la projection en cellules est appelée pour
/// chaque ligne à chaque construction du corps. La compter, c'est compter les
/// reconstructions réelles du corps — un widget d'en-tête, lui, serait
/// réutilisé à l'identique et ne mesurerait rien.
Map<String, Object?> Function(Item) countingCells(List<int> projections) =>
    (item) {
      projections.add(1);
      return <String, Object?>{
        'id': item.id,
        'name': item.name,
        'qty': item.qty,
      };
    };

Finder get trashToggle => find.byKey(const ValueKey('zCrudTrashToggle'));

bool _neverDeleted(Item item) => false;

Future<void> _noRestore(BuildContext context, Item item) async {}

Future<FakeItemRepo> pumpTrashScreen(
  WidgetTester tester, {
  required ZAcl acl,
  ZTrashPolicy trashPolicy = ZTrashPolicy.full,
  ValueListenable<int>? trashCount,
}) async {
  final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
  addTearDown(repo.dispose);
  await pumpScreen(
    tester,
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      trashPolicy: trashPolicy,
      trashCount: trashCount,
    ),
    acl: acl,
  );
  return repo;
}

void main() {
  group('Critère de visibilité de l\'accès à la corbeille', () {
    testWidgets(
      'SUPPRIMER seul ⇒ AUCUN accès : mettre à la corbeille n\'est pas y '
      'entrer',
      (tester) async {
        await pumpTrashScreen(
          tester,
          acl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.delete}),
        );
        expect(trashToggle, findsNothing);
        // Le geste de mise à la corbeille, lui, reste offert sur la ligne.
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets('RESTAURER seul ⇒ accès offert', (tester) async {
      await pumpTrashScreen(
        tester,
        acl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.restore}),
      );
      expect(trashToggle, findsOneWidget);
    });

    testWidgets('PURGER seul ⇒ accès offert', (tester) async {
      await pumpTrashScreen(
        tester,
        acl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.clear}),
      );
      expect(trashToggle, findsOneWidget);
    });

    testWidgets('ni restaurer ni purger ⇒ aucun accès', (tester) async {
      await pumpTrashScreen(tester, acl: const ViewPlusAcl(<ZCrudAction>{}));
      expect(trashToggle, findsNothing);
    });

    testWidgets('condition refusante ⇒ aucun accès malgré RESTAURER', (
      tester,
    ) async {
      await pumpTrashScreen(
        tester,
        acl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.restore}),
        trashPolicy: ZTrashPolicy(viewAccess: (_, _) => false),
      );
      expect(trashToggle, findsNothing);
    });

    testWidgets(
      'condition accordante ⇒ vue offerte sans RESTAURER ni PURGER, sans '
      'ouvrir leurs gestes',
      (tester) async {
        final repo = FakePurgeableItemRepo(const <Item>[
          Item(id: 'i1', name: 'Alpha'),
        ]);
        addTearDown(repo.dispose);
        await repo.softDelete('i1');
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.repository(repo),
            registry: buildItemRegistry(),
            trashPolicy: ZTrashPolicy(viewAccess: (_, _) => true),
          ),
          acl: const ViewPlusAcl(<ZCrudAction>{}),
        );

        expect(trashToggle, findsOneWidget);
        await openTrashView(tester);
        expect(find.byIcon(Icons.restore_from_trash), findsNothing);
        expect(find.byIcon(Icons.delete_forever), findsNothing);
      },
    );

    testWidgets('sans condition : le défaut garde ses comptes absolus', (
      tester,
    ) async {
      await pumpTrashScreen(
        tester,
        acl: const ViewPlusAcl(<ZCrudAction>{ZCrudAction.restore}),
      );
      expect(trashToggle, findsOneWidget);
      expect(find.byType(IconButton), findsNWidgets(2));
    });

    testWidgets('condition qui lève ⇒ accès refusé sans exception au rendu', (
      tester,
    ) async {
      await pumpTrashScreen(
        tester,
        acl: const ZAllowAllAcl(),
        trashPolicy: ZTrashPolicy(
          viewAccess: (_, _) => throw StateError('condition injectée'),
        ),
      );
      expect(trashToggle, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('Corbeille vide', () {
    testWidgets(
      'visibleWhenEmpty: false + compte NUL ⇒ pas de bouton vers une page '
      'vide',
      (tester) async {
        final counter = ValueNotifier<int>(0);
        addTearDown(counter.dispose);
        await pumpTrashScreen(
          tester,
          acl: const ZAllowAllAcl(),
          trashPolicy: const ZTrashPolicy(visibleWhenEmpty: false),
          trashCount: counter,
        );
        expect(trashToggle, findsNothing);
      },
    );

    testWidgets('le bouton REVIENT dès que la corbeille se remplit', (
      tester,
    ) async {
      final counter = ValueNotifier<int>(0);
      addTearDown(counter.dispose);
      await pumpTrashScreen(
        tester,
        acl: const ZAllowAllAcl(),
        trashPolicy: const ZTrashPolicy(visibleWhenEmpty: false),
        trashCount: counter,
      );
      expect(trashToggle, findsNothing);

      counter.value = 2;
      await tester.pump();
      expect(trashToggle, findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('compte INCONNU : l\'accès reste offert (non compté ≠ vide)', (
      tester,
    ) async {
      await pumpTrashScreen(
        tester,
        acl: const ZAllowAllAcl(),
        trashPolicy: const ZTrashPolicy(visibleWhenEmpty: false),
      );
      expect(trashToggle, findsOneWidget);
    });

    testWidgets(
      'CONTRE-TÉMOIN : par défaut (visibleWhenEmpty), l\'accès reste offert '
      'à zéro élément',
      (tester) async {
        final counter = ValueNotifier<int>(0);
        addTearDown(counter.dispose);
        await pumpTrashScreen(
          tester,
          acl: const ZAllowAllAcl(),
          trashCount: counter,
        );
        expect(trashToggle, findsOneWidget);
      },
    );

    testWidgets(
      'visibleWhenEmpty: false masque une corbeille vide après condition '
      'accordante',
      (tester) async {
        final counter = ValueNotifier<int>(0);
        addTearDown(counter.dispose);
        await pumpTrashScreen(
          tester,
          acl: const ViewPlusAcl(<ZCrudAction>{}),
          trashPolicy: ZTrashPolicy(
            visibleWhenEmpty: false,
            viewAccess: (_, _) => true,
          ),
          trashCount: counter,
        );
        expect(trashToggle, findsNothing);
      },
    );
  });

  group('Pastille de comptage de la corbeille', () {
    testWidgets('le compte déclaré est affiché et ANNONCÉ', (tester) async {
      final counter = ValueNotifier<int>(4);
      addTearDown(counter.dispose);
      await pumpTrashScreen(
        tester,
        acl: const ZAllowAllAcl(),
        trashCount: counter,
      );
      expect(find.byType(ZCountBadge), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Trash, 4 items in trash')),
        findsOneWidget,
      );
    });

    testWidgets(
      'AD-2 : changer le compte redessine la PASTILLE, pas le corps de '
      'l\'écran',
      (tester) async {
        final counter = ValueNotifier<int>(1);
        addTearDown(counter.dispose);
        final projections = <int>[];
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: const ZCrudSource<Item>.items(
              <Item>[Item(id: 'i1', name: 'Alpha')],
              isDeleted: _neverDeleted,
              onRestore: _noRestore,
            ),
            registry: buildItemRegistry(),
            listFields: itemSpecs,
            cellsOf: countingCells(projections),
            trashCount: counter,
          ),
        );
        expect(find.text('1'), findsOneWidget);
        final before = projections.length;
        expect(before, greaterThan(0));

        counter.value = 9;
        await tester.pump();

        expect(find.text('9'), findsOneWidget);
        expect(
          projections.length,
          before,
          reason:
              'le corps de l\'écran a été reconstruit alors que SEUL le '
              'compte de la corbeille a changé',
        );
      },
    );

    testWidgets('showCount: false ⇒ aucune pastille, accès inchangé', (
      tester,
    ) async {
      final counter = ValueNotifier<int>(4);
      addTearDown(counter.dispose);
      await pumpTrashScreen(
        tester,
        acl: const ZAllowAllAcl(),
        trashPolicy: const ZTrashPolicy(showCount: false),
        trashCount: counter,
      );
      expect(trashToggle, findsOneWidget);
      expect(find.byType(ZCountBadge), findsNothing);
      expect(find.text('4'), findsNothing);
    });

    testWidgets(
      'voie items : le compte est DÉRIVÉ de la liste, sans rien déclarer',
      (tester) async {
        await pumpScreen(
          tester,
          ZCrudScreen<Item>(
            title: 'Items',
            source: ZCrudSource<Item>.items(
              const <Item>[
                Item(id: 'i1', name: 'Alpha'),
                Item(id: 'i2', name: 'Beta'),
                Item(id: 'i3', name: 'Gamma'),
              ],
              isDeleted: (item) => item.id != 'i1',
              onSave: (_) async {},
              onRestore: (context, item) async {},
            ),
            registry: buildItemRegistry(),
          ),
        );
        expect(trashToggle, findsOneWidget);
        expect(find.text('2'), findsOneWidget);
      },
    );

    testWidgets(
      'CONTRE-TÉMOIN : sans compte déclaré ni dérivable, aucune pastille '
      '(comportement strictement antérieur)',
      (tester) async {
        await pumpTrashScreen(tester, acl: const ZAllowAllAcl());
        expect(trashToggle, findsOneWidget);
        expect(find.byType(ZCountBadge), findsNothing);
      },
    );
  });
}
