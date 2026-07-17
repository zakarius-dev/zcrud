/// AC2/AC5 — surface des DEUX ports IA de su-3 (AD-4/AD-5/AD-35/AD-36).
///
/// Ce test prouve que les ports sont **implémentables par une app hôte** avec la
/// forme exigée : `abstract interface class` (jamais `sealed`), retour
/// `Future<ZResult<…>>` (jamais une valeur nue), requête AD-35 **complète**, et
/// exports au **barrel public** (c'est via le barrel que tout est importé ici —
/// un oubli d'export casse la compilation de ce fichier).
///
/// ⚠️ Les implémentations ci-dessous sont des **doublures de test** : elles
/// prouvent l'*implémentabilité* du contrat, elles ne re-testent aucune logique
/// de prod (pas de tautologie D5).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// Une app hôte *implements* le port (⇒ il n'est PAS `sealed` : ce fichier ne
/// compilerait pas, AD-4 « frontière inter-package »).
class _FakeEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  ZFlashcardAnswerEvaluationRequest? seen;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    seen = request;
    return const Right<ZFailure, ZFlashcardAnswerEvaluation>(
      ZFlashcardAnswerEvaluation(feedback: 'ok', suggestedQuality: 4),
    );
  }
}

class _FakeHintPort implements ZFlashcardHintPort {
  ZFlashcardHintRequest? seen;

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    seen = request;
    return const Right<ZFailure, String>('indice généré');
  }
}

void main() {
  group('AC2 — port d\'évaluation ADVISORY', () {
    test('la requête porte les 7 champs d\'AD-35, mot pour mot', () {
      const request = ZFlashcardAnswerEvaluationRequest(
        question: 'q',
        userAnswer: 'a',
        cardType: ZFlashcardType.openQuestion,
        expectedAnswer: 'attendu',
        explanation: 'explication',
        timeTaken: Duration(seconds: 12),
        hintsUsed: 2,
      );
      expect(request.question, 'q');
      expect(request.userAnswer, 'a');
      expect(request.cardType, ZFlashcardType.openQuestion);
      expect(request.expectedAnswer, 'attendu');
      expect(request.explanation, 'explication');
      expect(request.timeTaken, const Duration(seconds: 12));
      expect(request.hintsUsed, 2);
    });

    test('hintsUsed défaut 0 ; timeTaken/expectedAnswer/explanation nullables',
        () {
      const request = ZFlashcardAnswerEvaluationRequest(
        question: 'q',
        userAnswer: 'a',
        cardType: ZFlashcardType.shortAnswer,
      );
      expect(request.hintsUsed, 0);
      expect(request.timeTaken, isNull);
      expect(request.expectedAnswer, isNull);
      expect(request.explanation, isNull);
    });

    test('la sortie est ADVISORY : isCorrect NULLABLE (AD-35 « isCorrect? »)',
        () {
      const evaluation =
          ZFlashcardAnswerEvaluation(feedback: 'f', suggestedQuality: 3);
      expect(evaluation.isCorrect, isNull);
      expect(evaluation.feedback, 'f');
      expect(evaluation.suggestedQuality, 3);
    });

    test(
        'la sortie transporte une suggestedQuality BRUTE, même hors bornes '
        '(le clamp est la charge du CONSOMMATEUR — AD-46, voie unique)', () {
      // Le VO ne clampe PAS : sinon la discipline d'échelle aurait DEUX
      // propriétaires (lui + `config.clampQuality`) et ils divergeraient.
      const evaluation =
          ZFlashcardAnswerEvaluation(feedback: 'f', suggestedQuality: 9);
      expect(evaluation.suggestedQuality, 9);
    });

    test('le port est implémentable et rend un ZResult (Either) — AD-5',
        () async {
      final port = _FakeEvaluationPort();
      final result = await port.evaluateAnswer(
        const ZFlashcardAnswerEvaluationRequest(
          question: 'q',
          userAnswer: 'a',
          cardType: ZFlashcardType.openQuestion,
        ),
      );
      expect(result.isRight(), isTrue);
      expect(port.seen, isNotNull);
    });

    test('l\'échappatoire `extra` (AD-4) loge un `quota` app-specific', () {
      // Arbitrage consigné : `quota?` d'AD-35 n'est PAS livré en v1
      // (`ZEducationQuotaInfo` vit dans `zcrud_study` ⇒ inatteignable sans
      // CYCLE). `extra` est la voie documentée, sans rupture de surface.
      const evaluation = ZFlashcardAnswerEvaluation(
        feedback: 'f',
        suggestedQuality: 3,
        extra: <String, dynamic>{'quota': 12},
      );
      expect(evaluation.extra['quota'], 12);
    });
  });

  group('AC5 — port d\'indices', () {
    test('shownHints défaut vide ; transporte les indices déjà montrés', () {
      const request = ZFlashcardHintRequest(
        question: 'q',
        cardType: ZFlashcardType.openQuestion,
      );
      expect(request.shownHints, isEmpty);

      const withShown = ZFlashcardHintRequest(
        question: 'q',
        cardType: ZFlashcardType.openQuestion,
        expectedAnswer: 'attendu',
        shownHints: <String>['indice stocké', 'indice généré 1'],
      );
      expect(withShown.shownHints, <String>['indice stocké', 'indice généré 1']);
      expect(withShown.expectedAnswer, 'attendu');
    });

    test('le port est implémentable et rend un ZResult<String> — AD-5',
        () async {
      final port = _FakeHintPort();
      final result = await port.generateHint(
        const ZFlashcardHintRequest(
          question: 'q',
          cardType: ZFlashcardType.openQuestion,
        ),
      );
      expect(result.isRight(), isTrue);
      expect(port.seen, isNotNull);
    });
  });

  group('égalité par VALEUR des VOs (value-objects immuables)', () {
    test('requête d\'évaluation : == et hashCode par valeur', () {
      const a = ZFlashcardAnswerEvaluationRequest(
        question: 'q',
        userAnswer: 'a',
        cardType: ZFlashcardType.openQuestion,
        hintsUsed: 1,
      );
      const b = ZFlashcardAnswerEvaluationRequest(
        question: 'q',
        userAnswer: 'a',
        cardType: ZFlashcardType.openQuestion,
        hintsUsed: 1,
      );
      const c = ZFlashcardAnswerEvaluationRequest(
        question: 'q',
        userAnswer: 'a',
        cardType: ZFlashcardType.openQuestion,
        hintsUsed: 2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('requête d\'indice : shownHints participe à l\'égalité', () {
      const a = ZFlashcardHintRequest(
        question: 'q',
        cardType: ZFlashcardType.openQuestion,
        shownHints: <String>['x'],
      );
      const b = ZFlashcardHintRequest(
        question: 'q',
        cardType: ZFlashcardType.openQuestion,
        shownHints: <String>['x'],
      );
      const c = ZFlashcardHintRequest(
        question: 'q',
        cardType: ZFlashcardType.openQuestion,
        shownHints: <String>['y'],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
