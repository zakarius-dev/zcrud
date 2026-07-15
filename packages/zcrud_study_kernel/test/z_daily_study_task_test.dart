/// Tests `ZDailyStudyTask` (famille OUVERTE, AC5) + port `ZApproachingExam`
/// (AC6) — ES-2.7.
///
/// Le double `_FakeApproachingExam` a une forme **identique à `ZExam`**
/// (`isApproaching`/`daysUntil`/`date`), prouvant que le port est satisfait
/// structurellement SANS importer `zcrud_exam` (acyclicité AD-1/AD-17, D3/D10).
///
/// Littéraux JS-safe, **aucun `dart:io`** (gate:web AC15).
library;

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('AC5 — famille OUVERTE : discriminant `kind`', () {
    test('kind de chaque variante', () {
      expect(const ZDueCardsTask(3).kind, 'dueCards');
      final exam = _FakeApproachingExam(date: DateTime.utc(2026, 7, 20));
      expect(ZExamTask(exam, 2).kind, 'exam');
    });

    test('les variantes sont bien des ZDailyStudyTask (interface, pas sealed)',
        () {
      expect(const ZDueCardsTask(1), isA<ZDailyStudyTask>());
      final exam = _FakeApproachingExam(date: DateTime.utc(2026, 7, 20));
      expect(ZExamTask(exam, 0), isA<ZDailyStudyTask>());
    });

    test('AD-4 — un satellite peut AJOUTER une variante sans toucher au kernel',
        () {
      // `_PodcastTask` (défini ci-dessous) implémente l'interface OUVERTE :
      // le kernel n'a rien à modifier (pas de `sealed`, dispatch `kind` + default).
      const ZDailyStudyTask task = _PodcastTask();
      final rendered = switch (task.kind) {
        'dueCards' => 'dues',
        'exam' => 'examen',
        _ => 'autre(${task.kind})', // ← default OBLIGATOIRE (aucune exhaustivité)
      };
      expect(rendered, 'autre(podcast)');
    });
  });

  group('AC5 — égalité de valeur des variantes', () {
    test('ZDueCardsTask : égaux ssi count égal', () {
      expect(const ZDueCardsTask(5), const ZDueCardsTask(5));
      expect(const ZDueCardsTask(5).hashCode, const ZDueCardsTask(5).hashCode);
      expect(const ZDueCardsTask(5) == const ZDueCardsTask(6), isFalse);
    });

    test('ZExamTask : égaux ssi exam ET daysUntil égaux', () {
      final e = _FakeApproachingExam(date: DateTime.utc(2026, 7, 20), id: 'a');
      final same = _FakeApproachingExam(date: DateTime.utc(2026, 7, 20), id: 'a');
      final other = _FakeApproachingExam(date: DateTime.utc(2026, 7, 20), id: 'b');
      expect(ZExamTask(e, 2), ZExamTask(same, 2));
      expect(ZExamTask(e, 2).hashCode, ZExamTask(same, 2).hashCode);
      // daysUntil différent ⇒ inégal.
      expect(ZExamTask(e, 2) == ZExamTask(e, 3), isFalse);
      // exam différent ⇒ inégal.
      expect(ZExamTask(e, 2) == ZExamTask(other, 2), isFalse);
    });
  });

  group('AC6 — port neutre ZApproachingExam (double de forme ZExam)', () {
    test('le double satisfait le contrat isApproaching/daysUntil/date', () {
      final e = _FakeApproachingExam(
        date: DateTime.utc(2026, 7, 20),
        approaching: true,
      );
      final now = DateTime.utc(2026, 7, 19);
      expect(e, isA<ZApproachingExam>());
      expect(e.isApproaching(now), isTrue);
      expect(e.daysUntil(now), 1);
      expect(e.date, DateTime.utc(2026, 7, 20));
    });
  });
}

/// Double local — forme **identique** à `ZExam` (ES-2.6) : filtre
/// `isApproaching`/`daysUntil` UTC-normalisés, horloge injectée. AUCUN import de
/// `zcrud_exam` (le kernel reste acyclique, D3).
class _FakeApproachingExam implements ZApproachingExam {
  _FakeApproachingExam({
    required this.date,
    this.id = '',
    bool? approaching,
  }) : _forcedApproaching = approaching;

  final String id;
  @override
  final DateTime? date;
  final bool? _forcedApproaching;
  static const List<int> reminderDaysBefore = <int>[7, 1];
  static const bool reminderEnabled = true;

  @override
  int? daysUntil(DateTime now) {
    final d = date;
    if (d == null) return null;
    final target = DateTime.utc(d.year, d.month, d.day);
    final today = DateTime.utc(now.year, now.month, now.day);
    return target.difference(today).inDays;
  }

  @override
  bool isApproaching(DateTime now) {
    if (_forcedApproaching != null) return _forcedApproaching;
    if (!reminderEnabled) return false;
    final delta = daysUntil(now);
    if (delta == null || delta < 0) return false;
    return reminderDaysBefore.any((threshold) => delta <= threshold);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FakeApproachingExam && id == other.id && date == other.date;

  @override
  int get hashCode => Object.hash(id, date);
}

/// Variante AJOUTÉE par un satellite hypothétique (AD-4) — prouve que la famille
/// est OUVERTE (aucune modification du kernel requise).
class _PodcastTask implements ZDailyStudyTask {
  const _PodcastTask();
  @override
  String get kind => 'podcast';
}
