// E2-9 AC8 : garde d'ISOLEMENT D'IDIOME — le code manager-spécifique d'un AUTRE
// binding (Riverpod/provider) n'apparaît JAMAIS dans `zcrud_get/lib`. GetX/get_it
// sont les seuls idiomes de manager autorisés ici.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Localise `lib/` quel que soit le CWD (racine repo ou dossier du package).
Directory _libDir() {
  for (final base in <String>['', 'packages/zcrud_get/']) {
    final dir = Directory('${base}lib');
    if (dir.existsSync()) return dir;
  }
  fail('lib/ introuvable depuis ${Directory.current.path}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

String _stripComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9_]').hasMatch(c);

/// `true` si [needle] apparaît dans [line] borné par des non-mots (évite les
/// faux positifs sur les sous-chaînes, ex. `ProviderScope` dans `ZcrudProviderScope`).
bool _containsToken(String line, String needle) {
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

void main() {
  // Idiomes/imports d'AUTRES managers, interdits dans zcrud_get.
  const forbidden = <String>[
    'package:flutter_riverpod',
    'package:riverpod',
    'package:provider/',
    'ProviderScope',
    'ChangeNotifierProvider',
    'ProviderContainer',
    'WidgetRef',
    'Provider.of',
    'context.read',
    'context.watch',
  ];

  test('zcrud_get/lib ne contient aucun idiome Riverpod/provider (AC8)', () {
    final offenders = <String>[];
    for (final file in _dartFiles(_libDir())) {
      var lineNo = 0;
      for (final raw in file.readAsLinesSync()) {
        lineNo++;
        final line = _stripComment(raw);
        for (final token in forbidden) {
          if (_containsToken(line, token)) {
            offenders.add('${file.path}:$lineNo: $token → ${line.trim()}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Idiomes d\'un autre manager dans zcrud_get:\n'
            '${offenders.join('\n')}');
  });
}
