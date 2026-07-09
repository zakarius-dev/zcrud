// E2-4 (AC5/AC6/AC7) : le catalogue `EditionFieldType` + les types-valeur
// d'autorité `const` vivent dans `zcrud_core/domain` (pur-Dart) et sont
// entièrement `const`-constructibles (donc lisibles par `ConstantReader` en
// E2-5).
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('EditionFieldType (catalogue de parité + custom)', () {
    test('couvre le catalogue de parité DODLP (technical-inventory §3)', () {
      // Référence unique de parité SM-2 : le tableau §3. On asserte la présence
      // NOMMÉE de chaque type (pas un simple compte approximatif).
      const paritySet = <EditionFieldType>{
        EditionFieldType.text,
        EditionFieldType.multiline,
        EditionFieldType.number,
        EditionFieldType.integer,
        EditionFieldType.float,
        EditionFieldType.boolean,
        EditionFieldType.dateTime,
        EditionFieldType.time,
        EditionFieldType.select,
        EditionFieldType.radio,
        EditionFieldType.checkbox,
        EditionFieldType.relation,
        EditionFieldType.rowChips,
        EditionFieldType.tags,
        EditionFieldType.subItems,
        EditionFieldType.dynamicItem,
        EditionFieldType.file,
        EditionFieldType.image,
        EditionFieldType.document,
        EditionFieldType.location,
        EditionFieldType.geoArea,
        EditionFieldType.phoneNumber,
        EditionFieldType.country,
        EditionFieldType.address,
        EditionFieldType.rating,
        EditionFieldType.slider,
        EditionFieldType.signature,
        EditionFieldType.color,
        EditionFieldType.icon,
        EditionFieldType.markdown,
        EditionFieldType.inlineMarkdown,
        EditionFieldType.html,
        EditionFieldType.inlineHtml,
        EditionFieldType.richText,
        EditionFieldType.stepper,
        EditionFieldType.password,
        EditionFieldType.hidden,
        EditionFieldType.widget,
      };
      for (final t in paritySet) {
        expect(EditionFieldType.values, contains(t));
      }
      // Catalogue de parité (38) + la valeur ouverte `custom` = 39.
      expect(paritySet.length, 38);
      expect(EditionFieldType.values.length, paritySet.length + 1);
    });

    test('porte la valeur ouverte `custom` (AD-4)', () {
      expect(EditionFieldType.values, contains(EditionFieldType.custom));
    });

    test('valeurs en camelCase (discipline @JsonKey future — canonique §5)', () {
      // `name` d'enum = jsonValue camelCase : première lettre minuscule,
      // aucun séparateur `_`/`-`.
      for (final t in EditionFieldType.values) {
        expect(t.name, isNot(contains('_')));
        expect(t.name, isNot(contains('-')));
        expect(t.name[0], equals(t.name[0].toLowerCase()));
      }
    });
  });

  group('ZFieldRename', () {
    test('énumère les stratégies, défaut snake aligné AD-3', () {
      expect(ZFieldRename.values,
          containsAll(<ZFieldRename>[
            ZFieldRename.none,
            ZFieldRename.snake,
            ZFieldRename.kebab,
            ZFieldRename.pascal,
          ]));
    });
  });

  group('ZFieldChoice', () {
    test('const-constructible et porte value/label', () {
      const choice = ZFieldChoice(value: 'a', label: 'Option A');
      expect(choice.value, 'a');
      expect(choice.label, 'Option A');
    });

    test('égalité de valeur', () {
      expect(const ZFieldChoice(value: 1, label: 'Un'),
          const ZFieldChoice(value: 1, label: 'Un'));
      expect(const ZFieldChoice(value: 1, label: 'Un').hashCode,
          const ZFieldChoice(value: 1, label: 'Un').hashCode);
    });
  });

  group('ZValidatorSpec (déclaratif, aucune closure)', () {
    test('chaque variante est const-constructible et porte sa donnée', () {
      const variants = <ZValidatorSpec>[
        ZValidatorSpec.required(),
        ZValidatorSpec.minLength(3),
        ZValidatorSpec.maxLength(100),
        ZValidatorSpec.min(0),
        ZValidatorSpec.minKey('other'),
        ZValidatorSpec.max(10),
        ZValidatorSpec.maxKey('other'),
        ZValidatorSpec.equal('x'),
        ZValidatorSpec.notEqual('y'),
        ZValidatorSpec.match('confirm'),
        ZValidatorSpec.email(),
        ZValidatorSpec.url(),
        ZValidatorSpec.ip(),
        ZValidatorSpec.creditCard(),
        ZValidatorSpec.phone(),
        ZValidatorSpec.numeric(),
        ZValidatorSpec.integer(),
        ZValidatorSpec.dateString(),
        ZValidatorSpec.address(),
        ZValidatorSpec.percentage(),
        ZValidatorSpec.password(),
        ZValidatorSpec.pattern(r'^\d+$'),
      ];
      // Couvre l'ensemble transverse de l'inventaire (§3, ligne validators).
      final kinds = variants.map((v) => v.kind).toSet();
      expect(kinds, containsAll(ZValidatorKind.values));
    });

    test('paramètres portés correctement', () {
      const minL = ZValidatorSpec.minLength(3, errorText: 'trop court');
      expect(minL.kind, ZValidatorKind.minLength);
      expect(minL.length, 3);
      expect(minL.errorText, 'trop court');

      const minKey = ZValidatorSpec.minKey('start');
      expect(minKey.kind, ZValidatorKind.min);
      expect(minKey.refKey, 'start');
      expect(minKey.bound, isNull);

      const eq = ZValidatorSpec.equal(42);
      expect(eq.value, 42);

      const pat = ZValidatorSpec.pattern(r'\w+');
      expect(pat.pattern, r'\w+');
    });

    test('égalité de valeur', () {
      expect(const ZValidatorSpec.minLength(3),
          const ZValidatorSpec.minLength(3));
      expect(const ZValidatorSpec.minLength(3),
          isNot(const ZValidatorSpec.minLength(4)));
    });
  });

  group('ZCondition (déclarative, jamais une closure)', () {
    test('feuilles const-constructibles', () {
      const eq = ZCondition.equals('status', 'open');
      expect(eq.op, ZConditionOp.equals);
      expect(eq.field, 'status');
      expect(eq.value, 'open');

      const ne = ZCondition.notEquals('status', 'closed');
      expect(ne.op, ZConditionOp.notEquals);

      const isN = ZCondition.isNull('deletedAt');
      expect(isN.op, ZConditionOp.isNull);

      const notN = ZCondition.notNull('createdAt');
      expect(notN.op, ZConditionOp.notNull);

      const tr = ZCondition.truthy('enabled');
      expect(tr.op, ZConditionOp.truthy);
    });

    test('combinateurs and/or/not const-constructibles', () {
      const and = ZCondition.and(<ZCondition>[
        ZCondition.truthy('a'),
        ZCondition.equals('b', 1),
      ]);
      expect(and.op, ZConditionOp.and);
      expect(and.operands, hasLength(2));

      const or = ZCondition.or(<ZCondition>[
        ZCondition.isNull('x'),
        ZCondition.notNull('y'),
      ]);
      expect(or.op, ZConditionOp.or);

      const not = ZCondition.not(ZCondition.truthy('flag'));
      expect(not.op, ZConditionOp.not);
      expect(not.operand, isNotNull);
      expect(not.operand!.op, ZConditionOp.truthy);
    });

    test('égalité de valeur (profonde)', () {
      expect(
        const ZCondition.and(<ZCondition>[ZCondition.truthy('a')]),
        const ZCondition.and(<ZCondition>[ZCondition.truthy('a')]),
      );
    });
  });

  group('ZFieldConfig (base d\'extension + configs triviales pur-cœur)', () {
    test('ZTextConfig const', () {
      const c = ZTextConfig(minLines: 1, maxLines: 5, keyboardType: 'multiline');
      expect(c, isA<ZFieldConfig>());
      expect(c.minLines, 1);
      expect(c.maxLines, 5);
      expect(c.keyboardType, 'multiline');
    });

    test('ZNumberConfig const', () {
      const c = ZNumberConfig(
        minValueKey: 'lo',
        maxValueKey: 'hi',
        isCurrency: true,
      );
      expect(c, isA<ZFieldConfig>());
      expect(c.minValueKey, 'lo');
      expect(c.maxValueKey, 'hi');
      expect(c.isCurrency, isTrue);
      expect(c.isPercentage, isFalse);
    });

    test('ZDateConfig const', () {
      const c = ZDateConfig(firstDateKey: 'from', lastDateKey: 'to');
      expect(c, isA<ZFieldConfig>());
      expect(c.firstDateKey, 'from');
      expect(c.lastDateKey, 'to');
    });
  });
}
