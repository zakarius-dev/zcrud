/// `ZTabbedList` — **onglets de catégorisation** de listes du cœur `zcrud_core`
/// (AD-8/AD-13/AD-2/AD-15).
///
/// Un chrome `TabBar`/`TabBarView` **pur-Flutter Material** où **chaque
/// onglet est une [DynamicList]/`ZListController` indépendante** (typiquement
/// catégorisée par un filtre via `baseFilters`). L'**état de chaque onglet
/// est PRÉSERVÉ** au changement d'onglet (recherche / tri / pagination /
/// **sélection** / scroll) : chaque page est enveloppée dans un
/// `_KeepAliveTabPage` (`AutomaticKeepAliveClientMixin`, `wantKeepAlive =>
/// true`) → son sous-arbre (et le `State` portant ses contrôleurs) est monté
/// **une fois** et **conservé** — les contrôleurs ne sont ni recréés ni
/// disposés au switch (équivalent « liste » du principe AD-2 : état stable,
/// pas recréé au rebuild).
///
/// **Sélection INDÉPENDANTE par onglet** : chaque onglet possède sa **propre**
/// `ZListSelectionController` (créée dans son `builder`) — sélectionner dans un
/// onglet n'affecte jamais les autres.
///
/// Le chrome des onglets est **pur-Flutter Material** (`TabBar`/
/// `TabBarView`, déjà dans `flutter/material.dart`) ; les listes ne rendent
/// Syncfusion QUE si l'app a injecté `ZSfDataGridRenderer` via `ZcrudScope`
/// (sinon layout `builder`/`custom` neutre). Ce fichier n'importe JAMAIS
/// `zcrud_list`/Syncfusion.
///
/// **Neutre (AD-2/AD-15)** : imports limités à `package:flutter/material.dart` +
/// types `zcrud_core`. AUCUN gestionnaire d'état.
library;

import 'package:flutter/material.dart';

import '../../domain/ports/z_acl.dart';
import '../l10n/z_localizations.dart';
import '../zcrud_scope.dart';
import 'z_list_tab.dart';

/// Onglets de catégorisation : `TabBar` (N onglets) + `TabBarView` (une liste
/// indépendante par onglet, état préservé au switch).
class ZTabbedList extends StatefulWidget {
  /// Construit les onglets à partir de [tabs]. [initialIndex] fixe l'onglet actif
  /// initial ; [onTabChanged] est notifié à chaque changement d'onglet ;
  /// [isScrollable] rend la barre défilante (nombreux onglets) ;
  /// [tabAlignment] règle l'alignement des onglets dans la barre ; [header]
  /// pose un widget partagé au-dessus de la barre d'onglets ;
  /// [activeIndexNotifier] suit l'index de l'onglet actif.
  const ZTabbedList({
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
    this.isScrollable = false,
    this.tabAlignment,
    this.header,
    this.activeIndexNotifier,
    super.key,
  });

  /// Descripteurs d'onglets (libellé l10n + icône + builder de vue).
  final List<ZListTab> tabs;

  /// Index de l'onglet actif initial.
  final int initialIndex;

  /// Notifié à chaque changement d'onglet (nouvel index). N'est **pas**
  /// notifié à la construction (l'onglet initial est connu de l'appelant via
  /// [initialIndex]) — pour suivre l'onglet actif y compris à l'initialisation,
  /// utiliser [activeIndexNotifier].
  final ValueChanged<int>? onTabChanged;

  /// Barre d'onglets défilante (défaut `false`).
  final bool isScrollable;

