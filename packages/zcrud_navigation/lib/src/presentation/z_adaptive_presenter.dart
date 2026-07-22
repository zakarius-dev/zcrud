/// Présentateur **par défaut pur-Flutter** (EX-UI.6, AD-30) — exécute le mode
/// [ZEditionPresentation] en **Flutter vanilla**.
///
/// [ZAdaptivePresenter] est la réécriture **neutre** (sans gestionnaire d'état ni
/// routeur) du `showPushedDialog<T>` GetX des apps historiques (dodlp / iffd
/// `forms_utils.dart`) : les trois branches `Get.to`/`Get.dialog`/
/// `Get.bottomSheet` deviennent `Navigator.push(MaterialPageRoute(...))` /
/// `showDialog` / `showModalBottomSheet` **natifs**, `Get.width`/`Get.height`
/// deviennent `MediaQuery.sizeOf(context)`, et les booléens `fullscreenDialog`/
/// `dialog` deviennent l'`enum` [ZEditionPresentation].
///
/// **Aucun manager (AD-2/AD-15/NFR-U2)** : ce fichier n'importe **NI**
/// `package:get/...` **NI** `go_router` **NI** aucun gestionnaire d'état — que
/// `package:flutter/material.dart`.
library;

import 'package:flutter/material.dart';

import '../domain/z_edition_presentation.dart';
import 'z_form_presenter.dart';

/// Fractions d'écran par défaut (dp) dérivées de `MediaQuery.sizeOf` quand
/// `maxWidth`/`maxHeight` ne sont pas fournis — reproduit l'intention des apps
/// (dialog ~ largeur bornée, sheet ~ 90 % hauteur) **sans** largeur globale.
/// Bornes d'écran par défaut de la présentation adaptative (dp) — **publiques**
/// (audit de consolidation, 2026-07-22).
///
/// Elles étaient privées, et `zcrud_get` les **répliquait** dans un
/// `_ZGetPresenterDefaults` local : deux copies d'une même décision M3, libres
/// de diverger silencieusement au prochain ajustement. Un binding qui implémente
/// le port `ZFormPresenter` doit pouvoir s'aligner sur la source, pas la recopier.
abstract final class ZAdaptivePresenterDefaults {
  /// Largeur max (dp) d'une `dialog` : `min(largeurÉcran, 560)` (M3 medium).
  static const double dialogMaxWidth = 560;

  /// Fraction de la hauteur d'écran allouée par défaut à une bottom-sheet.
  static const double sheetMaxHeightFraction = 0.9;
}

/// Présentateur **par défaut** : exécute chaque [ZEditionPresentation] via une
/// primitive Flutter **vanilla**. `const` (aucun état). Substituable par un
/// binding via le seam `ZFormPresenterScope`.
///
/// | `mode`   | Primitive Flutter                                            |
/// |----------|--------------------------------------------------------------|
/// | `page`   | `Navigator.push(MaterialPageRoute(fullscreenDialog: true))`  |
/// | `sheet`  | `showModalBottomSheet(isScrollControlled: true, ...)`        |
/// | `dialog` | `showDialog(→ Dialog + ConstrainedBox aux tailles max)`      |
class ZAdaptivePresenter implements ZFormPresenter {
  /// Construit le présentateur par défaut. `const` — aucun champ mutable.
  const ZAdaptivePresenter();

  @override
  Future<T?> present<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
  }) {
    // Switch EXHAUSTIF sur les 3 valeurs de l'enum ⇒ jamais de `throw` (AD-10).
    switch (mode) {
      case ZEditionPresentation.page:
        // Route pleine page — tailles max IGNORÉES (la page occupe l'écran).
        return Navigator.of(context).push<T>(
          MaterialPageRoute<T>(
            builder: builder,
            fullscreenDialog: true,
          ),
        );

      case ZEditionPresentation.sheet:
        final screen = MediaQuery.sizeOf(context);
        final effectiveMaxHeight =
            maxHeight ?? screen.height * ZAdaptivePresenterDefaults.sheetMaxHeightFraction;
        return showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: useSafeArea,
          constraints: BoxConstraints(
            maxHeight: effectiveMaxHeight,
            maxWidth: maxWidth ?? double.infinity,
          ),
          builder: builder,
        );

      case ZEditionPresentation.dialog:
        final screen = MediaQuery.sizeOf(context);
        final effectiveMaxWidth = maxWidth ??
            (screen.width < ZAdaptivePresenterDefaults.dialogMaxWidth
                ? screen.width
                : ZAdaptivePresenterDefaults.dialogMaxWidth);
        return showDialog<T>(
          context: context,
          useSafeArea: useSafeArea,
          barrierDismissible: barrierDismissible,
          builder: (ctx) => Dialog(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: effectiveMaxWidth,
                maxHeight: maxHeight ?? double.infinity,
              ),
              child: builder(ctx),
            ),
          ),
        );
    }
  }
}
