/// Tests E9-3 : primitive PURE `ZStudySessionSelector` (AC8, FR-18, AD-14).
///
/// Couvre la sémantique EXACTE : filtre dossier (couvre sous-dossier), tags
/// (intersection non vide), types (appartenance), composition ET, plafond
/// `count` (troncature + `null` illimité + `<= 0` vide), config vide (tout
/// null ⇒ toutes les cartes), ordre préservé. Pur et déterministe.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

ZFlashcard _card(
  String q, {
  String? folderId,
  String? subFolderId,
  List<String> tagIds = const <String>[],
  ZFlashcardType type = ZFlashcardType.openQuestion,
}) =>
    ZFlashcard(
      question: q,
      folderId: folderId,
      subFolderId: subFolderId,
      tagIds: tagIds,
      type: type,
    );

List<String> _qs(List<ZFlashcard> cards) =>
    cards.map((c) => c.question).toList();

void main() {
  group('Filtre dossier (AC8)', () {
    final cards = <ZFlashcard>[
      _card('a', folderId: 'f1'),
      _card('b', folderId: 'f2'),
      _card('c', subFolderId: 'f1'), // sous-dossier de f1
      _card('d', folderId: 'other', subFolderId: 'x'),
    ];

    test('folderId null ⇒ pas de filtre dossier', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig());
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('folderId cible couvre le dossier ET ses sous-dossiers', () {
      final sel =
          const ZStudySessionSelector(ZStudySessionConfig(folderId: 'f1'));
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'c']);
    });
  });

  group('Filtre tags (AC8)', () {
    final cards = <ZFlashcard>[
      _card('a', tagIds: const <String>['x', 'y']),
      _card('b', tagIds: const <String>['z']),
      _card('c', tagIds: const <String>['y']),
      _card('d'),
    ];

    test('tagIds null ⇒ pas de filtre', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig());
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('tagIds vide ⇒ pas de filtre (documenté)', () {
      final sel = const ZStudySessionSelector(
        ZStudySessionConfig(tagIds: <String>[]),
      );
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('intersection non vide (au moins une étiquette commune)', () {
      final sel = const ZStudySessionSelector(
        ZStudySessionConfig(tagIds: <String>['y', 'q']),
      );
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'c']);
    });
  });

  group('Filtre types (AC8)', () {
    final cards = <ZFlashcard>[
      _card('a', type: ZFlashcardType.multipleChoice),
      _card('b', type: ZFlashcardType.trueOrFalse),
      _card('c', type: ZFlashcardType.openQuestion),
    ];

    test('types null ⇒ pas de filtre', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig());
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c']);
    });

    test('types vide ⇒ pas de filtre', () {
      final sel = const ZStudySessionSelector(
        ZStudySessionConfig(types: <ZFlashcardType>[]),
      );
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c']);
    });

    test('appartenance (config.types.contains(card.type))', () {
      final sel = const ZStudySessionSelector(
        ZStudySessionConfig(
          types: <ZFlashcardType>[
            ZFlashcardType.multipleChoice,
            ZFlashcardType.openQuestion,
          ],
        ),
      );
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'c']);
    });
  });

  group('Composition ET des filtres (AC8)', () {
    test('dossier ∧ tags ∧ types se composent en ET', () {
      final cards = <ZFlashcard>[
        _card('ok',
            folderId: 'f1',
            tagIds: const <String>['x'],
            type: ZFlashcardType.multipleChoice),
        _card('mauvais_dossier',
            folderId: 'f2',
            tagIds: const <String>['x'],
            type: ZFlashcardType.multipleChoice),
        _card('mauvais_tag',
            folderId: 'f1',
            tagIds: const <String>['z'],
            type: ZFlashcardType.multipleChoice),
        _card('mauvais_type',
            folderId: 'f1',
            tagIds: const <String>['x'],
            type: ZFlashcardType.trueOrFalse),
      ];
      final sel = const ZStudySessionSelector(
        ZStudySessionConfig(
          folderId: 'f1',
          tagIds: <String>['x'],
          types: <ZFlashcardType>[ZFlashcardType.multipleChoice],
        ),
      );
      expect(_qs(sel.selectFrom(cards)), <String>['ok']);
    });
  });

  group('Plafond count (AC8)', () {
    final cards = <ZFlashcard>[
      _card('a'),
      _card('b'),
      _card('c'),
      _card('d'),
    ];

    test('count null ⇒ illimité', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig());
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('count tronque en préservant l\'ordre d\'entrée', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig(count: 2));
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b']);
    });

    test('count >= taille ⇒ toute la sélection', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig(count: 10));
      expect(_qs(sel.selectFrom(cards)), <String>['a', 'b', 'c', 'd']);
    });

    test('count <= 0 ⇒ sélection vide (documenté, sans throw)', () {
      expect(
        const ZStudySessionSelector(ZStudySessionConfig(count: 0))
            .selectFrom(cards),
        isEmpty,
      );
      expect(
        const ZStudySessionSelector(ZStudySessionConfig(count: -3))
            .selectFrom(cards),
        isEmpty,
      );
    });

    test('count s\'applique APRÈS les filtres', () {
      final cards2 = <ZFlashcard>[
        _card('a', folderId: 'f1'),
        _card('skip', folderId: 'f2'),
        _card('b', folderId: 'f1'),
        _card('c', folderId: 'f1'),
      ];
      final sel = const ZStudySessionSelector(
        ZStudySessionConfig(folderId: 'f1', count: 2),
      );
      expect(_qs(sel.selectFrom(cards2)), <String>['a', 'b']);
    });
  });

  group('Config vide + prédicat matches (AC8)', () {
    test('config tout-null ⇒ toutes les cartes telles quelles', () {
      final cards = <ZFlashcard>[_card('a'), _card('b')];
      final sel = const ZStudySessionSelector(ZStudySessionConfig());
      expect(sel.selectFrom(cards), cards);
    });

    test('matches n\'applique pas le plafond count', () {
      final sel = const ZStudySessionSelector(ZStudySessionConfig(count: 0));
      expect(sel.matches(_card('a')), isTrue);
    });

    test('selectFrom déterministe (mêmes entrées ⇒ même sortie)', () {
      final cards = <ZFlashcard>[
        _card('a', folderId: 'f1'),
        _card('b', folderId: 'f1'),
      ];
      final sel =
          const ZStudySessionSelector(ZStudySessionConfig(folderId: 'f1'));
      expect(_qs(sel.selectFrom(cards)), _qs(sel.selectFrom(cards)));
    });
  });
}
