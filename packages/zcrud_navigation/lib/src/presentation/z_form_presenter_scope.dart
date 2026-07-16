/// Seam de résolution du **présentateur effectif** (EX-UI.6, AD-6/D8) —
/// `InheritedWidget` **local à `zcrud_navigation`**.
///
/// [ZFormPresenterScope] est le point d'injection qui résout le [ZFormPresenter]
/// courant dans l'arbre de widgets, avec un **défaut sûr** `const
/// ZAdaptivePresenter()` (jamais de `throw` — AD-6/AD-10). Un **binding**
/// (EX-UI.11) surcharge le présentateur en enveloppant l'app :
/// `ZFormPresenterScope(presenter: ZGetFormPresenter(), child: ...)`.
///
/// **Seam LOCAL, `ZcrudScope` intact (D8/AD-1)** : on **NE modifie PAS** le
/// `ZcrudScope` de `zcrud_core` (il n'a aucun slot présentateur et vit dans le
/// cœur — y ajouter un [ZFormPresenter] défini ici forcerait
/// `zcrud_core → zcrud_navigation`, **cassant `CORE OUT=0`**). Le mécanisme de
/// seam (un `InheritedWidget` zéro-dépendance, à l'image de `ZcrudScope`) est
/// donc **répliqué localement** pour le type propre à ce package.
library;

import 'package:flutter/widgets.dart';

import 'z_adaptive_presenter.dart';
import 'z_form_presenter.dart';

/// `InheritedWidget` local exposant le [ZFormPresenter] effectif à la
/// sous-arborescence.
class ZFormPresenterScope extends InheritedWidget {
  /// Enveloppe [child] en fournissant [presenter] à ses descendants.
  const ZFormPresenterScope({
    required this.presenter,
    required super.child,
    super.key,
  });

  /// Présentateur injecté, exposé à la sous-arborescence.
  final ZFormPresenter presenter;

  /// Présentateur **par défaut** utilisé quand aucun [ZFormPresenterScope] n'est
  /// présent dans l'arbre. `const` — défaut sûr partagé (AD-6/AD-10).
  static const ZFormPresenter _defaultPresenter = ZAdaptivePresenter();

  /// Résout le présentateur effectif : celui injecté par le plus proche
  /// [ZFormPresenterScope] **ou**, à défaut, `const ZAdaptivePresenter()`.
  /// **Ne lève jamais** (défaut sûr — AD-6/AD-10).
  static ZFormPresenter of(BuildContext context) =>
      maybeOf(context)?.presenter ?? _defaultPresenter;

  /// Lookup **brut** du plus proche [ZFormPresenterScope] (ou `null`).
  static ZFormPresenterScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZFormPresenterScope>();

  @override
  bool updateShouldNotify(ZFormPresenterScope oldWidget) =>
      presenter != oldWidget.presenter;
}
