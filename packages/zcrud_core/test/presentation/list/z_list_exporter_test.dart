// Gardes du port d'export de liste : le contrat neutre, sa blindage défensif
// (AD-10) et la composition du nom de fichier.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Exporteur qui LÈVE — le cas que l'assemblage ne doit jamais laisser passer.
class _ThrowingExporter implements ZListExporter {
  const _ThrowingExporter();

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

/// Exporteur qui rend un échec ordinaire.
class _FailingExporter implements ZListExporter {
  const _FailingExporter();

  @override
  String get id => 'fail';
  @override
  String get labelKey => 'Fail';
  @override
  String get fileExtension => 'fail';
  @override
  String get mimeType => 'application/x-fail';

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async =>
      Left<ZFailure, Uint8List>(const ZDomainFailure('refus'));
}

/// Exporteur nominal : rend le nombre de colonnes et de lignes reçues.
class _CountingExporter implements ZListExporter {
  const _CountingExporter();

  @override
  String get id => 'count';
  @override
  String get labelKey => 'Count';
  @override
  String get fileExtension => 'bin';
  @override
  String get mimeType => 'application/octet-stream';

  @override
  Future<ZResult<Uint8List>> export(
    ZListRenderRequest request, {
    String? title,
    String Function(String headerKey)? resolveHeader,
  }) async =>
      Right<ZFailure, Uint8List>(
        Uint8List.fromList(<int>[request.columns.length, request.rows.length]),
      );
}

void main() {
  const request = ZListRenderRequest(
    columns: <ZListColumn>[],
    rows: <ZListRow>[],
  );

  group('ZListExporter — blindage défensif (AD-10)', () {
    test('un exporteur qui LÈVE devient un échec, jamais une exception', () async {
      const exporter = _ThrowingExporter();

      // Le chemin nu propage bien le jet : c'est ce que le blindage intercepte.
      await expectLater(exporter.export(request), throwsStateError);

      final result = await exporter.exportSafely(request);
      expect(
        result.isLeft(),
        isTrue,
        reason: 'un jet doit devenir un Left, sinon l\'écran est emporté',
      );
      expect(
        result.fold((f) => f.message, (_) => ''),
        contains('moteur indisponible'),
        reason: 'le jet d\'origine doit rester diagnosticable',
      );
    });

    test('un échec ordinaire traverse le blindage tel quel', () async {
      final result = await const _FailingExporter().exportSafely(request);
      expect(result.fold((f) => f.message, (_) => ''), 'refus');
    });

    test('un succès traverse le blindage tel quel', () async {
      final result = await const _CountingExporter().exportSafely(request);
      expect(result.fold((_) => <int>[], (b) => b.toList()), <int>[0, 0]);
    });
  });

  group('ZListExporter — ce que le port transporte', () {
    test('les colonnes reçues sont celles dérivées du schéma, sans identité',
        () async {
      final fields = <ZFieldSpec>[
        const ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
        const ZFieldSpec(name: 'nom', type: EditionFieldType.text),
      ];
      final built = ZListRenderRequest.fromSchema(
        fields,
        <ZListRow>[
          const ZListRow(id: 'a', cells: <String, Object?>{'nom': 'Alice'}),
        ],
      );
      expect(
        built.columns.map((c) => c.name),
        <String>['nom'],
        reason: 'le champ d\'identité n\'est pas une colonne exportable',
      );
      final bytes = await const _CountingExporter()
          .exportSafely(built)
          .then((r) => r.fold((_) => <int>[], (b) => b.toList()));
      expect(bytes, <int>[1, 1]);
    });

    test(
        'la colonne technique de NUMÉRO D\'ORDRE reste hors des colonnes '
        'exportables', () async {
      final built = ZListRenderRequest.fromSchema(
        <ZFieldSpec>[const ZFieldSpec(name: 'nom', type: EditionFieldType.text)],
        <ZListRow>[
          const ZListRow(id: 'a', cells: <String, Object?>{'nom': 'Alice'}),
        ],
        policy: const ZColumnPolicy(ordinal: ZListOrdinal(enabled: true)),
      );
      expect(built.ordinal.enabled, isTrue, reason: 'la colonne est demandée');
      expect(
        built.columns.map((c) => c.name),
        isNot(contains(ZListOrdinal.columnName)),
        reason: 'le numéro d\'ordre décrit une position d\'écran, pas une donnée',
      );
      expect(built.columns.map((c) => c.name), <String>['nom']);
    });
  });

  group('zExportFileName', () {
    test('retient lettres, chiffres, tiret et tiret bas', () {
      expect(zExportFileName('Consignataires', 'csv'), 'Consignataires.csv');
      expect(zExportFileName('mes-listes_2026', 'csv'), 'mes-listes_2026.csv');
    });

    test('remplace la ponctuation et réduit les répétitions', () {
      expect(zExportFileName('Écrans / listes : 2026', 'pdf'),
          'crans_listes_2026.pdf');
      expect(zExportFileName('a   b', 'csv'), 'a_b.csv');
    });

    test('un titre sans caractère retenu donne un nom générique', () {
      expect(zExportFileName('', 'csv'), 'export.csv');
      expect(zExportFileName('///', 'xlsx'), 'export.xlsx');
    });
  });
}
