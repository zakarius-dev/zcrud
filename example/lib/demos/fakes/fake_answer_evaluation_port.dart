import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// **Port d'évaluation FAKE** — ADVISORY strict (adaptateur app-side,
/// AD-15/AD-35/AC3).
///
/// ## Migration
///
/// L'app réelle branche ICI son routeur IA (prompt/endpoint/clé CÔTÉ APP,
/// AD-12). Ce port **SUGGÈRE** une qualité, il ne **note** jamais et **n'écrit
/// jamais** le SRS (AD-33) : seul le tap de l'apprenant sur les boutons de
/// qualité vaut notation. Il n'est **JAMAIS** appelé pour un QCM ou un Vrai/Faux
/// (évalués LOCALEMENT et exactement par `zEvaluateLocally`, AD-35) — la surface
/// route par le TYPE, ce fake ne sert que la voie **rédigée**.
///
/// Ici : comparaison déterministe insensible à la casse/aux espaces entre la
/// réponse et l'attendu → `suggestedQuality` brute (le consommateur la clampe
/// via `config.clampQuality` puis plafonne via `zApplyHintCeiling` — jamais ici,
/// AD-46/AD-36). Configurable en **échec** (`Left`) : la surface retombe alors
/// sur la qualité neutre (`passThreshold`), sans exception (AD-10).
class FakeAnswerEvaluationPort implements ZFlashcardAnswerEvaluationPort {
  /// Construit le fake ; [failure] force un `Left` déterministe.
  FakeAnswerEvaluationPort({this.failure, this.correctQuality = 5, this.wrongQuality = 1});

  /// Si non nul, [evaluateAnswer] échoue (`Left`) — repli AD-10/AD-35.
  final ZFailure? failure;

  /// Qualité BRUTE suggérée sur bonne réponse (clampée EN AVAL, jamais ici).
  final int correctQuality;

  /// Qualité BRUTE suggérée sur réponse erronée.
  final int wrongQuality;

  /// Nombre d'appels reçus (témoin : l'AC1 assère l'ABSENCE d'appel pour QCM/VF).
  int callCount = 0;

  @override
  Future<ZResult<ZFlashcardAnswerEvaluation>> evaluateAnswer(
    ZFlashcardAnswerEvaluationRequest request,
  ) async {
    callCount += 1;
    final f = failure;
    if (f != null) return Left<ZFailure, ZFlashcardAnswerEvaluation>(f);
    final expected = (request.expectedAnswer ?? '').trim().toLowerCase();
    final given = request.userAnswer.trim().toLowerCase();
    final isCorrect = expected.isNotEmpty && given == expected;
    return Right<ZFailure, ZFlashcardAnswerEvaluation>(
      ZFlashcardAnswerEvaluation(
        feedback: isCorrect
            ? 'Bonne réponse — la formulation attendue est reconnue.'
            : 'À revoir : comparez votre réponse à l\'attendu.',
        suggestedQuality: isCorrect ? correctQuality : wrongQuality,
        isCorrect: isCorrect,
      ),
    );
  }
}
