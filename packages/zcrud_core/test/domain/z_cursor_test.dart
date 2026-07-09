// AC5 : `ZCursor` — curseur opaque neutre, égalité profonde sur `values`+`id`,
// construction sans aucune API backend (preuve de neutralité, AD-5/AD-16).
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZCursor — neutralité & construction (AC5)', () {
    test('construit à partir de valeurs opaques sans type backend', () {
      const cursor = ZCursor(values: <Object?>['2026-07-09', 42, null], id: 'abc');
      expect(cursor.values, ['2026-07-09', 42, null]);
      expect(cursor.id, 'abc');
    });

    test('id optionnel (repli in-memory par values seules)', () {
      const cursor = ZCursor(values: [1]);
      expect(cursor.id, isNull);
    });
  });

  group('ZCursor — égalité de valeur profonde (AC5)', () {
    test('values + id égaux ⇒ égal + hashCode identique', () {
      const a = ZCursor(values: [1, 'x'], id: 'k');
      const b = ZCursor(values: [1, 'x'], id: 'k');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('values différentes ⇒ inégal', () {
      expect(const ZCursor(values: [1]) == const ZCursor(values: [2]), isFalse);
    });

    test('id différent ⇒ inégal (values identiques)', () {
      expect(const ZCursor(values: [1], id: 'a') == const ZCursor(values: [1], id: 'b'),
          isFalse);
    });

    test('longueur de values différente ⇒ inégal', () {
      expect(const ZCursor(values: [1]) == const ZCursor(values: [1, 2]), isFalse);
    });
  });

  test('toString lisible (AC5)', () {
    expect(const ZCursor(values: [1], id: 'z').toString(),
        'ZCursor(values: [1], id: z)');
  });
}
