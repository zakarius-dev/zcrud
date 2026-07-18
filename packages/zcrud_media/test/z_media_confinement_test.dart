/// 🎯 fp-4-2 (AC5) — garde de CONFINEMENT média du satellite `zcrud_media`.
///
/// 🔴 **CE TEST EST LA SEULE PROTECTION** de l'allowlist de dépendances média.
/// `scripts/dev/graph_proof.py` ne connaît QUE les arêtes inter-`zcrud_*` : il
/// ne verra JAMAIS une dépendance média interdite NON `zcrud_*` (un
/// `cunning_document_scanner`/`path_provider` qui fuirait). Sans ce fichier, le
/// confinement est déclaratif.
///
/// Patron : `zcrud_export_ui/test/z_export_ui_confinement_test.dart` (su-11) —
/// dé-commentateur **YAML** (`#`), motifs **ANCRÉS**, allowlist **DÉRIVÉE**,
/// contre-preuves **R12 mutantes**.
///
/// ## Deux volets FALSIFIABLES :
///  1. **Allowlist pubspec** : clés de `dependencies:` ⊆ [_allowedDeps] (8 EXACT :
///     `{flutter, zcrud_core}` ∪ les 6 deps média fp-4-2 ; `camera` retiré MED-3).
///  2. **Allowlist import** : aucun `import 'package:<X>/'` dans `lib/**` hors
///     [_allowedImportPkgs] (= [_allowedDeps] ∪ `{zcrud_media}`).
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _self = 'zcrud_media';

/// Les 6 deps média sanctionnées par le brief fp-4-2 (allowlist EXACTE, dérivée
/// une seule fois — pas d'énumération divergente ailleurs). MED-3 : `camera`
/// RETIRÉ (jamais importé ; capture via `image_picker`/`ImageSource.camera`).
const Set<String> _mediaDeps = <String>{
  'image_picker',
  'image_cropper',
  'video_thumbnail',
  'file_picker',
  'open_file',
  'dotted_border',
};

/// Allowlist des dépendances `pubspec` : `{flutter, zcrud_core}` ∪ [_mediaDeps]
/// (8 entrées EXACTES). Le bloc `dependencies:` en est un **sous-ensemble exact**.
const Set<String> _allowedDeps = <String>{'flutter', 'zcrud_core', ..._mediaDeps};

/// Allowlist des imports `lib/**` : deps ∪ `{zcrud_media}` (dart-core est
/// hors-scope du parseur `package:`).
const Set<String> _allowedImportPkgs = <String>{..._allowedDeps, _self};

/// Un intrus témoin **désormais réellement hors périmètre** : `cunning_document_scanner`
/// est explicitement EXCLU de l'allowlist média (ET-1) — sa présence DOIT faire
/// rougir la règle.
const String _probeIntruder = 'cunning_document_scanner';

Directory _repoRoot() {
  for (final p in <String>['.', '../..']) {
    if (Directory('$p/packages').existsSync()) return Directory(p);
  }
  fail('racine du monorepo introuvable depuis ${Directory.current.path}');
}

