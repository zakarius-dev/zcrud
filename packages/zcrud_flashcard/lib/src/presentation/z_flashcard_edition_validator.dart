/// Validation **éditeur** flashcard déférée d'E9-1 (Story E9-5, AC2).
///
/// origine: E9-1 avait explicitement **déféré** à E9-5 la règle métier « QCM :
/// min 2 choix + ≥ 1 correct » (`z_flashcard.dart:152`, `z_choice.dart`) — un
/// invariant portant sur une `List<ZChoice>` que les `ZValidatorSpec` `const`
/// pur-données du cœur (chaîne-orientés, appliqués sur `_stringOf(value)`) **ne
/// peuvent pas** exprimer. Cette validation vit donc **ici**, pure et
/// backend-agnostique, et se **révèle** via le canal `reveal` du
/// `ZFormController` (jamais un `Form`/`FormBuilder` global — AD-2).
library;

import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_flashcard_type.dart';
import 'z_flashcard_editor_values.dart';

/// Messages d'erreur éditeur (défauts FR ; l'app peut les surcharger).
///
/// Pur-données `const` : aucun style, aucune couleur (FR-26) — le rendu du
/// message (surface accessible) est la responsabilité du widget/chrome.
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

/// Validateur **éditeur** flashcard (pur, sans état). Ne dépend d'**aucun**
/// backend/gestionnaire d'état (AD-1).
abstract final class ZFlashcardEditionValidator {
  /// Messages par défaut (partagés — évite d'allouer à chaque appel).
  static const ZFlashcardEditionMessages defaultMessages =
      ZFlashcardEditionMessages();

  /// Erreur éditeur sur la **liste de choix** [value] d'un champ QCM (`null` si
  /// valide) : **≥ 2 choix** ET **≥ 1 choix `isCorrect`** (AC2). Défensif : une
  /// valeur illisible est coercée en `[]` (⇒ « min 2 choix »).
  static String? validateChoices(
    Object? value, {
    ZFlashcardEditionMessages messages = defaultMessages,
  }) {
    final choices = coerceChoices(value);
    if (choices.length < 2) return messages.qcmMinChoices;
    if (!choices.any((c) => c.isCorrect)) return messages.qcmNoCorrect;
    return null;
  }

  /// Erreur éditeur sur l'**énoncé** [value] (`null` si valide) : requis (AC2).
  static String? validateQuestion(
    Object? value, {
    ZFlashcardEditionMessages messages = defaultMessages,
  }) {
    final ok = value is String && value.trim().isNotEmpty;
    return ok ? null : messages.questionRequired;
  }

  /// Valide un **snapshot** de valeurs de formulaire flashcard et retourne la
  /// table `name → message` des champs invalides (vide si tout est valide).
  ///
  /// Règles (AC2) : [questionKey] requis ; si le [typeKey] vaut
  /// `multipleChoice`, le [choicesKey] doit avoir **≥ 2 choix + ≥ 1 correct**.
  /// Défensif : types illisibles coercés (jamais de throw).
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

  /// Valide les valeurs courantes de [controller] et, si **invalide**,
  /// déclenche [ZFormController.revealErrors] (révélation de TOUTES les familles
  /// **sans** `Form` global — AC2) puis retourne `false` (soumission à
  /// **bloquer**). Valide → `true` (aucune révélation superflue).
  ///
  /// C'est la brique d'intégration soumission : l'app la branche dans son seam
  /// `onSubmit`/bouton (le SRS et la persistance restent pilotés par l'app,
  /// UJ-4). Ne monte **aucun** `Form` global (AD-2).
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
