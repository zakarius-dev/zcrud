// CR-DODLP 2026-08-11 « parc documentaire existant » + Lot 2a « listing
// corbeille » : sémantique de lecture `ZDeletionSemantics` (opt-in,
// `absentMeansAlive`) + scope `ZDataRequest.deletedScope` honoré dans les DEUX
// sémantiques par `FirebaseZRepositoryImpl`.
//
// Le PREMIER test reproduit le test du spike DODLP (`z_berth_repository_test`)
// à l'identique de mécanisme : un document écrit par le chemin legacy (AUCUNE
// métadonnée ZSyncMeta, pas de `is_deleted`) est INVISIBLE en mode strict
// (comportement historique GARDÉ) et VISIBLE en `absentMeansAlive`.
//
// Backend : `fake_cloud_firestore` (même outillage que la suite E5-1).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_firestore/zcrud_firestore.dart';

// ───────────────────────── Modèle de test ─────────────────────────────────

/// Entité minimale (mêmes conventions que `firebase_z_repository_impl_test`).
class _Berth extends ZEntity {
  const _Berth({this.id, required this.name});

  @override
  final String? id;
  final String name;

  static _Berth fromMap(Map<String, dynamic> map) {
    final name = map['name'];
    if (name is! String) throw const FormatException('name manquant');
    return _Berth(id: map['id'] as String?, name: name);
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (id != null) 'id': id,
        'name': name,
      };

  @override
  bool operator ==(Object other) =>
      other is _Berth && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

const String _kPath = 'bmd_berths';

FirebaseZRepositoryImpl<_Berth> _repo(
  FakeFirebaseFirestore fs, {
  ZDeletionSemantics semantics = ZDeletionSemantics.strict,
  String? legacyDeletedKey,
}) =>
    FirebaseZRepositoryImpl<_Berth>(
      firestore: fs,
      collectionPath: _kPath,
      kind: 'berth',
      fromMap: _Berth.fromMap,
      toMap: (b) => b.toMap(),
      deletionSemantics: semantics,
      legacyDeletedKey: legacyDeletedKey,
    );

/// Document « parc existant » écrit par le chemin LEGACY : corps métier NU —
/// aucune métadonnée `ZSyncMeta` (`is_deleted`/`updated_at` ABSENTS), comme le
/// spike DODLP (`.set(berth.toMap())`). [extra] permet d'y poser la clé legacy
/// camelCase (`deleted: true`).
Future<void> _seedLegacy(
  FakeFirebaseFirestore fs,
  String id,
  String name, {
  Map<String, dynamic> extra = const <String, dynamic>{},
}) =>
    fs.collection(_kPath).doc(id).set(<String, dynamic>{
      'id': id,
      'name': name,
      ...extra,
    });

/// Document « né zcrud » : `is_deleted` explicite (comme `_seedRaw` E5-1).
Future<void> _seedZcrud(
  FakeFirebaseFirestore fs,
  String id,
  String name, {
  bool isDeleted = false,
}) =>
    fs.collection(_kPath).doc(id).set(<String, dynamic>{
      'id': id,
      'name': name,
      'is_deleted': isDeleted,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

List<String> _names(ZResult<List<_Berth>> r) => r.fold(
      (f) => fail('Left inattendu : $f'),
      (list) => list.map((b) => b.name).toList()..sort(),
    );

void main() {
  group('CR-DODLP — reproduction du test du spike (legacy sans is_deleted)',
      () {
    test(
        'strict (défaut, GARDÉ) : le document legacy vivant est INVISIBLE '
        'de getAll', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLegacy(fs, 'legacy-1', 'quai nord');

      final repo = _repo(fs); // défaut = strict, aucun paramètre nouveau
      final all = await repo.getAll();

      expect(_names(all), isEmpty,
          reason: 'comportement historique inchangé : sans is_deleted, '
              'exclu de tous les chemins de lecture');
      repo.dispose();
    });

    test('absentMeansAlive : le MÊME document legacy vivant est VISIBLE',
        () async {
      final fs = FakeFirebaseFirestore();
      await _seedLegacy(fs, 'legacy-1', 'quai nord');

      final repo =
          _repo(fs, semantics: ZDeletionSemantics.absentMeansAlive);
      final all = await repo.getAll();

      expect(_names(all), <String>['quai nord'],
          reason: 'absent = vivant (sens métier legacy) — résolution de la '
              'bascule de lecture B3 sans backfill');
      repo.dispose();
    });

    test('absentMeansAlive : getById lit aussi le document legacy', () async {
      final fs = FakeFirebaseFirestore();
      await _seedLegacy(fs, 'legacy-1', 'quai nord');

      final strict = _repo(fs);
      final compat =
          _repo(fs, semantics: ZDeletionSemantics.absentMeansAlive);

      expect((await strict.getById('legacy-1')).isLeft(), isTrue,
          reason: 'strict : is_deleted absent ⇒ non visible (inchangé)');
      expect(
        (await compat.getById('legacy-1'))
            .fold((f) => fail('Left inattendu : $f'), (b) => b.name),
        'quai nord',
      );
      strict.dispose();
      compat.dispose();
    });
  });

  group('deletedScope — sémantique STRICT (clauses serveur)', () {
    late FakeFirebaseFirestore fs;
    late FirebaseZRepositoryImpl<_Berth> repo;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      repo = _repo(fs);
      await _seedZcrud(fs, 'a', 'vivant-a');
      await _seedZcrud(fs, 'b', 'vivant-b');
      await _seedZcrud(fs, 't', 'corbeille-t', isDeleted: true);
      await _seedLegacy(fs, 'l', 'legacy-l'); // sans is_deleted
    });

    tearDown(() => repo.dispose());

    test('aliveOnly (défaut) : vivants seuls, legacy exclu (inchangé)',
        () async {
      expect(_names(await repo.getAll()), <String>['vivant-a', 'vivant-b']);
    });

    test('deletedOnly : les soft-deleted SEULS (corbeille)', () async {
      final r = await repo.getAll(
        request:
            const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
      );
      expect(_names(r), <String>['corbeille-t']);
    });

    test('includeDeleted : vivants + supprimés, l\'ABSENT reste exclu (strict)',
        () async {
      final r = await repo.getAll(
        request:
            const ZDataRequest(deletedScope: ZDeletedScope.includeDeleted),
      );
      expect(
        _names(r),
        <String>['corbeille-t', 'vivant-a', 'vivant-b'],
        reason: 'strict : un document SANS is_deleted n\'appartient à AUCUN '
            'scope (précondition zcrud-native inchangée)',
      );
    });

    test('watch honore deletedOnly (flux corbeille)', () async {
      final events = <List<_Berth>>[];
      final sub = repo
          .watch(const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly))
          .listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, isNotEmpty);
      expect(events.last.map((b) => b.name), <String>['corbeille-t']);
      await sub.cancel();
    });

