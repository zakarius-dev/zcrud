/// Barrel d'API publique de `zcrud_ui_kit`.
///
/// Kit de widgets UI **transverses** (epic EX-UI, AD-32) — patterns génériques
/// factorisés à partir des applications (dodlp, iffd) :
/// * [ZContentState] (EX-UI.7) : l'état d'un contenu asynchrone en **enum**
///   (`idle`/`loading`/`empty`/`error`/`success`) — remplace les combinaisons de
///   `bool` (`isLoading`/`hasError`/`isEmpty`, NFR-U7) ;
/// * [ZEmptyState] / [ZLoadingState] / [ZErrorState] (EX-UI.7) : widgets d'état
///   `const`, thème/couleurs **dérivés** du `ColorScheme` (jamais de hex), textes
///   injectés (l10n), `Semantics`, cibles ≥ 48 dp, directionnels (RTL-safe) ;
/// * [ZContentStateView] (EX-UI.7) : aiguilleur `switch` exhaustif de l'enum vers
///   le bon widget, avec replis sûrs (jamais de throw — AD-10) ;
/// * [ZConfirmTone] (EX-UI.7) : tonalité de confirmation en **enum**
///   (`neutral`/`destructive`) — remplace un `bool isDestructive` ;
/// * [ZConfirmDialog] + [showZConfirmDialog] (EX-UI.7) : dialog de confirmation
///   dark-mode-aware (couleurs dérivées du `ColorScheme`, labels via
///   `MaterialLocalizations`), retournant `Future<bool>`, **sans** gestionnaire
///   d'état (`showDialog` + `Navigator.pop`).
///
/// EX-UI.8 ajoute la **notification (toast) par PORT** (AD-32) :
/// * [ZToastSeverity] (EX-UI.8) : sévérité d'un toast en **enum**
///   (`info`/`success`/`warning`/`error`) — remplace un `bool isError` ou un
///   `String` libre, et les méthodes ad hoc `showError`/`showSuccess`/`showInfo`
///   (NFR-U7) ;
/// * [ZToaster] (EX-UI.8) : **port** de notification `abstract interface class`
///   (jamais `sealed`, AD-4) — les impls concrètes (GetX/`toastification`)
///   vivent dans les bindings/app ;
/// * [ZScaffoldMessengerToaster] (EX-UI.8) : impl **par défaut** pur-Flutter
///   (`ScaffoldMessenger.showSnackBar`), couleur **dérivée** du `ColorScheme`
///   selon la sévérité (jamais de hex, dark-mode-aware), icône + texte (couleur
///   jamais seul canal), `SnackBarAction` a11y, directionnel, **sans**
///   gestionnaire d'état ;
/// * [ZToasterScope] + [zToast] (EX-UI.8) : **seam** (`InheritedWidget` local)
///   permettant à l'app de substituer son toaster (AD-6), avec repli sûr sur
///   [ZScaffoldMessengerToaster] (jamais de throw, AD-10).
///
/// EX-UI.9 ajoute la **garde anti-perte de saisie** (AD-32) :
/// * [ZDiscardChangesGuard] (EX-UI.9) : `StatelessWidget` enveloppant un
///   `PopScope` qui **intercepte toute sortie** tant que le formulaire est
///   *dirty*. L'état *dirty* est **consommé en lecture seule** via un
///   `ValueListenable<bool>` (canoniquement `ZFormController.isDirty` de
///   `zcrud_core`) — **aucun** gestionnaire d'état, **aucune** mutation du
///   contrôleur. La confirmation réutilise [showZConfirmDialog]
///   (`ZConfirmTone.destructive`), jamais un `AlertDialog` réinventé. Rebuild
///   **ciblé** (SM-1) : seul le `PopScope` est reconstruit au flip *dirty*, le
///   sous-arbre protégé (`child`) ne l'est jamais.
///
/// EX-UI.10 **clôt** la surface `zcrud_ui_kit` avec l'index alphabétique et les
/// transitions de route **RTL-aware** (AD-32/AD-13) :
/// * [ZAlphabetIndexBar] (EX-UI.10) : index vertical A→Z **cliquable**
///   (`StatelessWidget` pur `const`, le `ConsumerWidget`/`WidgetRef` mort de lex
///   **retiré**) — jeu de lettres injectable ([kZDefaultAlphabet] par défaut),
///   distinction actif/inerte/courant **multi-canal** (couleur dérivée du
///   `ColorScheme` **jamais** seul canal : a11y `enabled`/`selected` + geste
///   inactif), cibles ≥ 48 dp, `Semantics`, directionnel. Le widget **émet** la
///   lettre via `onLetter` (tap/scrub) ; l'appelant scrolle (aucun
///   `ScrollController` interne, aucun routeur, aucun manager) ;
/// * [ZRouteTransition] (EX-UI.10) : type de transition en **enum**
///   (`slide`/`fade`) — jamais un `bool isSlide`/`fade` (NFR-U7), valeur d'UI
///   runtime non persistée ;
/// * [zSlideBeginOffset] (EX-UI.10) : **fonction pure** (testable sans
///   `BuildContext`) — offset de début du slide selon la `TextDirection`, le
///   signe **s'inverse** en RTL (AD-13/NFR-U6) ;
/// * [zPageRoute] + [ZPageTransitionsBuilder] (EX-UI.10) : primitives de
///   transition **neutres** (`PageRouteBuilder`/`PageTransitionsBuilder`
///   `package:flutter`) — **découplées de tout routeur** (le couplage `go_router`
///   de lex est **retiré**), durées/courbes **injectées**, sens du slide dérivé
///   de `Directionality.of(context)`.
///
/// **Dépendance (AD-29)** : ce package **dépend de `zcrud_core`** et **consomme**
/// ses seams (`ZcrudScope` / `ZcrudTheme` / `ZcrudLocalizations`) en lecture, avec
/// repli systématique sur `Theme.of(context)` / `MaterialLocalizations.of(context)`
/// quand le scope n'est pas monté. ⛔ Aucun symbole de `zcrud_core` n'est
/// redéclaré ni ré-exporté (le consommateur importe `zcrud_core` directement au
/// besoin). ⛔ Aucun gestionnaire d'état / routeur / tiers UI (AD-2/AD-15).
///
/// API publique = ce barrel ; implémentation sous `lib/src/{domain,presentation}`.
library;

export 'src/domain/z_confirm_tone.dart';
export 'src/domain/z_content_state.dart';
export 'src/domain/z_route_transition.dart';
export 'src/domain/z_toast_severity.dart';
export 'src/domain/z_toaster.dart';
export 'src/presentation/z_alphabet_index_bar.dart';
export 'src/presentation/z_confirm_dialog.dart';
export 'src/presentation/z_discard_changes_guard.dart';
export 'src/presentation/z_scaffold_messenger_toaster.dart';
export 'src/presentation/z_state_widgets.dart';
export 'src/presentation/z_toaster_scope.dart';
export 'src/presentation/z_transitions.dart';
