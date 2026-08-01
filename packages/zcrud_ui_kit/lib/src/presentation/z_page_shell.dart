/// Page-shell déclaratif : `ZSearchableAppBar` (app-bar recherchable) +
/// `ZPageScaffold` (assemblage titre/actions/recherche/onglets/modes) — SUF-1.
///
/// Ce fichier est le **cœur de bibliothèque** partagé par les deux parties
/// ([ZSearchableAppBar] et [ZPageScaffold]). Il porte les briques privées
/// factorisées (contrôleur d'état de recherche `_ZSearchController`, résolution
/// de labels, constructeurs de tranches leading/titre/actions) — ainsi le motif
/// `SliverAppBar`/app-bar-recherchable qu'on élimine des applications hôtes
/// n'est **pas re-dupliqué** entre le mode fixe et le mode sliver (SUF-1, T3).
///
/// **AD-2/AD-15** : l'état de recherche (`isSearching`/`query`) est détenu par
/// un `ValueNotifier` **interne** au widget — aucun gestionnaire d'état importé
/// (`get`/`flutter_riverpod`/`provider`), aucun contrôleur externe requis. La
/// frappe reconstruit **seulement** la tranche app-bar (via
/// `ValueListenableBuilder`), jamais le corps des onglets (SM-1).
///
/// **AD-13** : insets/positions **directionnels** (RTL-safe), `Semantics`
/// explicites, cibles ≥ 48 dp, `const` là où l'immuabilité le permet.
///
/// **AD-29** : dépend UNIQUEMENT de `zcrud_core` (+ flutter) et **consomme** ses
/// seams (`ZcrudScope`/`ZcrudLocalizations`) en lecture, avec repli sur
/// `MaterialLocalizations` — aucun symbole de `zcrud_core` redéclaré/ré-exporté.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_app_bar_action.dart';
import '../domain/z_app_bar_search_config.dart';
import '../domain/z_page_app_bar_mode.dart';
import '../domain/z_page_tab.dart';

part 'z_page_scaffold.dart';
part 'z_page_shell_body.dart';
part 'z_searchable_app_bar.dart';

/// Contrôleur d'état de recherche **détenu par le widget** (AD-2/AD-15).
///
/// Propriétaire unique de `isSearching`/`query` + du `TextEditingController` et
/// du `FocusNode` (créés une fois, `dispose`és une fois — jamais recréés au
/// rebuild). Aucun état global, aucun singleton : chaque app-bar a le sien.
///
/// **La config n'est jamais copiée** : elle est lue **au moment de l'émission**
/// via [_configOf] (`() => widget.search`). `ZAppBarSearchConfig` est une valeur
/// `@immutable` que l'hôte remplace à chaque `build` (son `onQueryChanged` est
/// typiquement une closure recréée capturant l'onglet/dossier courant) —
/// capturer la première instance figerait le point d'émission et perdrait la
/// frappe **en silence**. Le rendu (hint/icône) et l'émission lisent donc
/// **la même** config fraîche.
class _ZSearchController {
  _ZSearchController(this._configOf)
    : _isSearching = ValueNotifier<bool>(false),
      query = ValueNotifier<String>(_configOf()?.initialQuery ?? ''),
      textController = TextEditingController(
        text: _configOf()?.initialQuery ?? '',
      ),
      focusNode = FocusNode();

  /// Accès **paresseux** à la config courante du widget propriétaire (jamais
  /// une copie : relu à chaque émission).
  final ZAppBarSearchConfig? Function() _configOf;
  final ValueNotifier<bool> _isSearching;

  /// Query détenue par le widget (source de vérité de la saisie).
  final ValueNotifier<String> query;

  /// Contrôleur de saisie (état d'entrée détenu par le widget).
  final TextEditingController textController;

  /// Focus du champ de recherche (autofocus à l'ouverture).
  final FocusNode focusNode;

  /// Tranche réactive de bascule recherche (lecture seule).
  ValueListenable<bool> get isSearching => _isSearching;

  /// Ouvre la recherche (morphe l'app-bar en champ, autofocus).
  void open() => _isSearching.value = true;

  /// Émet la query **exacte** : met à jour l'état détenu ET notifie l'app.
  /// La config est relue **maintenant** (jamais la copie d'un `initState`).
  void onChanged(String text) {
    query.value = text;
    _configOf()?.onQueryChanged(text);
  }

  /// Ferme la recherche : **vide** le champ, remet `query = ''`, émet `''` et
  /// restaure le titre (AC7).
  void close() {
    textController.clear();
    query.value = '';
    _isSearching.value = false;
    _configOf()?.onQueryChanged('');
  }

