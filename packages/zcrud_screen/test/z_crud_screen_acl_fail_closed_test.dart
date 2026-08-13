// Gardes du REFUS PAR DÉFAUT (fail-closed) de `ZCrudScreen`.
//
// 🔴 MOTIF — le socle repliait sur une ACL PERMISSIVE quand aucune n'était
// déclarée : une application qui oubliait de brancher la sienne voyait TOUS les
// gestes (créer, modifier, corbeille, restaurer, actions de ligne) au lieu
// d'AUCUN. Rien ne levait, rien ne rougissait. Le repli est désormais refusant,
// et `ZCrudAction.view` gouverne l'écran entier.
//
// Ce fichier affirme les quatre faces de la règle :
//   (a) sans ACL déclarée  → aucun geste, et un état « accès refusé » ;
//   (b) `ZAllowAllAcl` DÉCLARÉE → tous les gestes reviennent (échappatoire) ;
//   (c) `view` refusé      → état d'accès refusé ET **aucune lecture** de la
//                            source (assertion d'ABSENCE d'appel au dépôt, pas
//                            seulement d'absence visuelle) ;
//   (d) contre-témoin      → une ACL réelle rend exactement le comportement
//                            d'avant (non-régression).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart' show ZErrorState;

import 'support/fixtures.dart';

/// Décorateur COMPTEUR : recense toute lecture réellement adressée au dépôt.
///
/// C'est la sonde de la face (c) : un écran refusé ne doit pas seulement
/// *cacher* la liste, il ne doit pas **interroger** la source.
class _CountingRepo implements ZRepository<Item> {
  _CountingRepo(this._inner);

  final ZRepository<Item> _inner;

  /// Nombre d'appels de LECTURE (`getAll`/`count`/`getById`/`watch*`).
  int reads = 0;

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) {
    reads++;
    return _inner.getAll(request: request);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) {
    reads++;
    return _inner.count(request: request);
  }

  @override
  Future<ZResult<Item>> getById(String id) {
    reads++;
    return _inner.getById(id);
  }

  @override
  Stream<List<Item>> watch(ZDataRequest request) {
    reads++;
    return _inner.watch(request);
  }

  @override
  Stream<List<Item>> watchAll() {
    reads++;
    return _inner.watchAll();
  }

  @override
  Future<ZResult<Item>> save(Item item, {String? collectionId}) =>
      _inner.save(item, collectionId: collectionId);

  @override
  Future<ZResult<Unit>> softDelete(String id) => _inner.softDelete(id);

  @override
  Future<ZResult<Unit>> restore(String id) => _inner.restore(id);

  @override
  void dispose() => _inner.dispose();
}

/// ACL réelle d'une application : consultation ouverte, écritures réservées.
class _ReaderAcl implements ZAcl {
  const _ReaderAcl();

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      action == ZCrudAction.view;
}

Widget _screen(ZRepository<Item> repo) => ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
    );

