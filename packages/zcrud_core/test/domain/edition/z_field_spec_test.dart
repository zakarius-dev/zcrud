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
    // DP-13 : défaut inversé à `false` (parité DODLP — masque les vides en
    // lecture, sauf `showIfNull: true` explicite).
    expect(s.showIfNull, isFalse);
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

  // ── DP-1 / B1 : ZFieldSpec.fieldSize (additif, rétro-compatible, AC1/AC2) ──

  test('fieldSize : défaut = normal (rétro-compat AC2)', () {
    const s = ZFieldSpec(name: 'x', type: EditionFieldType.text);
    expect(s.fieldSize, ZFieldSize.normal);
  });

  test('fieldSize : copyWith(fieldSize: large) surcharge ciblée (AC2)', () {
    const s = ZFieldSpec(name: 'x', type: EditionFieldType.text);
    final large = s.copyWith(fieldSize: ZFieldSize.large);
    expect(large.fieldSize, ZFieldSize.large);
    // Identité de valeur préservée pour les autres champs.
    expect(large.copyWith(fieldSize: ZFieldSize.normal), equals(s));
  });

  test('fieldSize : entre dans == / hashCode (AC2)', () {
    const normal = ZFieldSpec(name: 'x', type: EditionFieldType.text);
    const large = ZFieldSpec(
      name: 'x',
      type: EditionFieldType.text,
      fieldSize: ZFieldSize.large,
    );
    expect(normal, isNot(equals(large)));
    expect(normal.hashCode, isNot(large.hashCode));
    // Rétro-compat : une spec sans fieldSize == une spec fieldSize: normal.
    const explicitNormal = ZFieldSpec(
      name: 'x',
      type: EditionFieldType.text,
      fieldSize: ZFieldSize.normal,
    );
    expect(normal, equals(explicitNormal));
    expect(normal.hashCode, explicitNormal.hashCode);
  });
}
