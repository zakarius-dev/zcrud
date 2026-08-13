// Gardes de l'EXPORT du listing de `ZCrudScreen`.
//
// Ce que ces gardes tiennent, dans l'ordre :
//  - contre-témoin : sans exporteur déclaré, aucune entrée d'export, et
//    l'écran fonctionne exactement comme avant ;
//  - une politique déclarée SANS format n'ouvre pas d'entrée non plus ;
//  - le fichier reflète ce que l'utilisateur VOIT : recherche, filtres et tri
//    déjà appliqués ;
//  - une SÉLECTION en cours restreint l'export aux seuls éléments cochés ;
//  - un exporteur qui échoue — ou qui LÈVE — est notifié, jamais propagé ;
//  - les valeurs exportées sont les valeurs FORMATÉES (format dépendant de la
//    ligne), pas les valeurs brutes ;
//  - les colonnes techniques (identité, numéro d'ordre) n'entrent jamais dans
//    le fichier ;
//  - ISOLATION : ni `zcrud_screen` ni `zcrud_core` ne nomment un moteur
//    d'export, et `zcrud_screen` ne déclare aucune dépendance d'export.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

const List<Item> _seed = <Item>[
  Item(id: 'a', name: 'Alpha', qty: 1),
  Item(id: 'b', name: 'Bravo', qty: 2),
  Item(id: 'c', name: 'Charlie', qty: 3),
];

/// Exporteur d'essai : écrit une ligne de texte par ligne reçue, et retient la
/// dernière requête — la seule façon d'asserter sur ce qui a RÉELLEMENT été
/// exporté plutôt que sur ce qui est affiché.
class SpyExporter implements ZListExporter {
  SpyExporter({this.id = 'spy', this.labelKey = 'Spy'});

  @override
  final String id;
  @override
  final String labelKey;
  @override
  String get fileExtension => 'txt';
  @override
  String get mimeType => 'text/plain';

  /// Requêtes reçues, dans l'ordre.
  final List<ZListRenderRequest> requests = <ZListRenderRequest>[];

  /// Titres reçus, dans l'ordre.
  final List<String?> titles = <String?>[];

  /// En-têtes RÉSOLUS de la dernière requête.
  List<String> lastHeaders = const <String>[];

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async {
    requests.add(request);
    titles.add(title);
    final resolve = resolveHeader ?? (String key) => key;
    lastHeaders = <String>[
      for (final column in request.columns) resolve(column.header),
    ];
    final buffer = StringBuffer();
    for (final row in request.rows) {
      buffer.writeln(<String>[
        for (final column in request.columns)
          column.formatRow(row.cells[column.name], row.cells),
      ].join('|'));
    }
    return Right<ZFailure, Uint8List>(
      Uint8List.fromList(utf8.encode(buffer.toString())),
    );
  }

  /// Noms de colonnes de la dernière requête.
  List<String> get lastColumnNames =>
      <String>[for (final c in requests.last.columns) c.name];

  /// Identités des lignes de la dernière requête.
  List<String> get lastRowIds =>
      <String>[for (final r in requests.last.rows) r.id];
}

/// Exporteur qui rend un échec ordinaire.
class FailingExporter implements ZListExporter {
  const FailingExporter();

  @override
  String get id => 'ko';
  @override
  String get labelKey => 'KO';
  @override
  String get fileExtension => 'ko';
  @override
  String get mimeType => 'application/x-ko';

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async =>
      Left<ZFailure, Uint8List>(const ZServerFailure('moteur en panne'));
}

/// Exporteur qui LÈVE — le pire cas que l'écran doit absorber.
class ThrowingExporter implements ZListExporter {
  const ThrowingExporter();

  @override
  String get id => 'boom';
  @override
  String get labelKey => 'Boom';
  @override
  String get fileExtension => 'boom';
  @override
  String get mimeType => 'application/x-boom';

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async =>
      throw StateError('moteur indisponible');
}

Widget _screen(
  FakeItemRepo repo, {
  ZExportPolicy? export,
  ZSelectionPolicy? selection,
  ZListQueryPolicy query = const ZListQueryPolicy(),
  ZColumnPolicy? columnPolicy,
}) =>
    ZCrudScreen<Item>(
      title: 'Items',
      source: ZCrudSource<Item>.repository(repo),
      registry: buildItemRegistry(),
      export: export,
      selection: selection,
      query: query,
      columnPolicy: columnPolicy,
    );

