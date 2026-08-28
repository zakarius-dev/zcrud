import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

const _allSelector = ZStudySessionSelector(ZStudySessionConfig());

void main() {
  group('sourceIds — inertie absolue', () {
    final cards = List<ZFlashcard>.generate(60, _variedCard);

    test('vide préserve octet pour octet le tirage de session', () {
      final result = zApplyTestFilters(
        cards,
        srsById: const <String, ZRepetitionInfo>{},
        filters: const ZFlashcardTestFilters(questionCount: 100),
        config: const ZSrsConfig(),
        selector: _allSelector,
        random: Random(42),
      );

      _expectSameOrderedInstances(result, cards);
    });

    test('vide préserve octet pour octet la liste de consultation', () {
      final result = zApplyBrowseFilters(
        cards,
        selector: _allSelector,
        filters: const ZFlashcardBrowseFilters(),
      );

      _expectSameOrderedInstances(result, cards);
    });
  });

  group('sourceIds — effet et composition avec le kind', () {
    const docA = ZFlashcard(
      id: 'doc-a',
      question: 'Document A',
      source: ZDocumentSource(documentId: 'docA'),
    );
    const noteB = ZFlashcard(
      id: 'note-b',
      question: 'Note B',
      source: ZNoteSource(noteId: 'noteB'),
    );
    const withoutSource = ZFlashcard(
      id: 'without-source',
      question: 'Sans source',
    );
    const effectCards = <ZFlashcard>[docA, noteB, withoutSource];

    test('le prédicat extrait exhaustivement les identifiants canoniques', () {
      const note = ZFlashcard(
        question: 'Note',
        source: ZNoteSource(noteId: 'note-1'),
      );
      const message = ZFlashcard(
        question: 'Message',
        source: ZConversationSource(
          conversationId: 'conversation-1',
          messageId: 'message-1',
        ),
      );
      const document = ZFlashcard(
        question: 'Document',
        source: ZDocumentSource(documentId: 'document-1'),
      );
      final custom = ZFlashcard(
        question: 'Source ouverte',
        source: ZCustomSource('article', const <String, dynamic>{
          'id': 'article-1',
        }),
      );
      const none = ZFlashcard(question: 'Sans source');

      expect(zMatchesSourceId(note, const <String>{'note-1'}), isTrue);
      expect(zMatchesSourceId(message, const <String>{'message-1'}), isTrue);
      expect(
        zMatchesSourceId(message, const <String>{'conversation-1'}),
        isFalse,
        reason: 'Le contenu source est le message précis, pas son conteneur.',
      );
      expect(zMatchesSourceId(document, const <String>{'document-1'}), isTrue);
      expect(zMatchesSourceId(custom, const <String>{'article-1'}), isFalse);
      expect(zMatchesSourceId(none, const <String>{'document-1'}), isFalse);
      expect(zMatchesSourceId(none, const <String>{}), isTrue);
    });

    test(
      '{docA} retient docA dans le tirage et exclut noteB et sans-source',
      () {
        final result = zApplyTestFilters(
          effectCards,
          srsById: const <String, ZRepetitionInfo>{},
          filters: const ZFlashcardTestFilters(
            questionCount: 10,
            sourceIds: <String>{'docA'},
          ),
          config: const ZSrsConfig(),
          selector: _allSelector,
          random: Random(1),
        );

        expect(result, orderedEquals(const <ZFlashcard>[docA]));
      },
    );

    test('{docA} retient docA dans la consultation et exclut les autres', () {
      final result = zApplyBrowseFilters(
        effectCards,
        selector: _allSelector,
        filters: const ZFlashcardBrowseFilters(sourceIds: <String>{'docA'}),
      );

      expect(result, orderedEquals(const <ZFlashcard>[docA]));
    });

    test(
      'sourceIds et sources se composent en ET dans les deux appliqueurs',
      () {
        const collision = <ZFlashcard>[
          ZFlashcard(
            id: 'document',
            question: 'Document',
            source: ZDocumentSource(documentId: 'same-id'),
          ),
          ZFlashcard(
            id: 'note',
            question: 'Note',
            source: ZNoteSource(noteId: 'same-id'),
          ),
        ];
        const testFilters = ZFlashcardTestFilters(
          questionCount: 10,
          sources: <String>{'document'},
          sourceIds: <String>{'same-id'},
        );
        const browseFilters = ZFlashcardBrowseFilters(
          sources: <String>{'document'},
          sourceIds: <String>{'same-id'},
        );

        final session = zApplyTestFilters(
          collision,
          srsById: const <String, ZRepetitionInfo>{},
          filters: testFilters,
          config: const ZSrsConfig(),
          selector: _allSelector,
          random: Random(1),
        );
        final browse = zApplyBrowseFilters(
          collision,
          selector: _allSelector,
          filters: browseFilters,
        );

        expect(
          session.map((card) => card.id),
          orderedEquals(<String>['document']),
        );
        expect(
          browse.map((card) => card.id),
          orderedEquals(<String>['document']),
        );
      },
    );

    test(
      'sourceIds participe à l\'égalité et au hashCode des deux filtres',
      () {
        const testA = ZFlashcardTestFilters(sourceIds: <String>{'docA'});
        const testB = ZFlashcardTestFilters(sourceIds: <String>{'docA'});
        const testOther = ZFlashcardTestFilters(sourceIds: <String>{'docB'});
        const browseA = ZFlashcardBrowseFilters(sourceIds: <String>{'docA'});
        const browseB = ZFlashcardBrowseFilters(sourceIds: <String>{'docA'});
        const browseOther = ZFlashcardBrowseFilters(
          sourceIds: <String>{'docB'},
        );

        expect(testA, equals(testB));
        expect(testA.hashCode, equals(testB.hashCode));
        expect(testA, isNot(equals(testOther)));
        expect(browseA, equals(browseB));
        expect(browseA.hashCode, equals(browseB.hashCode));
        expect(browseA, isNot(equals(browseOther)));
      },
    );
  });
}

ZFlashcard _variedCard(int index) {
  final source = switch (index % 5) {
    0 => null,
    1 => ZNoteSource(noteId: 'note-${index % 7}'),
    2 => ZConversationSource(
      conversationId: 'conversation-${index % 3}',
      messageId: 'message-${index % 11}',
    ),
    3 => ZDocumentSource(documentId: 'document-${index % 13}', page: index),
    _ => ZCustomSource('article', <String, dynamic>{
      'article_id': 'article-${index % 17}',
    }),
  };
  return ZFlashcard(
    id: 'card-$index',
    folderId: 'folder-${index % 4}',
    question: 'Question $index',
    tagIds: <String>['tag-${index % 6}'],
    source: source,
  );
}

void _expectSameOrderedInstances(
  List<ZFlashcard> actual,
  List<ZFlashcard> expected,
) {
  expect(actual, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    expect(
      actual[index],
      same(expected[index]),
      reason: 'La carte à l\'index $index doit rester la même instance.',
    );
  }
}
