// E11a-3 — Tests fonctionnels de `ZExporter` (AC1..AC4, AC10).
//
// Vérifie le CONTENU réel :
//   • Excel : le `.xlsx` généré est ré-ouvert (décodage ZIP via `package:archive`,
//     xlsio étant write-only) et l'on assert la présence des en-têtes + valeurs
//     formatées dans le XML de la feuille/sharedStrings.
//   • PDF : le document généré est ré-ouvert (`PdfTextExtractor`) et l'on assert
//     la présence des en-têtes + valeurs (parité `col.format`).
//   • Colonnes dérivées du schéma (SM-5) : id/`richText` exclus, `forceInclude`
//     inclus, `select` → libellé de choix, `tags` → join `', '`.
//   • Défensif (AD-10) : rows vides / columns vides / clé absente / null / tout
//     vide → `returnsNormally`, bytes non-null.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// Schéma de référence couvrant des types variés + champs exclus (id, richText).
List<ZFieldSpec> _schema() => const <ZFieldSpec>[
      ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
      ZFieldSpec(name: 'name', type: EditionFieldType.text, label: 'Nom'),
      ZFieldSpec(name: 'age', type: EditionFieldType.integer),
      ZFieldSpec(name: 'active', type: EditionFieldType.boolean),
      ZFieldSpec(
        name: 'status',
        type: EditionFieldType.select,
        label: 'Statut',
        choices: <ZFieldChoice>[
          ZFieldChoice(value: 'open', label: 'Ouvert'),
          ZFieldChoice(value: 'closed', label: 'Fermé'),
        ],
      ),
      ZFieldSpec(name: 'tags', type: EditionFieldType.tags),
      ZFieldSpec(name: 'created', type: EditionFieldType.dateTime),
      // Non tabulaire → exclu par deriveColumns.
      ZFieldSpec(name: 'notes', type: EditionFieldType.richText),
    ];

List<ZListRow> _rows() => <ZListRow>[
      ZListRow(id: '1', cells: <String, Object?>{
        'id': '1',
        'name': 'Alice',
        'age': 30,
        'active': true,
        'status': 'open',
        'tags': <String>['a', 'b'],
        'created': DateTime.utc(2026, 1, 2, 3, 4, 5),
        'notes': 'longue note',
      }),
      // row2 : valeurs manquantes / null / listes vides (défensif AD-10).
      const ZListRow(id: '2', cells: <String, Object?>{
        'id': '2',
        'name': 'Bob',
        'active': false,
        'status': 'closed',
        'tags': <String>[],
        // 'age' et 'created' ABSENTS ; 'notes' absent.
      }),
    ];

/// Concatène le texte XML des feuilles + sharedStrings d'un `.xlsx` (ZIP).
String _xlsxText(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final buffer = StringBuffer();
  for (final file in archive.files) {
    if (!file.isFile) continue;
    final name = file.name;
    if (name.startsWith('xl/worksheets/') || name == 'xl/sharedStrings.xml') {
      buffer.write(utf8.decode(file.content, allowMalformed: true));
    }
  }
  return buffer.toString();
}

