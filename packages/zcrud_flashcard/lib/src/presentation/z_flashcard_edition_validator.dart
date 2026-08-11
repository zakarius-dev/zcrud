/// Validation d'éditeur flashcard différée du modèle canonique.
///
/// La règle métier « QCM : au moins 2 choix, au moins 1 correct » porte sur
/// une `List<ZChoice>` que les `ZValidatorSpec` du cœur (chaîne-orientés,
/// `const`, appliqués sur une forme textuelle de la valeur) ne peuvent pas
/// exprimer. Cette validation vit donc ici, pure et backend-agnostique, et
/// se révèle via le canal `reveal` du `ZFormController` (jamais un
/// `Form`/`FormBuilder` global — invariant AD-2).
library;

import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_flashcard_type.dart';
import 'z_flashcard_editor_values.dart';

/// Messages d'erreur d'éditeur (défauts FR ; l'application peut les
/// surcharger).
///
/// Pur-données `const` : aucun style, aucune couleur — le rendu du message
/// (surface accessible) est la responsabilité du widget appelant.
class ZFlashcardEditionMessages {
  /// Construit un jeu de messages d'édition.
  const ZFlashcardEditionMessages({
    this.questionRequired = 'La question est requise.',
    this.qcmMinChoices = 'Un QCM requiert au moins 2 choix.',
    this.qcmNoCorrect = 'Au moins un choix doit être marqué comme correct.',
  });

  /// Message « énoncé requis ».
  final String questionRequired;

  /// Message « QCM : au moins 2 choix ».
  final String qcmMinChoices;

  /// Message « QCM : au moins 1 choix correct ».
  final String qcmNoCorrect;
}

/// Validateur d'éditeur flashcard (pur, sans état). Ne dépend d'aucun
/// backend ni gestionnaire d'état (invariant AD-1).
abstract final class ZFlashcardEditionValidator {
  /// Messages par défaut (partagés — évite d'allouer à chaque appel).
  static const ZFlashcardEditionMessages defaultMessages =
      ZFlashcardEditionMessages();

  /// Erreur d'éditeur sur la liste de choix [value] d'un champ QCM (`null`
  /// si valide) : au moins deux choix et au moins un choix `isCorrect`.
  /// Défensif : une valeur illisible est coercée en liste vide (⇒ « min 2
  /// choix »).
  static String? validateChoices(
    Object? value, {
    ZFlashcardEditionMessages messages = defaultMessages,
  }) {
    final choices = coerceChoices(value);
    if (choices.length < 2) return messages.qcmMinChoices;
    if (!choices.any((c) => c.isCorrect)) return messages.qcmNoCorrect;
    return null;
  }

  /// Erreur d'éditeur sur l'énoncé [value] (`null` si valide) : requis.
  static String? validateQuestion(
    Object? value, {
    ZFlashcardEditionMessages messages = defaultMessages,
  }) {
    final ok = value is String && value.trim().isNotEmpty;
    return ok ? null : messages.questionRequired;
  }

  /// Valide un instantané de valeurs de formulaire flashcard et retourne la
  /// table `name → message` des champs invalides (vide si tout est valide).
  ///
  /// Règles : [questionKey] requis ; si le [typeKey] vaut `multipleChoice`,
  /// le [choicesKey] doit avoir au moins deux choix et au moins un correct.
  /// Défensif : types illisibles coercés (jamais d'exception).
  static Map<String, String> validate(
    Map<String, Object?> values, {
    String questionKey = 'question',
    String typeKey = 'type',
    String choicesKey = 'choices',
    ZFlashcardEditionMessages messages = defaultMessages,
  }) {
    final errors = <String, String>{};
    final questionError =
        validateQuestion(values[questionKey], messages: messages);
    if (questionError != null) errors[questionKey] = questionError;

    if (coerceFlashcardType(values[typeKey]) ==
        ZFlashcardType.multipleChoice) {
      final choicesError =
          validateChoices(values[choicesKey], messages: messages);
      if (choicesError != null) errors[choicesKey] = choicesError;
    }
    return errors;
  }

  /// Valide les valeurs courantes de [controller] et, si invalide,
  /// déclenche [ZFormController.revealErrors] (révélation de toutes les
  /// familles sans `Form` global) puis retourne `false` (soumission à
  /// bloquer). Valide → `true` (aucune révélation superflue).
  ///
  /// C'est la brique d'intégration soumission : l'application la branche
  /// dans son propre seam `onSubmit`/bouton (le SRS et la persistance
  /// restent pilotés par l'application). Ne monte aucun `Form` global
  /// (invariant AD-2).
  static bool validateAndReveal(
    ZFormController controller, {
    String questionKey = 'question',
    String typeKey = 'type',
    String choicesKey = 'choices',
    ZFlashcardEditionMessages messages = defaultMessages,
  }) {
    final errors = validate(
      controller.values,
      questionKey: questionKey,
      typeKey: typeKey,
      choicesKey: choicesKey,
      messages: messages,
    );
    if (errors.isEmpty) return true;
    controller.revealErrors();
    return false;
  }
}
