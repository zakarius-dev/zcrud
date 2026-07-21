// AC3/AC4/AC8 (E4-4, AD-2/AD-15/AD-11) : sélection multiple NEUTRE keyée par id.
//
// toggle/selectAll/clearSelection/selectRange/isSelected, modes single/none,
// émissions non modifiables, dispose no-op, suppression EN LOT (softDeleteSelected).
// Aucun Syncfusion : pur cœur (SM-5).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

class _FakeEntity extends ZEntity {
  const _FakeEntity(this._id);
  final String? _id;
  @override
  String? get id => _id;
}

/// Repo fake : softDelete réussit sauf pour les id de [failingIds].
class _FakeRepo implements ZRepository<_FakeEntity> {
  _FakeRepo({this.failingIds = const <String>{}});
  final Set<String> failingIds;
  final List<String> softDeleted = <String>[];

  @override
  Future<ZResult<Unit>> softDelete(String id) async {
    softDeleted.add(id);
    if (failingIds.contains(id)) {
      return Left<ZFailure, Unit>(ZServerFailure('fail-$id'));
    }
    return Right<ZFailure, Unit>(unit);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  test('AC3 : toggle accumule puis retire (multiple), émissions ciblées', () {
    final c = ZListSelectionController();
    final emissions = <Set<String>>[];
    c.selectedIds.addListener(() => emissions.add(c.selectedIds.value));

    c.toggle('a');
    c.toggle('b');
    expect(c.selectedIds.value, <String>{'a', 'b'});
    expect(emissions.length, 2);

    c.toggle('a');
    expect(c.selectedIds.value, <String>{'b'});
    expect(c.isSelected('b'), isTrue);
    expect(c.isSelected('a'), isFalse);
    expect(c.selectedCount, 1);
    c.dispose();
  });

  test('AC3 : émet des Set NON modifiables', () {
    final c = ZListSelectionController()..toggle('a');
    expect(() => c.selectedIds.value.add('x'), throwsUnsupportedError);
    c.dispose();
  });

  test('AC3 : selectAll (union) puis clearSelection', () {
    final c = ZListSelectionController()
      ..selectAll(<String>['a', 'b'])
      ..selectAll(<String>['b', 'c']);
    expect(c.selectedIds.value, <String>{'a', 'b', 'c'});
    c.clearSelection();
    expect(c.selectedIds.value, isEmpty);
    c.dispose();
  });

  test('AC3 : selectRange plage inclusive dans l\'ordre visuel', () {
    final order = <String>['a', 'b', 'c', 'd', 'e'];
    final c = ZListSelectionController()..selectRange(order, 'b', 'd');
    expect(c.selectedIds.value, <String>{'b', 'c', 'd'});
    // Anchor/target inversés → même plage.
    final c2 = ZListSelectionController()..selectRange(order, 'd', 'b');
    expect(c2.selectedIds.value, <String>{'b', 'c', 'd'});
    // Borne absente → no-op.
    final c3 = ZListSelectionController()..selectRange(order, 'z', 'd');
    expect(c3.selectedIds.value, isEmpty);
    c.dispose();
    c2.dispose();
    c3.dispose();
  });

  test('AC3 : mode single remplace (toggle/setSelection/selectAll)', () {
    final c = ZListSelectionController(mode: ZListSelectionMode.single);
    c.toggle('a');
    c.toggle('b');
    expect(c.selectedIds.value, <String>{'b'});
    c.toggle('b'); // re-toggle → désélection
    expect(c.selectedIds.value, isEmpty);
    c.selectAll(<String>['x', 'y']);
    expect(c.selectedIds.value.length, 1);
    c.dispose();
  });

  test('AC3 : mode none = no-op sur toutes les mutations', () {
    final c = ZListSelectionController(mode: ZListSelectionMode.none)
      ..toggle('a')
      ..selectAll(<String>['b', 'c'])
      ..selectRange(<String>['a', 'b'], 'a', 'b');
    expect(c.selectedIds.value, isEmpty);
    c.dispose();
  });

  test('AC3 : dispose → plus d\'émission', () {
    final c = ZListSelectionController()..toggle('a');
    var count = 0;
    c.selectedIds.addListener(() => count++);
    c.dispose();
    // Après dispose, toute mutation est un no-op (aucune émission).
    expect(() => c.toggle('b'), returnsNormally);
    expect(count, 0);
  });

  test('AC3 : initialSelection normalisée par mode', () {
    final m = ZListSelectionController(
      initialSelection: <String>['a', 'b'],
    );
    expect(m.selectedIds.value, <String>{'a', 'b'});
    final s = ZListSelectionController(
      mode: ZListSelectionMode.single,
      initialSelection: <String>['a', 'b'],
    );
    expect(s.selectedIds.value.length, 1);
    m.dispose();
    s.dispose();
  });

  test('AC6/AC8 : softDeleteSelected best-effort — succès retire, échec reste',
      () async {
    final repo = _FakeRepo(failingIds: <String>{'b'});
    final c = ZListSelectionController()..selectAll(<String>['a', 'b', 'c']);
    final failures = <ZFailure>[];
    var success = false;
    await c.softDeleteSelected(
      repo,
      onFailure: failures.add,
      onSuccess: () => success = true,
    );
    expect(repo.softDeleted.toSet(), <String>{'a', 'b', 'c'});
    // 'a' et 'c' retirés (succès) ; 'b' reste (échec).
    expect(c.selectedIds.value, <String>{'b'});
    expect(failures.length, 1);
    expect(success, isFalse);
    c.dispose();
  });

  test('AC6 : softDeleteSelected — tout réussit → onSuccess, sélection vidée',
      () async {
    final repo = _FakeRepo();
    final c = ZListSelectionController()..selectAll(<String>['a', 'b']);
    var success = false;
    await c.softDeleteSelected(repo, onSuccess: () => success = true);
    expect(c.selectedIds.value, isEmpty);
    expect(success, isTrue);
    c.dispose();
  });
}
