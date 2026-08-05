part of 'z_page_shell.dart';

/// App-bar **recherchable** déclarative et thémable (SUF-1, AC1–AC8, AC12–AC14).
///
/// Utilisable seule via `Scaffold(appBar: ZSearchableAppBar(...))` — elle
/// `implements PreferredSizeWidget`. Détient son **propre** état de recherche
/// (aucun contrôleur externe requis, AD-2/AD-15). Le titre morphe en champ de
/// recherche quand [search] est configurée et que la loupe est activée ; la
/// frappe ne reconstruit que la tranche app-bar.
///
/// Toutes les couleurs/typo dérivent de `Theme.of(context)` (aucun littéral),
/// les libellés du hint/tooltips sont résolus par l10n injectée (repli
/// `MaterialLocalizations`), la mise en page est directionnelle (RTL-safe).
class ZSearchableAppBar extends StatefulWidget implements PreferredSizeWidget {
  /// Construit l'app-bar. [title] est un `Widget` ou un `String` (→ `Text`).
  /// [actions] par défaut vide (aucun bouton fantôme). [search] nul ⇒ aucune
  /// recherche possible. [bottom] optionnel (ex. `TabBar`) participe à la
  /// hauteur préférée.
  const ZSearchableAppBar({
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.bottom,
    this.gradientKey,
    this.titleTextStyle,
    this.subtitleTextStyle,
    super.key,
  }) : assert(
         title is Widget || title is String,
         'title doit être un Widget ou un String',
       ),
       _controller = null;

  /// Variante interne : le contrôleur est détenu par `ZPageScaffold` afin de
  /// traverser un changement de branche fixe/sliver sans perdre la recherche.
  const ZSearchableAppBar._controlled({
    required this.title,
    required _ZSearchController this._controller,
    this.subtitle,
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.bottom,
    this.gradientKey,
    this.titleTextStyle,
    this.subtitleTextStyle,
  }) : assert(
         title is Widget || title is String,
         'title doit être un Widget ou un String',
       );

  /// Titre : `Widget` rendu tel quel, ou `String` emballé dans un `Text`.
  final Object title;

  /// Typographie du TITRE (**CR-IFFD-63**) — priorité **paramètre > jeton
  /// `ZcrudTheme.pageHeaderTitleStyle` > défaut de l'app-bar de l'hôte**.
  ///
  /// `null` des deux côtés ⇒ **aucune** enveloppe de style dans l'arbre : le
  /// titre est rendu exactement comme avant (`AppBarTheme.titleTextStyle`,
  /// repli `TextTheme.titleLarge`).
  ///
  /// 🔴 Seules les **métriques** sont retenues (taille, graisse, style, famille,
  /// interlettrage, interlignage). La **couleur est ignorée** : elle reste
  /// héritée du `foregroundColor` de l'app-bar — sans quoi un titre deviendrait
  /// illisible sous un dégradé d'identité (`gradientKey`). Pour imposer une
  /// couleur de premier plan, c'est `ZForegroundOverride` (zcrud_core) ou le
  /// `AppBarTheme` de l'hôte, jamais ce paramètre.
  ///
  /// ⚠️ Sans effet en **mode recherche** : le titre cède alors la place au champ
  /// de saisie, qui n'est pas un titre.
  ///
  /// ## Ellipse : ce qui la déplace, et ce qui ne la déplace pas (mesuré)
  ///
  /// La largeur **offerte** au titre — donc le seuil d'ellipse — ne dépend pas
  /// du style mais de la place restante. Mesuré (mode fixe, densité 1.0) :
  ///
  /// | écran  | sans leading ni action | avec leading + 1 action |
  /// |--------|------------------------|-------------------------|
  /// | 320 dp | 288 dp                 | 184 dp                  |
  /// | 400 dp | 368 dp                 | 264 dp                  |
  /// | 600 dp | 568 dp                 | 464 dp                  |
  ///
  /// Ce qui la déplace : la **taille**. À 368 dp de large, `titleLarge` (22)
  /// laisse ≈ 16 caractères ; 24 ⇒ 15 ; 26 ⇒ 14 ; 28 ⇒ 13.
  ///
  /// 🔴 Ce qui **ne** la déplace **pas** dans nos mesures : la **graisse** (la
  /// police du harnais de test a des avances indépendantes du poids — largeur
  /// strictement identique en w400/w500/w600/w700). Sur une police réelle un
  /// tracé gras est un peu plus large : l'effet existe, mais il n'est pas
  /// mesurable ici et n'a donc PAS été chiffré.
  ///
  /// ⚠️ **Le facteur d'échelle de texte sature.** `AppBar` borne le
  /// `textScaler` du titre à **1.34** : à 22 dp de base, la taille effective
  /// plafonne à **29,5 dp** et le seuil d'ellipse à ≈ 12 caractères pour 368 dp
  /// — identique à `textScaler` 1.6, 2.0 ou 3.0 (mesuré). Le titre s'**ellipse**
  /// donc, il n'est jamais rogné horizontalement, et la hauteur de sa boîte
  /// plafonne à 37 dp.
  final TextStyle? titleTextStyle;

