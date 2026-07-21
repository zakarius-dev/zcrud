/// Tests E9-4 — `ZFlashcardRepository` offline-first + invariant SRS top-level.
///
/// Couvre les 11 ACs : composition via ports neutres, invariant SRS top-level
/// (0 clé SRS dans la map carte), non-duplication au partage, voie d'écriture
/// SRS unique `reviewCard → apply`, matérialisation de l'éphémère, garde
/// `folderId`, défensif (AD-10), `getDue` (filtrage local), offline-first +
/// `sync()` best-effort. Fakes **en mémoire** (aucun Firebase).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

import 'support/fakes.dart';

void main() {
  late FakeCardRepository cards;
  late FakeRepetitionStore reps;
  late ZFlashcardRepository repo;

  setUp(() {
    cards = FakeCardRepository();
    reps = FakeRepetitionStore();
    repo = ZFlashcardRepository(cards: cards, repetitions: reps);
  });

  // Clés SRS qui ne doivent JAMAIS apparaître dans la map d'une carte (AC2).
  // Clés SRS-spécifiques (AC2) — `folder_id` est un champ légitime de la carte
  // et n'en fait donc PAS partie.
  const srsKeys = <String>{
    'interval',
    'repetitions',
    'ease_factor',
    'next_review_date',
    'learned_at',
    'last_quality',
    'repetition_info',
  };

  ZFlashcard ephemeralCard({String? folderId = 'folder-1'}) => ZFlashcard(
        folderId: folderId,
        question: 'Q ?',
        answer: 'A',
      );

  group('AC1 — composition via ports neutres injectés', () {
    test('construction avec fakes en mémoire ; écritures via ports injectés',
        () async {
      final saved = await repo.save(ephemeralCard());
      expect(saved.isRight(), isTrue);
      expect(cards.saveCount, 1, reason: 'le port carte injecté est utilisé');

      final init = await repo.initRepetition(
        flashcardId: 'c1',
        folderId: 'folder-1',
      );
      expect(init.isRight(), isTrue);
      expect(reps.putCount, 1, reason: 'le port SRS injecté est utilisé');
    });
  });

  group('AC2 — INVARIANT SRS top-level (jamais dans la map carte)', () {
    test('après save + reviewCard, la map carte relue = 0 clé SRS', () async {
      final saved = await repo.save(ephemeralCard());
      final card = saved.getOrElse(() => throw StateError('save KO'));
      final id = card.id!;

      // Avance l'état SRS de CETTE carte.
      await repo.reviewCard(flashcardId: id, folderId: 'folder-1', quality: 5);

      final reloaded = await repo.getById(id);
      final map = reloaded
          .getOrElse(() => throw StateError('getById KO'))
          .toMap();

      for (final k in srsKeys) {
        expect(map.containsKey(k), isFalse,
            reason: 'la map carte ne doit contenir aucune clé SRS ($k)');
      }
      // L'état SRS n'est lisible QUE via le canal séparé.
      final srs = await reps.getByCard(id);
      expect(srs.getOrElse(() => null), isNotNull);
    });
  });

  group('AC3 — non-duplication au partage/duplication', () {
    test('carte dupliquée (nouvel id, même corps) sans état SRS hérité', () async {
      final savedA = await repo.save(ephemeralCard());
      final a = savedA.getOrElse(() => throw StateError('save A KO'));
      await repo.reviewCard(
          flashcardId: a.id!, folderId: 'folder-1', quality: 4);

      // Duplication : même corps, id remis à null → nouvel id à la (re)save.
      final duplicate = a.copyWith(id: null);
      final savedB = await repo.save(duplicate);
      final b = savedB.getOrElse(() => throw StateError('save B KO'));

      expect(b.id, isNot(a.id));

      final srsB = await reps.getByCard(b.id!);
      expect(srsB.getOrElse(() => null), isNull,
          reason: 'la carte dupliquée n\'hérite d\'aucun état SRS');

      final srsA = await reps.getByCard(a.id!);
      expect(srsA.getOrElse(() => null), isNotNull,
          reason: 'l\'état SRS de la source reste intact');
    });
  });

  group('AC4/AC9 — voie d\'écriture SRS UNIQUE (reviewCard → apply)', () {
    test('reviewCard == scheduler.apply(current, quality)', () async {
      const scheduler = ZSm2Scheduler();
      final now = DateTime(2026, 7, 10, 12);
      final expected = scheduler.apply(
        scheduler.initial(flashcardId: 'c1', folderId: 'folder-1'),
        5,
        now: now,
      );

      final res = await repo.reviewCard(
        flashcardId: 'c1',
        folderId: 'folder-1',
        quality: 5,
        now: now,
      );
      expect(res.getOrElse(() => throw StateError('reviewCard KO')), expected);
    });

    test('deux reviewCard successifs = courbe SM-2 cohérente', () async {
      final now1 = DateTime(2026, 7, 10);
      final r1 = await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 5, now: now1);
      final s1 = r1.getOrElse(() => throw StateError('r1 KO'));
      expect(s1.repetitions, 1);
      expect(s1.interval, 1);

      final now2 = DateTime(2026, 7, 11);
      final r2 = await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 5, now: now2);
      final s2 = r2.getOrElse(() => throw StateError('r2 KO'));
      expect(s2.repetitions, 2, reason: 'compteur avance');
      expect(s2.interval, 6, reason: 'seconde réussite → intervalle 6j (SM-2)');
    });

    test('reviewCard ne touche JAMAIS la carte (aucun save carte)', () async {
      cards.saveCount = 0;
      await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 3);
      expect(cards.saveCount, 0,
          reason: 'reviewCard n\'écrit que le canal SRS');
    });

    test('l\'état relu via le store == l\'état renvoyé (map telle quelle)',
        () async {
      final res = await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 4);
      final returned = res.getOrElse(() => throw StateError('reviewCard KO'));
      final reloaded = await reps.getByCard('c1');
      expect(reloaded.getOrElse(() => null), returned);
    });
  });

  group('AC5 — matérialisation de l\'éphémère (UUID + folderId + dates)', () {
    test('save(ephemeral, folderId) → id != null, folderId conservé, updatedAt',
        () async {
      final res = await repo.save(ephemeralCard(folderId: 'folder-42'));
      final card = res.getOrElse(() => throw StateError('save KO'));
      expect(card.id, isNotNull);
      expect(card.folderId, 'folder-42');
      expect(card.updatedAt, isNotNull);
    });
  });

  group('AC6 — carte éphémère sans dossier cible → Left(ZDomainFailure)', () {
    test('folderId == null → Left(ZDomainFailure), port carte jamais appelé',
        () async {
      final res = await repo.save(ephemeralCard(folderId: null));
      expect(res.isLeft(), isTrue);
      res.fold(
        (f) => expect(f, isA<ZDomainFailure>()),
        (_) => fail('attendu Left'),
      );
      expect(cards.saveCount, 0, reason: 'aucune écriture sur garde folderId');
    });

    test('folderId == "" → Left(ZDomainFailure), port carte jamais appelé',
        () async {
      final res = await repo.save(ephemeralCard(folderId: ''));
      expect(res.isLeft(), isTrue);
      res.fold(
        (f) => expect(f, isA<ZDomainFailure>()),
        (_) => fail('attendu Left'),
      );
      expect(cards.saveCount, 0);
    });

    test('carte déjà matérialisée sans folderId → garde NON appliquée',
        () async {
      final materialized = ZFlashcard(
        id: 'existing-1',
        folderId: null,
        question: 'Q ?',
      );
      final res = await repo.save(materialized);
      expect(res.isRight(), isTrue,
          reason: 'la garde ne vise que la matérialisation de l\'éphémère');
      expect(cards.saveCount, 1);
    });
  });

  group('AC8 — défensif (AD-10) + Either/flux nus', () {
    test('reviewCard sur carte jamais révisée = premier apply sur initial()',
        () async {
      const scheduler = ZSm2Scheduler();
      final now = DateTime(2026, 7, 10);
      final expected = scheduler.apply(
        scheduler.initial(flashcardId: 'new', folderId: 'folder-1'),
        5,
        now: now,
      );
      final res = await repo.reviewCard(
          flashcardId: 'new', folderId: 'folder-1', quality: 5, now: now);
      expect(res.getOrElse(() => throw StateError('KO')), expected);
    });

    test('état SRS corrompu reconstruit via fromMap sans throw', () async {
      // Injecte une map corrompue (compteurs négatifs, ease illisible).
      reps.injectRaw('corrupt', <String, dynamic>{
        'flashcard_id': 'corrupt',
        'folder_id': 'folder-1',
        'interval': -99,
        'repetitions': -5,
        'ease_factor': 'not-a-number',
        'next_review_date': 'pas-une-date',
      });
      final res = await repo.reviewCard(
          flashcardId: 'corrupt', folderId: 'folder-1', quality: 4);
      expect(res.isRight(), isTrue, reason: 'jamais de throw sur corruption');
    });

    test('getDue sur store vide → Right([])', () async {
      final res = await repo.getDue(now: DateTime(2026, 7, 10));
      expect(res.getOrElse(() => [ZRepetitionInfo(flashcardId: 'x', folderId: 'y')]),
          isEmpty);
    });
  });

  group('AC10 — sélection de session getDue (filtrage local)', () {
    test('seuls les états dus remontent ; filtre folderId respecté', () async {
      final now = DateTime(2026, 7, 10, 12);
      // Jamais révisé (dû), dans folder-1.
      await repo.initRepetition(flashcardId: 'never', folderId: 'folder-1');
      // Dû (échéance passée) — reviewCard avec now ancien.
      await repo.reviewCard(
          flashcardId: 'due',
          folderId: 'folder-1',
          quality: 5,
          now: DateTime(2026, 7, 1));
      // Non dû (échéance future).
      await repo.reviewCard(
          flashcardId: 'notdue',
          folderId: 'folder-1',
          quality: 5,
          now: now);
      // Dû mais autre dossier.
      await repo.initRepetition(flashcardId: 'other', folderId: 'folder-2');

      final all = await repo.getDue(now: now);
      final dueIds = all
          .getOrElse(() => [])
          .map((r) => r.flashcardId)
          .toSet();
      expect(dueIds, containsAll(<String>{'never', 'due', 'other'}));
      expect(dueIds, isNot(contains('notdue')));

      final filtered = await repo.getDue(now: now, folderId: 'folder-1');
      final ids = filtered.getOrElse(() => []).map((r) => r.flashcardId).toSet();
      expect(ids, containsAll(<String>{'never', 'due'}));
      expect(ids, isNot(contains('other')),
          reason: 'filtre folderId respecté');
    });
  });

  group('AC11 — offline-first + sync() best-effort', () {
    test('sync() hors-ligne → Right(unit), local intact', () async {
      cards.connected = false;
      reps.connected = false;
      await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 5);
      final before = (await reps.getByCard('c1')).getOrElse(() => null);

      final res = await repo.sync();
      expect(res.isRight(), isTrue);
      final after = (await reps.getByCard('c1')).getOrElse(() => null);
      expect(after, before, reason: 'local intact après sync offline');
    });

    test('échec partiel d\'un port toléré → Right(unit), les deux syncs appelés',
        () async {
      reps.failSync = true;
      final res = await repo.sync();
      expect(res.isRight(), isTrue,
          reason: 'échec partiel jamais d\'arrêt global');
      expect(cards.syncCount, 1);
      expect(reps.syncCount, 1);
    });

    test('sync() délègue aux deux ports', () async {
      await repo.sync();
      expect(cards.syncCount, 1);
      expect(reps.syncCount, 1);
    });
  });
}
