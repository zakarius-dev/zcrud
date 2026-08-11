/// Barrel d'API publique de `zcrud_navigation`.
///
/// Infrastructure UI de **navigation transverse**. Ce paquet pose le
/// **maillon manquant** — la **politique de présentation
/// dérivée du breakpoint** :
/// * [ZEditionPresentation] : mode d'édition en **enum** (`page`/`sheet`/`dialog`)
///   — remplace les booléens `fullscreenDialog`/`dialog`/`isWebOrDesktop` d'une
///   intégration ad hoc ;
/// * [ZFormWeight] : poids de formulaire en **enum** (`light`/`heavy`), critère qui
///   départage `expanded → dialog|page` ;
/// * [ZPresentationPolicy] : dérive **PUREMENT** (sans `BuildContext`) un
///   [ZEditionPresentation] d'un `ZWindowSizeClass` (fourni par `zcrud_responsive`),
///   **injectable / surchargeable** (jamais figée — invariant AD-6),
///   **non-`sealed`** (invariant AD-4).
///
/// **Dépendances (invariant AD-1)** : ce package **dépend de `zcrud_core` ET
/// `zcrud_responsive`** (arêtes SORTANTES ; `CORE OUT=0` intact ; graphe
/// ACYCLIQUE). Il n'importe **aucun** gestionnaire d'état ni routeur ; la politique
/// est **pur-Dart** (aucun `import 'package:flutter/...'`).
///
/// **Présentation (`lib/src/presentation/`)** — exécution du mode :
/// * [ZFormPresenter] : **port pluggable** (jamais `sealed`, invariant AD-4)
///   qui exécute un [ZEditionPresentation] sur la bonne surface modale,
///   **form-agnostique** ;
/// * [ZAdaptivePresenter] : présentateur **par défaut pur-Flutter** —
///   `Navigator.push(MaterialPageRoute(fullscreenDialog:))` / `showModalBottomSheet`
///   / `showDialog(Dialog + ConstrainedBox)`, **aucun** `get`/`go_router`
///   (invariant AD-2) ;
/// * [ZFormPresenterScope] : **seam local** (`InheritedWidget`) de résolution du
///   présentateur effectif — défaut `const ZAdaptivePresenter()` ; `ZcrudScope`
///   de `zcrud_core` **inchangé** (`CORE OUT=0`, invariant AD-1) ;
/// * [presentEdition] : **helper de câblage** `largeur → breakpoint → politique →
///   mode → surface` (le maillon qu'aucune app ne réalise nativement).
///
/// **Bindings manager** : les présentateurs de binding implémentent **ce même
/// port** [ZFormPresenter], injectés via [ZFormPresenterScope] — c'est le cas
/// de `ZGetFormPresenter` (`zcrud_get`), qui implémente aussi la capacité
/// optionnelle de contrôle des fermetures implicites et la feuille
/// contrainte/encadrée.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/domain/z_edition_presentation.dart';
export 'src/domain/z_form_weight.dart';
export 'src/domain/z_presentation_policy.dart';
export 'src/presentation/present_edition.dart';
export 'src/presentation/z_adaptive_presenter.dart';
export 'src/presentation/z_edition_body_fit.dart';
export 'src/presentation/z_edition_chrome.dart';
export 'src/presentation/z_edition_scaffold.dart';
export 'src/presentation/z_form_presenter.dart';
export 'src/presentation/z_form_presenter_scope.dart';
export 'src/presentation/z_implicit_dismiss_control.dart';
export 'src/presentation/z_sheet_frame.dart';
