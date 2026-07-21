/// Tests E9-5 — dettes E9-4 intégrées : [M1] `moveCard` + re-sync folder-only du
/// `folderId` SRS dénormalisé (AC7) ; [L2] idempotence de `initRepetition` +
/// `resetRepetition` explicite (AC8). Fakes en mémoire (aucun Firebase).
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

  Future<ZFlashcard> saveCard({String? folderId = 'folder-1'}) async {
    final res = await repo.save(ZFlashcard(folderId: folderId, question: 'Q ?'));
    return res.getOrElse(() => throw StateError('save KO'));
  }

  group('AC7 [M1] — moveCard + re-sync folder-only du folderId SRS', () {
    test('moveCard(old→new) : getDue(new) inclut / getDue(old) exclut', () async {
      final card = await saveCard(folderId: 'old');
      final id = card.id!;
      // Inscrit la carte à l'étude dans le dossier d'origine.
      await repo.initRepetition(flashcardId: id, folderId: 'old');

      final now = DateTime(2026, 7, 10);
      // Avant le déplacement : due dans `old`, absente de `new`.
      final beforeOld = await repo.getDue(now: now, folderId: 'old');
      final beforeNew = await repo.getDue(now: now, folderId: 'new');
      expect(beforeOld.getOrElse(() => []).map((r) => r.flashcardId), contains(id));
      expect(beforeNew.getOrElse(() => []).map((r) => r.flashcardId),
          isNot(contains(id)));

      final moved = await repo.moveCard(flashcardId: id, folderId: 'new');
      expect(moved.isRight(), isTrue);
      final movedCard = moved.getOrElse(() => throw StateError('move KO'));
      expect(movedCard.folderId, 'new', reason: 'carte relocalisée');

      final afterOld = await repo.getDue(now: now, folderId: 'old');
      final afterNew = await repo.getDue(now: now, folderId: 'new');
      expect(afterNew.getOrElse(() => []).map((r) => r.flashcardId), contains(id),
          reason: 'la ligne SRS suit le nouveau dossier (re-sync)');
      expect(afterOld.getOrElse(() => []).map((r) => r.flashcardId),
          isNot(contains(id)),
          reason: 'la ligne SRS ne remonte plus dans l\'ancien dossier');
    });

    test('moveCard préserve TOUS les champs d\'ordonnancement SRS (AD-9)', () async {
      final card = await saveCard(folderId: 'old');
      final id = card.id!;
      // Avance l'état SRS (repetitions/interval/ease/dates non triviaux).
      await repo.reviewCard(
          flashcardId: id, folderId: 'old', quality: 5, now: DateTime(2026, 7, 1));
      final before =
          (await reps.getByCard(id)).getOrElse(() => null)!;

      await repo.moveCard(flashcardId: id, folderId: 'new', subFolderId: 'sub');

      final after = (await reps.getByCard(id)).getOrElse(() => null)!;
      // SEUL le folderId change (routage) ; l'ordonnancement est IDENTIQUE.
      expect(after.folderId, 'new');
      expect(after.interval, before.interval);
      expect(after.repetitions, before.repetitions);
      expect(after.easeFactor, before.easeFactor);
      expect(after.nextReviewDate, before.nextReviewDate);
      expect(after.learnedAt, before.learnedAt);
      expect(after.lastQuality, before.lastQuality);
      // La carte porte aussi le sous-dossier demandé.
      final movedCard = (await repo.getById(id)).getOrElse(() => throw StateError('KO'));
      expect(movedCard.subFolderId, 'sub');
    });

    test('carte sans ligne SRS → carte déplacée, AUCUN put SRS', () async {
      final card = await saveCard(folderId: 'old');
      final id = card.id!;
      reps.putCount = 0; // remet l'espion à zéro (aucune inscription faite).

      final moved = await repo.moveCard(flashcardId: id, folderId: 'new');
      expect(moved.isRight(), isTrue);
      expect((moved.getOrElse(() => throw StateError('KO'))).folderId, 'new');
      expect(reps.putCount, 0, reason: 'vide ≠ erreur : aucun put SRS');
    });

    test('carte introuvable → Left(ZNotFoundFailure), aucune écriture', () async {
      cards.saveCount = 0;
      final moved = await repo.moveCard(flashcardId: 'ghost', folderId: 'new');
      expect(moved.isLeft(), isTrue);
      moved.fold((f) => expect(f, isA<ZNotFoundFailure>()), (_) => fail('Left attendu'));
      expect(cards.saveCount, 0, reason: 'aucune sauvegarde si carte absente');
    });

    test('MEDIUM-2 : échec du put de re-sync SRS est LOGGÉ (jamais avalé, AD-11)',
        () async {
      final logs = <String>[];
      final localReps = FakeRepetitionStore();
      final localRepo = ZFlashcardRepository(
        cards: cards,
        repetitions: localReps,
        logger: (message, {error, stackTrace}) => logs.add(message),
      );
      final saved = await localRepo.save(
        ZFlashcard(folderId: 'old', question: 'Q ?'),
      );
      final id = saved.getOrElse(() => throw StateError('save KO')).id!;
      await localRepo.initRepetition(flashcardId: id, folderId: 'old');
      localReps.failPut = true; // le put de re-sync échouera

      final moved = await localRepo.moveCard(flashcardId: id, folderId: 'new');
      expect(moved.isRight(), isTrue,
          reason: 'la carte est déplacée malgré l\'échec du put SRS');
      expect(logs.any((m) => m.contains('re-sync du folderId SRS échouée')),
          isTrue,
          reason: 'l\'échec du put de re-sync doit être loggé (jamais silencieux)');
    });
  });

  group('AC8 [L2] — idempotence initRepetition + resetRepetition explicite', () {
    test('double initRepetition PRÉSERVE l\'historique (no-op)', () async {
      // Historique établi via la voie unique reviewCard → apply.
      await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 5, now: DateTime(2026, 7, 1));
      final historical = (await reps.getByCard('c1')).getOrElse(() => null)!;
      expect(historical.repetitions, 1);

      reps.putCount = 0;
      final first = await repo.initRepetition(flashcardId: 'c1', folderId: 'folder-1');
      expect(first.getOrElse(() => throw StateError('KO')), historical,
          reason: 'init sur état existant = no-op (renvoie l\'existant)');
      final second = await repo.initRepetition(flashcardId: 'c1', folderId: 'folder-1');
      expect(second.getOrElse(() => throw StateError('KO')), historical);

      expect(reps.putCount, 0,
          reason: 'aucun écrasement : init idempotent n\'écrit rien si présent');
      // L'historique est intact (pas remis à zéro).
      final after = (await reps.getByCard('c1')).getOrElse(() => null)!;
      expect(after.repetitions, 1);
      expect(after, historical);
    });

    test('initRepetition ABSENT → écrit un état neuf (initial)', () async {
      const scheduler = ZSm2Scheduler();
      final expected = scheduler.initial(flashcardId: 'new', folderId: 'folder-1');
      final res = await repo.initRepetition(flashcardId: 'new', folderId: 'folder-1');
      expect(res.getOrElse(() => throw StateError('KO')), expected);
      expect(reps.putCount, 1);
    });

    test('resetRepetition → remet à neuf (initial), inconditionnel', () async {
      await repo.reviewCard(
          flashcardId: 'c1', folderId: 'folder-1', quality: 5, now: DateTime(2026, 7, 1));
      final before = (await reps.getByCard('c1')).getOrElse(() => null)!;
      expect(before.repetitions, 1);

      const scheduler = ZSm2Scheduler();
      final expected = scheduler.initial(flashcardId: 'c1', folderId: 'folder-1');
      final res = await repo.resetRepetition(flashcardId: 'c1', folderId: 'folder-1');
      expect(res.getOrElse(() => throw StateError('KO')), expected,
          reason: 'reset explicite = scheduler.initial');
      final after = (await reps.getByCard('c1')).getOrElse(() => null)!;
      expect(after.repetitions, 0, reason: 'historique effacé par le reset explicite');
      expect(after.interval, 0);
      expect(after.learnedAt, isNull);
    });
  });
}
