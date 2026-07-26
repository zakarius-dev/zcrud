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
    this.leading,
    this.actions = const <ZAppBarAction>[],
    this.search,
    this.bottom,
    super.key,
  }) : assert(
          title is Widget || title is String,
          'title doit être un Widget ou un String',
        );

  /// Titre : `Widget` rendu tel quel, ou `String` emballé dans un `Text`.
  final Object title;

  /// Leading optionnel (rendu **si et seulement si** fourni — AC1).
  final Widget? leading;

  /// Actions déclarées en données (absentes si non fournies — AC2).
  final List<ZAppBarAction> actions;

  /// Configuration de recherche (nulle ⇒ pas de loupe, pas de champ — AC8).
  final ZAppBarSearchConfig? search;

  /// Contenu bas optionnel (ex. `TabBar`) — participe à [preferredSize].
  final PreferredSizeWidget? bottom;

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

  @override
  void initState() {
    super.initState();
    // La config est lue à l'ÉMISSION (`() => widget.search`), jamais copiée :
    // une `ZAppBarSearchConfig` remplacée (closure recréée au build de l'hôte)
    // est donc prise en compte immédiatement, sans perte silencieuse.
    _controller = _ZSearchController(() => widget.search);
  }

  @override
  void didUpdateWidget(ZSearchableAppBar oldWidget) {
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
        return AppBar(
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
          bottom: widget.bottom,
        );
      },
    );
  }
}
