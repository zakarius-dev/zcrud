part of 'z_page_shell.dart';

/// Page-shell déclaratif complet (SUF-1, AC9–AC11) : assemble titre, leading,
/// actions, recherche, onglets et un [mode] d'app-bar (fixe vs sliver
/// repliable).
///
/// * [ZPageAppBarMode.fixed] : `Scaffold(appBar: ZSearchableAppBar(...))`,
///   corps = `TabBarView` (si [tabs]) ou [body]. Aucun `SliverAppBar`.
/// * modes sliver : le corps est délégué à [ZPageShellBody] (`SliverAppBar`
///   floating/pinned dans un `NestedScrollView` avec onglets, un
///   `CustomScrollView` sans) — **un seul** rendu sliver dans la bibliothèque.
///
/// Le rendu titre/actions/recherche est **factorisé** avec [ZSearchableAppBar]
/// (fonctions `_zBuild*` de `z_page_shell.dart`) : le motif app-bar n'est pas
/// re-dupliqué entre les deux modes.
///
/// ## Slots de `Scaffold` (CR-52)
///
/// Ce shell **construit** le `Scaffold` : il en expose donc les slots utiles à
/// un hôte en **pass-through** ([floatingActionButton],
/// [floatingActionButtonLocation], [persistentFooterButtons], [drawer],
/// [endDrawer], [bottomNavigationBar], [bottomSheet], [backgroundColor],
/// [resizeToAvoidBottomInset], [extendBody], [extendBodyBehindAppBar]). Tous
/// sont **optionnels** et leurs valeurs par défaut sont celles de `Scaffold` :
/// un slot non fourni est **structurellement absent** (aucune boîte vide, aucun
/// `SizedBox.shrink` inerte) et le rendu est **identique** à celui d'avant leur
/// introduction.
///
/// **Un seul `Scaffold`, un seul porteur.** Quel que soit le mode, exactement
/// **un** `Scaffold` est construit — par [_scaffold], **unique** site de
/// construction : mode fixe et modes sliver sont des branches **exclusives**, et
/// le `NestedScrollView` du mode sliver+onglets n'est PAS un `Scaffold`
/// imbriqué. Les slots ne peuvent donc pas être dupliqués (FAB fantôme, double
/// tiroir) : c'est le `Scaffold` **extérieur** — le seul — qui les porte, en
/// dehors de la zone défilante, comme le veut Material.
///
/// ⚠️ [extendBodyBehindAppBar] n'a d'effet qu'en [ZPageAppBarMode.fixed] (seul
/// mode où l'app-bar est celle du `Scaffold`) ; en mode sliver l'app-bar est
/// **dans** le corps défilant, l'option est donc sans objet — Flutter l'ignore,
/// aucun rendu n'est altéré.
///
/// 💡 **Hôte au `Scaffold` non trivial** (enveloppé dans un `PopScope`, ou
/// plusieurs `Scaffold` aiguillés selon l'état, ou un slot que ce pass-through
/// n'expose pas) : préférer [ZPageShellBody], qui ne possède aucun `Scaffold` et
/// laisse à l'hôte **tous** ses slots, présents et futurs.
class ZPageScaffold extends StatelessWidget {
  /// Construit le shell. [title] est un `Widget` ou `String`. [tabs] nul/vide ⇒
  /// aucun `TabBar` (corps = [body]). [mode] défaut [ZPageAppBarMode.fixed].
  /// [tabController] optionnel : si fourni, le shell ne crée pas de
  /// `DefaultTabController`. Les slots de `Scaffold` sont tous optionnels et
  /// conservent les défauts de `Scaffold` (cf. doc de classe).
  const ZPageScaffold({
    required this.title,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.mode = ZPageAppBarMode.fixed,
    this.tabController,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    super.key,
  }) : assert(
          title is Widget || title is String,
          'title doit être un Widget ou un String',
        );

  /// Titre : `Widget` rendu tel quel, ou `String` emballé dans un `Text`.
  final Object title;

  /// Leading optionnel (rendu si et seulement si fourni — AC1).
  final Widget? leading;

  /// Actions déclarées en données (absentes si non fournies — AC2).
  final List<ZAppBarAction> actions;

  /// Configuration de recherche (nulle ⇒ pas de recherche — AC8).
  final ZAppBarSearchConfig? search;

