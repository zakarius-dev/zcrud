@TestOn('vm')
library;

// Gardes de SOURCE du catalogue de routes (`domain/route/`) :
//   G-R1 pureté Dart, une seule arête (`zcrud_core/domain.dart`) ;
//   G-R2 chaque fichier du dossier est exporté par le barrel ;
//   G-R3 la dartdoc s'adresse au consommateur (ni CR, ni version, ni hôte) ;
//   G-R4 FR-26 : aucun fournisseur, plan, palier ou clé de tâche d'hôte
//        dans le CODE (avec contre-preuve « le motif voit ») ;
//   G-R5 AD-19.1 : `_reservedKeys` du routeur cite `ZSyncMeta.reservedKeys`
//        ET le schéma ; `zSanitizeExtra` dans `fromMap` et `copyWith` ;
//   G-R6 dérive schéma ↔ `toMap` (premier `$FieldSpecs` écrit à la main du
//        dépôt : rien ne le régénère, seule cette garde le tient) ;
//   G-R9 méta-garde : toute garde disque du kernel porte `@TestOn('vm')`.
//
// R3 rejouée sur chaque garde (injection → rouge PAR ASSERTION → restauration
// par copie → sha256) : consignée dans le rapport du lot.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'support/z_repo_sources.dart';

Directory _routeDir() => Directory(
  '${repoRoot().path}/packages/zcrud_chat_kernel/lib/src/domain/route',
);

List<File> _routeFiles() =>
    _routeDir()
        .listSync()
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList()
      ..sort((File a, File b) => a.path.compareTo(b.path));

File _routeFile(String name) => File('${_routeDir().path}/$name');

const List<String> _expectedFiles = <String>[
  'z_chat_model_ref.dart',
  'z_chat_route_catalog_port.dart',
  'z_chat_route_gate.dart',
  'z_chat_route_handlers.dart',
  'z_chat_route_resolution.dart',
  'z_chat_route_spec.dart',
  'z_chat_router.dart',
];

/// Routeur **complet** (tout champ optionnel renseigné) — la base de G-R6.
ZChatRouter _fullRouter() => ZChatRouter(
  id: 'id',
  name: 'name',
  description: 'desc',
  isActive: false,
  tier: 'tier',
  model: const ZChatModelRef(providerId: 'p', modelId: 'm'),
  fallbacks: const <ZChatModelRef>[ZChatModelRef(modelId: 'f')],
  computeEffort: ZChatComputeEffort(3),
  routes: ZChatRouter.indexRoutes(<ZChatRouteSpec>[_fullRoute()]),
  params: const <String, dynamic>{'k': 1},
  extension: ZOpaqueExtension.of(const <String, dynamic>{'v': 1}),
  extra: const <String, dynamic>{'host_key': true},
);

ZChatRouteSpec _fullRoute() => ZChatRouteSpec(
  taskKey: 'task',
  routeName: 'route',
  model: const ZChatModelRef(providerId: 'p', modelId: 'm'),
  fallbacks: const <ZChatModelRef>[ZChatModelRef(modelId: 'f')],
  computeEffort: ZChatComputeEffort(2),
  params: const <String, dynamic>{'k': 1},
  requiredAccessTokens: const <String>['t'],
  handlerId: 'h',
);

