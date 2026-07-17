import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// T8 (AC1) — GARDE anti-`/src/` : le parcours d'étude (et tout `example/lib`
/// **ET** `example/test`) n'importe QUE des **barrels** publics
/// `package:zcrud_*/zcrud_*.dart`, jamais un chemin `/src/`.
///
/// ⚠️ Si un widget nécessaire n'était PAS exporté par son barrel, la conduite
/// EXIGÉE est de **signaler un défaut de barrel** (à corriger dans le package),
/// **jamais** de contourner par un import `src/`. Ce test rougirait sur toute
/// tentative de contournement.
///
/// 🔴 su-10 D4 — la garde couvre désormais **`lib/` ET `test/`** : AC1 nomme
/// explicitement les DEUX (« aucun import `/src/` dans `example/lib` NI
/// `example/test` »). Un futur test qui sonderait un état interne via
/// `package:zcrud_*/src/...` serait attrapé.
void main() {
  final importRe = RegExp(r'''^\s*import\s+['"]([^'"]+)['"]''');

  /// Détecte les imports `/src/` d'une **ligne** unique (siège testable du
  /// détecteur, pour prouver qu'il n'est pas inerte — R3).
  String? srcImportOf(String line) {
    final m = importRe.firstMatch(line);
    if (m == null) return null;
    final uri = m.group(1)!;
    return uri.contains('/src/') ? uri : null;
  }

  /// Scanne récursivement les [dirs] et renvoie tous les imports `/src/` trouvés.
  List<String> srcImportsUnder(List<String> dirs) {
    final hits = <String>[];
    for (final dir in dirs) {
      final root = Directory(dir);
      if (!root.existsSync()) continue;
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (srcImportOf(lines[i]) != null) {
            hits.add('${entity.path}:${i + 1} → ${lines[i].trim()}');
          }
        }
      }
    }
    return hits;
  }

  test('aucun import `/src/` dans example/lib ET example/test (barrels publics '
      'seuls, AC1)', () {
    final srcImports = srcImportsUnder(<String>['lib', 'test']);
    expect(
      srcImports,
      isEmpty,
      reason: 'Import(s) `/src/` détecté(s) — un widget non exporté est un '
          'DÉFAUT DE BARREL à corriger dans le package, jamais à contourner :\n'
          '${srcImports.join('\n')}',
    );
  });

  test('🔴 le détecteur N\'EST PAS inerte : il flaggue un import `/src/` '
      '(y compris depuis test/) — sinon la garde ci-dessus serait infalsifiable',
      () {
    // Ligne synthétique telle qu'un test pourrait la contenir : le détecteur
    // DOIT la repérer, faute de quoi une vraie violation dans `test/` passerait.
    expect(
      srcImportOf("import 'package:zcrud_session/src/presentation/z_x.dart';"),
      isNotNull,
    );
    // Un barrel public légitime ne doit PAS être flaggué (pas de faux positif).
    expect(srcImportOf("import 'package:zcrud_session/zcrud_session.dart';"),
        isNull);
    // Un commentaire mentionnant `/src/` ne doit PAS être flaggué.
    expect(srcImportOf('// jamais un import /src/ ici'), isNull);
  });

  test('les fichiers du parcours d\'étude existent (surface assemblée)', () {
    for (final path in <String>[
      'lib/demos/study_session_demo_screen.dart',
      'lib/demos/fakes/in_memory_study_store.dart',
      'lib/demos/fakes/fake_flashcard_hint_port.dart',
      'lib/demos/fakes/fake_answer_evaluation_port.dart',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path manquant');
    }
  });
}
