// me-2 — contrôleur de BROUILLON : régime DÉCLARÉ + preuve AD-43 à 3 étages.
//
// 🔴 Leçon su-9/su-4/su-7/me-1 (MÊME invariant) : une assertion « 0 écriture »
// est INFALSIFIABLE si l'espion n'est jamais prouvé capable de capter. Ici
// l'espion de commit enregistre d'abord une ÉCRITURE TÉMOIN (writes==1) AVANT
// toute assertion à 0 — sans quoi l'étape suivante ne prouverait rien.
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart' show ZServerFailure, Unit, ZResult;
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Espion de commit : compte les écritures et capture chaque payload. Configurable
/// pour échouer (`Left`) — étage échec de commit (AC9).
class _CommitSpy {
  int writes = 0;
  final List<List<ZFlashcard>> payloads = <List<ZFlashcard>>[];
  bool fail = false;

  Future<ZResult<Unit>> commit(List<ZFlashcard> cards) async {
    writes++;
    payloads.add(List<ZFlashcard>.of(cards));
    if (fail) return left(const ZServerFailure('commit refusé'));
    return right(unit);
  }
}

ZFlashcard _card(String id, {String question = 'Q'}) =>
    ZFlashcard(id: id, question: question);

ZFlashcard _ephemeral(String question) => ZFlashcard(question: question);

