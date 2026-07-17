// SU-9/AC5..AC8 — contrôleur de génération : port FAILLIBLE, jeton de fraîcheur,
// anti-double-tap, cartes ÉPHÉMÈRES. « Rien persisté » (AD-43) est tenu
// STRUCTURELLEMENT (aucun seam de store dans le contrôleur — garde purity
// mutation-vérifiée) ; l'étage COMPORTEMENTAL témoigne, en actionnant le flux,
// que le handoff ne remet que des cartes id==null (non persistables telles quelles).
import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

const _messages = ZFlashcardGenerationMessages(
  unexpectedError: 'ERREUR-INATTENDUE',
  emptyResult: 'AUCUNE-CARTE',
);

/// Port pilotable : chaque appel renvoie le Future du responder fourni.
class _FakePort implements ZFlashcardGenerationPort {
  _FakePort(this.responder);
  final Future<ZResult<List<ZFlashcard>>> Function(
      ZFlashcardGenerationRequest request) responder;
  int calls = 0;
  ZFlashcardGenerationRequest? lastRequest;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
      ZFlashcardGenerationRequest request) {
    calls++;
    lastRequest = request;
    return responder(request);
  }
}

ZFlashcard _card({String? id, ZFlashcardSource? source}) => ZFlashcard(
      id: id,
      question: 'Q',
      answer: 'A',
      source: source,
    );

ZFlashcardGenerationRequest _req({ZFlashcardSource? provenance}) =>
    ZFlashcardGenerationRequest(content: 'c', count: 3, provenance: provenance);

ZFlashcardGenerationController _controller(
  _FakePort port, {
  ZFlashcardGeneratedCallback? onGenerated,
}) =>
    ZFlashcardGenerationController(
      port: port,
      messages: _messages,
      onGenerated: onGenerated,
    );

