part of 'z_page_shell.dart';

/// Page-shell déclaratif complet (SUF-1, AC9–AC11) : assemble titre, leading,
/// actions, recherche, onglets et un [mode] d'app-bar (fixe vs sliver
/// repliable).
///
/// * [ZPageAppBarMode.fixed] : `Scaffold(appBar: ZSearchableAppBar(...))`,
///   corps = `TabBarView` (si [tabs]) ou [body]. Aucun `SliverAppBar`.
/// * modes sliver : `SliverAppBar` (floating/pinned selon [mode]) dans un
///   `NestedScrollView` (avec onglets) ou un `CustomScrollView` (sans).
///
/// Le rendu titre/actions/recherche est **factorisé** avec [ZSearchableAppBar]
/// (fonctions `_zBuild*` de `z_page_shell.dart`) : le motif app-bar n'est pas
/// re-dupliqué entre les deux modes.
class ZPageScaffold extends StatefulWidget {
  /// Construit le shell. [title] est un `Widget` ou `String`. [tabs] nul/vide ⇒
  /// aucun `TabBar` (corps = [body]). [mode] défaut [ZPageAppBarMode.fixed].
  /// [tabController] optionnel : si fourni, le shell ne crée pas de
  /// `DefaultTabController`.
  const ZPageScaffold({
    required this.title,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.mode = ZPageAppBarMode.fixed,
    this.tabController,
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

  /// Corps affiché quand il n'y a **pas** d'onglets.
  final Widget? body;

  /// Mode d'app-bar (fixe vs sliver repliable — AC11).
  final ZPageAppBarMode mode;

  /// `TabController` injecté optionnel (sinon `DefaultTabController` interne).
  final TabController? tabController;

  @override
  State<ZPageScaffold> createState() => _ZPageScaffoldState();
}

class _ZPageScaffoldState extends State<ZPageScaffold> {
  /// Contrôleur de recherche utilisé par les modes sliver (en mode fixe, c'est
  /// [ZSearchableAppBar] qui détient le sien).
  ///
  /// Créé **INCONDITIONNELLEMENT** : [mode] est une prop déclarative qu'un hôte
  /// adaptatif change d'un build à l'autre (`fixed` en compact, sliver en
  /// large). Le conditionner à `_isSliver` en `initState` figerait le
  /// propriétaire de l'état sur le mode INITIAL, alors que `build` réévalue
  /// `_isSliver` à chaque frame ⇒ déréférencement nul au premier build sliver.
  /// Son coût (un `TextEditingController` + un `FocusNode` inutilisés en mode
  /// fixe) est négligeable devant un crash, et son cycle de vie devient trivial.
  late final _ZSearchController _controller;

  bool get _isSliver => widget.mode != ZPageAppBarMode.fixed;

  bool get _hasTabs => widget.tabs != null && widget.tabs!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Config lue à l'ÉMISSION (jamais copiée) — cf. `_ZSearchController`.
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

  // --- Onglets partagés ------------------------------------------------------

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: widget.tabController,
      isScrollable: true,
      tabs: <Widget>[
        for (final tab in widget.tabs!)
          Tab(
            text: tab.label,
            icon: tab.icon == null ? null : Icon(tab.icon),
          ),
      ],
    );
  }

  Widget _buildTabBarView() {
    return TabBarView(
      controller: widget.tabController,
      children: <Widget>[
        for (final tab in widget.tabs!) Builder(builder: tab.contentBuilder),
      ],
    );
  }

  /// Fournit un `DefaultTabController` seulement si aucun contrôleur n'est
  /// injecté (sinon `TabBar`/`TabBarView` reçoivent [widget.tabController]).
  Widget _wrapTabs(Widget child) {
    if (widget.tabController != null) return child;
    return DefaultTabController(length: widget.tabs!.length, child: child);
  }

  // --- Mode fixe -------------------------------------------------------------

  Widget _buildFixed(BuildContext context) {
    final scaffold = Scaffold(
      appBar: ZSearchableAppBar(
        title: widget.title,
        leading: widget.leading,
        actions: widget.actions,
        search: widget.search,
        bottom: _hasTabs ? _buildTabBar() : null,
      ),
      body: _hasTabs
          ? _buildTabBarView()
          : (widget.body ?? const SizedBox.shrink()),
    );
    return _hasTabs ? _wrapTabs(scaffold) : scaffold;
  }

  // --- Modes sliver ----------------------------------------------------------

  Widget _sliverAppBar(BuildContext context, {PreferredSizeWidget? bottom}) {
    final floating = widget.mode == ZPageAppBarMode.floating ||
        widget.mode == ZPageAppBarMode.floatingPinned;
    final pinned = widget.mode == ZPageAppBarMode.pinned ||
        widget.mode == ZPageAppBarMode.floatingPinned;
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isSearching,
      builder: (context, searching, _) => SliverAppBar(
        floating: floating,
        pinned: pinned,
        leading: _zBuildLeading(
          context,
          _controller,
          widget.leading,
          widget.search,
          searching,
        ),
        title: _zBuildTitle(
          context,
          _controller,
          widget.title,
          widget.search,
          searching,
        ),
        centerTitle: false,
        actions: _zBuildActions(
          context,
          _controller,
          widget.actions,
          widget.search,
          searching,
        ),
        bottom: bottom,
      ),
    );
  }

  Widget _buildSliver(BuildContext context) {
    if (_hasTabs) {
      final nested = Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => <Widget>[
            _sliverAppBar(context, bottom: _buildTabBar()),
          ],
          body: _buildTabBarView(),
        ),
      );
      return _wrapTabs(nested);
    }
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          _sliverAppBar(context),
          SliverToBoxAdapter(child: widget.body ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}
