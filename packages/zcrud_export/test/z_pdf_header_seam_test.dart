// CR pilote DODLP 2026-08-11 (Lot 4 — Exports) : seam d'en-tête PDF RICHE dans
// `ZPdfExportOptions.header` (parité `dodlp_pdf_header.dart` : logo + lignes
// organisationnelles + sous-titre), 100 % ADDITIF (AD-10) — `header == null`
// (défaut) conserve le rendu historique E11a-3 bit pour bit.
//
// R3 : chaque assertion de contenu ci-dessous a été rejouée manuellement contre
// une version de `buildPdfBytes`/`z_pdf_exporter.dart` où la branche
// `if (header != null) { ... }` était neutralisée (retour direct à l'ancien
// bloc `if (title != null) {...}` pour toute valeur de `header`) : les tests
// « logo + org + sous-titre » rougissaient PAR ASSERTION (texte absent), preuve
// que la garde mord réellement sur l'implémentation et non sur un artefact de
// setup. Restauration faite PAR ÉDITION CIBLÉE (jamais git checkout).
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_export/zcrud_export.dart';

/// PNG 1×1 valide et décodable — logo de test (pas d'asset réel nécessaire).
final Uint8List _kOnePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

List<ZFieldSpec> _schema() => <ZFieldSpec>[
      const ZFieldSpec(name: 'nom', type: EditionFieldType.text, label: 'Nom'),
    ];

List<ZListRow> _rows() => <ZListRow>[
      ZListRow(id: '1', cells: const <String, Object?>{'nom': 'Dupont'}),
    ];

String _pdfText(Uint8List bytes) {
  final document = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(document).extractText();
  } finally {
    document.dispose();
  }
}

void _assertValidPdf(Uint8List bytes) {
  expect(bytes, isNotEmpty);
  expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
}

void main() {
  const exporter = ZExporter();

  group('ZPdfHeaderSpec — valeur neutre, égalité', () {
    test('égalité de valeur (const-constructible), y compris logoBytes', () {
      const a = ZPdfHeaderSpec(
        organizationLines: <String>['Agence X', 'Division Y'],
        subtitle: 'Sous-titre',
      );
      const b = ZPdfHeaderSpec(
        organizationLines: <String>['Agence X', 'Division Y'],
        subtitle: 'Sous-titre',
      );
      const c = ZPdfHeaderSpec(
        organizationLines: <String>['Agence X', 'Division Z'],
        subtitle: 'Sous-titre',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));

      final withBytesA = ZPdfHeaderSpec(logoBytes: Uint8List.fromList([1, 2, 3]));
      final withBytesB = ZPdfHeaderSpec(logoBytes: Uint8List.fromList([1, 2, 3]));
      final withBytesC = ZPdfHeaderSpec(logoBytes: Uint8List.fromList([1, 2, 4]));
      expect(withBytesA, equals(withBytesB));
      expect(withBytesA.hashCode, withBytesB.hashCode);
      expect(withBytesA, isNot(equals(withBytesC)));
    });

    test('défauts : logoBytes null, lignes vides, sous-titre null, 60x60', () {
      const spec = ZPdfHeaderSpec();
      expect(spec.logoBytes, isNull);
      expect(spec.organizationLines, isEmpty);
      expect(spec.subtitle, isNull);
      expect(spec.logoWidth, 60);
      expect(spec.logoHeight, 60);
    });

    test('ZPdfExportOptions : header entre dans l\'égalité de valeur', () {
      const h1 = ZPdfHeaderSpec(organizationLines: <String>['A']);
      const h2 = ZPdfHeaderSpec(organizationLines: <String>['A']);
      const optsA = ZPdfExportOptions(title: 't', header: h1);
      const optsB = ZPdfExportOptions(title: 't', header: h2);
      const optsNoHeader = ZPdfExportOptions(title: 't');
      expect(optsA, equals(optsB));
      expect(optsA.hashCode, optsB.hashCode);
      expect(optsA, isNot(equals(optsNoHeader)));
      expect(const ZPdfExportOptions().header, isNull);
    });
  });

  group('AC — en-tête riche opt-in : contenu réellement rendu', () {
    test(
        'header != null → logo (sans crash) + lignes organisationnelles + '
        'sous-titre + titre TOUS présents dans le texte extrait', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final bytes = exporter.toPdfBytes(
        request,
        options: ZPdfExportOptions(
          title: 'Titre Du Rapport',
          header: ZPdfHeaderSpec(
            logoBytes: _kOnePixelPng,
            organizationLines: const <String>[
              'Organisation Exemple',
              'Division Exemple',
            ],
            subtitle: 'Sous-titre Exemple',
          ),
        ),
      );
      _assertValidPdf(bytes);
      final text = _pdfText(bytes);
      expect(text, contains('Organisation Exemple'),
          reason: 'ligne organisationnelle absente du rendu — seam inerte');
      expect(text, contains('Division Exemple'),
          reason: 'seconde ligne organisationnelle absente — jointure défaillante');
      expect(text, contains('Sous-titre Exemple'),
          reason: 'sous-titre absent — seam inerte');
      expect(text, contains('Titre Du Rapport'),
          reason: 'titre absent quand header fourni (branche riche cassée)');
      // Contenu tabulaire toujours présent (le header ne masque pas la grille).
      expect(text, contains('Dupont'));
    });

    test('header avec logoBytes NON décodable → défensif (AD-10), reste rendu',
        () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final garbage = Uint8List.fromList(<int>[0, 1, 2, 3, 4, 5]);
      Uint8List? bytes;
      expect(
        () => bytes = exporter.toPdfBytes(
          request,
          options: ZPdfExportOptions(
            title: 'T',
            header: ZPdfHeaderSpec(
              logoBytes: garbage,
              organizationLines: const <String>['Org Robuste'],
            ),
          ),
        ),
        returnsNormally,
        reason: 'un logo non décodable ne doit JAMAIS faire crasher l\'export',
      );
      _assertValidPdf(bytes!);
      final text = _pdfText(bytes!);
      expect(text, contains('Org Robuste'),
          reason: 'le reste de l\'en-tête doit survivre à un logo invalide');
      expect(text, contains('T'));
    });

    test('header avec SEULEMENT logo (pas de lignes/sous-titre) → valide', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final bytes = exporter.toPdfBytes(
        request,
        options: ZPdfExportOptions(
          header: ZPdfHeaderSpec(logoBytes: _kOnePixelPng),
        ),
      );
      _assertValidPdf(bytes);
      expect(_pdfText(bytes), contains('Dupont'));
    });
  });

  group('AC — rétro-compat STRICTE : header == null == comportement E11a-3', () {
    test('sans header (options avec titre seul) : rendu identique au bloc '
        'historique — même contenu que la garde AC9 pré-existante', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      final withoutHeader = exporter.toPdfBytes(
        request,
        options: const ZPdfExportOptions(title: 'Rapport'),
      );
      _assertValidPdf(withoutHeader);
      final text = _pdfText(withoutHeader);
      expect(text, contains('Rapport'));
      expect(text, contains('Dupont'));
      // Aucune trace d'un quelconque artefact du chemin "header riche" :
      // le champ header est bien absent par défaut.
      expect(const ZPdfExportOptions(title: 'Rapport').header, isNull);
    });

    test('options == null (aucun header possible) → comportement inchangé', () {
      final request = ZListRenderRequest.fromSchema(_schema(), _rows());
      expect(() => exporter.toPdfBytes(request), returnsNormally);
    });
  });
}
