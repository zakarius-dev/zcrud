/// Choix de QCM `ZChoice`.
///
/// Sous-modèle du codegen. Il est décodé défensivement, élément par élément,
/// dans la liste `ZFlashcard.choices` : un élément corrompu est ignoré,
/// jamais un échec du parent (invariant AD-10).
///
/// Aucune validation métier (au moins deux choix, au moins un correct) ici :
/// c'est la validation de la couche d'édition. L'entité transporte
/// simplement le choix.
///
/// Importe la surface pure `edition.dart` (jamais le barrel principal, qui
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

  /// Reconstruit depuis une map persistée (délègue au décodeur généré et
  /// défensif : `content` absent → `''`, `is_correct` absent → `false`,
  /// jamais d'exception).
  factory ZChoice.fromMap(Map<String, dynamic> map) => _$ZChoiceFromMap(map);

  /// Libellé du choix (défaut `''` si absent).
  @ZcrudField(label: 'Choix')
  final String content;

  /// `true` si ce choix est la bonne réponse (persisté `is_correct`,
  /// snake_case ; défaut `false` si absent).
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