    test(
        'parcours corbeille complet : l\'id se retrouve via getAll(deletedOnly) '
        'et restore(id) rend l\'élément aux vivants', () async {
      // L'appelant ne connaît PAS l'id : il le retrouve par le listing
      // corbeille (c'est le point du CR — restore suppose un id qu'une
      // lecture doit pouvoir rendre).
      final trash = (await repo.getAll(
        request: const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
      ))
          .fold((f) => fail('Left inattendu : $f'), (l) => l);
      expect(trash.map((b) => b.name), <String>['corbeille-t']);
      final id = trash.single.id;
      expect(id, isNotNull, reason: 'le listing corbeille porte l\'identité');

      expect((await repo.restore(id!)).isRight(), isTrue);

      expect(_names(await repo.getAll()),
          <String>['corbeille-t', 'vivant-a', 'vivant-b'],
          reason: 'restauré : de retour dans aliveOnly');
      final after = await repo.getAll(
        request: const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
      );
      expect(_names(after), isEmpty, reason: 'la corbeille se vide');
    });

    test('count honore le scope (agrégat serveur)', () async {
      expect(
        (await repo.count(
          request:
              const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
        ))
            .fold((f) => fail('$f'), (n) => n),
        1,
      );
      expect(
        (await repo.count(
          request:
              const ZDataRequest(deletedScope: ZDeletedScope.includeDeleted),
        ))
            .fold((f) => fail('$f'), (n) => n),
        3,
      );
    });
  });

  group(
      'deletedScope — sémantique absentMeansAlive (filtrage client, '
      'legacyDeletedKey)', () {
    late FakeFirebaseFirestore fs;
    late FirebaseZRepositoryImpl<_Berth> repo;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      repo = _repo(
        fs,
        semantics: ZDeletionSemantics.absentMeansAlive,
        legacyDeletedKey: 'deleted',
      );
      await _seedZcrud(fs, 'a', 'vivant-a');
      await _seedZcrud(fs, 't', 'corbeille-t', isDeleted: true);
      await _seedLegacy(fs, 'l', 'legacy-vivant'); // aucun drapeau
      await _seedLegacy(fs, 'ld', 'legacy-corbeille',
          extra: <String, dynamic>{'deleted': true}); // clé camelCase legacy
      await _seedLegacy(fs, 'lf', 'legacy-vivant-2',
          extra: <String, dynamic>{'deleted': false});
    });

    tearDown(() => repo.dispose());

    test('aliveOnly : absent = vivant ; is_deleted==true ET deleted==true '
        'écartés', () async {
      expect(
        _names(await repo.getAll()),
        <String>['legacy-vivant', 'legacy-vivant-2', 'vivant-a'],
      );
    });

    test('deletedOnly : flag canonique true OU legacyDeletedKey true',
        () async {
      final r = await repo.getAll(
        request:
            const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
      );
      expect(_names(r), <String>['corbeille-t', 'legacy-corbeille'],
          reason: 'parité corbeille complète sur parc ancien (bonus Lot 2a)');
    });

    test('includeDeleted : TOUT le parc, drapeaux confondus', () async {
      final r = await repo.getAll(
        request:
            const ZDataRequest(deletedScope: ZDeletedScope.includeDeleted),
      );
      expect(_names(r), <String>[
        'corbeille-t',
        'legacy-corbeille',
        'legacy-vivant',
        'legacy-vivant-2',
        'vivant-a',
      ]);
    });

    test('watch honore aliveOnly (les supprimés legacy n\'apparaissent pas)',
        () async {
      final events = <List<_Berth>>[];
      final sub = repo.watch(const ZDataRequest()).listen(events.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events, isNotEmpty);
      expect(
        events.last.map((b) => b.name).toList()..sort(),
        <String>['legacy-vivant', 'legacy-vivant-2', 'vivant-a'],
      );
      await sub.cancel();
    });

    test('count : décompte CLIENT aligné sur le même prédicat que les listes',
        () async {
      expect(
        (await repo.count()).fold((f) => fail('$f'), (n) => n),
        3,
        reason: 'aliveOnly : 2 legacy vivants + 1 zcrud vivant',
      );
      expect(
        (await repo.count(
          request:
              const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
        ))
            .fold((f) => fail('$f'), (n) => n),
        2,
      );
    });

    test('getById : le supprimé legacy (deleted==true) est un Left soft-deleted',
        () async {
      final r = await repo.getById('ld');
      expect(
        r.fold((f) => f.message, (b) => fail('Right inattendu : $b')),
        'Entité soft-deleted',
      );
    });

    test(
        'parcours corbeille (flag canonique) : id retrouvé via '
        'getAll(deletedOnly), restore(id) rend l\'élément aux vivants',
        () async {
      final trash = (await repo.getAll(
        request: const ZDataRequest(deletedScope: ZDeletedScope.deletedOnly),
      ))
          .fold((f) => fail('Left inattendu : $f'), (l) => l);
      final t = trash.singleWhere((b) => b.name == 'corbeille-t');
      expect(t.id, isNotNull);

      expect((await repo.restore(t.id!)).isRight(), isTrue);

      expect(
        _names(await repo.getAll()),
        <String>['corbeille-t', 'legacy-vivant', 'legacy-vivant-2', 'vivant-a'],
        reason: 'restauré : de retour dans aliveOnly (getById redevient Right)',
      );
      expect(
        (await repo.getById(t.id!)).isRight(),
        isTrue,
        reason: 'l\'élément restauré est de nouveau lisible par id',
      );
    });

    test('auto-réparation à l\'écriture : save pose is_deleted:false '
        '(convergence vers strict)', () async {
      await repo.save(const _Berth(id: 'l', name: 'legacy-vivant'));
      final doc = await fs.collection(_kPath).doc('l').get();
      expect(doc.data()!['is_deleted'], false);
    });
  });

  group('garde d\'API additive', () {
    test('legacyDeletedKey en mode strict est REFUSÉE (assert debug)', () {
      expect(
        () => _repo(FakeFirebaseFirestore(), legacyDeletedKey: 'deleted'),
        throwsA(isA<AssertionError>()),
        reason: 'la clé serait ignorée silencieusement par les clauses '
            'serveur strictes — misconfiguration signalée',
      );
    });
  });
}