void main() {
  test(
    'le dossier existe et porte exactement les sept fichiers du catalogue',
    () {
      expect(_routeDir().existsSync(), isTrue);
      expect(
        _routeFiles().map((File f) => f.uri.pathSegments.last),
        _expectedFiles,
      );
    },
  );

  group('G-R1 — PUR-DART : une seule arête sortante', () {
    test('aucun import Flutter / dart:ui / paquet zcrud autre que le cœur', () {
      final List<String> offenders = <String>[];
      int imports = 0;
      for (final File f in _routeFiles()) {
        for (final String raw in f.readAsLinesSync()) {
          final String line = raw.trimLeft();
          if (!line.startsWith('import ') && !line.startsWith('export ')) {
            continue;
          }
          imports++;
          if (line.contains('package:flutter') ||
              line.contains('dart:ui') ||
              line.contains('dart:io') ||
              (line.contains('package:zcrud_') &&
                  !line.contains('package:zcrud_core/domain.dart'))) {
            offenders.add('${f.path}: $line');
          }
        }
      }
      expect(imports, greaterThan(5), reason: 'garde VACUELLE');
      expect(offenders, isEmpty, reason: offenders.join('\n'));
    });
  });

  group('G-R2 — chaque fichier du dossier est atteignable par le barrel', () {
    test('un export par fichier, en ordre alphabétique', () {
      final String barrel = File(
        '${repoRoot().path}/packages/zcrud_chat_kernel/lib/zcrud_chat_kernel.dart',
      ).readAsStringSync();
      final List<String> exported = <String>[];
      for (final String line in barrel.split('\n')) {
        final RegExpMatch? m = RegExp(
          r"^export 'src/domain/route/([a-z_]+\.dart)';",
        ).firstMatch(line);
        if (m != null) exported.add(m.group(1)!);
      }
      expect(
        exported,
        _expectedFiles,
        reason: 'tout fichier de `route/` est public — et dans l\'ordre',
      );
    });
  });

  group('G-R3 — la dartdoc s\'adresse au CONSOMMATEUR', () {
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
        for (final File f in _routeFiles()) {
          int no = 0;
          for (final String raw in f.readAsLinesSync()) {
            no++;
            final String line = raw.trimLeft();
            if (!line.startsWith('///')) continue;
            docLines++;
            if (interdit.hasMatch(line)) offenders.add('${f.path}:$no: $line');
          }
        }
        expect(docLines, greaterThan(100), reason: 'garde VACUELLE');
        expect(
          offenders,
          isEmpty,
          reason: 'journal de traitement en dartdoc :\n${offenders.join('\n')}',
        );
      },
    );
  });

  group(
    'G-R4 — FR-26 : le socle ne nomme NI fournisseur, NI plan, NI tâche',
    () {
      // Littéraux de fournisseur / palier / plan (entre quotes) et noms de tâche
      // ou d'agent d'hôte (mots entiers), CODE seul (commentaires retirés).
      final RegExp quoted = RegExp(
        r"'(free|openrouter|low|medium|high|concis|standard|detaille)'",
        caseSensitive: false,
      );
      final RegExp words = RegExp(
        r'\b(explanation|flashcards|mindmap|supervisor|writer)\b',
        caseSensitive: false,
      );

      test('aucun littéral d\'hôte dans le CODE de `route/`', () {
        final List<String> offenders = <String>[];
        int codeLines = 0;
        for (final File f in _routeFiles()) {
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
        expect(codeLines, greaterThan(300), reason: 'garde VACUELLE');
        expect(
          offenders,
          isEmpty,
          reason:
              '🔴 FR-26 : valeur d\'hôte dans le socle :\n'
              '${offenders.join('\n')}',
        );
      });

      test('🔬 CONTRE-PREUVE — le motif VOIT chaque terme', () {
        for (final String sample in <String>[
          "const String kDefault = 'free';",
          "providerId: 'openrouter',",
          "tier: 'LOW',",
          "ZChatGenerationStyle('explanation')",
          "routes['flashcards']",
          "handlerId: 'writer'",
        ]) {
          expect(
            quoted.hasMatch(sample) || words.hasMatch(sample),
            isTrue,
            reason: 'motif aveugle à : $sample',
          );
        }
        // Et il ne voit PAS un identifiant légitime qui CONTIENT un terme.
        expect(quoted.hasMatch('class ZAllowAllChatRouteGate'), isFalse);
        expect(words.hasMatch('class ZAllowAllChatRouteGate'), isFalse);
      });
    },
  );

  group('G-R5 — AD-19.1 : clés réservées du routeur', () {
    test('`_reservedKeys` cite `ZSyncMeta.reservedKeys` ET le schéma', () {
      final String src = strippedLines(
        _routeFile('z_chat_router.dart'),
      ).join('\n');
      final RegExpMatch? block = RegExp(
        r'_reservedKeys\s*=\s*<String>\{([^}]*)\}',
      ).firstMatch(src);
      expect(block, isNotNull, reason: '`_reservedKeys` introuvable');
      final String body = block!.group(1)!;
      expect(body, contains('ZSyncMeta.reservedKeys'));
      expect(body, contains(r'$ZChatRouterFieldSpecs'));
      expect(body, contains("'extension'"));
      expect(body, contains("'params'"));
    });

    test('`zSanitizeExtra` dans `fromMap` ET dans `copyWith`', () {
      final String src = strippedLines(
        _routeFile('z_chat_router.dart'),
      ).join('\n');
      final int fromMap = src.indexOf('factory ZChatRouter.fromMap(');
      final int copyWith = src.indexOf('ZChatRouter copyWith(');
      final int operatorEq = src.indexOf('bool operator ==(');
      expect(fromMap, greaterThan(0));
      expect(copyWith, greaterThan(fromMap));
      expect(operatorEq, greaterThan(copyWith));
      final String fromMapBody = src.substring(
        fromMap,
        src.indexOf('@override', fromMap),
      );
      final String copyWithBody = src.substring(copyWith, operatorEq);
      expect(
        RegExp(
          r'zSanitizeExtra\(\s*map,\s*_reservedKeys',
        ).hasMatch(fromMapBody),
        isTrue,
        reason: '`fromMap` doit sanitiser EAGER avec `_reservedKeys`',
      );
      expect(
        RegExp(
          r'zSanitizeExtra\(\s*extra as Map<String, dynamic>,\s*_reservedKeys',
        ).hasMatch(copyWithBody),
        isTrue,
        reason: '`copyWith` doit sanitiser EAGER avec `_reservedKeys`',
      );
    });
  });

  group('G-R6 — DÉRIVE SCHÉMA : `\$FieldSpecs` ≡ clés de `toMap`', () {
    test('routeur : chaque `name` du schéma est une clé de `toMap()` d\'un '
        'routeur complet', () {
      final Set<String> keys = _fullRouter().toMap().keys.toSet();
      final List<String> missing = <String>[
        for (final ZFieldSpec s in $ZChatRouterFieldSpecs)
          if (!keys.contains(s.name)) s.name,
      ];
      expect(
        missing,
        isEmpty,
        reason:
            'champ du schéma jamais persisté (le formulaire éditerait '
            'une clé que `toMap` ignore) : $missing',
      );
    });

    test('routeur : chaque clé TYPÉE de `toMap()` est un `name` du schéma '
        '(hors `extra`, `params`, `extension`)', () {
      final ZChatRouter full = _fullRouter();
      final Set<String> names = <String>{
        for (final ZFieldSpec s in $ZChatRouterFieldSpecs) s.name,
      };
      final Set<String> hors = <String>{
        'params',
        'extension',
        ...full.extra.keys,
      };
      final List<String> stray = <String>[
        for (final String k in full.toMap().keys)
          if (!hors.contains(k) && !names.contains(k)) k,
      ];
      expect(
        stray,
        isEmpty,
        reason:
            'clé persistée absente du schéma (le formulaire ne '
            'l\'éditerait jamais) : $stray',
      );
    });

    test('route : même double inclusion sur `\$ZChatRouteSpecFieldSpecs` '
        '(hors `params`)', () {
      final Map<String, dynamic> json = _fullRoute().toJson();
      final Set<String> names = <String>{
        for (final ZFieldSpec s in $ZChatRouteSpecFieldSpecs) s.name,
      };
      final List<String> missing = <String>[
        for (final String n in names)
          if (!json.containsKey(n)) n,
      ];
      final List<String> stray = <String>[
        for (final String k in json.keys)
          if (k != 'params' && !names.contains(k)) k,
      ];
      expect(missing, isEmpty, reason: 'schéma sans clé : $missing');
      expect(stray, isEmpty, reason: 'clé sans schéma : $stray');
    });

    test(
      'le sous-schéma `routes` est EXACTEMENT `\$ZChatRouteSpecFieldSpecs`',
      () {
        final ZFieldSpec routes = $ZChatRouterFieldSpecs.singleWhere(
          (ZFieldSpec s) => s.name == 'routes',
        );
        expect(routes.type, EditionFieldType.subItems);
        final ZFieldConfig? cfg = routes.config;
        expect(cfg, isA<ZSubListConfig>());
        expect(
          identical(
            (cfg! as ZSubListConfig).itemFields,
            $ZChatRouteSpecFieldSpecs,
          ),
          isTrue,
        );
        expect((cfg as ZSubListConfig).summaryFields, <String>[
          'task_key',
          'model_id',
        ]);
      },
    );

    test('aucun `label` (FR-26) et `task_key` requis', () {
      for (final ZFieldSpec s in <ZFieldSpec>[
        ...$ZChatRouterFieldSpecs,
        ...$ZChatRouteSpecFieldSpecs,
      ]) {
        expect(s.label, isNull, reason: '`${s.name}` porte un libellé');
      }
      expect(
        $ZChatRouteSpecFieldSpecs
            .singleWhere((ZFieldSpec s) => s.name == 'task_key')
            .isRequired,
        isTrue,
      );
    });
  });

  group('G-R9 — méta-garde : toute garde DISQUE porte `@TestOn(\'vm\')`', () {
    test('chaque `*_test.dart` du kernel qui importe `dart:io` est annoté', () {
      final Directory tests = Directory(
        '${repoRoot().path}/packages/zcrud_chat_kernel/test',
      );
      final List<String> offenders = <String>[];
      int scanned = 0;
      for (final File f in tests.listSync().whereType<File>().where(
        (File f) => f.path.endsWith('_test.dart'),
      )) {
        final String src = f.readAsStringSync();
        if (!src.contains("import 'dart:io';") &&
            !src.contains("import 'support/z_repo_sources.dart';")) {
          continue;
        }
        scanned++;
        if (!src.contains("@TestOn('vm')")) offenders.add(f.path);
      }
      expect(scanned, greaterThan(5), reason: 'garde VACUELLE');
      expect(
        offenders,
        isEmpty,
        reason:
            'gate web : une garde disque sans `@TestOn(\'vm\')` casse la '
            'compilation JS de TOUTE la suite :\n${offenders.join('\n')}',
      );
    });
  });
}