/// Extrait le texte d'un PDF (ré-ouverture + `PdfTextExtractor`).
String _pdfText(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

void main() {
  const exporter = ZExporter();

  group('AC1 — Excel : en-têtes + lignes, contenu réel (parité)', () {
    test('classeur .xlsx valide avec en-têtes et valeurs formatées', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final bytes = exporter.toExcelBytes(request);

      // .xlsx = ZIP → préfixe 'PK', bytes non vides.
      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x50); // 'P'
      expect(bytes[1], 0x4B); // 'K'

      final text = _xlsxText(bytes);
      // En-têtes (header = label ?? name).
      expect(text, contains('Nom'));
      expect(text, contains('Statut'));
      expect(text, contains('age'));
      expect(text, contains('created'));
      // Valeurs formatées via col.format (parité écran).
      expect(text, contains('Alice'));
      expect(text, contains('Bob'));
      expect(text, contains('Ouvert')); // select → libellé de choix
      expect(text, contains('a, b')); // tags → join ', '
      expect(text, contains('30'));
      expect(text, contains('2026-01-02T03:04:05.000Z')); // dateTime ISO
    });

    test('resolveHeader résout la clé l10n des en-têtes (headless)', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final bytes = exporter.toExcelBytes(
        request,
        resolveHeader: (key) => key.toUpperCase(),
      );
      final text = _xlsxText(bytes);
      expect(text, contains('NOM'));
      expect(text, contains('STATUT'));
    });
  });

  group('AC2 — PDF : document tabulaire valide, contenu réel', () {
    test('%PDF non vide, en-têtes + valeurs présents (parité)', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final bytes = exporter.toPdfBytes(request);

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');

      final text = _pdfText(bytes);
      expect(text, contains('Nom'));
      expect(text, contains('Statut'));
      expect(text, contains('Alice'));
      expect(text, contains('Ouvert'));
      expect(text, contains('a, b'));
    });
  });

  group('AC3 — colonnes dérivées du schéma respectées (SM-5)', () {
    test('id (isId) et richText exclus ; ordre/visibilité = deriveColumns', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final names = request.columns.map((c) => c.name).toList();
      expect(names, <String>['name', 'age', 'active', 'status', 'tags', 'created']);
      expect(names, isNot(contains('id')));
      expect(names, isNot(contains('notes')));

      // L'export n'ajoute/retire aucune colonne : même cardinalité qu'à l'écran.
      final text = _xlsxText(exporter.toExcelBytes(request));
      expect(text, isNot(contains('longue note'))); // richText jamais exporté
    });

    test('ZColumnPolicy.forceInclude fait apparaître un champ exclu', () {
      final request = ZListRenderRequest.fromSchema(
        _schema(),
        _rows(),
        policy: const ZColumnPolicy(forceInclude: <String>{'id'}),
      );
      expect(request.columns.map((c) => c.name), contains('id'));
      final text = _xlsxText(exporter.toExcelBytes(request));
      expect(text, contains('Alice'));
    });

    test('forceExclude prioritaire sur forceInclude', () {
      final request = ZListRenderRequest.fromSchema(
        _schema(),
        _rows(),
        policy: const ZColumnPolicy(
          forceInclude: <String>{'name'},
          forceExclude: <String>{'name'},
        ),
      );
      expect(request.columns.map((c) => c.name), isNot(contains('name')));
    });
  });

  group('AC4/AC10 — défensif : vides / clé absente / null (AD-10)', () {
    ZListRenderRequest emptyRows() =>
        ZListRenderRequest.fromSchema(_schema(), const <ZListRow>[]);
    const emptyCols =
        ZListRenderRequest(columns: <ZListColumn>[], rows: <ZListRow>[]);
    ZListRenderRequest missingKeys() => ZListRenderRequest.fromSchema(
          _schema(),
          const <ZListRow>[ZListRow(id: 'x', cells: <String, Object?>{})],
        );

    test('rows vides → en-têtes seuls, pas de crash', () {
      expect(() => exporter.toExcelBytes(emptyRows()), returnsNormally);
      expect(() => exporter.toPdfBytes(emptyRows()), returnsNormally);
      final xlsx = exporter.toExcelBytes(emptyRows());
      expect(xlsx, isNotEmpty);
      expect(_xlsxText(xlsx), contains('Nom'));
    });

    test('columns vides → fichiers valides sans colonne', () {
      final xlsx = exporter.toExcelBytes(emptyCols);
      final pdf = exporter.toPdfBytes(emptyCols);
      expect(xlsx, isNotEmpty);
      expect(xlsx[0], 0x50); // ZIP valide
      expect(pdf, isNotEmpty);
      expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
    });

    test('clé de cellule absente → cellule vide, pas de crash', () {
      expect(() => exporter.toExcelBytes(missingKeys()), returnsNormally);
      expect(() => exporter.toPdfBytes(missingKeys()), returnsNormally);
    });

    test('tout vide → Excel + PDF non-null valides', () {
      final xlsx = exporter.toExcelBytes(emptyCols);
      final pdf = exporter.toPdfBytes(emptyCols);
      expect(xlsx, isA<Uint8List>());
      expect(pdf, isA<Uint8List>());
    });

    test('valeur null → cellule vide (row2 : age/created absents)', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      // Le formateur pur du cœur mappe null/absent → '' ; l'export n'y ajoute
      // rien : pas d'exception, bytes produits.
      expect(() => exporter.toExcelBytes(request), returnsNormally);
      expect(() => exporter.toPdfBytes(request), returnsNormally);
    });
  });

  group('ZExportTable — projection neutre (parité formatage)', () {
    test('cellule = col.format(row.cells[name]) ; défensif', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final table = ZExportTable.fromRequest(request);
      expect(table.headers, <String>[
        'Nom', 'age', 'active', 'Statut', 'tags', 'created',
      ]);
      expect(table.columnCount, 6);
      expect(table.rowCount, 2);
      // row1 : status → 'Ouvert', tags → 'a, b', created → ISO.
      final r1 = table.rows[0];
      expect(r1[0], 'Alice');
      expect(r1[3], 'Ouvert');
      expect(r1[4], 'a, b');
      expect(r1[5], '2026-01-02T03:04:05.000Z');
      // row2 : age absent → '', created absent → '', tags [] → ''.
      final r2 = table.rows[1];
      expect(r2[1], ''); // age
      expect(r2[4], ''); // tags []
      expect(r2[5], ''); // created
    });
  });
}
