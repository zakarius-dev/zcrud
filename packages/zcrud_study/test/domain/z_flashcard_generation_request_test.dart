// SU-9/AC1/AC2 — requête d'union canonique (AD-37) : les 6 dimensions portées
// PAR VALEUR, `modelId` OPAQUE transporté verbatim (jamais interprété).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

ZFlashcardGenerationRequest _base() => const ZFlashcardGenerationRequest(
      content: 'source text',
      count: 10,
      languageTag: 'fr',
    );

void main() {
  group('AC1 — les 6 dimensions sont portées', () {
    test('les trois nouveaux champs sont conservés', () {
      final req = ZFlashcardGenerationRequest(
        content: 'c',
        count: 5,
        languageTag: 'en',
        provenance: ZCustomSource('article', const <String, dynamic>{'id': '42'}),
        typesDistribution: const <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 3,
          ZFlashcardType.trueOrFalse: 2,
        },
        instructions: 'insiste sur les définitions',
        modelId: 'router:xyz-42/experimental',
      );
      expect(req.typesDistribution, <ZFlashcardType, int>{
        ZFlashcardType.openQuestion: 3,
        ZFlashcardType.trueOrFalse: 2,
      });
      expect(req.instructions, 'insiste sur les définitions');
      expect(req.modelId, 'router:xyz-42/experimental');
      expect(req.provenance, isA<ZCustomSource>());
    });

    test('== / hashCode incluent modelId (deux requêtes diffèrent par lui)', () {
      final a = _base();
      final b = ZFlashcardGenerationRequest(
        content: a.content,
        count: a.count,
        languageTag: a.languageTag,
        modelId: 'm-1',
      );
      expect(a == b, isFalse, reason: 'modelId doit compter dans ==');
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('== / hashCode incluent instructions', () {
      final a = _base();
      final b = ZFlashcardGenerationRequest(
        content: a.content,
        count: a.count,
        languageTag: a.languageTag,
        instructions: 'x',
      );
      expect(a == b, isFalse);
      expect(a.hashCode == b.hashCode, isFalse);
    });

    test('== / hashCode incluent typesDistribution (par valeur, profond)', () {
      final a = ZFlashcardGenerationRequest(
        content: 'c',
        typesDistribution: const <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 3,
        },
      );
      final b = ZFlashcardGenerationRequest(
        content: 'c',
        typesDistribution: const <ZFlashcardType, int>{
          ZFlashcardType.openQuestion: 4,
        },
      );
      expect(a == b, isFalse, reason: 'la valeur de la map doit compter');
      // Deux maps de contenu identique mais d'identité différente ⇒ ÉGALES.
      final c = ZFlashcardGenerationRequest(
        content: 'c',
        typesDistribution: <ZFlashcardType, int>{ZFlashcardType.openQuestion: 3},
      );
      expect(a == c, isTrue, reason: 'égalité PROFONDE (pas d\'identité)');
      expect(a.hashCode, c.hashCode);
    });

    test('deux requêtes identiques sur toutes les dimensions sont égales', () {
      final a = _base();
      final b = _base();
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('AC2 — modelId OPAQUE : round-trip VERBATIM, jamais interprété', () {
    test('une chaîne opaque inédite est portée EXACTEMENT (aucune normalisation)',
        () {
      // Si modelId devenait une enum/un type fermé, cette valeur libre ne
      // pourrait plus être portée telle quelle — la garde rougirait.
      const opaque = 'vendor://ns.Model+2026?exp=beta&x=/slash\\back';
      final req = ZFlashcardGenerationRequest(content: 'c', modelId: opaque);
      expect(req.modelId, opaque);
      // Le type reste bien `String?` (aucun catalogue/enum).
      expect(req.modelId, isA<String?>());
    });

    test('modelId null par défaut (l\'app décide)', () {
      expect(const ZFlashcardGenerationRequest(content: 'c').modelId, isNull);
    });
  });
}
