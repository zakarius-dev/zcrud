// AC4 (E4-2) : `ZListRenderRequest` porte des colonnes DÉRIVÉES (`ZListColumn`)
// + fabrique `fromSchema`, avec égalité de VALEUR profonde préservée.
// `ZListRow`/`ZListRenderRequest` sont Material-free et sans dépendance lourde —
// aucun import `zcrud_list`/Syncfusion ici (pilier SM-5).
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZListRow — égalité de valeur', () {
    test('deux lignes de même id + mêmes cellules sont égales', () {
      const a = ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30});
      const b = ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('ordre des clés de cells indifférent (hash commutatif)', () {
      const a = ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30});
      const b = ZListRow(id: '1', cells: {'age': 30, 'name': 'Alice'});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('id différent ⇒ inégal', () {
      const a = ZListRow(id: '1', cells: {'name': 'Alice'});
      const b = ZListRow(id: '2', cells: {'name': 'Alice'});
      expect(a, isNot(equals(b)));
    });

    test('valeur de cellule différente ⇒ inégal', () {
      const a = ZListRow(id: '1', cells: {'name': 'Alice'});
      const b = ZListRow(id: '1', cells: {'name': 'Bob'});
      expect(a, isNot(equals(b)));
    });
  });

  group('ZListRenderRequest.fromSchema — dérivation (AC4)', () {
    const fields = [
      ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
      ZFieldSpec(name: 'age', type: EditionFieldType.number),
      ZFieldSpec(name: 'doc', type: EditionFieldType.document),
    ];
    const rows = [
      ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
    ];

    test('fromSchema dérive les colonnes (isId + lourds exclus, ordre)', () {
      final req = ZListRenderRequest.fromSchema(fields, rows);
      // `id` (isId) et `doc` (document, lourd) exclus ; name+age gardés.
      expect(req.columns.map((c) => c.name), equals(['name', 'age']));
      expect(req.columns.first.header, equals('Nom'));
      expect(req.columns[1].header, equals('age'));
      expect(req.rows, equals(rows));
    });

    test('fromSchema == deriveColumns direct', () {
      final req = ZListRenderRequest.fromSchema(fields, rows);
      expect(req.columns, equals(deriveColumns(fields)));
    });

    test('policy forceInclude ramène un champ lourd (AD-4)', () {
      final req = ZListRenderRequest.fromSchema(
        fields,
        rows,
        policy: const ZColumnPolicy(forceInclude: {'doc'}),
      );
      expect(req.columns.map((c) => c.name), contains('doc'));
    });
  });

  group('ZListRenderRequest — égalité de valeur profonde (AC4)', () {
    const fields = [
      ZFieldSpec(name: 'name', type: EditionFieldType.text),
      ZFieldSpec(name: 'age', type: EditionFieldType.number),
    ];
    const rows = [
      ZListRow(id: '1', cells: {'name': 'Alice', 'age': 30}),
      ZListRow(id: '2', cells: {'name': 'Bob', 'age': 25}),
    ];

    test('mêmes colonnes dérivées + mêmes lignes ⇒ égal', () {
      final a = ZListRenderRequest.fromSchema(fields, rows);
      final b = ZListRenderRequest.fromSchema(fields, rows);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('lignes différentes ⇒ inégal', () {
      final a = ZListRenderRequest.fromSchema(fields, rows);
      final b = ZListRenderRequest.fromSchema(
        fields,
        const [ZListRow(id: '9', cells: {'name': 'Zed', 'age': 99})],
      );
      expect(a, isNot(equals(b)));
    });

    test('colonnes différentes ⇒ inégal', () {
      final a = ZListRenderRequest.fromSchema(fields, rows);
      final b = ZListRenderRequest.fromSchema(
        const [ZFieldSpec(name: 'name', type: EditionFieldType.text)],
        rows,
      );
      expect(a, isNot(equals(b)));
    });
  });
}