  /// Alignement des onglets dans la barre, **propagé tel quel** à
  /// `TabBar.tabAlignment`.
  ///
  /// `null` (défaut) ⇒ **rien n'est déclaré** : le `TabBar` conserve la
  /// résolution Flutter, qui dépend de [isScrollable] — `TabAlignment.fill`
  /// (onglets répartis sur toute la largeur) sur une barre fixe,
  /// `TabAlignment.startOffset` sur une barre défilante.
  ///
  /// `TabAlignment.startOffset` réserve un décrochage de tête avant le premier
  /// onglet ; avec des libellés longs dans une fenêtre étroite, il pousse les
  /// derniers onglets d'autant plus loin hors du viewport.
  /// `TabAlignment.start` supprime ce décrochage et colle le premier onglet au
  /// bord de tête : c'est la valeur à déclarer quand la barre doit tenir le
  /// plus d'onglets possible dans une fenêtre étroite.
  ///
  /// **Combinaisons interdites par Flutter** (assertion du SDK, pas du widget) :
  /// `TabAlignment.fill` avec `isScrollable: true` ; `TabAlignment.start` et
  /// `TabAlignment.startOffset` avec `isScrollable: false`. `center` est
  /// valide dans les deux modes. Le widget ne corrige ni ne filtre la valeur —
  /// le choix, et sa cohérence avec [isScrollable], appartiennent à
  /// l'appelant.
  final TabAlignment? tabAlignment;

  /// Widget **partagé** optionnel posé **au-dessus de la barre d'onglets**,
  /// dans le même arbre (typiquement une barre de recherche commune aux
  /// onglets). `null` (défaut) = aucun en-tête, rendu inchangé.
  ///
  /// **Honnêteté sur la performance** : ce seam règle le *placement* du widget
  /// partagé, pas le coût d'une recherche diffusée à **tous** les onglets à
  /// chaque frappe (chaque page keep-alive refiltrerait alors ses lignes alors
  /// qu'une seule est visible). Recommandation : que le `header` ne
  /// redistribue sa saisie qu'à l'onglet **actif** (lu via
  /// [activeIndexNotifier]), en la ré-appliquant au changement d'onglet.
  final Widget? header;

  /// Notifieur **possédé par l'appelant** (create/dispose côté hôte), tenu
  /// synchronisé par le widget avec l'**index de l'onglet actif** : positionné
  /// à l'index initial effectif dès le montage, puis à chaque changement
  /// d'onglet (tap **ou** swipe), **avant** l'appel de [onTabChanged].
  ///
  /// Lu comme `ValueListenable<int>`, il évite à l'hôte de dupliquer un
  /// `_activeIndex` maintenu à la main : un geste de création lit par exemple
  /// `tabs[notifier.value].defaultItemBuilder` / `tabs[notifier.value].canCreate`
  /// pour hériter du contexte (et de l'autorisation) du segment courant.
  ///
  /// Le flux est à **sens unique** (widget → hôte) : écrire dans ce notifieur
  /// côté hôte ne change **pas** l'onglet actif (la valeur serait écrasée à la
  /// prochaine synchronisation) — l'onglet initial se pilote par
  /// [initialIndex], le changement par le geste de l'usager.
  ///
  /// `null` (défaut) = aucun suivi, comportement antérieur inchangé.
  final ValueNotifier<int>? activeIndexNotifier;

  @override
  State<ZTabbedList> createState() => _ZTabbedListState();
}

