// Test DISCRIMINANT ES-9.2 — AC5 (AD-12/AD-26, R5) : les fichiers ES-9.2 ne
// contiennent NI `DateTime.now()`/`DateTime()` argless (l'horloge est INJECTÉE), NI
// aucun symbole de notification/scheduler OS (la planification est un SEAM APP). Le
// domaine ne calcule que `isApproaching(now)` déterministe. Patron
// `zcrud_exam/test/no_datetime_now_test.dart` : scan tokenisé, COMMENTAIRES
// DÉPOUILLÉS (les dartdoc ES-9.2 citent verbatim `DateTime.now()` pour l'interdire).
//
// Injections R3-I5 (insérer `DateTime.now()`) / R3-I5b (nommer
// `flutter_local_notifications` / `Timer`) ⇒ ce scan RC=1.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fichiers de PRODUCTION livrés par ES-9.2 (scan LOCAL au package).
const List<String> _es92Files = <String>[
  'lib/src/presentation/z_exam_editor.dart',
  'lib/src/presentation/z_exam_reminders.dart',
  'lib/src/presentation/z_exam_reminders_section.dart',
];

/// Invocation `DateTime.now(` (tolère les espaces).
final RegExp _dateTimeNow = RegExp(r'\bDateTime\s*\.\s*now\s*\(');

/// Constructeur argless `DateTime()` (`DateTime.utc(...)`/`DateTime(args)` exclus).
final RegExp _dateTimeArgless = RegExp(r'\bDateTime\s*\(\s*\)');

/// Symboles de notification / scheduler OS BANNIS (AC5) — la planification est
/// app-side. `Timer(`/`Timer.periodic`/`Future.delayed` = planification différée.
final List<RegExp> _schedulerSymbols = <RegExp>[
  RegExp(r'flutter_local_notifications'),
  RegExp(r'awesome_notifications'),
  RegExp(r'\bworkmanager\b'),
  RegExp(r'android_alarm_manager'),
  RegExp(r'\bAndroidAlarmManager\b'),
  RegExp(r'\bTimer\s*\('),
  RegExp(r'\bTimer\s*\.\s*periodic'),
  RegExp(r'\bFuture\s*\.\s*delayed'),
];

void main() {
  group('AC5 / R5 — horloge injectée + aucun scheduler dans les fichiers ES-9.2', () {
    test('aucun `DateTime.now()` / `DateTime()` argless (commentaires dépouillés)',
        () {
      final coupables = <String>[];
      for (final path in _es92Files) {
        final src = _stripComments(File(path).readAsStringSync());
        if (_dateTimeNow.hasMatch(src) || _dateTimeArgless.hasMatch(src)) {
          coupables.add(path);
        }
      }
      expect(
        coupables,
        isEmpty,
        reason: 'AC5 : l\'horloge `now` est INJECTÉE en paramètre '
            '(pattern ZExam/aggregateDailyStudyTasks). Fautifs : $coupables',
      );
    });

    test('aucun symbole de notification / scheduler OS (planification app-side)', () {
      final coupables = <String>[];
      for (final path in _es92Files) {
        final src = _stripComments(File(path).readAsStringSync());
        for (final rx in _schedulerSymbols) {
          if (rx.hasMatch(src)) coupables.add('$path :: ${rx.pattern}');
        }
      }
      expect(
        coupables,
        isEmpty,
        reason: 'AC5/AD-26 : la programmation OS (plugin, horaire) est app-side ; '
            'le widget/section ne planifie JAMAIS. Fautifs : $coupables',
      );
    });

    // 🔴 Pouvoir du filet (R2) : les regex MORDENT sur les formes interdites et
    // ÉPARGNENT les formes autorisées (jamais un test POWERLESS).
    test('R2 — le filet a du POUVOIR (mord sur interdit, épargne autorisé)', () {
      expect(_dateTimeNow.hasMatch('final t = DateTime.now();'), isTrue);
      expect(_dateTimeArgless.hasMatch('final t = DateTime();'), isTrue);
      expect(_dateTimeNow.hasMatch('DateTime.utc(2026, 7, 16)'), isFalse);
      expect(_dateTimeArgless.hasMatch('widget.now'), isFalse);
      expect(
        _schedulerSymbols.any((r) => r.hasMatch('import "flutter_local_notifications"')),
        isTrue,
      );
      expect(
        _schedulerSymbols.any((r) => r.hasMatch('Timer(const Duration(), () {})')),
        isTrue,
      );
      // `addPostFrameCallback` (exposition post-frame) N'EST PAS un scheduler OS.
      expect(
        _schedulerSymbols.any((r) => r.hasMatch('WidgetsBinding.instance.addPostFrameCallback')),
        isFalse,
      );
    });
  });
}

/// Dépouille les commentaires (`//` et `/* */`) avant le scan tokenisé.
String _stripComments(String src) {
  final sansBlocs = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sansBlocs
      .split('\n')
      .map((l) {
        final i = l.indexOf('//');
        return i == -1 ? l : l.substring(0, i);
      })
      .join('\n');
}