/// Ouvre le menu de débordement de l'app-bar (s'il existe).
Future<void> _openOverflow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  await tester.pumpAndSettle();
}

/// Coche la ligne [id].
Future<void> _tick(WidgetTester tester, String id) async {
  await tester.tap(
    find.descendant(
      of: find.byKey(ValueKey<String>('zListRow_$id')),
      matching: find.byType(Checkbox),
    ),
  );
  await tester.pumpAndSettle();
}

/// Déclenche l'export du format intitulé [entry] par le menu de débordement.
Future<void> _export(WidgetTester tester, String entry) async {
  await _openOverflow(tester);
  await tester.tap(find.text(entry));
  await tester.pumpAndSettle();
}

Finder _toastContaining(String text) => find.descendant(
      of: find.byType(SnackBar),
      matching: find.textContaining(text),
    );

void main() {
  group('CONTRE-TÉMOIN — sans exporteur, aucune entrée et aucun crash', () {
    testWidgets('aucune politique déclarée : pas de menu de débordement',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(tester, _screen(repo));

      expect(find.byIcon(Icons.file_download_outlined), findsNothing);
      expect(
        find.byIcon(Icons.more_vert),
        findsNothing,
        reason: 'aucune entrée de débordement ⇒ aucun menu ouvert pour rien',
      );
      // L'écran, lui, fonctionne : l'absence d'export n'est pas l'absence
      // d'écran.
      expect(find.byKey(const ValueKey('zListRow_a')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('politique déclarée SANS format : toujours aucune entrée',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: const <ZListExporter>[],
            onExported: (_, _) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('PRÉSENCE — un format déclaré = une entrée', () {
    testWidgets('l\'entrée porte « Exporter » et le nom du format',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[SpyExporter(labelKey: 'CSV')],
            onExported: (_, _) {},
          ),
        ),
      );

      await _openOverflow(tester);
      expect(find.text('Export (CSV)'), findsOneWidget);
    });

    testWidgets('deux formats = deux entrées, dans l\'ordre déclaré',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[
              SpyExporter(id: 'csv', labelKey: 'CSV'),
              SpyExporter(id: 'pdf', labelKey: 'PDF'),
            ],
            onExported: (_, _) {},
          ),
        ),
      );

      await _openOverflow(tester);
      expect(find.text('Export (CSV)'), findsOneWidget);
      expect(find.text('Export (PDF)'), findsOneWidget);
    });

    testWidgets('deux exporteurs de MÊME id ne font qu\'une entrée',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[
              SpyExporter(id: 'csv', labelKey: 'CSV'),
              SpyExporter(id: 'csv', labelKey: 'Doublon'),
            ],
            onExported: (_, _) {},
          ),
        ),
      );

      await _openOverflow(tester);
      expect(find.text('Export (CSV)'), findsOneWidget);
      expect(find.text('Export (Doublon)'), findsNothing);
    });
  });

  group('CE QUI EST EXPORTÉ — l\'état VISIBLE, rien de plus', () {
    testWidgets('sans geste : toutes les lignes listées, dans l\'ordre affiché',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      ZExportedBytes? delivered;
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, file) => delivered = file,
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(spy.lastRowIds, <String>['a', 'b', 'c']);
      expect(delivered, isNotNull);
      expect(delivered!.fileName, 'Items.txt');
      expect(delivered!.mimeType, 'text/plain');
      expect(utf8.decode(delivered!.bytes), contains('Alpha'));
    });

    testWidgets('une RECHERCHE en cours restreint le fichier à ce qui reste',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Brav');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('zListRow_a')), findsNothing);

      await _export(tester, 'Export (Spy)');

      expect(
        spy.lastRowIds,
        <String>['b'],
        reason: 'exporter ce que la source contient trahirait l\'écran',
      );
    });

    testWidgets('un TRI demandé se retrouve dans l\'ordre du fichier',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: const ZListQueryPolicy(
            sort: <ZSort>[ZSort('name', ZSortDirection.desc)],
          ),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(spy.lastRowIds, <String>['c', 'b', 'a']);
    });

    testWidgets('un FILTRE permanent se retrouve dans le fichier',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          query: const ZListQueryPolicy(
            baseFilters: <ZFilter>[
              ZFilter('qty', ZFilterOp.gt, 1),
            ],
          ),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(spy.lastRowIds, <String>['b', 'c']);
    });
  });

  group('SÉLECTION — cocher restreint l\'export aux éléments cochés', () {
    testWidgets('sélection active ⇒ seuls les cochés partent', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: const ZSelectionPolicy(),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'c');
      await _export(tester, 'Export (Spy)');

      expect(
        spy.lastRowIds,
        <String>['a', 'c'],
        reason: 'une sélection faite puis un export demandé porte sur elle',
      );
    });

    testWidgets('sélection VIDÉE ⇒ retour à la liste entière', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: const ZSelectionPolicy(),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _tick(tester, 'a');
      await _tick(tester, 'a');
      await _export(tester, 'Export (Spy)');

      expect(spy.lastRowIds, <String>['a', 'b', 'c']);
    });

    testWidgets('la sélection ne RÉORDONNE pas : l\'ordre reste celui de l\'écran',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          selection: const ZSelectionPolicy(),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _tick(tester, 'c');
      await _tick(tester, 'a');
      await _export(tester, 'Export (Spy)');

      expect(spy.lastRowIds, <String>['a', 'c']);
    });
  });

  group('COLONNES — les ornements d\'écran n\'entrent pas dans le fichier', () {
    testWidgets('la colonne d\'IDENTITÉ est absente', (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(spy.lastColumnNames, isNot(contains('id')));
      expect(spy.lastColumnNames, <String>['name', 'qty']);
    });

    testWidgets('la colonne de NUMÉRO D\'ORDRE est absente, même demandée',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          columnPolicy: const ZColumnPolicy(
            ordinal: ZListOrdinal(enabled: true),
          ),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(
        spy.lastColumnNames,
        isNot(contains(ZListOrdinal.columnName)),
        reason: 'le numéro d\'ordre décrit une position d\'écran',
      );
      expect(spy.lastColumnNames, <String>['name', 'qty']);
    });

    testWidgets('les VALEURS exportées sont les valeurs FORMATÉES',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      ZExportedBytes? delivered;
      await pumpScreen(
        tester,
        _screen(
          repo,
          columnPolicy: ZColumnPolicy(
            overrides: <String, ZColumnOverride>{
              'qty': ZColumnOverride(
                formatWithRow: (raw, row) => '$raw (${row['name']})',
              ),
            },
          ),
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, file) => delivered = file,
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(
        utf8.decode(delivered!.bytes),
        contains('1 (Alpha)'),
        reason: 'lire la valeur brute perdrait le format déclaré, en silence',
      );
      expect(utf8.decode(delivered!.bytes), contains('3 (Charlie)'));
    });

    testWidgets('les EN-TÊTES remis à l\'exporteur sont résolus',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) {},
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(spy.lastHeaders, <String>['name', 'qty']);
      expect(spy.titles.single, 'Items');
    });
  });

  group('DÉFENSIF (AD-10) — un export raté n\'emporte jamais l\'écran', () {
    testWidgets('exporteur en ÉCHEC : notifié, aucune exception',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      var delivered = 0;
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: const <ZListExporter>[FailingExporter()],
            onExported: (_, _) => delivered++,
          ),
        ),
      );

      await _export(tester, 'Export (KO)');

      expect(tester.takeException(), isNull);
      expect(_toastContaining('Export failed'), findsOneWidget);
      expect(_toastContaining('moteur en panne'), findsOneWidget);
      expect(delivered, 0, reason: 'aucun fichier n\'a été produit');
      expect(find.byKey(const ValueKey('zListRow_a')), findsOneWidget);
    });

    testWidgets('exporteur qui LÈVE : notifié, aucune exception',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      var delivered = 0;
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: const <ZListExporter>[ThrowingExporter()],
            onExported: (_, _) => delivered++,
          ),
        ),
      );

      await _export(tester, 'Export (Boom)');

      expect(tester.takeException(), isNull);
      expect(_toastContaining('Export failed'), findsOneWidget);
      expect(_toastContaining('moteur indisponible'), findsOneWidget);
      expect(delivered, 0);
    });

    testWidgets('liste VIDE : annoncé, aucun exporteur appelé', (tester) async {
      final repo = FakeItemRepo(const <Item>[]);
      addTearDown(repo.dispose);
      final spy = SpyExporter();
      var delivered = 0;
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[spy],
            onExported: (_, _) => delivered++,
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(tester.takeException(), isNull);
      expect(_toastContaining('Nothing to export'), findsOneWidget);
      expect(spy.requests, isEmpty);
      expect(delivered, 0);
    });
  });

  group('NOM DE FICHIER', () {
    testWidgets('le radical déclaré l\'emporte sur le titre de l\'écran',
        (tester) async {
      final repo = FakeItemRepo(_seed);
      addTearDown(repo.dispose);
      ZExportedBytes? delivered;
      await pumpScreen(
        tester,
        _screen(
          repo,
          export: ZExportPolicy(
            exporters: <ZListExporter>[SpyExporter()],
            fileBaseName: 'mon-export',
            onExported: (_, file) => delivered = file,
          ),
        ),
      );

      await _export(tester, 'Export (Spy)');

      expect(delivered!.fileName, 'mon-export.txt');
    });
  });

  group('ISOLATION — aucun moteur d\'export ne remonte dans l\'assemblage', () {
    /// Racine du dépôt : remontée jusqu'au dossier portant `melos.yaml`
    /// (jamais un `../` relatif, qui dépendrait du répertoire courant).
    Directory repoRoot() {
      var dir = Directory.current;
      while (!File('${dir.path}/melos.yaml').existsSync()) {
        final parent = dir.parent;
        if (parent.path == dir.path) {
          fail('melos.yaml introuvable en remontant depuis ${Directory.current}');
        }
        dir = parent;
      }
      return dir;
    }

    /// Retire commentaires et chaînes littérales : seul le CODE est jugé.
    ///
    /// Les dartdocs de ces paquets *parlent* des moteurs d'export pour dire
    /// qu'ils n'y sont pas ; les y chercher ferait rougir la garde sur sa
    /// propre documentation, et l'aurait rendue inerte au premier
    /// contournement.
    String codeOnly(String source) => source
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'//.*$'), ''))
        .join('\n')
        .replaceAll(RegExp("'[^'\\n]*'"), "''")
        .replaceAll(RegExp('"[^"\\n]*"'), '""');

    Map<String, String> sourcesOf(String package) {
      final lib = Directory('${repoRoot().path}/packages/$package/lib');
      expect(lib.existsSync(), isTrue, reason: '$package/lib doit exister');
      return <String, String>{
        for (final entity in lib.listSync(recursive: true))
          if (entity is File && entity.path.endsWith('.dart'))
            entity.path: codeOnly(entity.readAsStringSync()),
      };
    }

    test('anti-vacuité : le balayage trouve bien du code, pas des coquilles',
        () {
      final screen = sourcesOf('zcrud_screen');
      expect(screen.length, greaterThan(5));
      expect(sourcesOf('zcrud_core').length, greaterThan(50));
      // Le dépouillement ne vide pas les fichiers : le code reste là.
      expect(
        screen.values.any((code) => code.contains('class ZCrudScreen')),
        isTrue,
      );
      // ... et il retire bien la prose : ce mot n'existe QUE dans les dartdocs.
      expect(
        screen.values.any((code) => code.contains('Syncfusion')),
        isFalse,
      );
    });

    test('aucun symbole de moteur d\'export dans zcrud_screen ni zcrud_core',
        () {
      // Motifs des moteurs réels : le PDF Syncfusion, le tableur xlsio, et le
      // préfixe Syncfusion lui-même.
      final forbidden = <RegExp>[
        RegExp(r'syncfusion', caseSensitive: false),
        RegExp(r'\bxlsio\b', caseSensitive: false),
        RegExp(r'package:pdf\b'),
        RegExp(r'\bPdfDocument\b'),
        RegExp(r'\bWorkbook\b'),
      ];
      for (final package in <String>['zcrud_screen', 'zcrud_core']) {
        sourcesOf(package).forEach((path, code) {
          for (final pattern in forbidden) {
            expect(
              pattern.hasMatch(code),
              isFalse,
              reason: '$path ne doit nommer aucun moteur d\'export '
                  '(motif $pattern)',
            );
          }
        });
      }
    });

    test('zcrud_screen ne dépend d\'AUCUN paquet d\'export', () {
      final pubspec =
          File('${repoRoot().path}/packages/zcrud_screen/pubspec.yaml')
              .readAsStringSync();
      final deps = pubspec.split('dev_dependencies:').first;
      for (final package in <String>[
        'zcrud_export',
        'zcrud_export_pdf',
        'zcrud_export_ui',
        'syncfusion_flutter_pdf',
        'syncfusion_flutter_xlsio',
      ]) {
        expect(
          deps.contains(package),
          isFalse,
          reason: 'déclarer $package ferait payer l\'export à TOUT hôte',
        );
      }
      // Anti-vacuité : les dépendances réelles, elles, sont bien lues.
      expect(deps, contains('zcrud_core'));
    });
  });
}
