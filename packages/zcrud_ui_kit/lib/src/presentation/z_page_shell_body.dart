part of 'z_page_shell.dart';

/// Corps de page-shell **sans `Scaffold`** : app-bar repliable
/// (`SliverAppBar`) recherchable + onglets + contenu, à poser **dans le
/// `Scaffold` de l'hôte**.
///
/// ```dart
/// Scaffold(
///   drawer: const AppDrawer(), // slots de l'hôte: TOUS,
///   floatingActionButton: const MyFab(), // présents ET futurs
///   body: ZPageShellBody(title: 'Titre', mode: ZPageAppBarMode.pinned,...),
/// )
/// ```
///
/// **Pourquoi en plus de [ZPageScaffold]**: [ZPageScaffold] construit le
/// `Scaffold` et en expose les slots en pass-through (voir sa doc) — pratique
/// pour un écran simple, mais la liste des slots est **finie** et l'hôte qui
/// enveloppe son `Scaffold` (`PopScope`, `Banner`, `Stack`…) ou qui aiguille
/// plusieurs `Scaffold` selon l'état (chargement/erreur/succès) ne peut pas
/// l'utiliser. [ZPageShellBody] retire la question: le `Scaffold` reste à
/// l'hôte, le shell n'apporte que sa valeur propre (app-bar morphante +
/// onglets). Les deux voies partagent **le même code** (`_zTabBar`,
/// `_zTabBarView`, `_zWrapTabs`, `_ZSearchController`): [ZPageScaffold] en
/// modes sliver **délègue** son corps à ce widget — aucun rendu dupliqué.
///
/// **Mode fixe**: un app-bar FIXE n'appartient pas au corps mais à
/// `Scaffold(appBar:)` — utiliser directement [ZSearchableAppBar], qui est
/// publique et détient elle aussi son état. Si [ZPageAppBarMode.fixed] est
/// néanmoins passé ici, ce widget **ne lève pas** (AD-10): il se replie sur
/// [ZPageAppBarMode.pinned], visuellement équivalent (app-bar toujours visible
/// en tête) dans un contexte défilant.
///
/// **AD-2/AD-15**: l'état de recherche est détenu par ce widget (aucun
/// gestionnaire d'état, aucun contrôleur externe); la frappe ne reconstruit
/// que la tranche app-bar (`ValueListenableBuilder`), jamais le corps.
class ZPageShellBody extends StatefulWidget {
  /// Construit le corps de shell. [title] est un `Widget` ou un `String`.
  /// [tabs] nul/vide ⇒ aucun `TabBar` (contenu = [body]). [body] nul ⇒ **aucun
  /// sliver de contenu** (absence structurelle, pas de boîte vide).
  const ZPageShellBody({
    required this.title,
    this.subtitle,
    this.gradientKey,
    this.signatureKey,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.aboveTabBar,
    this.aboveTabBarHeight,
    this.aboveTabViews,
    this.mode = ZPageAppBarMode.pinned,
    this.tabController,
    this.tabAlignment,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tabLabelStyle,
    this.tabUnselectedLabelStyle,
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
    this.subtitle,
    this.gradientKey,
    this.signatureKey,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.tabs,
    this.body,
    this.aboveTabBar,
    this.aboveTabBarHeight,
    this.aboveTabViews,
    this.mode = ZPageAppBarMode.pinned,
    this.tabController,
    this.tabAlignment,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tabLabelStyle,
    this.tabUnselectedLabelStyle,
  }) : assert(
         title is Widget || title is String,
         'title doit être un Widget ou un String',
       );

  /// Titre: `Widget` rendu tel quel, ou `String` emballé dans un `Text`.
  final Object title;

  /// Sous-titre optionnel. Voir [ZSearchableAppBar.subtitle]:
  /// `null` ⇒ absent de l'arbre, rendu strictement inchangé.
  final Widget? subtitle;

  /// Clé d'identité du dégradé d'app-bar, **prioritaire sur tout le reste**.
  /// Voir [ZSearchableAppBar.gradientKey] : déclarée, elle peint la spec du
  /// seam à saturation pleine ; vide (`''`), elle éteint tout chrome
  /// d'identité sur ce site.
  final String? gradientKey;

  /// Identité alimentant le **lavis de palette signature** quand
  /// [gradientKey] n'est pas déclarée. Voir [ZSearchableAppBar.signatureKey] :
  /// repli sur le titre s'il est une chaîne, `ZReferenceProfile.neutral` pour
  /// tout éteindre à la racine.
  final String? signatureKey;

  /// Leading optionnel, rendu si et seulement si fourni.
  final Widget? leading;

  /// Actions déclarées en données (absentes si non fournies).
  final List<ZAppBarAction> actions;

  /// Configuration de recherche (nulle ⇒ pas de recherche).
  final ZAppBarSearchConfig? search;

  /// Onglets déclaratifs (nul/vide ⇒ aucun `TabBar`).
  final List<ZPageTab>? tabs;

  /// Contenu affiché quand il n'y a **pas** d'onglets (nul ⇒ absent).
  final Widget? body;

