/// Présentateur **GetX** (EX-UI.11, AD-30/AD-15) — implémentation manager du
/// port [ZFormPresenter] de `zcrud_navigation`.
///
/// [ZGetFormPresenter] **transpose** le présentateur par défaut pur-Flutter
/// `ZAdaptivePresenter` à l'idiome GetX : les trois modes [ZEditionPresentation]
/// deviennent `Get.to(fullscreenDialog:)` / `Get.bottomSheet` / `Get.dialog`.
/// C'est la réécriture **neutralisée** du `showPushedDialog<T>` des apps GetX
/// historiques (dodlp/iffd `forms_utils.dart`) :
/// * les booléens ad hoc `fullscreenDialog`/`dialog` → l'`enum`
///   [ZEditionPresentation] (NFR-U7) ;
/// * `Get.height`/`Get.width` → **`MediaQuery.sizeOf(context)`** (le port reçoit
///   le [BuildContext]) — ⛔ jamais `Get.width`/`Get.height`/`Get.context!` ;
/// * l'heuristique `builder is DynamicEditionScreen` → **supprimée** : le port
///   est **form-agnostique**, le [WidgetBuilder] est opaque (jamais inspecté) ;
/// * `barrierColor: Colors.black…` en dur → **supprimé** (défaut GetX / thème ;
///   aucun littéral hex introduit — AD-13).
///
/// **`get` confiné ici (AD-15/NFR-U2)** : ce fichier importe `package:get/get.dart`
/// — c'est légitime UNIQUEMENT dans le binding `zcrud_get`. `zcrud_navigation`
/// (qui définit le port) n'importe **NI** `get` **NI** `go_router`. La
/// substitution au défaut passe par le seam **déjà fourni** `ZFormPresenterScope`
/// (aucun nouveau seam) : `ZFormPresenterScope(presenter: const ZGetFormPresenter(), child: …)`.
///
/// **Bornes alignées sur `ZAdaptivePresenter`** (documentées, non hex) : dialog
/// ≤ 560 dp (M3 medium), sheet ≤ 90 % de la hauteur d'écran — mesurées via
/// `MediaQuery.sizeOf(context)`, pas via une largeur globale.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

/// Fractions/bornes d'écran par défaut (dp) — **répliquent** l'intention de
/// `ZAdaptivePresenter` (`_ZAdaptiveDefaults`) quand `maxWidth`/`maxHeight` ne
/// sont pas fournis. Aucun littéral de couleur : uniquement des tailles.
abstract final class _ZGetPresenterDefaults {
  /// Largeur max (dp) d'une `dialog` : `min(largeurÉcran, 560)` (M3 medium).
  static const double dialogMaxWidth = 560;

  /// Fraction de la hauteur d'écran allouée par défaut à une bottom-sheet.
  static const double sheetMaxHeightFraction = 0.9;
}

/// Présentateur **GetX** : exécute chaque [ZEditionPresentation] via une
/// primitive GetX. `const` (aucun état — un port de présentation ne conserve
/// aucune référence manager en champ, il reçoit le [BuildContext] à l'appel).
/// Substituable au défaut `ZAdaptivePresenter` via le seam [ZFormPresenterScope].
///
/// | `mode`   | Primitive GetX                                              |
/// |----------|-------------------------------------------------------------|
/// | `page`   | `Get.to<T>(() => …, fullscreenDialog: true)`                |
/// | `sheet`  | `Get.bottomSheet<T>(…, isScrollControlled: true)`           |
/// | `dialog` | `Get.dialog<T>(Dialog + ConstrainedBox, barrierDismissible:)` |
class ZGetFormPresenter implements ZFormPresenter {
  /// Construit le présentateur GetX. `const` — aucun champ mutable.
  const ZGetFormPresenter();

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
        // Route pleine page — tailles max IGNORÉES (la page occupe l'écran),
        // comme `ZAdaptivePresenter`. `Get.to` renvoie `Future<T?>?` (nullable
        // si la navigation est refusée) : on garantit le contrat `Future<T?>`
        // du port par un repli `Future<T?>.value()` (défaut sûr, jamais null).
        return Get.to<T>(
              () => Builder(builder: builder),
              fullscreenDialog: true,
            ) ??
            Future<T?>.value();

      case ZEditionPresentation.sheet:
        final screen = MediaQuery.sizeOf(context); // ⛔ jamais Get.height/width
        final effectiveMaxHeight = maxHeight ??
            screen.height * _ZGetPresenterDefaults.sheetMaxHeightFraction;
        return Get.bottomSheet<T>(
          _constrained(
            builder,
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: effectiveMaxHeight,
            useSafeArea: useSafeArea,
          ),
          isScrollControlled: true,
        );

      case ZEditionPresentation.dialog:
        final screen = MediaQuery.sizeOf(context);
        final effectiveMaxWidth = maxWidth ??
            (screen.width < _ZGetPresenterDefaults.dialogMaxWidth
                ? screen.width
                : _ZGetPresenterDefaults.dialogMaxWidth);
        return Get.dialog<T>(
          Dialog(
            child: _constrained(
              builder,
              maxWidth: effectiveMaxWidth,
              maxHeight: maxHeight ?? double.infinity,
              useSafeArea: useSafeArea,
            ),
          ),
          barrierDismissible: barrierDismissible,
        );
    }
  }

  /// Enveloppe le [builder] **opaque** dans un `Builder` (fournit un
  /// [BuildContext] frais et honore la signature [WidgetBuilder] **sans
  /// inspecter** le contenu — form-agnostique) borné par un `ConstrainedBox`
  /// (bornes alignées sur `ZAdaptivePresenter`) et, si [useSafeArea], une
  /// `SafeArea` (a11y). Aucune couleur, aucun `runtimeType`.
  Widget _constrained(
    WidgetBuilder builder, {
    required double maxWidth,
    required double maxHeight,
    required bool useSafeArea,
  }) {
    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
      child: Builder(builder: builder),
    );
    return useSafeArea ? SafeArea(child: content) : content;
  }
}
