/// Présentateur **GetX** (invariants AD-30/AD-15) — implémentation manager du
/// port [ZFormPresenter] de `zcrud_navigation`.
///
/// [ZGetFormPresenter] **transpose** le présentateur par défaut pur-Flutter
/// `ZAdaptivePresenter` à l'idiome GetX : les trois modes [ZEditionPresentation]
/// deviennent `Get.to(fullscreenDialog:)` / `Get.bottomSheet` / `Get.dialog`.
/// Par rapport à une intégration GetX ad hoc typique, cette implémentation :
/// * remplace les booléens ad hoc `fullscreenDialog`/`dialog` par l'`enum`
///   [ZEditionPresentation] ;
/// * lit **`MediaQuery.sizeOf(context)`** plutôt que `Get.height`/`Get.width`
///   (le port reçoit le [BuildContext]) — jamais
///   `Get.width`/`Get.height`/`Get.context!` ;
/// * reste **form-agnostique** : le [WidgetBuilder] est opaque, jamais
///   inspecté par son type concret ;
/// * ne code en dur aucune couleur de barrière (défaut GetX / thème ;
///   invariant AD-13).
///
/// **`get` confiné ici (invariant AD-15)** : ce fichier importe
/// `package:get/get.dart` — c'est légitime UNIQUEMENT dans le binding
/// `zcrud_get`. `zcrud_navigation` (qui définit le port) n'importe **NI**
/// `get` **NI** `go_router`. La substitution au défaut passe par le seam
/// **déjà fourni** `ZFormPresenterScope` (aucun nouveau seam) :
/// `ZFormPresenterScope(presenter: const ZGetFormPresenter(), child: …)`.
///
/// **Bornes alignées sur `ZAdaptivePresenter`** (documentées, non hex) : dialog
/// ≤ 560 dp (M3 medium), sheet ≤ 90 % de la hauteur d'écran — mesurées via
/// `MediaQuery.sizeOf(context)`, pas via une largeur globale.
///
/// ## Contrôle explicite du rejet implicite
///
/// Ce présentateur `implements` **aussi** [ZImplicitDismissControl], pour
/// deux raisons mesurées côté hôtes GetX :
///
/// | Sans ce contrôle | Cause | Effet |
/// |---|---|---|
/// | fermeture par **glissement** non gardée | `presentEdition` teste `is ZImplicitDismissControl` et **retombe** sur `present` (invariant AD-10) | `enableDrag` resterait au défaut GetX (`true`) ⇒ `BottomSheet.onClosing → Navigator.pop` court-circuiterait `PopScope`/`ZDiscardGuard` : saisie perdue sans confirmation |
/// | ni **marge** ni **cadre** | `sheetFrame` n'est porté QUE par `presentWithDismissControl` | feuille pleine largeur, sans bordure |
///
/// Sur le second point, une largeur maximale non contrainte
/// (`maxWidth ?? double.infinity`) n'est pas neutre : le `BottomSheet` du SDK
/// résout `widget.constraints ?? theme ?? defaults`, donc le plafond M3 de
/// 640 dp reste actif côté route GetX même sans marge déclarée en dessous.
///
/// Les deux trous sont fermés en **consommant** la chaîne partagée de
/// `zcrud_navigation` : `zSheetFrameMetricsOf` résout **paramètre
/// ([ZSheetFrameSpec]) > jetons `ZcrudTheme.editionSheet*` (`zcrud_core`) >
/// [ZSheetFrameReference]**, le mode transitant en `String?` converti par
/// `zSheetFrameModeFromToken` (`null` sur une valeur inconnue, sans lever).
/// **Aucune valeur n'est recopiée ici** : ni le ratio 0,9, ni le plafond 640,
/// ni une épaisseur, ni une couleur. Une garde de source dédiée le vérifie.
///
/// ### Divergence résiduelle, assumée : le plafond dur de GetX
///
/// `Get.bottomSheet` n'expose pas de paramètre `constraints` et
/// `GetModalBottomSheetRoute` ne le transmet pas davantage. Le
/// `ConstrainedBox` posé ici ne peut donc que **rétrécir** la feuille, jamais
/// l'élargir au-delà de ce que le `BottomSheet` résout lui-même. Conséquence :
/// l'échappatoire « pleine largeur »
/// (`ZSheetFrameSpec(widthRatio: 1, maxWidth: double.infinity)`) rend bien la
/// pleine largeur **sous 640 dp**, mais reste plafonnée à 640 dp au-delà —
/// là où `ZAdaptivePresenter` rendrait la largeur d'écran réelle. L'hôte GetX
/// qui veut vraiment dépasser 640 doit le dire à son thème
/// (`BottomSheetThemeData(constraints: …)`), seul canal que GetX laisse
/// passer.
///
/// ### `unlessChrome` n'est PAS résolu ici
///
/// `hasChrome: false` est passé en dur à [zSheetFrameMetricsOf] — exactement
/// comme dans `ZAdaptivePresenter`. La collapse de
/// `ZSheetFrameMode.unlessChrome` appartient à `presentEdition`, seul endroit
/// qui **sait** si l'appelant a déclaré un chrome. Le présentateur ne reçoit
/// donc que `always`/`never`, et **n'inspecte jamais** le contenu par
/// heuristique de type.
///
/// ## « Surface avec le cadre » — le fond effacé par GetX est rétabli
///
/// `Get.bottomSheet` **force** le fond
/// (`backgroundColor: backgroundColor ?? Colors.transparent`). Comme la
/// valeur remise à la route n'est alors **jamais `null`**,
/// `GetModalBottomSheetRoute.buildPage` court-circuite sa propre chaîne de
/// résolution : le `BottomSheetThemeData` de l'hôte ne sert à rien, et la
/// feuille est transparente. Divergence franche avec `showModalBottomSheet`,
/// qui résout `backgroundColor ?? modalBackgroundColor ?? backgroundColor ??
/// defaults`, avec en M3 `_BottomSheetDefaultsM3.backgroundColor =>
/// ColorScheme.surfaceContainerLow`, et en M2 le repli `ThemeData.canvasColor`.
///
/// Un hôte qui veut peindre un cadre autour de sa feuille a donc besoin d'une
/// **surface** en plus de la bordure, sans quoi le cadre flotterait sur la
/// barrière, sans fond.
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
/// [_themeSheetSurface] n'invente **aucune** teinte — elle lit
/// d'abord le `BottomSheetThemeData` de l'hôte, et son dernier maillon est un
/// **rôle** du `ColorScheme` (ou `canvasColor`), jamais un littéral. Une garde
/// de source interdit `Color(`/`Colors.` dans ce fichier.
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
    bool isDismissible = true,
    ZSheetFrameSpec? sheetFrame,
  }) {
    // Switch EXHAUSTIF sur les 3 valeurs de l'enum ⇒ jamais de `throw` (AD-10).
    switch (mode) {
      case ZEditionPresentation.page:
        // Route pleine page — tailles max IGNORÉES (la page occupe l'écran),
        // `useSafeArea` IGNORÉ (aucune `SafeArea` n'est insérée, ni avec `true`
        // ni avec `false`), `barrierDismissible` /
        // `isDismissible` / `allowImplicitDismiss` / `sheetFrame` sans objet.
        // Mêmes inerties que `ZAdaptivePresenter`, et DÉCLARÉES au port. `Get.to` renvoie `Future<T?>?` (nullable
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
          // La fermeture par GLISSEMENT passe par `Navigator.pop` et
          // COURT-CIRCUITE `PopScope` (donc `ZDiscardGuard`). Quand un garde
          // d'abandon est armé, la voie est désactivée ; sinon `true`, qui est
          // le défaut de `Get.bottomSheet` ⇒ voie historique inchangée. La
          // barrière, elle, RESTE fermante (`isDismissible` non touché) : elle
          // passe par `maybePop`, donc par le garde.
          enableDrag: allowImplicitDismiss,
          // Voie ORTHOGONALE au glissement : GetX transmet
          // `isDismissible` à `GetModalBottomSheetRoute`, dont
          // `barrierDismissible` en dérive (get 4.7.x,
          // `extension_navigation.dart` l. 52 ; `bottomsheet.dart`). `false` ⇒
          // le tap sur la barrière ne déclenche même plus `maybePop`, donc le
          // garde d'abandon n'est PAS consulté : « interdire » le renoncement,
          // là où `allowImplicitDismiss: false` dit « garder ». `true` (défaut
          // GetX et défaut du port) ⇒ comportement d'aujourd'hui INCHANGÉ.
          isDismissible: isDismissible,
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
          // (`thème > défauts M3`), invariant AD-4 — `null` ⇒ absent de l'arbre.
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
          // Un paramètre peut être lu par le code (`_constrained` reçoit bien
          // `useSafeArea` et pose bien sa `SafeArea`) et rester pourtant
          // **inerte** en pratique : `Get.dialog` porte SON PROPRE
          // `useSafeArea`, à `true` par défaut, et enveloppe la page dans une
          // `SafeArea` **en amont**. L'encart est donc déjà consommé quand la
          // `SafeArea` interne s'applique : `useSafeArea: false` rendrait
          // exactement le même arbre que `true`, sans avertissement — une
          // divergence franche avec `ZAdaptivePresenter`, où `showDialog`
          // honore réellement ce paramètre.
          //
          // Défaut INCHANGÉ pour tout hôte passif : `true` ⇒ la `SafeArea` de
          // GetX est posée comme hier, et la `SafeArea` interne reste au même
          // endroit de l'arbre. Seul l'opt-out `false` change — il devient
          // effectif au lieu d'être silencieusement ignoré.
          useSafeArea: useSafeArea,
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
  /// Deux **rôles** du thème de l'hôte, zéro littéral. La teinte
  /// suit le thème (clair/sombre, `seedColor`) sans que ce paquet n'en impose
  /// aucune. Invariant AD-10 : aucun chemin d'exception, le repli est total.
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
