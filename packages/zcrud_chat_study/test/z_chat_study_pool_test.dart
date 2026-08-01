/// Gardes de constitution du pool de session (CHAT-8).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat_study/zcrud_chat_study.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Fabrique de carte de test.
///
/// ⚠️ [question] par défaut = l'[id] : sans cela, deux cartes distinctes créées
/// par leur seul id partageraient la MÊME clé de contenu et seraient
/// légitimement dédoublonnées — le fixture masquerait alors la propriété qu'on
/// veut mesurer (mesuré : `fromFolder` valait 1 au lieu de 2).
ZFlashcard _card({
  String? id,
  String? folderId,
  String? question,
  String? answer,
  ZFlashcardType type = ZFlashcardType.openQuestion,
  List<String> tagIds = const <String>[],
}) =>
    ZFlashcard(
      id: id,
      folderId: folderId,
      question: question ?? id ?? 'q',
      answer: answer,
      type: type,
      tagIds: tagIds,
    );

void main() {
  test('l\'union préserve l\'ordre « dossier puis conversation »', () {
    final ZStudyPool pool = zBuildStudyPool(
      ZStudyPoolRequest(
        folderCards: <ZFlashcard>[_card(id: 'a', question: 'A')],
        conversationCards: <ZFlashcard>[_card(question: 'B')],
      ),
    );

    expect(pool.cards.map((ZFlashcard c) => c.question), <String>['A', 'B']);
    expect(pool.fromFolder, 1);
    expect(pool.fromConversation, 1);
  });

  group('dédoublonnage', () {
    test('deux occurrences du MÊME id ne comptent qu\'une fois', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[_card(id: 'a'), _card(id: 'a')],
        ),
      );

      expect(pool.cards, hasLength(1));
      expect(pool.duplicatesDropped, 1);
    });

    test(
        'une carte de conversation régénérée à l\'identique ne double PAS une '
        'carte du dossier (le défaut mesuré chez IFFD)', () {
      // Chez IFFD la fusion est une simple concaténation `+`, et les cartes de
      // chat reçoivent un id SYNTHÉTIQUE : elles ne peuvent jamais collisionner
      // avec l'id du dépôt ⇒ la même question apparaît DEUX fois en session.
      // C'est exactement ce que la clé de CONTENU corrige ici.
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[
            _card(id: 'persisted', question: 'Qu\'est-ce que la valeur ?',
                answer: 'Assiette'),
          ],
          conversationCards: <ZFlashcard>[
            _card(question: "  Qu'est-ce   QUE la Valeur ?  ", answer: 'assiette'),
          ],
        ),
      );

      expect(pool.cards, hasLength(1));
      expect(pool.duplicatesDropped, 1);
      // 🔴 C'est la carte PERSISTÉE qui est retenue : elle seule porte un `id`,
      // donc seule elle peut être jointe à son `ZRepetitionInfo`. Retenir
      // l'éphémère ferait repartir de zéro une carte déjà apprise, en silence.
      expect(pool.cards.single.id, 'persisted');
      expect(pool.fromFolder, 1);
      expect(pool.fromConversation, 0);
    });

    test('deux cartes de contenu DIFFÉRENT ne sont pas fusionnées', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          conversationCards: <ZFlashcard>[
            _card(question: 'A'),
            _card(question: 'B'),
          ],
        ),
      );

      expect(pool.cards, hasLength(2));
      expect(pool.duplicatesDropped, 0);
    });

    test('le TYPE discrimine deux cartes de même énoncé', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          conversationCards: <ZFlashcard>[
            _card(question: 'A', type: ZFlashcardType.openQuestion),
            _card(question: 'A', type: ZFlashcardType.trueOrFalse),
          ],
        ),
      );

      expect(pool.cards, hasLength(2));
    });
  });

  group('filtres — ZStudySessionSelector RÉUTILISÉ', () {
    test(
        '🔴 le filtre DOSSIER ne s\'applique PAS aux cartes de conversation '
        '(pas d\'aller-retour par le dossier, contrairement à lex)', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[
            _card(id: 'in', folderId: 'f1'),
            _card(id: 'out', folderId: 'f2'),
          ],
          // Éphémère, SANS folderId : le filtre dossier l'éliminerait.
          conversationCards: <ZFlashcard>[_card(question: 'issue du chat')],
          config: const ZStudySessionConfig(folderId: 'f1'),
        ),
      );

      expect(pool.cards.map((ZFlashcard c) => c.id ?? c.question),
          <String>['in', 'issue du chat']);
    });

    test('les filtres de CONTENU (types) s\'appliquent aux DEUX origines', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[
            _card(id: 'ok', type: ZFlashcardType.trueOrFalse),
            _card(id: 'ko', type: ZFlashcardType.openQuestion),
          ],
          conversationCards: <ZFlashcard>[
            _card(question: 'chat-ok', type: ZFlashcardType.trueOrFalse),
            _card(question: 'chat-ko', type: ZFlashcardType.openQuestion),
          ],
          config: const ZStudySessionConfig(
            types: <String>['trueOrFalse'],
          ),
        ),
      );

      expect(pool.cards.map((ZFlashcard c) => c.id ?? c.question),
          <String>['ok', 'chat-ok']);
    });

    test('les filtres d\'ÉTIQUETTES s\'appliquent aux deux origines', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          conversationCards: <ZFlashcard>[
            _card(question: 'taggée', tagIds: <String>['t1']),
            _card(question: 'sans tag'),
          ],
          config: const ZStudySessionConfig(tagIds: <String>['t1']),
        ),
      );

      expect(pool.cards.single.question, 'taggée');
    });
  });

  group('AD-9 — soft-delete, jamais de hard-delete', () {
    test('une carte soft-supprimée est EXCLUE du pool', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[_card(id: 'a'), _card(id: 'b')],
          softDeletedIds: const <String>{'b'},
        ),
      );

      expect(pool.cards.map((ZFlashcard c) => c.id), <String>['a']);
      expect(pool.softDeletedDropped, 1);
    });

    test('exclure du pool ne MUTE ni ne détruit la carte d\'entrée', () {
      final List<ZFlashcard> folder = <ZFlashcard>[_card(id: 'b')];

      zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: folder,
          softDeletedIds: const <String>{'b'},
        ),
      );

      // La liste d'entrée est intacte : le pool est une LECTURE filtrée.
      expect(folder, hasLength(1));
      expect(folder.single.id, 'b');
    });
  });

  group('plafond count', () {
    test('la troncature s\'applique APRÈS le dédoublonnage', () {
      // 3 entrées dont 1 doublon : avec un plafond de 2, tronquer AVANT le
      // dédoublonnage rendrait 1 seule carte utile (le doublon aurait mangé
      // une place). Ce test rougit si l'ordre des deux opérations s'inverse.
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[_card(id: 'a'), _card(id: 'a')],
          conversationCards: <ZFlashcard>[_card(question: 'b')],
          config: const ZStudySessionConfig(count: 2),
        ),
      );

      expect(pool.cards, hasLength(2));
      expect(pool.duplicatesDropped, 1);
    });

    test('count <= 0 rend un pool vide, sans lever (AD-10)', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[_card(id: 'a')],
          config: const ZStudySessionConfig(count: 0),
        ),
      );

      expect(pool.isEmpty, isTrue);
    });

    test('les compteurs restent exacts après troncature', () {
      final ZStudyPool pool = zBuildStudyPool(
        ZStudyPoolRequest(
          folderCards: <ZFlashcard>[_card(id: 'a'), _card(id: 'b')],
          conversationCards: <ZFlashcard>[
            _card(question: 'x'),
            _card(question: 'y'),
          ],
          config: const ZStudySessionConfig(count: 3),
        ),
      );

      expect(pool.cards, hasLength(3));
      expect(pool.fromFolder, 2);
      expect(pool.fromConversation, 1);
    });
  });

  test('requête vide → pool vide, sans lever (AD-10)', () {
    final ZStudyPool pool = zBuildStudyPool(const ZStudyPoolRequest());

    expect(pool.isEmpty, isTrue);
    expect(pool.duplicatesDropped, 0);
    expect(pool.softDeletedDropped, 0);
  });
}
