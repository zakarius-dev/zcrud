// E11a-3 + E11b-3 — Gates d'isolation (AD-1/AD-8/AD-12/SM-5), rejoués comme tests.
//
// Durcissement E11b-3 (AC12, learning E10 AI-E10-2 : « un garde ne prouve QUE ce
// qu'il scanne » ; clôt LOW-2 d'E11a-3 : listes de fichiers codées en dur) :
//   • L'allowlist des fichiers autorisés à importer Syncfusion est DÉRIVÉE
//     dynamiquement (tous les .dart de `src/data/` qui importent Syncfusion),
//     pas une liste figée.
//   • Le contrôle « aucun type Syncfusion en signature publique » DÉRIVE ses
//     fichiers publics (tous les .dart de `lib/` SAUF ceux qui importent
//     Syncfusion) au lieu d'une liste de 3 fichiers codée en dur.
//   • no-secret/no-badcert re-scanné sur TOUS les fichiers de `lib/` (dont les
//     nouveaux `z_file_saver_*.dart`), strip-comment, cwd-robuste.
//   • `package:web`/`dart:js_interop`/`dart:io` sont autorisés (ni Syncfusion ni
//     secret) mais CONFINÉS à leurs fichiers conditionnels respectifs.
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
  'PdfBitmap',
  'PdfStandardFont',
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
/// `registerLicense`, `badCertificateCallback`, `dart:html` comme contre-exemples
/// documentés. Aucun `//` ne vit dans un littéral de chaîne du `lib/` de ce package.
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

/// Lignes `import ...` du CODE (commentaires retirés).
List<String> _imports(String code) => code
    .split('\n')
    .where((l) => l.trimLeft().startsWith('import '))
    .toList();