void main() {
  group('(a) aucune ACL déclarée ⇒ AUCUN geste', () {
    testWidgets('écran : ni création, ni corbeille, ni action de ligne',
        (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      // `acl: null` = aucune ACL déclarée nulle part (ni écran, ni scope).
      await pumpScreen(tester, _screen(repo), acl: null);

      expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
      expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byIcon(Icons.copy_outlined), findsNothing);
      // Aucune donnée n'est rendue non plus : `view` gouverne l'écran.
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('DynamicList SEULE : les actions de ligne gouvernées '
        'disparaissent', (tester) async {
      const entity = Item(id: 'i1', name: 'Alpha');
      var custom = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynamicList<Item>.rows(
              itemSpecs,
              const <ZListRow>[
                ZListRow(id: 'i1', cells: <String, Object?>{'name': 'Alpha'}),
              ],
              layout: ZListBuilderLayout(
                itemBuilder: (context, row, columns) =>
                    Text('cell-${row.cells['name']}'),
              ),
              entityFor: (_) => entity,
              rowActions: <ZRowAction<Item>>[
                ZRowAction<Item>(
                  id: 'edit',
                  labelKey: 'edit',
                  requiredPermission: ZCrudAction.update,
                  onInvoke: (context, item) {},
                ),
                // Action SANS permission : toujours offerte (elle ne dépend
                // d'aucune autorisation), ce qui prouve que la liste EST rendue
                // et que la garde n'est pas vacante.
                ZRowAction<Item>(
                  id: 'custom',
                  labelKey: 'copy',
                  onInvoke: (context, item) => custom++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('cell-Alpha'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Copy'), findsOneWidget);
      expect(custom, 0);
    });
  });

  group('(b) `ZAllowAllAcl` DÉCLARÉE ⇒ tous les gestes reviennent', () {
    testWidgets('écran : création, corbeille et actions de ligne offertes',
        (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo), acl: const ZAllowAllAcl());

      expect(find.byKey(const ValueKey('zCrudCreate')), findsOneWidget);
      expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
    });

    testWidgets('le paramètre `acl:` de l\'écran l\'emporte sur le scope',
        (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        ZCrudScreen<Item>(
          title: 'Items',
          source: ZCrudSource<Item>.repository(repo),
          registry: buildItemRegistry(),
          acl: const ZAllowAllAcl(),
        ),
        // Scope refusant tout : c'est le paramètre de l'écran qui doit gagner.
        acl: const ZDenyAllAcl(),
      );

      expect(find.byKey(const ValueKey('zCrudCreate')), findsOneWidget);
      expect(find.text('Alpha'), findsWidgets);
    });
  });

  group('(c) `view` refusé ⇒ état d\'accès refusé, AUCUNE lecture', () {
    testWidgets('l\'état est rendu et le dépôt n\'est JAMAIS interrogé',
        (tester) async {
      final inner = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      final repo = _CountingRepo(inner);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo), acl: const ZDenyAllAcl());

      // L'état d'accès refusé est rendu, avec son message TEXTE (jamais une
      // icône seule).
      expect(find.byKey(const ValueKey('zCrudAccessDenied')), findsOneWidget);
      expect(find.byType(ZErrorState), findsOneWidget);
      expect(find.text('Access denied'), findsOneWidget);
      // ABSENCE d'appel : la source n'a pas été lue une seule fois.
      expect(repo.reads, 0, reason: 'une lecture a été déclenchée malgré le '
          'refus de `view`');
      // Et rien du listing n'est monté.
      expect(find.byType(DynamicList<Item>), findsNothing);
      expect(find.text('Alpha'), findsNothing);
    });

    testWidgets('un contre-témoin PROUVE que la sonde compte bien les lectures',
        (tester) async {
      final inner = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      final repo = _CountingRepo(inner);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo), acl: const ZAllowAllAcl());

      expect(repo.reads, greaterThan(0),
          reason: 'sonde inerte : la garde d\'absence serait vacante');
    });
  });

  group('(d) contre-témoin : une ACL réelle se comporte comme avant', () {
    testWidgets('lecture autorisée, écritures refusées : la liste s\'affiche, '
        'les gestes d\'écriture non', (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo), acl: const _ReaderAcl());

      // La consultation passe : la donnée est rendue.
      expect(find.text('Alpha'), findsWidgets);
      expect(find.byKey(const ValueKey('zCrudAccessDenied')), findsNothing);
      // Les écritures restent fermées, exactement comme avant l'inversion.
      expect(find.byKey(const ValueKey('zCrudCreate')), findsNothing);
      expect(find.byKey(const ValueKey('zCrudTrashToggle')), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('une ACL qui autorise tout sauf la suppression garde la '
        'création et l\'édition', (tester) async {
      final repo = FakeItemRepo(const <Item>[Item(id: 'i1', name: 'Alpha')]);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(repo),
        acl: const DenyAcl(<ZCrudAction>{ZCrudAction.delete}),
      );

      expect(find.byKey(const ValueKey('zCrudCreate')), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
