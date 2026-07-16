// Story ES-9.3 — surface + content-addressing du seam podcast.
//
// AC1 : type de retour EXACT du port (`ZResult<ZStudyPodcast>`, jamais nu ni
// Stream) + égalité PAR VALEUR du request (extra profond inclus).
// AC4 : COMPOSITION content-addressed — un podcast PRODUIT PAR LE PORT porte le
// `sourceHash` FOURNI ⇒ `isStale` détecte l'obsolescence, et `buildId(sourceId,
// mode)` compose l'id attendu. On n'asserte PAS `isStale`/`buildId` en boîte
// noire (code kernel DÉJÀ testé, piège R20) : on asserte la CIRCULATION du
// `sourceHash` opaque de bout en bout par le seam. Runner R14 : `flutter test`.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study/zcrud_study.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyPodcast, ZPodcastSourceKind, ZPodcastMode;

/// Fake app-side implémentant le port (l'app *implements* son pipeline TTS).
///
/// ESTAMPILLE `request.sourceHash` dans `ZStudyPodcast.sourceHash` et matérialise
/// l'id via `ZStudyPodcast.buildId` — exactement le contrat *content-addressed*
/// (D4). Aucun hashing ici : le hash est FOURNI par le request.
class _FakePodcastPort implements ZPodcastGenerationPort {
  @override
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  ) async =>
      Right<ZFailure, ZStudyPodcast>(
        ZStudyPodcast(
          id: ZStudyPodcast.buildId(request.sourceId, request.mode),
          sourceKind: request.sourceKind,
          sourceId: request.sourceId,
          folderId: request.folderId,
          mode: request.mode,
          sourceHash: request.sourceHash, // ← circulation de l'empreinte opaque
        ),
      );
}

/// Fake retournant systématiquement `Left` (échec quota/TTS).
class _FailingPodcastPort implements ZPodcastGenerationPort {
  @override
  Future<ZResult<ZStudyPodcast>> generatePodcast(
    ZPodcastGenerationRequest request,
  ) async =>
      Left<ZFailure, ZStudyPodcast>(const DomainFailure('quota'));
}

