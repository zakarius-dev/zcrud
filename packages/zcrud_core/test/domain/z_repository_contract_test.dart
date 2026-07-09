// AC3/AC9 : preuve que `ZRepository<T>` est implémentable en **pur-Dart** sans
// aucun backend. `_InMemoryZRepository` implémente l'INTÉGRALITÉ du contrat :
// matérialisation de l'éphémère, soft-delete/restore, flux NUS re-broadcastés,
// count filtré, et **pagination curseur par repli in-memory** (AD-16).
import 'dart:async';

import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Entité de test immuable (id nullable → éphémère tant que non matérialisée).
class _Person implements ZEntity {
  const _Person({this.id, required this.name, required this.age});

  @override
  final String? id;
  final String name;
  final int age;

  @override
  bool get isEphemeral => id == null;

  _Person withId(String newId) => _Person(id: newId, name: name, age: age);
}

/// Repository en mémoire — implémente TOUT `ZRepository<_Person>` en pur-Dart.
class _InMemoryZRepository implements ZRepository<_Person> {
  final Map<String, _Person> _store = <String, _Person>{};
  final Set<String> _deleted = <String>{};
  final StreamController<List<_Person>> _changes =
      StreamController<List<_Person>>.broadcast();
  int _seq = 0;

  List<_Person> _live() => _store.values
      .where((p) => !_deleted.contains(p.id))
      .toList(growable: false);

  void _emit() => _changes.add(_live());

  Object? _fieldOf(_Person p, String field) {
    switch (field) {
      case 'id':
        return p.id;
      case 'name':
        return p.name;
      case 'age':
        return p.age;
      default:
        return null;
    }
  }

  bool _matches(_Person p, ZFilter f) {
    final v = _fieldOf(p, f.field);
    switch (f.op) {
      case ZFilterOp.eq:
        return v == f.value;
      case ZFilterOp.neq:
        return v != f.value;
      case ZFilterOp.lt:
        return (v as Comparable).compareTo(f.value) < 0;
      case ZFilterOp.lte:
        return (v as Comparable).compareTo(f.value) <= 0;
      case ZFilterOp.gt:
        return (v as Comparable).compareTo(f.value) > 0;
      case ZFilterOp.gte:
        return (v as Comparable).compareTo(f.value) >= 0;
      case ZFilterOp.contains:
        return '$v'.contains('${f.value}');
      case ZFilterOp.isIn:
        return (f.value as List).contains(v);
      case ZFilterOp.isNull:
        return v == null;
    }
  }

  List<_Person> _applyRequest(ZDataRequest? request) {
    var rows = _live();
    if (request == null) return rows;

    // Filtres (conjonction).
    for (final f in request.filters) {
      rows = rows.where((p) => _matches(p, f)).toList();
    }
    // Recherche plein-texte simple sur `name`.
    final s = request.search;
    if (s != null) {
      rows = rows.where((p) => p.name.contains(s)).toList();
    }
    // Tri multi-clés.
    if (request.sorts.isNotEmpty) {
      rows.sort((a, b) {
        for (final sort in request.sorts) {
          final av = _fieldOf(a, sort.field) as Comparable;
          final bv = _fieldOf(b, sort.field) as Comparable;
          final c = av.compareTo(bv);
          if (c != 0) {
            return sort.direction == ZSortDirection.asc ? c : -c;
          }
        }
        return 0;
      });
    }
    // Repli in-memory du curseur (AD-16) : saute toutes les lignes situées
    // AVANT l'ancre dans l'ordre courant, en comparant les VALEURS des clés
    // d'ordre (`request.sorts`) — `id` ne sert que de départage à valeurs
    // d'ordre égales. Le saut ne dépend donc PAS de la présence de `cursor.id`
    // (cas `ZCursor(id: null)` légitime : pagination pilotée par `values`).
    // Un curseur invalide (ancre inexistante) ne plante jamais : il définit
    // simplement une position d'ordre (page vide si au-delà de la fin, départ
    // complet si avant le début).
    final cursor = request.startAfter;
    if (cursor != null) {
      if (request.sorts.isEmpty) {
        // Sans clé d'ordre, seul `id` peut ancrer (repli dégénéré, page 1 si
        // l'ancre est introuvable).
        final anchor = rows.indexWhere((p) => p.id == cursor.id);
        rows = anchor >= 0 ? rows.sublist(anchor + 1) : rows;
      } else {
        rows = rows
            .where((p) => _compareToAnchor(p, cursor, request.sorts) > 0)
            .toList();
      }
    }
    // Pagination.
    final limit = request.limit;
    if (limit != null && rows.length > limit) {
      rows = rows.sublist(0, limit);
    }
    return rows;
  }

