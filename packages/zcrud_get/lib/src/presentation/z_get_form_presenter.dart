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
///
/// ## 🔴 Alignement CR-IFFD-SHEET / chrome-presentation-aware (2026-08-09)
///
/// Ce présentateur `implements` **aussi** [ZImplicitDismissControl]. Mesuré
/// avant cet alignement, il ne l'implémentait pas — avec **deux** conséquences
/// silencieuses pour DODLP et IFFD, les deux hôtes GetX :
///
/// | Défaut | Cause mesurée | Effet chez l'hôte GetX |
/// |---|---|---|
/// | fermeture par **glissement** non gardée | `presentEdition` teste `is ZImplicitDismissControl` et **retombe** sur `present` (AD-10) | `enableDrag` reste au défaut GetX (`true`) ⇒ `BottomSheet.onClosing → Navigator.pop` court-circuite `PopScope`/`ZDiscardGuard` : **saisie perdue sans confirmation** |
/// | ni **marge** ni **cadre** | `sheetFrame` n'est porté QUE par `presentWithDismissControl` | feuille pleine largeur, sans bordure |
///
/// Pire pour le second point : la branche `sheet` passait
/// `maxWidth ?? double.infinity` à son `ConstrainedBox`. Ce n'était pas neutre
/// — le `BottomSheet` du SDK résout `widget.constraints ?? theme ?? defaults`
/// (`flutter/lib/src/material/bottom_sheet.dart` l. 351-352), donc le plafond
/// M3 de 640 dp (`_BottomSheetDefaultsM3.constraints`, l. 1489) restait bien
/// actif côté route GetX, mais **aucune** marge n'existait sous ce plafond.
///
/// Les deux trous sont fermés en **consommant** la chaîne partagée de
/// `zcrud_navigation` : `zSheetFrameMetricsOf` résout **paramètre
/// ([ZSheetFrameSpec]) > jetons `ZcrudTheme.editionSheet*` (`zcrud_core`) >
/// [ZSheetFrameReference]**. (Le maillon intermédiaire fut brièvement une
/// `ThemeExtension` locale à `zcrud_navigation` ; elle a été **supprimée** le
/// 2026-08-09 au profit du canal de thème unique du dépôt — le mode y transite
/// désormais en `String?`, converti par `zSheetFrameModeFromToken`, qui rend
/// `null` sur une valeur inconnue et laisse la référence décider, sans lever.)
/// **Aucune valeur n'est recopiée ici** : ni le ratio 0,9, ni le plafond 640,
/// ni une épaisseur, ni une couleur. La garde de source
/// `z_get_form_presenter_source_guard_test.dart` (exemption **zéro**) le tient.
///
/// ### Divergence RÉSIDUELLE, mesurée et assumée : le plafond dur de GetX
///
/// `Get.bottomSheet` **n'expose pas** `constraints` (get 4.7.2,
/// `extension_navigation.dart` l. 19-36) et `GetModalBottomSheetRoute` ne le
/// transmet pas davantage. Notre `ConstrainedBox` ne peut donc que **rétrécir**
/// la feuille, jamais l'élargir au-delà de ce que le `BottomSheet` résout
/// lui-même. Conséquence : l'échappatoire « pleine largeur »
/// (`ZSheetFrameSpec(widthRatio: 1, maxWidth: double.infinity)`) rend bien la
/// pleine largeur **sous 640 dp**, mais reste plafonnée à 640 dp au-delà —
/// là où `ZAdaptivePresenter` rendrait 1600. L'hôte GetX qui veut vraiment
/// dépasser 640 doit le dire à son thème
/// (`BottomSheetThemeData(constraints: …)`), seul canal que GetX laisse
/// passer. Épinglé par le volet `GS-9` de `z_get_sheet_frame_test.dart`.
///
/// ### `unlessChrome` n'est PAS résolu ici
///
/// `hasChrome: false` est passé en dur à [zSheetFrameMetricsOf] — exactement
/// comme dans `ZAdaptivePresenter`. La collapse de
/// `ZSheetFrameMode.unlessChrome` appartient à `presentEdition`, seul endroit
/// qui **sait** si l'appelant a déclaré un chrome. Le présentateur ne reçoit
/// donc que `always`/`never`, et **n'inspecte jamais** le contenu : l'heuristique
/// `runtimeType.toString().endsWith("EditionScreen")` d'IFFD reste écartée.
///
/// ## 🔴 « Surface avec le cadre » — le fond effacé par GetX est RÉTABLI
///
/// Mesuré dans `get 4.7.2` : `Get.bottomSheet` **force** le fond,
/// `backgroundColor: backgroundColor ?? Colors.transparent`
/// (`extension_navigation.dart` l. 46). Comme la valeur remise à la route n'est
/// alors **jamais `null`**, `GetModalBottomSheetRoute.buildPage` court-circuite
/// sa propre chaîne `?? sheetTheme.modalBackgroundColor ?? sheetTheme.backgroundColor`
/// (`bottomsheet.dart` l. 89-91) : le `BottomSheetThemeData` de l'hôte **ne sert
/// à rien**, et la feuille est transparente. Divergence franche avec
/// `showModalBottomSheet`, qui résout
/// `backgroundColor ?? modalBackgroundColor ?? backgroundColor ?? defaults`
/// (`bottom_sheet.dart` l. 1145-1149) avec, en M3,
/// `_BottomSheetDefaultsM3.backgroundColor => ColorScheme.surfaceContainerLow`
/// (l. 1496) — et, en M2 (`useMaterial3: false`), `defaults` vide (l. 1139-1141)
/// donc `Material(color: null)`, c'est-à-dire `ThemeData.canvasColor`.
///
/// C'est très probablement pourquoi IFFD enveloppe son contenu dans un
/// `Card.outlined` (`forms_utils.dart` ~l. 690-712, **vérifié**) : la carte n'y
/// apporte pas seulement la bordure, elle apporte **la surface** que GetX venait
/// d'effacer. Sans elle, le cadre livré par CR-IFFD-SHEET se peindrait comme un
/// **contour flottant sur la barrière**, sans fond.
///
/// **Décision propriétaire — « surface avec le cadre »** :
///
/// | Cas | Fond remis à `Get.bottomSheet` |
/// |---|---|
/// | [sheetBackgroundColor] fourni | ce fond — il **prime sur tout** |
/// | cadre **peint** (`frame.framed`) | [_themeSheetSurface] : la résolution du SDK, **reproduite** |
/// | cadre **désactivé** | `null` ⇒ GetX applique `Colors.transparent` : **comportement d'aujourd'hui strictement conservé** |
///
/// Le troisième cas EST l'échappatoire : un hôte qui veut le rendu d'avant
/// coupe le cadre (`ZSheetFrameSpec(mode: never)` ou
/// `ZcrudTheme(editionSheetFrameMode: ZSheetFrameMode.never.name)`) et retrouve
/// exactement la feuille transparente de GetX.
///
/// 🔴 **FR-26** : [_themeSheetSurface] n'invente **aucune** teinte — elle lit
/// d'abord le `BottomSheetThemeData` de l'hôte, et son dernier maillon est un
/// **rôle** du `ColorScheme` (ou `canvasColor`), jamais un littéral. La garde de
/// source `GSG-2` interdit `Color(`/`Colors.` dans ce fichier.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:zcrud_navigation/zcrud_navigation.dart';

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
class ZGetFormPresenter implements ZFormPresenter, ZImplicitDismissControl {
  /// Construit le présentateur GetX. `const` — aucun champ mutable.
  ///
  /// [sheetBackgroundColor] est l'échappatoire **la plus haute** sur le fond de
  /// la bottom-sheet (cf. l'en-tête, « surface avec le cadre ») : quand il est
  /// fourni, il prime sur le `BottomSheetThemeData` de l'hôte comme sur le rôle
  /// de repli, **et** dans les deux états du cadre. `null` (défaut) ⇒ la chaîne
  /// décide.
  const ZGetFormPresenter({this.sheetBackgroundColor});