  /// Bascule ouvrir/fermer (fermeture ⇒ reset complet via [close]).
  void toggle() => _isSearching.value ? close() : open();

  /// Resynchronise l'état détenu quand la **prop** `search` change d'un build à
  /// l'autre (appelé depuis `didUpdateWidget` des deux propriétaires).
  ///
  /// Ne recrée **jamais** le `TextEditingController`/`FocusNode` (invariant
  /// AD-2 : pas de controller recréé au rebuild) — seul l'état déclaré change :
  /// * `search` retirée (non-null → null) ⇒ la recherche se referme et le champ
  ///   est vidé, **sans** émettre vers le callback disparu ;
  /// * `initialQuery` déclaré différemment (y compris à l'apparition d'une
  ///   config, null → non-null) ⇒ la nouvelle valeur initiale est adoptée ;
  /// * simple remplacement de la closure `onQueryChanged` ⇒ **aucun** effet sur
  ///   la saisie en cours (elle est déjà relue à l'émission).
  void didUpdateConfig(
    ZAppBarSearchConfig? previous,
    ZAppBarSearchConfig? current,
  ) {
    if (current == null) {
      if (previous == null) return;
      _isSearching.value = false;
      if (query.value.isNotEmpty) {
        textController.clear();
        query.value = '';
      }
      return;
    }
    if (previous?.initialQuery == current.initialQuery) return;
    // Nouvelle valeur initiale DÉCLARÉE : elle prime sur la saisie précédente.
    textController.value = TextEditingValue(
      text: current.initialQuery,
      selection: TextSelection.collapsed(offset: current.initialQuery.length),
    );
    query.value = current.initialQuery;
  }

  void dispose() {
    _isSearching.dispose();
    query.dispose();
    textController.dispose();
    focusNode.dispose();
  }
}

/// `TabBar` déclaratif **partagé** par [ZPageScaffold] (mode fixe) et
/// [ZPageShellBody] (modes sliver) — le motif n'est écrit qu'une fois.
PreferredSizeWidget _zTabBar(
  List<ZPageTab> tabs,
  TabController? controller,
  TabAlignment? tabAlignment,
) => TabBar(
  controller: controller,
  tabAlignment: tabAlignment,
  isScrollable: true,
  tabs: <Widget>[
    for (final tab in tabs)
      Tab(text: tab.label, icon: tab.icon == null ? null : Icon(tab.icon)),
  ],
);

/// `TabBarView` déclaratif **partagé** (mêmes propriétaires que [_zTabBar]).
Widget _zTabBarView(List<ZPageTab> tabs, TabController? controller) =>
    TabBarView(
      controller: controller,
      children: <Widget>[
        for (final tab in tabs) Builder(builder: tab.contentBuilder),
      ],
    );

/// Fournit un `DefaultTabController` **seulement** si aucun contrôleur n'est
/// injecté (sinon `TabBar`/`TabBarView` reçoivent celui de l'hôte).
Widget _zWrapTabs({
  required Widget child,
  required int length,
  required TabController? controller,
}) => controller != null
    ? child
    : DefaultTabController(length: length, child: child);

/// Résout un libellé par composition défensive (AD-13/AD-10) :
/// `ZcrudScope.labels` → `ZcrudLocalizations` → `MaterialLocalizations`.
/// Jamais de throw, jamais de chaîne codée en dur.
String _resolveSearchLabel(BuildContext context) =>
    ZcrudScope.maybeOf(context)?.labels?.maybeResolve('search') ??
    ZcrudLocalizations.maybeOf(context)?.maybeResolve('search') ??
    MaterialLocalizations.of(context).searchFieldLabel;

/// Idem pour le libellé de fermeture (`'close'`).
String _resolveCloseLabel(BuildContext context) =>
    ZcrudScope.maybeOf(context)?.labels?.maybeResolve('close') ??
    ZcrudLocalizations.maybeOf(context)?.maybeResolve('close') ??
    MaterialLocalizations.of(context).closeButtonTooltip;

/// Emballe un titre déclaratif (`Widget` tel quel, ou `String` → `Text`).
Widget _resolveTitleWidget(Object title) =>
    title is Widget ? title : Text(title as String);

/// Tranche **leading** partagée (fixe + sliver). En mode recherche, un bouton
/// retour (`close`) ; sinon le [leading] fourni (nul ⇒ **absent**, AC1).
Widget? _zBuildLeading(
  BuildContext context,
  _ZSearchController controller,
  Widget? leading,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  if (search != null && searching) {
    return IconButton(
      icon: Icon(Icons.arrow_back, semanticLabel: _resolveCloseLabel(context)),
      tooltip: _resolveCloseLabel(context),
      onPressed: controller.close,
    );
  }
  return leading;
}

