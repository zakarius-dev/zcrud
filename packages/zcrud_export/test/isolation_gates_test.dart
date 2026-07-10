// E11a-3 — Gates d'isolation (AD-1/AD-8/AD-12/SM-5), rejoués comme tests :
//   AC5 — `zcrud_core/pubspec.yaml` ne tire AUCUNE lib d'export Syncfusion ;
//         ces libs ne sont déclarées qu'au `pubspec.yaml` de `zcrud_export`.
//   AC6 — signature : le barrel principal n'exporte AUCUN symbole Syncfusion ;
//         aucun type Syncfusion dans une signature publique de `lib/` (voie
//         confinée : imports Syncfusion uniquement dans `src/data/z_*_exporter`).
//   AC7 — no-secret : aucune clé/licence Syncfusion (`registerLicense('<clé>')`)
//         committée dans `lib/`.
//   AC8 — no-badcert : aucun rappel de validation de certificat permissif
//         (bad-cert callback renvoyant vrai) dans `lib/`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Libs Syncfusion d'export confinées à `zcrud_export` (E11a-3).
const _exportLibs = <String>[
  'syncfusion_flutter_xlsio',
  'syncfusion_flutter_pdf',
];

/// Symboles de type Syncfusion qui ne doivent JAMAIS fuiter dans une signature
/// publique (barrel/API neutre).
const _syncfusionTypes = <String>[
  'Workbook',
  'Worksheet',
  'Range',
  'PdfDocument',
  'PdfGrid',
  'PdfPage',
  'PdfGridRow',
];

String _read(String path) {
  final candidates = <String>[path, '../../$path'];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f.readAsStringSync();
  }
  fail('Fichier introuvable pour le gate : $path');
}

Directory _libDir() {
  for (final p in <String>['packages/zcrud_export/lib', 'lib']) {
    final d = Directory(p);
    if (d.existsSync()) return d;
  }
  fail('Dossier lib/ de zcrud_export introuvable depuis ${Directory.current.path}');
}

Iterable<File> _dartFiles(Directory dir) => dir
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

/// Retire les commentaires Dart (`/* */`, `//`, `///`) : les gates ciblent le
/// CODE, jamais la prose des doc-comments — qui cite légitimement `Workbook`,
/// `registerLicense`, `badCertificateCallback` comme contre-exemples documentés
/// (même philosophie que le gate:secrets, qui exclut la prose). Aucun `//` ne
/// vit dans un littéral de chaîne du `lib/` de ce package.
String _code(String src) {
  final noBlocks = src.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return noBlocks
      .split('\n')
      .map((l) {
        final idx = l.indexOf('//');
        return idx >= 0 ? l.substring(0, idx) : l;
      })
      .join('\n');
}

void main() {
  group('AC5 — isolation graphe : Syncfusion export confiné à zcrud_export', () {
    test('zcrud_core/pubspec.yaml sans lib d\'export Syncfusion', () {
      final core = _read('packages/zcrud_core/pubspec.yaml');
      for (final lib in _exportLibs) {
        expect(core.contains('$lib:'), isFalse,
            reason: 'zcrud_core ne doit PAS dépendre de $lib (AD-1/SM-5)');
      }
    });

    test('les libs d\'export sont déclarées dans le pubspec de zcrud_export', () {
      final export = _read('packages/zcrud_export/pubspec.yaml');
      for (final lib in _exportLibs) {
        expect(export.contains('$lib:'), isTrue,
            reason: '$lib doit être déclaré dans zcrud_export (arête AD-8)');
      }
    });

    test('aucun autre package que zcrud_export ne déclare ces libs', () {
      final packagesDir = Directory('packages').existsSync()
          ? Directory('packages')
          : Directory('../../packages');
      for (final entity in packagesDir.listSync().whereType<Directory>()) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        if (name == 'zcrud_export') continue;
        final pubspec = File('${entity.path}/pubspec.yaml');
        if (!pubspec.existsSync()) continue;
        final content = pubspec.readAsStringSync();
        for (final lib in _exportLibs) {
          expect(content.contains('$lib:'), isFalse,
              reason: '$name ne doit PAS déclarer $lib (confiné à zcrud_export)');
        }
      }
    });
  });

  group('AC6 — signature : aucune fuite de type Syncfusion', () {
    test('le barrel n\'exporte/importe AUCUN fichier Syncfusion ni backend', () {
      final barrel = _read('packages/zcrud_export/lib/zcrud_export.dart');
      final directives = barrel
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return t.startsWith('export ') || t.startsWith('import ');
          })
          .join('\n');
      expect(directives.contains('syncfusion'), isFalse,
          reason: 'le barrel ne doit réexporter aucun package Syncfusion');
      // Les backends (qui importent Syncfusion) ne sont PAS réexportés.
      expect(directives.contains('z_excel_exporter'), isFalse);
      expect(directives.contains('z_pdf_exporter'), isFalse);
    });

    test('les imports Syncfusion sont confinés aux backends src/data', () {
      for (final f in _dartFiles(_libDir())) {
        final src = f.readAsStringSync();
        final importsSyncfusion = src
            .split('\n')
            .where((l) => l.trimLeft().startsWith('import '))
            .any((l) => l.contains('syncfusion'));
        if (importsSyncfusion) {
          final base = f.uri.pathSegments.last;
          expect(base == 'z_excel_exporter.dart' || base == 'z_pdf_exporter.dart',
              isTrue,
              reason: 'import Syncfusion hors backend confiné : ${f.path}');
        }
      }
    });

    test('aucun type Syncfusion dans une signature publique (facade/table/barrel)',
        () {
      // On inspecte les fichiers de l'API neutre (façade + table + barrel) : ils
      // ne doivent référencer AUCUN type Syncfusion (les backends, eux, en
      // contiennent légitimement mais ne sont pas réexportés — voir test ci-dessus).
      final publicFiles = <String>[
        'packages/zcrud_export/lib/zcrud_export.dart',
        'packages/zcrud_export/lib/src/data/z_exporter.dart',
        'packages/zcrud_export/lib/src/data/z_export_table.dart',
      ];
      for (final path in publicFiles) {
        final src = _code(_read(path));
        for (final type in _syncfusionTypes) {
          expect(RegExp('\\b$type\\b').hasMatch(src), isFalse,
              reason: 'type Syncfusion $type ne doit pas apparaître dans $path');
        }
      }
    });
  });

  group('AC7/AC8 — secrets : aucune licence ni badCertificateCallback', () {
    test('aucun registerLicense ni badCertificateCallback dans lib/', () {
      // Motif badcert aligné sur le gate:secrets, sans s'auto-déclencher.
      final badCert = RegExp(r'badCertificateCallback\s*(=>|=)');
      final registerLicense = RegExp(r'registerLicense\s*\(');
      for (final f in _dartFiles(_libDir())) {
        final src = _code(f.readAsStringSync());
        expect(badCert.hasMatch(src), isFalse,
            reason: 'badCertificateCallback interdit (AD-12) dans ${f.path}');
        expect(registerLicense.hasMatch(src), isFalse,
            reason: 'registerLicense (clé/licence) interdit dans le package '
                '(délégué à l\'app hôte, AD-12) : ${f.path}');
      }
    });
  });
}
