/// Test de graphe **anti-cycle** (SU-12, AC3, AD-40/AD-1) : l'adaptateur d'édition
/// riche vit CHEZ LE CONSOMMATEUR (`zcrud_mindmap`) au-dessus de l'arête existante
/// `zcrud_mindmap → zcrud_markdown`. L'arête INVERSE `zcrud_markdown → zcrud_mindmap`
/// doit rester **ABSENTE** — sinon cycle (AD-1). La garde prouve l'absence par
/// LECTURE RÉELLE du disque (pubspec + `lib/`), pas par affirmation.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Résout un chemin sous `packages/zcrud_markdown/` que les tests soient lancés
/// depuis le package (`../zcrud_markdown/…`) ou depuis la racine melos.
File _markdownFile(String rel) {
  const candidates = <String>[
    '../zcrud_markdown',
    'packages/zcrud_markdown',
  ];
  for (final base in candidates) {
    final f = File('$base/$rel');
    if (f.existsSync()) return f;
  }
  return File('${candidates.first}/$rel');
}

Directory _markdownDir(String rel) {
  const candidates = <String>[
    '../zcrud_markdown',
    'packages/zcrud_markdown',
  ];
  for (final base in candidates) {
    final d = Directory('$base/$rel');
    if (d.existsSync()) return d;
  }
  return Directory('${candidates.first}/$rel');
}

void main() {
  group('AC3 — graphe acyclique (AD-1/AD-40)', () {
    test('zcrud_markdown/pubspec.yaml ne dépend PAS de zcrud_mindmap', () {
      final pubspec = _markdownFile('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue,
          reason: 'pubspec zcrud_markdown introuvable — chemin de garde cassé');
      final content = pubspec.readAsStringSync();
      // Preuve d'ABSENCE par lecture réelle (équivalent grep RC=1).
      expect(content.contains('zcrud_mindmap'), isFalse,
          reason: 'arête inverse zcrud_markdown → zcrud_mindmap INTERDITE (cycle)');
    });

    test('aucun fichier lib/ de zcrud_markdown ne référence zcrud_mindmap', () {
      final libDir = _markdownDir('lib');
      expect(libDir.existsSync(), isTrue,
          reason: 'lib/ zcrud_markdown introuvable — chemin de garde cassé');
      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      var scanned = 0;
      for (final f in dartFiles) {
        scanned++;
        final s = f.readAsStringSync();
        expect(s.contains('zcrud_mindmap'), isFalse,
            reason: 'import inverse interdit dans ${f.path}');
        expect(s.contains('z_mindmap'), isFalse,
            reason: 'référence inverse interdite dans ${f.path}');
      }
      // La garde a RÉELLEMENT lu des fichiers (jamais un scan vide qui passe).
      expect(scanned, greaterThan(0),
          reason: 'aucun fichier lib/ scanné — garde vacante');
    });
  });
}
