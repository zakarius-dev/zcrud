@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class _Note extends ZEntity {
  const _Note({this.id, required this.title});

  @override
  final String? id;
  final String title;

  static _Note fromMap(Map<String, dynamic> map) => _Note(
    id: map['id'] as String?,
    title: map['title'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => <String, dynamic>{
    'id': id,
    'title': title,
  };
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('deferred_scope_test');
    Hive.init(tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('un scope absent n\'ouvre pas la box non cloisonnée', () async {
    final ValueNotifier<String?> scope = ValueNotifier<String?>(null);
    var opens = 0;
    final ZDeferredScopedLocalStore<_Note> store =
        ZDeferredScopedLocalStore<_Note>(
          kind: 'note',
          scope: scope,
          open: (String next) async {
            opens++;
            return HiveZLocalStore.openBox<_Note>(
              kind: 'note',
              scope: next,
              fromMap: _Note.fromMap,
              toMap: (_Note n) => n.toMap(),
            );
          },
        );

    final ZResult<List<_Note>> empty = await store.getAll();
    expect(empty.getOrElse(() => <_Note>[const _Note(title: 'x')]), isEmpty);
    final ZResult<_Note> refused = await store.put(const _Note(title: 'a'));
    expect(refused.isLeft(), isTrue);
    expect(opens, 0);
    expect(Hive.isBoxOpen(HiveZLocalStore.boxNameFor('note')), isFalse);

    scope.value = 'account';
    final ZResult<_Note> saved = await store.put(const _Note(title: 'a'));
    expect(saved.isRight(), isTrue);
    expect(opens, 1);
    final List<_Note> kept =
        (await store.getAll()).getOrElse(() => <_Note>[]);
    expect(kept, hasLength(1));
    expect(kept.single.title, 'a');
    await _close(store, 'account');
    scope.dispose();
  });

  test('sans scope, une lecture peut échouer au lieu de rendre vide', () async {
    final ValueNotifier<String?> scope = ValueNotifier<String?>(null);
    final ZDeferredScopedLocalStore<_Note> store =
        ZDeferredScopedLocalStore<_Note>(
          kind: 'note',
          scope: scope,
          unsignedReadsAreEmpty: false,
          open: (String next) => HiveZLocalStore.openBox<_Note>(
            kind: 'note',
            scope: next,
            fromMap: _Note.fromMap,
            toMap: (_Note n) => n.toMap(),
          ),
        );
    final ZResult<List<_Note>> read = await store.getAll();
    expect(read.isLeft(), isTrue);
    await _close(store, null);
    scope.dispose();
  });

  test('une ouverture en échec se réessaie à l\'opération suivante', () async {
    final ValueNotifier<String?> scope = ValueNotifier<String?>('account');
    var opens = 0;
    final ZDeferredScopedLocalStore<_Note> store =
        ZDeferredScopedLocalStore<_Note>(
          kind: 'note',
          scope: scope,
          open: (String next) async {
            opens++;
            if (opens == 1) throw StateError('disk');
            return HiveZLocalStore.openBox<_Note>(
              kind: 'note',
              scope: next,
              fromMap: _Note.fromMap,
              toMap: (_Note n) => n.toMap(),
            );
          },
        );
    expect((await store.getAll()).isLeft(), isTrue);
    expect((await store.getAll()).isRight(), isTrue);
    expect(opens, 2);
    await _close(store, 'account');
    scope.dispose();
  });

  test('dispose d\'un store partagé ne ferme pas la box de l\'autre', () async {
    final ValueNotifier<String?> scope = ValueNotifier<String?>('account');
    Future<ZLocalStore<_Note>> open(String next) =>
        HiveZLocalStore.openBox<_Note>(
          kind: 'note',
          scope: next,
          fromMap: _Note.fromMap,
          toMap: (_Note n) => n.toMap(),
        );
    final ZDeferredScopedLocalStore<_Note> first =
        ZDeferredScopedLocalStore<_Note>(
          kind: 'note',
          scope: scope,
          open: open,
        );
    await first.put(const _Note(id: 'a', title: 'a'));
    final ZDeferredScopedLocalStore<_Note> second =
        ZDeferredScopedLocalStore<_Note>(
          kind: 'note',
          scope: scope,
          open: open,
        );
    await second.getAll();
    first.dispose();
    final ZResult<_Note> written = await second.put(
      const _Note(id: 'b', title: 'b'),
    );
    expect(written.isRight(), isTrue);
    await _close(second, 'account');
    scope.dispose();
  });
}

Future<void> _close(ZDeferredScopedLocalStore<_Note> store, String? scope) async {
  store.dispose();
  if (scope == null || scope.isEmpty) return;
  final String name = HiveZLocalStore.boxNameFor('note', scope: scope);
  var spins = 0;
  while (Hive.isBoxOpen(name) && spins < 50) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    spins++;
  }
}