  /// Compare `p` à l'ancre du curseur selon l'ordre `sorts` (départage `id`).
  ///
  /// Renvoie `> 0` si `p` est **strictement après** l'ancre (donc conservé en
  /// page suivante), `< 0` si avant, `0` si `p` EST l'ancre. Compare
  /// positionnellement `cursor.values` aux valeurs des clés d'ordre de `p`
  /// (dans le sens de tri), puis départage par `id` à valeurs égales.
  int _compareToAnchor(_Person p, ZCursor cursor, List<ZSort> sorts) {
    final n =
        sorts.length < cursor.values.length ? sorts.length : cursor.values.length;
    for (var i = 0; i < n; i++) {
      final sort = sorts[i];
      final pv = _fieldOf(p, sort.field) as Comparable;
      final cv = cursor.values[i] as Comparable;
      var c = pv.compareTo(cv);
      if (sort.direction == ZSortDirection.desc) c = -c;
      if (c != 0) return c;
    }
    // Égalité sur toutes les clés d'ordre → départage par `id` stable.
    final pid = p.id;
    final cid = cursor.id;
    if (pid != null && cid != null) return pid.compareTo(cid);
    // `id` absent d'un côté : l'ancre est traitée comme exacte (non après).
    return 0;
  }

  @override
  Stream<List<_Person>> watchAll() async* {
    yield _live();
    yield* _changes.stream;
  }

  @override
  Stream<List<_Person>> watch(ZDataRequest request) async* {
    yield _applyRequest(request);
    yield* _changes.stream.map((_) => _applyRequest(request));
  }

  @override
  Future<ZResult<List<_Person>>> getAll({ZDataRequest? request}) async =>
      Right(_applyRequest(request));

  @override
  Future<ZResult<_Person>> getById(String id) async {
    final p = _store[id];
    if (p == null || _deleted.contains(id)) {
      return Left(NotFoundFailure('introuvable', id: id, entity: 'Person'));
    }
    return Right(p);
  }

  @override
  Future<ZResult<_Person>> save(_Person item, {String? collectionId}) async {
    final id = item.id ?? 'p${++_seq}'; // matérialise l'éphémère (AD-14)
    final stored = item.isEphemeral ? item.withId(id) : item;
    _store[id] = stored;
    _deleted.remove(id);
    _emit();
    return Right(stored);
  }

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    if (!_store.containsKey(id)) {
      return Left(NotFoundFailure('introuvable', id: id));
    }
    _deleted.add(id);
    _emit();
    return Right(unit);
  }

  @override
  Future<ZResult<Unit>> restore(String id) async {
    _deleted.remove(id);
    _emit();
    return Right(unit);
  }

  @override
  Future<ZResult<int>> count({ZDataRequest? request}) async =>
      Right(_applyRequest(request).length);

  @override
  void dispose() => _changes.close();
}

