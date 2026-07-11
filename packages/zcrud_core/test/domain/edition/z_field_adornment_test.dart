// DP-12 (M1) : `ZFieldAdornment` (type-valeur `const` pur-données) + slots
// additifs de `ZFieldSpec` + getter `isRequired`. Pur-Dart (garde
// `domain_purity_test.dart`).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  group('ZFieldAdornment — type-valeur const', () {
    test('constructeurs nommés : kind + payload', () {
      const t = ZFieldAdornment.text('EUR');
      const i = ZFieldAdornment.icon('search');
      const w = ZFieldAdornment.widget('clear');
      expect(t.kind, ZAdornmentKind.text);
      expect(t.value, 'EUR');
      expect(i.kind, ZAdornmentKind.icon);
      expect(i.value, 'search');
      expect(w.kind, ZAdornmentKind.widget);
      expect(w.value, 'clear');
    });

    test('égalité de valeur (== / hashCode) discriminée par kind + value', () {
      const a = ZFieldAdornment.icon('search');
      const b = ZFieldAdornment.icon('search');
      const c = ZFieldAdornment.text('search'); // même value, kind différent
      const d = ZFieldAdornment.icon('close'); // même kind, value différente
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('toString lisible', () {
      expect(const ZFieldAdornment.text('x').toString(),
          'ZFieldAdornment(text: x)');
    });
  });

  group('ZFieldSpec — slots DP-12 additifs (rétro-compat)', () {
    test('défauts null (spec sans slot inchangée)', () {
      const s = ZFieldSpec(name: 'x', type: EditionFieldType.text);
      expect(s.leading, isNull);
      expect(s.prefix, isNull);
      expect(s.suffix, isNull);
      expect(s.hintText, isNull);
      expect(s.helperText, isNull);
    });

    test('une spec sans slot == une spec sans slot (égalité préservée)', () {
      const a = ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'L');
      const b = ZFieldSpec(name: 'x', type: EditionFieldType.text, label: 'L');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('les slots entrent dans == / hashCode', () {
      const bare = ZFieldSpec(name: 'x', type: EditionFieldType.text);
      const withLeading = ZFieldSpec(
        name: 'x',
        type: EditionFieldType.text,
        leading: ZFieldAdornment.icon('search'),
      );
      const withHint = ZFieldSpec(
        name: 'x',
        type: EditionFieldType.text,
        hintText: 'h',
      );
      expect(bare, isNot(equals(withLeading)));
      expect(bare, isNot(equals(withHint)));
      expect(bare.hashCode, isNot(withLeading.hashCode));
    });

    test('copyWith surcharge ciblée + identité de valeur préservée', () {
      const s = ZFieldSpec(name: 'x', type: EditionFieldType.text);
      final withSuffix =
          s.copyWith(suffix: const ZFieldAdornment.text('%'));
      expect(withSuffix.suffix, const ZFieldAdornment.text('%'));
      // Les autres champs restent égaux.
      expect(withSuffix.copyWith().name, 'x');
      // copyWith sans argument ne perd pas le slot.
      expect(withSuffix.copyWith().suffix, const ZFieldAdornment.text('%'));
    });

    test('copyWith(readOnly:true) préserve les slots (mode lecture E3-4)', () {
      const s = ZFieldSpec(
        name: 'x',
        type: EditionFieldType.text,
        leading: ZFieldAdornment.icon('search'),
        hintText: 'h',
      );
      final ro = s.copyWith(readOnly: true);
      expect(ro.readOnly, isTrue);
      expect(ro.leading, const ZFieldAdornment.icon('search'));
      expect(ro.hintText, 'h');
    });
  });

  group('ZFieldSpec.isRequired (M5)', () {
    test('true ssi un validateur required est présent', () {
      const req = ZFieldSpec(
        name: 'x',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[ZValidatorSpec.required()],
      );
      const opt = ZFieldSpec(
        name: 'x',
        type: EditionFieldType.text,
        validators: <ZValidatorSpec>[ZValidatorSpec.email()],
      );
      const none = ZFieldSpec(name: 'x', type: EditionFieldType.text);
      expect(req.isRequired, isTrue);
      expect(opt.isRequired, isFalse);
      expect(none.isRequired, isFalse);
    });
  });
}
