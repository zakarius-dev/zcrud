// Gardes STRUCTURELLES du vocabulaire d'outils, lues sur les SOURCES.
//
// Elles ne dupliquent pas les gardes de comportement (`z_chat_tools_test.dart`) :
// elles surveillent des propriétés qu'aucune assertion de valeur ne peut
// atteindre — l'absence d'une arête, l'absence d'un défaut de libellé,
// l'atteignabilité des types par le barrel, et l'hygiène de la dartdoc
// publiée.
//
// ⚠️ `@TestOn('vm')` OBLIGATOIRE (paquet PUR-DART) : ces gardes lisent les
// sources via `dart:io`, incompilable en JS.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

List<File> _toolFiles() {
  final Directory dir = Directory(
    '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/tools',
  );
  expect(dir.existsSync(), isTrue, reason: '${dir.path} introuvable');
  final List<File> files = dir
      .listSync()
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
  expect(files.length, greaterThanOrEqualTo(3),
      reason: 'le vocabulaire tient en au moins trois fichiers');
  return files;
}

void main() {
  group('G-T1 — AUCUNE arête de présentation dans le vocabulaire d\'outils',
      () {
    test('aucun import Flutter / dart:ui (grep négatif OUTILLÉ)', () {
      const List<String> interdits = <String>[
        'package:flutter/',
        'package:flutter_',
        'dart:ui',
      ];
      final List<String> offenders = <String>[];
      for (final File f in _toolFiles()) {
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
        }
      }
      expect(offenders, isEmpty,
          reason: 'présentation dans le domaine :\n${offenders.join('\n')}');
    });

    test('une SEULE arête sortante : `package:zcrud_core/domain.dart`', () {
      final List<String> offenders = <String>[];
      for (final File f in _toolFiles()) {
        for (final String raw in f.readAsLinesSync()) {
          final String line = raw.trimLeft();
          if (!line.startsWith('import ')) continue;
          if (!line.contains('package:')) continue;
          if (line.contains("package:zcrud_core/domain.dart")) continue;
          offenders.add('${f.path}: $line');
        }
      }
      expect(offenders, isEmpty,
          reason: 'AD-1 violé :\n${offenders.join('\n')}');
    });

    test('aucun type de rendu nommé, même sans import', () {
      // Un type de rendu peut entrer par une signature avant d'entrer par un
      // import (paramètre générique, typedef d'hôte recopié). On lit donc les
      // IDENTIFIANTS, pas seulement les directives.
      final RegExp bad = RegExp(
        r'\b(Widget|BuildContext|IconData|Color|TextStyle|EdgeInsets'
        r'|VoidCallback|ValueChanged|ChangeNotifier|ValueListenable)\b',
      );
      final List<String> offenders = <String>[];
      for (final File f in _toolFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (bad.hasMatch(line)) offenders.add('${f.path}:$no: $line');
        }
      }
      expect(offenders, isEmpty,
          reason: 'type de rendu dans le domaine :\n${offenders.join('\n')}');
    });
  });

  group('G-T2 — le vocabulaire est ATTEIGNABLE (sinon il n\'existe pas)', () {
    test('les trois fichiers sont exportés par le barrel', () {
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/zcrud_chat_kernel.dart',
      ).readAsStringSync();
      for (final String name in <String>[
        'z_chat_tool_state.dart',
        'z_chat_tool_entry.dart',
        'z_chat_tool_catalog.dart',
      ]) {
        expect(barrel.contains("export 'src/domain/tools/$name';"), isTrue,
            reason: '$name n\'est pas exporté : le type est inatteignable');
      }
    });
  });

  group('G-T3 — FR-26 : le socle ne NOMME rien à la place de l\'hôte', () {
    test('aucun libellé ni jeton de raison n\'a de valeur par défaut', () {
      // Un défaut sur `label`, `stateLabels` ou `reasonToken` ferait entrer un
      // texte du socle dans l'interface d'un hôte — précisément l'interdit.
      final RegExp defaulted = RegExp(
        r'\b(this\.)?(label|reasonToken)\s*=\s*'
        r'''(?!const <)['"]''',
      );
      final List<String> offenders = <String>[];
      for (final File f in _toolFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = stripComment(raw);
          if (defaulted.hasMatch(line)) offenders.add('${f.path}:$no: $line');
        }
      }
      expect(offenders, isEmpty,
          reason: 'libellé par défaut du socle :\n${offenders.join('\n')}');
    });

    test('les jetons du socle sont des JETONS, pas des phrases', () {
      // Un jeton d'état est une clé opaque : pas d'espace, pas de majuscule
      // initiale de phrase. S'il devenait une phrase, il serait un libellé.
      final RegExp constToken =
          RegExp(r"const String kZChatToolToken\w+\s*=\s*'([^']*)'");
      final List<String> offenders = <String>[];
      for (final File f in _toolFiles()) {
        for (final RegExpMatch m
            in constToken.allMatches(f.readAsStringSync())) {
          final String value = m.group(1)!;
          if (value.contains(' ') || value.isEmpty) {
            offenders.add('${f.path}: "$value"');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'jeton devenu libellé :\n${offenders.join('\n')}');
    });
  });

  group('G-T4 — la dartdoc publiée s\'adresse au CONSOMMATEUR', () {
    test('aucun numéro de CR, aucune version, aucun récit de lot dans un `///`',
        () {
      final RegExp interdit = RegExp(
        r'(CR-[A-Z]+-\d+|livré en v\d|\bv\d+\.\d+\.\d+\b|\blot [A-Z]\b)',
        caseSensitive: false,
      );
      final List<String> offenders = <String>[];
      for (final File f in _toolFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = raw.trimLeft();
          if (!line.startsWith('///')) continue;
          if (interdit.hasMatch(line)) offenders.add('${f.path}:$no: $line');
        }
      }
      expect(offenders, isEmpty,
          reason: 'journal de traitement en dartdoc :\n${offenders.join('\n')}');
    });
  });
}
