@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class _Doc extends ZEntity {
  const _Doc({required this.id, required this.folder});

  @override
  final String? id;
  final String folder;
}

class _Mem implements ZLocalStore<_Doc> {
  final Map<String, _Doc> items = <String, _Doc>{};
  int clears = 0;
  int disposes = 0;

  @override
  Stream<List<_Doc>> watchAll() async* {
    yield items.values.toList();
  }

  @override
  Future<ZResult<List<_Doc>>> getAll() async =>
      Right<ZFailure, List<_Doc>>(items.values.toList());

  @override
  Future<ZResult<_Doc>> getById(String id) async {
    final _Doc? found = items[id];
    if (found == null) {
      return Left<ZFailure, _Doc>(ZNotFoundFailure('absent', id: id));
    }
    return Right<ZFailure, _Doc>(found);
  }

  @override
  Future<ZResult<_Doc>> put(_Doc item) async {
    items[item.id!] = item;
    return Right<ZFailure, _Doc>(item);
  }

  @override
  Future<ZResult<_Doc>> putMerged(_Doc item) => put(item);

  @override
  Future<ZResult<Unit>> softDelete(String id) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> restore(String id) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<List<ZSyncEntry<_Doc>>>> syncEntries() async =>
      Right<ZFailure, List<ZSyncEntry<_Doc>>>(<ZSyncEntry<_Doc>>[
        for (final _Doc doc in items.values)
          ZSyncEntry<_Doc>(
            entity: doc,
            meta: ZSyncMeta(updatedAt: DateTime.utc(2026), isDeleted: false),
          ),
      ]);

  @override
  Future<ZResult<Unit>> applyMerged(ZSyncEntry<_Doc> entry) async {
    items[entry.entity.id!] = entry.entity;
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> purge(String id) async {
    items.remove(id);
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> clear() async {
    clears++;
    items.clear();
    return const Right<ZFailure, Unit>(unit);
  }

  @override
  void dispose() => disposes++;
}

void main() {
  test('un dossier ne voit ni n\'efface les autres', () async {
    final _Mem mem = _Mem();
    await mem.put(const _Doc(id: 'a', folder: 'f1'));
    await mem.put(const _Doc(id: 'b', folder: 'f2'));
    final ZFolderScopedLocalStore<_Doc> scoped = ZFolderScopedLocalStore<_Doc>(
      inner: mem,
      folderId: 'f1',
      folderIdOf: (_Doc doc) => doc.folder,
    );

    final List<_Doc> all = (await scoped.getAll()).getOrElse(() => <_Doc>[]);
    expect(all.map((_Doc d) => d.id), <String?>['a']);
    expect(
      (await scoped.put(const _Doc(id: 'c', folder: 'f2'))).isLeft(),
      isTrue,
    );
    expect(mem.items.containsKey('c'), isFalse);

    expect((await scoped.clear()).isRight(), isTrue);
    expect(mem.clears, 0);
    expect(mem.items.containsKey('b'), isTrue);
    expect(mem.items.containsKey('a'), isFalse);

    scoped.dispose();
    expect(mem.disposes, 0);
  });
}
