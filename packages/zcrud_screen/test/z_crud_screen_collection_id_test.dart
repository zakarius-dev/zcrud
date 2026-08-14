// Gardes de la séparation des deux sémantiques de `collectionId` :
// `ZCrudScreen.collectionId` gouverne l'AUTORISATION (`ZAcl.can`) et rien
// d'autre. Il n'est plus transmis à `repository.save` — un dépôt sait déjà où
// il écrit.
//
// Le dépôt de test reproduit fidèlement la sémantique de l'adaptateur
// Firestore : `save` écrit dans `collectionId ?? collectionPath`, et les
// lectures interrogent toujours `collectionPath`. C'est cette asymétrie qui
// rendait la perte silencieuse : l'écriture réussissait dans une collection
// fantôme que rien ne relisait.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Dépôt en mémoire **à collections nommées** : chaque écriture atterrit dans
/// une collection identifiée par son chemin, exactement comme chez
/// l'adaptateur Firestore. Les lectures ne connaissent que [collectionPath].
class CollectionPathRepo implements ZRepository<Item> {
  CollectionPathRepo({required this.collectionPath, List<Item> seed = const []})
      : collections = <String, List<Item>>{
          collectionPath: List<Item>.of(seed),
        };

  /// Chemin de collection du dépôt — la seule collection qu'il relit.
  final String collectionPath;

  /// Contenu réel, par chemin de collection écrit.
  final Map<String, List<Item>> collections;

  final Set<String> _deleted = <String>{};
  final StreamController<List<Item>> _changes =
      StreamController<List<Item>>.broadcast();
  int _nextId = 100;

  List<Item> get _own => collections[collectionPath]!;

  /// Nombre d'éléments présents dans la collection [path] (0 si elle n'a
  /// jamais été créée).
  int countIn(String path) => collections[path]?.length ?? 0;

  List<Item> _alive() =>
      <Item>[for (final e in _own) if (!_deleted.contains(e.id)) e];

