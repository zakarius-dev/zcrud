// AC1/AC2/AC3 (E4-2) : dérivation PURE `schéma → colonnes`. Tests UNIT purs
// (aucun widget, aucun BuildContext) : visibilité (isId + types lourds exclus,
// scalaires inclus, ordre stable), format par `EditionFieldType`, `ZColumnPolicy`
// include/exclude, égalité de valeur `ZListColumn`. Aucun import Flutter/Syncfusion.
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('deriveColumns — visibilité (AC3)', () {
    test('exclut isId + types lourds/non-tabulaires ; inclut les scalaires', () {
      const schema = [
        ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
        ZFieldSpec(name: 'title', type: EditionFieldType.text),
        ZFieldSpec(name: 'body', type: EditionFieldType.multiline),
        ZFieldSpec(name: 'count', type: EditionFieldType.integer),
        ZFieldSpec(name: 'ratio', type: EditionFieldType.float),
        ZFieldSpec(name: 'active', type: EditionFieldType.boolean),
        ZFieldSpec(name: 'when', type: EditionFieldType.dateTime),
        ZFieldSpec(name: 'hour', type: EditionFieldType.time),
        ZFieldSpec(name: 'kind', type: EditionFieldType.select),
        ZFieldSpec(name: 'flag', type: EditionFieldType.radio),
        ZFieldSpec(name: 'checks', type: EditionFieldType.checkbox),
        ZFieldSpec(name: 'labels', type: EditionFieldType.tags),
        ZFieldSpec(name: 'chips', type: EditionFieldType.rowChips),
        ZFieldSpec(name: 'nation', type: EditionFieldType.country),
        ZFieldSpec(name: 'phone', type: EditionFieldType.phoneNumber),
        ZFieldSpec(name: 'stars', type: EditionFieldType.rating),
        ZFieldSpec(name: 'level', type: EditionFieldType.slider),
        ZFieldSpec(name: 'hue', type: EditionFieldType.color),
        // Lourds / non-tabulaires → exclus.
        ZFieldSpec(name: 'kids', type: EditionFieldType.subItems),
        ZFieldSpec(name: 'deep', type: EditionFieldType.dynamicItem),
        ZFieldSpec(name: 'f', type: EditionFieldType.file),
        ZFieldSpec(name: 'img', type: EditionFieldType.image),
        ZFieldSpec(name: 'doc', type: EditionFieldType.document),
        ZFieldSpec(name: 'loc', type: EditionFieldType.location),
        ZFieldSpec(name: 'area', type: EditionFieldType.geoArea),
        ZFieldSpec(name: 'addr', type: EditionFieldType.address),
        ZFieldSpec(name: 'sig', type: EditionFieldType.signature),
        // Autres non-whitelistés → exclus par défaut.
        ZFieldSpec(name: 'secret', type: EditionFieldType.hidden),
        ZFieldSpec(name: 'md', type: EditionFieldType.markdown),
        ZFieldSpec(name: 'rel', type: EditionFieldType.relation),
      ];
      final columns = deriveColumns(schema);
      final names = columns.map((c) => c.name).toList();
      expect(
        names,
        equals([
          'title', 'body', 'count', 'ratio', 'active', 'when', 'hour', 'kind',
          'flag', 'checks', 'labels', 'chips', 'nation', 'phone', 'stars',
          'level', 'hue',
        ]),
      );
      // isId + lourds + non-whitelistés absents.
      for (final excluded in <String>[
        'id', 'kids', 'deep', 'f', 'img', 'doc', 'loc', 'area', 'addr', 'sig',
        'secret', 'md', 'rel',
      ]) {
        expect(names, isNot(contains(excluded)), reason: '$excluded exclu');
      }
    });

    test('ordre = index d\'origine dans le schéma (stable malgré filtrage)', () {
      const schema = [
        ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
        ZFieldSpec(name: 'a', type: EditionFieldType.text),
        ZFieldSpec(name: 'doc', type: EditionFieldType.document),
        ZFieldSpec(name: 'b', type: EditionFieldType.number),
      ];
      final columns = deriveColumns(schema);
      expect(columns.map((c) => c.name), equals(['a', 'b']));
      // order = index d'origine (a=1, b=3), pas l'index post-filtrage.
      expect(columns[0].order, equals(1));
      expect(columns[1].order, equals(3));
    });

    test('header = label ?? name', () {
      const schema = [
        ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
        ZFieldSpec(name: 'age', type: EditionFieldType.number),
      ];
      final columns = deriveColumns(schema);
      expect(columns[0].header, equals('Nom'));
      expect(columns[1].header, equals('age'));
    });

    test('déterministe : même entrée → colonnes égales', () {
      const schema = [
        ZFieldSpec(name: 'name', type: EditionFieldType.text),
        ZFieldSpec(name: 'age', type: EditionFieldType.number),
      ];
      expect(deriveColumns(schema), equals(deriveColumns(schema)));
    });

    test('schéma vide → aucune colonne', () {
      expect(deriveColumns(const <ZFieldSpec>[]), isEmpty);
    });
  });

  group('ZColumnPolicy (AC3, AD-4)', () {
    const schema = [
      ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
      ZFieldSpec(name: 'name', type: EditionFieldType.text),
      ZFieldSpec(name: 'doc', type: EditionFieldType.document),
    ];

    test('forceInclude ramène un champ lourd ET un isId', () {
      final columns = deriveColumns(
        schema,
        policy: const ZColumnPolicy(forceInclude: {'doc', 'id'}),
      );
      expect(columns.map((c) => c.name), containsAll(<String>['id', 'doc']));
    });

    test('forceExclude retire un champ normalement inclus', () {
      final columns = deriveColumns(
        schema,
        policy: const ZColumnPolicy(forceExclude: {'name'}),
      );
      expect(columns.map((c) => c.name), isNot(contains('name')));
    });

    test('forceExclude l\'emporte sur forceInclude (conflit)', () {
      final columns = deriveColumns(
        schema,
        policy: const ZColumnPolicy(
          forceInclude: {'doc'},
          forceExclude: {'doc'},
        ),
      );
      expect(columns.map((c) => c.name), isNot(contains('doc')));
    });

    test('égalité de valeur ZColumnPolicy', () {
      const a = ZColumnPolicy(forceInclude: {'x'}, forceExclude: {'y'});
      const b = ZColumnPolicy(forceInclude: {'x'}, forceExclude: {'y'});
      const c = ZColumnPolicy(forceInclude: {'x'});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('format par EditionFieldType (AC2)', () {
    ZListColumn colOf(ZFieldSpec f) => deriveColumns([f]).single;

    test('null → chaîne vide', () {
      final col = colOf(const ZFieldSpec(name: 'x', type: EditionFieldType.text));
      expect(col.format(null), equals(''));
    });

    test('select/radio/checkbox → libellé de choix résolu, repli toString', () {
      const choices = [
        ZFieldChoice(value: 'o', label: 'Ouvert'),
        ZFieldChoice(value: 'c', label: 'Clos'),
      ];
      final sel = colOf(const ZFieldSpec(
        name: 's',
        type: EditionFieldType.select,
        choices: choices,
      ));
      expect(sel.format('o'), equals('Ouvert'));
      expect(sel.format('c'), equals('Clos'));
      // Valeur sans option correspondante → repli toString.
      expect(sel.format('z'), equals('z'));

      final rad = colOf(const ZFieldSpec(
        name: 'r',
        type: EditionFieldType.radio,
        choices: choices,
      ));
      expect(rad.format('o'), equals('Ouvert'));
    });

    test('multiple / tags / Iterable → éléments joints par ", "', () {
      // Champ multiple explicite.
      final multi = colOf(const ZFieldSpec(
        name: 'm',
        type: EditionFieldType.select,
        multiple: true,
        choices: [
          ZFieldChoice(value: 'a', label: 'Alpha'),
          ZFieldChoice(value: 'b', label: 'Beta'),
        ],
      ));
      expect(multi.format(['a', 'b']), equals('Alpha, Beta'));

      // tags → join même sans flag multiple.
      final tags = colOf(const ZFieldSpec(name: 't', type: EditionFieldType.tags));
      expect(tags.format(['x', 'y', 'z']), equals('x, y, z'));

      // Valeur Iterable sur un champ scalaire → jointure neutre.
      final txt = colOf(const ZFieldSpec(name: 'c', type: EditionFieldType.text));
      expect(txt.format(['p', 'q']), equals('p, q'));
    });

    test('dateTime/time → ISO-8601 si DateTime, sinon toString', () {
      final dt = colOf(const ZFieldSpec(
        name: 'd',
        type: EditionFieldType.dateTime,
      ));
      final date = DateTime.utc(2026, 7, 10, 8, 30);
      expect(dt.format(date), equals(date.toIso8601String()));
      expect(dt.format('pas une date'), equals('pas une date'));
    });

    test('number/integer/float/boolean → toString neutre', () {
      expect(
        colOf(const ZFieldSpec(name: 'n', type: EditionFieldType.number))
            .format(42),
        equals('42'),
      );
      expect(
        colOf(const ZFieldSpec(name: 'i', type: EditionFieldType.integer))
            .format(7),
        equals('7'),
      );
      expect(
        colOf(const ZFieldSpec(name: 'f', type: EditionFieldType.float))
            .format(3.14),
        equals('3.14'),
      );
      expect(
        colOf(const ZFieldSpec(name: 'b', type: EditionFieldType.boolean))
            .format(true),
        equals('true'),
      );
    });

    test('ne lève jamais sur valeur inattendue (AD-10)', () {
      final col = colOf(const ZFieldSpec(name: 'x', type: EditionFieldType.text));
      expect(() => col.format(Object()), returnsNormally);
    });
  });

  group('ZListColumn — égalité de valeur (format exclu, AC1)', () {
    test('mêmes name/header/type/order/width ⇒ égales (closures ignorées)', () {
      final a = deriveColumns(
        const [ZFieldSpec(name: 'x', type: EditionFieldType.text)],
      ).single;
      final b = deriveColumns(
        const [ZFieldSpec(name: 'x', type: EditionFieldType.text)],
      ).single;
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('header différent ⇒ inégales', () {
      final a = deriveColumns(
        const [ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'A')],
      ).single;
      final b = deriveColumns(
        const [ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'B')],
      ).single;
      expect(a, isNot(equals(b)));
    });
  });
}
