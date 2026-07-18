// Primitive de **purge SRS** `ZRepetitionStore.deleteByCard` (me-3, AC5/AC6 —
// AD-10/AD-39).
//
// 🔴 Racine de la dette d'orphelins lex : sans primitive de purge, supprimer une
// carte laissait son `ZRepetitionInfo` SURVIVRE top-level. Ce fichier prouve, au
// niveau du port (via le fake in-memory), que :
//   (a) l'espion capte RÉELLEMENT le canal (témoin : `deleteByCard` retire l'état
//       ET consigne l'`id`) — sinon les assertions « purgé » des tests study-side
//       seraient infalsifiables (leçon su-10) ;
//   (b) la purge est IDEMPOTENTE (absence ⇒ `Right(unit)`, jamais un `Left`) ;
//   (c) une panne réelle du store est un `Left` (rapportée, jamais avalée).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

import 'support/fakes.dart';

ZRepetitionInfo _seed(String id) =>
    const ZSm2Scheduler().initial(flashcardId: id, folderId: 'f');

void main() {
  group('🔴 AC5 — deleteByCard : espion PROUVÉ captant AVANT (témoin)', () {
    test('purge un état PRÉSENT : store vide pour cet id + id consigné', () async {
      final store = FakeRepetitionStore();
      await store.put(_seed('A'));
      // Sonde : l'état est bien présent AVANT (sinon la purge ne prouverait rien).
      expect((await store.getByCard('A')).getOrElse(() => null), isNotNull,
          reason: 'sonde : l\'état SRS de A doit exister AVANT la purge');

      final res = await store.deleteByCard('A');

      expect(res.isRight(), isTrue, reason: 'purge d\'un état présent = succès');
      expect((await store.getByCard('A')).getOrElse(() => null), isNull,
          reason: '🔴 l\'espion capte le BON canal : A est réellement retiré');
      expect(store.deletedIds, <String>['A'],
          reason: '🔴 l\'espion consigne exactement l\'id purgé (canal prouvé)');
    });
  });

  group('🔴 AC5/AD-10 — idempotence : purger un id absent est un SUCCÈS', () {
    test('id jamais inscrit ⇒ Right(unit), aucun throw', () async {
      final store = FakeRepetitionStore();
      final res = await store.deleteByCard('inconnu');
      expect(res.isRight(), isTrue,
          reason: '🔴 AD-10 : absence ≠ erreur — la cascade ne doit JAMAIS '
              'échouer sur une carte jamais inscrite');
      expect(store.deletedIds, <String>['inconnu']);
    });

    test('double purge du même id ⇒ succès les DEUX fois', () async {
      final store = FakeRepetitionStore();
      await store.put(_seed('B'));
      expect((await store.deleteByCard('B')).isRight(), isTrue);
      expect((await store.deleteByCard('B')).isRight(), isTrue,
          reason: '🔴 un double-appel accidentel ne fait jamais échouer');
    });
  });

  group('🔴 AC6/AD-39 — panne réelle du store : Left RAPPORTÉ (jamais avalé)', () {
    test('failDeleteFor ⇒ Left(CacheFailure), l\'état N\'est PAS retiré', () async {
      final store = FakeRepetitionStore(failDeleteFor: <String>{'K'});
      await store.put(_seed('K'));
      final res = await store.deleteByCard('K');
      expect(res.isLeft(), isTrue,
          reason: '🔴 une panne réelle est un Left (rapporté au grain de la '
              'racine par batchDelete) — jamais un succès masquant un orphelin');
      expect((await store.getByCard('K')).getOrElse(() => null), isNotNull,
          reason: 'l\'échec ne prétend pas un succès : l\'état K subsiste');
      expect(store.deletedIds, <String>['K'],
          reason: 'l\'espion consigne la tentative (canal prouvé, même en échec)');
    });
  });
}
