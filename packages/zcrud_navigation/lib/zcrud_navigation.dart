/// Barrel d'API publique de `zcrud_navigation`.
///
/// Infrastructure UI de **navigation transverse** (epic EX-UI). Cette tête P2
/// (EX-UI.5) pose le **maillon manquant AD-30** — la **politique de présentation
/// dérivée du breakpoint** :
/// * [ZEditionPresentation] : mode d'édition en **enum** (`page`/`sheet`/`dialog`)
///   — remplace les booléens `fullscreenDialog`/`dialog`/`isWebOrDesktop` des apps
///   (NFR-U7) ;
/// * [ZFormWeight] : poids de formulaire en **enum** (`light`/`heavy`), critère qui
///   départage `expanded → dialog|page` ;
/// * [ZPresentationPolicy] : dérive **PUREMENT** (sans `BuildContext`) un
///   [ZEditionPresentation] d'un `ZWindowSizeClass` (fourni par `zcrud_responsive`,
///   EX-UI.1), **injectable / surchargeable** (jamais figée — AD-30/AD-6),
///   **non-`sealed`** (AD-4).
///
/// **Dépendances (AD-1)** : ce package **dépend de `zcrud_core` ET
/// `zcrud_responsive`** (arêtes SORTANTES ; `CORE OUT=0` intact ; graphe
/// ACYCLIQUE). Il n'importe **aucun** gestionnaire d'état ni routeur ; la politique
/// est **pur-Dart** (aucun `import 'package:flutter/...'`).
///
/// **Présentation (EX-UI.6, `lib/src/presentation/`)** — exécution du mode :
/// * [ZFormPresenter] : **port pluggable** (jamais `sealed`, AD-4) qui exécute un
///   [ZEditionPresentation] sur la bonne surface modale, **form-agnostique** ;
/// * [ZAdaptivePresenter] : présentateur **par défaut pur-Flutter** —
///   `Navigator.push(MaterialPageRoute(fullscreenDialog:))` / `showModalBottomSheet`
///   / `showDialog(Dialog + ConstrainedBox)`, **aucun** `get`/`go_router` (AD-30/
///   AD-2) ;
/// * [ZFormPresenterScope] : **seam local** (`InheritedWidget`) de résolution du
///   présentateur effectif — défaut `const ZAdaptivePresenter()` ; `ZcrudScope`
///   de `zcrud_core` **inchangé** (`CORE OUT=0`, D8/AD-1) ;
/// * [presentEdition] : **helper de câblage** `largeur → breakpoint → politique →
///   mode → surface` (le maillon qu'aucune app ne réalise, AD-30).
///
/// **Bindings manager (hors périmètre → EX-UI.11)** : les présentateurs GetX
/// (`zcrud_get`) / go_router (`zcrud_riverpod`) implémenteront **ce même port**
/// [ZFormPresenter], injectés via [ZFormPresenterScope].
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/domain/z_edition_presentation.dart';
export 'src/domain/z_form_weight.dart';
export 'src/domain/z_presentation_policy.dart';
export 'src/presentation/present_edition.dart';
export 'src/presentation/z_adaptive_presenter.dart';
export 'src/presentation/z_form_presenter.dart';
export 'src/presentation/z_form_presenter_scope.dart';
