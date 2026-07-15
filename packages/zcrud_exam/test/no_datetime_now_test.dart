@TestOn('vm')
/// 🔴 AC10 — AUCUN `DateTime.now()` / `DateTime()` argless dans
/// `packages/zcrud_exam/lib/`, **PROUVÉ PAR MACHINE** (R5).
///
/// ## ⚠️ Pourquoi ce fichier est SÉPARÉ et taggé `@TestOn('vm')`
///
/// Ce test **lit le disque** (`dart:io`) : il ne peut pas s'exécuter sur la
/// plateforme **JS**. Or `gate:web` (`scripts/ci/gate_web_determinism.dart`) est
/// **default-ON** — il rejoue sous `dart test -p node` la suite de TOUT package
/// `packages/*` pur-Dart possédant un `test/`, donc `zcrud_exam` **dès sa
/// création**. On **tagge** (`@TestOn('vm')` + cette RAISON écrite), on n'opt-out
/// PAS du gate (patron `zcrud_note/test/source_policy_test.dart`). Les autres
/// tests (`z_exam_clock_test.dart` inclus) restent **libres de `dart:io`** ⇒ la
/// proximité d'horloge est rejouée EN JS, ce qui a une valeur réelle.
///
/// ## Méthode : scan tokenisé DOCUMENTÉ (R5, à défaut de `package:analyzer`)
///
/// `zcrud_exam` ne dépend pas de `package:analyzer` (aucune dép hors codegen —
/// AC11). On procède donc par un **scan tokenisé** : on DÉPOUILLE les commentaires
/// (les dartdoc de ce package CITENT VERBATIM `DateTime.now()` pour l'interdire —
/// sans dépouillement, le filet mordrait sur sa propre documentation), puis on
/// cherche une **invocation** `DateTime.now(` ou un **constructeur argless**
/// `DateTime()`. Les formes AUTORISÉES ne sont PAS des invocations argless :
/// `DateTime.utc(args)`, `DateTime.tryParse(...)`, le TYPE `DateTime?`,
/// `is DateTime`, `_$asDateTime` (pas de frontière de mot avant `DateTime`).
///
/// Le `.g.dart` généré est **inclus** dans le scan (il ne contient que
/// `_$asDateTime`/`DateTime.tryParse`/`is DateTime`/`DateTime?` — aucune forme
/// interdite) : aucune exclusion n'est nécessaire.
library;

import 'dart:io';

import 'package:test/test.dart';

/// Invocation `DateTime.now(` (tolère les espaces).
final RegExp _dateTimeNow = RegExp(r'\bDateTime\s*\.\s*now\s*\(');

/// Constructeur argless `DateTime()` (tolère les espaces ; `DateTime.utc(...)` et
/// `DateTime(args)` ne matchent pas).
final RegExp _dateTimeArgless = RegExp(r'\bDateTime\s*\(\s*\)');

void main() {
  group('AC10 / R5 — aucun `DateTime.now()` / `DateTime()` argless dans lib/', () {
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
        reason: 'D5 / FR-S9 : l\'horloge est INJECTÉE en paramètre (`DateTime '
            'now`). Un `DateTime.now()`/`DateTime()` argless dans le domaine est '
            'non déterministe, non testable, et littéralement banni des scripts '
            'de ce repo. Fichiers fautifs : $coupables',
      );
    });

    // 🔴 Fixture d'échec ISOLÉE (R2) — le test lui-même a du POUVOIR : sur une
    // source SIMULÉE contenant `DateTime.now()`, les regex MORDENT. (On ne
    // touche PAS au disque ; on prouve la discrimination du filet, jamais un
    // test POWERLESS — leçon DW-ES25-1/ES-2.5.)
    test('R2 — le filet MORD sur `DateTime.now()` / `DateTime()` (pouvoir)', () {
      expect(_dateTimeNow.hasMatch('final t = DateTime.now();'), isTrue);
      expect(_dateTimeArgless.hasMatch('final t = DateTime();'), isTrue);
      // …et ne mord PAS sur les formes AUTORISÉES.
      expect(_dateTimeNow.hasMatch('DateTime.utc(2026, 7, 20)'), isFalse);
      expect(_dateTimeArgless.hasMatch('DateTime.utc(2026, 7, 20)'), isFalse);
      expect(_dateTimeArgless.hasMatch('DateTime.tryParse(v)'), isFalse);
      expect(_dateTimeNow.hasMatch('DateTime? _\$asDateTime(Object? v)'), isFalse);
      expect(_dateTimeArgless.hasMatch('date as DateTime?'), isFalse);
    });
  });
}

/// Sources de `lib/`, **commentaires DÉPOUILLÉS** (`path → code`).
Map<String, String> _libSources() {
  final out = <String, String>{};
  for (final f in Directory('lib')
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