class _ZTabbedListState extends State<ZTabbedList>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Les `resolvedPageKey` (pageKey ?? labelKey) servent de clés de page
    // (`ValueKey('zTab_<resolvedPageKey>')`) — un doublon provoquerait une
    // collision de clés dans le `TabBarView`. On l'attrape tôt avec un message
    // actionnable. Deux onglets HOMONYMES à `pageKey` distinctes sont valides.
    assert(
      widget.tabs.map((t) => t.resolvedPageKey).toSet().length ==
          widget.tabs.length,
      'ZTabbedList : les clés de page des onglets (pageKey, repli labelKey) '
      'doivent être uniques. Doublon détecté dans '
      '${widget.tabs.map((t) => t.resolvedPageKey).toList()} — donner une '
      '`pageKey` distincte aux onglets homonymes.',
    );
    _tabController = _createController();
    // Suivi de l'onglet actif : positionné dès le montage à l'index initial
    // effectif (clampé) — sans passer par `onTabChanged` (timing préservé).
    _publishActiveIndex();
  }

  /// Porte l'index actif dans le notifieur de l'hôte, **sans jamais notifier
  /// pendant une construction**.
  ///
  /// Le montage d'un `ZTabbedList` a lieu au milieu du `build` de son parent :
  /// y écrire une valeur *différente* réveillerait sur-le-champ des abonnés que
  /// le framework est en train de construire. Quand la valeur est déjà la
  /// bonne — le cas de très loin le plus courant, un notifieur neuf sur
  /// l'onglet initial — rien n'est notifié et le timing reste celui d'avant.
  /// Quand elle diffère (remontage au-dessus d'un notifieur déjà avancé, ou
  /// `initialIndex` non nul), la mise à jour est reportée à la fin de la frame
  /// courante : l'hôte l'obtient toujours, une frame plus tard, au lieu d'une
  /// exception de construction.
  void _publishActiveIndex() {
    final notifier = widget.activeIndexNotifier;
    if (notifier == null) return;
    final index = _tabController.index;
    if (notifier.value == index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.activeIndexNotifier?.value = index;
    });
  }

  TabController _createController() {
    final controller = TabController(
      length: widget.tabs.length,
      initialIndex: widget.initialIndex.clamp(
        0,
        widget.tabs.isEmpty ? 0 : widget.tabs.length - 1,
      ),
      vsync: this,
    );
    controller.addListener(_handleTabChange);
    return controller;
  }

  void _handleTabChange() {
    // Notifie une seule fois par sélection (ignore les frames intermédiaires de
    // l'animation d'indicateur).
    if (_tabController.indexIsChanging) return;
    // Le notifieur d'index actif est mis à jour AVANT le callback : un
    // `onTabChanged` qui lit `activeIndexNotifier.value` voit le nouvel index.
    widget.activeIndexNotifier?.value = _tabController.index;
    widget.onTabChanged?.call(_tabController.index);
  }

  @override
  void didUpdateWidget(covariant ZTabbedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le nombre d'onglets change ⇒ recycle le `TabController` (longueur figée).
    if (oldWidget.tabs.length != widget.tabs.length) {
      _tabController
        ..removeListener(_handleTabChange)
        ..dispose();
      _tabController = _createController();
    }
    // Nouveau notifieur (ou controller recyclé) ⇒ resynchronise l'index actif.
    if (oldWidget.activeIndexNotifier != widget.activeIndexNotifier ||
        oldWidget.tabs.length != widget.tabs.length) {
      _publishActiveIndex();
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

  /// Builder de page de [tab], **enrichi de sa restriction de droits**.
  ///
  /// Sans `ZListTab.acl`, c'est le builder de l'onglet tel quel : rien ne
  /// s'interpose, l'arbre est identique à celui d'avant. Avec, la page est
  /// enveloppée d'un scope dont l'ACL est la **conjonction** de celle qui
  /// englobe les onglets et de celle de l'onglet — les listes construites par
  /// le builder la lisent alors comme n'importe quelle ACL ambiante.
  ///
  /// Le niveau englobant est lu par le scope ambiant, et **retombe sur le
  /// refus** quand aucun n'est monté : déclarer des droits sur un onglet ne
  /// crée jamais un droit à partir de rien.
  ///
  /// **Onglet sans vue** (`ZListTab.builder` à `null`, dit *assemblé*) : sa
  /// page est laissée **vide**. Un tel onglet ne déclare que sa catégorie et
  /// ses droits, et attend d'un **assembleur** (`ZCrudScreen`) qu'il lui
  /// fournisse une vue avant de le monter ; monté nu, il n'a rien à rendre —
  /// et le rendre vide vaut mieux que lever (AD-10).
  WidgetBuilder _pageBuilderFor(ZListTab tab) {
    final declared = tab.builder;
    if (declared == null) return _emptyPage;
    final tabAcl = tab.acl;
    if (tabAcl == null) return declared;
    return (pageContext) => ZcrudScope.derive(
          pageContext,
          acl: ZRestrictedAcl(
            ZcrudScope.maybeOf(pageContext)?.acl ?? const ZDenyAllAcl(),
            tabAcl,
          ),
          child: Builder(builder: declared),
        );
  }

  /// Page d'un onglet **sans vue déclarée** : rien à rendre.
  static Widget _emptyPage(BuildContext context) => const SizedBox.shrink();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // En-tête partagé optionnel — AU-DESSUS de la barre d'onglets.
        if (widget.header != null) widget.header!,
        TabBar(
          controller: _tabController,
          isScrollable: widget.isScrollable,
          // Non déclaré ⇒ `null` transmis tel quel : le `TabBar` garde sa
          // résolution Flutter (`fill` en fixe, `startOffset` en défilant).
          tabAlignment: widget.tabAlignment,
          tabs: <Widget>[
            for (final tab in widget.tabs)
              Tab(
                // Cible tactile ≥ 48 dp (AD-13).
                height: 48,
                icon: tab.icon == null ? null : Icon(tab.icon),
                child: _ZTabLabel(tab: tab),
              ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              for (final tab in widget.tabs)
                _KeepAliveTabPage(
                  // Clé stable par onglet (pageKey, repli labelKey) : préserve
                  // le `State` (donc les contrôleurs) à travers les rebuilds
                  // du parent — et survit au renommage d'un libellé si une
                  // `pageKey` est fournie.
                  key: ValueKey<String>('zTab_${tab.resolvedPageKey}'),
                  builder: _pageBuilderFor(tab),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Libellé d'un onglet, suivi de sa **pastille de comptage** quand l'onglet en
/// déclare une (`ZListTab.countOf`).
///
/// La pastille est le **seul** sous-arbre abonné au compteur : sa mise à jour
/// ne rebâtit ni la barre d'onglets ni la page (AD-2). Sans compteur déclaré,
/// le libellé est rendu tel quel — aucune pastille, aucun abonnement.
class _ZTabLabel extends StatelessWidget {
  const _ZTabLabel({required this.tab});

  final ZListTab tab;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label(context, tab.labelKey),
      textAlign: TextAlign.center,
    );
    final counter = tab.countOf;
    if (counter == null) return text;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(child: text),
        const SizedBox(width: 6),
        ValueListenableBuilder<int>(
          valueListenable: counter,
          builder: (context, count, _) => _ZTabCountChip(count: count),
        ),
      ],
    );
  }
}

/// Pastille de comptage d'un onglet : nombre lisible, couleurs **dérivées du
/// `ColorScheme`** (jamais de littéral), rien d'affiché à zéro.
///
/// Volontairement minimale et privée : le cœur ne dépend d'aucun paquet d'UI
/// (AD-1). La pastille réutilisable, avec ses variantes et son a11y complète,
/// est `ZCountBadge` dans `zcrud_ui_kit` — c'est elle qu'un assemblage doit
/// employer.
class _ZTabCountChip extends StatelessWidget {
  const _ZTabCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

/// Page d'onglet **keep-alive** : monte `builder` **une fois** et conserve son
/// sous-arbre (donc les `ZListController`/`ZListSelectionController` créés dans
/// le `builder`) au changement d'onglet (`AutomaticKeepAliveClientMixin`,
/// `wantKeepAlive => true`). Sans quoi `TabBarView` détruirait les pages hors
/// écran (perte de la recherche/tri/pagination/sélection/scroll).
class _KeepAliveTabPage extends StatefulWidget {
  const _KeepAliveTabPage({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<_KeepAliveTabPage> createState() => _KeepAliveTabPageState();
}

class _KeepAliveTabPageState extends State<_KeepAliveTabPage>
    with AutomaticKeepAliveClientMixin<_KeepAliveTabPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // requis par AutomaticKeepAliveClientMixin.
    return widget.builder(context);
  }
}
