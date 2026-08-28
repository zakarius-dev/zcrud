@TestOn('vm')
/// Contrat P2-F des ports d'extraction de texte et d'OCR.
///
/// Trois familles de gardes :
///
/// 1. **Pureté** — les deux fichiers de port sont du DOMAINE : ni Flutter, ni
///    `dart:ui`, ni nom de moteur/plugin, ni URL de service. Un port qui
///    nommerait son moteur ferait de `zcrud_document` un paquet couplé à ce
///    moteur ; c'est précisément ce que l'indirection évite.
/// 2. **Ports inertes** — sans moteur configuré, TOUT appel rend un `Left`.
///    Jamais une levée, jamais un `Right` vide qui ferait croire au succès.
/// 3. **Valeurs** — round-trip `toMap`/`fromMap` et TOLÉRANCE (AD-10) : une
///    map absente, mal typée ou partiellement corrompue ne fait jamais échouer
///    la reconstruction du parent.
///
/// ⚠️ `dart:io` : ce fichier lit les sources du paquet, il tourne donc sous VM.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_document/zcrud_document.dart';

import 'support/z_sources.dart';

const _portFiles = <String>[
  'lib/src/domain/z_document_text_extraction_port.dart',
  'lib/src/domain/z_document_ocr_port.dart',
];

