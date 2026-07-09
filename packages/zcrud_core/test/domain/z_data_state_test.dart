// AC6 : `ZDataState<T>` sealed — ensemble fermé de 4 états ; un switch exhaustif
// COMPILE sans branche `default` (preuve `sealed`). `ZDataError` porte un `ZFailure`.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Réduit un `ZDataState` en libellé via un `switch` **exhaustif SANS `default`**.
///
/// Si `ZDataState` n'était pas `sealed`, ce switch ne compilerait pas sans
/// branche par défaut : sa seule compilation prouve AC6.
String _label<T>(ZDataState<T> state) {
  switch (state) {
    case ZDataLoading<T>():
      return 'loading';
    case ZDataLoaded<T>():
      return 'loaded';
    case ZDataEmpty<T>():
      return 'empty';
    case ZDataError<T>():
      return 'error';
  }
}

void main() {
  group('ZDataState — switch exhaustif (sealed, AC6)', () {
    test('les 4 variants sont couverts sans default', () {
      expect(_label<int>(const ZDataLoading()), 'loading');
      expect(_label<int>(const ZDataLoaded(items: [1])), 'loaded');
      expect(_label<int>(const ZDataEmpty()), 'empty');
      expect(_label<int>(const ZDataError(DomainFailure('boom'))), 'error');
    });

    test('ZDataEmpty est distinct de ZDataLoading', () {
      const ZDataState<int> empty = ZDataEmpty();
      const ZDataState<int> loading = ZDataLoading();
      expect(empty, isNot(equals(loading)));
      expect(empty.runtimeType, isNot(loading.runtimeType));
    });
  });

  group('ZDataLoaded — items/hasMore/nextCursor (AC6)', () {
    test('porte items, hasMore et nextCursor', () {
      const state = ZDataLoaded<int>(
        items: [1, 2, 3],
        hasMore: true,
        nextCursor: ZCursor(values: [3], id: 'c3'),
      );
      expect(state.items, [1, 2, 3]);
      expect(state.hasMore, isTrue);
      expect(state.nextCursor, const ZCursor(values: [3], id: 'c3'));
    });

    test('hasMore par défaut = false', () {
      const state = ZDataLoaded<int>(items: [1]);
      expect(state.hasMore, isFalse);
      expect(state.nextCursor, isNull);
    });

    test('égalité de valeur profonde sur items', () {
      expect(const ZDataLoaded<int>(items: [1, 2]),
          equals(const ZDataLoaded<int>(items: [1, 2])));
      expect(const ZDataLoaded<int>(items: [1, 2]) == const ZDataLoaded<int>(items: [1, 3]),
          isFalse);
    });
  });

  group('ZDataError — porte un ZFailure (AC6)', () {
    test('failure exposée et typée ZFailure', () {
      const state = ZDataError<int>(NotFoundFailure('x', id: '1'));
      expect(state.failure, isA<ZFailure>());
      expect(state.failure, const NotFoundFailure('x', id: '1'));
    });

    test('égalité par failure', () {
      expect(const ZDataError<int>(DomainFailure('e')),
          equals(const ZDataError<int>(DomainFailure('e'))));
      expect(
          const ZDataError<int>(DomainFailure('a')) ==
              const ZDataError<int>(DomainFailure('b')),
          isFalse);
    });
  });
}
