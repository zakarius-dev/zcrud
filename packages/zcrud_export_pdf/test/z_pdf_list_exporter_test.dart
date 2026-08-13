// Gardes de l'exporteur PDF branché sur le port `ZListExporter`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export_pdf/zcrud_export_pdf.dart';

ZListRenderRequest _request() => ZListRenderRequest.fromSchema(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
        const ZFieldSpec(name: 'nom', type: EditionFieldType.text),
      ],
      <ZListRow>[
        const ZListRow(id: '1', cells: <String, Object?>{'nom': 'Alice'}),
      ],
    );

void main() {
  group('ZPdfListExporter', () {
    test('se déclare comme format PDF', () {
      const exporter = ZPdfListExporter();
      expect(exporter.id, 'pdf');
      expect(exporter.labelKey, 'PDF');
      expect(exporter.fileExtension, 'pdf');
      expect(exporter.mimeType, 'application/pdf');
    });

    test('produit un document PDF réel', () async {
      final result = await const ZPdfListExporter().export(_request());
      final bytes = result.fold((_) => <int>[], (b) => b);
      expect(bytes.length, greaterThan(0));
      expect(
        String.fromCharCodes(bytes.take(5)),
        '%PDF-',
        reason: 'les octets rendus doivent être un PDF, pas un placeholder',
      );
    });

    test('le titre de l\'écran devient le titre du document', () {
      expect(
        const ZPdfListExporter().effectiveOptions('Consignataires').title,
        'Consignataires',
      );
      expect(const ZPdfListExporter().effectiveOptions(null).title, isNull);
    });

    test('un titre déclaré dans les options FAIT AUTORITÉ sur celui de l\'écran',
        () {
      const exporter = ZPdfListExporter(
        options: ZPdfExportOptions(
          title: 'Titre déclaré',
          orientation: ZPdfOrientation.landscape,
        ),
      );
      final effective = exporter.effectiveOptions('Titre d\'écran');
      expect(effective.title, 'Titre déclaré');
      expect(
        effective.orientation,
        ZPdfOrientation.landscape,
        reason: 'les autres réglages déclarés survivent au comblement',
      );
    });

    test('les réglages déclarés SURVIVENT quand le titre est comblé', () {
      const exporter = ZPdfListExporter(
        options: ZPdfExportOptions(
          orientation: ZPdfOrientation.landscape,
          repeatHeader: false,
          latexEnabled: false,
        ),
      );
      final effective = exporter.effectiveOptions('Consignataires');
      expect(effective.title, 'Consignataires');
      expect(effective.orientation, ZPdfOrientation.landscape);
      expect(effective.repeatHeader, isFalse);
      expect(effective.latexEnabled, isFalse);
    });

    test('une requête vide ne lève pas (AD-10)', () async {
      final result = await const ZPdfListExporter().exportSafely(
        const ZListRenderRequest(columns: <ZListColumn>[], rows: <ZListRow>[]),
      );
      expect(result.isRight(), isTrue);
    });
  });

  group('ZExportTable — parité écran/fichier', () {
    test('la cellule est lue EN CONNAISSANT LA LIGNE (devise portée par ligne)',
        () {
      final table = ZExportTable.fromRequest(
        ZListRenderRequest(
          columns: <ZListColumn>[
            ZListColumn(
              name: 'montant',
              header: 'Montant',
              type: EditionFieldType.number,
              order: 0,
              format: (raw) => '$raw',
              formatWithRow: (raw, row) => '$raw ${row['devise']}',
            ),
          ],
          rows: const <ZListRow>[
            ZListRow(
              id: '1',
              cells: <String, Object?>{'montant': 1200, 'devise': 'XOF'},
            ),
            ZListRow(
              id: '2',
              cells: <String, Object?>{'montant': 30, 'devise': 'EUR'},
            ),
          ],
        ),
      );
      expect(table.rows[0].single, '1200 XOF');
      expect(table.rows[1].single, '30 EUR');
    });
  });
}
