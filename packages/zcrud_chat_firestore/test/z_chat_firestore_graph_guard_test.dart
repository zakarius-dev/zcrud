// Garde structurelle du graphe (G-RC1) : ce satellite est un PUITS.
//
// Trois propriétés, toutes mesurées sur les sources réelles du dépôt :
// 1. aucune arête `zcrud_firestore → zcrud_chat*` — ni dans son
//    `pubspec.yaml`, ni dans un `import` de son `lib/` ;
// 2. ce paquet ne porte aucun code généré (`*.g.dart` / `*.freezed.dart`) ;
// 3. les imports de ce paquet se limitent à `zcrud_core`,
//    `zcrud_chat_kernel`, `zcrud_firestore`, `cloud_firestore`, `dartz`,
//    `flutter` (plus `dart:` et les imports relatifs).
//
// Chaque balayage porte une borne de NON-VACUITÉ : un chemin cassé ne peut
// pas rendre la garde verte par absence de fichiers.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Racine du dépôt, quel que soit le CWD — ancrage par remontée jusqu'à
/// `melos.yaml` (convention `melos exec` : chaque suite démarre dans le
/// dossier de SON paquet).
Directory _repoRoot() {
  Directory dir = Directory.current.absolute;
  for (int i = 0; i < 8; i++) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    final Directory parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('Racine du dépôt (melos.yaml) introuvable depuis ${Directory.current}');
}

List<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true, followLinks: false)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList();

/// Directives `import`/`export` d'une source, sous forme d'URI.
///
/// Le motif exige le mot-clé en DÉBUT de ligne : une dartdoc qui cite un
/// import (« ne jamais `import 'package:zcrud_chat…'` ») ne compte pas.
final RegExp _kDirective = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);

List<String> _directives(String source) =>
    _kDirective.allMatches(source).map((RegExpMatch m) => m.group(1)!).toList();

/// Nom du paquet d'un URI `package:`, `null` pour `dart:` et les relatifs.
String? _packageOf(String uri) {
  if (!uri.startsWith('package:')) return null;
  final String rest = uri.substring('package:'.length);
  final int slash = rest.indexOf('/');
  return slash < 0 ? rest : rest.substring(0, slash);
}

const Set<String> _kAllowedPackages = <String>{
  'zcrud_core',
  'zcrud_chat_kernel',
  'zcrud_firestore',
  'cloud_firestore',
  'dartz',
  'flutter',
};

void main() {
  late Directory root;
  late Directory firestoreLib;
  late Directory thisLib;

  setUpAll(() {
    root = _repoRoot();
    firestoreLib = Directory('${root.path}/packages/zcrud_firestore/lib');
    thisLib = Directory('${root.path}/packages/zcrud_chat_firestore/lib');
    expect(firestoreLib.existsSync(), isTrue, reason: firestoreLib.path);
    expect(thisLib.existsSync(), isTrue, reason: thisLib.path);
  });

  group('le détecteur de directives discrimine', () {
    test('un import en tête de ligne est vu, une mention en dartdoc non', () {
      expect(
        _directives("import 'package:zcrud_chat_kernel/x.dart';"),
        <String>['package:zcrud_chat_kernel/x.dart'],
      );
      expect(
        _directives("export 'src/a.dart';\n// import 'package:foo/f.dart';"),
        <String>['src/a.dart'],
      );
      expect(
        _directives("/// ne jamais `import 'package:zcrud_chat/x.dart'`"),
        isEmpty,
      );
      expect(_packageOf('package:cloud_firestore/cloud_firestore.dart'),
          'cloud_firestore');
      expect(_packageOf('dart:io'), isNull);
      expect(_packageOf('src/data/x.dart'), isNull);
    });
  });

  group('G-RC1 — aucune arête zcrud_firestore → zcrud_chat*', () {
    test('pubspec.yaml de zcrud_firestore ne cite aucun zcrud_chat*', () {
      final File pubspec =
          File('${root.path}/packages/zcrud_firestore/pubspec.yaml');
      expect(pubspec.existsSync(), isTrue);
      final List<String> offenders = pubspec
          .readAsLinesSync()
          .where((String l) => RegExp(r'^\s*zcrud_chat\w*\s*:').hasMatch(l))
          .toList();
      expect(offenders, isEmpty,
          reason: 'zcrud_firestore dépendrait du chat :\n${offenders.join('\n')}');
    });

    test('aucun import de zcrud_chat* dans packages/zcrud_firestore/lib', () {
      final List<File> files = _dartFiles(firestoreLib);
      expect(files.length, greaterThanOrEqualTo(10),
          reason: 'balayage vide : ${files.length} fichier(s)');
      int directives = 0;
      final List<String> offenders = <String>[];
      for (final File f in files) {
        for (final String uri in _directives(f.readAsStringSync())) {
          directives++;
          final String? pkg = _packageOf(uri);
          if (pkg != null && pkg.startsWith('zcrud_chat')) {
            offenders.add('${f.path.split('/packages/').last} → $uri');
          }
        }
      }
      expect(directives, greaterThanOrEqualTo(20),
          reason: 'détecteur inerte : $directives directive(s) vue(s)');
      expect(offenders, isEmpty,
          reason: 'arête interdite (AD-1) :\n  ${offenders.join('\n  ')}');
    });
  });

  group('G-RC1 — ce paquet est un puits borné', () {
    test('aucun code généré sous lib/', () {
      final List<String> generated = _dartFiles(thisLib)
          .map((File f) => f.path)
          .where((String p) => p.endsWith('.g.dart') || p.endsWith('.freezed.dart'))
          .toList();
      expect(generated, isEmpty);
    });

    test('les imports de lib/ se limitent aux paquets autorisés', () {
      final List<File> files = _dartFiles(thisLib);
      expect(files, isNotEmpty, reason: 'lib/ vide : chemin cassé ?');
      int packageDirectives = 0;
      final List<String> offenders = <String>[];
      for (final File f in files) {
        for (final String uri in _directives(f.readAsStringSync())) {
          final String? pkg = _packageOf(uri);
          if (pkg == null) continue;
          packageDirectives++;
          if (!_kAllowedPackages.contains(pkg)) {
            offenders.add('${f.path.split('/packages/').last} → $uri');
          }
        }
      }
      expect(packageDirectives, greaterThanOrEqualTo(3),
          reason: 'détecteur inerte : $packageDirectives import(s) package:');
      expect(offenders, isEmpty,
          reason: 'import hors allowlist :\n  ${offenders.join('\n  ')}');
    });

    test('le pubspec de ce paquet ne déclare que des dépendances autorisées',
        () {
      final File pubspec =
          File('${root.path}/packages/zcrud_chat_firestore/pubspec.yaml');
      final List<String> lines = pubspec.readAsLinesSync();
      final int start = lines.indexWhere((String l) => l.trim() == 'dependencies:');
      final int end = lines.indexWhere((String l) => l.trim() == 'dev_dependencies:');
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final List<String> deps = lines
          .sublist(start + 1, end)
          .map((String l) => RegExp(r'^  (\w+):').firstMatch(l)?.group(1))
          .whereType<String>()
          .toList();
      expect(deps, isNotEmpty);
      expect(
        deps.where((String d) => !_kAllowedPackages.contains(d)),
        isEmpty,
        reason: 'dépendance hors allowlist dans $deps',
      );
    });
  });
}