void main() {
  group('AC1 — type de retour EXACT (Either enveloppé, jamais nu)', () {
    test('ZPodcastGenerationPort ⇒ Future<ZResult<ZStudyPodcast>>', () async {
      final ZPodcastGenerationPort port = _FakePodcastPort();
      // Liaison de type statique EXACTE : rougirait à la COMPILATION si la
      // signature devenait `Future<ZStudyPodcast>` nue (R3-I1).
      final Future<ZResult<ZStudyPodcast>> future = port.generatePodcast(
        const ZPodcastGenerationRequest(content: 'x', sourceId: 's1'),
      );
      final res = await future;
      expect(res, isA<Either<ZFailure, ZStudyPodcast>>());
      res.fold(
        (l) => fail('attendu Right'),
        (r) => expect(r, isA<ZStudyPodcast>()),
      );
    });

    test('Left possible en échec (quota/TTS)', () async {
      final ZPodcastGenerationPort port = _FailingPodcastPort();
      final res = await port.generatePodcast(
        const ZPodcastGenerationRequest(content: 'x'),
      );
      expect(res, isA<Either<ZFailure, ZStudyPodcast>>());
      expect(res.isLeft(), isTrue);
    });
  });

  group('AC1 — request = value-object (égalité PAR VALEUR, R3-I1)', () {
    test('== par valeur (extra profond inclus), discrimine chaque champ', () {
      final a = ZPodcastGenerationRequest(
        content: 'src',
        sourceKind: ZPodcastSourceKind.folder,
        sourceId: 's1',
        folderId: 'f1',
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h1',
        languageTag: 'fr',
        extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
      );
      final b = ZPodcastGenerationRequest(
        content: 'src',
        sourceKind: ZPodcastSourceKind.folder,
        sourceId: 's1',
        folderId: 'f1',
        mode: ZPodcastMode.dialogue,
        sourceHash: 'h1',
        languageTag: 'fr',
        extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
      );
      // Deux instances DISTINCTES mais ÉGALES : rougit si `==` devient identité.
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      // Discrimine CHAQUE champ (pouvoir discriminant, R12).
      expect(a, isNot(equals(const ZPodcastGenerationRequest(content: 'src'))));
      expect(
        a,
        isNot(equals(ZPodcastGenerationRequest(
          content: 'src',
          sourceKind: ZPodcastSourceKind.note, // ← seul champ qui change
          sourceId: 's1',
          folderId: 'f1',
          mode: ZPodcastMode.dialogue,
          sourceHash: 'h1',
          languageTag: 'fr',
          extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
        ))),
      );
      expect(
        a,
        isNot(equals(ZPodcastGenerationRequest(
          content: 'src',
          sourceKind: ZPodcastSourceKind.folder,
          sourceId: 's1',
          folderId: 'f1',
          mode: ZPodcastMode.dialogue,
          sourceHash: 'AUTRE', // ← seule l'empreinte change
          languageTag: 'fr',
          extra: const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
        ))),
      );
      // 🔴 LOAD-BEARING (MEDIUM-1 code-review) : verrouille la contribution de
      // CHACUN des 6 autres champs à `==`. Sans ces cas mono-champ, retirer p.ex.
      // `zJsonEquals(extra, …)` ou `folderId == …` de `operator ==` laissait le
      // test faussement VERT. `copyOf` ne varie qu'UN champ à la fois.
      ZPodcastGenerationRequest copyOf({
        String? content,
        String? sourceId,
        String? folderId,
        ZPodcastMode? mode,
        String? languageTag,
        Map<String, dynamic>? extra,
      }) =>
          ZPodcastGenerationRequest(
            content: content ?? 'src',
            sourceKind: ZPodcastSourceKind.folder,
            sourceId: sourceId ?? 's1',
            folderId: folderId ?? 'f1',
            mode: mode ?? ZPodcastMode.dialogue,
            sourceHash: 'h1',
            languageTag: languageTag ?? 'fr',
            extra: extra ?? const <String, dynamic>{'k': 1, 'nested': <String>['a', 'b']},
          );
      expect(a, isNot(equals(copyOf(content: 'AUTRE'))),
          reason: 'content doit discriminer `==`');
      expect(a, isNot(equals(copyOf(sourceId: 'AUTRE'))),
          reason: 'sourceId doit discriminer `==`');
      expect(a, isNot(equals(copyOf(folderId: 'AUTRE'))),
          reason: 'folderId doit discriminer `==`');
      expect(a, isNot(equals(copyOf(mode: ZPodcastMode.simple))),
          reason: 'mode doit discriminer `==`');
      expect(a, isNot(equals(copyOf(languageTag: 'en'))),
          reason: 'languageTag doit discriminer `==`');
      expect(a, isNot(equals(copyOf(extra: const <String, dynamic>{'k': 2}))),
          reason: 'extra (égalité profonde) doit discriminer `==`');
    });
  });

  group('AC4 — content-addressed : le seam FAIT CIRCULER le sourceHash opaque', () {
    test('podcast produit ⇒ isStale détecte obsolescence + id composé', () async {
      final ZPodcastGenerationPort port = _FakePodcastPort();
      const request = ZPodcastGenerationRequest(
        content: 'contenu source',
        sourceKind: ZPodcastSourceKind.note,
        sourceId: 'note42',
        mode: ZPodcastMode.simple,
        sourceHash: 'HASH_FOURNI_PAR_APP',
      );
      final res = await port.generatePodcast(request);
      final podcast = res.getOrElse(() => const ZStudyPodcast());

      // CIRCULATION : l'empreinte FOURNIE par le request est portée par le
      // podcast produit ⇒ l'invalidation content-addressed fonctionne de bout
      // en bout (le seam transporte, il n'invente pas — D4).
      expect(podcast.sourceHash, request.sourceHash);
      expect(podcast.isStale('UN_AUTRE_HASH'), isTrue,
          reason: 'un hash source différent doit invalider (stale)');
      expect(podcast.isStale(request.sourceHash), isFalse,
          reason: 'le même hash source ⇒ podcast frais (non stale)');

      // Identité content-addressed matérialisée par le contrat du port.
      expect(podcast.id, '${request.sourceId}_${request.mode.name}');
      expect(podcast.id, ZStudyPodcast.buildId(request.sourceId, request.mode));
    });

    test('sources distinctes ⇒ ids distincts (pouvoir discriminant)', () async {
      final ZPodcastGenerationPort port = _FakePodcastPort();
      final a = (await port.generatePodcast(const ZPodcastGenerationRequest(
        content: 'c',
        sourceId: 'note42',
        mode: ZPodcastMode.simple,
      )))
          .getOrElse(() => const ZStudyPodcast());
      final b = (await port.generatePodcast(const ZPodcastGenerationRequest(
        content: 'c',
        sourceId: 'folder7',
        mode: ZPodcastMode.dialogue,
      )))
          .getOrElse(() => const ZStudyPodcast());
      expect(a.id, isNot(equals(b.id)),
          reason: '(note42, simple) ≠ (folder7, dialogue) ⇒ ids distincts');
    });
  });
}
