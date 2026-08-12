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

import '../l10n/z_localizations.dart';
import 'z_list_tab.dart';

/// Onglets de catégorisation : `TabBar` (N onglets) + `TabBarView` (une liste
/// indépendante par onglet, état préservé au switch).
class ZTabbedList extends StatefulWidget {
  /// Construit les onglets à partir de [tabs]. [initialIndex] fixe l'onglet actif
  /// initial ; [onTabChanged] est notifié à chaque changement d'onglet ;
  /// [isScrollable] rend la barre défilante (nombreux onglets) ; [header]
  /// pose un widget partagé au-dessus de la barre d'onglets ;
  /// [activeIndexNotifier] suit l'index de l'onglet actif.
  const ZTabbedList({
    required this.tabs,
    this.initialIndex = 0,
    this.onTabChanged,
    this.isScrollable = false,
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
    widget.activeIndexNotifier?.value = _tabController.index;
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
      widget.activeIndexNotifier?.value = _tabController.index;
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChange)
      ..dispose();
    super.dispose();
  }

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
          tabs: <Widget>[
            for (final tab in widget.tabs)
              Tab(
                // Cible tactile ≥ 48 dp (AD-13).
                height: 48,
                icon: tab.icon == null ? null : Icon(tab.icon),
                child: Text(
                  label(context, tab.labelKey),
                  textAlign: TextAlign.center,
                ),
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
                  builder: tab.builder,
                ),
            ],
          ),
        ),
      ],
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
