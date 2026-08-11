part of 'z_page_shell.dart';

/// Page-shell déclaratif complet: assemble titre, leading,
/// actions, recherche, onglets et un [mode] d'app-bar (fixe vs sliver
/// repliable).
///
/// * [ZPageAppBarMode.fixed]: `Scaffold(appBar: ZSearchableAppBar(...))`,
///   corps = `TabBarView` (si [tabs]) ou [body]. Aucun `SliverAppBar`.
/// * modes sliver: le corps est délégué à [ZPageShellBody] (`SliverAppBar`
///   floating/pinned dans un `NestedScrollView` avec onglets, un
///   `CustomScrollView` sans) — **un seul** rendu sliver dans la bibliothèque.
///
/// Le rendu titre/actions/recherche est **factorisé** avec [ZSearchableAppBar]
/// (fonctions `_zBuild*` de `z_page_shell.dart`): le motif app-bar n'est pas
/// re-dupliqué entre les deux modes.
///
/// ## Slots de `Scaffold`
///
/// Ce shell **construit** le `Scaffold`: il en expose donc les slots utiles à
/// un hôte en **pass-through** ([floatingActionButton],
/// [floatingActionButtonLocation], [persistentFooterButtons], [drawer],
/// [endDrawer], [bottomNavigationBar], [bottomSheet], [backgroundColor],
/// [resizeToAvoidBottomInset], [extendBody], [extendBodyBehindAppBar]). Tous
/// sont **optionnels** et leurs valeurs par défaut sont celles de `Scaffold`:
/// un slot non fourni est **structurellement absent** (aucune boîte vide, aucun
/// `SizedBox.shrink` inerte) et le rendu est **identique** à celui d'avant leur
/// introduction.
///
/// **Un seul `Scaffold`, un seul porteur.** Quel que soit le mode, exactement
/// **un** `Scaffold` est construit — par [_scaffold], **unique** site de
/// construction: mode fixe et modes sliver sont des branches **exclusives**, et
/// le `NestedScrollView` du mode sliver+onglets n'est PAS un `Scaffold`
/// imbriqué. Les slots ne peuvent donc pas être dupliqués (FAB fantôme, double
/// tiroir): c'est le `Scaffold` **extérieur** — le seul — qui les porte, en
/// dehors de la zone défilante, comme le veut Material.
///
/// [extendBodyBehindAppBar] n'a d'effet qu'en [ZPageAppBarMode.fixed] (seul
/// mode où l'app-bar est celle du `Scaffold`); en mode sliver l'app-bar est
/// **dans** le corps défilant, l'option est donc sans objet — Flutter l'ignore,
/// aucun rendu n'est altéré.
///
/// 💡 **Hôte au `Scaffold` non trivial** (enveloppé dans un `PopScope`, ou
/// plusieurs `Scaffold` aiguillés selon l'état, ou un slot que ce pass-through
/// n'expose pas): préférer [ZPageShellBody], qui ne possède aucun `Scaffold` et
/// laisse à l'hôte **tous** ses slots, présents et futurs.
class ZPageScaffold extends StatefulWidget {
  /// Construit le shell. [title] est un `Widget` ou `String`. [tabs] nul/vide ⇒
  /// aucun `TabBar` (corps = [body]). [mode] défaut [ZPageAppBarMode.fixed].
  /// [tabController] optionnel: si fourni, le shell ne crée pas de
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
    this.aboveTabBar,
    this.aboveTabBarHeight,
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
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.tabLabelStyle,
    this.tabUnselectedLabelStyle,
    super.key,
  }) : assert(
         title is Widget || title is String,
         'title doit être un Widget ou un String',
       );

  /// Titre: `Widget` rendu tel quel, ou `String` emballé dans un `Text`.
  final Object title;

  /// Sous-titre optionnel de l'app-bar, propagé aux deux modes
  /// (fixe et sliver). Voir [ZSearchableAppBar.subtitle]: `null` (défaut) ⇒
  /// **absent de l'arbre**, rendu strictement identique à l'existant.
  final Widget? subtitle;

  /// Identité opaque de l'entité ouverte, alimentant le dégradé d'app-bar
  /// via la couture `zResolveGradient`. Voir
  /// [ZSearchableAppBar.gradientKey] : sans `ZcrudScope.gradientResolver`
  /// injecté par l'hôte, **aucun** dégradé — rendu inchangé.
  final String? gradientKey;

  /// Leading optionnel, rendu si et seulement si fourni.
  final Widget? leading;

  /// Actions déclarées en données (absentes si non fournies).
  final List<ZAppBarAction> actions;

  /// Configuration de recherche (nulle ⇒ pas de recherche).
  final ZAppBarSearchConfig? search;

  /// Onglets déclaratifs (nul/vide ⇒ aucun `TabBar`).
  final List<ZPageTab>? tabs;

  /// Corps affiché quand il n'y a **pas** d'onglets (nul ⇒ aucun corps).
  final Widget? body;

  /// Créneau de **contexte de page** rendu **entre l'app-bar et le `TabBar`**
  /// — dans le `bottom:` de l'app-bar, donc dans une zone dont la
  /// hauteur est **déclarée** et qui fait réellement grandir l'app-bar.
  ///
  /// * `null` (défaut) ⇒ **arbre strictement inchangé**: le `bottom:` reste
  ///   exactement ce qu'il était (le `TabBar` seul, ou `null` sans onglets);
  /// * avec onglets ⇒ `Column [aboveTabBar, TabBar]` de hauteur préférée égale
  ///   à la **somme** des deux;
  /// * **sans** onglets ⇒ le créneau devient à lui seul le `bottom:` de
  ///   l'app-bar;
  /// * en mode sliver, il est câblé dans le `bottom:` de la `SliverAppBar`:
  ///   `pinned` le garde visible au défilement, `floating` le replie avec
  ///   l'app-bar.
  ///
  /// **Ne pas utiliser [subtitle] pour cet usage.** `subtitle` vit dans le
  /// `title:` de l'`AppBar`, c'est-à-dire dans la toolbar de 56 dp qui **ne
  /// grandit pas**: mesuré (écran 500×800, mode fixe, 3 onglets), un
  /// `SizedBox(height: 48)` en `subtitle` laisse l'app-bar à 104 dp et
  /// **recouvre le `TabBar` de 10 dp**; un `SizedBox(height: 96)` déborde hors
  /// de l'écran par le haut (34 dp de chevauchement). Dans les deux cas **zéro
  /// exception de layout**: le défaut est totalement silencieux et le `TabBar`
  /// reste tapable sous la bande qui le recouvre. Voir `_zAppBarBottom`.
  final Widget? aboveTabBar;

  /// Hauteur **déclarée** de [aboveTabBar]. `null` (défaut) ⇒ la
  /// `preferredSize.height` du créneau s'il est un `PreferredSizeWidget`, sinon
  /// `kToolbarHeight` (56 dp).
  ///
  /// Un contenu plus haut que la hauteur déclarée produit un **débordement
  /// signalé par Flutter** (bruyant), jamais un recouvrement muet du `TabBar`.
  final double? aboveTabBarHeight;

  /// Slot rendu sous le [TabBar] et au-dessus du [TabBarView] si des onglets
  /// sont fournis. `null` conserve le corps historique sans wrapper ajouté.
  final Widget? aboveTabViews;

  /// Mode d'app-bar (fixe vs sliver repliable).
  final ZPageAppBarMode mode;

  /// `TabController` injecté optionnel (sinon `DefaultTabController` interne).
  final TabController? tabController;

  /// Alignement optionnel des onglets (`null` ⇒ comportement Flutter actuel).
  final TabAlignment? tabAlignment;

  /// `Scaffold.floatingActionButton` (nul ⇒ aucun FAB).
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
  /// thème; aucune couleur n'est codée en dur dans le package).
  final Color? backgroundColor;

  /// `Scaffold.resizeToAvoidBottomInset` (nul ⇒ défaut Flutter).
  final bool? resizeToAvoidBottomInset;

  /// `Scaffold.extendBody` (défaut `false`, comme `Scaffold`).
  final bool extendBody;

  /// `Scaffold.extendBodyBehindAppBar` (défaut `false`). Sans objet en mode
  /// sliver (cf. doc de classe).
  final bool extendBodyBehindAppBar;

  /// Typographie du TITRE de l'en-tête — priorité
  /// **paramètre > jeton `ZcrudTheme.pageHeaderTitleStyle` > défaut de
  /// l'app-bar de l'hôte**. Propagé aux DEUX modes (fixe et sliver).
  ///
  /// `null` des deux côtés ⇒ **aucune** enveloppe de style: rendu strictement
  /// inchangé. Voir [ZSearchableAppBar.titleTextStyle] pour la règle
  /// « métriques seules, couleur héritée » et son motif mesuré.
  final TextStyle? titleTextStyle;

  /// Typographie du SOUS-TITRE — priorité **paramètre > jeton
  /// `ZcrudTheme.pageHeaderSubtitleStyle` > métriques de `titleSmall`**. Sans
  /// objet si [subtitle] est nul (le slot reste absent de l'arbre).
  final TextStyle? subtitleTextStyle;

  /// Typographie du libellé d'onglet **SÉLECTIONNÉ** —
  /// priorité **paramètre > jeton
  /// `ZcrudTheme.pageHeaderTabSelectedLabelStyle` > défaut Material 3**
  /// (`TextTheme.titleSmall`).
  ///
  /// **Métriques seules, couleur ignorée** — et ce n'est pas un choix de
  /// style: `TabBar` dérive sa couleur de sélection de `labelStyle?.color`
  /// quand aucun `labelColor` n'est fourni. MESURÉ avec un style coloré des
  /// deux côtés: les onglets sélectionné et non sélectionné rendent la MÊME
  /// couleur — le canal chromatique de la sélection disparaît. Le poids doit
  /// AJOUTER un canal de distinction, jamais en retirer un (AD-13: la couleur
  /// n'est pas le seul canal, mais elle reste UN canal).
  ///
  /// Réglé SEUL, ce paramètre ne touche que l'onglet sélectionné: la
  /// retombée `unselectedLabelStyle ?? labelStyle` du SDK est explicitement
  /// neutralisée (sans quoi tous les onglets adopteraient le style
  /// « sélectionné » — mesuré).
  ///
  /// **Un libellé plus GRAND n'agrandit pas la bande d'onglets** (mesuré:
  /// `TabBar.preferredSize.height` reste 48 dp, la tuile `Tab` 46 dp, pour
  /// `fontSize` 14, 18 **et** 24). La cible tactile reste donc ≥ 48 dp, mais
  /// au-delà d'une vingtaine de dp le glyphe est rogné verticalement par le
  /// SDK. Le **poids** n'a pas cet effet: il ne change pas la hauteur de ligne.
  final TextStyle? tabLabelStyle;

  /// Typographie du libellé d'onglet **NON SÉLECTIONNÉ** —
  /// priorité **paramètre > jeton
  /// `ZcrudTheme.pageHeaderTabUnselectedLabelStyle` > défaut Material 3**.
  /// Couleur ignorée, pour le motif mesuré exposé dans [tabLabelStyle].
  final TextStyle? tabUnselectedLabelStyle;

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

  /// **Unique** site de construction du `Scaffold` du shell: les slots y sont
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
        titleTextStyle: widget.titleTextStyle,
        subtitleTextStyle: widget.subtitleTextStyle,
        bottom: _zAppBarBottom(
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
        ),
      ),
      body: _hasTabs ? _buildTabBody() : widget.body,
    );
    // Le `TabBar` vit dans l'app-bar du `Scaffold` (hors de son corps): le
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
  /// unique); les slots restent portés par le `Scaffold` extérieur.
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
      aboveTabBar: widget.aboveTabBar,
      aboveTabBarHeight: widget.aboveTabBarHeight,
      aboveTabViews: widget.aboveTabViews,
      mode: widget.mode,
      tabController: widget.tabController,
      tabAlignment: widget.tabAlignment,
      titleTextStyle: widget.titleTextStyle,
      subtitleTextStyle: widget.subtitleTextStyle,
      tabLabelStyle: widget.tabLabelStyle,
      tabUnselectedLabelStyle: widget.tabUnselectedLabelStyle,
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
