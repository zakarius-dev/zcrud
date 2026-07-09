// AC6 (E2-5) : `ZFieldSpec` — projection runtime pur-Dart, égalité de VALEUR
// (utile aux tests de projection et à la mémoïsation E3). Tests sous
// `flutter test` (zcrud_core dépend du SDK Flutter depuis E2-7) mais le type
// lui-même reste pur-Dart (garde `domain_purity_test.dart`).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('défauts sûrs', () {
    const s = ZFieldSpec(name: 'x', type: EditionFieldType.text);
    expect(s.validators, isEmpty);
    expect(s.choices, isEmpty);
    expect(s.searchable, isFalse);
    expect(s.readOnly, isFalse);
    expect(s.showIfNull, isTrue);
    expect(s.multiple, isFalse);
    expect(s.isId, isFalse);
    expect(s.condition, isNull);
    expect(s.config, isNull);
  });

  test('égalité de valeur (== / hashCode), listes profondes', () {
    const a = ZFieldSpec(
      name: 'title',
      type: EditionFieldType.text,
      label: 'Titre',
      validators: <ZValidatorSpec>[ZValidatorSpec.required()],
    );
    const b = ZFieldSpec(
      name: 'title',
      type: EditionFieldType.text,
      label: 'Titre',
      validators: <ZValidatorSpec>[ZValidatorSpec.required()],
    );
    const c = ZFieldSpec(name: 'title', type: EditionFieldType.integer);
    expect(a, equals(b));
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(equals(c)));
  });
}
