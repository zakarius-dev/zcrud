/// Barrel d'API publique de `zcrud_get`.
///
/// Binding état/injection <-> GetX + get_it (invariant AD-15) — cible l'hôte
/// GetX (DODLP). Fournit `ZGetResolver` (seam de résolution via `get_it`/GetX)
/// et `ZcrudGetScope` (scope de binding : création/scoping/dispose du
/// `ZFormController` + enveloppe `ZcrudScope`). Réutilise la réactivité du cœur
/// (`ZFormController`/`ZFieldListenableBuilder`) sans la réimplémenter.
///
/// **Surfaces UI GetX (invariants AD-15/AD-4)** — implémentations manager
/// des ports UI purs, substituables aux défauts pur-Flutter via leurs seams :
/// * `ZGetFormPresenter` implémente `ZFormPresenter` (de `zcrud_navigation`) :
///   `page → Get.to(fullscreenDialog:)` / `sheet → Get.bottomSheet` / `dialog →
///   Get.dialog`, form-agnostique, `MediaQuery.sizeOf` (jamais `Get.*`) ;
/// * `ZGetToaster` implémente `ZToaster` (de `zcrud_ui_kit`) : `Get.snackbar`
///   mappé sur `ZToastSeverity`, couleur dérivée du `ColorScheme` (jamais hex),
///   icône + texte (couleur jamais seul canal) ;
/// * `ZcrudGetUiScope` monte les 2 seams (`ZFormPresenterScope`/`ZToasterScope`)
///   d'un coup pour un câblage app « une ligne ».
/// Ces impls PROUVENT la pluggabilité des ports SANS modifier les paquets
/// purs ; tout le code `get` reste CONFINÉ à ce binding (invariant AD-15).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

// Adaptateur de schéma existant, historiquement DODLP (invariants AD-3/AD-6) :
// `ReflectableCodec` (SEULE exception `reflectable` autorisée — chemin
// allowlisté du gate) + le port de réflexion injecté `ZReflectionCapability` /
// helper `ReflectableMirrorCapability`.
export 'src/data/codecs/reflectable_codec.dart';
// Point de composition unique du registre de widgets : `registerZcrudFormFields`
// câble markdown/intl/geo sur un `ZWidgetRegistry` injecté, avec un seam
// opt-in `additionalRegistrars` (html/media/field_extras).
export 'src/presentation/z_form_fields_composer.dart';
export 'src/presentation/z_get_api.dart';
// Présentateur GetX (impl du port `ZFormPresenter`, 3 modes).
export 'src/presentation/z_get_form_presenter.dart';
export 'src/presentation/z_get_resolver.dart';
// Toaster GetX (impl du port `ZToaster`, `Get.snackbar` × 4 sévérités).
export 'src/presentation/z_get_toaster.dart';
export 'src/presentation/zcrud_get_scope.dart';
// Helper montant les 2 seams UI (`ZFormPresenterScope`/`ZToasterScope`).
export 'src/presentation/zcrud_get_ui_scope.dart';
// Binding study GÉNÉRIQUE GetX (invariant AD-2) : clé de cache à égalité
// profonde (`ZSessionConfigKey` + `tag`), controller de flux
// `ZStudyWatchController<T>`, factory seam `buildStudyWatchController`,
// factory de dédoublonnage `zPutStudySessionSelector`. Aucune entité concrète.
export 'src/study/z_session_config_key.dart';
export 'src/study/z_study_get.dart';