  /// Créneau de **contexte de page** posé entre l'app-bar et le `TabBar`,
  /// dans le `bottom:` de la `SliverAppBar` — **même endroit
  /// logique** que dans [ZPageScaffold.aboveTabBar], dont il partage la doc et
  /// le code (`_zAppBarBottom`).
  ///
  /// `null` (défaut) ⇒ arbre strictement inchangé. Mode `pinned`: la surface
  /// reste **visible** au défilement (le `bottom:` d'une `SliverAppBar` épinglée
  /// l'est aussi); mode `floating`: elle se replie avec l'app-bar.
  ///
  /// Ne pas router cet usage vers [subtitle]: voir
  /// [ZPageScaffold.aboveTabBar] pour les mesures (chevauchement **silencieux**
  /// de 10 dp du `TabBar` avec un `subtitle` de 48 dp).
  final Widget? aboveTabBar;

  /// Hauteur déclarée de [aboveTabBar] (`null` ⇒ `preferredSize` du créneau
  /// s'il est `PreferredSizeWidget`, sinon `kToolbarHeight`). Voir
  /// [ZPageScaffold.aboveTabBarHeight].
  final double? aboveTabBarHeight;

  /// Slot sous le `TabBar` et au-dessus des vues (`null` ⇒ absent).
  final Widget? aboveTabViews;

  /// Mode d'app-bar. [ZPageAppBarMode.fixed] se replie sur `pinned` (cf. doc de
  /// classe): un app-bar fixe se pose dans `Scaffold(appBar:)`.
  final ZPageAppBarMode mode;

  /// `TabController` injecté optionnel (sinon `DefaultTabController` interne).
  final TabController? tabController;

  /// Alignement optionnel des onglets (`null` ⇒ défaut Flutter).
  final TabAlignment? tabAlignment;

  /// Typographie du TITRE. Voir
  /// [ZSearchableAppBar.titleTextStyle]: priorité **paramètre > jeton
  /// `ZcrudTheme.pageHeaderTitleStyle` > défaut**, **métriques seules** (la
  /// couleur reste héritée du `foregroundColor` du sliver).
  final TextStyle? titleTextStyle;

  /// Typographie du SOUS-TITRE. Voir
  /// [ZSearchableAppBar.subtitleTextStyle].
  final TextStyle? subtitleTextStyle;

  /// Typographie du libellé d'onglet **SÉLECTIONNÉ**. Voir
  /// [ZPageScaffold.tabLabelStyle].
  final TextStyle? tabLabelStyle;

  /// Typographie du libellé d'onglet **NON SÉLECTIONNÉ**. Voir
  /// [ZPageScaffold.tabUnselectedLabelStyle].
  final TextStyle? tabUnselectedLabelStyle;

  final _ZSearchController? _controller;

  @override
  State<ZPageShellBody> createState() => _ZPageShellBodyState();
}

class _ZPageShellBodyState extends State<ZPageShellBody> {
  /// Contrôleur de recherche **détenu** (propriétaire unique, AD-2): créé une
  /// fois, `dispose`é une fois, jamais recréé au rebuild.
  late final _ZSearchController _controller;
  late final bool _ownsController;

  bool get _hasTabs => widget.tabs != null && widget.tabs!.isNotEmpty;

  /// Mode effectif: `fixed` n'a pas de sens dans un corps défilant ⇒ `pinned`
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
      builder: (context, searching, _) {
        // Resolver hôte appelé UNE seule fois par build (jamais deux fois pour
        // la même clé); `null` ⇒ slots absents ⇒ sliver strictement inchangé.
        final _ZAppBarChrome chrome = _zAppBarChrome(
          context,
          gradientKey: widget.gradientKey,
          signatureKey: widget.signatureKey,
          title: widget.title,
        );
        return SliverAppBar(
          floating: floating,
          pinned: pinned,
          flexibleSpace: chrome.flexibleSpace,
          foregroundColor: chrome.foregroundColor,
          elevation: chrome.elevation,
          leading: _zBuildLeading(
            context,
            _controller,
            widget.leading,
            widget.search,
            searching,
          ),
          title: _zBuildTitleBlock(
            context,
            _controller,
            widget.title,
            widget.subtitle,
            widget.search,
            searching,
            titleTextStyle: widget.titleTextStyle,
            subtitleTextStyle: widget.subtitleTextStyle,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Composition UNIQUE du `bottom:` (partagée avec le mode fixe): sans
    // `aboveTabBar`, `_zAppBarBottom` rend le `TabBar` tel quel — ou `null`.
    final PreferredSizeWidget? bottom = _zAppBarBottom(
      aboveTabBar: widget.aboveTabBar,
      aboveTabBarHeight: widget.aboveTabBarHeight,
      tabBar: _hasTabs
          ? _zTabBar(
              context,
              widget.tabs!,
              widget.tabController,
              widget.tabAlignment,
              widget.tabLabelStyle,
              widget.tabUnselectedLabelStyle,
            )
          : null,
    );
    if (_hasTabs) {
      return _zWrapTabs(
        length: widget.tabs!.length,
        controller: widget.tabController,
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => <Widget>[
            _sliverAppBar(context, bottom: bottom),
          ],
          body: _buildTabBody(),
        ),
      );
    }
    return CustomScrollView(
      slivers: <Widget>[
        _sliverAppBar(context, bottom: bottom),
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