  /// Typographie du SOUS-TITRE (**CR-IFFD-63**) — priorité **paramètre > jeton
  /// `ZcrudTheme.pageHeaderSubtitleStyle` > métriques de `TextTheme.titleSmall`**
  /// (le repli historique). Couleur ignorée, comme [titleTextStyle].
  final TextStyle? subtitleTextStyle;

  /// Sous-titre optionnel rendu **sous le titre** (CR-IFFD-34). `null` (défaut)
  /// ⇒ **absent de l'arbre** : aucune `Column` interposée, rendu strictement
  /// identique à celui d'avant l'ajout du slot. En mode recherche il n'est pas
  /// rendu (le champ occupe la zone titre). Voir `_zBuildTitleBlock` pour
  /// l'arbitrage de nommage (`subtitle` vs `belowSubtitle`).
  final Widget? subtitle;

  /// Identité **opaque et persistante** de l'entité ouverte (ex. l'id du
  /// dossier), passée à la couture `zResolveGradient` de `zcrud_core`
  /// (CR-IFFD-34) — jamais un index de liste, de tri ou de pagination.
  ///
  /// 🔴 Le dégradé n'apparaît **que** si l'hôte a injecté un
  /// `ZcrudScope.gradientResolver` **et** que celui-ci rend une spec pour cette
  /// clé. Sans injection (ou clé nulle/vide, ou resolver rendant `null`) le
  /// rendu est **inchangé** : c'est l'invariant de neutralité de VIS-1, aucun
  /// repli dérivé n'est appliqué automatiquement.
  final String? gradientKey;

  /// Leading optionnel (rendu **si et seulement si** fourni — AC1).
  final Widget? leading;

  /// Actions déclarées en données (absentes si non fournies — AC2).
  final List<ZAppBarAction> actions;

  /// Configuration de recherche (nulle ⇒ pas de loupe, pas de champ — AC8).
  final ZAppBarSearchConfig? search;

  /// Contenu bas optionnel (ex. `TabBar`) — participe à [preferredSize].
  final PreferredSizeWidget? bottom;

  final _ZSearchController? _controller;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  State<ZSearchableAppBar> createState() => ZSearchableAppBarState();
}

/// État de [ZSearchableAppBar]. Public pour servir de **seam de test** (R3) :
/// [queryListenable] expose la query détenue par le widget (AC5/AC6). N'expose
/// aucune mutation — l'état reste propriété exclusive du widget.
class ZSearchableAppBarState extends State<ZSearchableAppBar> {
  late final _ZSearchController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    // La config est lue à l'ÉMISSION (`() => widget.search`), jamais copiée :
    // une `ZAppBarSearchConfig` remplacée (closure recréée au build de l'hôte)
    // est donc prise en compte immédiatement, sans perte silencieuse.
    _ownsController = widget._controller == null;
    _controller = widget._controller ?? _ZSearchController(() => widget.search);
  }

  @override
  void didUpdateWidget(ZSearchableAppBar oldWidget) {
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

  /// Query détenue par le widget (lecture seule) — seam de test R3 (AC5/AC6).
  @visibleForTesting
  ValueListenable<String> get queryListenable => _controller.query;

  @override
  Widget build(BuildContext context) {
    // Rebuild GRANULAIRE : seule la bascule recherche (isSearching) reconstruit
    // l'app-bar. La frappe (query) ne rebâtit rien ici — le TextField gère son
    // texte via son controller (SM-1 / AD-2).
    return ValueListenableBuilder<bool>(
      valueListenable: _controller.isSearching,
      builder: (context, searching, _) {
        // Dégradé d'identité : `null` (défaut, aucun resolver hôte) ⇒ ni
        // `flexibleSpace` ni `foregroundColor` ⇒ AppBar strictement inchangée.
        final ZGradientSpec? gradient = _zAppBarGradient(
          context,
          widget.gradientKey,
        );
        return AppBar(
          flexibleSpace: _zGradientFlexibleSpace(gradient),
          foregroundColor: gradient?.onGradient,
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
          bottom: widget.bottom,
        );
      },
    );
  }
}
