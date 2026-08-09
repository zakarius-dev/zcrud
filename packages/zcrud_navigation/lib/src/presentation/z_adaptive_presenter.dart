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
import 'z_implicit_dismiss_control.dart';
import 'z_sheet_frame.dart';

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
class ZAdaptivePresenter implements ZFormPresenter, ZImplicitDismissControl {
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
  }) =>
      // Voie HISTORIQUE : délègue avec `allowImplicitDismiss: true`, qui rend
      // l'arbre et les paramètres EXACTEMENT d'avant (`enableDrag` laissé à
      // `null` ⇒ défaut SDK). Garde d'identité d'arbre : cf.
      // `z_edition_chrome_identity_test.dart`.
      presentWithDismissControl<T>(
        context,
        builder: builder,
        mode: mode,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        useSafeArea: useSafeArea,
        barrierDismissible: barrierDismissible,
      );

  @override
  Future<T?> presentWithDismissControl<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    required ZEditionPresentation mode,
    double? maxWidth,
    double? maxHeight,
    bool useSafeArea = true,
    bool barrierDismissible = true,
    bool allowImplicitDismiss = true,
    bool isDismissible = true,
    ZSheetFrameSpec? sheetFrame,
  }) {
    // Switch EXHAUSTIF sur les 3 valeurs de l'enum ⇒ jamais de `throw` (AD-10).
    switch (mode) {
      case ZEditionPresentation.page:
        // Route pleine page — tailles max IGNORÉES (la page occupe l'écran),
        // `useSafeArea` IGNORÉ (aucune `SafeArea` n'est insérée, ni avec `true`
        // ni avec `false` — mesuré, CR-IFFD-78 ①), `barrierDismissible` et
        // `isDismissible` sans objet (une route pleine n'a pas de barrière),
        // `allowImplicitDismiss` et `sheetFrame` sans objet. Ces inerties sont
        // DÉCLARÉES au port et MESURÉES par la matrice de paramètres.
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
        // ── Feuille CONTRAINTE et ENCADRÉE (CR-IFFD-SHEET, 2026-08-09) ──────
        //
        // 🔴 Changement VISIBLE pour tout hôte passif, assumé : le défaut du
        // socle est désormais une feuille plus étroite que l'écran, avec un
        // cadre. Un hôte qui veut l'ancien rendu le dit explicitement :
        // `sheetFrame: ZSheetFrameSpec(mode: ZSheetFrameMode.never)` (cadre) et
        // `sheetFrame: ZSheetFrameSpec(widthRatio: 1, maxWidth: double.infinity)`
        // (pleine largeur) — les deux réglages sont INDÉPENDANTS.
        //
        // `hasChrome: false` : ce presenter ne voit que le builder final ; la
        // collapse de `unlessChrome` est faite en amont par `presentEdition`,
        // seul endroit qui SAIT si un chrome a été déclaré.
        final ZSheetFrameMetrics frame =
            zSheetFrameMetricsOf(context, spec: sheetFrame, hasChrome: false);
        // `maxWidth` explicite (paramètre de `present`) reste PRIORITAIRE : il
        // était déjà la surcharge la plus haute avant la CR.
        final double effectiveMaxWidth =
            maxWidth ?? frame.effectiveMaxWidth(screen.width);
        return showModalBottomSheet<T>(
          context: context,
          isScrollControlled: true,
          useSafeArea: useSafeArea,
          // 🔴 La fermeture par GLISSEMENT passe par `Navigator.pop` et
          // COURT-CIRCUITE `PopScope` (donc `ZDiscardGuard`) — mesuré sur
          // Flutter 3.44.4. Quand un garde d'abandon est armé, la voie est
          // désactivée ; sinon `null` ⇒ défaut SDK, arbre INCHANGÉ.
          // (`true` est le défaut du SDK ⇒ voie historique inchangée.)
          enableDrag: allowImplicitDismiss,
          // 🔴 Voie ORTHOGONALE au glissement : `isDismissible` alimente
          // `ModalBottomSheetRoute.barrierDismissible` (SDK,
          // `bottom_sheet.dart` l. 1103). `false` ⇒ le tap sur la barrière ne
          // déclenche même plus `maybePop`, donc le garde d'abandon n'est PAS
          // consulté — c'est « interdire », là où `allowImplicitDismiss: false`
          // dit « garder ». `true` (défaut SDK et défaut du port) ⇒ arbre et
          // comportement INCHANGÉS pour tout hôte passif.
          isDismissible: isDismissible,
          // `null` quand le cadre est désactivé ⇒ AUCUNE `shape` imposée, donc
          // la résolution native du SDK (`thème > défauts M3`) est retrouvée
          // telle quelle (AD-4 : `null` ⇒ absent de l'arbre).
          shape: frame.resolveShape(Theme.of(context).bottomSheetTheme.shape),
          constraints: BoxConstraints(
            maxHeight: effectiveMaxHeight,
            maxWidth: effectiveMaxWidth,
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