void main() {
  late _InMemoryZRepository repo;
  setUp(() => repo = _InMemoryZRepository());
  tearDown(() => repo.dispose());

  test('save matérialise l éphémère : id null → id non-null (AC3/AD-14)', () async {
    const ephemeral = _Person(name: 'Ada', age: 36);
    expect(ephemeral.isEphemeral, isTrue);
    final res = await repo.save(ephemeral);
    final saved = res.getOrElse(() => throw StateError('left'));
    expect(saved.id, isNotNull);
    expect(saved.isEphemeral, isFalse);
    expect(saved.name, 'Ada');
  });

  test('getById après softDelete → Left(NotFoundFailure) (AC3)', () async {
    final saved =
        (await repo.save(const _Person(name: 'Bob', age: 40))).getOrElse(() => throw StateError('left'));
    final id = saved.id!;
    expect((await repo.getById(id)).isRight(), isTrue);

    await repo.softDelete(id);
    final res = await repo.getById(id);
    expect(res.isLeft(), isTrue);
    res.fold((f) => expect(f, isA<NotFoundFailure>()), (_) => fail('attendu Left'));

    // getAll exclut le soft-deleted.
    final all = (await repo.getAll()).getOrElse(() => []);
    expect(all.any((p) => p.id == id), isFalse);
  });

  test('restore réinclut l entité dans getAll (AC3)', () async {
    final saved =
        (await repo.save(const _Person(name: 'Cid', age: 22))).getOrElse(() => throw StateError('left'));
    final id = saved.id!;
    await repo.softDelete(id);
    await repo.restore(id);
    final all = (await repo.getAll()).getOrElse(() => []);
    expect(all.any((p) => p.id == id), isTrue);
  });

  test('watchAll renvoie un Stream<List<T>> NU et émet à chaque mutation (AC3/AD-11)',
      () async {
    // Typage NU : jamais Either (preuve AD-11 à la compilation).
    final Stream<List<_Person>> stream = repo.watchAll();
    final emissions = <List<_Person>>[];
    final sub = stream.listen(emissions.add);
    // Laisse le seed initial être émis et l'abonnement interne s'établir.
    await Future<void>.delayed(Duration.zero);
    await repo.save(const _Person(name: 'Dot', age: 10));
    await Future<void>.delayed(Duration.zero);
    await repo.save(const _Person(name: 'Eve', age: 20));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(emissions.first, isEmpty); // seed initial
    expect(emissions[1], hasLength(1));
    expect(emissions[2], hasLength(2));
  });

  test('count respecte le ZDataRequest (filtre) (AC3)', () async {
    await repo.save(const _Person(name: 'A', age: 18));
    await repo.save(const _Person(name: 'B', age: 30));
    await repo.save(const _Person(name: 'C', age: 40));
    final total = (await repo.count()).getOrElse(() => -1);
    expect(total, 3);
    final adults = (await repo.count(
            request: const ZDataRequest(filters: [ZFilter('age', ZFilterOp.gte, 30)])))
        .getOrElse(() => -1);
    expect(adults, 2);
  });

  test('pagination curseur par repli in-memory : page1 puis page2 (AC5/AC9)',
      () async {
    // Insère 5 personnes d'âges distincts.
    for (var i = 0; i < 5; i++) {
      await repo.save(_Person(name: 'P$i', age: 20 + i));
    }
    const sorts = [ZSort('age')];

    final page1 = (await repo.getAll(
            request: const ZDataRequest(sorts: sorts, limit: 2)))
        .getOrElse(() => []);
    expect(page1.map((p) => p.age), [20, 21]);

    // Consommateur : construit le curseur depuis le dernier élément (repli in-memory).
    final last = page1.last;
    final cursor = ZCursor(values: [last.age], id: last.id);

    final page2 = (await repo.getAll(
            request: ZDataRequest(sorts: sorts, limit: 2, startAfter: cursor)))
        .getOrElse(() => []);
    expect(page2.map((p) => p.age), [22, 23]);
  });

  // ── M1 — watch(ZDataRequest) exercé (filtre + tri sur le flux NU) ──────────
  test('watch(request) émet la liste FILTRÉE+TRIÉE à chaque mutation (AC9/M1)',
      () async {
    // Flux NU dérivé : filtre age>=18 + tri age asc — distinct de watchAll.
    const request = ZDataRequest(
      filters: [ZFilter('age', ZFilterOp.gte, 18)],
      sorts: [ZSort('age')],
    );
    final Stream<List<_Person>> stream = repo.watch(request); // typage NU
    final emissions = <List<_Person>>[];
    final sub = stream.listen(emissions.add);
    await Future<void>.delayed(Duration.zero); // seed
    await repo.save(const _Person(name: 'Kid', age: 10)); // filtré (age<18)
    await Future<void>.delayed(Duration.zero);
    await repo.save(const _Person(name: 'Old', age: 40));
    await Future<void>.delayed(Duration.zero);
    await repo.save(const _Person(name: 'Mid', age: 25));
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(emissions.first, isEmpty); // seed initial vide
    expect(emissions[1], isEmpty); // Kid (10) filtré → toujours vide
    expect(emissions[2].map((p) => p.age), [40]); // Old passe le filtre
    // Mid (25) inséré → réémission triée [25, 40] (filtre + tri appliqués).
    expect(emissions.last.map((p) => p.age), [25, 40]);
  });

  // ── M2 — repli curseur par `values` (id null) + départage par id ──────────
  test('pagination par values avec ZCursor(id: null) (M2)', () async {
    for (var i = 0; i < 5; i++) {
      await repo.save(_Person(name: 'P$i', age: 20 + i));
    }
    const sorts = [ZSort('age')];
    // Curseur SANS id : le saut doit se faire par `values` seules.
    const cursor = ZCursor(values: [21], id: null);
    final page = (await repo.getAll(
            request: const ZDataRequest(sorts: sorts, limit: 2, startAfter: cursor)))
        .getOrElse(() => []);
    // Saut par values : ages > 21 → [22, 23] (aucun retour à la page 1).
    expect(page.map((p) => p.age), [22, 23]);
  });

  test('départage par id à valeurs d ordre égales (M2)', () async {
    // 5 personnes de MÊME âge : seul `id` peut départager l'ancre.
    final ids = <String>[];
    for (var i = 0; i < 5; i++) {
      final saved = (await repo.save(const _Person(name: 'Same', age: 30)))
          .getOrElse(() => throw StateError('left'));
      ids.add(saved.id!);
    }
    ids.sort();
    final anchorId = ids[1]; // 2e id → on attend les ids strictement supérieurs
    final cursor = ZCursor(values: const [30], id: anchorId);
    final rest = (await repo.getAll(
            request: ZDataRequest(sorts: const [ZSort('age')], startAfter: cursor)))
        .getOrElse(() => []);
    // Valeurs d'ordre égales (age=30 partout) → départage par id : id > anchorId.
    expect(
      rest.map((p) => p.id).toSet(),
      ids.where((id) => id.compareTo(anchorId) > 0).toSet(),
    );
  });

  // ── M3 — branches non couvertes ───────────────────────────────────────────
  test('tri multi-clés : tie-break sur la 2e clé quand la 1re est égale (M3)',
      () async {
    await repo.save(const _Person(name: 'B', age: 30));
    await repo.save(const _Person(name: 'A', age: 30)); // age égal à B
    await repo.save(const _Person(name: 'C', age: 20));
    const request = ZDataRequest(sorts: [ZSort('age'), ZSort('name')]);
    final rows = (await repo.getAll(request: request)).getOrElse(() => []);
    // age asc puis name asc : C(20), A(30), B(30) — le tie-break age==0 → name.
    expect(rows.map((p) => p.name), ['C', 'A', 'B']);
  });

  test('curseur invalide (id inexistant) : pas de crash, saut par values (M3)',
      () async {
    for (var i = 0; i < 5; i++) {
      await repo.save(_Person(name: 'P$i', age: 20 + i)); // ages 20..24
    }
    // id qui ne correspond à AUCUNE ancre (et trie après tous les ids réels
    // 'p1'..'p5') ; le saut reste piloté par `values`, sans exception.
    const cursor = ZCursor(values: [22], id: 'zzz-inexistant');
    final page = (await repo.getAll(
            request: const ZDataRequest(sorts: [ZSort('age')], startAfter: cursor)))
        .getOrElse(() => []);
    // Comportement défini : ages > 22 → [23, 24] (pas d'exception, pas de page 1).
    expect(page.map((p) => p.age), [23, 24]);
  });

  test('pagination au-delà de la fin → liste vide, pas d erreur (M3)', () async {
    for (var i = 0; i < 3; i++) {
      await repo.save(_Person(name: 'P$i', age: 20 + i)); // ages 20,21,22
    }
    const sorts = [ZSort('age')];
    final all = (await repo.getAll(request: const ZDataRequest(sorts: sorts)))
        .getOrElse(() => []);
    final last = all.last; // age 22 (dernier)
    final cursor = ZCursor(values: [last.age], id: last.id);
    final beyond = (await repo.getAll(
            request: ZDataRequest(sorts: sorts, limit: 2, startAfter: cursor)))
        .getOrElse(() => [const _Person(name: 'sentinel', age: -1)]);
    expect(beyond, isEmpty); // au-delà de la fin → vide, aucun crash
  });
}
