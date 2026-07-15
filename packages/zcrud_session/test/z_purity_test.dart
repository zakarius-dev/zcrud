/// Garde de PURETÉ (AC1, AD-2/AD-23/NFR-S5) — scan d'imports du **runtime**.
///
/// `ZStudySessionEngine` (et tout le runtime `lib/src/domain/`) doit être une
/// classe PURE, **zéro gestionnaire d'état** et **zéro widget** : la réactivité
/// est Flutter-native (`ChangeNotifier` ∈ `package:flutter/foundation.dart`
/// SEULE). Ce test **lit les sources** du runtime et ROUGIT si un import banni
/// apparaît (`flutter_riverpod`, `get`, `provider`, ou les surfaces widget
/// `flutter/material`/`flutter/widgets`).
///
/// 🔴 ES-4.5 — la surface de PRÉSENTATION `lib/src/presentation/` (widgets
/// `ZSrsQualityButtons`/`ZSessionQualityBreakdown`/`ZStudyProgressRings`)
/// importe LÉGITIMEMENT `flutter/material` (AD-2 : widgets PURS de présentation).
/// Elle est donc EXCLUE de ce scan « runtime widget-free » ; sa propre garde de
/// pureté (aucun moteur importé, aucun gestionnaire d'état, aucune écriture SRS)
/// vit dans `presentation/z_widgets_purity_test.dart` (AC9).
///
/// ⚠️ Ce fichier accède au **système de fichiers** (`dart:io`) pour lire les
/// sources ⇒ `@TestOn('vm')`. `zcrud_session` étant un paquet **Flutter**
/// (ChangeNotifier), il est de toute façon HORS cible du `gate:web` (pur-Dart
/// only) — aucune contrainte de déterminisme web.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Imports **interdits** dans le runtime (regex sur la ligne `import`).
const List<String> _bannedImports = <String>[
  'package:flutter_riverpod/',
  'package:riverpod/',
  'package:get/',
  'package:provider/',
  'package:flutter/material.dart',
  'package:flutter/widgets.dart',
  'package:flutter/cupertino.dart',
];

void main() {
  test('AC1 — aucun import de gestionnaire d\'état / widget dans le runtime', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'répertoire lib/ introuvable (cwd = ${Directory.current.path})');

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        // Runtime SEUL : la surface présentation (widgets Material PURS, ES-4.5)
        // est exclue — sa garde de pureté dédiée vit dans presentation/ (AC9).
        .where((f) => !f.path.replaceAll(r'\', '/').contains('/presentation/'))
        .toList();

    // Contre-preuve R12 : le scan DOIT réellement voir des fichiers.
    expect(dartFiles, isNotEmpty, reason: 'aucun fichier .dart scanné');

    final violations = <String>[];
    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (!line.startsWith('import ') && !line.startsWith('export ')) {
          continue;
        }
        for (final banned in _bannedImports) {
          if (line.contains(banned)) {
            violations.add('${file.path}:${i + 1} → $line');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: 'imports bannis (gestionnaire d\'état / widget) détectés :\n'
          '${violations.join('\n')}',
    );
  });
}
