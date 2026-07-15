/// Tests `ZReminderTime` — value-object `HH:mm` défensif (AC1, AC2).
///
/// PUR `dart test` (JS-safe : `gate:web` default-ON) — aucun `dart:io`, aucun
/// `DateTime`.
library;

import 'package:test/test.dart';
import 'package:zcrud_exam/zcrud_exam.dart';

void main() {
  group('AC1 — value-object PUR', () {
    test('ctor `const`, deux `int`, `==`/`hashCode` de VALEUR', () {
      const a = ZReminderTime(hour: 8, minute: 5);
      const b = ZReminderTime(hour: 8, minute: 5);
      const c = ZReminderTime(hour: 8, minute: 6);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
      expect(a.hour, 8);
      expect(a.minute, 5);
      // Utilisable en contexte `const` (immuable).
      expect(identical(a, b), isTrue,
          reason: 'deux littéraux `const` identiques sont canonicalisés');
    });
  });

  group('AC2 — parse défensif et TOTAL (AD-10)', () {
    test('parse `HH:mm` valide (zéro-paddé et non paddé)', () {
      expect(ZReminderTime.parse('08:05'), const ZReminderTime(hour: 8, minute: 5));
      expect(ZReminderTime.parse('8:5'), const ZReminderTime(hour: 8, minute: 5));
      expect(ZReminderTime.parse('23:59'),
          const ZReminderTime(hour: 23, minute: 59));
      expect(ZReminderTime.parse('00:00'),
          const ZReminderTime(hour: 0, minute: 0));
    });

    test('tolère `HH:mm:ss` (secondes tronquées, parité `ZTimeCodec`)', () {
      expect(ZReminderTime.parse('08:30:45'),
          const ZReminderTime(hour: 8, minute: 30));
    });

    // 🔴 Fixture d'échec ISOLÉE (R2) — hors bornes / non parsable / null ⇒ null,
    // JAMAIS un throw.
    test('R2 — hors bornes / non parsable / vide / null ⇒ `null`', () {
      expect(ZReminderTime.parse('25:00'), isNull, reason: 'hour > 23');
      expect(ZReminderTime.parse('08:99'), isNull, reason: 'minute > 59');
      expect(ZReminderTime.parse('08:60'), isNull, reason: 'borne minute == 60');
      expect(ZReminderTime.parse('huit heures'), isNull);
      expect(ZReminderTime.parse('8'), isNull, reason: 'pas de séparateur');
      expect(ZReminderTime.parse(''), isNull);
      expect(ZReminderTime.parse(null), isNull);
      expect(ZReminderTime.parse('-1:30'), isNull, reason: 'hour < 0');
    });

    test('parse ne throw JAMAIS (AD-10)', () {
      expect(() => ZReminderTime.parse('n\'importe quoi'), returnsNormally);
      expect(() => ZReminderTime.parse(null), returnsNormally);
    });

    test('toHhmm rend la chaîne zéro-paddée 24h', () {
      expect(const ZReminderTime(hour: 8, minute: 5).toHhmm(), '08:05');
      expect(const ZReminderTime(hour: 0, minute: 0).toHhmm(), '00:00');
      expect(const ZReminderTime(hour: 23, minute: 59).toHhmm(), '23:59');
    });

    test('round-trip parse(t.toHhmm()) == t pour tout t valide', () {
      for (var h = 0; h < 24; h++) {
        for (var m = 0; m < 60; m += 7) {
          final t = ZReminderTime(hour: h, minute: m);
          expect(ZReminderTime.parse(t.toHhmm()), equals(t),
              reason: 'round-trip cassé pour $h:$m');
        }
      }
    });
  });
}
