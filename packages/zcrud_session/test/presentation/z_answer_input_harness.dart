/// Harnais PARTAGÉ des tests de `ZFlashcardAnswerInput` (SU-3).
///
/// ⚠️ Ce fichier ne contient **aucune assertion de règle métier** : ce sont des
/// **doublures** et des **fabriques de carte**. Il ne re-code AUCUNE logique de
/// prod (défaut D5 : un test qui appelle sa propre implémentation de la règle
/// qu'il vérifie est tautologique).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Port d'évaluation **ESPION** : compte les appels et capture la requête.
///
/// 🔒 `callCount` est la garde centrale d'AD-35 : pour un QCM/VF il doit rester
/// à **0** (assertion d'**ABSENCE d'appel**).
class SpyEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  SpyEvaluationPort({this.suggestedQuality = 4, this.isCorrect, this.feedback});

  final int suggestedQuality;
  final bool? isCorrect;
  final String? feedback;

  int callCount = 0;
  ZFlashcardAnswerEvaluationRequest? request;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    callCount++;
    this.request = request;
    return Right<ZFailure, ZFlashcardAnswerEvaluation>(
      ZFlashcardAnswerEvaluation(
        feedback: feedback ?? 'retour du barème',
        suggestedQuality: suggestedQuality,
        isCorrect: isCorrect,
      ),
    );
  }
}

/// Port d'évaluation **LENT**, dont le test contrôle l'instant de réponse.
///
/// 🔒 Indispensable aux gardes de **CONCURRENCE** : la fenêtre `await` est le
/// seul endroit où une carte peut changer / un second tap peut passer. Un port
/// qui répond immédiatement ferme cette fenêtre et rend le défaut **invisible**.
class SlowEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  SlowEvaluationPort({this.suggestedQuality = 4});

  final int suggestedQuality;
  int callCount = 0;
  final List<Completer<void>> gates = <Completer<void>>[];
  final List<ZFlashcardAnswerEvaluationRequest> requests =
      <ZFlashcardAnswerEvaluationRequest>[];

  /// Libère la réponse n° [i] (0-indexée).
  void release(int i, {String feedback = 'fb'}) {
    _feedbacks[i] = feedback;
    gates[i].complete();
  }

  final Map<int, String> _feedbacks = <int, String>{};

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    final i = callCount++;
    requests.add(request);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return Right<ZFailure, ZFlashcardAnswerEvaluation>(
      ZFlashcardAnswerEvaluation(
        feedback: _feedbacks[i] ?? 'fb$i',
        suggestedQuality: suggestedQuality,
      ),
    );
  }
}

/// Port d'indices **LENT** — même rôle que [SlowEvaluationPort].
class SlowHintPort implements ZFlashcardHintPort {
  int callCount = 0;
  final List<Completer<void>> gates = <Completer<void>>[];
  final List<ZFlashcardHintRequest> requests = <ZFlashcardHintRequest>[];

  void release(int i, String hint) {
    _hints[i] = hint;
    gates[i].complete();
  }

  final Map<int, String> _hints = <int, String>{};

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    final i = callCount++;
    requests.add(request);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return Right<ZFailure, String>(_hints[i] ?? 'indice $i');
  }
}

/// Port d'évaluation qui **ÉCHOUE** (`Left`) — AC3.
class FailingEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  int callCount = 0;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    callCount++;
    return const Left<ZFailure, ZFlashcardAnswerEvaluation>(
      ZServerFailure('quota dépassé'),
    );
  }
}

/// Port d'évaluation qui **JETTE** — AC3 (AD-10 : le repli couvre AUSSI le throw).
class ThrowingEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  int callCount = 0;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    callCount++;
    throw StateError('routeur IA en panne');
  }
}

/// Port d'indices **ESPION**.
class SpyHintPort implements ZFlashcardHintPort {
  SpyHintPort({this.hint = 'indice généré'});

  final String hint;
  int callCount = 0;
  ZFlashcardHintRequest? request;

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    callCount++;
    this.request = request;
    return Right<ZFailure, String>('$hint ${callCount}');
  }
}

/// Port d'indices qui **ÉCHOUE**.
class FailingHintPort implements ZFlashcardHintPort {
  int callCount = 0;

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    callCount++;
    return const Left<ZFailure, String>(ZServerFailure('indisponible'));
  }
}

/// Port d'indices qui **JETTE**.
class ThrowingHintPort implements ZFlashcardHintPort {
  int callCount = 0;

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    callCount++;
    throw StateError('boom');
  }
}

/// QCM à **UN** correct (index 1) ⇒ mode **exclusif** attendu.
ZFlashcard qcmSingle() => const ZFlashcard(
  question: 'Capitale du Togo ?',
  type: ZFlashcardType.multipleChoice,
  choices: <ZChoice>[
    ZChoice(content: 'Accra'),
    ZChoice(content: 'Lomé', isCorrect: true),
    ZChoice(content: 'Cotonou'),
  ],
);

/// QCM à **DEUX** corrects (0 et 2) ⇒ mode **cumulatif** attendu.
ZFlashcard qcmMulti() => const ZFlashcard(
  question: 'Lesquels sont des pays ?',
  type: ZFlashcardType.multipleChoice,
  choices: <ZChoice>[
    ZChoice(content: 'Togo', isCorrect: true),
    ZChoice(content: 'Lomé'),
    ZChoice(content: 'Ghana', isCorrect: true),
  ],
);

/// Carte Vrai/Faux.
ZFlashcard trueFalseCard({bool? isTrue = true}) => ZFlashcard(
  question: 'Le Togo borde le Ghana.',
  type: ZFlashcardType.trueOrFalse,
  isTrue: isTrue,
);

/// Carte à réponse **rédigée** (type NON local ⇒ port).
ZFlashcard writtenCard({String? hint}) => ZFlashcard(
  question: 'Expliquez le transit douanier.',
  type: ZFlashcardType.openQuestion,
  answer: 'réponse attendue',
  explanation: 'explication',
  hint: hint,
);

/// Clés de test (miroir des `static const` privées du widget).
abstract final class K {
  static const ValueKey<String> submit = ValueKey<String>('zSubmit');
  static const ValueKey<String> dontKnow = ValueKey<String>('zDontKnow');
  static const ValueKey<String> hintButton = ValueKey<String>('zHintButton');
  static const ValueKey<String> answerField = ValueKey<String>('zAnswerField');
  static const ValueKey<String> answerTrue = ValueKey<String>('zAnswerTrue');
  static const ValueKey<String> answerFalse = ValueKey<String>('zAnswerFalse');
  static const ValueKey<String> feedback = ValueKey<String>('zFeedback');
  static const ValueKey<String> timer = ValueKey<String>('zFlashcardTimer');

  static ValueKey<String> choice(int i) => ValueKey<String>('zAnswerChoice_$i');
  static ValueKey<String> quality(int q) => ValueKey<String>('zSrsQuality_$q');
}

/// Monte la surface dans un hôte minimal.
Widget host(ZFlashcardAnswerInput input) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: input)),
);
