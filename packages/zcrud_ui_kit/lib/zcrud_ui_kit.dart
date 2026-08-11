/// Barrel d'API publique de `zcrud_ui_kit`.
///
/// Kit de widgets UI **transverses** — patterns génériques d'état de
/// contenu, de confirmation, de notification, de garde de saisie et de
/// page-shell, communs à des applications CRUD Flutter :
/// * [ZContentState] : l'état d'un contenu asynchrone en **enum**
///   (`idle`/`loading`/`empty`/`error`/`success`) — remplace les
///   combinaisons de `bool` (`isLoading`/`hasError`/`isEmpty`) ;
/// * [ZEmptyState] / [ZLoadingState] / [ZErrorState] : widgets d'état
///   `const`, thème/couleurs **dérivés** du `ColorScheme` (jamais de hex),
///   textes injectés (l10n), `Semantics`, cibles ≥ 48 dp, directionnels
///   (RTL-safe) ;
/// * [ZContentStateView] : aiguilleur `switch` exhaustif de l'enum vers
///   le bon widget, avec replis sûrs (jamais de throw, invariant AD-10) ;
/// * [ZConfirmTone] : tonalité de confirmation en **enum**
///   (`neutral`/`destructive`) — remplace un `bool isDestructive` ;
/// * [ZConfirmDialog] + [showZConfirmDialog] : dialog de confirmation
///   dark-mode-aware (couleurs dérivées du `ColorScheme`, labels via
///   `MaterialLocalizations`), retournant `Future<bool>`, **sans**
///   gestionnaire d'état (`showDialog` + `Navigator.pop`).
///
/// La **notification (toast) par port** :
/// * [ZToastSeverity] : sévérité d'un toast en **enum**
///   (`info`/`success`/`warning`/`error`) — remplace un `bool isError` ou un
///   `String` libre, et les méthodes ad hoc `showError`/`showSuccess`/
///   `showInfo` ;
/// * [ZToaster] : **port** de notification `abstract interface class`
///   (jamais `sealed`, invariant AD-4) — les impls concrètes (GetX/
///   `toastification`) vivent dans les bindings/app ;
/// * [ZScaffoldMessengerToaster] : impl **par défaut** pur-Flutter
///   (`ScaffoldMessenger.showSnackBar`), couleur **dérivée** du
///   `ColorScheme` selon la sévérité (jamais de hex, dark-mode-aware),
///   icône + texte (couleur jamais seul canal), `SnackBarAction` a11y,
///   directionnel, **sans** gestionnaire d'état ;
/// * [ZToasterScope] + [zToast] : **seam** (`InheritedWidget` local)
///   permettant à l'app de substituer son toaster (invariant AD-6), avec
///   repli sûr sur [ZScaffoldMessengerToaster] (jamais de throw, invariant
///   AD-10).
///
/// La **garde anti-perte de saisie** :
/// * [ZDiscardChangesGuard] : `StatelessWidget` enveloppant un
///   `PopScope` qui **intercepte toute sortie** tant que le formulaire est
///   *dirty*. L'état *dirty* est **consommé en lecture seule** via un
///   `ValueListenable<bool>` (canoniquement `ZFormController.isDirty` de
///   `zcrud_core`) — **aucun** gestionnaire d'état, **aucune** mutation du
///   contrôleur. La confirmation réutilise [showZConfirmDialog]
///   (`ZConfirmTone.destructive`), jamais un `AlertDialog` réinventé.
///   Rebuild **ciblé** : seul le `PopScope` est reconstruit au flip
///   *dirty*, le sous-arbre protégé (`child`) ne l'est jamais.
///
/// L'**index alphabétique** et les **transitions de route RTL-aware**
/// (invariant AD-13) :
/// * [ZAlphabetIndexBar] : index vertical A→Z **cliquable**
///   (`StatelessWidget` pur `const`) — jeu de lettres injectable
///   ([kZDefaultAlphabet] par défaut), distinction actif/inerte/courant
///   **multi-canal** (couleur dérivée du `ColorScheme` **jamais** seul
///   canal : a11y `enabled`/`selected` + geste inactif), cibles ≥ 48 dp,
///   `Semantics`, directionnel. Le widget **émet** la lettre via
///   `onLetter` (tap/scrub) ; l'appelant scrolle (aucun `ScrollController`
///   interne, aucun routeur, aucun manager) ;
/// * [ZRouteTransition] : type de transition en **enum**
///   (`slide`/`fade`) — jamais un `bool isSlide`/`fade`, valeur d'UI
///   runtime non persistée ;
/// * [zSlideBeginOffset] : **fonction pure** (testable sans
///   `BuildContext`) — offset de début du slide selon la `TextDirection`,
///   le signe **s'inverse** en RTL (invariant AD-13) ;
/// * [zPageRoute] + [ZPageTransitionsBuilder] : primitives de
///   transition **neutres** (`PageRouteBuilder`/`PageTransitionsBuilder`
///   `package:flutter`) — **découplées de tout routeur**, durées/courbes
///   **injectées**, sens du slide dérivé de `Directionality.of(context)`.
///
/// Le **page-shell déclaratif** (invariants AD-2, AD-13) :
/// * [ZAppBarAction] : action d'app-bar **en données** (icône +
///   `semanticLabel` + `onPressed` + `tooltip?` + `isOverflow?`) — une
///   action non déclarée est structurellement absente (aucun bouton
///   fantôme) ;
/// * [ZAppBarSearchConfig] : config **déclarative** de la recherche
///   intégrée — le shell **détient** l'état (`isSearching`/`query`), la
///   config n'expose qu'un callback d'émission `onQueryChanged` (invariants
///   AD-2, AD-15) ;
/// * [ZPageTab] : onglet déclaratif (`label`/`icon?`/`contentBuilder`)
///   pilotant `TabBar`/`TabBarView` (`isScrollable`) ;
/// * [ZPageAppBarMode] : mode d'app-bar en **enum**
///   (`fixed`/`floating`/`pinned`/`floatingPinned`) — jamais un couple de
///   `bool` ;
/// * [ZSearchableAppBar] : app-bar recherchable `PreferredSizeWidget`,
///   état de recherche **détenu** (aucun contrôleur externe), rebuild
///   **granulaire** (la frappe ne rebâtit que la tranche app-bar), titre
///   qui morphe en champ (autofocus, `Échap` ⇒ fermeture), couleurs
///   dérivées du `ColorScheme`, libellés/hints via l10n injectée (repli
///   `MaterialLocalizations`), directionnelle (RTL) et a11y (`Semantics`,
///   cibles ≥ 48 dp) ;
/// * [ZPageScaffold] : assemblage titre/leading/actions/recherche/
///   onglets + [ZPageAppBarMode] (app-bar fixe **ou** `SliverAppBar`
///   repliable), factorisant le rendu app-bar entre les deux modes. Il
///   **construit** le `Scaffold` : il en expose donc les slots en
///   **pass-through** — `floatingActionButton` (+ `Location`),
///   `drawer`/`endDrawer`, `bottomNavigationBar`, `bottomSheet`,
///   `persistentFooterButtons`, `backgroundColor`,
///   `resizeToAvoidBottomInset`, `extendBody`/`extendBodyBehindAppBar`.
///   Tous **optionnels**, défauts `Scaffold` : un slot non fourni est
///   **structurellement absent** et le rendu par défaut est inchangé. **Un
///   seul `Scaffold`** est construit quel que soit le mode ⇒ aucun slot
///   dupliqué ;
/// * [ZPageShellBody] : la même valeur (app-bar morphante repliable +
///   onglets) **sans posséder de `Scaffold`** — à poser dans le `Scaffold`
///   de l'hôte, qui garde ainsi **tous** ses slots, présents et futurs. À
///   préférer dès que l'hôte enveloppe son `Scaffold` (`PopScope`…) ou en
///   aiguille plusieurs selon l'état. Pour un app-bar **fixe**, la brique
///   équivalente est [ZSearchableAppBar] dans `Scaffold(appBar:)`.
///
/// **La typographie de l'en-tête est atteignable sans réécrire le thème.**
/// Quatre créneaux (`titleTextStyle`, `subtitleTextStyle`, `tabLabelStyle`,
/// `tabUnselectedLabelStyle`) sur [ZPageScaffold] / [ZPageShellBody] (les
/// deux premiers aussi sur [ZSearchableAppBar]), doublés de quatre jetons
/// de `ZcrudTheme` (`pageHeaderTitleStyle`, `pageHeaderSubtitleStyle`,
/// `pageHeaderTabSelectedLabelStyle`, `pageHeaderTabUnselectedLabelStyle`).
/// Priorité stricte **paramètre > jeton > défaut**. Un hôte n'a donc plus à
/// envelopper sa page dans un `Theme` réécrivant `AppBarTheme`/`TabBarTheme`
/// pour atteindre deux textes.
///
/// **Défaut strictement inchangé** : sans paramètre ni jeton, **aucune**
/// enveloppe de style n'entre dans l'arbre et le rendu est celui d'une
/// app-bar Material nue. **Métriques seules** : la couleur d'un style
/// fourni est délibérément **ignorée** — pour le titre parce qu'elle doit
/// rester héritée du `foregroundColor` (lisibilité sous dégradé
/// d'identité), pour les onglets parce que `TabBar` dérive sa couleur de
/// sélection de `labelStyle?.color` et qu'un style coloré **supprimerait**
/// la distinction sélectionné/non-sélectionné.
///
/// **Dépendance** : ce package **dépend de `zcrud_core`** et **consomme**
/// ses seams (`ZcrudScope` / `ZcrudTheme` / `ZcrudLocalizations`) en
/// lecture, avec repli systématique sur `Theme.of(context)` /
/// `MaterialLocalizations.of(context)` quand le scope n'est pas monté.
/// Aucun symbole de `zcrud_core` n'est redéclaré ni ré-exporté (le
/// consommateur importe `zcrud_core` directement au besoin). Aucun
/// gestionnaire d'état / routeur / tiers UI (invariants AD-2, AD-15).
///
/// API publique = ce barrel ; implémentation sous `lib/src/{domain,presentation}`.
library;

export 'src/domain/z_app_bar_action.dart';
export 'src/domain/z_app_bar_search_config.dart';
export 'src/domain/z_confirm_tone.dart';
export 'src/domain/z_content_state.dart';
export 'src/domain/z_page_app_bar_mode.dart';
export 'src/domain/z_page_tab.dart';
export 'src/domain/z_route_transition.dart';
export 'src/domain/z_toast_severity.dart';
export 'src/domain/z_toaster.dart';
export 'src/presentation/z_alphabet_index_bar.dart';
export 'src/presentation/z_confirm_dialog.dart';
export 'src/presentation/z_discard_changes_guard.dart';
export 'src/presentation/z_page_shell.dart';
export 'src/presentation/z_scaffold_messenger_toaster.dart';
export 'src/presentation/z_state_widgets.dart';
export 'src/presentation/z_toaster_scope.dart';
export 'src/presentation/z_transitions.dart';