  /// Onglets déclaratifs (nul/vide ⇒ aucun `TabBar` — AC10).
  final List<ZPageTab>? tabs;

  /// Corps affiché quand il n'y a **pas** d'onglets (nul ⇒ aucun corps).
  final Widget? body;

  /// Mode d'app-bar (fixe vs sliver repliable — AC11).
  final ZPageAppBarMode mode;

  /// `TabController` injecté optionnel (sinon `DefaultTabController` interne).
  final TabController? tabController;

  /// `Scaffold.floatingActionButton` (nul ⇒ aucun FAB — CR-52).
  final Widget? floatingActionButton;

  /// `Scaffold.floatingActionButtonLocation` (nul ⇒ position par défaut).
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// `Scaffold.persistentFooterButtons` (nul ⇒ aucun pied persistant).
  final List<Widget>? persistentFooterButtons;

  /// `Scaffold.drawer` — tiroir de navigation (nul ⇒ aucun tiroir).
  final Widget? drawer;

  /// `Scaffold.endDrawer` — tiroir de fin (RTL-aware côté Flutter).
  final Widget? endDrawer;

  /// `Scaffold.bottomNavigationBar` (nul ⇒ aucune barre basse).
  final Widget? bottomNavigationBar;

  /// `Scaffold.bottomSheet` — feuille persistante (nul ⇒ absente).
  final Widget? bottomSheet;

  /// `Scaffold.backgroundColor` — **injectée par l'hôte** (nul ⇒ couleur du
  /// thème ; aucune couleur n'est codée en dur dans le package).
  final Color? backgroundColor;

  /// `Scaffold.resizeToAvoidBottomInset` (nul ⇒ défaut Flutter).
  final bool? resizeToAvoidBottomInset;

  /// `Scaffold.extendBody` (défaut `false`, comme `Scaffold`).
  final bool extendBody;

  /// `Scaffold.extendBodyBehindAppBar` (défaut `false`). Sans objet en mode
  /// sliver (cf. doc de classe).
  final bool extendBodyBehindAppBar;

  bool get _isSliver => mode != ZPageAppBarMode.fixed;

  bool get _hasTabs => tabs != null && tabs!.isNotEmpty;

  @override
  Widget build(BuildContext context) =>
      _isSliver ? _buildSliver(context) : _buildFixed(context);

  /// **Unique** site de construction du `Scaffold` du shell : les slots y sont
  /// câblés une seule fois, donc jamais dupliqués entre les modes.
  Scaffold _scaffold({PreferredSizeWidget? appBar, Widget? body}) => Scaffold(
        appBar: appBar,
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
        persistentFooterButtons: persistentFooterButtons,
        drawer: drawer,
        endDrawer: endDrawer,
        bottomNavigationBar: bottomNavigationBar,
        bottomSheet: bottomSheet,
        backgroundColor: backgroundColor,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        extendBody: extendBody,
        extendBodyBehindAppBar: extendBodyBehindAppBar,
      );

  // --- Mode fixe -------------------------------------------------------------

  Widget _buildFixed(BuildContext context) {
    final scaffold = _scaffold(
      appBar: ZSearchableAppBar(
        title: title,
        leading: leading,
        actions: actions,
        search: search,
        bottom: _hasTabs ? _zTabBar(tabs!, tabController) : null,
      ),
      body: _hasTabs ? _zTabBarView(tabs!, tabController) : body,
    );
    // Le `TabBar` vit dans l'app-bar du `Scaffold` (hors de son corps) : le
    // `DefaultTabController` doit donc envelopper le `Scaffold` lui-même.
    return _hasTabs
        ? _zWrapTabs(
            length: tabs!.length,
            controller: tabController,
            child: scaffold,
          )
        : scaffold;
  }

  // --- Modes sliver ----------------------------------------------------------

  /// Le corps sliver est **délégué** à [ZPageShellBody] (même rendu, code
  /// unique) ; les slots restent portés par le `Scaffold` extérieur.
  Widget _buildSliver(BuildContext context) => _scaffold(
        body: ZPageShellBody(
          title: title,
          leading: leading,
          actions: actions,
          search: search,
          tabs: tabs,
          body: body,
          mode: mode,
          tabController: tabController,
        ),
      );
}
