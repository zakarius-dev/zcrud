/// Gardes du câblage du `ZFlashcardGenerationPort` EXISTANT (CHAT-8).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_study/zcrud_chat_study.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_study/zcrud_study.dart';

/// Impl d'hôte factice — **implements** le port réel (aucun port maison).
class _FakePort implements ZFlashcardGenerationPort {
  _FakePort(this._answer);

  final ZResult<List<ZFlashcard>> Function(ZFlashcardGenerationRequest) _answer;
  ZFlashcardGenerationRequest? seen;

  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  ) async {
    seen = request;
    return _answer(request);
  }
}

/// Impl d'hôte qui **lève** — le cas hors de notre contrôle (AD-10).
class _ThrowingPort implements ZFlashcardGenerationPort {
  @override
  Future<ZResult<List<ZFlashcard>>> generateFlashcards(
    ZFlashcardGenerationRequest request,
  ) async =>
      throw StateError('quota');
}

const ZChatMessage _message = ZChatMessage(
  id: 'm1',
  conversationId: 'c1',
  role: ZChatRole.assistant,
  contentBlocks: <ZContentBlock>[ZTextBlock(text: 'La valeur en douane…')],
);

void main() {
  test('le contenu NEUTRE du message traverse jusqu\'au port', () async {
    final _FakePort port =
        _FakePort((_) => const Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[]));

    await ZChatFlashcardGenerator(port).generateFromMessage(_message);

    expect(port.seen?.content, contains('La valeur en douane'));
    expect(
      port.seen?.provenance,
      const ZConversationSource(conversationId: 'c1', messageId: 'm1'),
    );
  });

  test(
      'AD-10 — une impl qui OUBLIE la provenance ne produit pas de carte muette',
      () async {
    final _FakePort port = _FakePort(
      (_) => const Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[
        ZFlashcard(question: 'q'), // source == null : l'oubli.
      ]),
    );

    final ZResult<List<ZFlashcard>> result =
        await ZChatFlashcardGenerator(port).generateFromMessage(_message);

    final ZFlashcard card = result.getOrElse(() => <ZFlashcard>[]).single;
    expect(
      card.source,
      const ZConversationSource(conversationId: 'c1', messageId: 'm1'),
    );
  });

  test('une provenance DÉJÀ posée par l\'impl n\'est JAMAIS écrasée', () async {
    const ZNoteSource explicit = ZNoteSource(noteId: 'n42');
    final _FakePort port = _FakePort(
      (_) => const Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[
        ZFlashcard(question: 'q', source: explicit),
      ]),
    );

    final ZResult<List<ZFlashcard>> result =
        await ZChatFlashcardGenerator(port).generateFromMessage(_message);

    expect(result.getOrElse(() => <ZFlashcard>[]).single.source, explicit);
  });

  test('le dossier d\'accueil est posé — sans déplacer une carte déjà rangée',
      () async {
    final _FakePort port = _FakePort(
      (_) => const Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[
        ZFlashcard(question: 'sans dossier'),
        ZFlashcard(question: 'déjà rangée', folderId: 'autre'),
      ]),
    );

    final ZResult<List<ZFlashcard>> result = await ZChatFlashcardGenerator(port)
        .generateFromMessage(_message, folderId: 'f1');

    final List<ZFlashcard> cards = result.getOrElse(() => <ZFlashcard>[]);
    expect(cards[0].folderId, 'f1');
    expect(cards[1].folderId, 'autre');
  });

  test('AD-5 — un Left du port est propagé tel quel', () async {
    final _FakePort port = _FakePort(
      (_) => const Left<ZFailure, List<ZFlashcard>>(ZDomainFailure('nope')),
    );

    final ZResult<List<ZFlashcard>> result =
        await ZChatFlashcardGenerator(port).generateFromMessage(_message);

    expect(result.isLeft(), isTrue);
  });

  test('AD-10 — une impl qui LÈVE devient un Left, pas une exception nue',
      () async {
    final ZResult<List<ZFlashcard>> result =
        await ZChatFlashcardGenerator(_ThrowingPort())
            .generateFromMessage(_message);

    expect(result.isLeft(), isTrue);
    result.fold(
      (ZFailure f) => expect(f, isA<ZDomainFailure>()),
      (_) => fail('un Right est impossible ici'),
    );
  });

  test('la génération depuis une CONVERSATION porte la provenance conversation',
      () async {
    final _FakePort port =
        _FakePort((_) => const Right<ZFailure, List<ZFlashcard>>(<ZFlashcard>[]));

    await ZChatFlashcardGenerator(port).generateFromConversation(
      const ZChatConversation(id: 'c9'),
      const <ZChatMessage>[_message],
    );

    expect(
      port.seen?.provenance,
      const ZConversationSource(conversationId: 'c9', messageId: ''),
    );
  });
}
