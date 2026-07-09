// AC1/AC6 (AD-2/AD-6/AD-14/AD-15) : pureté PAR COUCHE de la couche
// `lib/src/presentation/` du cœur, + garde TRANSVERSE tout `lib/`.
//
// - `presentation/` AUTORISE `package:flutter/foundation.dart`,
//   `package:flutter/widgets.dart` ET (INFLEXION E2-8, FR-26) `package:flutter/
//   material.dart` (requis par `ThemeExtension`/`Theme.of`) (+ imports internes
//   `package:zcrud_core/...` ou relatifs, + `package:dartz`). INTERDITS même
//   ici : `dart:ui` (import direct), `package:flutter/cupertino.dart`,
//   `package:flutter/services.dart`, tout gestionnaire d'état
//   (riverpod/get/provider), toute dépendance lourde (Firebase/Firestore/Hive/
//   Syncfusion/Quill/Maps).
// - Transverse à TOUT `lib/` : 0 occurrence TEXTUELLE (hors commentaires) des
//   tokens `WidgetRef`, `Get.find`, `Get.put`, `Provider.of` (AD-6) ET
//   `lex_localizations`, `go_router`, `GoRouter`, `context.l10n` (AD-13, AC8).
//
// Test pur-fichiers (`package:test`) : tourne sous `flutter test` comme les
// autres tests de zcrud_core (le package est désormais Flutter).
import 'dart:io';

import 'package:test/test.dart';

/// URIs `package:flutter/*` AUTORISÉES sous `presentation/` (material : E2-8).
const _allowedFlutter = <String>[
  'package:flutter/foundation.dart',
  'package:flutter/widgets.dart',
  'package:flutter/material.dart',
];

/// Motifs d'import INTERDITS même sous `presentation/` (regex sur la ligne).
/// `material.dart` en est RETIRÉ (E2-8, FR-26) ; cupertino/services restent.
const _forbiddenPresentation = <String>[
  'dart:ui',
  'package:flutter/cupertino.dart',
  'package:flutter/services.dart',
  'package:flutter_riverpod/',
  'package:riverpod',
  'package:get/',
  'package:provider/',
  'package:cloud_firestore/',
  'package:firebase',
  'package:hive',
  'package:syncfusion',
  'package:flutter_quill',
  'package:google_maps',
];

/// Tokens INTERDITS TEXTUELLEMENT dans tout `lib/` : gestionnaires d'état (AD-6)
/// + l10n/routing app-spécifique (AD-13, AC8).
const _forbiddenTokens = <String>[
  'WidgetRef',
  'Get.find',
  'Get.put',
  'Provider.of',
  'lex_localizations',
  'go_router',
  'GoRouter',
  'context.l10n',
];

/// Localise un sous-répertoire de `lib/` quel que soit le CWD.
Directory _libSubdir(String rel) {
  for (final base in <String>['', 'packages/zcrud_core/']) {
    final dir = Directory('$base$rel');
    if (dir.existsSync()) return dir;
  }
  fail('Répertoire $rel introuvable depuis ${Directory.current.path}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Retire la partie commentaire d'une ligne (tout à partir de `//`).
String _stripComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9_]').hasMatch(c);

/// `true` si [needle] apparaît dans [line] borné par des non-mots.
bool _containsWord(String line, String needle) {
  var from = 0;
  while (true) {
    final i = line.indexOf(needle, from);
    if (i < 0) return false;
    final before = i == 0 ? '' : line[i - 1];
    final afterIdx = i + needle.length;
    final after = afterIdx >= line.length ? '' : line[afterIdx];
    final okBefore = before.isEmpty || !_isWordChar(before);
    final okAfter = after.isEmpty || !_isWordChar(after);
    if (okBefore && okAfter) return true;
    from = i + 1;
  }
}

/// Extrait l'URI d'une ligne `import '...'` / `export '...'`, ou `null`.
String? _importUri(String line) {
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
    return null;
  }
  final m = RegExp("['\"]([^'\"]+)['\"]").firstMatch(trimmed);
  return m?.group(1);
}

void main() {
  test('imports autorisés uniquement sous lib/src/presentation (AC1/AC6)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_libSubdir('lib/src/presentation'))) {
      var lineNo = 0;
      for (final raw in file.readAsLinesSync()) {
        lineNo++;
        final uri = _importUri(raw);
        if (uri == null) continue;

        // Interdits explicites d'abord (message clair).
        final forbidden = _forbiddenPresentation.any(uri.contains);
        if (forbidden) {
          offenders.add('${file.path}:$lineNo: INTERDIT → $uri');
          continue;
        }

        // Whitelist : relatif, package interne, dartz, flutter foundation/widgets.
        final isRelative = !uri.startsWith('package:') && !uri.startsWith('dart:');
        final isInternal = uri.startsWith('package:zcrud_core/');
        final isDartz = uri.startsWith('package:dartz');
        final isDartSafe = uri.startsWith('dart:') && uri != 'dart:ui';
        final isAllowedFlutter = _allowedFlutter.contains(uri);
        final allowed = isRelative ||
            isInternal ||
            isDartz ||
            isDartSafe ||
            isAllowedFlutter;
        if (!allowed) {
          offenders.add('${file.path}:$lineNo: NON AUTORISÉ → $uri');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Imports non conformes sous presentation/:\n'
            '${offenders.join('\n')}');
  });

  test('aucun token de gestionnaire d\'état dans tout lib/ (AC6/AD-6)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_libSubdir('lib'))) {
      var lineNo = 0;
      for (final raw in file.readAsLinesSync()) {
        lineNo++;
        final line = _stripComment(raw);
        for (final token in _forbiddenTokens) {
          if (_containsWord(line, token)) {
            offenders.add('${file.path}:$lineNo: $token → $line');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Tokens de gestionnaire d\'état interdits (AD-6):\n'
            '${offenders.join('\n')}');
  });
}