  @override
  Future<ZResult<List<Item>>> getAll({ZDataRequest? request}) async {
    final scope = (request ?? const ZDataRequest()).deletedScope;
    return Right(<Item>[
      for (final e in _own)
        if (switch (scope) {
          ZDeletedScope.aliveOnly => !_deleted.contains(e.id),
          ZDeletedScope.deletedOnly => _deleted.contains(e.id),
          ZDeletedScope.includeDeleted => true,
        })
          e,
    ]);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async {
    final res = await getAll(request: request);
    return res.fold(Left.new, (list) => Right(list.length));
  }

  @override
  Future<ZResult<Item>> getById(String id) async {
    for (final e in _alive()) {
      if (e.id == id) return Right(e);
    }
    return Left(ZNotFoundFailure('absent', id: id));
  }

  @override
  Stream<List<Item>> watchAll() => _changes.stream;

  @override
  Stream<List<Item>> watch(ZDataRequest request) => _changes.stream;

  @override
  Future<ZResult<Item>> save(Item item, {String? collectionId}) async {
    // Sémantique de l'adaptateur : le paramètre LOCALISE le conteneur.
    final target = collectionId ?? collectionPath;
    final bucket = collections.putIfAbsent(target, () => <Item>[]);
    final materialized = item.id == null
        ? Item(id: 'id${_nextId++}', name: item.name, qty: item.qty)
        : item;
    final index = bucket.indexWhere((e) => e.id == materialized.id);
    if (index >= 0) {
      bucket[index] = materialized;
    } else {
      bucket.add(materialized);
    }
    _changes.add(_alive());
    return Right(materialized);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    _deleted.add(id);
    _changes.add(_alive());
    return const Right(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    _deleted.remove(id);
    _changes.add(_alive());
    return const Right(unit);
  }

  @override
  void dispose() => _changes.close();
}

/// Dépôt à collections nommées sachant purger.
class PurgeableCollectionPathRepo extends CollectionPathRepo
    with ZPurgeable<Item> {
  PurgeableCollectionPathRepo({
    required super.collectionPath,
    super.seed,
  });

  @override
  Future<ZResult<Unit>> purge(String id) async {
    _own.removeWhere((e) => e.id == id);
    _deleted.remove(id);
    _changes.add(_alive());
    return const Right(unit);
  }
}

/// ACL permissive qui **enregistre** l'identifiant de collection reçu.
class SpyAcl implements ZAcl {
  final List<String?> seenCollectionIds = <String?>[];

  @override
  bool can(ZCrudAction action, {ZEntity? target, String? collectionId}) {
    seenCollectionIds.add(collectionId);
    return true;
  }
}

/// Crée une entité depuis l'écran : bouton « + », saisie du nom, sauvegarde.
Future<void> createEntity(WidgetTester tester, String name) async {
  await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
  await tester.pumpAndSettle();
  final nameField = find.descendant(
    of: find.byType(DynamicEdition),
    matching: find.byType(TextField),
  );
  await tester.enterText(nameField.first, name);
  await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'écriture : un écran déclarant collectionId écrit dans la collection '
      'du dépôt, jamais dans une collection portant la clé d\'ACL',
      (tester) async {
    final repo = CollectionPathRepo(
      collectionPath: 'module_x',
      seed: const <Item>[Item(id: 'i1', name: 'Alpha')],
    );
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        collectionId: 'x',
      ),
    );

    await createEntity(tester, 'Gamma');

    // Contenu RÉEL des deux collections : rien dans la collection fantôme,
    // tout dans celle du dépôt.
    expect(repo.countIn('x'), 0);
    expect(repo.countIn('module_x'), 2);
    expect(repo.collections.keys, <String>['module_x']);
    repo.dispose();
  });

  testWidgets('autorisation : la gouvernance reçoit toujours le collectionId',
      (tester) async {
    final repo = CollectionPathRepo(
      collectionPath: 'module_x',
      seed: const <Item>[Item(id: 'i1', name: 'Alpha')],
    );
    final acl = SpyAcl();
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        collectionId: 'x',
      ),
      acl: acl,
    );

    await createEntity(tester, 'Gamma');

    expect(acl.seenCollectionIds, isNotEmpty);
    expect(acl.seenCollectionIds, everyElement('x'));
    repo.dispose();
  });

  testWidgets(
      'corbeille : mise à la corbeille, restauration et purge n\'ouvrent '
      'aucune collection fantôme', (tester) async {
    final repo = PurgeableCollectionPathRepo(
      collectionPath: 'module_x',
      seed: const <Item>[Item(id: 'i1', name: 'Alpha')],
    );
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.repository(repo),
        registry: buildItemRegistry(),
        collectionId: 'x',
      ),
    );

    // Création (écriture), mise à la corbeille, restauration, puis purge
    // définitive : la totalité des écritures de l'écran.
    await createEntity(tester, 'Gamma');
    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    await tester.tap(find.byIcon(Icons.restore_from_trash).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('zCrudTrashBack')));
    await tester.pumpAndSettle();
    await softDeleteFirstRow(tester);
    await openTrashView(tester);
    await tester.tap(find.byIcon(Icons.delete_forever).first);
    await tester.pumpAndSettle();
    await confirmDestructiveDialog(tester);

    expect(repo.collections.keys, <String>['module_x']);
    expect(repo.countIn('x'), 0);
    repo.dispose();
  });

  test(
      'contre-témoin : un appel DIRECT au dépôt avec un collectionId localise '
      'toujours le conteneur (le port est inchangé)', () async {
    final repo = CollectionPathRepo(collectionPath: 'module_x');

    await repo.save(const Item(id: 'i9', name: 'Delta'), collectionId: 'autre');

    expect(repo.countIn('autre'), 1);
    expect(repo.countIn('module_x'), 0);
    repo.dispose();
  });

  testWidgets('voie items : la sauvegarde déclarée reste appelée telle quelle',
      (tester) async {
    final saved = <Item>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Item>(
        title: 'Items',
        source: ZCrudSource<Item>.items(
          const <Item>[Item(id: 'i1', name: 'Alpha')],
          onSave: (item) async => saved.add(item),
        ),
        registry: buildItemRegistry(),
        collectionId: 'x',
      ),
    );

    await createEntity(tester, 'Gamma');

    expect(saved, hasLength(1));
    expect(saved.single.name, 'Gamma');
  });
}
