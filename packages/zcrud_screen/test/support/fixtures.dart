// Fixtures partagées des gardes de `zcrud_screen` : entité de test, registre
// manuel (mêmes structures que le registrar généré : specs aux NOMS PERSISTÉS),
// fake `ZRepository` NEUTRE honorant `ZDataRequest.deletedScope` (même patron
// que les fakes des gardes de `zcrud_core`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_ui_kit/zcrud_ui_kit.dart';

/// Entité de test : identité opaque + deux champs métier.
class Item extends ZEntity {
  const Item({this.id, required this.name, this.qty = 0});

  @override
  final String? id;
  final String name;
  final int qty;
}

/// Schéma « généré » : noms de specs = clés persistées (comme le codegen).
const List<ZFieldSpec> itemSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'qty', type: EditionFieldType.integer),
];

/// Registre où [Item] est enregistré sous le kind `item`, avec ses specs —
/// l'équivalent manuel du registrar émis par `zcrud_generator`.
ZcrudRegistry buildItemRegistry() {
  final registry = ZcrudRegistry();
  registry.register<Item>(
    'item',
    fromMap: (map) => Item(
      id: map['id'] as String?,
      name: (map['name'] as String?) ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
    ),
    toMap: (item) => <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'qty': item.qty,
    },
    fieldSpecs: itemSpecs,
  );
  return registry;
}

/// Fake `ZRepository` en mémoire, NEUTRE : honore `deletedScope` (corbeille),
/// la recherche via `zApplyListRequest`, matérialise l'éphémère au `save` et
/// émet sur `watchAll` à chaque mutation.
class FakeItemRepo implements ZRepository<Item> {
  FakeItemRepo(List<Item> seed) : _store = List<Item>.of(seed);

  final List<Item> _store;
  final Set<String> _deleted = <String>{};
  final StreamController<List<Item>> _changes =
      StreamController<List<Item>>.broadcast();
  int _nextId = 100;

  /// Entités passées à [save], dans l'ordre.
  final List<Item> saved = <Item>[];

  /// Identités passées à [softDelete], dans l'ordre (ce qui a RÉELLEMENT été
  /// écrit — la garde d'exclusion d'un lot s'assère là-dessus, pas sur le
  /// rendu).
  final List<String> softDeleted = <String>[];

  /// Identités passées à [restore], dans l'ordre.
  final List<String> restored = <String>[];

  /// Nombre d'appels à [getAll] (coût réel des lectures de source).
  int getAllCalls = 0;

  List<Item> _select(ZDeletedScope scope) => <Item>[
        for (final item in _store)
          if (switch (scope) {
            ZDeletedScope.aliveOnly => !_deleted.contains(item.id),
            ZDeletedScope.deletedOnly => _deleted.contains(item.id),
            ZDeletedScope.includeDeleted => true,
          })
            item,
      ];

  ZListRow _toRow(Item item) => ZListRow(
        id: item.id!,
        cells: <String, Object?>{
          'id': item.id,
          'name': item.name,
          'qty': item.qty,
        },
      );

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) async {
    getAllCalls++;
    final req = request ?? const ZDataRequest();
    final selected = _select(req.deletedScope);
    final page = zApplyListRequest(
      <ZListRow>[for (final item in selected) _toRow(item)],
      req,
      schema: itemSpecs,
    );
    final byId = <String, Item>{for (final item in selected) item.id!: item};
    return Right(<Item>[for (final row in page.rows) byId[row.id]!]);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_select((request ?? const ZDataRequest()).deletedScope).length);

  @override
  Future<ZResult<Item>> getById(String id) async {
    for (final item in _select(ZDeletedScope.aliveOnly)) {
      if (item.id == id) return Right(item);
    }
    return Left(ZNotFoundFailure('absent', id: id));
  }

  @override
  Stream<List<Item>> watchAll() => _changes.stream;

  @override
  Stream<List<Item>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<Item>> save(Item item, {String? collectionId}) async {
    final materialized = item.id == null
        ? Item(id: 'id${_nextId++}', name: item.name, qty: item.qty)
        : item;
    saved.add(materialized);
    final index = _store.indexWhere((e) => e.id == materialized.id);
    if (index >= 0) {
      _store[index] = materialized;
    } else {
      _store.add(materialized);
    }
    _changes.add(_select(ZDeletedScope.aliveOnly));
    return Right(materialized);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    softDeleted.add(id);
    _deleted.add(id);
    _changes.add(_select(ZDeletedScope.aliveOnly));
    return const Right(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    restored.add(id);
    _deleted.remove(id);
    _changes.add(_select(ZDeletedScope.aliveOnly));
    return const Right(unit);
  }

  @override
  void dispose() {
    _changes.close();
  }
}

