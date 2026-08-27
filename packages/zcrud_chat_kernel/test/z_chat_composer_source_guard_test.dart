// Garde de SOURCE du vocabulaire de composer (`lib/src/domain/composer/`).
// Elle ne teste pas un comportement : elle teste des ABSENCES, et une absence
// n'est un constat que si un grep la prouve. C'est ce grep, rejoué par une
// machine à chaque `dart test`.
//
// Cinq propriétés :
//   (1) PURETÉ — aucune arête nouvelle : le paquet garde UNE dépendance
//       (`zcrud_core`) et le dossier n'importe que sa surface pur-Dart ;
//   (2) ATTEIGNABILITÉ — tout fichier du dossier est exporté par le barrel ;
//   (3) AD-19.1 STRUCTUREL — tout `extra` concret passe par `zSanitizeExtra`,
//       et tout `_reservedKeys` consomme `ZSyncMeta.reservedKeys` : un TYPE
//       FUTUR qui l'oublierait rougit ici, sans qu'on ait à y penser ;
//   (4) FR-26 — aucune amorce, aucun nom de commande, aucun libellé de repli
//       codés en dur : ce sont des données d'hôte ;
//   (5) AUCUNE POLITIQUE — le socle n'exécute pas et ne résout pas.
//
// ⚠️ `@TestOn('vm')` OBLIGATOIRE : cette garde lit les SOURCES du dépôt
// (`dart:io`), donc elle est incompilable en JavaScript. Sans l'annotation,
// elle rend TOUTE la suite du paquet non exécutable sous `dart test -p node`
// ⇒ gate `web` de `melos run verify` ROUGE.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

const List<String> _fichiers = <String>[
  'z_chat_draft_store.dart',
  'z_chat_mention.dart',
  'z_chat_slash_command.dart',
  'z_chat_text_measure_port.dart',
];

Directory _composerDir() => Directory(
  '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/composer',
);

List<File> _composerFiles() {
  final Directory d = _composerDir();
  expect(d.existsSync(), isTrue, reason: 'dossier `composer/` introuvable');
  final List<File> files = d
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList()
    ..sort((File a, File b) => a.path.compareTo(b.path));
  expect(files, isNotEmpty, reason: 'aucun fichier scanné : garde VACUELLE');
  return files;
}

