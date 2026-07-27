part of 'z_page_shell.dart';

/// Corps de page-shell **sans `Scaffold`** (CR-52, option « ne pas posséder le
/// `Scaffold` ») : app-bar repliable (`SliverAppBar`) recherchable + onglets +
/// contenu, à poser **dans le `Scaffold` de l'hôte**.
///
/// ```dart
/// Scaffold(
///   drawer: const AppDrawer(),                 // slots de l'hôte : TOUS,
///   floatingActionButton: const MyFab(),       // présents ET futurs
///   body: ZPageShellBody(title: 'Titre', mode: ZPageAppBarMode.pinned, ...),
/// )
/// ```
///
/// **Pourquoi en plus de [ZPageScaffold]** : [ZPageScaffold] construit le
/// `Scaffold` et en expose les slots en pass-through (voir sa doc) — pratique
/// pour un écran simple, mais la liste des slots est **finie** et l'hôte qui
/// enveloppe son `Scaffold` (`PopScope`, `Banner`, `Stack`…) ou qui aiguille
/// plusieurs `Scaffold` selon l'état (chargement/erreur/succès) ne peut pas
/// l'utiliser. [ZPageShellBody] retire la question : le `Scaffold` reste à
/// l'hôte, le shell n'apporte que sa valeur propre (app-bar morphante +
/// onglets). Les deux voies partagent **le même code** (`_zTabBar`,
/// `_zTabBarView`, `_zWrapTabs`, `_ZSearchController`) : [ZPageScaffold] en
/// modes sliver **délègue** son corps à ce widget — aucun rendu dupliqué.
///
/// **Mode fixe** : un app-bar FIXE n'appartient pas au corps mais à
/// `Scaffold(appBar:)` — utiliser directement [ZSearchableAppBar], qui est
/// publique et détient elle aussi son état. Si [ZPageAppBarMode.fixed] est
/// néanmoins passé ici, ce widget **ne lève pas** (AD-10) : il se replie sur
/// [ZPageAppBarMode.pinned], visuellement équivalent (app-bar toujours visible
/// en tête) dans un contexte défilant.
///
/// **AD-2/AD-15** : l'état de recherche est détenu par ce widget (aucun
/// gestionnaire d'état, aucun contrôleur externe) ; la frappe ne reconstruit
/// que la tranche app-bar (`ValueListenableBuilder`), jamais le corps.
class ZPageShellBody extends StatefulWidget {
  /// Construit le corps de shell. [title] est un `Widget` ou un `String`.
  /// [tabs] nul/vide ⇒ aucun `TabBar` (contenu = [body]). [body] nul ⇒ **aucun
  /// sliver de contenu** (absence structurelle, pas de boîte vide).
  const ZPageShellBody({
    required this.title,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.aboveTabViews,
    this.mode = ZPageAppBarMode.pinned,
    this.tabController,
    this.tabAlignment,
    super.key,
  }) : assert(
         title is Widget || title is String,
         'title doit être un Widget ou un String',
       ),
       _controller = null;

  /// Variante interne composée par `ZPageScaffold` avec son unique état de
  /// recherche, pour survivre à un hot-swap de mode.
  const ZPageShellBody._controlled({
    required this.title,
    required _ZSearchController this._controller,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.aboveTabViews,
    this.mode = ZPageAppBarMode.pinned,
    this.tabController,
    this.tabAlignment,
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

  /// Contenu affiché quand il n'y a **pas** d'onglets (nul ⇒ absent).
  final Widget? body;

  /// Slot sous le `TabBar` et au-dessus des vues (`null` ⇒ absent).
  final Widget? aboveTabViews;

  /// Mode d'app-bar. [ZPageAppBarMode.fixed] se replie sur `pinned` (cf. doc de
  /// classe) : un app-bar fixe se pose dans `Scaffold(appBar:)`.
  final ZPageAppBarMode mode;

  /// `TabController` injecté optionnel (sinon `DefaultTabController` interne).
  final TabController? tabController;

  /// Alignement optionnel des onglets (`null` ⇒ défaut Flutter).
  final TabAlignment? tabAlignment;

  final _ZSearchController? _controller;

  @override
  State<ZPageShellBody> createState() => _ZPageShellBodyState();
}

class _ZPageShellBodyState extends State<ZPageShellBody> {
  /// Contrôleur de recherche **détenu** (propriétaire unique, AD-2) : créé une
  /// fois, `dispose`é une fois, jamais recréé au rebuild.
  late final _ZSearchController _controller;
  late final bool _ownsController;

  bool get _hasTabs => widget.tabs != null && widget.tabs!.isNotEmpty;

  /// Mode effectif : `fixed` n'a pas de sens dans un corps défilant ⇒ `pinned`
  /// (repli documenté, jamais un throw — AD-10).
  ZPageAppBarMode get _mode => widget.mode == ZPageAppBarMode.fixed
      ? ZPageAppBarMode.pinned
      : widget.mode;

  @override
  void initState() {
    super.initState();
    // Config lue à l'ÉMISSION (jamais copiée) — cf. `_ZSearchController`.
    _ownsController = widget._controller == null;
    _controller = widget._controller ?? _ZSearchController(() => widget.search);
  }

  @override
  void didUpdateWidget(ZPageShellBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ownsController && !identical(oldWidget.search, widget.search)) {
      _controller.didUpdateConfig(oldWidget.search, widget.search);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  Widget _sliverAppBar(BuildContext context, {PreferredSizeWidget? bottom}) {
    final mode = _mode;
    final floating =
        mode == ZPageAppBarMode.floating ||
        mode == ZPageAppBarMode.floatingPinned;
    final pinned =
        mode == ZPageAppBarMode.pinned ||
        mode == ZPageAppBarMode.floatingPinned;
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

  @override
  Widget build(BuildContext context) {
    if (_hasTabs) {
      return _zWrapTabs(
        length: widget.tabs!.length,
        controller: widget.tabController,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => <Widget>[
            _sliverAppBar(
              context,
              bottom: _zTabBar(
                widget.tabs!,
                widget.tabController,
                widget.tabAlignment,
              ),
            ),
          ],
          body: _buildTabBody(),
        ),
      );
    }
    return CustomScrollView(
      slivers: <Widget>[
        _sliverAppBar(context),
        // Corps non fourni ⇒ sliver ABSENT (jamais un `SizedBox.shrink` inerte).
        if (widget.body != null) SliverToBoxAdapter(child: widget.body),
      ],
    );
  }

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
