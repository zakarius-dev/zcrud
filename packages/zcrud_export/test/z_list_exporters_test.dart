// Gardes des exporteurs de liste branchés sur le port `ZListExporter` :
// contenu réel du CSV, parité de formatage avec l'écran, exclusion des
// colonnes techniques.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// Décode le CSV produit, marque d'ordre des octets retirée, en lignes.
List<String> _lines(List<int> bytes) {
  var text = utf8.decode(bytes);
  if (text.startsWith('﻿')) text = text.substring(1);
  return text.split('\r\n').where((line) => line.isNotEmpty).toList();
}

ZListRenderRequest _request() => ZListRenderRequest.fromSchema(
      <ZFieldSpec>[
        const ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
        const ZFieldSpec(name: 'nom', label: 'label.nom', type: EditionFieldType.text),
        const ZFieldSpec(name: 'montant', type: EditionFieldType.number),
      ],
      <ZListRow>[
        const ZListRow(
          id: '1',
          cells: <String, Object?>{'nom': 'Alice', 'montant': 1200},
        ),
        const ZListRow(
          id: '2',
          cells: <String, Object?>{'nom': 'Bob; "le vrai"', 'montant': 30},
        ),
      ],
    );

void main() {
  group('ZCsvListExporter — le fichier dit ce que l\'écran montre', () {
    test('en-tête résolu puis une ligne par ligne affichée', () async {
      final result = await const ZCsvListExporter().export(
        _request(),
        resolveHeader: (key) => key == 'label.nom' ? 'Nom' : key,
      );
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(lines.first, 'Nom,montant');
      expect(lines.length, 3, reason: 'un en-tête + deux lignes');
      expect(lines[1], 'Alice,1200');
    });

    test('la colonne d\'IDENTITÉ n\'est jamais écrite', () async {
      final result = await const ZCsvListExporter().export(_request());
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(lines.first, isNot(contains('id')));
      expect(lines[1], isNot(contains('1,Alice')));
    });

    test('la colonne technique de NUMÉRO D\'ORDRE n\'est jamais écrite',
        () async {
      final request = ZListRenderRequest.fromSchema(
        <ZFieldSpec>[const ZFieldSpec(name: 'nom', type: EditionFieldType.text)],
        <ZListRow>[
          const ZListRow(id: 'a', cells: <String, Object?>{'nom': 'Alice'}),
        ],
        policy: const ZColumnPolicy(ordinal: ZListOrdinal(enabled: true)),
      );
      final result = await const ZCsvListExporter().export(request);
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(lines.first, 'nom');
      expect(lines[1], 'Alice', reason: 'aucun « 1 » de numérotation d\'écran');
    });

    test('séparateur, guillemet et retour à la ligne sont échappés', () async {
      final result = await const ZCsvListExporter().export(_request());
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(lines[2], '"Bob; ""le vrai""",30');
    });

    test('le séparateur déclaré est celui employé', () async {
      final result = await const ZCsvListExporter(delimiter: ';')
          .export(_request());
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(lines.first, 'label.nom;montant');
    });

    test('la marque d\'ordre des octets est présente par défaut, absente sinon',
        () async {
      final avec = await const ZCsvListExporter().export(_request());
      expect(avec.fold((_) => <int>[], (b) => b).take(3), <int>[0xEF, 0xBB, 0xBF]);
      final sans =
          await const ZCsvListExporter(byteOrderMark: false).export(_request());
      expect(
        sans.fold((_) => <int>[], (b) => b).take(3),
        isNot(<int>[0xEF, 0xBB, 0xBF]),
      );
    });

    test('une requête vide donne un fichier valide, jamais un jet', () async {
      final result = await const ZCsvListExporter().exportSafely(
        const ZListRenderRequest(columns: <ZListColumn>[], rows: <ZListRow>[]),
      );
      expect(result.isRight(), isTrue);
    });
  });

  group('Parité écran/fichier — la valeur EXPORTÉE est la valeur FORMATÉE', () {
    ZListRenderRequest requestWithRowFormat() => ZListRenderRequest(
          columns: <ZListColumn>[
            ZListColumn(
              name: 'montant',
              header: 'Montant',
              type: EditionFieldType.number,
              order: 0,
              format: (raw) => '$raw',
              // Ce que B3 apporte : un format qui LIT LA LIGNE (devise portée
              // par la ligne, suffixe composé).
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
        );

    test('CSV — le format dépendant de la ligne est honoré, ligne par ligne',
        () async {
      final result =
          await const ZCsvListExporter().export(requestWithRowFormat());
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(
        lines[1],
        '1200 XOF',
        reason: 'lire la seule valeur brute perdrait la devise, en silence',
      );
      expect(
        lines[2],
        '30 EUR',
        reason: 'chaque ligne porte SA devise — jamais celle de la précédente',
      );
    });

    test('la projection partagée honore aussi le format monétaire déclaré',
        () async {
      final request = ZListRenderRequest(
        columns: <ZListColumn>[
          ZListColumn(
            name: 'montant',
            header: 'Montant',
            type: EditionFieldType.number,
            order: 0,
            format: (raw) => '$raw',
            currency: const ZCurrencyFormat(
              codeField: 'devise',
              fallbackCode: 'XOF',
            ),
          ),
        ],
        rows: const <ZListRow>[
          ZListRow(
            id: '1',
            cells: <String, Object?>{'montant': 1200, 'devise': 'EUR'},
          ),
        ],
      );
      final result = await const ZCsvListExporter().export(request);
      final lines = _lines(result.fold((_) => <int>[], (b) => b));
      expect(lines[1], contains('EUR'));
      expect(lines[1], isNot(equals('1200')));
    });
  });

  group('ZXlsxListExporter — identité du format', () {
    test('produit un classeur non vide et se déclare correctement', () async {
      const exporter = ZXlsxListExporter();
      expect(exporter.id, 'xlsx');
      expect(exporter.fileExtension, 'xlsx');
      expect(
        exporter.mimeType,
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      final result = await exporter.exportSafely(_request());
      expect(result.isRight(), isTrue);
      expect(result.fold((_) => 0, (b) => b.length), greaterThan(0));
    });
  });
}