void main() {
  group('(1) PURETÉ — aucune arête nouvelle', () {
    test('le paquet déclare EXACTEMENT une dépendance : `zcrud_core`', () {
      final File pubspec = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/pubspec.yaml',
      );
      final List<String> lignes = pubspec.readAsLinesSync();
      final int debut = lignes.indexOf('dependencies:');
      expect(debut, greaterThanOrEqualTo(0));
      final List<String> deps = <String>[];
      for (int i = debut + 1; i < lignes.length; i++) {
        final String l = lignes[i];
        if (l.trim().isEmpty || l.trimLeft().startsWith('#')) continue;
        if (!l.startsWith('  ')) break; // fin du bloc
        deps.add(l.trim().split(':').first);
      }
      expect(deps, <String>['zcrud_core'],
          reason: '🔴 arête NOUVELLE : le noyau est un PUITS du graphe (AD-1)');
    });

    test('le dossier `composer/` n\'importe que `zcrud_core/domain.dart` et '
        'ses voisins relatifs (grep négatif)', () {
      const List<String> interdits = <String>[
        'package:flutter/',
        'dart:ui',
        'dart:io',
        'package:cloud_firestore/',
        'package:firebase',
        'package:hive',
        'package:riverpod',
        'package:flutter_riverpod/',
        'package:get/',
        'package:provider/',
        'package:json_annotation/',
        'package:dartz/',
      ];
      final List<String> offenders = <String>[];
      for (final File f in _composerFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = raw.trimLeft();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          for (final String bad in interdits) {
            if (line.contains(bad)) offenders.add('${f.path}:$no: $line');
          }
          if (line.contains('package:zcrud_') &&
              !line.contains('package:zcrud_core/domain.dart')) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'AD-1/AD-14 violés :\n${offenders.join('\n')}');
    });
  });

  group('(2) ATTEIGNABILITÉ', () {
    test('chaque fichier du dossier est exporté par le barrel', () {
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/'
        'zcrud_chat_kernel.dart',
      ).readAsStringSync();
      final List<String> manquants = <String>[];
      for (final File f in _composerFiles()) {
        final String nom = f.uri.pathSegments.last;
        if (!barrel.contains("export 'src/domain/composer/$nom';")) {
          manquants.add(nom);
        }
      }
      expect(manquants, isEmpty,
          reason: '🔴 INATTEIGNABLE depuis le barrel : $manquants');
    });

    test('les quatre fichiers attendus du lot sont bien là', () {
      expect(
        _composerFiles().map((File f) => f.uri.pathSegments.last).toList(),
        containsAll(_fichiers),
      );
    });
  });

  group('(3) AD-19.1 — tout `extra` concret est filtré, structurellement', () {
    test('chaque `_reservedKeys` consomme `ZSyncMeta.reservedKeys`', () {
      int declarations = 0;
      int consommations = 0;
      final List<String> fichiersSansConsommation = <String>[];
      for (final File f in _composerFiles()) {
        final String src = f.readAsStringSync();
        final int d = 'static const Set<String> _reservedKeys'.allMatches(src)
            .length;
        final int c = '...ZSyncMeta.reservedKeys,'.allMatches(src).length;
        declarations += d;
        consommations += c;
        if (d != c) fichiersSansConsommation.add('${f.path}: $d != $c');
      }
      expect(declarations, greaterThan(0),
          reason: 'garde VACUELLE : aucun `_reservedKeys` scanné');
      expect(fichiersSansConsommation, isEmpty,
          reason: '🔴 un `_reservedKeys` ne consomme pas les clés de sync :\n'
              '${fichiersSansConsommation.join('\n')}');
      expect(consommations, declarations);
    });

    test('tout paramètre `extra` de constructeur passe par `zSanitizeExtra`',
        () {
      final List<String> offenders = <String>[];
      for (final File f in _composerFiles()) {
        final String src = f.readAsStringSync();
        final int params =
            RegExp(r'Map<String, dynamic> extra = const <String, dynamic>\{\},')
                .allMatches(src)
                .length;
        final int filtres =
            'zSanitizeExtra(extra, _reservedKeys)'.allMatches(src).length;
        final int accesseurs =
            'zNormalizeExtra(_extra, _reservedKeys)'.allMatches(src).length;
        if (params != filtres || params != accesseurs) {
          offenders.add('${f.path}: $params paramètres, $filtres assainis, '
              '$accesseurs accesseurs normalisés');
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 AD-19.1 : un `extra` concret sans filtre :\n'
              '${offenders.join('\n')}');
    });
  });

  group('(4) FR-26 — le socle ne nomme rien', () {
    test('aucune amorce codée en dur : `character` n\'a AUCUN défaut littéral',
        () {
      final RegExp defaut = RegExp(r"""character\s*=\s*['"]""");
      // Contre-preuve : le motif reconnaît bien ce qu'il prétend interdire.
      expect(defaut.hasMatch("this.character = '@',"), isTrue);
      expect(defaut.hasMatch("String character = '/';"), isTrue);
      expect(defaut.hasMatch('final String character = zJsonString(x);'),
          isFalse);
      final List<String> offenders = <String>[];
      for (final File f in _composerFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (defaut.hasMatch(line)) offenders.add('${f.path}:$no: $line');
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 FR-26 : `@` et `/` sont des DONNÉES D\'HÔTE, pas des '
              'constantes du socle :\n${offenders.join('\n')}');
    });

    test('aucun libellé de repli : le socle ne substitue jamais la clé au '
        'libellé absent', () {
      final List<String> offenders = <String>[];
      for (final File f in _composerFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (RegExp(r'label\s*\?\?').hasMatch(line) ||
              RegExp(r"""label\s*=\s*['"]\w""").hasMatch(line)) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 FR-26 : un libellé absent RESTE absent :\n'
              '${offenders.join('\n')}');
    });
  });

  group('(5) AUCUNE POLITIQUE dans le socle', () {
    test('aucun verbe d\'exécution ni de résolution : le socle transporte',
        () {
      const List<String> interdits = <String>[
        'Function() execute',
        'void execute(',
        'Future<void> execute(',
        'levenshtein',
        'fuzzy',
        'SharedPreferences',
        'openBox',
        'HttpClient',
      ];
      final List<String> offenders = <String>[];
      for (final File f in _composerFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          for (final String bad in interdits) {
            if (line.contains(bad)) offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: '🔴 politique dans le socle :\n${offenders.join('\n')}');
    });

    test('aucun codegen (AD-3) : ni `part`, ni annotation de sérialisation',
        () {
      final List<String> offenders = <String>[];
      for (final File f in _composerFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw).trimLeft();
          if (line.startsWith('part ') ||
              line.startsWith('@JsonSerializable') ||
              line.startsWith('@ZcrudModel')) {
            offenders.add('${f.path}:$no: $line');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });
}
