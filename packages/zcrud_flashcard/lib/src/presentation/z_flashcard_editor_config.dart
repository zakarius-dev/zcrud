/// Discriminateur de widget d'édition flashcard (Story E9-5, AC1/AD-4).
///
/// origine: le dispatcher du cœur route un champ `EditionFieldType.custom` vers
/// le `ZWidgetRegistry` injecté **par le nom d'enum** (`'custom'`). Comme le cœur
/// n'expose **qu'un seul** `kind` `custom` (et qu'on **ne modifie pas**
/// `zcrud_core`), les widgets flashcard-spécifiques partagent ce `kind` et sont
/// discriminés **par la config du champ** ([ZFieldWidgetContext.field.config]) :
/// un unique builder enregistré sous `custom` lit le [ZFlashcardEditorKind]
/// porté par [ZFlashcardFieldConfig] et monte le sous-widget adéquat. Chaque
/// champ reste sa **propre tranche** (AD-2 : rebuild ciblé préservé).
library;

import 'package:zcrud_core/zcrud_core.dart';

/// Famille de widget d'édition flashcard-spécifique servie via le registre.
enum ZFlashcardEditorKind {
  /// Sélecteur du [type] de flashcard (6 valeurs, défensif → `openQuestion`).
  type,

  /// Éditeur QCM d'une `List<ZChoice>` (add/remove/reorder/toggle-correct).
  choices,

  /// Sélecteur vrai/faux (`isTrue`).
  trueFalse,
}

/// Config `const` d'un champ flashcard-spécifique (AD-4 — sous-classe additive
/// de [ZFieldConfig], **jamais** de fork du cœur). Porte le [editorKind] qui
/// discrimine le sous-widget monté par le builder unique enregistré sous le
/// `kind` `custom`.
class ZFlashcardFieldConfig extends ZFieldConfig {
  /// Construit la config d'un champ flashcard pour l'éditeur [editorKind].
  const ZFlashcardFieldConfig(this.editorKind);

  /// Famille d'éditeur flashcard à monter pour ce champ.
  final ZFlashcardEditorKind editorKind;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFlashcardFieldConfig &&
          runtimeType == other.runtimeType &&
          editorKind == other.editorKind;

  @override
  int get hashCode => Object.hash(runtimeType, editorKind);
}
