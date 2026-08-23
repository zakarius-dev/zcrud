@TestOn('vm')
library;

// Gardes de SOURCE du catalogue assemblé (`domain/route/catalog/`) :
//   G-RC7 pureté : aucun `dart:io`, aucune bibliothèque HTTP (`http`, `dio`),
//         aucun Flutter, une seule arête zcrud (`zcrud_core/domain.dart`) ;
//   G-RC8 chaque fichier du dossier est exporté par le barrel, en ordre ;
//   G-RC9 la dartdoc s'adresse au consommateur (ni CR, ni version, ni hôte) ;
//   G-RC10 FR-26 : aucun identifiant de routeur, fournisseur, plan ni clé de
//          tâche d'hôte dans le CODE — les presets de FORME ne portent que
//          des clés de DOCUMENT, jamais une valeur ; le repli n'est jamais
//          synthétisé par le socle (`fallback` nullable, aucun défaut).
//
// R3 rejouée sur chaque garde (injection → rouge PAR ASSERTION → restauration
// par copie → sha256) : consignée dans le rapport du lot.
import 'dart:io';

import 'package:test/test.dart';

import 'support/z_repo_sources.dart';

Directory _catalogDir() => Directory(
  '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/route/catalog',
);

List<File> _catalogFiles() =>
    _catalogDir()
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

const List<String> _expectedFiles = <String>[
  'z_chat_cascade_route_catalog.dart',
  'z_chat_in_memory_router_repository.dart',
  'z_chat_invalidating_router_repository.dart',
  'z_chat_remote_route_catalog_source.dart',
  'z_chat_repository_route_catalog_source.dart',
  'z_chat_route_catalog_decoder.dart',
  'z_chat_route_catalog_source.dart',
  'z_chat_ttl_route_catalog.dart',
];