Directory _selfLib() {
  final d = Directory('${_repoRoot().path}/packages/$_self/lib');
  if (!d.existsSync()) fail('lib/ de $_self introuvable : ${d.path}');
  return d;
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _stripYaml(String src) => src
    .split('\n')
    .map((l) {
      final i = l.indexOf('#');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

String _stripDart(String src) => src
    .split('\n')
    .where((l) {
      final t = l.trim();
      return !t.startsWith('//') && !t.startsWith('*') && !t.startsWith('/*');
    })
    .map((l) {
      final i = l.indexOf('//');
      return i >= 0 ? l.substring(0, i) : l;
    })
    .join('\n');

Set<String> _dependencyKeys(String rawYaml) {
  final src = _stripYaml(rawYaml);
  final keys = <String>{};
  var inBlock = false;
  int? childIndent;
  final blockOpen = RegExp(r'^dependencies:\s*$');
  final topLevel = RegExp(r'^[A-Za-z_]');
  final keyLine = RegExp(r'^(\s+)([A-Za-z0-9_]+)\s*:');
  for (final raw in src.split('\n')) {
    if (raw.trim().isEmpty) continue;
    if (blockOpen.hasMatch(raw)) {
      inBlock = true;
      childIndent = null;
      continue;
    }
    if (inBlock && topLevel.hasMatch(raw)) {
      inBlock = false;
      continue;
    }
    if (!inBlock) continue;
    final m = keyLine.firstMatch(raw);
    if (m == null) continue;
    final indent = m.group(1)!.length;
    childIndent ??= indent;
    if (indent == childIndent) keys.add(m.group(2)!);
  }
  return keys;
}

Set<String> _importedPackages(String rawDart) {
  final src = _stripDart(rawDart);
  final re = RegExp(r'''import\s+['"]package:([A-Za-z0-9_]+)/''');
  return re.allMatches(src).map((m) => m.group(1)!).toSet();
}

void main() {
  group('🎯 volet 1 — allowlist des dépendances (pubspec, YAML ANCRÉ)', () {
    test('🔴 `dependencies:` de `$_self` ⊆ $_allowedDeps', () {
      final raw = File('${_repoRoot().path}/packages/$_self/pubspec.yaml')
          .readAsStringSync();
      final keys = _dependencyKeys(raw);
      expect(keys, contains('zcrud_core'),
          reason: 'le satellite DOIT dépendre de zcrud_core (AD-1)');
      final intrus = keys.difference(_allowedDeps);
      expect(intrus, isEmpty, reason: '🔴 dépendance(s) hors allowlist : $intrus');
    });

    test('🔬 R12 — la règle SAIT détecter une dépendance média interdite', () {
      final falsified = '''
name: $_self
dependencies:
  zcrud_core: ^0.2.1
  $_probeIntruder: ^12.2.1
  flutter:
    sdk: flutter
''';
      final keys = _dependencyKeys(falsified);
      expect(keys, contains(_probeIntruder),
          reason: 'témoin : le parseur voit bien l\'intrus');
      expect(keys.difference(_allowedDeps), <String>{_probeIntruder},
          reason: '🔴 un intrus DOIT ressortir de la différence à l\'allowlist');
      const legit = '''
name: zcrud_media
dependencies:
  zcrud_core: ^0.2.1
  flutter:
    sdk: flutter
''';
      expect(_dependencyKeys(legit).difference(_allowedDeps), isEmpty);
    });
  });

  group('🎯 volet 2 — allowlist des imports (lib/**, DART dé-commenté)', () {
    test('🔴 aucun `import package:<X>` hors $_allowedImportPkgs', () {
      final leaks = <String>[];
      final files = _dartFiles(_selfLib()).toList();
      expect(files, isNotEmpty,
          reason: '🔴 anti-vacuité : le scan lib/** ne voit AUCUN fichier .dart '
              '— un refactor hors du glob rendrait cette garde inopérante');
      for (final f in files) {
        final pkgs = _importedPackages(f.readAsStringSync());
        for (final p in pkgs.difference(_allowedImportPkgs)) {
          leaks.add('${f.path} -> package:$p');
        }
      }
      expect(leaks, isEmpty,
          reason: '🔴 import(s) hors allowlist :\n${leaks.join('\n')}');
    });

    test('🔬 R12 — le scan voit une VRAIE fuite et IGNORE un import légitime', () {
      final probeLeak = "import 'package:$_probeIntruder/$_probeIntruder.dart';";
      const probeOwn = "import 'package:zcrud_core/zcrud_core.dart';";
      expect(_importedPackages(probeLeak).difference(_allowedImportPkgs),
          <String>{_probeIntruder},
          reason: '🔴 une fuite `$_probeIntruder` DOIT être vue');
      expect(_importedPackages(probeOwn).difference(_allowedImportPkgs), isEmpty,
          reason: '🔴 un import légitime NE DOIT PAS être compté comme fuite');
      expect(_importedPackages('// import "package:$_probeIntruder/x.dart";'),
          isEmpty,
          reason: '🔴 un import commenté ne déclare rien');
    });
  });
}
