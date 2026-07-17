// Story ES-9.1 — surface des 3 ports IA neutres (AC1) : type de retour EXACT
// (`ZResult<…>`, jamais nu ni Stream) + égalité PAR VALEUR des requests.
// Runner R14 : `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Fake app-side implémentant le port de génération (l'app *implements*).
class _FakeGenerationPort implements ZFlashcardGenerationPort {
  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  ) async =>
      Right<ZFailure, List<ZFlashcard>>(
        <ZFlashcard>[ZFlashcard(question: request.content)],
      );
}

/// Fake app-side du port de génération de carte mentale (SU-12) : renvoie une
/// forêt ÉPHÉMÈRE de nœuds (AD-37), OU un `Left` advisory (AD-10).
class _FakeMindmapGenerationPort implements ZMindmapGenerationPort {
  _FakeMindmapGenerationPort({this.fail = false});

  final bool fail;

  @override
  Future<ZResult<List<ZMindmapNode>>> generateMindmap(
    ZMindmapGenerationRequest request,
  ) async {
    if (fail) return Left<ZFailure, List<ZMindmapNode>>(const DomainFailure('quota'));
    return Right<ZFailure, List<ZMindmapNode>>(
      <ZMindmapNode>[ZMindmapNode(id: 'ephemeral', label: request.content)],
    );
  }
}

class _FakeExplanationPort implements ZAiExplanationPort {
  @override
  Future<ZResult<String>> explain(ZAiExplanationRequest request) async =>
      Right<ZFailure, String>('explained: ${request.content}');
}

class _FakeSummaryPort implements ZNoteSummaryPort {
  @override
  Future<ZResult<String>> summarize(ZNoteSummaryRequest request) async =>
      Left<ZFailure, String>(const DomainFailure('quota'));
}

