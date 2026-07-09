// AC2/AC4 : `ZDataRequest`/`ZFilter`/`ZSort` — value objects neutres immuables,
// égalité de valeur profonde, `copyWith` avec reset-null par sentinelle.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZDataRequest — défauts & immuabilité (AC4)', () {
    test('constructeur par défaut : tout vide/null (« tout, non paginé »)', () {
      const req = ZDataRequest();
      expect(req.filters, isEmpty);
      expect(req.sorts, isEmpty);
      expect(req.search, isNull);
      expect(req.limit, isNull);
      expect(req.startAfter, isNull);
    });
  });

  group('ZDataRequest — égalité de valeur profonde (AC4)', () {
    test('filtres/sorts identiques ⇒ égal + hashCode identique', () {
      const a = ZDataRequest(
        filters: [ZFilter('age', ZFilterOp.gte, 18)],
        sorts: [ZSort('name')],
        search: 'x',
        limit: 10,
      );
      const b = ZDataRequest(
        filters: [ZFilter('age', ZFilterOp.gte, 18)],
        sorts: [ZSort('name')],
        search: 'x',
        limit: 10,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('un filtre différent ⇒ inégal', () {
      const a = ZDataRequest(filters: [ZFilter('age', ZFilterOp.gte, 18)]);
      const b = ZDataRequest(filters: [ZFilter('age', ZFilterOp.gte, 21)]);
      expect(a == b, isFalse);
    });

    test('un sort différent ⇒ inégal', () {
      const a = ZDataRequest(sorts: [ZSort('name')]);
      const b = ZDataRequest(sorts: [ZSort('name', ZSortDirection.desc)]);
      expect(a == b, isFalse);
    });

    test('startAfter (curseur) participe à l égalité', () {
      const a = ZDataRequest(startAfter: ZCursor(values: [1], id: 'a'));
      const b = ZDataRequest(startAfter: ZCursor(values: [1], id: 'a'));
      const c = ZDataRequest(startAfter: ZCursor(values: [2], id: 'a'));
      expect(a, equals(b));
      expect(a == c, isFalse);
    });
  });

  group('ZDataRequest.copyWith — conserve/écrase/reset-null (AC4)', () {
    const base = ZDataRequest(
      filters: [ZFilter('k', ZFilterOp.eq, 1)],
      sorts: [ZSort('s')],
      search: 'hello',
      limit: 5,
      startAfter: ZCursor(values: [1], id: 'z'),
    );

    test('omission conserve les valeurs', () {
      final same = base.copyWith();
      expect(same, equals(base));
    });

    test('écrase un champ ciblé', () {
      final r = base.copyWith(limit: 20);
      expect(r.limit, 20);
      expect(r.search, 'hello'); // inchangé
    });

    test('reset-null explicite via sentinelle (search/limit/startAfter)', () {
      final r = base.copyWith(search: null, limit: null, startAfter: null);
      expect(r.search, isNull);
      expect(r.limit, isNull);
      expect(r.startAfter, isNull);
      expect(r.filters, equals(base.filters)); // non touché
    });
  });

  group('ZFilter / ZSort — égalité de valeur + enums (AC4)', () {
    test('ZFilter égal par (field, op, value)', () {
      expect(const ZFilter('a', ZFilterOp.eq, 1),
          equals(const ZFilter('a', ZFilterOp.eq, 1)));
      expect(const ZFilter('a', ZFilterOp.eq, 1) == const ZFilter('a', ZFilterOp.neq, 1),
          isFalse);
    });

    test('ZFilter isIn : valeur liste comparée en profondeur', () {
      expect(const ZFilter('a', ZFilterOp.isIn, [1, 2, 3]),
          equals(const ZFilter('a', ZFilterOp.isIn, [1, 2, 3])));
      expect(
          const ZFilter('a', ZFilterOp.isIn, [1, 2]) ==
              const ZFilter('a', ZFilterOp.isIn, [1, 3]),
          isFalse);
    });

    test('ZSort direction par défaut = asc', () {
      expect(const ZSort('n').direction, ZSortDirection.asc);
    });

    test('ZFilterOp couvre les 9 opérateurs canoniques', () {
      expect(ZFilterOp.values, hasLength(9));
      expect(ZFilterOp.values, contains(ZFilterOp.isIn));
      expect(ZFilterOp.values, contains(ZFilterOp.isNull));
    });

    test('ZSortDirection : asc/desc', () {
      expect(ZSortDirection.values, equals([ZSortDirection.asc, ZSortDirection.desc]));
    });
  });
}
