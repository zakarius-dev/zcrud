// Tests E5-2 : `FirestoreZRemoteStore<T>` (store DISTANT fire-and-forget par
// COMPOSITION sur `FirebaseZRepositoryImpl` d'E5-1).
//
// Backend : `fake_cloud_firestore` (round-trip push/pull, watch, soft-delete).
// L'objet de ces tests est la DÉLÉGATION (mêmes invariants clé/soft-delete que
// E5-1) + la PROPAGATION typée du ZResult — l'orchestration (débounce, merge,
// best-effort silencieux) est E5-3/E5-4 et n'est PAS testée ici.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

class _Note extends ZEntity {
  const _Note({this.id, required this.title, required this.count});

  @override
  final String? id;
  final String title;
  final int count;

  static _Note fromMap(Map<String, dynamic> map) {
    final title = map['title'];
    final count = map['count'];
    if (title is! String) throw const FormatException('title');
    if (count is! int) throw const FormatException('count');
    return _Note(id: map['id'] as String?, title: title, count: count);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'title': title,
        'count': count,
      };

  @override
  bool operator ==(Object other) =>
      other is _Note &&
      other.id == id &&
      other.title == title &&
      other.count == count;

  @override
  int get hashCode => Object.hash(id, title, count);
}

const String _kPath = 'notes';

FirestoreZRemoteStore<_Note> _remote(FakeFirebaseFirestore fs) =>
    FirestoreZRemoteStore<_Note>(
      repository: FirebaseZRepositoryImpl<_Note>(
        firestore: fs,
        collectionPath: _kPath,
        kind: 'note',
        fromMap: _Note.fromMap,
        toMap: (n) => n.toMap(),
      ),
    );

void main() {
  group('AC11 — round-trip push/pull + délégation', () {
    test('push (éphémère) matérialise un id puis pull restitue l\'égal',
        () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remote(fs);

      final pushed = (await remote.push(const _Note(title: 'Alpha', count: 3)))
          .getOrElse(() => fail('push'));
      expect(pushed.id, isNotNull);

      final pulled = (await remote.pull()).getOrElse(() => fail('pull'));
      expect(pulled, contains(pushed));
      remote.dispose();
    });

    test('pull filtré délègue à getAll(request:)', () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remote(fs);
      await remote.push(const _Note(id: 'a', title: 'a', count: 1));
      await remote.push(const _Note(id: 'b', title: 'b', count: 9));

      final r = (await remote.pull(
        request: const ZDataRequest(
          filters: <ZFilter>[ZFilter('count', ZFilterOp.gte, 5)],
        ),
      ))
          .getOrElse(() => fail('pull'));
      expect(r.map((n) => n.id), <String>['b']);
      remote.dispose();
    });
  });

  group('AC11/AC12 — remoteDelete propage le soft-delete (hors-entité)', () {
    test('remoteDelete masque l\'entité des lectures (pas de purge physique)',
        () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remote(fs);
      final n = (await remote.push(const _Note(id: 'x', title: 'x', count: 1)))
          .toIterable()
          .first;

      final del = await remote.remoteDelete(n.id!);
      expect(del.isRight(), isTrue);

      final pulled = (await remote.pull()).getOrElse(() => fail('pull'));
      expect(pulled, isEmpty);

      // Soft-delete : le document existe encore côté distant (drapeau), pas de
      // suppression physique.
      final raw = await fs.collection(_kPath).doc('x').get();
      expect(raw.exists, isTrue);
      expect(raw.data()!['is_deleted'], isTrue);
      remote.dispose();
    });

    test('remoteDelete d\'un id inconnu → Left(ZNotFoundFailure)', () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remote(fs);
      final r = await remote.remoteDelete('nope');
      expect(r.isLeft(), isTrue);
      r.leftMap((f) => expect(f, isA<ZNotFoundFailure>()));
      remote.dispose();
    });
  });

  group('AC11 — watchAll délègue au flux nu E5-1', () {
    test('émet un seed (Stream<List<T>> nu) puis reflète les push', () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remote(fs);
      await remote.push(const _Note(id: 's1', title: 's', count: 1));

      final first = await remote.watchAll().first;
      expect(first, isA<List<_Note>>());
      expect(first.map((n) => n.id), <String>['s1']);
      remote.dispose();
    });
  });

  group('AC12 — propagation typée (ZServerFailure jamais avalé)', () {
    test('ZResult remonte intact depuis l\'adaptateur E5-1', () async {
      final fs = FakeFirebaseFirestore();
      final remote = _remote(fs);
      final r = await remote.pull();
      expect(r, isA<Right<ZFailure, List<_Note>>>());
      remote.dispose();
    });
  });
}
