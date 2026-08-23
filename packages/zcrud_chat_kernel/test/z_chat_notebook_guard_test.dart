@TestOn('vm')
library;

// Gardes de SOURCE du vocabulaire du fil de travail (`domain/notebook/`) :
// pureté Dart, atteignabilité par le barrel, dartdoc adressée au consommateur,
// aucun libellé par défaut, et couverture EXHAUSTIVE de l'exécuteur par défaut
// (chaque membre abstrait des deux interfaces est redéfini, et refusé).
import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

Directory _notebookDir() => Directory(
      '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/notebook',
    );

List<File> _notebookFiles() => _notebookDir()
    .listSync()
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .toList()
  ..sort((File a, File b) => a.path.compareTo(b.path));

String _strip(String line) {
  final int i = line.indexOf('//');
  return i < 0 ? line : line.substring(0, i);
}

void main() {
  test('le dossier existe et porte les sept fichiers du vocabulaire', () {
    expect(_notebookDir().existsSync(), isTrue);
    expect(
      _notebookFiles().map((File f) => f.uri.pathSegments.last),
      <String>[
        'z_chat_artifact_declaration.dart',
        'z_chat_artifact_generation_port.dart',
        'z_chat_artifact_status.dart',
        'z_chat_artifact_store_port.dart',
        'z_chat_notebook_defaults.dart',
        'z_chat_transcript_port.dart',
        'z_chat_unsupported_action_executor.dart',
      ],
    );
  });

  group('G-N1 — PUR-DART : une seule arête sortante, aucun type de rendu', () {
    test('aucun import Flutter / dart:ui / paquet zcrud autre que le cœur', () {
      final List<String> offenders = <String>[];
      for (final File f in _notebookFiles()) {
        for (final String raw in f.readAsLinesSync()) {
          final String line = raw.trimLeft();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          if (line.contains('package:flutter') ||
              line.contains('dart:ui') ||
              (line.contains('package:zcrud_') &&
                  !line.contains('package:zcrud_core/domain.dart'))) {
            offenders.add('${f.path}: $line');
          }
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('aucun IconData / Color / Widget / BuildContext, même sans import', () {
      final RegExp rendering =
          RegExp(r'\b(IconData|Color|Colors|Widget|BuildContext|Icons)\b');
      final List<String> offenders = <String>[];
      for (final File f in _notebookFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = _strip(raw);
          if (rendering.hasMatch(line)) offenders.add('${f.path}:$no: $line');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('G-N2 — ATTEIGNABLE : tout fichier du dossier est exporté', () {
    test('le barrel exporte chaque fichier de notebook/', () {
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/zcrud_chat_kernel.dart',
      ).readAsStringSync();
      for (final File f in _notebookFiles()) {
        final String name = f.uri.pathSegments.last;
        expect(barrel, contains("export 'src/domain/notebook/$name';"),
            reason: '$name est INATTEIGNABLE par le consommateur');
      }
    });
  });

  group('G-N3 — la dartdoc s\'adresse au CONSOMMATEUR', () {
    test('aucun numéro de CR, version, récit de lot ou nom d\'hôte en `///`',
        () {
      final RegExp interdit = RegExp(
        r'(CR-[A-Z]+-\d+|livré en v\d|\bv\d+\.\d+\.\d+\b|\blot [A-Z]\b'
        r'|\bIFFD\b|\blex_douane\b|\bDODLP\b)',
        caseSensitive: false,
      );
      final List<String> offenders = <String>[];
      for (final File f in _notebookFiles()) {
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

  group('G-N4 — FR-26 : le socle ne NOMME rien', () {
    test('aucun jeton de libellé / icône / accent n\'a de valeur par défaut',
        () {
      final RegExp defaulted = RegExp(
        r'\b(this\.)?(labelToken|iconKey|accentToken|confirmToken)\s*=\s*'
        r'''['"]''',
      );
      final List<String> offenders = <String>[];
      for (final File f in _notebookFiles()) {
        int no = 0;
        for (final String raw in f.readAsLinesSync()) {
          no++;
          final String line = _strip(raw);
          if (defaulted.hasMatch(line)) offenders.add('${f.path}:$no: $line');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('G-N5 — l\'exécuteur par défaut couvre CHAQUE membre des interfaces',
      () {
    test('tout membre abstrait de ZChatActionExecutor et de '
        'ZChatSettingsAwareActionExecutor est redéfini ET refusé nommément', () {
      final String contract = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/action/'
        'z_chat_action_executor.dart',
      ).readAsStringSync();
      final RegExp member = RegExp(r'Future<ZResult<[^>]+(?:>)?>>\s+(\w+)\(');
      final Set<String> declared = <String>{
        for (final RegExpMatch m in member.allMatches(contract)) m.group(1)!,
      };
      expect(declared.length, greaterThanOrEqualTo(8),
          reason: 'le contrat doit porter au moins 7 + 1 membres');

      final String impl = File(
        '${_notebookDir().path}/z_chat_unsupported_action_executor.dart',
      ).readAsStringSync();
      for (final String name in declared) {
        expect(impl, contains(' $name('),
            reason: '`$name` n\'est pas redéfini par l\'exécuteur par défaut');
        expect(impl, contains("refuse<") , reason: 'helper de refus absent');
        expect(impl, contains("'$name'"),
            reason: '`$name` n\'est pas refusé sous son PROPRE nom');
      }
      // Aucun succès factice : pas un seul `Right(` dans le fichier.
      final List<String> rights = <String>[
        for (final String l in impl.split('\n'))
          if (_strip(l).contains('Right')) l,
      ];
      expect(rights, isEmpty,
          reason: 'un succès factice dans l\'exécuteur par défaut :\n'
              '${rights.join('\n')}');
    });
  });

  group('G-N6 — la séquence de génération DÉMARQUE dans un `finally`', () {
    test('le démarquage vit dans un bloc finally, pas sur un chemin heureux',
        () {
      final String src = File(
        '${_notebookDir().path}/z_chat_artifact_generation_port.dart',
      ).readAsStringSync();
      final RegExp finallyUnmark =
          RegExp(r'finally\s*\{[^}]*busy:\s*false', dotAll: true);
      expect(finallyUnmark.hasMatch(src), isTrue,
          reason: 'le démarquage doit être inconditionnel (finally)');
      // Aucun `catch (_)` muet : chaque capture nomme son erreur et la rend.
      expect(src.contains('catch (_)'), isFalse,
          reason: 'une capture muette avalerait l\'échec');
    });
  });
}
