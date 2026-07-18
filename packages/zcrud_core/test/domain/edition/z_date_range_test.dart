// AD-47 / AD-10 — `ZDateRange` : type-valeur plage de dates ISO-8601, invariant
// `end >= start`, désérialisation DÉFENSIVE FALSIFIABLE.
//
// Prouve la falsifiabilité (discipline R3) : le décodeur STRICT `fromJson`
// **lève** sur chaque forme de corruption (comportement observé), pendant que le
// décodeur défensif `fromJsonSafe` retombe TOUJOURS sur `null` sans throw. Un
// chemin de persistance branché sur `fromJson` (au lieu de `fromJsonSafe`) ferait
// donc mécaniquement ROUGIR ce test — la garde est load-bearing, pas décorative.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('ZDateRange — sérialisation valide', () {
    test('toJson émet start/end en ISO-8601', () {
      final r = ZDateRange(
        start: DateTime.parse('2026-01-01T00:00:00.000'),
        end: DateTime.parse('2026-01-31T12:30:00.000'),
      );
      expect(r.toJson(), <String, dynamic>{
        'start': '2026-01-01T00:00:00.000',
        'end': '2026-01-31T12:30:00.000',
      });
    });

    test('round-trip fromJson(toJson()) == r (plage valide)', () {
      final r = ZDateRange(
        start: DateTime.parse('2026-01-01T00:00:00.000'),
        end: DateTime.parse('2026-02-01T00:00:00.000'),
      );
      expect(ZDateRange.fromJson(r.toJson()), equals(r));
      expect(ZDateRange.fromJsonSafe(r.toJson()), equals(r));
    });

    test('égalité end == start autorisée (invariant end >= start)', () {
      final d = DateTime.parse('2026-01-01T00:00:00.000');
      expect(ZDateRange(start: d, end: d).start, d);
      final decoded = ZDateRange.fromJsonSafe(<String, dynamic>{
        'start': '2026-01-01T00:00:00.000',
        'end': '2026-01-01T00:00:00.000',
      });
      expect(decoded, isNotNull);
    });
  });

  // ── Corpus corrompu (≥ 6 entrées) : fromJsonSafe → null, JAMAIS de throw ────
  final corruptCorpus = <String, Object?>{
    'null': null,
    'non-map (int)': 42,
    'non-map (String)': 'x',
    'end absent': <String, dynamic>{'start': '2026-01-02T00:00:00.000'},
    'start absent': <String, dynamic>{'end': '2026-01-02T00:00:00.000'},
    'start/end non-String': <String, dynamic>{'start': 123, 'end': 456},
    'dates non-ISO': <String, dynamic>{'start': 'pas-une-date', 'end': 'x'},
    'start > end': <String, dynamic>{
      'start': '2026-02-01T00:00:00.000',
      'end': '2026-01-01T00:00:00.000',
    },
  };

  group('ZDateRange.fromJsonSafe — DÉFENSIF (AD-10)', () {
    corruptCorpus.forEach((name, corrupt) {
      test('[$name] → null sans throw', () {
        late ZDateRange? result;
        expect(
          () => result = ZDateRange.fromJsonSafe(corrupt),
          returnsNormally,
          reason: 'fromJsonSafe ne doit JAMAIS throw ($name)',
        );
        expect(result, isNull, reason: '$name → repli null');
      });
    });
  });

  // ── Falsifiabilité R3 : le décodeur STRICT `fromJson` LÈVE sur chaque forme de
  //    corruption (comportement observé). C'est ce throw que `fromJsonSafe` avale ;
  //    pointer un chemin défensif sur `fromJson` ferait ROUGIR le corpus AD-10. ──
  group('ZDateRange.fromJson — STRICT lève (preuve de falsifiabilité R3)', () {
    corruptCorpus.forEach((name, corrupt) {
      test('[$name] → throws (comportement, pas takeException isNull)', () {
        expect(
          () => ZDateRange.fromJson(corrupt),
          throwsA(anything),
          reason: 'fromJson strict DOIT lever sur $name '
              '(sinon fromJsonSafe serait tautologique)',
        );
      });
    });
  });
}
