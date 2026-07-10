/// Choix de QCM `ZChoice` (Story E9-1, AC2).
///
/// origine: lex_core (module « Étude ») — `lexia_flashcard.dart:15`
/// (`FlashcardChoice`) : déjà générique, zéro dépendance.
///
/// Sous-modèle `@ZcrudModel` (patron `Author` du corpus générateur, E2-5). Il
/// est décodé **défensivement par élément** dans la liste `ZFlashcard.choices`
/// (chemin `listModel` : un élément corrompu est ignoré, jamais de throw du
/// parent — AD-10).
///
/// **Aucune** validation métier (min 2 choix + 1 correct) ici : c'est la
/// validation **éditeur** (E9-5). L'entité **transporte** simplement le choix.
///
/// Importe la surface **pure** `edition.dart` (jamais le barrel principal, qui
/// tire Flutter) : `ZChoice` reste pur-Dart et testable sous `dart test`.
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

part 'z_choice.g.dart';

/// Un choix de QCM : un libellé [content] et son caractère correct [isCorrect].
@ZcrudModel(kind: 'flashcard_choice')
class ZChoice {
  /// Construit un choix (constructeur `const` — source du `copyWith` généré).
  const ZChoice({this.content = '', this.isCorrect = false});

  /// Reconstruit depuis une map persistée (délègue au `fromMap` généré défensif :
  /// `content` absent → `''`, `is_correct` absent → `false`, jamais de throw).
  factory ZChoice.fromMap(Map<String, dynamic> map) => _$ZChoiceFromMap(map);

  /// Libellé du choix (défaut `''` si absent — AC2).
  @ZcrudField(label: 'Choix')
  final String content;

  /// `true` si ce choix est la bonne réponse (persisté `is_correct`, snake_case ;
  /// défaut `false` si absent — AC2).
  @ZcrudField()
  final bool isCorrect;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChoice &&
          content == other.content &&
          isCorrect == other.isCorrect;

  @override
  int get hashCode => Object.hash(content, isCorrect);
}