void main() {
  group('AC7 — port FAILLIBLE : échec typé, sans throw, saisie préservée', () {
    test('(a) Left(ZFailure) → failed + message du failure + saisie intacte',
        () async {
      final port = _FakePort(
          (_) async => left(const DomainFailure('quota dépassé')));
      final c = _controller(port);
      final req = _req();
      await c.generate(req);
      expect(c.status, ZFlashcardGenerationStatus.failed);
      expect(c.errorMessage, 'quota dépassé');
      expect(c.lastRequest, req, reason: 'saisie préservée pour relance (AC7)');
    });

    test('(b) le port qui LÈVE est capté → failed, aucune exception ne remonte',
        () async {
      final port = _FakePort((_) async => throw StateError('boom'));
      final c = _controller(port);
      await expectLater(c.generate(_req()), completes);
      expect(c.status, ZFlashcardGenerationStatus.failed);
      expect(c.errorMessage, _messages.unexpectedError);
    });

    test('(c) Right([]) 0 carte → failed + message dédié, pas de crash', () async {
      final port = _FakePort((_) async => right(const <ZFlashcard>[]));
      final c = _controller(port);
      await c.generate(_req());
      expect(c.status, ZFlashcardGenerationStatus.failed);
      expect(c.errorMessage, _messages.emptyResult);
    });

    test('(d) cartes malformées (question vide) → preview, jamais un throw',
        () async {
      final port = _FakePort(
          (_) async => right(<ZFlashcard>[const ZFlashcard(question: '')]));
      final c = _controller(port);
      await c.generate(_req());
      expect(c.status, ZFlashcardGenerationStatus.preview);
      expect(c.cards, hasLength(1));
    });
  });

  group('AC5/AC6 — cartes ÉPHÉMÈRES ; RIEN persisté', () {
    test('id FORCÉ à null + source estampillée depuis request.provenance SEULE',
        () async {
      final backend = ZCustomSource('backend', const <String, dynamic>{'x': 1});
      final provenance =
          ZCustomSource('article', const <String, dynamic>{'id': '7'});
      final port = _FakePort((_) async =>
          right(<ZFlashcard>[_card(id: 'backend-id', source: backend)]));
      final c = _controller(port);
      await c.generate(_req(provenance: provenance));
      expect(c.cards.single.id, isNull, reason: 'jamais un id backend (AC5)');
      expect(c.cards.single.source, provenance,
          reason: 'source estampillée QUE depuis request.provenance');
      expect(c.cards.single.source, isNot(backend));
    });

    test('every card.id == null sur le lot d\'aperçu', () async {
      final port = _FakePort((_) async => right(<ZFlashcard>[
            _card(id: 'a'),
            _card(id: 'b'),
            _card(id: 'c'),
          ]));
      final c = _controller(port);
      await c.generate(_req());
      expect(c.cards.every((card) => card.id == null), isTrue);
    });

    test('confirmTags : id reste null + handoff, aucune persistance', () async {
      List<ZFlashcard>? handed;
      List<ZFlashcardTag>? handedTags;
      final port = _FakePort((_) async => right(<ZFlashcard>[_card(id: 'x')]));
      final c = _controller(port, onGenerated: (cards, tags) {
        handed = cards;
        handedTags = tags;
      });
      await c.generate(_req());
      c.proceedToTagConfirmation();
      const tag = ZFlashcardTag(id: 't1', title: 'algèbre');
      c.confirmTags(const <ZFlashcardTag>[tag]);
      expect(handed, isNotNull);
      expect(handed!.single.id, isNull, reason: 'copyWith ne matérialise pas d\'id');
      expect(handed!.single.tagIds, <String>['t1']);
      expect(handedTags, <ZFlashcardTag>[tag]);
      expect(c.status, ZFlashcardGenerationStatus.idle,
          reason: 'retour idle après handoff, rien persisté');
    });

    test(
        'handoff : chaque carte remise a id==null (non persistable telle quelle) '
        '— « zéro persistance » est STRUCTUREL (garde purity), pas un espion',
        () async {
      // su-9 D1 — le contrôleur n'a AUCUN seam de store (ni ctor, ni ZcrudScope) :
      // la garantie AD-43 « rien persisté » est tenue STRUCTURELLEMENT par la
      // garde z_widgets_purity_test (store/save/persist bannis, mutation-vérifiée),
      // PAS par un espion comportemental — un espion jamais joignable par le SUT
      // serait INFALSIFIABLE (leçon su-4/su-7 : « corpus rendant l'assertion vraie
      // quel que soit le code »). Ce qui EST falsifiable ici, en ACTIONNANT le
      // flux : le handoff ne transporte QUE des cartes id==null, donc non
      // persistables telles quelles par l'hôte. Mutation `_ephemeral → return card`
      // (id backend qui fuit) ⇒ ce test ROUGIT PAR LE COMPORTEMENT.
      List<ZFlashcard>? handed;
      final port = _FakePort(
          (_) async => right(<ZFlashcard>[_card(id: 'z1'), _card(id: 'z2')]));
      final c = _controller(port, onGenerated: (cards, _) => handed = cards);
      await c.generate(_req());
      c.proceedToTagConfirmation();
      c.confirmTags(const <ZFlashcardTag>[]);
      expect(handed, isNotNull);
      expect(handed, hasLength(2));
      expect(handed!.every((card) => card.id == null), isTrue,
          reason: 'le handoff ne remet que des cartes éphémères (id==null)');

      // Régénère puis abandonne (fermeture de feuille) : aucun résidu retenu,
      // retour à idle — falsifiable (un abandon qui ne reset pas laisse des cartes).
      await c.generate(_req());
      c.abandon();
      expect(c.status, ZFlashcardGenerationStatus.idle);
      expect(c.cards, isEmpty, reason: 'abandon ne persiste ni ne retient rien');
    });
  });

  group('AC8 — concurrence : anti-double-tap, jeton de fraîcheur, annulation', () {
    test('anti-double-tap : re-soumission pendant generating IGNORÉE', () async {
      final completer = Completer<ZResult<List<ZFlashcard>>>();
      final port = _FakePort((_) => completer.future);
      final c = _controller(port);

      final f1 = c.generate(_req()); // en vol
      expect(c.status, ZFlashcardGenerationStatus.generating);
      await c.generate(_req()); // ignorée (anti-double-tap)
      expect(port.calls, 1, reason: 'une seule requête en vol à la fois');

      completer.complete(right(<ZFlashcard>[_card()]));
      await f1;
      expect(c.status, ZFlashcardGenerationStatus.preview);
    });

    test('🔴 réponse N-1 arrivant APRÈS N : seule N est appliquée (jeton)',
        () async {
      final a = Completer<ZResult<List<ZFlashcard>>>();
      final b = Completer<ZResult<List<ZFlashcard>>>();
      var call = 0;
      final port = _FakePort((_) => (call++ == 0) ? a.future : b.future);
      final c = _controller(port);

      final fA = c.generate(_req()); // N-1, token capturé
      c.abandon(); // l'utilisateur annule → idle, jeton bumpé
      final fB = c.generate(_req()); // N, nouveau token

      // La réponse de N-1 arrive TARD : elle doit être écartée.
      a.complete(right(<ZFlashcard>[_card(id: 'A')]));
      await fA;
      expect(c.status, ZFlashcardGenerationStatus.generating,
          reason: 'N-1 périmée ⇒ ignorée, N toujours en vol');
      expect(c.cards, isEmpty);

      // La réponse de N arrive : elle est appliquée.
      b.complete(right(<ZFlashcard>[_card(id: 'B')]));
      await fB;
      expect(c.status, ZFlashcardGenerationStatus.preview);
      expect(c.cards, hasLength(1));
    });

    test('annulation en vol : abandon → idle, sans throw, réponse tardive droppée',
        () async {
      final completer = Completer<ZResult<List<ZFlashcard>>>();
      final port = _FakePort((_) => completer.future);
      final c = _controller(port);
      final f = c.generate(_req());
      c.abandon();
      expect(c.status, ZFlashcardGenerationStatus.idle);
      completer.complete(right(<ZFlashcard>[_card()]));
      await f;
      expect(c.status, ZFlashcardGenerationStatus.idle,
          reason: 'réponse tardive après abandon ⇒ aucun lot appliqué');
    });

    test('réponse APRÈS dispose : aucun notify/throw, rien appliqué', () async {
      final completer = Completer<ZResult<List<ZFlashcard>>>();
      final port = _FakePort((_) => completer.future);
      final c = _controller(port);
      var notifiedAfterDispose = false;
      final f = c.generate(_req());
      c.addListener(() => notifiedAfterDispose = true);
      c.dispose();
      completer.complete(right(<ZFlashcard>[_card()]));
      await f; // ne doit pas lever
      expect(notifiedAfterDispose, isFalse,
          reason: 'aucun notifyListeners après dispose (AC6/AC8)');
    });
  });
}