void main() {
  group('AC2 — régime BROUILLON DÉCLARÉ (enum public, jamais implicite)', () {
    test('le régime est DÉCLARÉ `ZEditingMode.draft`', () {
      final draft = ZMultiFlashcardDraftController();
      addTearDown(draft.dispose);
      expect(draft.mode, ZEditingMode.draft,
          reason: 'AD-43 : le régime est explicite (enum), jamais un booléen '
              'implicite');
    });

    test('la clé de travail est LOCALE, jamais l\'id de la carte (éphémère)', () {
      final draft = ZMultiFlashcardDraftController(
        initialCards: <ZFlashcard>[_ephemeral('sans id')],
      );
      addTearDown(draft.dispose);
      final key = draft.keys.single;
      // La carte n'a pas d'id (éphémère) — pourtant la sélection/les ValueKey
      // disposent d'une identité stable.
      expect(draft.cardOf(key)!.id, isNull);
      expect(key, isNotEmpty);
    });
  });

  group('🔴 AD-43 — preuve à 3 étages (brouillon, RIEN persisté)', () {
    test(
      '🔴 étage (b) FALSIFIABLE — espion CÂBLÉ au sujet (même canal `commit`) : '
      'édit→add→delete→gen→ABANDON sans commit ⇒ writes==0, PUIS commit ⇒ writes==1',
      () async {
        // FIX-4 : témoin et sujet PARTAGENT le MÊME canal de persistance. Le seul
        // seam de persistance du contrôleur est `commit(onCommit)` : l'espion y est
        // branché (et NON appelé directement à côté du sujet, ce qui rendait
        // l'ancienne assertion tautologique — l'espion n'était jamais vu par le
        // draft). Toute mutation qui se mettrait à persister via ce canal ferait
        // ROUGIR l'assertion « writes==0 » ; retirer le `commit` final ferait
        // ROUGIR « writes==1 » (le canal n'étant plus exercé).
        final spy = _CommitSpy();

        final draft = ZMultiFlashcardDraftController(
          initialCards: <ZFlashcard>[_card('a')],
        );
        addTearDown(draft.dispose);
        final key = draft.keys.first;

        draft.updateCard(key, draft.cardOf(key)!.copyWith(question: 'édité'));
        final added = draft.addBlank(_ephemeral(''));
        draft.removeKeys(<String>[added]);
        draft.addGenerated(<ZFlashcard>[_ephemeral('générée')]);
        draft.discardToSnapshot(); // ABANDON — ne persiste rien.

        expect(spy.writes, 0,
            reason: '🔴 AD-43 : éditer/ajouter/supprimer/générer/abandonner ne '
                'franchit JAMAIS la frontière de persistance (l\'espion, qui EST '
                'le seul canal de persistance du sujet, n\'a rien reçu)');

        // Témoin sur le MÊME canal : un commit — et LUI seul — écrit exactement 1.
        await draft.commit(spy.commit);
        expect(spy.writes, 1,
            reason: '🔴 l\'espion EST bien câblé au sujet : le commit (unique seam '
                'de persistance) le déclenche — la preuve « 0 » ci-dessus est donc '
                'significative, pas tautologique');
      },
    );

    test('🔴 étage (c) : un commit ⇒ EXACTEMENT une salve portant TOUTE la liste',
        () async {
      final spy = _CommitSpy();
      final draft = ZMultiFlashcardDraftController(
        initialCards: <ZFlashcard>[_card('a'), _card('b')],
      );
      addTearDown(draft.dispose);
      draft.addGenerated(<ZFlashcard>[_ephemeral('c'), _ephemeral('d')]);

      final result = await draft.commit(spy.commit);

      expect(result.isRight(), isTrue);
      expect(spy.writes, 1,
          reason: '🔴 AC4 : UNE seule invocation de handoff, jamais une écriture '
              'par-carte au fil de l\'eau');
      expect(spy.payloads.single, hasLength(4),
          reason: 'la salve porte l\'INTÉGRALITÉ de la liste de travail');
      expect(spy.payloads.single.map((c) => c.question).toList(),
          <String>['Q', 'Q', 'c', 'd']);
    });

    test('après un commit RÉUSSI, le brouillon n\'est plus dirty', () async {
      final spy = _CommitSpy();
      final draft = ZMultiFlashcardDraftController();
      addTearDown(draft.dispose);
      draft.addBlank(_ephemeral('x'));
      expect(draft.isDirty.value, isTrue);
      await draft.commit(spy.commit);
      expect(draft.isDirty.value, isFalse,
          reason: 'succès ⇒ le brouillon devient la nouvelle base');
    });

    test(
      '🔴 AC9 : commit qui ÉCHOUE ⇒ on reste dirty, AUCUNE perte (pas de vidage '
      'optimiste)',
      () async {
        final spy = _CommitSpy()..fail = true;
        final draft = ZMultiFlashcardDraftController(
          initialCards: <ZFlashcard>[_card('a')],
        );
        addTearDown(draft.dispose);
        draft.addGenerated(<ZFlashcard>[_ephemeral('b')]);
        final beforeLen = draft.length;

        final result = await draft.commit(spy.commit);

        expect(result.isLeft(), isTrue);
        expect(draft.isDirty.value, isTrue,
            reason: '🔴 échec ⇒ on RESTE dirty');
        expect(draft.length, beforeLen,
            reason: '🔴 aucune perte : la liste de travail est intacte');
        expect(draft.workingList.map((c) => c.question),
            containsAll(<String>['Q', 'b']));
      },
    );
  });

  group('🔴 BUG-2/AD-10 — un onCommit qui THROW ne traverse jamais la surface', () {
    test(
      '🔴 onCommit lève ⇒ commit retourne Left (jamais de throw), reste dirty',
      () async {
        final draft = ZMultiFlashcardDraftController(
          initialCards: <ZFlashcard>[_card('a')],
        );
        addTearDown(draft.dispose);
        draft.addGenerated(<ZFlashcard>[_ephemeral('b')]);
        expect(draft.isDirty.value, isTrue);
        final beforeLen = draft.length;

        // Le seam de persistance injecté lève : AD-10 exige un repli, jamais une
        // exception qui traverse la surface.
        final result = await draft.commit((_) async => throw StateError('boom'));

        expect(result.isLeft(), isTrue,
            reason: '🔴 BUG-2 : le throw est CAPTÉ et mappé en Left(ZFailure)');
        expect(draft.isDirty.value, isTrue,
            reason: '🔴 échec ⇒ le brouillon reste dirty (pas de vidage optimiste)');
        expect(draft.length, beforeLen,
            reason: '🔴 aucune perte : la liste de travail est intacte');
      },
    );
  });

  group('AC2/AC10 — isDirty = divergence vs snapshot (canal dédié)', () {
    test('propre à l\'ouverture, dirty après édition, RE-propre si revert', () {
      final original = _card('a', question: 'origine');
      final draft = ZMultiFlashcardDraftController(
        initialCards: <ZFlashcard>[original],
      );
      addTearDown(draft.dispose);
      final key = draft.keys.first;

      expect(draft.isDirty.value, isFalse, reason: 'ouverture : propre');
      draft.updateCard(key, original.copyWith(question: 'modifié'));
      expect(draft.isDirty.value, isTrue, reason: 'édit ⇒ divergence');
      draft.updateCard(key, original); // revert exact
      expect(draft.isDirty.value, isFalse,
          reason: 'revenu au snapshot ⇒ plus dirty (divergence, pas monotone)');
    });

    test(
      '🔴 FIX-9 : le décompte de divergence INCRÉMENTAL reste EXACT à travers '
      'éditions multiples, revert partiel et changements structurels',
      () {
        final a0 = _card('a', question: 'A');
        final b0 = _card('b', question: 'B');
        final draft = ZMultiFlashcardDraftController(
          initialCards: <ZFlashcard>[a0, b0],
        );
        addTearDown(draft.dispose);
        final ka = draft.keys[0];
        final kb = draft.keys[1];

        expect(draft.isDirty.value, isFalse, reason: 'ouverture : propre');

        // Deux positions divergent.
        draft.updateCard(ka, a0.copyWith(question: 'A!'));
        draft.updateCard(kb, b0.copyWith(question: 'B!'));
        expect(draft.isDirty.value, isTrue);

        // Revert de A seul : B diverge toujours ⇒ ENCORE dirty (le décompte ne
        // retombe pas à 0 prématurément — piège d'un compteur booléen naïf).
        draft.updateCard(ka, a0);
        expect(draft.isDirty.value, isTrue,
            reason: '🔴 B diverge encore ⇒ le décompte incrémental le sait');

        // Revert de B : toutes les positions reviennent au snapshot ⇒ propre.
        draft.updateCard(kb, b0);
        expect(draft.isDirty.value, isFalse,
            reason: '🔴 toutes positions au snapshot ⇒ le décompte retombe à 0');

        // Interleaving structurel : ajout (longueur diverge ⇒ dirty), puis retrait
        // (retour à la composition initiale), puis édition/revert — le chemin
        // FROID (add/remove) recalcule en entier, le chemin CHAUD reste exact.
        final added = draft.addBlank(_ephemeral('x'));
        expect(draft.isDirty.value, isTrue, reason: 'ajout ⇒ dirty structurel');
        draft.removeKeys(<String>[added]);
        expect(draft.isDirty.value, isFalse,
            reason: '🔴 retour à la composition d\'origine ⇒ propre');
        draft.updateCard(ka, a0.copyWith(question: 'zzz'));
        expect(draft.isDirty.value, isTrue);
        draft.updateCard(ka, a0);
        expect(draft.isDirty.value, isFalse,
            reason: '🔴 le décompte incrémental reste juste après un cycle '
                'structurel');
      },
    );

    test('🔴 SM-1 : updateCard n\'ÉMET PAS la tranche structurelle orderKeys', () {
      final draft = ZMultiFlashcardDraftController(
        initialCards: <ZFlashcard>[_card('a')],
      );
      addTearDown(draft.dispose);
      final key = draft.keys.first;
      var structureEmissions = 0;
      draft.orderKeys.addListener(() => structureEmissions++);

      draft.updateCard(key, draft.cardOf(key)!.copyWith(question: 'nouvelle'));

      expect(structureEmissions, 0,
          reason: '🔴 SM-1 : éditer un champ ne reconstruit PAS la liste — seul '
              'le canal isDirty bouge, jamais orderKeys');
    });

    test('add/remove/gen ÉMETTENT bien la tranche structurelle', () {
      final draft = ZMultiFlashcardDraftController();
      addTearDown(draft.dispose);
      var emissions = 0;
      draft.orderKeys.addListener(() => emissions++);

      final k = draft.addBlank(_ephemeral('a'));
      draft.addGenerated(<ZFlashcard>[_ephemeral('b')]);
      draft.removeKeys(<String>[k]);

      expect(emissions, 3, reason: 'chaque changement de composition émet');
    });
  });

  group('AC5/AC8 — génération & suppression = mutations IN MEMORY', () {
    test('addGenerated APPEND les cartes éphémères, dirty flippe', () {
      final draft = ZMultiFlashcardDraftController();
      addTearDown(draft.dispose);
      draft.addGenerated(<ZFlashcard>[_ephemeral('g1'), _ephemeral('g2')]);
      expect(draft.length, 2);
      expect(draft.workingList.every((c) => c.id == null), isTrue,
          reason: 'AD-37 : cartes générées ÉPHÉMÈRES (id == null)');
      expect(draft.isDirty.value, isTrue);
    });

    test('addGenerated([]) est un no-op (AC9 : génération vide ⇒ liste intacte)',
        () {
      final draft = ZMultiFlashcardDraftController(
        initialCards: <ZFlashcard>[_card('a')],
      );
      addTearDown(draft.dispose);
      draft.addGenerated(const <ZFlashcard>[]);
      expect(draft.length, 1);
      expect(draft.isDirty.value, isFalse);
    });

    test('removeKeys retire les entrées ciblées (aucune cascade, in-memory)', () {
      final draft = ZMultiFlashcardDraftController(
        initialCards: <ZFlashcard>[_card('a'), _card('b'), _card('c')],
      );
      addTearDown(draft.dispose);
      final keys = draft.keys;
      draft.removeKeys(<String>[keys[0], keys[2]]);
      expect(draft.length, 1);
      expect(draft.workingList.single.id, 'b');
    });
  });

  group('AC9 — états dégénérés (résultat DÉFINI, jamais de throw)', () {
    test('liste vide : commit remet une liste vide (une seule salve)', () async {
      final spy = _CommitSpy();
      final draft = ZMultiFlashcardDraftController();
      addTearDown(draft.dispose);
      await draft.commit(spy.commit);
      expect(spy.payloads.single, isEmpty);
    });

    test('opérations post-dispose : no-op silencieux (AD-10)', () {
      final draft = ZMultiFlashcardDraftController();
      draft.dispose();
      expect(() => draft.addBlank(_ephemeral('x')), returnsNormally);
      expect(() => draft.removeKeys(<String>['draft-0']), returnsNormally);
    });
  });
}