  /// Fond **explicite** de la bottom-sheet, ou `null` ⇒ « je ne me prononce
  /// pas » (AD-4 : `null` = absent, jamais une valeur déguisée).
  ///
  /// C'est la transposition, à l'échelle du présentateur, du paramètre
  /// `backgroundColor` que `Get.bottomSheet` accepte mais que le port
  /// `ZFormPresenter` n'expose pas.
  final Color? sheetBackgroundColor;

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
      // Voie HISTORIQUE : délègue avec `allowImplicitDismiss: true`, le défaut
      // de `Get.bottomSheet(enableDrag:)` — donc arbre et paramètres
      // INCHANGÉS pour tout appelant qui passait déjà par `present`.
      // (Même transposition que `ZAdaptivePresenter.present`.)
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
    ZSheetFrameSpec? sheetFrame,
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
            screen.height * ZAdaptivePresenterDefaults.sheetMaxHeightFraction;
        // ── Feuille CONTRAINTE et ENCADRÉE : chaîne PARTAGÉE, zéro recopie ──
        //
        // `hasChrome: false` — la collapse de `unlessChrome` est faite en amont
        // par `presentEdition` (seul endroit qui SAIT ; cf. l'en-tête).
        final ZSheetFrameMetrics frame =
            zSheetFrameMetricsOf(context, spec: sheetFrame, hasChrome: false);
        // `maxWidth` explicite (paramètre de `present`) reste PRIORITAIRE : il
        // était déjà la surcharge la plus haute avant l'alignement.
        final double effectiveMaxWidth =
            maxWidth ?? frame.effectiveMaxWidth(screen.width);
        return Get.bottomSheet<T>(
          _constrained(
            builder,
            maxWidth: effectiveMaxWidth,
            maxHeight: effectiveMaxHeight,
            useSafeArea: useSafeArea,
          ),
          isScrollControlled: true,
          // 🔴 La fermeture par GLISSEMENT passe par `Navigator.pop` et
          // COURT-CIRCUITE `PopScope` (donc `ZDiscardGuard`). Quand un garde
          // d'abandon est armé, la voie est désactivée ; sinon `true`, qui est
          // le défaut de `Get.bottomSheet` ⇒ voie historique inchangée. La
          // barrière, elle, RESTE fermante (`isDismissible` non touché) : elle
          // passe par `maybePop`, donc par le garde.
          enableDrag: allowImplicitDismiss,
          // ── SURFACE : « surface avec le cadre » (cf. l'en-tête) ──
          //
          // `Get.bottomSheet` applique `?? Colors.transparent` à ce qu'on lui
          // remet. Donc :
          // * fond explicite ⇒ il PRIME (et GetX le transmet tel quel) ;
          // * cadre peint ⇒ on REPRODUIT la résolution du SDK, sinon le cadre
          //   flotterait sur la barrière, sans surface ;
          // * cadre désactivé ⇒ `null` ⇒ `Colors.transparent`, exactement le
          //   comportement GetX d'aujourd'hui. C'est l'échappatoire.
          backgroundColor: sheetBackgroundColor ??
              (frame.framed ? _themeSheetSurface(context) : null),
          // `null` quand le cadre est désactivé ⇒ AUCUNE `shape` imposée : le
          // `BottomSheet` du SDK retrouve sa résolution native
          // (`thème > défauts M3`), AD-4 — `null` ⇒ absent de l'arbre.
          shape: frame.resolveShape(Theme.of(context).bottomSheetTheme.shape),
        );

