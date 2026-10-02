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
    scope.dispose();
  });
}
