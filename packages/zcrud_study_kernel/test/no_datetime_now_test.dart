@TestOn('vm')
/// 🔴 AC12 — AUCUN `DateTime.now()` / `DateTime()` argless dans
/// `packages/zcrud_study_kernel/lib/`, **PROUVÉ PAR MACHINE** (R5, D9).
///
/// ## ⚠️ Pourquoi ce fichier est SÉPARÉ et taggé `@TestOn('vm')`
///
/// Ce test **lit le disque** (`dart:io`) : il ne peut pas s'exécuter sur la
/// plateforme **JS**. Or `gate:web` (`scripts/ci/gate_web_determinism.dart`) est
/// **default-ON** — il rejoue sous `dart test -p node` la suite de TOUT package
/// pur-Dart possédant un `test/`. On **tagge** (`@TestOn('vm')` + cette RAISON
/// écrite), on n'opt-out PAS du gate (patron
/// `zcrud_exam/test/no_datetime_now_test.dart`). Les autres tests du kernel
/// restent **libres de `dart:io`** ⇒ le balayage d'horloge de
/// `aggregateDailyStudyTasks` est rejoué EN JS (valeur réelle).
///
/// `aggregateDailyStudyTasks` est la **PREMIÈRE fonction horloge-dépendante du
/// kernel** : le harnais de pureté existant (`z_kernel_purity_test.dart`) ne
/// scanne QUE Flutter/`Color`/`IconData` — il ne couvre PAS `DateTime.now()`.
///
/// ## Méthode : scan tokenisé DOCUMENTÉ (R5, à défaut de `package:analyzer`)
///
/// Le kernel ne dépend pas de `package:analyzer` (aucune dép hors codegen). On
/// procède par **scan tokenisé** : on DÉPOUILLE les commentaires (les dartdoc de
/// ce package CITENT VERBATIM `DateTime.now()` pour l'interdire — sans
/// dépouillement, le filet mordrait sur sa propre documentation), puis on cherche
/// une **invocation** `DateTime.now(` ou un **constructeur argless** `DateTime()`.
///
/// ## ⚠️ Portée HONNÊTE (leçon LOW-1 d'ES-2.6 — ne pas surpromettre)
///
/// Ce scan tokenisé attrape les formes **littérales** `DateTime.now(` et
/// `DateTime()`. Il **N'attrape PAS** un **tearoff** (`final f = DateTime.now;`
/// sans parenthèses) ni un accès par réflexion/alias — un scan lexical ne peut
/// pas les distinguer sans un vrai AST. Les formes AUTORISÉES légitimes ne
/// matchent pas : `DateTime.utc(args)`, `DateTime.tryParse(...)`, le TYPE
/// `DateTime?`, `is DateTime`. C'est un **filet de régression** raisonnable, pas
/// une preuve d'absence absolue.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Invocation `DateTime.now(` (tolère les espaces).
final RegExp _dateTimeNow = RegExp(r'\bDateTime\s*\.\s*now\s*\(');

/// Constructeur argless `DateTime()` (tolère les espaces ; `DateTime.utc(...)` et
/// `DateTime(args)` ne matchent pas).
final RegExp _dateTimeArgless = RegExp(r'\bDateTime\s*\(\s*\)');

void main() {
  group('AC12 / R5 — aucun `DateTime.now()` / `DateTime()` argless dans lib/',
      () {
    test('scan tokenisé de tout lib/ (commentaires dépouillés)', () {
      final coupables = <String>[];
      _libSources().forEach((path, src) {
        if (_dateTimeNow.hasMatch(src) || _dateTimeArgless.hasMatch(src)) {
          coupables.add(path);
        }
      });
      expect(
        coupables,
        isEmpty,
        reason: 'D4 / FR-S10 : l\'horloge est INJECTÉE en paramètre (`DateTime '
            'now`). Un `DateTime.now()`/`DateTime()` argless dans le domaine est '
            'non déterministe, non testable, et littéralement banni des scripts '
            'de ce repo. Fichiers fautifs : $coupables',
      );
    });

    test('méta-garde : le scan couvre bien les 3 fichiers ES-2.7', () {
      final paths = _libSources().keys.toList();
      for (final expected in <String>[
        'aggregate_daily_study_tasks.dart',
        'z_daily_study_task.dart',
        'z_study_session_result.dart',
      ]) {
        expect(
          paths.any((p) => p.endsWith(expected)),
          isTrue,
          reason: '$expected doit être couvert par le scan anti-DateTime.now()',
        );
      }
    });

    // 🔴 Fixture d'échec ISOLÉE (R2) — le filet a du POUVOIR : sur une source
    // SIMULÉE contenant `DateTime.now()`, les regex MORDENT. (On ne touche PAS au
    // disque ; on prouve la discrimination, jamais un test POWERLESS —
    // leçon DW-ES25-1/ES-2.5.)
    test('R2 — le filet MORD sur `DateTime.now()` / `DateTime()` (pouvoir)', () {
      expect(_dateTimeNow.hasMatch('final t = DateTime.now();'), isTrue);
      expect(_dateTimeArgless.hasMatch('final t = DateTime();'), isTrue);
      // …et ne mord PAS sur les formes AUTORISÉES.
      expect(_dateTimeNow.hasMatch('DateTime.utc(2026, 7, 20)'), isFalse);
      expect(_dateTimeArgless.hasMatch('DateTime.utc(2026, 7, 20)'), isFalse);
      expect(_dateTimeArgless.hasMatch('DateTime.tryParse(v)'), isFalse);
      expect(_dateTimeArgless.hasMatch('date as DateTime?'), isFalse);
    });
  });
}

/// Racine `lib/` de `zcrud_study_kernel`, quel que soit le CWD du run
/// (`dart test` depuis le package OU depuis la racine du repo).
Directory _kernelLibDir() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final nested =
        Directory('${dir.path}/packages/zcrud_study_kernel/lib');
    if (nested.existsSync()) return nested;
    final direct = Directory('${dir.path}/lib');
    if (direct.existsSync() &&
        File('${dir.path}/lib/zcrud_study_kernel.dart').existsSync()) {
      return direct;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('lib/ de zcrud_study_kernel introuvable depuis ${Directory.current.path}');
}

/// Sources de `lib/`, **commentaires DÉPOUILLÉS** (`path → code`).
Map<String, String> _libSources() {
  final out = <String, String>{};
  for (final f in _kernelLibDir()
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    out[f.path] = _stripComments(f.readAsStringSync());
  }
  return out;
}

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
