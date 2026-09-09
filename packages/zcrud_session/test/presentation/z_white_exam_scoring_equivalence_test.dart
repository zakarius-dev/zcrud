/// Équivalence de notation entre les deux surfaces d'examen blanc, et régime
/// de la copie incomplète.
///
/// Le risque visé : deux surfaces qui noteraient la même copie différemment.
/// Il n'existe qu'un producteur de résultat — ces gardes le mesurent au lieu
/// de le supposer.
@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudySessionResult;

import '../support/z_sources.dart';

List<ZSessionItem> _queue(int count) => <ZSessionItem>[
  for (var i = 0; i < count; i++)
    ZSessionItem(flashcardId: 'q$i', folderId: 'f'),
];

/// Espion de seam d'écriture SRS : il compte les appels et sait répondre.
///
/// Il est ici pour être **capable** de compter — le contre-témoin plus bas le
/// prouve en le branchant sur le runtime qui, lui, écrit vraiment.
class _SpyReviewer {
  int calls = 0;

  Future<ZResult<ZRepetitionInfo>> call({
    required String flashcardId,
    required String folderId,
    required int quality,
    DateTime? now,
  }) async {
    calls += 1;
    return Right<ZFailure, ZRepetitionInfo>(
      ZRepetitionInfo(flashcardId: flashcardId, folderId: folderId),
    );
  }
}

void main() {
  group('équivalence liste ↔ coquille', () {
    test('les mêmes réponses donnent le même résultat', () {
      const qualities = <int>[5, 1, 3, 0, 4];

      final shell = ZWhiteExamSessionEngine(queue: _queue(5))..start();
      addTearDown(shell.dispose);
      for (final quality in qualities) {
        shell.answer(quality);
      }
      shell.submit();

      final list = ZWhiteExamSessionEngine(
        queue: _queue(5),
        startImmediately: true,
      );
      addTearDown(list.dispose);
      // Saisie DÉSORDONNÉE : c'est le cas où une note peut être attribuée à
      // la mauvaise question. Le résultat doit rester le même.
      list
        ..answerAt(3, qualities[3])
        ..answerAt(0, qualities[0])
        ..answerAt(4, qualities[4])
        ..answerAt(1, qualities[1])
        ..answerAt(2, qualities[2]);
      list.submit();

      expect(list.result, shell.result);
      expect(list.result?.total, 5);
      expect(list.result?.correct, 3);
    });

    test('les deux voies passent par le MÊME barème', () {
      final seen = <List<int>>[];
      ZStudySessionResult spyScorer(
        List<int> qualities, {
        required int passThreshold,
      }) {
        seen.add(List<int>.of(qualities));
        return scoreWhiteExam(qualities, passThreshold: passThreshold);
      }

      final shell = ZWhiteExamSessionEngine(queue: _queue(2), scorer: spyScorer)
        ..start()
        ..answer(5)
        ..answer(1);
      addTearDown(shell.dispose);
      shell.submit();

      final list = ZWhiteExamSessionEngine(
        queue: _queue(2),
        scorer: spyScorer,
        startImmediately: true,
      )
        ..answerAt(1, 1)
        ..answerAt(0, 5);
      addTearDown(list.dispose);
      list.submit();

      expect(seen, hasLength(2), reason: 'un seul barème, appelé une fois');
      expect(seen[0], seen[1], reason: 'la même copie, les mêmes notes');
      expect(list.result, shell.result);
    });

    test('« je ne sais pas » vaut la borne basse sur les deux voies', () {
      final shell = ZWhiteExamSessionEngine(queue: _queue(2))
        ..start()
        ..answer(5)
        ..answer(const ZSrsConfig().minQuality);
      addTearDown(shell.dispose);
      shell.submit();

      final list = ZWhiteExamSessionEngine(
        queue: _queue(2),
        startImmediately: true,
      )
        ..answerAt(0, 5)
        ..dontKnowAt(1);
      addTearDown(list.dispose);
      list.submit();

      expect(list.result, shell.result);
    });
  });

  group('copie incomplète', () {
    test('sans le régime, une question blanche ne pèse sur rien', () {
      final engine = ZWhiteExamSessionEngine(
        queue: _queue(5),
        startImmediately: true,
      )
        ..answerAt(0, 5)
        ..answerAt(1, 4);
      addTearDown(engine.dispose);

      engine.submit();

      expect(engine.result?.total, 2);
      expect(engine.result?.correct, 2);
    });

    test('avec le régime, une question blanche compte FAUSSE', () {
      final engine = ZWhiteExamSessionEngine(
        queue: _queue(5),
        startImmediately: true,
      )
        ..answerAt(0, 5)
        ..answerAt(1, 4);
      addTearDown(engine.dispose);

      engine.submit(countUnansweredAsIncorrect: true);

      expect(engine.result?.total, 5, reason: 'notée sur toute l\'épreuve');
      expect(engine.result?.correct, 2);
      expect(engine.result?.byQuality['0'], 3, reason: 'trois blanches');
    });

    test('une copie complète note pareil dans les deux régimes', () {
      ZWhiteExamSessionEngine build() => ZWhiteExamSessionEngine(
        queue: _queue(3),
        startImmediately: true,
      )
        ..answerAt(0, 5)
        ..answerAt(1, 2)
        ..answerAt(2, 3);

      final strict = build();
      addTearDown(strict.dispose);
      strict.submit(countUnansweredAsIncorrect: true);

      final lenient = build();
      addTearDown(lenient.dispose);
      lenient.submit();

      expect(strict.result, lenient.result);
    });
  });

  group('aucune écriture de répétition espacée', () {
    test('aucun seam SRS n\'entre dans les surfaces d\'examen par index', () {
      const banned = <String>[
        'ZSessionReviewer',
        'ZSrsScheduler',
        'ZRepetitionStore',
        'ZRepetitionInfo',
        '.apply(',
        '.initial(',
        '.put(',
        'reviewCard',
      ];
      const paths = <String>[
        'z_white_exam_list_view.dart',
        'z_white_exam_score_banner.dart',
        'z_white_exam_submit_policy.dart',
        'z_exam_answer.dart',
      ];
      for (final path in paths) {
        final File file = libFile(path);
        final String source = strippedSource(file);
        // Contre-preuve : le scan doit voir un vrai fichier, sinon il serait
        // vert pour de mauvaises raisons.
        expect(
          source.length,
          greaterThan(200),
          reason: 'source vide ou introuvable : $path',
        );
        for (final symbol in banned) {
          expect(
            source.contains(symbol),
            isFalse,
            reason: 'symbole d\'écriture SRS « $symbol » dans $path',
          );
        }
      }
    });

    test('un examen mené de bout en bout n\'appelle aucun seam d\'écriture', () {
      final spy = _SpyReviewer();
      final engine = ZWhiteExamSessionEngine(
        queue: _queue(3),
        startImmediately: true,
      )
        ..answerAt(0, 5)
        ..dontKnowAt(1)
        ..toggleMarkAt(2);
      addTearDown(engine.dispose);

      engine.submit(countUnansweredAsIncorrect: true);

      expect(engine.result, isNotNull);
      expect(spy.calls, 0);
    });

    test(
      '…et l\'espion, LUI, sait compter — sans quoi la garde ci-dessus serait '
      'verte pour de mauvaises raisons',
      () async {
        final spy = _SpyReviewer();
        final engine = ZStudySessionEngine(
          queue: _queue(1),
          reviewer: spy.call,
        );
        addTearDown(engine.dispose);

        await engine.grade(5);

        expect(spy.calls, 1);
      },
    );
  });
}
