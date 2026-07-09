// E2-9 AC8 : garde d'ISOLEMENT D'IDIOME — aucun idiome GetX/get_it/provider dans
// `zcrud_riverpod/lib`. Riverpod est le seul manager autorisé ici.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Directory _libDir() {
  for (final base in <String>['', 'packages/zcrud_riverpod/']) {
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
/// faux positifs sur les sous-chaînes).
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
  const forbidden = <String>[
    'package:get/',
    'package:get_it',
    'package:provider/',
    'Get.find',
    'Get.put',
    'GetIt',
    'ChangeNotifierProvider',
    'context.read',
    'context.watch',
    'Provider.of',
  ];

  test('zcrud_riverpod/lib ne contient aucun idiome GetX/get_it/provider (AC8)',
      () {
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
        reason: 'Idiomes d\'un autre manager dans zcrud_riverpod:\n'
            '${offenders.join('\n')}');
  });
}