      case ZEditionPresentation.dialog:
        final screen = MediaQuery.sizeOf(context);
        final effectiveMaxWidth = maxWidth ??
            (screen.width < ZAdaptivePresenterDefaults.dialogMaxWidth
                ? screen.width
                : ZAdaptivePresenterDefaults.dialogMaxWidth);
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

  /// Le fond qu'une feuille **modale** du SDK Material résoudrait ici —
  /// reproduction **fidèle**, pas une invention.
  ///
  /// Ordre repris à l'identique de
  /// `flutter/lib/src/material/bottom_sheet.dart`,
  /// `_ModalBottomSheetRoute.buildPage` (l. 1145-1149) :
  ///
  /// ```
  /// backgroundColor            ← ici : le paramètre d'appel, traité en amont
  ///   ?? modalBackgroundColor  ← le canal MODAL du thème de l'hôte
  ///   ?? backgroundColor       ← le canal commun du thème de l'hôte
  ///   ?? defaults.backgroundColor
  /// ```
  ///
  /// Dernier maillon, lui aussi lu dans le SDK :
  /// * **M3** — `_BottomSheetDefaultsM3.backgroundColor` (l. 1496) est le
  ///   **rôle** `ColorScheme.surfaceContainerLow` ;
  /// * **M2** (`useMaterial3: false`) — `defaults` est un `BottomSheetThemeData`
  ///   vide (l. 1139-1141), le `BottomSheet` remet donc `null` à son `Material`,
  ///   dont la couleur de repli est `ThemeData.canvasColor`.
  ///
  /// 🔴 FR-26 : deux **rôles** du thème de l'hôte, zéro littéral. La teinte
  /// suit le thème (clair/sombre, `seedColor`) sans que ce paquet n'en impose
  /// aucune. AD-10 : aucun chemin d'exception, le repli est total.
  Color _themeSheetSurface(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final BottomSheetThemeData sheetTheme = theme.bottomSheetTheme;
    return sheetTheme.modalBackgroundColor ??
        sheetTheme.backgroundColor ??
        (theme.useMaterial3
            ? theme.colorScheme.surfaceContainerLow
            : theme.canvasColor);
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
