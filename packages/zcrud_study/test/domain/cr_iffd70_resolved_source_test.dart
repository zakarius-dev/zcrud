// CR-IFFD-70 — value-objects du créneau « prendre sa source sur place » :
// `ZResolvedGenerationSource` (3 formes : texte / paginé PARTIEL / par
// RÉFÉRENCE) + extension ADDITIVE `resolvedSources` de la requête d'union.
// Runner : `flutter test` DEPUIS packages/zcrud_study.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

void main() {
  group('CR-70 — ZResolvedGenerationSource : les 3 formes, égalité par valeur', () {
    test('forme PAR RÉFÉRENCE : text et pagesContents nuls, provenance portée '
        '(couvre le legacy …FromWholeDocument)', () {
      final source = ZResolvedGenerationSource(
        provenance: ZCustomSource('document', const <String, dynamic>{'id': 'd7'}),
      );
      expect(source.text, isNull);
      expect(source.pagesContents, isNull);
      expect(source.provenance, isNotNull,
          reason: 'la référence (documentId) voyage par la provenance — '
              'l\'impl app-side du port extrait côté serveur');
    });

    test('forme PAGINÉE PARTIELLE : seules les pages CHOISIES sont portées', () {
      const source = ZResolvedGenerationSource(
        pagesContents: <int, String>{3: 'page trois', 7: 'page sept'},
      );
      expect(source.pagesContents, hasLength(2));
      expect(source.pagesContents![3], 'page trois');
      expect(source.pagesContents!.containsKey(1), isFalse,
          reason: 'une source volumineuse (PDF 300 p.) se résout PARTIELLEMENT');
    });

    test('égalité PROFONDE du contenu paginé (indépendante de l\'ordre)', () {
      const a = ZResolvedGenerationSource(
        pagesContents: <int, String>{1: 'un', 2: 'deux'},
      );
      const b = ZResolvedGenerationSource(
        pagesContents: <int, String>{2: 'deux', 1: 'un'},
      );
      const c = ZResolvedGenerationSource(
        pagesContents: <int, String>{1: 'un', 2: 'MUTÉ'},
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)),
          reason: 'le CONTENU d\'une page compte dans l\'égalité (value-object)');
    });
  });

  group('CR-70 — requête : `resolvedSources` ADDITIF, value-object préservé', () {
    test('🔴 deux requêtes qui ne diffèrent QUE par resolvedSources sont '
        'INÉGALES (et deep-equal ⇒ égales, hash compris)', () {
      const base = ZFlashcardGenerationRequest(content: 'x');
      const withSources = ZFlashcardGenerationRequest(
        content: 'x',
        resolvedSources: <ZResolvedGenerationSource>[
          ZResolvedGenerationSource(text: 's1'),
        ],
      );
      const withSourcesBis = ZFlashcardGenerationRequest(
        content: 'x',
        resolvedSources: <ZResolvedGenerationSource>[
          ZResolvedGenerationSource(text: 's1'),
        ],
      );
      expect(base, isNot(equals(withSources)),
          reason: 'resolvedSources participe à l\'égalité par valeur');
      expect(withSources, equals(withSourcesBis));
      expect(withSources.hashCode, withSourcesBis.hashCode);
    });

    test('l\'ORDRE des sources compte (composition = ordre de présentation)', () {
      const ab = ZFlashcardGenerationRequest(
        content: 'x',
        resolvedSources: <ZResolvedGenerationSource>[
          ZResolvedGenerationSource(text: 'a'),
          ZResolvedGenerationSource(text: 'b'),
        ],
      );
      const ba = ZFlashcardGenerationRequest(
        content: 'x',
        resolvedSources: <ZResolvedGenerationSource>[
          ZResolvedGenerationSource(text: 'b'),
          ZResolvedGenerationSource(text: 'a'),
        ],
      );
      expect(ab, isNot(equals(ba)));
    });

    test('withResolvedSources : appose les sources, préserve TOUS les autres '
        'champs, liste NON modifiable', () {
      final provenance =
          ZCustomSource('article', const <String, dynamic>{'id': '9'});
      final request = ZFlashcardGenerationRequest(
        content: 'contenu',
        count: 12,
        languageTag: 'fr',
        provenance: provenance,
        typesDistribution: const <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 12,
        },
        instructions: 'insiste',
        modelId: 'opaque-1',
        extra: const <String, dynamic>{'legit': 42},
      );
      final sources = <ZResolvedGenerationSource>[
        const ZResolvedGenerationSource(text: 's1'),
      ];
      final effective = request.withResolvedSources(sources);

      expect(effective.content, 'contenu');
      expect(effective.count, 12);
      expect(effective.languageTag, 'fr');
      expect(effective.provenance, provenance);
      expect(effective.typesDistribution,
          const <ZFlashcardType, int>{ZFlashcardType.openQuestion: 12});
      expect(effective.instructions, 'insiste');
      expect(effective.modelId, 'opaque-1');
      expect(effective.extra['legit'], 42);
      expect(effective.resolvedSources, sources);
      expect(
        () => effective.resolvedSources!
            .add(const ZResolvedGenerationSource(text: 'intrus')),
        throwsUnsupportedError,
        reason: 'value-object : la liste apposée est non modifiable',
      );
      // La requête d'origine reste intacte (immuable).
      expect(request.resolvedSources, isNull);
    });

    test('hôte existant : resolvedSources ABSENT par défaut (null — additif)', () {
      const request = ZFlashcardGenerationRequest(content: 'x');
      expect(request.resolvedSources, isNull,
          reason: 'aucun hôte existant ne change sa construction (CR-70 repli)');
    });
  });
}