void main() {
  group('P2-F — pureté des ports', () {
    for (final path in _portFiles) {
      test('⛔ $path ne nomme ni Flutter, ni moteur, ni service', () {
        final source = stripCommentsOf(File(path));
        expect(source, isNot(contains('package:flutter/')));
        expect(source, isNot(contains('dart:ui')));
        expect(source, isNot(contains('http://')));
        expect(source, isNot(contains('https://')));
        for (final engine in const <String>[
          'MethodChannel',
          'ml_kit',
          'mlkit',
          'tesseract',
          'syncfusion',
          'firebase',
          'vision',
        ]) {
          expect(
            source.toLowerCase(),
            isNot(contains(engine.toLowerCase())),
            reason:
                'le port doit rester neutre : nommer $engine y enfermerait '
                'zcrud_document dans un moteur.',
          );
        }
      });
    }
  });

  group('P2-F — ports inertes', () {
    test('l’extraction inerte est indisponible et rend Left', () async {
      const port = ZInertDocumentTextExtractionPort();
      expect(port.isAvailable, isFalse);

      final result = await port.extract(
        ZDocumentTextRequest(documentId: 'd', source: 's'),
      );

      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => null),
        isA<ZUnsupportedOperationFailure>(),
      );
    });

    test('l’OCR inerte est indisponible et rend Left', () async {
      const port = ZInertDocumentOcrPort();
      expect(port.isAvailable, isFalse);

      final result = await port.recognize(
        ZDocumentOcrRequest(documentId: 'd', source: 's'),
      );

      expect(result.isLeft(), isTrue);
      expect(
        result.fold((failure) => failure, (_) => null),
        isA<ZUnsupportedOperationFailure>(),
      );
    });
  });

  group('P2-F — valeurs de requête', () {
    test('round-trip avec pages ciblées, ordonnées dans la map', () {
      final request = ZDocumentTextRequest(
        documentId: 'doc-1',
        source: 'documents/doc-1.pdf',
        pages: <int>{7, 2, 4},
      );

      expect(request.toMap(), <String, dynamic>{
        'document_id': 'doc-1',
        'pages': <int>[2, 4, 7],
        'source': 'documents/doc-1.pdf',
      });
      expect(ZDocumentTextRequest.fromMap(request.toMap()), request);
    });

    test('sans pages, la clé est ABSENTE et le round-trip la garde nulle', () {
      final request = ZDocumentTextRequest(documentId: 'd', source: 's');

      expect(request.toMap().containsKey('pages'), isFalse);
      expect(ZDocumentTextRequest.fromMap(request.toMap()).pages, isNull);
    });

    test('la collection de pages est FIGÉE', () {
      final request = ZDocumentTextRequest(
        documentId: 'd',
        source: 's',
        pages: <int>{1},
      );

      expect(() => request.pages!.add(2), throwsUnsupportedError);
    });

    test('AD-10 — une map vide ou mal typée ne lève pas', () {
      final empty = ZDocumentTextRequest.fromMap(<String, dynamic>{});
      expect(empty.documentId, '');
      expect(empty.source, '');
      expect(empty.pages, isNull);

      final corrupted = ZDocumentTextRequest.fromMap(<String, dynamic>{
        'document_id': 42,
        'source': <String>['nope'],
        'pages': 'pas une liste',
      });
      expect(corrupted.pages, isNull);
    });

    test('AD-10 — une page illisible est ignorée, les autres survivent', () {
      final decoded = ZDocumentTextRequest.fromMap(<String, dynamic>{
        'document_id': 'd',
        'source': 's',
        'pages': <Object?>[3, null, 'huit', 5],
      });

      expect(decoded.pages, <int>{3, 5});
    });

    test('== compare documentId, source ET pages', () {
      final base = ZDocumentTextRequest(
        documentId: 'd',
        source: 's',
        pages: <int>{1, 2},
      );

      expect(
        base,
        ZDocumentTextRequest(
          documentId: 'd',
          source: 's',
          pages: <int>{2, 1},
        ),
      );
      expect(
        base.hashCode,
        ZDocumentTextRequest(
          documentId: 'd',
          source: 's',
          pages: <int>{2, 1},
        ).hashCode,
      );
      expect(
        base,
        isNot(
          ZDocumentTextRequest(
            documentId: 'd',
            source: 'AUTRE',
            pages: <int>{1, 2},
          ),
        ),
      );
      expect(
        base,
        isNot(ZDocumentTextRequest(documentId: 'd', source: 's')),
      );
    });
  });

  group('P2-F — valeurs de résultat', () {
    test('round-trip du texte, confiance comprise', () {
      final text = ZDocumentText(
        pages: const <ZDocumentPageText>[
          ZDocumentPageText(page: 1, text: 'un', confidence: 0.5),
          ZDocumentPageText(page: 2, text: 'deux'),
        ],
      );

      expect(text.toMap(), <String, dynamic>{
        'pages': <Map<String, dynamic>>[
          <String, dynamic>{'page': 1, 'text': 'un', 'confidence': 0.5},
          <String, dynamic>{'page': 2, 'text': 'deux'},
        ],
      });
      expect(ZDocumentText.fromMap(text.toMap()), text);
    });

    test('la liste de pages est FIGÉE', () {
      final text = ZDocumentText();

      expect(
        () => text.pages.add(const ZDocumentPageText(page: 0, text: '')),
        throwsUnsupportedError,
      );
    });

    test('AD-10 — une page corrompue est SAUTÉE sans perdre les autres', () {
      final decoded = ZDocumentText.fromMap(<String, dynamic>{
        'pages': <Object?>[
          <String, dynamic>{'page': 1, 'text': 'gardée'},
          'pas une map',
          null,
          <String, dynamic>{'page': 2, 'text': 'gardée aussi'},
        ],
      });

      expect(decoded.pages, hasLength(2));
      expect(decoded.pages.map((p) => p.text), <String>[
        'gardée',
        'gardée aussi',
      ]);
    });

    test('AD-10 — pages absentes ou mal typées donnent un texte vide', () {
      expect(ZDocumentText.fromMap(<String, dynamic>{}).pages, isEmpty);
      expect(
        ZDocumentText.fromMap(<String, dynamic>{'pages': 12}).pages,
        isEmpty,
      );
    });

    test('AD-10 — une confiance non finie ou mal typée retombe à null', () {
      expect(
        ZDocumentPageText.fromMap(<String, dynamic>{
          'page': 1,
          'text': 't',
          'confidence': double.nan,
        }).confidence,
        isNull,
      );
      expect(
        ZDocumentPageText.fromMap(<String, dynamic>{
          'page': 1,
          'text': 't',
          'confidence': 'haute',
        }).confidence,
        isNull,
      );
    });

    test('AD-10 — une page sans numéro ni texte vaut 0 et vide', () {
      final page = ZDocumentPageText.fromMap(<String, dynamic>{});

      expect(page.page, 0);
      expect(page.text, '');
      expect(page.confidence, isNull);
    });

    test('== du texte compare les pages en ORDRE', () {
      final ab = ZDocumentText(
        pages: const <ZDocumentPageText>[
          ZDocumentPageText(page: 1, text: 'a'),
          ZDocumentPageText(page: 2, text: 'b'),
        ],
      );
      final ba = ZDocumentText(
        pages: const <ZDocumentPageText>[
          ZDocumentPageText(page: 2, text: 'b'),
          ZDocumentPageText(page: 1, text: 'a'),
        ],
      );

      expect(ab, isNot(ba));
      expect(
        ab,
        ZDocumentText(
          pages: const <ZDocumentPageText>[
            ZDocumentPageText(page: 1, text: 'a'),
            ZDocumentPageText(page: 2, text: 'b'),
          ],
        ),
      );
      expect(
        const ZDocumentPageText(page: 1, text: 'a', confidence: 0.5),
        isNot(const ZDocumentPageText(page: 1, text: 'a')),
      );
    });
  });
}