/// Tranche **titre** partagée : le champ de recherche (autofocus, `Échap` ⇒
/// fermeture) en mode recherche, sinon le titre déclaratif (AC4).
Widget _zBuildTitle(
  BuildContext context,
  _ZSearchController controller,
  Object title,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  if (search != null && searching) {
    final String hint = search.hintLabel ?? _resolveSearchLabel(context);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): controller.close,
      },
      child: TextField(
        controller: controller.textController,
        focusNode: controller.focusNode,
        autofocus: true,
        textInputAction: TextInputAction.search,
        textAlign: TextAlign.start,
        onChanged: controller.onChanged,
        style: Theme.of(context).textTheme.titleLarge,
        decoration: InputDecoration(hintText: hint, border: InputBorder.none),
      ),
    );
  }
  return _resolveTitleWidget(title);
}

/// Tranche **titre + sous-titre** partagée (CR-IFFD-34) — mode fixe ET slivers.
///
/// 🔴 **Défaut strictement inchangé** : [subtitle] nul ⇒ cette fonction rend
/// **exactement** ce que rendait [_zBuildTitle] (le titre nu), sans `Column`
/// interposée, sans boîte vide. Aucun hôte existant ne voit son arbre bouger.
///
/// En mode recherche le titre morphe en champ de saisie : le sous-titre est
/// alors **absent de l'arbre** (il qualifie le titre, pas la requête, et le
/// champ occupe déjà la zone titre).
///
/// **Nommage — pourquoi `subtitle` et non `belowSubtitle`** : sur les cartes
/// (`ZStudyToolsItemCard`/`ZStudyNoteCard`/`ZFolderCard`) `belowSubtitle`
/// désigne un slot rendu **sous un sous-titre déjà existant**. Une app-bar n'a
/// pas de sous-titre : ce slot **EST** le sous-titre. Réutiliser
/// `belowSubtitle` ici nommerait une position relative à un élément absent —
/// donc une 4ᵉ sémantique déguisée en 3ᵉ. Le nom `subtitle` décrit ce que la
/// chose est ; le **type** (`Widget?`) et le **traitement** (`null` ⇒ absence
/// structurelle, contenu opaque, sémantique laissée au widget de l'hôte)
/// restent identiques aux slots des cartes.
Widget _zBuildTitleBlock(
  BuildContext context,
  _ZSearchController controller,
  Object title,
  Widget? subtitle,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  final Widget titleSlice = _zBuildTitle(
    context,
    controller,
    title,
    search,
    searching,
  );
  if (subtitle == null || (search != null && searching)) return titleSlice;
  return Column(
    mainAxisSize: MainAxisSize.min,
    // `CrossAxisAlignment.start` est DIRECTIONNEL (AD-13) : jamais `left`.
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[titleSlice, _zSubtitleSlice(context, subtitle)],
  );
}

/// Sous-titre d'app-bar : métriques **dérivées du thème** (`titleSmall`), jamais
/// de littéral. 🔴 La **couleur n'est pas touchée** : elle reste héritée du
/// `DefaultTextStyle` de l'app-bar (donc du `foregroundColor`, y compris celui
/// imposé par un dégradé d'identité). Forcer ici une couleur de `textTheme`
/// rendrait le sous-titre illisible sur une app-bar teintée.
Widget _zSubtitleSlice(BuildContext context, Widget subtitle) {
  final TextStyle? small = Theme.of(context).textTheme.titleSmall;
  return DefaultTextStyle.merge(
    style: TextStyle(
      fontSize: small?.fontSize,
      fontWeight: small?.fontWeight,
      letterSpacing: small?.letterSpacing,
      height: small?.height,
    ),
    child: subtitle,
  );
}

/// Dégradé d'identité de l'app-bar (CR-IFFD-34) — **réutilise** la couture
/// `zResolveGradient` de `zcrud_core` (v0.20.0), celle-là même que consomme
/// `ZFolderCardGradientAccent` : la même entité colore donc sa carte ET l'en-tête
/// de sa page, par le même seam.
///
/// 🔴 **Chaîne inchangée : seam hôte → `null`.** Aucun repli dérivé n'est
/// réintroduit ici (`zDerivedGradientResolver` reste OPT-IN, arbitrage VIS-1
/// AC4/AC9) : sans `ZcrudScope.gradientResolver` injecté, ou avec une clé nulle
/// ou vide, ou si le resolver de l'hôte rend `null`, cette fonction rend `null`
/// et l'app-bar est **strictement identique** à ce qu'elle était.
ZGradientSpec? _zAppBarGradient(BuildContext context, String? gradientKey) {
  if (gradientKey == null || gradientKey.isEmpty) return null;
  return zResolveGradient(context, gradientKey);
}