/// Fake dépôt sachant **purger** : exactement le même dépôt en mémoire, plus
/// le mixin optionnel `ZPurgeable`. C'est la seule différence entre les deux
/// fixtures — ce qui rend mesurable « avec mixin » vs « sans mixin ».
class FakePurgeableItemRepo extends FakeItemRepo with ZPurgeable<Item> {
  FakePurgeableItemRepo(super.seed);

  /// Identités passées à [purge], dans l'ordre.
  final List<String> purged = <String>[];

  @override
  Future<ZResult<Unit>> purge(String id) async {
    purged.add(id);
    _store.removeWhere((item) => item.id == id);
    _deleted.remove(id);
    _changes.add(_select(ZDeletedScope.aliveOnly));
    return const Right(unit);
  }
}

/// ACL refusant les actions de [denied], autorisant le reste.
class DenyAcl implements ZAcl {
  const DenyAcl(this.denied);

  final Set<ZCrudAction> denied;

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) =>
      !denied.contains(action);
}

/// Monte [child] dans une app Material à fenêtre large (mode `dialog` stable
/// pour la présentation d'édition).
///
/// L'ACL permissive est **DÉCLARÉE** au scope : le socle refuse par défaut, et
/// déclarer l'ouverture totale est exactement le geste qu'une application doit
/// poser tant qu'elle n'a pas d'ACL réelle. Passer [acl] remplace ce défaut de
/// test ; passer `acl: null` monte l'écran SANS aucune ACL déclarée (sert les
/// gardes de refus par défaut).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  ZAcl? acl = const ZAllowAllAcl(),
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: acl == null ? child : ZcrudScope(acl: acl, child: child),
    ),
  );
  await tester.pumpAndSettle();
}

/// Confirme le dialogue destructif du socle (`ZConfirmDialog` de
/// `zcrud_ui_kit`) : bouton de confirmation = `FilledButton` du dialog.
Future<void> confirmDestructiveDialog(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ZConfirmDialog),
      matching: find.byType(FilledButton),
    ),
  );
  await tester.pumpAndSettle();
}

/// **Annule** le dialogue destructif du socle : bouton d'annulation =
/// `TextButton` du dialog.
Future<void> cancelDestructiveDialog(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(ZConfirmDialog),
      matching: find.byType(TextButton),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bascule vers la vue corbeille.
Future<void> openTrashView(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('zCrudTrashToggle')));
  await tester.pumpAndSettle();
}

/// Met la première ligne à la corbeille en passant par la confirmation.
Future<void> softDeleteFirstRow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.delete_outline).first);
  await tester.pumpAndSettle();
  await confirmDestructiveDialog(tester);
}

/// Ouvre la recherche de l'app-bar (`ZSearchableAppBar`) et saisit [text].
/// La recherche n'est plus un champ de corps : le titre MORPHE en champ après
/// activation de la loupe — d'où l'ouverture explicite.
Future<void> searchInAppBar(WidgetTester tester, String text) async {
  final searchIcon = find.descendant(
    of: find.byType(AppBar),
    matching: find.byIcon(Icons.search),
  );
  if (searchIcon.evaluate().isNotEmpty) {
    await tester.tap(searchIcon);
    await tester.pumpAndSettle();
  }
  await tester.enterText(
    find.descendant(of: find.byType(AppBar), matching: find.byType(TextField)),
    text,
  );
  await tester.pumpAndSettle();
}
