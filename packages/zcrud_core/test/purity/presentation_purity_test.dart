// AC1/AC6 (AD-2/AD-6/AD-14/AD-15) : pureté PAR COUCHE de la couche
// `lib/src/presentation/` du cœur, + garde TRANSVERSE tout `lib/`.
//
// - `presentation/` AUTORISE `package:flutter/foundation.dart`,
//   `package:flutter/widgets.dart` ET (INFLEXION E2-8, FR-26) `package:flutter/
//   material.dart` (requis par `ThemeExtension`/`Theme.of`) ET (INFLEXION E3-2,
//   AD-2 Stack « moteur édition ») `package:form_builder_validators/` (validateurs
//   PURS `String? Function(String?)` pour la compilation des `ZValidatorSpec` —
//   PAS un gestionnaire d'état) (+ imports internes `package:zcrud_core/...` ou
//   relatifs, + `package:dartz`). INTERDITS même ici : `dart:ui` (import direct),
//   `package:flutter/cupertino.dart`, `package:flutter/services.dart`, tout
//   gestionnaire d'état (riverpod/get/provider), `flutter_form_builder` (état de
//   formulaire global — AD-2), toute dépendance lourde (Firebase/Firestore/Hive/
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

/// URI de `services.dart` — traité SPÉCIFIQUEMENT (L-2, E3-3b-1) : autorisé
/// UNIQUEMENT avec une clause `show` restreinte à [_allowedServicesSymbols] ;
/// nu ou avec un symbole hors allowlist → REJETÉ. Il est donc RETIRÉ de
/// [_forbiddenPresentation] (sinon `uri.contains` le bannirait en bloc) et géré
/// par [_servicesImportAllowed] en amont.
const _servicesUri = 'package:flutter/services.dart';

/// Symboles PURS **sans état** autorisés en `show` sur `services.dart` (L-2,
/// code-review E3-3a §3) — analogues à `form_builder_validators` (validateurs
/// purs). `Clipboard`/`SystemChannels`/`rootBundle`… (état/plateforme) restent
/// bannis (hors allowlist ⇒ rejet).
const _allowedServicesSymbols = <String>[
  'TextInputFormatter',
  'FilteringTextInputFormatter',
  'TextInputType',
];

/// Motifs d'import INTERDITS même sous `presentation/` (regex sur la ligne).
/// `material.dart` en est RETIRÉ (E2-8, FR-26) ; cupertino reste. `services.dart`
/// est géré à part (L-2, allowlist par symbole via [_servicesImportAllowed]).
const _forbiddenPresentation = <String>[
  'dart:ui',
  'package:flutter/cupertino.dart',
  'package:flutter_riverpod/',
  'package:riverpod',
  'package:get/',
  'package:provider/',
  // `flutter_form_builder` (widgets/état de formulaire global) est INTERDIT même
  // si `form_builder_validators` (validateurs purs) est autorisé (E3-2, AD-2).
  'package:flutter_form_builder',
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

/// Extrait les symboles d'une clause `show` d'une ligne d'import, ou `null` si
/// aucune clause `show` (L-2).
List<String>? _showSymbols(String line) {
  final m = RegExp(r'\bshow\b([^;]*)').firstMatch(line);
  if (m == null) return null;
  return m
      .group(1)!
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Décide si une ligne important `services.dart` est CONFORME (L-2) : autorisée
/// UNIQUEMENT avec une clause `show` **restreinte** à [_allowedServicesSymbols].
/// Retourne `null` si la ligne n'importe PAS `services.dart` (non concernée),
/// `true` si conforme, `false` si `services.dart` nu ou avec un symbole hors
/// allowlist (garde bidirectionnelle).
bool? _servicesImportAllowed(String rawLine) {
  if (_importUri(rawLine) != _servicesUri) return null;
  final symbols = _showSymbols(rawLine);
  if (symbols == null || symbols.isEmpty) return false; // nu → rejeté
  return symbols.every(_allowedServicesSymbols.contains);
}

/// Reconstruit l'instruction d'import complète à partir de [lines] et de
/// l'index [start], en concaténant les lignes jusqu'au `;` terminal (une
/// directive peut porter sa clause `show` sur la ligne suivante).
String _joinStatement(List<String> lines, int start) {
  final buffer = StringBuffer();
  for (var j = start; j < lines.length; j++) {
    buffer.write(lines[j]);
    if (lines[j].contains(';')) break;
    buffer.write(' ');
  }
  return buffer.toString();
}

void main() {
  test('imports autorisés uniquement sous lib/src/presentation (AC1/AC6)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_libSubdir('lib/src/presentation'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final raw = lines[i];
        final lineNo = i + 1;
        final uri = _importUri(raw);
        if (uri == null) continue;

        // L-2 : `services.dart` traité en amont (allowlist par symbole `show`).
        // Une directive peut s'étendre sur PLUSIEURS lignes (le `show` sur la
        // ligne suivante) : on reconstruit l'instruction complète (jusqu'au `;`)
        // avant d'évaluer la clause `show`.
        if (uri == _servicesUri) {
          final statement = _joinStatement(lines, i);
          if (!(_servicesImportAllowed(statement) ?? false)) {
            offenders.add('${file.path}:$lineNo: INTERDIT (services.dart sans '
                '`show` pur ou symbole hors allowlist) → ${statement.trim()}');
          }
          continue;
        }

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
        // INFLEXION E3-2 (AD-2, Stack « moteur édition ») : validateurs PURS de
        // `form_builder_validators` autorisés (jamais `flutter_form_builder`,
        // déjà rejeté par `_forbiddenPresentation` ci-dessus, contrôle prioritaire).
        final isFormValidators =
            uri.startsWith('package:form_builder_validators/');
        final allowed = isRelative ||
            isInternal ||
            isDartz ||
            isDartSafe ||
            isAllowedFlutter ||
            isFormValidators;
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

  // ── L-2 : garde bidirectionnelle du relâchement `services.dart` ───────────
  // Prouve que la garde AUTORISE `show <symbole pur>` et REJETTE le `services`
  // nu ou tout symbole hors allowlist (Clipboard/SystemChannels/rootBundle…).
  test('L-2 : services.dart show <symbole pur> AUTORISÉ ; nu/hors-allowlist '
      'REJETÉ (garde bidirectionnelle)', () {
    // (a) show restreint aux symboles purs → AUTORISÉ.
    expect(
      _servicesImportAllowed(
          "import 'package:flutter/services.dart' show TextInputFormatter;"),
      isTrue,
    );
    expect(
      _servicesImportAllowed("import 'package:flutter/services.dart' "
          'show FilteringTextInputFormatter, TextInputType;'),
      isTrue,
    );
    // (b) services.dart NU (sans show) → REJETÉ.
    expect(
      _servicesImportAllowed("import 'package:flutter/services.dart';"),
      isFalse,
    );
    // (c) symbole HORS allowlist → REJETÉ (même en `show`).
    expect(
      _servicesImportAllowed(
          "import 'package:flutter/services.dart' show Clipboard;"),
      isFalse,
    );
    expect(
      _servicesImportAllowed("import 'package:flutter/services.dart' "
          'show TextInputFormatter, Clipboard;'),
      isFalse,
    );
    // (d) un import NON-services n'est pas concerné (null).
    expect(
      _servicesImportAllowed("import 'package:flutter/material.dart';"),
      isNull,
    );
  });
}