void main() {
  group('AC1 — type de retour EXACT (Either enveloppé, jamais nu)', () {
    test('ZFlashcardGenerationPort ⇒ Future<ZResult<List<ZFlashcard>>>', () async {
      final ZFlashcardGenerationPort port = _FakeGenerationPort();
      // Liaison de type statique EXACTE : rougirait à la COMPILATION si la
      // signature devenait `Future<List<ZFlashcard>>` nue (R3-I1).
      final Future<ZResult<List<ZFlashcard>>> future =
          port.generateFlashcards(const ZFlashcardGenerationRequest(content: 'x'));
      final res = await future;
      expect(res, isA<Either<ZFailure, List<ZFlashcard>>>());
      res.fold(
        (l) => fail('attendu Right'),
        (r) => expect(r, isA<List<ZFlashcard>>()),
      );
    });

    test('ZAiExplanationPort ⇒ Future<ZResult<String>>', () async {
      final ZAiExplanationPort port = _FakeExplanationPort();
      final Future<ZResult<String>> future =
          port.explain(const ZAiExplanationRequest(content: 'x'));
      final res = await future;
      expect(res, isA<Either<ZFailure, String>>());
      expect(res.getOrElse(() => ''), 'explained: x');
    });

    test('ZNoteSummaryPort ⇒ Future<ZResult<String>> (Left possible)', () async {
      final ZNoteSummaryPort port = _FakeSummaryPort();
      final Future<ZResult<String>> future =
          port.summarize(const ZNoteSummaryRequest(content: 'x'));
      final res = await future;
      expect(res, isA<Either<ZFailure, String>>());
      expect(res.isLeft(), isTrue);
    });

    test(
        'ZMindmapGenerationPort ⇒ Future<ZResult<List<ZMindmapNode>>> (SU-12, AD-37)',
        () async {
      final ZMindmapGenerationPort port = _FakeMindmapGenerationPort();
      // Liaison de type statique EXACTE : rougirait à la COMPILATION si la
      // signature devenait `Future<List<ZMindmapNode>>` nue OU `ZResult<ZMindmap>`
      // (résultat de persistance, interdit AD-37). Forêt éphémère de NŒUDS.
      final Future<ZResult<List<ZMindmapNode>>> future =
          port.generateMindmap(const ZMindmapGenerationRequest(content: 'x'));
      final res = await future;
      expect(res, isA<Either<ZFailure, List<ZMindmapNode>>>());
      res.fold(
        (l) => fail('attendu Right'),
        (r) {
          expect(r, isA<List<ZMindmapNode>>());
          // Résultat ÉPHÉMÈRE : des NŒUDS, jamais un `ZMindmap` (id/folderId).
          expect(r.first, isA<ZMindmapNode>());
        },
      );
    });

    test('ZMindmapGenerationPort ⇒ Left advisory possible (AD-10)', () async {
      final ZMindmapGenerationPort port =
          _FakeMindmapGenerationPort(fail: true);
      final res = await port.generateMindmap(
        const ZMindmapGenerationRequest(content: 'x'),
      );
      expect(res.isLeft(), isTrue); // échec advisory, jamais un throw
    });
  });

  group('AC1 — requests = value-objects (égalité PAR VALEUR, R3-I1)', () {
    test('ZFlashcardGenerationRequest == par valeur (extra profond inclus)', () {
      final a = ZFlashcardGenerationRequest(
        content: 'src',
        count: 3,
        languageTag: 'fr',
        provenance: const ZNoteSource(noteId: 'n1'),
        extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
      );
      final b = ZFlashcardGenerationRequest(
        content: 'src',
        count: 3,
        languageTag: 'fr',
        provenance: const ZNoteSource(noteId: 'n1'),
        extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
      );
      // Deux instances DISTINCTES mais ÉGALES : rougit si `==` devient identité.
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Discrimine un champ qui change.
      expect(
        a,
        isNot(equals(const ZFlashcardGenerationRequest(content: 'src'))),
      );
      expect(
        a,
        isNot(equals(ZFlashcardGenerationRequest(
          content: 'src',
          count: 3,
          languageTag: 'fr',
          provenance: const ZNoteSource(noteId: 'AUTRE'),
        ))),
      );
    });

    test('ZAiExplanationRequest == par valeur', () {
      const a = ZAiExplanationRequest(content: 'c', context: 'ctx', languageTag: 'en');
      const b = ZAiExplanationRequest(content: 'c', context: 'ctx', languageTag: 'en');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const ZAiExplanationRequest(content: 'c'))));
    });

    test('ZNoteSummaryRequest == par valeur', () {
      const a = ZNoteSummaryRequest(content: 'c', maxLength: 200, languageTag: 'fr');
      const b = ZNoteSummaryRequest(content: 'c', maxLength: 200, languageTag: 'fr');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(const ZNoteSummaryRequest(content: 'c', maxLength: 10))));
    });

    test('ZMindmapGenerationRequest == par valeur (extra profond + modelId)', () {
      final a = ZMindmapGenerationRequest(
        content: 'src',
        count: 5,
        languageTag: 'fr',
        instructions: 'une branche par chapitre',
        modelId: 'model-x',
        extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
      );
      final b = ZMindmapGenerationRequest(
        content: 'src',
        count: 5,
        languageTag: 'fr',
        instructions: 'une branche par chapitre',
        modelId: 'model-x',
        extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
      );
      // Deux instances DISTINCTES mais ÉGALES : rougit si `==` devient identité.
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      // Discrimine `modelId` (transporté verbatim — SU-12/AC5) : deux requêtes
      // qui n'en diffèrent QUE par modelId ne sont PAS égales.
      expect(
        a,
        isNot(equals(ZMindmapGenerationRequest(
          content: 'src',
          count: 5,
          languageTag: 'fr',
          instructions: 'une branche par chapitre',
          modelId: 'AUTRE-model',
          extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
        ))),
      );
      // Discrimine aussi le contenu minimal.
      expect(
        a,
        isNot(equals(const ZMindmapGenerationRequest(content: 'src'))),
      );
    });
  });
}