/// Fond dégradé de l'app-bar (`null` ⇒ slot `flexibleSpace` **absent**).
/// `Container` (et non `DecoratedBox`) : sans enfant il occupe les contraintes
/// que lui passe la `Stack` de l'app-bar — c'est l'idiome Flutter du fond plein.
Widget? _zGradientFlexibleSpace(ZGradientSpec? spec) => spec == null
    ? null
    : Container(decoration: BoxDecoration(gradient: spec.gradient));

/// Tranche **actions** partagée : chaque [ZAppBarAction] non-débordement rend
/// **un** `IconButton` (cible ≥ 48 dp par défaut, `Semantics` via
/// `Icon.semanticLabel`) ; les actions `isOverflow` alimentent un
/// `PopupMenuButton` ; la loupe/close de recherche est ajoutée si [search]
/// est configurée (AC2/AC3/AC4/AC8).
List<Widget> _zBuildActions(
  BuildContext context,
  _ZSearchController controller,
  List<ZAppBarAction> actions,
  ZAppBarSearchConfig? search,
  bool searching,
) {
  final inline = <ZAppBarAction>[];
  final overflow = <ZAppBarAction>[];
  for (final action in actions) {
    (action.isOverflow ? overflow : inline).add(action);
  }
  return <Widget>[
    if (!(searching && (search?.hidesHostActions ?? false)))
      for (final action in inline)
        IconButton(
          icon: _zActionChild(action),
          tooltip: action.tooltip,
          onPressed: action.onPressed,
        ),
    if (overflow.isNotEmpty &&
        !(searching && (search?.hidesHostActions ?? false)))
      // 🔴 Résolution par IDENTITÉ, JAMAIS par position (CR-MENU) : la valeur
      // portée par chaque entrée est l'ACTION elle-même, pas son index. Avec
      // `value: i` + `overflow[i]`, la liste était relue APRÈS la sélection :
      // un rebuild de l'app-bar (props réactives — `ZPageShell` rebâtit ses
      // actions à chaque notification) qui RÉORDONNE le débordement entre
      // l'ouverture et le tap exécutait une AUTRE action, sans aucune trace ;
      // un rebuild qui le RACCOURCIT levait un `RangeError` dans un
      // gestionnaire de tap. Même lecture que `ZDefaultMenuRenderer`
      // (`zcrud_menu`, `PopupMenuButton<ZMenuEntry>`).
      PopupMenuButton<ZAppBarAction>(
        icon: const Icon(Icons.more_vert),
        itemBuilder: (context) => <PopupMenuEntry<ZAppBarAction>>[
          for (final action in overflow)
            PopupMenuItem<ZAppBarAction>(
              value: action,
              enabled: action.onPressed != null,
              child: Row(
                children: <Widget>[
                  _zActionChild(action),
                  const SizedBox(width: 12),
                  Text(action.semanticLabel),
                ],
              ),
            ),
        ],
        onSelected: (action) => action.onPressed?.call(),
      ),
    if (search != null)
      IconButton(
        icon: Icon(
          searching ? Icons.close : Icons.search,
          semanticLabel: searching
              ? _resolveCloseLabel(context)
              : _resolveSearchLabel(context),
        ),
        tooltip: searching
            ? _resolveCloseLabel(context)
            : _resolveSearchLabel(context),
        onPressed: controller.toggle,
      ),
  ];
}

/// Contenu d'action avec sémantique explicite, quelle que soit sa forme.
///
/// 🔴 `ExcludeSemantics` est INDISPENSABLE sur le chemin widget (CR-LEX-58).
/// MESURÉ sans lui, avec `child: CircleAvatar(child: Text('ZD'))` et
/// `semanticLabel: 'PROFIL'` : le nœud fusionné portait `'PROFIL\nZD'` — le
/// texte interne du widget FUYAIT dans le libellé, et un lecteur d'écran
/// annonçait « PROFIL ZD ». Quand l'hôte fournit un `semanticLabel` explicite,
/// il fait AUTORITÉ : le contenu visuel ne doit pas s'y concaténer.
/// Sans objet sur le chemin icône (`Icon` sans `semanticLabel` n'émet rien),
/// donc aucune régression de ce côté.
Widget _zActionChild(ZAppBarAction action) => Semantics(
  label: action.semanticLabel,
  child: ExcludeSemantics(child: action.child ?? Icon(action.icon)),
);
