// AC2..AC6 (E4-3, AD-10/AD-16) : moteur in-memory NEUTRE `zApplyListRequest`
// (+ `zMatchesSearch`) — recherche sans accents sur `searchable` UNIQUEMENT,
// filtres par ZFilterOp (défensifs), tri multi-clés STABLE + direction,
// pagination curseur (`ZListPage`/`nextCursor`/`hasMore`) sur N pages, curseur
// invalide / ancre absente SANS crash. Pas d'import `zcrud_list` (SM-5).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

// `name` searchable, `city` NON searchable, `age` non searchable.
const _schema = <ZFieldSpec>[
  ZFieldSpec(name: 'name', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'city', type: EditionFieldType.text),
  ZFieldSpec(name: 'age', type: EditionFieldType.number),
];

ZListRow _row(String id, String name, int age, {String city = ''}) =>
    ZListRow(id: id, cells: <String, Object?>{
      'name': name,
      'age': age,
      'city': city,
    });

void main() {
  group('zMatchesSearch — recherche sans accents sur `searchable` (AC2)', () {
    test('terme vide/blanc → match tous', () {
      final r = _row('1', 'Café', 30);
      expect(zMatchesSearch(r, '', schema: _schema), isTrue);
      expect(zMatchesSearch(r, '   ', schema: _schema), isTrue);
    });

    test('« e » matche name == "Élève" (sans accents)', () {
      expect(zMatchesSearch(_row('1', 'Élève', 12), 'e', schema: _schema),
          isTrue);
    });

    test('« cafe » matche name == "Café"', () {
      expect(zMatchesSearch(_row('1', 'Café', 30), 'cafe', schema: _schema),
          isTrue);
    });

    test('une valeur présente UNIQUEMENT dans un champ non-searchable ne matche '
        'pas', () {
      // "Lyon" est dans `city` (non searchable) ; `name` ne contient pas "lyon".
      final r = _row('1', 'Bob', 30, city: 'Lyon');
      expect(zMatchesSearch(r, 'lyon', schema: _schema), isFalse);
    });
  });

  group('zApplyListRequest — filtres par ZFilterOp (AC3)', () {
    final rows = <ZListRow>[
      _row('1', 'Ann', 18, city: 'Paris'),
      _row('2', 'Bob', 30, city: 'Lyon'),
      _row('3', 'Cid', 40, city: 'Paris'),
      _row('4', 'Dan', 30, city: 'Nice'),
    ];

    List<String> ids(ZDataRequest req) =>
        zApplyListRequest(rows, req, schema: _schema)
            .rows
            .map((r) => r.id)
            .toList();

    test('eq / neq', () {
      expect(ids(const ZDataRequest(filters: [ZFilter('age', ZFilterOp.eq, 30)])),
          ['2', '4']);
      expect(
          ids(const ZDataRequest(filters: [ZFilter('age', ZFilterOp.neq, 30)])),
          ['1', '3']);
    });

    test('lt / lte / gt / gte', () {
      expect(ids(const ZDataRequest(filters: [ZFilter('age', ZFilterOp.lt, 30)])),
          ['1']);
      expect(
          ids(const ZDataRequest(filters: [ZFilter('age', ZFilterOp.lte, 30)])),
          ['1', '2', '4']);
      expect(ids(const ZDataRequest(filters: [ZFilter('age', ZFilterOp.gt, 30)])),
          ['3']);
      expect(
          ids(const ZDataRequest(filters: [ZFilter('age', ZFilterOp.gte, 30)])),
          ['2', '3', '4']);
    });

    test('contains (sous-chaîne repliée)', () {
      expect(
          ids(const ZDataRequest(
              filters: [ZFilter('city', ZFilterOp.contains, 'par')])),
          ['1', '3']);
    });

    test('isIn (appartenance à une liste)', () {
      expect(
          ids(const ZDataRequest(
              filters: [ZFilter('name', ZFilterOp.isIn, ['Ann', 'Cid'])])),
          ['1', '3']);
    });

    test('isNull', () {
      final withNull = <ZListRow>[
        const ZListRow(id: 'x', cells: {'name': 'X', 'age': null}),
        _row('y', 'Y', 20),
      ];
      final res = zApplyListRequest(
        withNull,
        const ZDataRequest(filters: [ZFilter('age', ZFilterOp.isNull)]),
        schema: _schema,
      );
      expect(res.rows.map((r) => r.id), ['x']);
    });

    test('contains à opérande null/vide → ne matche RIEN (L-4, pas de faux '
        'positif `contains("")`)', () {
      // Opérande null : sans la garde, `text.contains("")` matcherait TOUT.
      final resNull = zApplyListRequest(
        rows,
        const ZDataRequest(filters: [ZFilter('city', ZFilterOp.contains, null)]),
        schema: _schema,
      );
      expect(resNull.rows, isEmpty,
          reason: 'opérande null → filtre indéfini → aucun match');
      // Opérande chaîne vide : idem.
      final resEmpty = zApplyListRequest(
        rows,
        const ZDataRequest(filters: [ZFilter('city', ZFilterOp.contains, '')]),
        schema: _schema,
      );
      expect(resEmpty.rows, isEmpty);
      // Non-régression : un opérande non vide filtre toujours correctement.
      final resReal = zApplyListRequest(
        rows,
        const ZDataRequest(filters: [ZFilter('city', ZFilterOp.contains, 'par')]),
        schema: _schema,
      );
      expect(resReal.rows.map((r) => r.id), ['1', '3']);
    });

    test('comparaison sur type incompatible → 0 crash, ne matche pas (AD-10)',
        () {
      // `name` (String) comparé avec `< 30` (int) : pas de throw, exclusion.
      final res = zApplyListRequest(
        rows,
        const ZDataRequest(filters: [ZFilter('name', ZFilterOp.lt, 30)]),
        schema: _schema,
      );
      expect(res.rows, isEmpty);
    });
  });

  group('zApplyListRequest — tri multi-clés stable + direction (AC4)', () {
    test('age asc puis tie-break name asc', () {
      final rows = <ZListRow>[
        _row('1', 'B', 30),
        _row('2', 'A', 30),
        _row('3', 'C', 20),
      ];
      final res = zApplyListRequest(
        rows,
        const ZDataRequest(sorts: [ZSort('age'), ZSort('name')]),
        schema: _schema,
      );
      expect(res.rows.map((r) => r.cells['name']), ['C', 'A', 'B']);
    });

    test('age desc', () {
      final rows = <ZListRow>[
        _row('1', 'A', 20),
        _row('2', 'B', 40),
        _row('3', 'C', 30),
      ];
      final res = zApplyListRequest(
        rows,
        const ZDataRequest(sorts: [ZSort('age', ZSortDirection.desc)]),
        schema: _schema,
      );
      expect(res.rows.map((r) => r.cells['age']), [40, 30, 20]);
    });

    test('stabilité : lignes égales conservent l\'ordre d\'entrée', () {
      final rows = <ZListRow>[
        _row('1', 'same', 30),
        _row('2', 'same', 30),
        _row('3', 'same', 30),
      ];
      final res = zApplyListRequest(
        rows,
        const ZDataRequest(sorts: [ZSort('age')]),
        schema: _schema,
      );
      expect(res.rows.map((r) => r.id), ['1', '2', '3']);
    });
  });

  group('zApplyListRequest — pagination curseur (AC5)', () {
    List<ZListRow> mkRows() => <ZListRow>[
          for (var i = 0; i < 5; i++) _row('p$i', 'P$i', 20 + i),
        ];

    test('N=5, limit:2, age asc → 3 pages accumulées sans doublon ni trou', () {
      final rows = mkRows();
      const sorts = [ZSort('age')];

      final page1 = zApplyListRequest(
          rows, const ZDataRequest(sorts: sorts, limit: 2),
          schema: _schema);
      expect(page1.rows.map((r) => r.cells['age']), [20, 21]);
      expect(page1.hasMore, isTrue);
      expect(page1.nextCursor, isNotNull);

      final page2 = zApplyListRequest(
          rows,
          ZDataRequest(sorts: sorts, limit: 2, startAfter: page1.nextCursor),
          schema: _schema);
      expect(page2.rows.map((r) => r.cells['age']), [22, 23]);
      expect(page2.hasMore, isTrue);

      final page3 = zApplyListRequest(
          rows,
          ZDataRequest(sorts: sorts, limit: 2, startAfter: page2.nextCursor),
          schema: _schema);
      expect(page3.rows.map((r) => r.cells['age']), [24]);
      expect(page3.hasMore, isFalse);
      expect(page3.nextCursor, isNull);

      final accumulated = [...page1.rows, ...page2.rows, ...page3.rows];
      expect(accumulated.map((r) => r.id), ['p0', 'p1', 'p2', 'p3', 'p4']);
      expect(accumulated.map((r) => r.id).toSet().length, 5);
    });

    test('limit == null → tout, hasMore false, nextCursor null', () {
      final res = zApplyListRequest(
          mkRows(), const ZDataRequest(sorts: [ZSort('age')]),
          schema: _schema);
      expect(res.rows, hasLength(5));
      expect(res.hasMore, isFalse);
      expect(res.nextCursor, isNull);
    });
  });

  group('zApplyListRequest — curseur invalide / ancre absente (AC6, AD-16)', () {
    List<ZListRow> mkRows() => <ZListRow>[
          for (var i = 0; i < 5; i++) _row('p$i', 'P$i', 20 + i),
        ];

    test('ZCursor(values:[9999], id:absent) → page vide, 0 throw', () {
      final res = zApplyListRequest(
        mkRows(),
        const ZDataRequest(
          sorts: [ZSort('age')],
          startAfter: ZCursor(values: [9999], id: 'absent'),
        ),
        schema: _schema,
      );
      expect(res.rows, isEmpty);
      expect(res.hasMore, isFalse);
    });

    test('ancre introuvable mais values in-range → saut par values (id ignoré)',
        () {
      final res = zApplyListRequest(
        mkRows(),
        const ZDataRequest(
          sorts: [ZSort('age')],
          startAfter: ZCursor(values: [22], id: 'zzz-inexistant'),
        ),
        schema: _schema,
      );
      // ages > 22 → [23, 24] (pas de retour page 1, pas d'exception).
      expect(res.rows.map((r) => r.cells['age']), [23, 24]);
    });

    test('ZCursor(id:null) : saut piloté par values seules', () {
      final res = zApplyListRequest(
        mkRows(),
        const ZDataRequest(
          sorts: [ZSort('age')],
          limit: 2,
          startAfter: ZCursor(values: [21]),
        ),
        schema: _schema,
      );
      expect(res.rows.map((r) => r.cells['age']), [22, 23]);
    });
  });
}
