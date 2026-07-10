// AC1 (AD-1 / AD-14 / AD-5) : la couche `lib/src/domain/` de `zcrud_core` reste
// PUR-DART. Ce test lit tous les `.dart` du domaine et asserte qu'aucun n'importe
// Flutter, dart:ui, Firebase/Firestore, Hive, ni un gestionnaire d'état. Le seul
// import externe autorisé est `package:dartz`.
//
// E2-2 élargit la garde : (a) 0 occurrence TEXTUELLE d'un type backend
// (`Timestamp`/`Filter`/`FirebaseException`/`DocumentSnapshot`/…), et (b) 0
// identifiant de type non préfixé `Z` fusionné (`DataRequest`/`DataState`/`ZQuery`)
// — finding readiness #15.
import 'dart:io';

import 'package:test/test.dart';

/// Motifs d'import INTERDITS dans la couche domaine (regex sur la ligne d'import).
const _forbidden = <String>[
  'package:flutter/',
  'dart:ui',
  'package:cloud_firestore/',
  'package:firebase',
  'package:hive',
  'package:flutter_riverpod/',
  'package:riverpod',
  'package:get/',
  'package:provider/',
];

/// Types backend qui ne doivent JAMAIS apparaître TEXTUELLEMENT (AD-5). Bornés
/// par des délimiteurs de mot pour éviter les faux positifs.
const _forbiddenBackendTypes = <String>[
  'Timestamp',
  'Filter',
  'FirebaseException',
  'DocumentSnapshot',
  'QuerySnapshot',
  'CollectionReference',
];

/// Identifiants de type NON préfixés `Z` fusionnés en E2-2 (finding #15). Aucun
/// ne doit être déclaré ni référencé dans le domaine.
const _forbiddenLegacyTypes = <String>[
  'DataRequest',
  'DataState',
  'ZQuery',
];

/// Localise les couches PUR-DART (`lib/src/domain/` + `lib/src/data/` si créé)
/// quel que soit le CWD (racine du workspace ou package). E2-7 : l'ajout du SDK
/// Flutter au package NE DOIT PAS faire fuiter Flutter dans ces couches — ce
/// test échoue si un `import 'package:flutter/...'` y apparaît.
List<Directory> _pureDirs() {
  final dirs = <Directory>[];
  for (final rel in <String>['lib/src/domain', 'lib/src/data']) {
    for (final base in <String>['', 'packages/zcrud_core/']) {
      final dir = Directory('$base$rel');
      if (dir.existsSync()) {
        dirs.add(dir);
        break;
      }
    }
  }
  if (dirs.isEmpty) {
    fail('Répertoire lib/src/domain introuvable depuis ${Directory.current.path}');
  }
  return dirs;
}

/// `true` si [needle] apparaît dans [line] borné par des non-mots (word boundary
/// maison — `\b` évitant les sous-chaînes comme `ZDataRequest` contenant
/// `DataRequest`).
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

bool _isWordChar(String c) => RegExp(r'[A-Za-z0-9_]').hasMatch(c);

/// Retire la partie commentaire d'une ligne (tout à partir de `//`, ce qui
/// couvre les doc-comments `///`). Les checks de tokens ciblent le **code**, pas
/// la prose : les docstrings mentionnent légitimement les types interdits pour
/// documenter qu'ils ne doivent jamais apparaître.
String _stripComment(String line) {
  final i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

List<File> _domainDartFiles() => _pureDirs()
    .expand((d) => d.listSync(recursive: true, followLinks: false))
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

void main() {
  test('aucun import interdit sous lib/src/domain (AC1)', () {
    final offenders = <String>[];
    for (final ent in _domainDartFiles()) {
      for (final line in ent.readAsLinesSync()) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        for (final bad in _forbidden) {
          if (trimmed.contains(bad)) offenders.add('${ent.path}: $trimmed');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Imports interdits dans le domaine:\n${offenders.join('\n')}');
  });

  test('aucun type backend en clair sous lib/src/domain (AC1/AD-5)', () {
    final offenders = <String>[];
    for (final ent in _domainDartFiles()) {
      var lineNo = 0;
      for (final rawLine in ent.readAsLinesSync()) {
        lineNo++;
        final line = _stripComment(rawLine);
        for (final bad in _forbiddenBackendTypes) {
          if (_containsWord(line, bad)) {
            offenders.add('${ent.path}:$lineNo: $bad → $line');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Types backend en clair (AD-5):\n${offenders.join('\n')}');
  });

  test('les points d\'entrée PURS (domain.dart, edition.dart) sans import Flutter',
      () {
    // Le barrel principal `zcrud_core.dart` tire Flutter (présentation) — normal.
    // Mais les entrypoints PURS destinés aux couches domaine des satellites
    // (AD-14) ne doivent JAMAIS exporter/importer un lib Flutter/backend/manager.
    final offenders = <String>[];
    for (final rel in <String>['lib/domain.dart', 'lib/edition.dart']) {
      File? file;
      for (final base in <String>['', 'packages/zcrud_core/']) {
        final f = File('$base$rel');
        if (f.existsSync()) {
          file = f;
          break;
        }
      }
      if (file == null) continue;
      for (final line in file.readAsLinesSync()) {
        final trimmed = line.trimLeft();
        if (!trimmed.startsWith('import ') && !trimmed.startsWith('export ')) {
          continue;
        }
        for (final bad in _forbidden) {
          if (trimmed.contains(bad)) offenders.add('$rel: $trimmed');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Entrée pure avec dépendance Flutter/backend:\n'
            '${offenders.join('\n')}');
  });

  test('aucun identifiant de type non-Z fusionné (finding #15)', () {
    final offenders = <String>[];
    for (final ent in _domainDartFiles()) {
      var lineNo = 0;
      for (final rawLine in ent.readAsLinesSync()) {
        lineNo++;
        final line = _stripComment(rawLine);
        for (final bad in _forbiddenLegacyTypes) {
          if (_containsWord(line, bad)) {
            offenders.add('${ent.path}:$lineNo: $bad → $line');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Noms non préfixés Z / ZQuery interdits (finding #15):\n'
            '${offenders.join('\n')}');
  });
}
