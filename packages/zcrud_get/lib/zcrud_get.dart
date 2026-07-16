/// Barrel d'API publique de `zcrud_get`.
///
/// Binding état/injection <-> GetX + get_it (E2-9, AD-15) — cible DODLP (E7).
/// Fournit `ZGetResolver` (seam de résolution via `get_it`/GetX) et
/// `ZcrudGetScope` (scope de binding : création/scoping/dispose du
/// `ZFormController` + enveloppe `ZcrudScope`). Réutilise la réactivité du cœur
/// (`ZFormController`/`ZFieldListenableBuilder`) sans la réimplémenter.
///
/// **Surfaces UI GetX (EX-UI.11, AD-30/AD-32/AD-15)** — implémentations manager
/// des ports UI purs, substituables aux défauts pur-Flutter via leurs seams :
/// * `ZGetFormPresenter` implémente `ZFormPresenter` (de `zcrud_navigation`) :
///   `page → Get.to(fullscreenDialog:)` / `sheet → Get.bottomSheet` / `dialog →
///   Get.dialog`, form-agnostique, `MediaQuery.sizeOf` (jamais `Get.*`) ;
/// * `ZGetToaster` implémente `ZToaster` (de `zcrud_ui_kit`) : `Get.snackbar`
///   mappé sur `ZToastSeverity`, couleur dérivée du `ColorScheme` (jamais hex),
///   icône + texte (couleur jamais seul canal) ;
/// * `ZcrudGetUiScope` monte les 2 seams (`ZFormPresenterScope`/`ZToasterScope`)
///   d'un coup pour un câblage app « une ligne ».
/// Ces impls PROUVENT la pluggabilité des ports (AD-4/NFR-U9) SANS modifier les
/// paquets purs ; tout le code `get` reste CONFINÉ à ce binding (AD-15).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Adaptateur de schéma existant DODLP (E2-6, FR-11, AD-3/AD-6) : `ReflectableCodec`
// (SEULE exception `reflectable` autorisée — chemin allowlisté du gate) + le port
// de réflexion injecté `ZReflectionCapability` / helper `ReflectableMirrorCapability`.
export 'src/data/codecs/reflectable_codec.dart';
export 'src/presentation/z_get_api.dart';
// EX-UI.11 — présentateur GetX (impl du port `ZFormPresenter`, 3 modes).
export 'src/presentation/z_get_form_presenter.dart';
export 'src/presentation/z_get_resolver.dart';
// EX-UI.11 — toaster GetX (impl du port `ZToaster`, `Get.snackbar` × 4 sévérités).
export 'src/presentation/z_get_toaster.dart';
export 'src/presentation/zcrud_get_scope.dart';
// EX-UI.11 — helper montant les 2 seams UI (`ZFormPresenterScope`/`ZToasterScope`).
export 'src/presentation/zcrud_get_ui_scope.dart';
// Binding study GÉNÉRIQUE GetX (ES-11.1, AD-24/R28) — miroir GetX d'ES-10.1 :
// clé de cache à égalité profonde (`ZSessionConfigKey` + `tag`), controller de
// flux `ZStudyWatchController<T>`, factory seam `buildStudyWatchController`,
// factory dédup SM-1 `zPutStudySessionSelector`. Aucune entité concrète.
export 'src/study/z_session_config_key.dart';
export 'src/study/z_study_get.dart';
