/// Tests `ZExam` — round-trip zéro-perte, AD-19, patron `extra` ES-2.2b
/// (AC3–AC7).
///
/// PUR `dart test` (JS-safe : `gate:web` default-ON) — aucun `dart:io`. Les
/// `DateTime` sont des littéraux `DateTime.utc(...)` (arguments explicites,
/// JS-safe) ou des `String` ISO ; jamais `DateTime.now()`.
library;

import 'package:test/test.dart';
import 'package:zcrud_exam/zcrud_exam.dart';

void main() {
  group('AC4 — fromMap défensive, non-nue (AD-10)', () {
    test('fromMap({}) rend une instance sur les défauts, ne throw JAMAIS', () {
      final e = ZExam.fromMap(const <String, dynamic>{});
      expect(e.id, isNull);
      expect(e.folderId, '');
      expect(e.title, '');
      expect(e.date, isNull);
      expect(e.reminderEnabled, isFalse);
      expect(e.reminderDaysBefore, isEmpty);
      expect(e.reminderTime, isNull);
      expect(e.extension, isNull);
      expect(e.extra, isEmpty);
    });

    test('R2 — date corrompue ⇒ date == null (pas de throw)', () {
      final e = ZExam.fromMap(const <String, dynamic>{'date': 'pas-une-date'});
      expect(e.date, isNull);
    });

    test('R2 — reminder_time invalide ⇒ reminderTime == null (pas de throw)', () {
      final e =
          ZExam.fromMap(const <String, dynamic>{'reminder_time': '99:99'});
      expect(e.reminderTime, isNull);
    });

    test('reminder_time valide est décodé en ZReminderTime', () {
      final e =
          ZExam.fromMap(const <String, dynamic>{'reminder_time': '08:30'});
      expect(e.reminderTime, const ZReminderTime(hour: 8, minute: 30));
    });
  });

  group('AC5 — round-trip Map idempotent et ZÉRO-PERTE', () {
    // 🔴 Pouvoir discriminant OBSERVÉ (anti-golden-fortuit) : clé inconnue
    // IMBRIQUÉE, `reminder_days_before` ordonné [7, 1], `reminder_time`.
    final map = <String, dynamic>{
      'id': 'exam-1',
      'folder_id': 'f42',
      'title': 'Partiel de droit douanier',
      'date': '2026-07-20T00:00:00.000Z',
      'reminder_enabled': true,
      'reminder_days_before': <int>[7, 1],
      'reminder_time': '08:30',
      'legacy_note': <String, dynamic>{
        'source': 'iffd',
        'tags': <String>['a', 'b'],
      },
    };

    test('fromMap(m).toMap() réémet EXACTEMENT les mêmes clés/valeurs', () {
      final e = ZExam.fromMap(map);
      final out = e.toMap();
      expect(out['id'], 'exam-1');
      expect(out['folder_id'], 'f42');
      expect(out['title'], 'Partiel de droit douanier');
      expect(out['date'], '2026-07-20T00:00:00.000Z');
      expect(out['reminder_enabled'], true);
      expect(out['reminder_days_before'], <int>[7, 1],
          reason: 'ordre préservé');
      expect(out['reminder_time'], '08:30');
      // Clé inconnue portée par `extra`, préservée VERBATIM (AD-4).
      expect(out['legacy_note'], <String, dynamic>{
        'source': 'iffd',
        'tags': <String>['a', 'b'],
      });
    });

    test('égalité PROFONDE : fromMap(m) == fromMap(m) (extra imbriqué)', () {
      expect(ZExam.fromMap(map), equals(ZExam.fromMap(map)));
      expect(ZExam.fromMap(map).hashCode, equals(ZExam.fromMap(map).hashCode));
    });

    test('idempotence : fromMap(m).toMap() re-décodée redonne une instance ==',
        () {
      final e1 = ZExam.fromMap(map);
      final e2 = ZExam.fromMap(e1.toMap());
      expect(e2, equals(e1));
    });

    test('reminderTime == null ⇒ clé reminder_time OMISE (patron nullable)', () {
      final e = ZExam.fromMap(const <String, dynamic>{'title': 't'});
      expect(e.toMap().containsKey('reminder_time'), isFalse);
    });

    // 🔴 Injection de régression (R3) épinglée : la clé reminder_time DOIT
    // apparaître dans toMap quand reminderTime != null. Retirer la ligne
    // `map[kReminderTimeKey] = ...` de toMap() rendrait ce test ROUGE.
    test('R3 — reminderTime non-null ⇒ toMap réémet reminder_time', () {
      const e = ZExam(reminderTime: ZReminderTime(hour: 8, minute: 30));
      expect(e.toMap()[kReminderTimeKey], '08:30');
    });
  });

  group('AC6 — AD-19 : aucun horodatage de sync inline', () {
    test('clés de sync écrites dans le corps ne tombent PAS dans extra', () {
      final e = ZExam.fromMap(<String, dynamic>{
        'id': 'x',
        'title': 't',
        'updated_at': '1999-01-01',
        'is_deleted': true,
      });
      expect(e.extra.containsKey('updated_at'), isFalse);
      expect(e.extra.containsKey('is_deleted'), isFalse);
    });

    test('toMap ne réémet NI updated_at NI is_deleted', () {
      final e = ZExam.fromMap(<String, dynamic>{
        'id': 'x',
        'title': 't',
        'updated_at': '1999-01-01',
        'is_deleted': true,
      });
      final out = e.toMap();
      expect(out.containsKey('updated_at'), isFalse);
      expect(out.containsKey('is_deleted'), isFalse);
    });

    // 🔴 R3 — la garde tient sur la voie copyWith (leçon H2/MAJEUR-3) : la MÊME
    // fonction nommée `_sanitizeExtra` sur les DEUX frontières. Retirer
    // `_sanitizeExtra` de copyWith rendrait ce test ROUGE.
    test('R3 — copyWith(extra: {sync}) ne réémet PAS ces clés', () {
      const base = ZExam(id: 'x', title: 't');
      final e = base.copyWith(
        extra: <String, dynamic>{'updated_at': 'x', 'is_deleted': true},
      );
      expect(e.extra.containsKey('updated_at'), isFalse);
      expect(e.toMap().containsKey('updated_at'), isFalse);
      expect(e.toMap().containsKey('is_deleted'), isFalse);
    });

    test('date est une clé MÉTIER, jamais une clé de sync', () {
      final e = ZExam.fromMap(const <String, dynamic>{
        'date': '2026-07-20T00:00:00.000Z',
      });
      expect(e.date, DateTime.utc(2026, 7, 20));
      expect(e.toMap()['date'], '2026-07-20T00:00:00.000Z');
    });
  });

  group('AC7 — patron extra ES-2.2b INTÉGRAL', () {
    // 🔴 Fixture d'échec ISOLÉE (R2) : la voie CONSTRUCTEUR (const, polluante) —
    // l'accesseur NORMALISE quand même.
    test('R2 — voie CONSTRUCTEUR : extra est VIDE de clés réservées', () {
      const e = ZExam(extra: <String, dynamic>{'updated_at': 'x'});
      expect(e.extra.containsKey('updated_at'), isFalse,
          reason: 'l\'accesseur `extra` normalise, même via le ctor const');
    });

    test('une clé réservée de schéma via extra est filtrée (ctor)', () {
      const e = ZExam(extra: <String, dynamic>{'folder_id': 'pollution'});
      expect(e.extra.containsKey('folder_id'), isFalse);
    });

    test('reminder_time via extra est filtré (canal réservé)', () {
      const e = ZExam(extra: <String, dynamic>{'reminder_time': '01:01'});
      expect(e.extra.containsKey('reminder_time'), isFalse);
    });

    // 🔴 R3 — égalité PROFONDE sur extra imbriqué (DW-ES22-4). Remplacer
    // zJsonEquals par `extra == other.extra` rendrait ce test ROUGE.
    test('R3 — égalité profonde : extra imbriqué', () {
      const a = ZExam(extra: <String, dynamic>{
        'k': <String, dynamic>{
          'nested': <int>[1, 2],
        },
      });
      const b = ZExam(extra: <String, dynamic>{
        'k': <String, dynamic>{
          'nested': <int>[1, 2],
        },
      });
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith à sentinelle : un champ omis est préservé', () {
      const base = ZExam(
        id: 'x',
        folderId: 'f',
        title: 't',
        reminderEnabled: true,
        reminderDaysBefore: <int>[3],
        reminderTime: ZReminderTime(hour: 9, minute: 0),
      );
      final e = base.copyWith(title: 'nouveau');
      expect(e.title, 'nouveau');
      // Tous les autres champs PRÉSERVÉS (le copyWith généré les perdrait).
      expect(e.id, 'x');
      expect(e.folderId, 'f');
      expect(e.reminderEnabled, isTrue);
      expect(e.reminderDaysBefore, <int>[3]);
      expect(e.reminderTime, const ZReminderTime(hour: 9, minute: 0));
    });

    test('copyWith(reminderTime: null) remet explicitement à null', () {
      const base = ZExam(reminderTime: ZReminderTime(hour: 9, minute: 0));
      expect(base.copyWith(reminderTime: null).reminderTime, isNull);
    });

    test('reminderDaysBefore : ordre préservé dans == et round-trip', () {
      const a = ZExam(reminderDaysBefore: <int>[7, 1]);
      const b = ZExam(reminderDaysBefore: <int>[1, 7]);
      expect(a, isNot(equals(b)), reason: 'égalité ORDONNÉE');
    });
  });
}