void main() {
  test('le dossier porte exactement les huit fichiers du catalogue', () {
    expect(_catalogDir().existsSync(), isTrue);
    expect(
      _catalogFiles().map((File f) => f.uri.pathSegments.last),
      _expectedFiles,
    );
  });

  group('G-RC7 — PUR-DART, SANS HTTP : une seule arête sortante', () {
    test('aucun `dart:io`, `http`, `dio`, Flutter, ni paquet zcrud autre que '
        'le cœur', () {
      final List<String> offenders = <String>[];
      int imports = 0;
      for (final File f in _catalogFiles()) {
        for (final String raw in f.readAsLinesSync()) {
          final String line = raw.trimLeft();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          imports++;
          if (line.contains('package:flutter') ||
              line.contains('dart:ui') ||
              line.contains('dart:io') ||
              line.contains('package:http') ||
              line.contains('package:dio') ||
              (line.contains('package:zcrud_') &&
                  !line.contains('package:zcrud_core/domain.dart'))) {
            offenders.add('${f.path}: $line');
          }
        }
      }
      expect(imports, greaterThan(8), reason: 'garde VACUELLE');
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });

    test('la source distante ne fait AUCUNE requête : elle reçoit un corps '
        'texte par un ouvreur typé', () {
      final String src = strippedLines(
        File('${_catalogDir().path}/z_chat_remote_route_catalog_source.dart'),
      ).join('\n');
      expect(
        src,
        contains(
          'typedef ZChatRouteCatalogOpener =\n'
          '    Future<String> Function(ZChatRouteCatalogQuery query);',
        ),
      );
      expect(src, isNot(contains('Uri.')));
      expect(src, isNot(contains('HttpClient')));
    });
  });

  group('G-RC8 — chaque fichier du dossier est atteignable par le barrel', () {
    test('un export par fichier, en ordre alphabétique', () {
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/zcrud_chat_kernel.dart',
      ).readAsStringSync();
      final List<String> exported = <String>[];
      for (final String line in barrel.split('\n')) {
        final RegExpMatch? m = RegExp(
          r"^export 'src/domain/route/catalog/([a-z_]+\.dart)';",
        ).firstMatch(line);
        if (m != null) exported.add(m.group(1)!);
      }
      expect(exported, _expectedFiles);
    });
  });

  group('G-RC9 — la dartdoc s\'adresse au CONSOMMATEUR', () {
    test(
      'aucun numéro de CR, version, récit de lot ou nom d\'hôte en `///`',
      () {
        final RegExp interdit = RegExp(
          r'(CR-[A-Z]+-\d+|livré en v\d|\bv\d+\.\d+\.\d+\b|\blot [A-Z]\d?\b'
          r'|\bIFFD\b|\blex_douane\b|\bDODLP\b|\bLex\b)',
          caseSensitive: false,
        );
        final List<String> offenders = <String>[];
        int docLines = 0;
        for (final File f in _catalogFiles()) {
          int no = 0;
          for (final String raw in f.readAsLinesSync()) {
            no++;
            final String line = raw.trimLeft();
            if (!line.startsWith('///')) continue;
            docLines++;
            // Une référence `[symbole]` désigne un membre du code (le preset
            // de forme `lex`), pas un hôte raconté.
            final String prose = line.replaceAll(
              RegExp(r'\[[A-Za-z_.]+\]'),
              '',
            );
            if (interdit.hasMatch(prose)) offenders.add('${f.path}:$no: $line');
          }
        }
        expect(docLines, greaterThan(120), reason: 'garde VACUELLE');
        expect(
          offenders,
          isEmpty,
          reason: 'journal de traitement en dartdoc :\n${offenders.join('\n')}',
        );
      },
    );
  });

  group('G-RC10 — FR-26 : le socle n\'invente NI routeur, NI fournisseur', () {
    final RegExp quoted = RegExp(
      r"'(free|openrouter|anthropic|openai|deepseek|low|medium|high|concis"
      r'|standard|detaille)'
      "'",
      caseSensitive: false,
    );
    final RegExp words = RegExp(
      r'\b(explanation|flashcards|mindmap|supervisor|writer)\b',
      caseSensitive: false,
    );

    test('aucun littéral d\'hôte dans le CODE de `catalog/`', () {
      final List<String> offenders = <String>[];
      int codeLines = 0;
      for (final File f in _catalogFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          if (line.trim().isEmpty) continue;
          codeLines++;
          if (quoted.hasMatch(line) || words.hasMatch(line)) {
            offenders.add('${f.path}:$no: ${line.trim()}');
          }
        }
      }
      expect(codeLines, greaterThan(400), reason: 'garde VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason:
            '🔴 FR-26 : valeur d\'hôte dans le socle :\n${offenders.join('\n')}',
      );
    });

    test('`taskAliases` est une table d\'HÔTE : aucune clé de tâche de '
        'session ni entrée d\'alias en dur dans `catalog/`', () {
      final RegExp taskKeys = RegExp(
        r'\b(summarize|summary|elaborate|elaboration|story|history|classroom'
        r'|chatStyle)\b',
      );
      final List<String> offenders = <String>[];
      bool declared = false;
      for (final File f in _catalogFiles()) {
        int no = 0;
        for (final String line in strippedLines(f)) {
          no++;
          if (line.contains('this.taskAliases = const <String, String>{}')) {
            declared = true;
          }
          if (taskKeys.hasMatch(line)) {
            offenders.add('${f.path}:$no: ${line.trim()}');
          }
        }
      }
      expect(declared, isTrue, reason: 'la table par défaut doit être VIDE');
      expect(
        offenders,
        isEmpty,
        reason:
            '🔴 FR-26 : alias de tâche d\'hôte dans le socle :\n'
            '${offenders.join('\n')}',
      );
      expect(taskKeys.hasMatch("'summary': 'summarize',"), isTrue);
      expect(taskKeys.hasMatch('final String task ='), isFalse);
    });

    test('le repli de la cascade est NULLABLE et sans défaut', () {
      final String src = strippedLines(
        File('${_catalogDir().path}/z_chat_cascade_route_catalog.dart'),
      ).join('\n');
      expect(src, contains('final ZChatRouteFallbackBuilder? fallback;'));
      expect(
        RegExp(r'fallback\s*=\s*[^_,\)]').hasMatch(src),
        isFalse,
        reason: 'un défaut de repli serait un routeur inventé par le socle',
      );
      expect(src, contains("ZNotFoundFailure('router not found', id: id"));
    });

    test('🔬 CONTRE-PREUVE — le motif VOIT chaque terme', () {
      for (final String sample in <String>[
        "fallback: (_) => const ZChatRouter(id: 'free')",
        "providerId: 'openrouter',",
        "tier: 'LOW',",
        "routes['flashcards']",
      ]) {
        expect(
          quoted.hasMatch(sample) || words.hasMatch(sample),
          isTrue,
          reason: 'motif aveugle à : $sample',
        );
      }
      expect(quoted.hasMatch("'routers'"), isFalse);
      expect(words.hasMatch('class ZChatCascadeRouteCatalog'), isFalse);
    });
  });
}
