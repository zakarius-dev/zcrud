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
class ZPageScaffold extends StatefulWidget {
  /// Construit le shell. [title] est un `Widget` ou `String`. [tabs] nul/vide ⇒
  /// aucun `TabBar` (corps = [body]). [mode] défaut [ZPageAppBarMode.fixed].
  /// [tabController] optionnel : si fourni, le shell ne crée pas de
  /// `DefaultTabController`. Les slots de `Scaffold` sont tous optionnels et
  /// conservent les défauts de `Scaffold` (cf. doc de classe).
  const ZPageScaffold({
    required this.title,
    this.subtitle,
    this.gradientKey,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.aboveTabViews,
    this.mode = ZPageAppBarMode.fixed,
    this.tabController,
    this.tabAlignment,
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

  /// Sous-titre optionnel de l'app-bar (CR-IFFD-34), propagé aux deux modes
  /// (fixe et sliver). Voir [ZSearchableAppBar.subtitle] : `null` (défaut) ⇒
  /// **absent de l'arbre**, rendu strictement identique à l'existant.
  final Widget? subtitle;

  /// Identité opaque de l'entité ouverte, alimentant le dégradé d'app-bar via
  /// la couture `zResolveGradient` (CR-IFFD-34). Voir
  /// [ZSearchableAppBar.gradientKey] : sans `ZcrudScope.gradientResolver`
  /// injecté par l'hôte, **aucun** dégradé — rendu inchangé (neutralité VIS-1).
  final String? gradientKey;

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

  /// Slot rendu sous le [TabBar] et au-dessus du [TabBarView] si des onglets
  /// sont fournis. `null` conserve le corps historique sans wrapper ajouté.
  final Widget? aboveTabViews;

  /// Mode d'app-bar (fixe vs sliver repliable — AC11).
  final ZPageAppBarMode mode;

  /// `TabController` injecté optionnel (sinon `DefaultTabController` interne).
  final TabController? tabController;

  /// Alignement optionnel des onglets (`null` ⇒ comportement Flutter actuel).
  final TabAlignment? tabAlignment;

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

  @override
  State<ZPageScaffold> createState() => _ZPageScaffoldState();
}

class _ZPageScaffoldState extends State<ZPageScaffold> {
  late final _ZSearchController _controller;

  bool get _isSliver => widget.mode != ZPageAppBarMode.fixed;

  bool get _hasTabs => widget.tabs != null && widget.tabs!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = _ZSearchController(() => widget.search);
  }

  @override
  void didUpdateWidget(ZPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.search, widget.search)) {
      _controller.didUpdateConfig(oldWidget.search, widget.search);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _isSliver ? _buildSliver(context) : _buildFixed(context);

  /// **Unique** site de construction du `Scaffold` du shell : les slots y sont
  /// câblés une seule fois, donc jamais dupliqués entre les modes.
  Scaffold _scaffold({PreferredSizeWidget? appBar, Widget? body}) => Scaffold(
    appBar: appBar,
    body: body,
    floatingActionButton: widget.floatingActionButton,
    floatingActionButtonLocation: widget.floatingActionButtonLocation,
    persistentFooterButtons: widget.persistentFooterButtons,
    drawer: widget.drawer,
    endDrawer: widget.endDrawer,
    bottomNavigationBar: widget.bottomNavigationBar,
    bottomSheet: widget.bottomSheet,
    backgroundColor: widget.backgroundColor,
    resizeToAvoidBottomInset: widget.resizeToAvoidBottomInset,
    extendBody: widget.extendBody,
    extendBodyBehindAppBar: widget.extendBodyBehindAppBar,
  );

  // --- Mode fixe -------------------------------------------------------------

  Widget _buildFixed(BuildContext context) {
    final scaffold = _scaffold(
      appBar: ZSearchableAppBar._controlled(
        title: widget.title,
        controller: _controller,
        subtitle: widget.subtitle,
        gradientKey: widget.gradientKey,
        leading: widget.leading,
        actions: widget.actions,
        search: widget.search,
        bottom: _hasTabs
            ? _zTabBar(widget.tabs!, widget.tabController, widget.tabAlignment)
            : null,
      ),
      body: _hasTabs ? _buildTabBody() : widget.body,
    );
    // Le `TabBar` vit dans l'app-bar du `Scaffold` (hors de son corps) : le
    // `DefaultTabController` doit donc envelopper le `Scaffold` lui-même.
    return _hasTabs
        ? _zWrapTabs(
            length: widget.tabs!.length,
            controller: widget.tabController,
            child: scaffold,
          )
        : scaffold;
  }

  // --- Modes sliver ----------------------------------------------------------

  /// Le corps sliver est **délégué** à [ZPageShellBody] (même rendu, code
  /// unique) ; les slots restent portés par le `Scaffold` extérieur.
  Widget _buildSliver(BuildContext context) => _scaffold(
    body: ZPageShellBody._controlled(
      title: widget.title,
      subtitle: widget.subtitle,
      gradientKey: widget.gradientKey,
      leading: widget.leading,
      actions: widget.actions,
      search: widget.search,
      tabs: widget.tabs,
      body: widget.body,
      aboveTabViews: widget.aboveTabViews,
      mode: widget.mode,
      tabController: widget.tabController,
      tabAlignment: widget.tabAlignment,
      controller: _controller,
    ),
  );

  Widget _buildTabBody() {
    final tabViews = _zTabBarView(widget.tabs!, widget.tabController);
    final aboveTabViews = widget.aboveTabViews;
    return aboveTabViews == null
        ? tabViews
        : Column(
            children: <Widget>[
              aboveTabViews,
              Expanded(child: tabViews),
            ],
          );
  }
}