/// Un fichier importe-t-il Syncfusion ? (dérivation dynamique de l'allowlist.)
bool _importsSyncfusion(String code) =>
    _imports(code).any((l) => l.contains('syncfusion'));

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

    test('chaque lib Syncfusion d\'export reste confinée à SON paquet', () {
      // CR-LEX-40 : la topologie a deux paquets depuis la scission.
      // - `syncfusion_flutter_xlsio` (tableur) : `zcrud_export` UNIQUEMENT —
      //   c'est précisément ce qu'un hôte PDF-seul ne doit plus tirer ;
      // - `syncfusion_flutter_pdf` : les DEUX, puisque `zcrud_export` compose
      //   `zcrud_export_pdf` en y ajoutant l'Excel.
      const proprietaires = <String, Set<String>>{
        'syncfusion_flutter_xlsio': <String>{'zcrud_export'},
        'syncfusion_flutter_pdf': <String>{'zcrud_export', 'zcrud_export_pdf'},
      };
      final packagesDir = Directory('packages').existsSync()
          ? Directory('packages')
          : Directory('../../packages');
      for (final entity in packagesDir.listSync().whereType<Directory>()) {
        final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
        final pubspec = File('${entity.path}/pubspec.yaml');
        if (!pubspec.existsSync()) continue;
        final content = pubspec.readAsStringSync();
        for (final lib in _exportLibs) {
          if (proprietaires[lib]!.contains(name)) continue;
          expect(content.contains('$lib:'), isFalse,
              reason: '$name ne doit PAS déclarer $lib');
        }
      }
    });

    test('🔴 CR-LEX-40 — `zcrud_export_pdf` n\'a AUCUNE arête tableur', () {
      // C'est l'invariant que la scission existe pour tenir : un hôte PDF-seul
      // ne doit tirer ni xlsio, ni son transitif officecore, ni jiffy.
      final pubspec = File(
        Directory('packages').existsSync()
            ? 'packages/zcrud_export_pdf/pubspec.yaml'
            : '../../packages/zcrud_export_pdf/pubspec.yaml',
      );
      expect(pubspec.existsSync(), isTrue);
      // On cherche la DÉCLARATION (`  lib: ^x`), pas une mention en commentaire —
      // le pubspec du paquet léger EXPLIQUE justement pourquoi xlsio en est
      // absent, et une détection naïve se serait mordu la queue.
      final declarations = pubspec
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(declarations.contains('syncfusion_flutter_xlsio:'), isFalse,
          reason: 'la scission serait vaine si le paquet léger la déclarait');
      // Contrôle POSITIF : la détection sait trouver une lib réellement déclarée.
      expect(declarations.contains('syncfusion_flutter_pdf:'), isTrue,
          reason: 'sans ce contrôle, un pubspec vide rendrait le test vert');
    });
  });

  group('AC6/AC12 — signature : aucune fuite de type Syncfusion (dérivé)', () {
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
      expect(directives.contains('z_pdf_document_builder'), isFalse);
    });

    test('les imports Syncfusion sont confinés à des backends src/data/', () {
      // Allowlist DÉRIVÉE : tout fichier important Syncfusion DOIT être un backend
      // sous src/data/ (aucune liste figée — le garde couvre tout nouveau backend).
      final syncfusionImporters = <String>[];
      for (final f in _dartFiles(_libDir())) {
        final code = _code(f.readAsStringSync());
        if (_importsSyncfusion(code)) {
          syncfusionImporters.add(f.path);
          final normalized = f.path.replaceAll(r'\', '/');
          expect(normalized.contains('/src/data/'), isTrue,
              reason: 'import Syncfusion hors src/data/ confiné : ${f.path}');
          final base = f.uri.pathSegments.last;
          expect(base.startsWith('z_') && base.endsWith('.dart'), isTrue,
              reason: 'backend Syncfusion hors convention z_*.dart : ${f.path}');
        }
      }
      // CR-LEX-40 : depuis la scission, les backends PDF vivent dans
      // `zcrud_export_pdf` (où le même garde s'applique). `zcrud_export` ne
      // conserve que le backend TABLEUR — mais il doit en rester AU MOINS un,
      // sans quoi ce garde s'auto-satisferait sur un paquet vide.
      expect(syncfusionImporters.length, greaterThanOrEqualTo(1),
          reason: 'le backend Syncfusion tableur doit exister');
    });

    test('aucun type Syncfusion dans une signature publique (fichiers DÉRIVÉS)',
        () {
      // Fichiers publics DÉRIVÉS : tous les .dart de lib/ SAUF ceux qui importent
      // Syncfusion (backends confinés). Clôt LOW-2 : plus de liste de 3 en dur.
      var scanned = 0;
      for (final f in _dartFiles(_libDir())) {
        final code = _code(f.readAsStringSync());
        if (_importsSyncfusion(code)) continue; // backend confiné, exclu
        scanned++;
        for (final type in _syncfusionTypes) {
          expect(RegExp('\\b$type\\b').hasMatch(code), isFalse,
              reason: 'type Syncfusion $type ne doit pas apparaître dans ${f.path}');
        }
      }
      expect(scanned, greaterThan(0), reason: 'aucun fichier public scanné ?');
    });
  });

  group('AC12 — imports plateforme confinés à leurs fichiers conditionnels', () {
    test('dart:io / package:web / dart:js_interop confinés aux z_file_saver_*', () {
      for (final f in _dartFiles(_libDir())) {
        final code = _code(f.readAsStringSync());
        final base = f.uri.pathSegments.last;
        final imports = _imports(code);
        final usesIo = imports.any((l) => l.contains("'dart:io'"));
        final usesWeb = imports.any((l) => l.contains('package:web/'));
        final usesJsInterop = imports.any((l) => l.contains("'dart:js_interop'"));
        if (usesIo) {
          expect(base == 'z_file_saver_io.dart', isTrue,
              reason: 'dart:io hors z_file_saver_io.dart : ${f.path}');
        }
        if (usesWeb || usesJsInterop) {
          expect(base == 'z_file_saver_web.dart', isTrue,
              reason: 'package:web/js_interop hors z_file_saver_web.dart : ${f.path}');
        }
      }
    });

    test('dart:html (déprécié) BANNI de tout lib/ (AD-12)', () {
      final html = RegExp(r'''import\s+['"]dart:html['"]''');
      for (final f in _dartFiles(_libDir())) {
        final code = _code(f.readAsStringSync());
        expect(html.hasMatch(code), isFalse,
            reason: 'dart:html interdit (utiliser package:web) : ${f.path}');
      }
    });

    // 🔴 su-11 (AC3/AD-42, learning E10) : `zcrud_export` reste PUR — aucun
    // rendu widget→image. Le port `ZLatexRasterizer` (abstraction) délègue CE
    // besoin au satellite `zcrud_export_ui`. On BANNIT donc les primitives de
    // rendu écran de `dart:ui`/`rendering` dans le CODE de `lib/`. Note : les
    // TYPES DATA de `dart:ui` (`Offset`, `Rect`, `Color`) restent permis — seuls
    // les APPELS de rasterisation sont interdits. Sans ce garde, un dev pourrait
    // ajouter `RepaintBoundary().toImage()` ici sans qu'aucun test ne rougisse.
    test('aucune primitive de RENDU ÉCRAN dart:ui dans lib/ (pureté AD-42)', () {
      final render =
          RegExp(r'\b(RepaintBoundary|PictureRecorder|toImage|toByteData)\b');
      for (final f in _dartFiles(_libDir())) {
        final code = _code(f.readAsStringSync());
        final m = render.firstMatch(code);
        expect(m, isNull,
            reason: 'rendu écran interdit dans zcrud_export (AD-42) : '
                '${f.path} → ${m?.group(0)}');
      }
    });
  });

  group('AC7/AC8/AC12 — secrets : aucune licence, badCert, ni appel réseau', () {
    test('aucun registerLicense ni badCertificateCallback dans lib/', () {
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

    test('ZFileSaver purement local : aucun HttpClient/requête réseau', () {
      // Sauvegarde/téléchargement LOCAL de bytes : aucune arête réseau (AD-12).
      final net = RegExp(r'\bHttpClient\b|\bhttp\.(get|post|put)\b');
      for (final f in _dartFiles(_libDir())) {
        final base = f.uri.pathSegments.last;
        if (!base.startsWith('z_file_saver')) continue;
        final src = _code(f.readAsStringSync());
        expect(net.hasMatch(src), isFalse,
            reason: 'aucun appel réseau dans un ZFileSaver local : ${f.path}');
      }
    });
  });
}
