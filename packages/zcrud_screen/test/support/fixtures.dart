// Fixtures partagées des gardes de `zcrud_screen` : entité de test, registre
// manuel (mêmes structures que le registrar généré : specs aux NOMS PERSISTÉS),
// fake `ZRepository` NEUTRE honorant `ZDataRequest.deletedScope` (même patron
// que les fakes des gardes de `zcrud_core`).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

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
    _deleted.add(id);
    _changes.add(_select(ZDeletedScope.aliveOnly));
    return const Right(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    _deleted.remove(id);
    _changes.add(_select(ZDeletedScope.aliveOnly));
    return const Right(unit);
  }

  @override
  void dispose() {
    _changes.close();
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
Future<void> pumpScreen(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}
