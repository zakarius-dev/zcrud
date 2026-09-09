/// État d'examen blanc **par index** : réponse rangée sous sa question,
/// « je ne sais pas », marquage, et invariant de comptage.
///
/// Ces gardes attaquent le point où un examen se fausse sans lever la moindre
/// exception : une note attribuée à la mauvaise question, ou comptée deux
/// fois.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart' show ZSrsConfig;
import 'package:zcrud_session/zcrud_session.dart';

ZWhiteExamSessionEngine _engine({
  int count = 5,
  ZSrsConfig config = const ZSrsConfig(),
  ZExamScoringPort? scorer,
}) => ZWhiteExamSessionEngine(
  queue: <ZSessionItem>[
    for (var i = 0; i < count; i++)
      ZSessionItem(flashcardId: 'q$i', folderId: 'f'),
  ],
  config: config,
  scorer: scorer ?? scoreWhiteExam,
  startImmediately: true,
);

void main() {
  group('comptage par index', () {
    test('répondre à 2 questions sur 5 en laisse 3 sans réponse', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.answerAt(0, 5);
      engine.answerAt(3, 4);

      expect(engine.answeredCount, 2);
      expect(engine.unansweredCount, 3);
      expect(engine.answersByIndex.keys.toSet(), <int>{0, 3});
      // La note est rangée SOUS SA QUESTION : la 4e vaut 4, pas 5.
      expect(engine.state.answerFor(3).quality, 4);
      expect(engine.state.answerFor(1).kind, ZExamAnswerKind.unanswered);
    });

    test('répondre dans le désordre n\'attribue aucune note de travers', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.answerAt(4, 5);
      engine.answerAt(1, 2);
      engine.answerAt(2, 0);

      expect(engine.state.answerFor(4).quality, 5);
      expect(engine.state.answerFor(1).quality, 2);
      expect(engine.state.answerFor(2).quality, 0);
      expect(engine.state.answerFor(0).isAnswered, isFalse);
      expect(engine.state.answerFor(3).isAnswered, isFalse);
    });

    test('« je ne sais pas » compte répondue ET fausse', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.answerAt(0, 5);
      engine.dontKnowAt(3);

      expect(engine.answeredCount, 2, reason: 'elle compte répondue');
      expect(engine.state.answerFor(3).isAnswered, isTrue);
      expect(engine.state.answerFor(3).kind, ZExamAnswerKind.dontKnow);
      expect(engine.state.answerFor(3).quality, isNull);

      engine.submit();
      final result = engine.result;
      expect(result, isNotNull);
      expect(result?.total, 2);
      expect(result?.correct, 1, reason: 'elle compte fausse');
      // Elle entre au scoring à la borne basse de l'échelle déclarée.
      expect(result?.byQuality['0'], 1);
    });

    test('la borne basse suit la config, jamais un littéral', () {
      final engine = _engine(config: const ZSrsConfig(minQuality: 1));
      addTearDown(engine.dispose);

      engine.dontKnowAt(2);
      engine.submit();

      expect(engine.result?.byQuality['1'], 1);
      expect(engine.result?.byQuality['0'], isNull);
      expect(engine.result?.correct, 0);
    });

    test('le marquage bascule sans toucher à la réponse', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.answerAt(2, 5);
      engine.toggleMarkAt(2);

      expect(engine.marked, <int>{2});
      expect(engine.state.isMarkedAt(2), isTrue);
      expect(engine.state.answerFor(2).quality, 5, reason: 'réponse intacte');
      expect(engine.answeredCount, 1);

      engine.toggleMarkAt(2);
      expect(engine.marked, isEmpty);
      expect(engine.state.answerFor(2).quality, 5);
      expect(engine.answeredCount, 1);
    });

    test('marquer une question sans réponse ne la rend pas répondue', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.toggleMarkAt(1);

      expect(engine.state.isMarkedAt(1), isTrue);
      expect(engine.answeredCount, 0);
      expect(engine.unansweredCount, 5);
    });

    test('une réponse est remplaçable tant que l\'examen n\'est pas soumis', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.answerAt(1, 5);
      engine.dontKnowAt(1);

      expect(engine.answeredCount, 1, reason: 'jamais comptée deux fois');
      expect(engine.state.answers, hasLength(1));
      expect(engine.state.answerFor(1).kind, ZExamAnswerKind.dontKnow);

      engine.submit();
      expect(engine.result?.total, 1);
      expect(engine.result?.correct, 0);
    });
  });

  group('invariant des deux vues de l\'état', () {
    test('la voie par index tient answers et answersByIndex alignés', () {
      final engine = _engine();
      addTearDown(engine.dispose);

      engine.answerAt(4, 5);
      engine.dontKnowAt(1);
      engine.answerAt(0, 3);
      engine.answerAt(4, 2);

      final derived = zWhiteExamRecordedQualities(
        engine.answersByIndex,
        incorrectQuality: const ZSrsConfig().minQuality,
      );
      expect(engine.state.answers, derived);
      expect(engine.state.answers, hasLength(engine.answersByIndex.length));
    });

    test('le parcours linéaire tient les deux vues alignées, lui aussi', () {
      final engine = _engine(count: 3);
      addTearDown(engine.dispose);

      engine
        ..answer(5)
        ..answer(1)
        ..answer(4);

      expect(engine.state.answers, <int>[5, 1, 4]);
      expect(
        zWhiteExamRecordedQualities(
          engine.answersByIndex,
          incorrectQuality: const ZSrsConfig().minQuality,
        ),
        <int>[5, 1, 4],
      );
      expect(engine.answeredCount, 3);
      expect(engine.unansweredCount, 0);
    });
  });

  group('transitions illégales — jamais un enregistrement perdu en silence', () {
    test('saisir par index hors `running` lève', () {
      final engine = ZWhiteExamSessionEngine(
        queue: const <ZSessionItem>[
          ZSessionItem(flashcardId: 'q', folderId: 'f'),
        ],
      );
      addTearDown(engine.dispose);

      expect(() => engine.answerAt(0, 5), throwsStateError);
      expect(() => engine.dontKnowAt(0), throwsStateError);
      expect(() => engine.toggleMarkAt(0), throwsStateError);
    });

    test('un index hors de la file lève, il n\'est pas rangé ailleurs', () {
      final engine = _engine(count: 2);
      addTearDown(engine.dispose);

      expect(() => engine.answerAt(2, 5), throwsRangeError);
      expect(() => engine.answerAt(-1, 5), throwsRangeError);
      expect(() => engine.dontKnowAt(7), throwsRangeError);
      expect(() => engine.toggleMarkAt(2), throwsRangeError);
      expect(engine.answersByIndex, isEmpty);
      expect(engine.marked, isEmpty);
    });

    test('mêler les deux voies d\'écriture sur la même question lève', () {
      final engine = _engine(count: 3);
      addTearDown(engine.dispose);

      engine.answerAt(0, 5);

      expect(() => engine.answer(3), throwsStateError);
      expect(engine.answeredCount, 1, reason: 'aucun double comptage');
      expect(engine.state.answers, <int>[5]);
    });

    test('un examen né commencé n\'a pas de phase de réglage', () {
      final engine = _engine(count: 1);
      addTearDown(engine.dispose);

      expect(engine.phase, ZWhiteExamPhase.running);
      expect(engine.start, throwsStateError);
    });
  });
}
