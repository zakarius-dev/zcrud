/// Tests de `applyOrder<T>` (ES-1.2, AC4) : tri stable + position déterministe
/// des ids absents ; générique de collection sans dépendance métier.
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

class _Item {
  const _Item(this.id, this.label);
  final String id;
  final String label;

  @override
  String toString() => 'Item($id,$label)';
}

String _idOf(_Item i) => i.id;

void main() {
  group('applyOrder<T> (AC4)', () {
    test('ordre complet -> items ressortent dans l\'ordre de order', () {
      final items = <_Item>[
        _Item('c', 'C'),
        _Item('a', 'A'),
        _Item('b', 'B'),
      ];
      final result = applyOrder(items, const ['a', 'b', 'c'], idOf: _idOf);
      expect(result.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('ordre partiel -> absents à la fin, ordre relatif préservé (défaut end)',
        () {
      final items = <_Item>[
        _Item('a', 'A'),
        _Item('x', 'X'),
        _Item('b', 'B'),
        _Item('y', 'Y'),
      ];
      final result = applyOrder(items, const ['b', 'a'], idOf: _idOf);
      // Ordonnés d'abord (b, a), puis non-ordonnés dans leur ordre d'entrée (x, y).
      expect(result.map((e) => e.id).toList(), ['b', 'a', 'x', 'y']);
    });

    test('option ZUnorderedPlacement.start -> absents en tête', () {
      final items = <_Item>[
        _Item('a', 'A'),
        _Item('x', 'X'),
        _Item('b', 'B'),
        _Item('y', 'Y'),
      ];
      final result = applyOrder(
        items,
        const ['b', 'a'],
        idOf: _idOf,
        unordered: ZUnorderedPlacement.start,
      );
      expect(result.map((e) => e.id).toList(), ['x', 'y', 'b', 'a']);
    });

    test('order vide -> ordre d\'entrée intégralement préservé', () {
      final items = <_Item>[
        _Item('c', 'C'),
        _Item('a', 'A'),
        _Item('b', 'B'),
      ];
      final result = applyOrder(items, const <String>[], idOf: _idOf);
      expect(result.map((e) => e.id).toList(), ['c', 'a', 'b']);
    });

    test('id de order inconnu (aucun item correspondant) -> ignoré', () {
      final items = <_Item>[_Item('a', 'A'), _Item('b', 'B')];
      final result = applyOrder(
        items,
        const ['zzz', 'b', 'yyy', 'a'],
        idOf: _idOf,
      );
      expect(result.map((e) => e.id).toList(), ['b', 'a']);
    });

    test('id dupliqué dans order -> la 1re occurrence fait foi', () {
      final items = <_Item>[
        _Item('a', 'A'),
        _Item('b', 'B'),
        _Item('c', 'C'),
      ];
      // 'a' apparaît en position 0 puis re-déclaré en position 2 : la 1re
      // occurrence (0) fait foi -> 'a' reste avant 'b'/'c'.
      final result = applyOrder(
        items,
        const ['a', 'b', 'c', 'a'],
        idOf: _idOf,
      );
      expect(result.map((e) => e.id).toList(), ['a', 'b', 'c']);
    });

    test('ids dupliqués dans items -> tous conservés, ordre relatif préservé',
        () {
      final items = <_Item>[
        _Item('a', 'A1'),
        _Item('a', 'A2'),
        _Item('b', 'B'),
      ];
      final result = applyOrder(items, const ['b', 'a'], idOf: _idOf);
      // Les deux 'a' sont ex-aequo sur la position -> stabilité : A1 avant A2.
      expect(result.map((e) => e.label).toList(), ['B', 'A1', 'A2']);
    });

    test('non-mutation : items et order restent inchangés', () {
      final items = <_Item>[_Item('b', 'B'), _Item('a', 'A')];
      final order = <String>['a', 'b'];
      final itemsSnapshot = List<_Item>.of(items);
      final orderSnapshot = List<String>.of(order);
      applyOrder(items, order, idOf: _idOf);
      expect(items.map((e) => e.id).toList(), itemsSnapshot.map((e) => e.id));
      expect(order, orderSnapshot);
    });

    test('retourne une NOUVELLE liste (pas la même référence que items)', () {
      final items = <_Item>[_Item('a', 'A')];
      final result = applyOrder(items, const <String>[], idOf: _idOf);
      expect(identical(result, items), isFalse);
    });

    test('stabilité : items totalement non-ordonnés préservent leur ordre',
        () {
      final items = <_Item>[
        _Item('a', 'A'),
        _Item('b', 'B'),
        _Item('c', 'C'),
        _Item('d', 'D'),
      ];
      final result = applyOrder(items, const <String>['x'], idOf: _idOf);
      expect(result.map((e) => e.id).toList(), ['a', 'b', 'c', 'd']);
    });

    test('générique sans dépendance métier : fonctionne sur des int', () {
      final result = applyOrder<int>(
        [3, 1, 2],
        const ['1', '2'],
        idOf: (i) => i.toString(),
      );
      expect(result, [1, 2, 3]);
    });
  });
}
