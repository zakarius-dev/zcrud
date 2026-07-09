// E2-4 (AC2/AC3/AC4/AC11) : test de couverture de surface. Chaque annotation est
// instanciée EN `const` avec TOUS ses paramètres renseignés simultanément, ce qui
// prouve que la surface d'autorité est entièrement `const`-constructible (donc
// lisible par `ConstantReader` en E2-5) et couvre
// label/type/validators/config/choices/condition/searchable + extras canoniques.
import 'package:test/test.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

void main() {
  group('@ZcrudModel', () {
    test('const avec défauts sûrs', () {
      const m = ZcrudModel();
      expect(m.kind, isNull);
      expect(m.fieldRename, ZFieldRename.snake);
    });

    test('const avec tous les paramètres', () {
      const m = ZcrudModel(kind: 'article', fieldRename: ZFieldRename.none);
      expect(m.kind, 'article');
      expect(m.fieldRename, ZFieldRename.none);
    });
  });

  group('@ZcrudField (surface complète)', () {
    test('const avec défauts sûrs', () {
      const f = ZcrudField();
      expect(f.label, isNull);
      expect(f.type, isNull);
      expect(f.validators, isNull);
      expect(f.config, isNull);
      expect(f.choices, isNull);
      expect(f.condition, isNull);
      expect(f.searchable, isFalse);
      expect(f.defaultValue, isNull);
      expect(f.readOnly, isFalse);
      expect(f.showIfNull, isTrue);
      expect(f.name, isNull);
      expect(f.multiple, isFalse);
    });

    test('const avec CHAQUE paramètre simultanément (couverture de surface)', () {
      const f = ZcrudField(
        label: 'field.title',
        type: EditionFieldType.select,
        validators: <ZValidatorSpec>[
          ZValidatorSpec.required(),
          ZValidatorSpec.minLength(2),
          ZValidatorSpec.pattern(r'^\w+$'),
        ],
        config: ZTextConfig(minLines: 1, maxLines: 3),
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'a', label: 'A'),
          ZFieldChoice(value: 'b', label: 'B'),
        ],
        condition: ZCondition.and(<ZCondition>[
          ZCondition.truthy('enabled'),
          ZCondition.notEquals('status', 'archived'),
        ]),
        searchable: true,
        defaultValue: 'a',
        readOnly: true,
        showIfNull: false,
        name: 'title_key',
        multiple: true,
      );

      expect(f.label, 'field.title');
      expect(f.type, EditionFieldType.select);
      expect(f.validators, hasLength(3));
      expect(f.validators!.first.kind, ZValidatorKind.required);
      expect(f.config, isA<ZTextConfig>());
      expect(f.choices, hasLength(2));
      expect(f.choices!.last.label, 'B');
      expect(f.condition!.op, ZConditionOp.and);
      expect(f.searchable, isTrue);
      expect(f.defaultValue, 'a');
      expect(f.readOnly, isTrue);
      expect(f.showIfNull, isFalse);
      expect(f.name, 'title_key');
      expect(f.multiple, isTrue);
    });
  });

  group('@ZcrudId', () {
    test('marqueur const sans paramètre', () {
      const id = ZcrudId();
      expect(id, isA<ZcrudId>());
    });
  });

  test('marqueur de version conservé (décision dev)', () {
    expect(ZAnnotationsApi.version, isNotEmpty);
    expect(ZAnnotationsApi.coreApiVersion, isNotEmpty);
  });
}
