/// `ZFlashcardEditingScope` — `InheritedWidget` **flashcard-local** exposant le
/// [ZFormController] aux widgets d'édition flashcard (Story E9-5, AC2/AD-2).
///
/// origine: un widget servi par le `ZWidgetRegistry` ne reçoit du cœur qu'un
/// [ZFieldWidgetContext] (`field`/`value`/`onChanged`) — **pas** le contrôleur
/// ni son canal de **révélation d'erreurs** (`reveal`). Or la validation éditeur
/// déférée (QCM ≥ 2 choix + ≥ 1 correct, AC2) doit se **révéler à la soumission
/// agrégée** via ce canal, **sans** monter de `Form` global (AD-2). Ce scope
/// **additif** (dans `zcrud_flashcard`, **aucune** édition de `zcrud_core`)
/// porte le contrôleur pour que l'éditeur QCM observe **uniquement** sa tranche
/// `reveal` (un `ValueListenable<int>` dédié — jamais le `notifyListeners()`
/// global). Absent → dégradation propre : aucun message révélé (l'app le câble).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Scope Flutter-natif exposant le [ZFormController] d'édition flashcard.
///
/// L'app enveloppe son `DynamicEdition` flashcard dans ce scope pour activer la
/// **révélation** des erreurs éditeur non-texte (QCM) à la soumission agrégée
/// (`controller.revealErrors()`), sans imposer de gestionnaire d'état (AD-15).
class ZFlashcardEditingScope extends InheritedWidget {
  /// Construit le scope autour de [child], exposant [controller].
  const ZFlashcardEditingScope({
    required this.controller,
    required super.child,
    super.key,
  });

  /// Contrôleur de formulaire détenant les tranches + le canal `reveal`.
  final ZFormController controller;

  /// Retourne le scope le plus proche, ou `null` s'il n'y en a pas.
  static ZFlashcardEditingScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZFlashcardEditingScope>();

  @override
  bool updateShouldNotify(ZFlashcardEditingScope oldWidget) =>
      !identical(controller, oldWidget.controller);
}
