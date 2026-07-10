// E11b-3 — Test de SURFACE d'API (Axe D, AC11) : le barrel `zcrud_export.dart`
// verrouille la présence — additive, sans retrait ni renommage — des symboles
// publics. Leçon rétro : la suppression de `ZExportApi` en E11a-3 avait cassé
// `zcrud_flashcard` (`exportApiVersion = ZExportApi.version`), `melos analyze`
// resté RED plusieurs commits. Ce test compile ⇒ tout symbole retiré/renommé
// casse la compilation ici (garde-fou local ; le garde repo-wide reste
// `melos run analyze`).
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_export/zcrud_export.dart';

void main() {
  test('AC11 — API STABLE E11a-3 toujours exportée (aucun retrait)', () {
    // ZExportApi : marqueur consommé par zcrud_flashcard — nom `version` figé.
    expect(ZExportApi.version, isA<String>());
    expect(ZExportApi.coreApiVersion, isA<String>());
    // ZExporter (façade tabulaire) + ZExportTable (projection neutre).
    const exporter = ZExporter();
    expect(exporter, isA<ZExporter>());
    const table = ZExportTable(headers: <String>[], rows: <List<String>>[]);
    expect(table.columnCount, 0);
  });

  test('AC11 — ajouts additifs E11b-3 exportés par le barrel', () {
    // ZPdfCreationService (images → PDF).
    const service = ZPdfCreationService();
    expect(service, isA<ZPdfCreationService>());
    expect(service.buildFromImages(const <Uint8List>[]), isA<Uint8List>());

    // ZFileSaver + ZFileSaveResult.
    const saver = ZFileSaver();
    expect(saver, isA<ZFileSaver>());
    const result = ZFileSaveResult(fileName: 'f', success: true, path: '/tmp/f');
    expect(result.fileName, 'f');
    expect(result.success, isTrue);

    // ZPdfExportOptions + ZPdfOrientation.
    const options = ZPdfExportOptions(
      orientation: ZPdfOrientation.landscape,
      title: 't',
      repeatHeader: false,
    );
    expect(options.orientation, ZPdfOrientation.landscape);
    expect(ZPdfOrientation.values, contains(ZPdfOrientation.portrait));
  });
}
