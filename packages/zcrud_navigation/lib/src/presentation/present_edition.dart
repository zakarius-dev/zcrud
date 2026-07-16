/// Helper de câblage **responsivité → présentation** (EX-UI.6, AD-30) — le
/// « maillon vivant ».
///
/// [presentEdition] matérialise la chaîne complète que **aucune app** ne réalise :
/// `largeur → ZWindowSizeClass → ZPresentationPolicy.resolve → ZEditionPresentation
/// → ZFormPresenter → surface`. C'est le **seul** endroit qui lie
/// `context → largeur` côté présentation (via `ZWindowSizeClass.of(context)` de
/// `zcrud_responsive`, EX-UI.1) — la politique EX-UI.5 reste **pure** (sans
/// `BuildContext`).
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_responsive/zcrud_responsive.dart' show ZWindowSizeClass;

import '../domain/z_form_weight.dart';
import '../domain/z_presentation_policy.dart';
import 'z_form_presenter.dart';
import 'z_form_presenter_scope.dart';

/// Présente un formulaire d'édition en **dérivant le mode du breakpoint courant**.
///
/// Étapes (AD-30) :
/// 1. mesure la classe de fenêtre : `ZWindowSizeClass.of(context)`
///    (`zcrud_responsive`, `MediaQuery.sizeOf` — jamais `Get.width`) ;
/// 2. dérive le mode : `policy.resolve(sizeClass, formWeight: formWeight)`
///    (`ZPresentationPolicy`, EX-UI.5, **pure**) ;
/// 3. résout le présentateur effectif : [presenter] fourni, **sinon** le seam
///    `ZFormPresenterScope.of(context)` (défaut `const ZAdaptivePresenter()`) ;
/// 4. délègue à `present<T>(context, builder: ..., mode: ...)`.
///
/// [policy] **et** [presenter] sont **injectables** (défauts M3 + défaut
/// pur-Flutter) — surchargeables par app sans modifier le package (AD-6/AD-4).
Future<T?> presentEdition<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  ZFormWeight formWeight = ZFormWeight.light,
  ZPresentationPolicy policy = const ZPresentationPolicy(),
  ZFormPresenter? presenter,
  double? maxWidth,
  double? maxHeight,
  bool useSafeArea = true,
  bool barrierDismissible = true,
}) {
  final sizeClass = ZWindowSizeClass.of(context);
  final mode = policy.resolve(sizeClass, formWeight: formWeight);
  final effective = presenter ?? ZFormPresenterScope.of(context);
  return effective.present<T>(
    context,
    builder: builder,
    mode: mode,
    maxWidth: maxWidth,
    maxHeight: maxHeight,
    useSafeArea: useSafeArea,
    barrierDismissible: barrierDismissible,
  );
}
