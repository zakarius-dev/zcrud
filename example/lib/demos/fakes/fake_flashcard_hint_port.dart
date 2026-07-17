import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';

/// **Port d'indices FAKE** déterministe (adaptateur app-side, AD-15/AD-36/AC3).
///
/// ## Migration
///
/// L'app réelle branche ICI son routeur IA (prompt + endpoint + clé restent
/// CÔTÉ APP, AD-12). Le contrat d'ordre est **imposé par la surface**
/// (`ZFlashcardAnswerInput`), pas par ce fake : l'indice **STOCKÉ**
/// (`ZFlashcard.hint`) est servi D'ABORD, et ce port n'est appelé qu'**APRÈS
/// épuisement** du stock (AD-36). La requête porte les [shownHints] déjà
/// affichés (anti-répétition).
///
/// Ici : renvoie un indice **neuf** déterministe dérivé du nombre d'indices déjà
/// montrés (jamais une paraphrase du précédent). Configurable en **échec**
/// (`Left`) — un indice non obtenu ne lève JAMAIS d'exception et ne pénalise pas
/// l'apprenant (AD-10/AC5).
class FakeFlashcardHintPort implements ZFlashcardHintPort {
  /// Construit le fake ; [failure] force un `Left` déterministe.
  FakeFlashcardHintPort({this.failure});

  /// Si non nul, [generateHint] échoue (`Left`) — pour prouver le repli AD-10.
  final ZFailure? failure;

  /// Nombre d'appels reçus (témoin : l'AC5 assère l'ABSENCE d'appel tant que le
  /// stock n'est pas épuisé).
  int callCount = 0;

  @override
  Future<ZResult<String>> generateHint(ZFlashcardHintRequest request) async {
    callCount += 1;
    final f = failure;
    if (f != null) return Left<ZFailure, String>(f);
    // Déterministe + anti-répétition : l'indice dépend du nombre déjà montré.
    final n = request.shownHints.length + 1;
    return Right<ZFailure, String>(
      'Indice IA #$n : concentrez-vous sur le mot clé de la question.',
    );
  }
}
